# 大缓存优化：2026-10-30 后续对照

基线 c9decf212667337d518e3a1d48dc3e07cd5fef0e 原目录、二进制、证据与源码归档保留。工作起点 b3f38f7890087853d449ff2bd5ab04a9aaadff91，运行代码与 c9decf2 相同。容器 86d7c3021b9e、Ascend910_9382、CANN 9.1.0、驱动 26.1.1、物理设备 1→逻辑设备 0；模型路径不适用，无新服务端口。SSH 复用既有会话，双层 20 秒 keepalive。

## 新证据

读取既有 916c7d7 的官方 msprof L2 原始 CSV，而非重新跑相同基准。007 后三条任务约 92.8–93.7 us；每条 AIV r0_read_cache_hit=524768、miss=0，r1_read_cache_hit=524767、miss=1。原先 PipeUtilization 中大输入 MTE2=0.77、MTE3=0.748、scalar=0.109。原始 CSV 下载及哈希保存在 artifacts/optimization_20261030/。

这支持优先检查搬运调度和同步，而不是把大量 L2 miss 当成已知瓶颈。数据来自历史版本，不能冒充新候选的计数器结果。

## 对照 1：输出 tile 内聚合

假设：原 Copy 对每个历史/追加片段独立 EnQue/DeQue 和 MTE3 写回；同一 tile 的片段聚合到一个 UB 后，只做一次队列交接及输出写回，可减少 DMA 小事务和同步。

唯一实现变量：大且 32B 对齐的缓存路径，将多个 MTE2 片段放入同一个局部 tile，单次写回完整输出 tile。保留 c9decf2 的 64 KiB×2、48 AIV 交错分核、输入 NORMAL、输出 DISABLE；不引入新 workspace、数据类型转换或第二次 L2 hint。非对齐输入继续使用原始路径。

CPU 地址检查覆盖 35 个公开 shape、120 个随机 shape；增加 UB 片段偏移/长度/源地址的 32B 对齐和容量约束。报告写到独立 artifacts 路径，不覆盖最佳版本报告。

验收仍按构建→扩大 Smoke→完整正确性/工程/内存→固定 50/200/5 性能。任何阶段失败即停止依赖阶段。性能 10/10 全部通过前不标记完成。
