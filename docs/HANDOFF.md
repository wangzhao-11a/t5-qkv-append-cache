# 2026-11-01 当前接续（优先于下方旧快照）

已连回 Ascend910_9382，地址 199.103.53.243，容器 05d447771751。旧 SSH 会话 97653 已失效；用户刷新授权后会话 32184 已连通，确认容器、卡 3/chip 1 和 VDie 标识未变化。分配为物理 6、7，选择 runtime 可见编号 1 对应物理 7/logical 0。新分配控制组已完成：c9 为 7/10，大缓存 100.29210/103.59585 us；1bba 为 8/10，大缓存 84.80070/84.38320 us。完整证据已归档，不要重复启动已结束的控制流水线。

70a03ad 和 1ecd80e 均全正确性/工程/内存通过、固定性能 8/10；大缓存分别 90.05245/89.96810 和 129.24005/129.03745 us。两者已否证并撤销，完整证据均已下载校验，PID 50325/74115 流水线已结束。当前准备对照 16：基于 1bba 只给已有有界 K 前缀设置 PERSISTENT，其余运行代码保持不变；尚无该候选的 NPU 结果。

8f00c2c 的 24 核对照已完成：7/10，大缓存 99.89330/108.17345 us；证据已导入。1bba/1ecd 完整 L2 采样与 1bba 地址诊断也已完成并归档，勿重复启动。计数不支持分工增 miss 的解释；未采样地址诊断同样约 131 us，因此变化不能单独归因于 profiler。每个大例 1051 次输出地址一致。实际加载的扩展及算子库均来自 1bba，安装文件与原 build 匹配；审计脚本将共用 NumPy 误归为算子库的断言已离线修正，原失败日志保留。

新流水线必须设置 T5_FUNCTIONAL_DEVICE_SCOPE=board 和 T5_PHYSICAL_DEVICE=7。旧 collector 的 physical_device=1 是硬编码元数据错误，旧报告保留，实际设备映射由 smoke PID/npu-smi 证实为 7。SoC 门禁和原固定协议保持。详情见 [OPTIMIZATION_20261101.md](OPTIMIZATION_20261101.md)。950PR 未纳入验收。目标仍未达到 10/10。

# 2026-10-30 后续优化进展

用户目标仍是固定性能 10/10，尚未完成。c9decf2 基线、原 reports/STATUS.json、performance.json 和交付 ZIP 均保留。

