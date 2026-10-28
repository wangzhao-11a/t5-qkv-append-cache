"""Build the thin PyTorch binding against a private CANN operator installation."""
import os
from pathlib import Path
from setuptools import setup
import torch_npu
from torch.utils.cpp_extension import BuildExtension, CppExtension

root = Path(__file__).resolve().parent
cann = Path(os.environ["ASCEND_HOME_PATH"])
private = Path(os.environ["T5_OPP_ROOT"])
headers = list(private.rglob("aclnn_t5_split_qkv_append_cache.h"))
libs = list(private.rglob("libcust_opapi.so"))
if len(headers) != 1 or len(libs) != 1:
    raise RuntimeError("Expected exactly one task ACLNN header/library in T5_OPP_ROOT")
npu = Path(torch_npu.__file__).resolve().parent
direct = root / "build/direct/lib"
if not (direct / "libt5_direct.so").is_file():
    raise RuntimeError("Build the direct launcher first; expected build/direct/lib/libt5_direct.so")
setup(
    name="t5-qkv-append-cache", version="0.1.0",
    ext_modules=[CppExtension(
        "_t5_qkv", [str(root / "csrc/torch_binding.cpp")],
        include_dirs=[str(headers[0].parent), str(cann / "include"), str(npu.parent), str(npu / "include")],
        library_dirs=[str(libs[0].parent), str(cann / "lib64"), str(npu / "lib"), str(direct)],
        libraries=["cust_opapi", "ascendcl", "nnopbase", "torch_npu", "t5_direct"],
        runtime_library_dirs=[str(libs[0].parent), str(cann / "lib64"), str(npu / "lib"), str(direct)],
        extra_compile_args=["-O3", "-std=c++17"],
    )],
    cmdclass={"build_ext": BuildExtension},
)
