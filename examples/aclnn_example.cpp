#include "acl/acl.h"
#include "aclnn_t5_split_qkv_append_cache.h"
#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include <algorithm>

static void Check(aclError code, const char* call) {
  if (code != ACL_SUCCESS) throw std::runtime_error(std::string(call) + ": " + std::to_string(code));
}
struct Runtime {
  aclrtStream stream{};
  Runtime() { Check(aclInit(nullptr), "aclInit"); Check(aclrtSetDevice(0), "setDevice"); Check(aclrtCreateStream(&stream), "createStream"); }
  ~Runtime() { if (stream) { aclrtSynchronizeStream(stream); aclrtDestroyStream(stream); } aclrtResetDevice(0); aclFinalize(); }
};
struct Buffer {
  void* ptr{}; size_t bytes;
  explicit Buffer(size_t n) : bytes(n * 2) { Check(aclrtMalloc(&ptr, std::max<size_t>(bytes, 32), ACL_MEM_MALLOC_NORMAL_ONLY), "malloc"); }
  ~Buffer() { if (ptr) aclrtFree(ptr); }
  Buffer(const Buffer&) = delete;
};
struct Tensor {
  aclTensor* ptr{};
  Tensor(Buffer& b, std::vector<int64_t> shape, aclDataType type) {
    std::vector<int64_t> strides(shape.size(), 1);
    for (int i = int(shape.size()) - 2; i >= 0; --i) strides[i] = strides[i+1] * shape[i+1];
    int64_t storageElements = b.bytes / 2;
    ptr = aclCreateTensor(shape.data(), shape.size(), type, strides.data(), 0, ACL_FORMAT_ND,
                          &storageElements, 1, b.ptr);
    if (!ptr) throw std::runtime_error("aclCreateTensor failed");
  }
  ~Tensor() { if (ptr) aclDestroyTensor(ptr); }
};
int main(int argc, char** argv) {
  try {
    const bool negative = argc > 1 && std::string(argv[1]) == "--negative";
    const bool bf16 = argc > 1 && std::string(argv[1]) == "--bf16";
    const aclDataType type = bf16 ? ACL_BF16 : ACL_FLOAT16;
    Runtime runtime;
    constexpr int64_t B = 2, H = 3, L = 2, D = 5, N = B * H * D;
    Buffer packed(3*N), pastKey(N*L), pastValue(N*L), query(N), key(N*(L+1)), value(N*(L+1));
    std::vector<uint16_t> x(3*N), pk(N*L), pv(N*L);
    for (size_t i=0; i<x.size(); ++i) x[i] = uint16_t(i * 997 + 0x7c01);
    for (size_t i=0; i<pk.size(); ++i) { pk[i]=uint16_t(i * 719 + 0x8000); pv[i]=uint16_t(i * 113 + 0xfc00); }
    Check(aclrtMemcpy(packed.ptr, packed.bytes, x.data(), packed.bytes, ACL_MEMCPY_HOST_TO_DEVICE), "copy qkv");
    Check(aclrtMemcpy(pastKey.ptr, pastKey.bytes, pk.data(), pastKey.bytes, ACL_MEMCPY_HOST_TO_DEVICE), "copy pk");
    Check(aclrtMemcpy(pastValue.ptr, pastValue.bytes, pv.data(), pastValue.bytes, ACL_MEMCPY_HOST_TO_DEVICE), "copy pv");
    Tensor tx(packed,{B,1,3*H*D},type), tpk(pastKey,{B,H,L,D},type), tpv(pastValue,{B,H,L,D},type);
    Tensor tq(query,{B,H,1,D},type), tk(key,{B,H,L+1,D},type), tv(value,{B,H,L+1,D},type);
    if (negative) {
      // Five independent invalid metadata requests. Never submit a kernel.
      for (int scenario=0; scenario<5; ++scenario) {
        auto shape = std::vector<int64_t>{B,H,1,D};
        if (scenario == 0) shape = {B,H,D};
        if (scenario == 1) shape[3] = D - 1;
        if (scenario == 2) shape[0] = B - 1;
        Tensor bad(query, shape, scenario == 3 ? ACL_INT16 : type);
        uint64_t ws=0; aclOpExecutor* ex=nullptr;
        auto code = aclnnT5SplitQkvAppendCacheGetWorkspaceSize(tx.ptr,tpk.ptr,tpv.ptr,
            scenario == 4 ? H + 1 : H,D,bad.ptr,tk.ptr,tv.ptr,&ws,&ex);
        if (code == ACL_SUCCESS) throw std::runtime_error("invalid metadata accepted: " + std::to_string(scenario));
        std::cout << "{\"metadata_scenario\":" << scenario << ",\"status\":\"passed\",\"acl_status\":" << code << "}\n";
      }
      return 0;
    }
    uint64_t ws=0; aclOpExecutor* executor=nullptr;
    Check(aclnnT5SplitQkvAppendCacheGetWorkspaceSize(tx.ptr,tpk.ptr,tpv.ptr,H,D,tq.ptr,tk.ptr,tv.ptr,&ws,&executor), "GetWorkspaceSize");
    if (ws) throw std::runtime_error("nonzero explicit workspace");
    Check(aclnnT5SplitQkvAppendCache(nullptr,0,executor,runtime.stream), "aclnn launch");
    Check(aclrtSynchronizeStream(runtime.stream), "synchronize");
    std::array<std::vector<uint16_t>,3> result{std::vector<uint16_t>(N),std::vector<uint16_t>(N*(L+1)),std::vector<uint16_t>(N*(L+1))};
    std::array<Buffer*,3> buffers{&query,&key,&value};
    for (int i=0;i<3;++i) Check(aclrtMemcpy(result[i].data(),buffers[i]->bytes,buffers[i]->ptr,buffers[i]->bytes,ACL_MEMCPY_DEVICE_TO_HOST), "copy output");
    for(int64_t b=0;b<B;++b) for(int64_t h=0;h<H;++h) for(int64_t d=0;d<D;++d) {
      const int64_t qpos=(b*H+h)*D+d;
      if(result[0][qpos]!=x[b*3*H*D+h*D+d]) throw std::runtime_error("query bits differ");
      for(int64_t l=0;l<=L;++l) {
        const int64_t dst=((b*H+h)*(L+1)+l)*D+d;
        for(int s=1;s<=2;++s) {
          const auto expected=l==L?x[b*3*H*D+s*H*D+h*D+d]:(s==1?pk:pv)[((b*H+h)*L+l)*D+d];
          if(result[s][dst]!=expected) throw std::runtime_error("cache bits differ");
        }
      }
    }
    std::cout << "{\"status\":\"passed\",\"workspace_bytes\":0,\"bit_mismatches\":0}\n";
    return 0;
  } catch(const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