- 新证据确认设备 L2 为 192 MiB。仅让部分输出进入 L2 的 34829e0 候选，两个大缓存降至 76.5275 / 79.2032 us，较基线 94.08875 / 94.47925 us 明显改善，仍未过 75/77 us。
- 短采样曾见 176/184 MiB 输入读 miss 约 6.5%/20.8%；完整 benchmark 顺序下，176 MiB 的 miss 为 15.57%/17.57%，不能把短采样外推到验收。160/172/184 MiB、PERSISTENT 输入和 24 核也未达标；详见 [OPTIMIZATION_20261030.md](OPTIMIZATION_20261030.md) 与 [结构化证据](../reports/optimization_20261030.json)。
- 刷新授权后已读回 159b181：构建、Smoke、正确性/工程/内存通过，固定性能 8/10；007/017 为 87.1103 / 87.2277 us，均分 K/V 前缀更慢，已撤销。后台流水线已结束，不要重复启动。
- c09d875 已部署并构建，Smoke 被设备 0 占用的旧整板门禁拦下，未执行算子。功能阶段改为核查所分配设备 1，保持同一运行源码的 829bb14 全部正确性/工程/内存通过；最终固定性能 7/10，大缓存 105.7108/101.84815 us，交错访问已否证。
- 708c670 的 172 MiB 顺序 K 前缀方案全正确性通过，固定性能 5/10，大缓存 116.50015/116.5804 us；完整 msprof 输入 miss 为 26.43%/25.82%。当前 c9decf2 控制组仍为 94.57235/94.3156 us，不支持平台整体变慢。停止预算参数扫描。
- b9e1608 反向缓存方案完整正确性通过，性能 0/10，大缓存 120.6958/120.8585 us。320224a 分散缓存同样全正确性通过，性能 8/10，大缓存 127.2803/126.89245 us；两项均已撤销。
- 1bba0d0 保持 34829e0 内核，新增官方 ACLNN 执行器复用；完整验证及新增地址刷新检查通过，固定性能 8/10，大缓存 77.20215/77.59 us。同构建强制关闭复用后，大缓存 72.21455/71.52035 us 通过，小用例约 28.6–30.2 us。不能拼接两个进程的结果作为 10/10。
- 05ba122 的 auto 组合全正确性通过但仍 8/10，大缓存 94.11055/100.85635 us，已撤销。同进程 ABBA 已完成：全部输出地址采样相同，大缓存复用开/关均约 86.2/84.5 us；小例复用快约 5–6 us。前两次准备检查失败均未计时，旧日志保留。
- 当前候选恢复 1bba0d0 主机路径，只合并已缓存 K 前缀的 tile 写入；仍需完整验证，详见优化记录对照 14。下一步按精确提交部署流水线，先查状态避免重复启动。
- 已回到原目标 199.103.54.86、容器 86d7c3021b9e、Ascend910_9382。曾收到的 179.130.54.104 是 950PR，仅做只读检查后离开，未用于任务验收。
- SSH 曾使用双层 20 秒 transport keepalive 及持续远端 shell 心跳，观察到连续存活超过 90 分钟。2026-10-31 接续检查确认原会话 50644 已失效；旧令牌重连被跳板以 platform authorization denied 拒绝，已请求原目标的新授权。对照 14 尚未上传或启动。断线根因仍未证明。上传使用临时文件、远端 SHA256 校验后发布；凭据未写入项目。
- 十三组完整候选证据及 c09 门禁失败证据均已下载核验。829 首次性能门禁失败证据单独保留，确认未执行计时后才复用原构建完成一次正式测试。性能阶段现在最多等待 15 分钟取得连续三次整板空闲，不终止其他任务。
- 导入器支持 `@collector.log` 解析原始 SHA256；Windows rename 被拒绝时，复制到新目录并逐文件复验，保留暂存证据。流程事故和机械门禁已记入 memories。

以下为前一轮接续快照，不能作为当前 HEAD 状态。

---

# 2026-10-30 接续后的当前状态

任务仍未通过固定性能验收。运行代码已恢复到已知可用基线 c9decf212667337d518e3a1d48dc3e07cd5fef0e，保留本轮流程门禁修复；当前工作区不再包含 64 位 DMA 或连续区间调度实验。

- 已查明并修复原 1460dca 的 const 指针转换编译错误。
- 新候选 8533022 编译通过后在 007 触发设备地址异常；CANN 实现证实宽视图重复应用 L2 bypass 地址偏移，已在 f07d91d 修正并通过完整正确性/工程/内存。
- f07d91d 固定性能 0/10，大缓存 95.1595 / 94.8100 us；4ba7e22 连续区间对照 6/10，大缓存 93.9696 / 94.0556 us。两项均未达到 75/77 us，运行改动已撤销，证据全部保留。
- 阶段脚本现在自动解析部署目录并校验 manifest/源码哈希；先检查旧证据与前置阶段，再创建日志及原子锁。Smoke 已增加大缓存分支。
- 原 reports/STATUS.json、performance.json、交付 ZIP 保留 c9decf2 的实测数据，未用候选结果覆盖。
- 本轮详情见 [TAKEOVER_20261030.md](TAKEOVER_20261030.md)，结构化记录见 [takeover_20261030.json](../reports/takeover_20261030.json)。
- 末次检查无本任务 worker 或 NPU 进程，未新增服务端口。当前聊天 SSH 长连接保留，20 秒 keepalive；没有将凭据写入项目。

下文是原 2026-10-29 交接快照，其中的“当前 HEAD”“当前阻塞”仅指当时状态。继续任务应优先采用上面的更新和本轮结构化记录。

---

# T5SplitQkvAppendCache 交接文档

更新日期：2026-10-29

## 1. 结论先行

**任务尚未完成，唯一实质阻塞是固定性能目标未全部通过。** 不得把当前状态标成最终验收通过。

