# T5 QKV 拆分与缓存追加算子：社区说明草稿

本文件是上游社区待发布说明，2026-11-03 更新；随个人实现仓公开，但尚未同步到上游设计 PR 或提交上游实现 PR。

单 token 解码时，融合输入按全部 Q、全部 K、全部 V 排列。实现输出独立连续 Q，并向两份历史缓存追加当前 K/V。FP16/BF16 共用 uint16 原样搬运，支持 L=0、非对齐维度、原始 NaN 位模式和连续存储偏移视图。

工程包含完整 Ascend C/OpDef/tiling、私有 `.run` 安装包、ACLNN 两阶段 API、独立 C++ 样例、PyTorch `run`、Kernel launch `run_direct` 及只保存元数据的 `prepare`。当前设计见 [design.md](design.md)，包括 48 AIV 分核、128 KiB UB 双缓冲、workspace=0、K 后缀 L2 策略、对齐判断前移、ACLNN executor 复用、stream 顺序和生命周期处理。

实测运行源码 `f52671207769bf5f334972c997743eb6aa6f91b3` 在一次完整原固定协议中 10/10 通过，大缓存 FP16/BF16 为 70.22155/70.20120 μs。98 条有效输入/入口精度、84 条非法输入、3 条验证器反例、15 条工程和 20 条内存记录全部通过。原始五轮数据、源码和二进制 SHA256、环境及阶段日志均随交付包提供。跨进程时延变化及独立配对对照边界见 [最终验收](ACCEPTANCE_20261101.md)。

环境为 Ascend910_9382、CANN 9.1.0、驱动 26.1.1。用户接受当前驱动并披露差异；原题指定的 25.5.t6.b001 未测试。不能把本地固定性能通过扩大为社区正式验收完成。

2026-11-03 只读核实：[设计 PR #2604](https://github.com/xLLM-AI/xllm/pull/2604) 仍开放、未合入，3 个文件仅包含旧版中英文设计与侧边栏；正式 reviews 列表为空。本地最新设计和 10/10 证据尚未同步到此 PR。该设计分支不包含本次实现，不能作为实现代码交付地址。

个人实现仓现已公开发布：`https://github.com/wangzhao-11a/t5-qkv-append-cache`，分支 `codex/t5-qkv-append-cache`，算子目录为仓库根目录 `.`，固定交付提交 `874f2bbbb385bc032d004735ae524244401a29ce`，实测运行 commit 仍为 f526712。公开仓库、完整目录树及 c9/f526/874 固定提交已匿名核实。仍待提交上游实现 PR、同步最新设计并跟进社区评审。设计仓 `https://github.com/wangzhao-11a/xllm` 的 `docs/t5-split-qkv-append-cache-design` 分支仅承载设计文档。
