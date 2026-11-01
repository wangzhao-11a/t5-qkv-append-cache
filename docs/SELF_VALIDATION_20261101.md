# T5 QKV 拆分与缓存追加：自验证步骤

本材料对应实测源码 **f52671207769bf5f334972c997743eb6aa6f91b3**。原固定性能 **10/10 通过**，大缓存 FP16/BF16 **70.22155 / 70.20120 μs**，上限 75 / 77 μs。98 条有效输入/入口精度、84 条非法输入、3 条验证器反例、15 条工程和 20 条内存记录均通过。重复稳定性为 8 项 × 20 次。

完整证据 65 项，SHA256 `fcb4f5398b008bd3affe784bfe39a0d842c669cfaad5824c51f9488e5edadff6`。三份 Excel 的数据均来自本次原始 JSON；独立 views/concat 对照仅用于耗时比，其自定义结果不替换固定协议成绩。跨进程时延有变化，详见工程包 `docs/ACCEPTANCE_20261101.md`。

## 1. 基线、环境和原始执行记录

原 c9decf2、原七件和旧交付 ZIP 保留。实际验收为 199.103.53.243、容器 e60fcee5f79f、Ascend910_9382、48 AIV/24 AIC、CANN 9.1.0、驱动 **26.1.1**。用户已确认使用此环境；题目要求的驱动 **25.5.t6.b001 未测试**。aarch64 openEuler 24.03 LTS-SP3，Python 3.12.13，torch 2.10.0+cpu，torch_npu 2.10.0.post4（5dd8ef3），NumPy 2.2.6，ml_dtypes 0.6.0。

卡 3/chip 1/物理 7，通过 `ASCEND_RT_VISIBLE_DEVICES=1` 映射逻辑 0。私有 OPP 为 `/root/.local/t5_qkv_f52671207769`。部署根目录 `/workspace/t5_qkv_tasks/t5_qkv_f52671207769`。镜像 ID 在容器内不可查询，未推测。没有模型文件，不启动服务，不监听端口。

原始启动命令为 `bash /tmp/t5_launch_aligned_fragments_20261101.sh`，脚本、所有环境设置和阶段日志位于完整工程包 `evidence/tested/reports/`。执行顺序为 LF/源码/环境检查、构建、独立 C++ 与 Python smoke、重复稳定性、完整正确性/工程/内存、性能、证据收集。四阶段及总流水线 exit=0。最终整板无 NPU 进程、无本任务 worker，端口与开始时一致。

以下命令用于**另建验证目录**后复现，先保存/核对当前进程、端口和分配设备，确认空闲再执行。不要在已完成的证据目录重跑或覆盖日志。Windows 源码必须从精确 commit 用 git archive 导出，传输前验证 LF/无 BOM，解压前核对路径布局、提交和逐文件 SHA256；构建二进制单独以清单记录。

## 2. 编译与私有安装

```bash
source /usr/local/Ascend/cann-9.1.0/set_env.sh
export PATH=/workspace/vasc031_a3/bin:$PATH
export T5_OPP_ROOT=$HOME/.local/t5_qkv_opp
# 若现有环境没有规定的 NumPy，将官方 wheel 安装到工程私有目录。
python -m pip install --no-deps --target "$PWD/python_deps" artifacts/wheels/numpy-2.2.6-*.whl
export PYTHONPATH="$PWD/python_deps:$PWD:$PWD/reference${PYTHONPATH:+:$PYTHONPATH}"
python tools/preflight.py --static
bash -n scripts/build.sh
bash scripts/build.sh > build.log 2>&1
source "$T5_OPP_ROOT/vendors/t5qkv/bin/set_env.bash"
```

生成器为 CANN 自带 msopgen。正式安装包只从 `build/aclnn/build_out/` 顶层选择；CPack 暂存目录的重复副本不能算作另一安装包。直调编译显式使用 `SOC_VERSION=Ascend910_9382`、`CMAKE_BUILD_TYPE=Release`，并拒绝在同一目录改变配置。保留既有成功产物与日志，后续修复只重编相关目标。

`setup.py` 编译 PyTorch 绑定，`examples/CMakeLists.txt` 编译独立 C++ 两阶段 API 样例。若出现加载错误，先记录实际 loader/import 错误并对具体库执行 `ldd/readelf`；不能因为构建失败推断 ABI 缺库。