- 最佳已完整验证的运行版本：`c9decf212667337d518e3a1d48dc3e07cd5fef0e`
- 对应报告/交付提交：`3da8059b1728aa32475eadbe0b0fbfc9a90fe4ed`
- 当前 HEAD：`1460dcac58e22f52c48f51fa8db312d4a2815f6e`
- 当前 HEAD 不是可用版本：64 位 DMA 候选在 ACLNN 编译阶段失败，`build_full.exit=2`，未执行 NPU 测试。
- 设计文档 PR 已提交并保持开放：<https://github.com/xLLM-AI/xllm/pull/2604>
- 最佳版本正确性、工程和内存全部通过；固定性能仅 5/10 通过。

接续工作先处理 `1460dca` 的首个实际编译错误，或明确放弃该实验并回到 `c9decf2`。不要直接把 HEAD 打包为已验收实现。

## 2. 最佳版本实测状态

运行版本：`c9decf212667337d518e3a1d48dc3e07cd5fef0e`

- 94 条有效输入/入口逐位检查通过。
- 84 条非法输入检查通过。
- 3 类验证器反例通过。
- 13 条工程检查通过。
- 20 条内存记录通过，每条含 20 次释放检查。
- 构建、Smoke、正确性阶段退出码均为 0。
- 性能协议：50 次预热，5 轮 × 200 次，取 wall-time 轮均值中位数。

固定性能结果：

| 用例 | 中位时延 | 上限 | 结果 |
| --- | ---: | ---: | --- |
| 001 FP16 | 27.6494 μs | 28 μs | 通过 |
| 005 FP16 | 28.8226 μs | 28 μs | 失败 |
| 006 FP16 | 29.0565 μs | 29 μs | 失败 |
| 007 FP16 | 94.08875 μs | 75 μs | 失败 |
| 008 FP16 | 27.57765 μs | 29 μs | 通过 |
| 011 BF16 | 26.96165 μs | 28 μs | 通过 |
| 015 BF16 | 28.03855 μs | 28 μs | 失败 |
| 016 BF16 | 27.6397 μs | 29 μs | 通过 |
| 017 BF16 | 94.47925 μs | 77 μs | 失败 |
| 018 BF16 | 28.59245 μs | 29 μs | 通过 |

实际环境：Ascend910_9382、48 AIV / 24 AIC、CANN 9.1.0、驱动 **26.1.1**。任务指定驱动 **25.5.t6.b001** 未实测。用户此前已同意使用当前环境并要求明确披露差异。

## 3. 已做实验，不要无依据重复

下表只比较大缓存 FP16/BF16；小输入存在主机侧波动，应查看对应原始 JSON，不能用单次小输入结果推断内核回退。

| 提交 | 改动 | 大缓存结果（μs） | 结论 |
| --- | --- | --- | --- |
| `912ceee` | 大行独立分块 + 原生属性解析 | 94.393 / 94.855 | 分块无收益，增加微小工作项 |
| `c8101d8` | 96 KiB × 2，192 KiB UB | `GetWorkspaceSize=561002` | UB 配置被拒绝，未启动内核 |
| `e6c66ea` | 80 KiB × 2，160 KiB UB | 96.656 / 96.478 | 比 64 KiB 慢 |
| `aa52f65` | 48 KiB × 3，144 KiB UB | 96.800 / 96.772 | 更深队列无收益 |
| `2f47348` | 大输出 NORMAL L2 | 216.739 / 216.753 | 输出写分配明显有害 |
| `db5fc18` | 大历史输入 DISABLE L2 | 210.355 / 210.191 | 输入缓存命中很重要 |
| `a53373f` | 一次批量 D2D | 94.367 / 94.235 | 与 AIV 基本相同，无收益 |
| `d5fbcc9` | 历史输入 PERSISTENT | 94.508 / 94.900 | 无收益 |
| `68e7422` | SDMA K + AIV Q/V 并行 | 94.658 / 94.565 | 并行无收益 |
| `972872f` | 大输出 PERSISTENT | 215.887 / 215.885 | 与 NORMAL 相近，不采用 |
| `989683d` | AIC K + AIV Q/V 并行 | 94.970 / 94.646 | 24 AIC 无增益，正确性通过 |
| `c9decf2` | 64 KiB × 2，输入 NORMAL，输出 DISABLE | 94.089 / 94.479 | 当前最佳可用配置 |
| `1460dca` | 大对齐路径 uint64_t DMA | 构建失败 | 未上机，先查首个编译错误 |

