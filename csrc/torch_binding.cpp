#include <torch/extension.h>
#include <c10/core/DeviceGuard.h>
#include "torch_npu/csrc/core/npu/NPUStream.h"
#include "torch_npu/csrc/core/npu/NPUCachingAllocator.h"
#include "torch_npu/csrc/aten/CustomFunctions.h"
#include "acl/acl.h"
#include "aclnn_t5_split_qkv_append_cache.h"
#include "../common/t5_plan.h"
#include <array>
#include <memory>
#include <tuple>
#include <vector>

extern "C" void t5LaunchDirect(void*, void*, void*, void*, void*, void*, void*,
                               uint32_t, uint32_t, uint32_t, uint32_t);
namespace {
using Tensors = std::array<at::Tensor, 3>;
using Shape = std::array<int64_t, 4>;
struct Arguments {
  std::vector<at::Tensor> inputs;
  int64_t heads = -2, dim = -2;
};
Arguments ParseArguments(pybind11::handle inputs, pybind11::handle attributes) {
  if ((!PyTuple_Check(inputs.ptr()) && !PyList_Check(inputs.ptr())) || PySequence_Size(inputs.ptr()) != 3)
    throw pybind11::value_error("inputs must be a tuple/list of exactly three tensors");
  if (!PyDict_Check(attributes.ptr())) throw pybind11::type_error("attributes must be a dictionary");
  Arguments result;
  Py_ssize_t position = 0;
  PyObject *key, *value;
  while (PyDict_Next(attributes.ptr(), &position, &key, &value)) {
    const bool heads = PyUnicode_Check(key) && PyUnicode_CompareWithASCIIString(key, "headNum") == 0;
    const bool dim = PyUnicode_Check(key) && PyUnicode_CompareWithASCIIString(key, "headDim") == 0;
    if (!heads && !dim) throw pybind11::value_error("unknown attributes");
    // Exact int excludes bool and int subclasses, matching the public contract.
    if (!PyLong_CheckExact(value)) throw pybind11::value_error("attributes must be integers");
    const int64_t number = PyLong_AsLongLong(value);
    if (PyErr_Occurred()) throw pybind11::error_already_set();
    if (number < 1 || number > (heads ? 128 : 256)) throw pybind11::value_error("attribute out of range");
    (heads ? result.heads : result.dim) = number;
  }
  result.inputs = pybind11::cast<std::vector<at::Tensor>>(inputs);
  return result;
}
Shape Validate(const std::vector<at::Tensor>& xs, int64_t headNum, int64_t headDim) {
  TORCH_CHECK(xs.size() == 3, "expected qkv, pastKey, pastValue");
  const auto& q = xs[0]; const auto& k = xs[1]; const auto& v = xs[2];
  TORCH_CHECK(q.device().type() == c10::DeviceType::PrivateUse1, "inputs must be on NPU");
  TORCH_CHECK(q.scalar_type() == at::kHalf || q.scalar_type() == at::kBFloat16, "FP16 or BF16 required");
  for (const auto& x : xs) {
    TORCH_CHECK(x.device() == q.device(), "all inputs must use the same device");
    TORCH_CHECK(x.scalar_type() == q.scalar_type(), "input dtype mismatch");
    TORCH_CHECK(x.layout() == c10::kStrided && x.is_contiguous(), "contiguous ND input required");
    const auto format = at_npu::native::custom_ops::get_npu_format(x);
    // Base NCHW/NCDHW descriptors have the same contiguous physical bytes.
    // Reject padded/blocked internal formats instead of pretending they are ND.
    TORCH_CHECK(format == ACL_FORMAT_ND || format == ACL_FORMAT_NCHW || format == ACL_FORMAT_NCDHW,
                "contiguous ND/base storage required; internal blocked format is unsupported");
  }
  TORCH_CHECK(q.dim() == 3 && k.dim() == 4 && v.dim() == 4, "invalid input rank");
  TORCH_CHECK(k.sizes() == v.sizes(), "cache shape mismatch");
  const auto b = k.size(0), h = k.size(1), l = k.size(2), d = k.size(3);
  TORCH_CHECK(t5qkv::ValidShape(b, h, l, d), "shape range/output element limit exceeded");
  TORCH_CHECK(q.size(0) == b && q.size(1) == 1 && q.size(2) == 3 * h * d, "invalid packed QKV shape");
  TORCH_CHECK((headNum == -2 || headNum == h) && (headDim == -2 || headDim == d), "attribute/shape mismatch");
  return {b, h, l, d};
}

struct TensorDeleter { void operator()(aclTensor* x) const { if (x) aclDestroyTensor(x); } };
using Descriptor = std::unique_ptr<aclTensor, TensorDeleter>;
Descriptor Describe(const at::Tensor& x) {
  // data_ptr() already includes storage_offset(). Describe this contiguous span
  // with offset zero, instead of applying the PyTorch offset a second time.
  const int64_t storageSize = x.numel();
  auto type = x.scalar_type() == at::kHalf ? ACL_FLOAT16 : ACL_BF16;
  auto* p = aclCreateTensor(x.sizes().data(), x.dim(), type, x.strides().data(),
                            0, ACL_FORMAT_ND, &storageSize, 1, x.data_ptr());
  TORCH_CHECK(p, "aclCreateTensor failed");
  return Descriptor(p);
}

std::tuple<at::Tensor, at::Tensor, at::Tensor> Execute(
    const std::vector<at::Tensor>& xs, int64_t headNum, int64_t headDim, bool direct) {
  const auto shape = Validate(xs, headNum, headDim);
  const auto [b, h, l, d] = shape;
  c10::DeviceGuard deviceGuard(xs[0].device());
  const auto options = xs[0].options().requires_grad(false);
  Tensors out{at::empty({b,h,1,d}, options), at::empty({b,h,l+1,d}, options), at::empty({b,h,l+1,d}, options)};
  auto stream = c10_npu::getCurrentNPUStream(xs[0].device().index());
  // Official stream() drains pending host submissions, not device work. This
  // preserves ordering with preceding PyTorch operations without another host
  // callback/captured-output queue. Kernel execution remains asynchronous.
  const aclrtStream rawStream = stream.stream();
  TORCH_CHECK(rawStream, "failed to obtain ordered current NPU stream");
  auto call = [&]() -> int {
    for (const auto& x : xs)
      if (x.numel()) c10_npu::NPUCachingAllocator::recordStream(x.storage().data_ptr(), stream);
    if (direct) {
      t5LaunchDirect(rawStream, xs[0].data_ptr(), xs[1].data_ptr(), xs[2].data_ptr(),
                     out[0].data_ptr(), out[1].data_ptr(), out[2].data_ptr(),
                     shape[0], shape[1], shape[2], shape[3]);
      return 0;
    }
    std::array<Descriptor, 6> desc{Describe(xs[0]), Describe(xs[1]), Describe(xs[2]),
                                  Describe(out[0]), Describe(out[1]), Describe(out[2])};
    uint64_t workspaceSize = 0;
    aclOpExecutor* executor = nullptr;
    auto status = aclnnT5SplitQkvAppendCacheGetWorkspaceSize(
        desc[0].get(), desc[1].get(), desc[2].get(), shape[1], shape[3],
        desc[3].get(), desc[4].get(), desc[5].get(), &workspaceSize, &executor);
    TORCH_CHECK(status == ACL_SUCCESS, "GetWorkspaceSize failed: ", status);
    TORCH_CHECK(workspaceSize == 0, "zero-workspace contract violated: ", workspaceSize);
    status = aclnnT5SplitQkvAppendCache(nullptr, 0, executor, rawStream);
    TORCH_CHECK(status == ACL_SUCCESS, "aclnnT5SplitQkvAppendCache failed: ", status);
    return 0;
  };
  call();
  return {std::move(out[0]), std::move(out[1]), std::move(out[2])};
}
}
PYBIND11_MODULE(TORCH_EXTENSION_NAME, m) {
  m.def("validate", [](pybind11::handle inputs, pybind11::handle attributes) {
    auto args = ParseArguments(inputs, attributes);
    pybind11::gil_scoped_release release;
    return Validate(args.inputs, args.heads, args.dim);
  });
  m.def("execute", [](pybind11::handle inputs, pybind11::handle attributes, bool direct) {
    auto args = ParseArguments(inputs, attributes);
    pybind11::gil_scoped_release release;
    return Execute(args.inputs, args.heads, args.dim, direct);
  });
}
