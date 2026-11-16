# Host-only kernel semantics

`test_t5_copy.cpp` includes the real `op_kernel/t5_copy.h` and `common/t5_plan.h`.
The local `kernel_operator.h` adapter implements only the single-block byte-copy
and queue operations used here. It checks ordinary-DMA alignment, GM bounds,
UB capacity and queue call order. It does not implement CANN, cache aliases,
asynchronous scheduling, device concurrency or performance.

The executable is prepared to check 776 scenarios: six small shapes, every
combination of independent 0/1-element offsets for the six tensors, two sets of
FP16/BF16 special bit patterns, and the actual large shape with aligned storage
or one offset input. It verifies output bits, input immutability and guard
regions, and prints separate DMA/Pad call counts for each large case.

On the current Windows machine, only host compilation succeeded. Windows
application control rejected execution with error 4551 both inside and outside
the sandbox. No semantic test pass is claimed and no policy bypass was tried.

From the repository root, the Windows compile-only command is:

```powershell
python tests/check_host_kernel.py --compile-only --report artifacts/host_kernel_compile.json
```

On a Linux host with an existing C++17 compiler and this Git checkout, the following checks both
headers without using an NPU. It retains the generated directory and logs:

```bash
set -euo pipefail
mkdir -p artifacts
task_test_dir=$(mktemp -d ./artifacts/host-kernel-linux-XXXXXX)
mkdir "$task_test_dir/baseline" "$task_test_dir/candidate"
git show f52671207769bf5f334972c997743eb6aa6f91b3:op_kernel/t5_copy.h > "$task_test_dir/baseline/t5_copy.h"
cp op_kernel/t5_copy.h "$task_test_dir/candidate/t5_copy.h"
for version in baseline candidate; do
  c++ -std=c++17 -O2 -Wall -Wextra -Itests/host_kernel -I. -I"$task_test_dir/$version" \
    tests/host_kernel/test_t5_copy.cpp -o "$task_test_dir/$version/test_t5_copy" || exit
  "$task_test_dir/$version/test_t5_copy" > "$task_test_dir/$version/run.log" || exit
done
```

For an exact-commit source archive without `.git`, replace the `git show` line
with a copy from the preserved f526712 source directory. Verify that header's
SHA256 is `80187bdde2fc70e730a1f690dc1c0cfc4bf516a38a2d7988c9e3c0a911ea79c4`
before compiling. Never substitute the candidate header for both versions.

This remains a host semantic check even when run on an Ascend machine. The
actual CANN build, device correctness, memory and performance checks are still
required separately.