辅助带宽测量（同机、50/200/5）：

- 两个 FP16 大输出纯写：34.9182 μs，约 3.846 TB/s。
- 两个 FP16 大输入 `sum` 纯读：84.3569 μs，约 1.592 TB/s。
- 默认 `copy_` 连续读写：216.5336 μs。
- 75 μs 对大 case 所需总读写带宽约 3.581 TB/s；最佳版本约 2.854 TB/s。

这些数字说明读路径是重点，但 AIC、SDMA 和更深流水线均未带来收益。不要把“硬件一定不可达”写成已证明结论；指定驱动和不同实现仍未验证。

## 4. 当前编译阻塞

当前提交：`1460dcac58e22f52c48f51fa8db312d4a2815f6e`

变更点：`op_kernel/t5_copy.h` 在大且 32B 对齐的路径构造 `GlobalTensor<uint64_t>`，按 `uint64_t` 发起 `DataCopy`；小 shape 和非对齐路径保留 `uint16_t`。

远端目录：

```text
/workspace/t5_qkv_tasks/t5_qkv_1460dcac58e2
```

已知状态：

- 源码部署成功，134 个文件校验通过。
- `artifacts/validation/build_full.exit = 2`
- 日志末尾是 `ld.lld: cannot open ..._0.o: No such file or directory`，这只是后续链接症状。
- 尚未收集首个实际编译错误；不得直接声称 uint64_t 不支持。
- 没有 Smoke、正确性或性能结果，也没有该候选的证据包。

恢复后先执行只读检查：

```bash
cd /workspace/t5_qkv_tasks/t5_qkv_1460dcac58e2
cat artifacts/validation/build_full.exit
grep -n -B 8 -A 12 -E 'error:|ERROR' artifacts/validation/build_full.log | head -n 200
ps -eo pid,ppid,etimes,args --sort=pid
npu-smi info
```

先找最早的真实编译错误，再修接口或回退。不要重复完整构建来碰运气。

## 5. 本地文件与证据

项目根目录：

```text
C:\Users\wzy85\Documents\ChatGPT\zh\t5_qkv_task
```

重要文件：

- `reports/STATUS.json`：最佳版本状态、性能未达项、驱动差异。
- `reports/performance.json`：最佳版本全部五轮数据。
- `docs/design.md`：实现设计。
- `docs/community_review_draft.md`：社区评审草稿。
- `task_submission.zip`：七件自验证材料。
- `artifacts/t5_qkv_delivery_3da8059.zip`：最佳版本完整交付包。

交付包校验：

```text
SHA256  8da7f61797cd12eaddeaf570300d2ea79ff88832d20ae1974ebe77a8160949f4
文件数  185（含 DELIVERY_MANIFEST.json）
```

最佳版本证据：

```text
归档    .codex-tmp/t5-c9decf2-evidence-20261029/evidence.tar.gz
解包    .codex-tmp/t5-c9decf2-extracted-20261029
SHA256  64ff58d37a4babfe12edac255a08d9fb3e31bf6b9480a3f5bb393043c45ac61f
```

AIC 候选证据：

```text
归档    .codex-tmp/t5-989683d-evidence-20261029/evidence.tar.gz
SHA256  6c27e0a69c22d81e6b317956fcac63ad0ef8f562e198eb354395abf27157b728
```

`.codex-tmp` 位于：

```text
C:\Users\wzy85\Documents\ChatGPT\zh\.codex-tmp
```

其他实验证据按提交短哈希分目录保存，例如 `t5-a53373f-evidence-20261029`、`t5-68e7422-evidence-20261029`。下载归档均按不可信数据隔离，解包使用 `python -I tools/unpack_evidence.py` 并校验 SHA256。

