# 算子设计

## 数据与地址

定义 `S=H×D`，元素以 uint16_t 解释。Q 输出线性地址 `q=((bH+h)D+d)`，源地址为 `3bS+hD+d`。K/V 输出地址 `o=((bH+h)(L+1)+t)D+d`；当 `t<L`，源历史地址为 `((bH+h)L+t)D+d`；否则源 QKV 地址为 `3bS+sS+hD+d`，其中 K 的 s=1、V 的 s=2。

不执行浮点计算或 dtype 转换，FP16 与 BF16 使用相同 16 位搬运路径。NaN、Inf、正负零和非正规数的所有位均保持。L=0 不进入历史缓存搬运分支。

## 分核与缓冲

各输出独立切分为 32768 元素（64 KiB）的连续 tile。工作编号顺序为 Q、K、V；最多 48 个 AIV 按 `blockIdx + n×blockNum` 领取 tile。所有 tile 起点均为 32 字节对齐；一个非对齐行跨 tile 时，两个核仍写入不同的对齐区间。每个 tile 内根据 batch/历史行/追加 token 边界分割 DMA 片段。

使用 `TQueBind<VECIN,VECOUT,2>` 管理两份 64 KiB UB 缓冲。实际源/目的地址与片段长度均满足 32 字节对齐时使用 DataCopy；否则使用 DataCopyPad 搬运合法片段。判断包含真实 GM 基地址，不能仅凭逻辑索引推断偏移视图的对齐。两条路径均不补读输入末尾，也不将 padding 写出。总片上队列缓冲 131072 字节，每核还使用少量标量状态。明确指定 `KERNEL_TYPE_AIV_ONLY`。

大缓存由所有 AIV 共同搬运；小输入减少到实际 tile 数个核。单个输出缓存达到 32 MiB 时，为只写的 K/V 输出设置官方 `CACHE_MODE_DISABLE`，历史输入仍使用默认 L2 策略。官方 msprof 在 `c5f6658` 上显示大输入 MTE2/MTE3 占比较高；`b2b0cca` 的输出绕过 L2 修改将正式大输入时延从约 228–232 微秒降至约 94–95 微秒，但这仍未满足 75/77 微秒固定门槛。性能结论以对应版本实测为准，不能依据带宽模型宣布达标。对于 D=1 等小行，片段数可能较多，但这些边界仍必须先保证正确性。

## 校验与资源

Host 用 int64/uint64 计算尺寸乘积，先检查 B/H/L/D 范围，再检查 `BHD(2L+3) ≤ 2^28`。框架层同时校验输入数量、属性容器与类型、dtype、device、rank、shape、连续性和物理格式。OpDef shape/type 推导及 tiling 重复检查原生调用的元数据。C++ 原生调用方负责真实指针有效、ND 描述正确、输出地址不重叠。

输出通过三次独立 at::empty 分配。不存在缓存输出、预存结果、CPU 代算、输入原地修改或额外全局工作区。显式 workspace=0，调用时再次核查 ACLNN 的 workspace size。输出字节数为 `2BHD(2L+3)`；内存上限为该值加 16384 字节。

张量描述采用已经包含 storage_offset 的 data_ptr，ACL tensor 的 offset 设为 0，以免偏移重复叠加。空历史张量可以具有空指针，但不会被内核读取。

## stream 与生命周期

调用时获取输入设备的当前 NPU stream，再调用官方 `NPUStream::stream()` 排空先前的主机提交队列，使当前 stream 上的调用顺序与先前 PyTorch 操作一致。它不等待设备计算完成。随后直接在调用线程完成 ACLNN 两阶段提交或 kernel launch，省去额外主机回调及其张量捕获；设备执行仍为异步。提交前仅对输入 recordStream，保护跨 stream 输入提前释放场景。输出在当前 stream 分配，依靠同 stream 的分配/执行顺序安全复用，不添加多余回收事件。两个入口共用该策略。

torch_npu 5dd8ef3 的 recordStream 不跳过分配 stream，早期版本对输出登记后产生延迟回收。旧失败日志与完整精度基线保存在 `artifacts/preserved_5ae7160.tar.gz`，修正必须通过原有严格峰值及 20 次释放检查，不能放宽验收值。`6245532` 和 `c5f6658` 两版已有全部精度、生命周期和内存通过记录。

prepare 保存 shape/dtype/device/属性，不保存张量或 stream；每次调用重新验证并分配。旧元数据不匹配必须报错。

## 验证设计

先执行原始测试包字节与脚本编码检查，再编译、原生 C++ FP16/BF16 最小调用和非法元数据拒绝检查；随后公开 35 例、直调 35 例、12 个偏移种子 × 两入口、28 类非法场景 × 三入口、验证器反例、双 stream、连续两次缓存追加、提前释放和多次输出保留检查。最后执行 10 个 shape 的内存和固定性能协议。

CPU 地址模型遍历全部 tile/片段的覆盖和界限，并以独立坐标推导核对片段首/中/末地址；较小 shape 逐位对照原包 golden。它既不模拟 CANN 的 DMA 行为，也不能证明内核编译、同步或设备性能正确。

## 上游核对

核对 xLLM 主分支 commit `fea4d5d6a3f46b37b3703262be182e0579914103` 的完整 tree 及 T5 相关公开 issue/PR。未发现本题同名算子；T5 搜索结果中的已合入项目是模型/流水线重构，并非本题实现。没有引入未合入 PR。

官方参考：
- [xLLM 算子接入目录](https://github.com/xLLM-AI/xllm/tree/fea4d5d6a3f46b37b3703262be182e0579914103/xllm/core/kernels/npu/xllm_ops)
- [Ascend 官方 samples 固定版本](https://github.com/Ascend/samples/tree/fc2aea93e48be8f8cee51d0c6c1b13a08155f83a/cplusplus/level1_single_api/4_op_dev/6_ascendc_custom_op)
- [torch_npu 2.10 OpCommand](https://github.com/Ascend/pytorch/blob/v2.10.0/torch_npu/csrc/framework/OpCommand.cpp)
- [torch_npu 2.10 分配器 recordStream](https://github.com/Ascend/pytorch/blob/v2.10.0/torch_npu/csrc/core/npu/NPUCachingAllocator.h)
- [本次运行版本的分配器实现](https://github.com/Ascend/pytorch/blob/5dd8ef3f9b375b5ae4a83538d5785754148c3302/torch_npu/csrc/core/npu/NPUCachingAllocator.cpp)
- [官方纯搬运 TQueBind 说明](https://github.com/Ascend/agent-skills/blob/master/skills/ascendc-operator-performance-optim/references/api-usage-prof.md)
- [CANN Kernel 类型](https://www.hiascend.com/doc_center/source/en/CANNCommunityEdition/900/API/ascendcopapi/atlasascendc_api_07_0218.html)

下载的官方示例只作接口参考，未直接作为本地算子实现导入。保存的下载哈希见 `research/downloads.json`。
