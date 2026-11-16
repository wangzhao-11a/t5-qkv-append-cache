# 分方向 DMA 对齐候选：待上机

开发基于独立分支 `codex/t5-qkv-alignment-revalidation-20261116`，原实测
f526712、c9 基线、二进制及提交包保持保留。此候选尚未做 CANN 编译、NPU
正确性或性能验证，不能作为已修复 007/017 的提交。

## 内核改动与适用边界

`op_kernel/t5_copy.h` 原来以源地址、目的地址和长度的共同对齐条件，同时
选择 G2L 与 L2G 的普通/填充 DMA。现在分别判断两个方向：源未对齐而目的
与长度对齐时，允许 Pad 读取后普通 DMA 写回；反方向同理。长度不是
16 个 uint16 的整数倍时仍双侧 Pad。原 all-aligned 快路径、分核、缓存
预算、缓存后缀、队列顺序及宿主分配/执行器策略保持原实现。

假设：单边不对齐造成了不必要的双侧 Pad 降级；该候选消除这种耦合。
完全对齐时两版均使用普通 DMA，不能据此预测完全对齐慢档的改善。
最终设备代码、调度成本和延迟均须上机验证；不要把源码层面的同路径
解释为编译后指令完全相同。

当前单块、零 stride、零显式 padding、长度 32B 整数倍的条件下，Pad 读取
不会在有效数据前后插入需要转移的元素。该推论依据官方
[DataCopyPad 参数说明](https://www.hiascend.com/doc_center/source/zh/CANNCommunityEdition/910beta2/API/ascendcopapi/atlasascendc_api_07_0265.html)。
普通 DMA 的长度约束见[基础搬运说明](https://www.hiascend.com/doc_center/source/en/CANNCommunityEdition/900/API/ascendcopapi/atlasascendc_api_07_0103.html)。
仍须在实际 CANN 9.1.0 头文件及编译器核对支持情况。队列顺序不改，遵循
[EnQue](https://www.hiascend.com/document/detail/en/CANNCommunityEdition/910/API/ascendcopapi/docs/en/api/SIMD-API/basic_api/resource_management/TQue/EnQue.md)
和 [DeQue](https://www.hiascend.com/document/detail/en/CANNCommunityEdition/910/API/ascendcopapi/docs/en/api/SIMD-API/basic_api/resource_management/TQue/DeQue.md)
的 TQueBind 无 Vector 用法。

## 本地验证

- 冻结 reference 哈希与 Linux 脚本编码检查通过。
- 既有 CPU 地址模型：35 个公开形状、120 个随机形状通过。它不执行内核。
- `tests/host_kernel/` 直接包含真实内核头文件，准备了 776 个 CPU 适配器
  语义场景：六个输入/输出独立偏移组合、空缓存、奇数 D/尾块、FP16/BF16
  位模式、大缓存和 guard 区。原 f526712 与候选均通过 MSVC 主机编译。
- Windows 应用控制以 4551 拒绝新 EXE，**上述 776 场景尚未执行**。
  不绕过策略；Linux 上先按该目录 README 运行 CPU 语义测试。
- 主机适配器不模拟 GM 别名、缓存映射、异步 DMA、设备同步和性能。
- ABBA 诊断的 Python 语法、help、无设备确认的提前拒绝及拒绝覆盖检查通过。
- OPP 路径排他校验和失败段记录保留的离线检查通过。
- 重复性能脚本的三项模拟控制流检查通过：benchmark 首败只启动一次、
  性能验收首败不进入下一次、全部成功恰好执行五次。未执行真实 benchmark。

本地结果位于 `artifacts/cpu_address_model_candidate_20261116.json`、
`artifacts/host_kernel_compile_20261116.json` 与
`artifacts/host_kernel_execution_block_20261116.json`。
可移交的本地检查摘要及证据哈希见 `reports/development_20261116.json`。

## 上机执行顺序

1. 先收取本次已有的五轮报告、地址记录和二进制身份，区分五次完整运行
   与一次协议内五轮。只读核对型号、容器、版本、设备映射、进程和端口。
2. 用精确 Git 归档部署到新目录；清单/SHA256、LF/无 BOM 及目标端
   `bash -n` 通过后才构建。保留原二进制与私有 OPP，分别构建候选的
   ACLNN 与 direct 两入口，核对实际加载内核身份。先执行 CPU 语义测试，
   再执行 smoke、完整正确性、重复输出稳定性和工程/内存检查。
3. 需要地址对照时，复用冻结 `benchmark.measure`，一次仅选择一个输入和
   一个偏移假设。示例（全部占位符必须替换为核实后的值）：

   ```bash
   export ASCEND_RT_VISIBLE_DEVICES=<verified_selector>
   export T5_PHYSICAL_DEVICE=<verified_physical_id>
   export T5_DEVICE_CONFIRMED=1
   export T5_OPP_ROOT=<matching_private_opp>
   export ASCEND_CUSTOM_OPP_PATH="$T5_OPP_ROOT/vendors/t5qkv"
   python tests/compare_alignment_paths.py \
     --solution-root <preserved_baseline_or_candidate_directory> \
     --case 007 --entry run_direct --input-index 1 --offset 1 \
     --source-commit <exact_40_digit_commit> \
     --expected-extension-sha256 <verified_64_digit_sha256> \
     --hypothesis 'Single past-key input loses 32B alignment in the same allocation' \
     --report artifacts/validation/alignment_007_key_offset1.json
   ```

   脚本按 A/B/B/A 使用同一 backing allocation，计时外逐段填入相同数据。
   每段前后核对位精度、输入未改及输出所有权；计时中不采样地址或保留输出。
   记录真实宿主映射与私有 OPP 候选文件指纹，但不冒充已观察设备 .o 的选择。
   诊断进程只允许所选私有 OPP 搜索路径，拒绝混入其他自定义算子库；失败段
   也保留已经取得的计时和地址记录。旧基线目录不会被改写。
   偏移 16 元素对照保持 32B 对齐，可区分低 5 位条件与其他布局影响。
   明确的诊断结果不等于正式性能验收，不跑全部排列来挑最好数值。
4. 若快慢档的对齐条件相同，停止“32B 分支切换”解释和本候选的性能归因，
   按已收取的加载/地址证据选下一项区分实验。已有否证路线见 REVALIDATION。
5. 候选完成一次原始全套验收后，运行 `bash scripts/phase_repeated_performance.sh`。
   它要求原 `performance_phase` 成功，复用既有设备空闲门禁，每次启动新的
   原始十例 benchmark 进程。五次均须通过各自的冻结中位数门槛；首次失败
   立即停止并保留原始记录，不能反复重试挑一个通过。此项重复进程稳定性
   与原始单次固定验收分开记录。

收到设备后按证据选择诊断，正式性能需整板空闲。
机器版本、路径或分配改变时先确认并调整调用环境，不重建已有已知可用运行库。