## 6. Git 工作区注意事项

当前分支：`codex/t5-qkv-append-cache`，没有配置远端。

当前 HEAD 后有未提交的阶段脚本路径更新：

- `scripts/collect_evidence.sh`
- `scripts/phase_smoke.sh`
- `scripts/phase_correctness.sh`
- `scripts/phase_performance.sh`
- `scripts/start_optimized_build.sh`

还有若干未跟踪的历史诊断/报告脚本，例如 `scripts/profile_916c7d7.sh`、`reports/performance_916c7d7.json`。不要执行 `git reset --hard`、`git clean` 或批量删除，它们仍需甄别。

如果回退运行代码，只恢复明确路径，保留历史提交和证据，例如：

```bash
git restore --source=c9decf212667337d518e3a1d48dc3e07cd5fef0e -- csrc direct op_kernel
```

这会移除当前工作区的 AIC/并行/uint64 实验代码；这些实验已在各自提交中保留。执行前仍应查看 `git status`。

## 7. 远端与进程安全

- 使用分配的物理设备 1，通过 `ASCEND_RT_VISIBLE_DEVICES=1` 映射为逻辑设备 0。
- 最后检查时设备 0 有其他用户任务，设备 1 空闲。该状态会变化，每次启动前必须重新执行 `ps` 和 `npu-smi info`。
- 不得为释放设备而终止其他用户进程；执行任何 `pkill` 前必须重新核对实时 PID 和完整命令行。
- 跳板令牌会过期，需由用户提供新的 `ssh -J` 命令或令牌。不要把令牌或目标密码写入源码、文档、报告、归档或 Git。
- 本地 Claude Code 曾因系统内存压力多次自动停止持久 SSH 进程。恢复后先查远端阶段退出文件，不要假设任务已停止或已完成。
- 远端构建曾在 SSH 断开后继续完成，因此 `build_full.exit` 和实际日志比连接状态更可靠。

## 8. 标准验证与证据回收顺序

1. 新提交运行 `python tools/archive_source.py --commit HEAD`，保留归档和逐文件清单。
2. 部署到新的 `/workspace/t5_qkv_tasks/t5_qkv_<commit12>`，拒绝覆盖旧目录。
3. 检查 `build_full.exit`，再依次运行 Smoke、正确性/工程/内存、性能。
4. 阶段脚本必须指向当前候选。此前曾因远端脚本仍指向 `t5_qkv_916c7d793f9e` 而在旧目录退出，不能重复这个错误。
5. 每阶段使用独立日志和 `.exit` 文件，启动前检查既有证据，禁止静默覆盖。
6. 性能阶段因固定目标失败而返回 1 时，仍要回收 `performance.json` 和全部日志。
7. 执行 `collect_evidence.sh`，下载 tar.gz 并核对 SHA256，再更新报告和交付材料。

关键路径：

```text
artifacts/validation/build_full.exit
artifacts/validation/smoke_phase.exit
artifacts/validation/correctness_phase.exit
artifacts/validation/performance_phase.exit
artifacts/validation/performance.json
artifacts/binary_manifest.json
```

## 9. 下一步建议

1. 先收集 `1460dca` 最早的真实编译错误，判断 uint64_t DMA 是接口问题还是实现问题。
2. 若不能快速证实该路径有效，回到 `c9decf2`，不要继续叠加未验证改动。
3. 新优化必须有可证伪的假设和独立对照，优先解释为什么纯读只有约 1.59 TB/s，以及 AIC 为什么没有增益。
4. 如需验证任务指定环境，使用驱动 25.5.t6.b001；当前 26.1.1 结果不能冒充指定驱动结果。
5. 只有 10/10 固定性能目标通过，且正确性、工程、内存仍全部通过后，才可写最终验收完成。

## 10. 已发布事项

设计文档 PR：<https://github.com/xLLM-AI/xllm/pull/2604>

该 PR 仅含中英文设计文档和侧边栏，共 3 个文件、287 行新增；文档测试 25/25、Astro 构建 160 页通过。它不包含实现代码，也不构成性能验收或合入承诺。
