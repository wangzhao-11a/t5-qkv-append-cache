# 2026-10-30 后续优化进展（优先于下方旧快照）

用户目标仍是固定性能 10/10，尚未完成。c9decf2 基线、原 reports/STATUS.json、performance.json 和交付 ZIP 均保留。

- 新证据确认设备 L2 为 192 MiB。仅让部分输出进入 L2 的 34829e0 候选，两个大缓存降至 76.5275 / 79.2032 us，较基线 94.08875 / 94.47925 us 明显改善，仍未过 75/77 us。
- 176 MiB 总工作集预算时输入读 miss 约 6.5%；增到 184 MiB 时约 20.8%，并退化至 86.88145 / 89.0899 us。160 MiB、PERSISTENT 输入和 24 核也未达到目标；详见 [OPTIMIZATION_20261030.md](OPTIMIZATION_20261030.md) 与 [结构化证据](../reports/optimization_20261030.json)。
- 刷新授权后已读回 159b181：构建、Smoke、正确性/工程/内存通过，固定性能 8/10；007/017 为 87.1103 / 87.2277 us，均分 K/V 前缀更慢，已撤销。后台流水线已结束，不要重复启动。
- 当前运行代码为 c09d875159970d0a2f287ecbb46a219baca326b4：恢复 176 MiB K 前缀，仅交错执行 K/V tile。CPU 检查通过；精确提交归档 `artifacts/source_c09d87515997.tar` 与 manifest 已生成。上传时连接已关闭，部署和设备验证尚未开始。
- 刷新后的 SSH 曾成功连接并下载证据，之后再度断开；同令牌重连又被跳板以 `platform authorization denied / Administratively prohibited` 拒绝。已请求新授权。下次连接先检查 `/tmp/t5_source_c09d87515997.tar` 是否残留，核对哈希后再部署，不要视作已经上传成功。
- 双层 20 秒 transport keepalive 未防止本次断线，原始断线原因尚未查明。客户端新增持续远端心跳会话及连接层状态/存活时长记录，效果待验证；上传改为临时文件、远端逐字节 SHA256 校验后发布，遇到不同内容旧文件拒绝覆盖。
- 新的七组完整证据均已下载、校验与隔离解包。导入器支持 `@collector.log` 直接解析原始 SHA256；Windows 目录 rename 拒绝时，新目录复制后逐文件复验，保留暂存证据。相关事故和机械门禁已记入 memories。

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