## 3. 设备前置检查与最小调用

```bash
export ASCEND_RT_VISIBLE_DEVICES=1
python tools/preflight.py --output reports/environment_before.json
python tools/check_environment.py --input reports/environment_before.json --accepted-driver 26.1.1
npu-smi info
build/examples/t5_example
build/examples/t5_example --bf16
build/examples/t5_example --negative
```

先确认所分配设备空闲；不得终止其他任务来获得设备。NPU 入口只使用逻辑设备 0。独立 C++ 样例执行非对齐 D=5 的 FP16/BF16 原始位模式检查，`--negative` 记录至少五次非法元数据拒绝。

## 4. 精度、稳定性和内存

```bash
export PYTHONPATH="$PWD:$PWD/reference${PYTHONPATH:+:$PYTHONPATH}"
python reference/verify.py --solution-file "$PWD/solution.py" --report reports/public_accuracy.json > reports/public_accuracy.log 2>&1
python tests/npu_suite.py --group accuracy --report reports/extended_accuracy.json > reports/extended_accuracy.log 2>&1
python tests/npu_suite.py --group engineering --report reports/engineering.json > reports/engineering.log 2>&1
python tests/npu_suite.py --group memory --report reports/memory.json > reports/memory.log 2>&1
```

必须检查退出码。覆盖 35 例正式入口及 35 例直调；12 个额外随机种子/存储偏移 × 两入口；大缓存奇数维度 [15,17,2048,63]、storage_offset=1 的两 dtype × 两入口，共 98 条有效输入/入口记录；28 类非法场景 × prepare/run/run_direct；验证器三类反例；两条独立 stream 各至少 10 次准备后调用；输入提前释放后的另一 stream 分配压力；8 组保留输出同时进行 32 次提前释放；连续两次缓存追加；两 dtype 各 8 次执行器地址刷新，共 15 条工程记录。

精度按原始 16 位逐位比较，输出必须与所有输入/其他输出的底层存储独立，所有输入位模式不变。内存使用分配器 `active_bytes.all.current/peak`，显式 workspace=0，峰值增量上限为输出字节数+16384，每入口每个性能 shape 再执行 20 次释放回收检查。报告不可使用整卡 HBM 作为活跃张量字节数的替代指标。

## 5. 性能

```bash
python reference/benchmark.py --solution-file "$PWD/solution.py" --report reports/performance.json > reports/performance.log 2>&1
python reference/check_performance.py --report reports/performance.json --output reports/performance_acceptance.json
python tests/compare_baseline.py --report reports/baseline_comparison.json > reports/baseline_comparison.log 2>&1
python tools/check_coverage.py --reports reports
```

每个输入和算法均先验证精度。协议为 50 次预热、5 轮×200 次，保留全部 wall/event 轮次，取 wall 轮均值中位数。正式 `run` 包含新输出分配、ACLNN 提交和完成等待。设备事件含提交间隙，不称作纯内核耗时。

原任务 README/JSON/检查器规定固定绝对耗时上限；任务书另有未定义阈值的耗时比文字。固定目标由原检查器判断，另保留同机基线和比值供审阅，不擅自认定缺失的比值阈值。

## 6. 报告与归档

三份 Excel 沿用官方模板的 shape、dtype、结果、截图、解释字段；清除模板示例截图和示例测量值。按本题要求补充 case ID、入口、位不一致数、五轮耗时和按字节统计的内存上限。截图字段无实际截图则留空，真实输出以原始日志/JSON 为准。

使用 `tools/build_reports.mjs --reports <本次证据reports目录> --output <新的输出目录> --artifact-workspace <内置依赖联接目录>` 从真实 JSON 更新 Excel，再使用 `tools/finalize_materials.py --reports <本次证据reports目录> --output-dir <新的输出目录> --archive <新的七件ZIP>` 打包。两个工具均拒绝覆盖根目录 c9decf2 七件材料。失败、未执行或缺少记录不得填写通过。报告中的 CPU 地址模型测试与 NPU 实测明确区分。

本地可执行 `tests/cpu_address_model.py` 检查地址模型，它不替代 NPU 实测。提交源码、环境、二进制指纹和原始日志一并保留。截图字段保持空白，不用生成的报告预览冒充 Ascend 实测截图。
