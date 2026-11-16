# 2026-11-16 已完成：五进程全部10/10，新九文件包已放桌面

- 固定交付提交：`a09f31fef90fc076e57e2ab4a5e05dc800a45093`，个人仓
  `wangzhao-11a/t5-qkv-append-cache` 分支 `codex/t5-qkv-alignment-revalidation-20261116`。
  已push并使用禁用凭据的Git读取核对公开分支；原分支未改。运行源码仍为a201。
- 桌面新包：`C:\Users\wzy85\Desktop\t5_qkv_submit_a201_stable_20261116_9files.zip`，
  288785字节，精确9个根文件，无嵌套ZIP，CRC/SHA检查通过。
  SHA256 `ab93e819fe8dc62ad118d5a12875812aaecf78a5a2bc9bd20c9f90392117602f`。
- 包含新七件、00提交信息及实测`.run`。三表使用artifact-tool生成/重算/渲染/重开，
  原始日志逐段对照通过。源代码和完整证据由包内固定链接提供。
- `reports/upload_delivery_20261116.json` 保存发布和包校验；旧ZIP和基线均保留。
- SSH session25514最后确认7808.9秒/390心跳仍在线，未关闭；目前没有新的NPU验证任务。
- 本轮预定五个独立固定进程均10/10；007/017最差71.34950/71.21085us。
  不宣称已确认旧八档的对齐根因；不将本次结果移用于上游PR移植提交。

以下为过程快照，原“制作中/已启动”阶段已完成。

---

# 2026-11-16 当前：预定五个独立进程固定10/10全部通过

PID20761已结束，总exit0；原始255文件归档已下载并逐文件SHA/长度验真。
候选a201首次固定10/10，随后五个新进程全部10/10，007/017最差中位数
71.34950/71.21085us，25轮均值最大71.86470/71.37255us，均低于75/77。
完整功能、覆盖、设备及端口清场、前后源码/二进制身份检查均通过。
见 `docs/ACCEPTANCE_20261116.md`、`reports/stability_validation_20261116.json`。

当前在制作新的九文件提交包并准备发布本轮个人仓分支；旧ZIP不覆盖。
实测a201 `.run`已收回，SHA97b1f9e0e271df439ee8913e3fa67ffd970a737462f7b4c0c17b1d8fb980e42e，
内嵌14文件与已测OPP全部匹配。两版Python扩展已收回到artifacts/remote_20261116。
SSH session25514最近6842.8秒/342心跳仍有效，保持连接；没有存续NPU测试。
未运行额外offset ABBA，因为预定稳定性门禁已全部通过；不宣称对齐根因已证明。
后续发布仅针对本次独立工程，不能把上游PR移植版当作已实测版本。

---

# 2026-11-16 候选首次固定 10/10，五独立进程稳定性已启动

候选 a201 首次固定协议和结束身份/清场检查均通过：007=69.5922us，017=70.0743us。
本地原始 `artifacts/remote_20261116/performance_a201_fixed_once.json` SHA
cdd8e8c5bc7c28c65e68c5151b6ad299d6f9664d9ea9da74a52c5e9681c4901b。
这个跨进程结果尚不能将收益归因于对齐改动；与 f526 的本轮74.63/76.67分别记账。

PID **20761** 稳定性流水线已启动，先复用现有 compare_baseline 完成完整coverage，
再直接执行候选已追踪的 `scripts/phase_repeated_performance.sh`：五个新进程、
每个原始10例/50预热/200调用×5轮，首败立即停。禁止重新启动或挑选通过结果。
- 启动脚本 `/tmp/t5_sources_20261116/launch_candidate_stability_v2_20261116.sh`
- SHA f0e0a18409507c310ddfd39a1f005ab9977bf9759eaee493244bd8df2f8e283d
- 外层日志 `/tmp/t5_candidate_stability_20261116.log`
- 总退出码 `/workspace/t5_qkv_tasks/candidate_stability_20261116.exit`
- 各轮 `<a201>/artifacts/validation/repeated_performance/run_N.json/.exit`
- 若失败，下一项考虑 f526/007/run/past-key/offset16 的单次同 backing ABBA，
  检验保持32B对齐的32字节相位变化；不重复已否证的预算/核数/执行器扫描。

---

# 2026-11-16 两版完整功能通过，f526 首次固定 10/10 但接近上限

修正版离线安装和两版 Python binding 全部成功，总 exit0；功能管道 PID15576
也已 exit0。每版公开精度35、扩展150、工程15、内存20、smoke 160次均通过，
结束设备及端口清场验证通过。完整159文件证据已下载逐项验真，归档 SHA
0065e46b5886be15e9e03e7a383a23fa892a1f91c98c0dfbb1a2cc25f9a0fbfc，
见 `reports/functional_validation_20261116.json`。

当前新环境 f526 一次原始固定协议已通过10/10，007=74.62955us，017=76.67090us，
阈值分别75/77us；余量仅0.37045/0.32910us，**不能宣称稳定性达标**。
`artifacts/remote_20261116/performance_f526_fixed_once.json` SHA
aa8b0ceb1103ba29f6ec5469d04f4fcf45527eb60aad735653017eca60d44597。
该运行 performance_phase.exit=0，身份哈希及结束清场均通过。

候选 a201 首次固定协议 PID **19912** 已启动，不得重复启动：
`/workspace/t5_qkv_tasks/t5_qkv_a2013d56db4f/artifacts/validation/performance_phase.log/.exit`，
外层 `/tmp/t5_fixed_a201_20261116.log`。需先取结果，再按新证据选诊断/稳定性检验。
两版跨进程差异不能单独证明对齐根因；候选全对齐源码快路径不变。
当前 SSH session25514；源码 a201 未改变，证据提交95e8edc不是新的运行源码。
旧 c9/f526 和旧交付件均保留，稳定10/10目标尚未完成。

---

# 2026-11-16 离线依赖已传完，修正后私有环境/绑定构建启动

全部 13 个本机官方 wheel 已传输并逐哈希验真，外部 Torch 完整 wheel 已在目标保存。
两版 native smoke 后的 16 个文件各自哈希全部未变，收据
`artifacts/remote_20261116/post_native_smoke_hashes_20261116.json`。

离线 v3 首次检查因手工摘要遗漏内核版本 `.aarch64` 后缀拒绝；未建立 venv 或运行 pip。
失败目录只含 setup.exit=1，已严格检查并原子重命名保留为
`/workspace/t5_qkv_tasks/venv_t5_py312_torch210_20261116_offline_v3_rejected_kernel_metadata`。
修正直接读取原始 `target_platform_exact_20261116.json`（SHA2f7090ce...da36a），
不再手写内核版本。实际 release 为 `5.10.0-216.0.0.115.oe2203sp4.aarch64`。

修正版独占管道 PID **13943** 已启动，不能重复启动：
- 日志 `/tmp/t5_offline_v3_and_bindings_corrected_20261116.log`
- 总退出码 `/workspace/t5_qkv_tasks/offline_v3_and_bindings_corrected_20261116.exit`
- 新环境 `/workspace/t5_qkv_tasks/venv_t5_py312_torch210_20261116_offline_v3`
- 安装成功后顺序构建 f526/a201 Python 绑定；尚未观察最终结果。

功能 wrapper、单次固定 benchmark wrapper 已上传并通过目标 bash-n，尚未执行。
绑定成功后，先由 `launch_functional_pair_20261116.sh` 完成两版 smoke/完整功能；
再按当前环境新证据运行一次 f526 固定协议，不能自动重试失败性能。
session25514 最近已超过 71 分钟、214 次心跳，仍在线。c9/f526/旧包均保留。

---

# 2026-11-16 两版原生 NPU smoke 已通过，离线 Python 依赖传输中

当前 SSH session **25514** 仍有效，已持续超过 51 分钟并收到 155 次心跳；
目标仍为 199.142.52.52 / 248a9b8f1bbd / Ascend910_9382。
f526/a201 的 CPU 实际头文件各 776 项、CANN 原生构建及原生 C++ NPU smoke
均通过。smoke 使用 physical3/runtime selector1：FP16/BF16 bit_mismatches=0，
五项非法参数均拒绝，结束后设备清空且监听端口无变化；这不是完整 35 例或性能验收。
原始摘要已收回 artifacts/remote_20261116/native_smoke_{f526,a201}_summary.json。

原生重建 f526 的 direct.so 与 C++ example 与历史已验收文件逐字节相同；
不能据此归因于原生 ABI/编译器回归。a201 的设备对象不同，具体热路径尚未证明。
实际执行的 smoke 脚本 SHA=3a60d8a1128a27bf2f1ab77a5133de956b788e3b7d10a5dde2959cb57001a53c，
已回收同名本地文件。后编辑的 with_hash_guard_v2.sh 未执行，另存以免混淆。
后续补验原生文件哈希，不为此重复 NPU 测试。

Python 准备 v1 官方下载超时 exit124；v2 镜像 GET403，另一个镜像目标端小 GET 也403，
已停止镜像尝试，两个失败环境及下载片段保留。完整 Torch 官方 wheel 已在目标端校验，
其余官方 wheel 从本机下载并校验后通过现有 SSH 传输；TorchNPU 已收到 SHA 验真 ACK，
NumPy 和其余依赖在队列中。新环境将使用全新后缀 offline_v3，严格 no-index/hash 安装。
现有其他工程 Torch2.8 环境未改动。绑定脚本已上传并验真，尚未执行。

下一步：确认所有上传 ACK → 全部 wheel 复核 → offline_v3 安装 → 两版绑定 →
完整正确性/重复输出/工程/内存 → 当前环境 f526 固定基线及有区分度的性能对照。
新五轮复测原始报告在已搜索本机范围内未找到；新环境实测须与历史证据分别记账。
**固定性能稳定 10/10 尚未完成，没有替换旧交付件。** 下文均为较早的进度快照。

---

# 2026-11-16 原版/候选 CPU 语义与 CANN 原生编译已通过

新授权连回同一248a9b8f1bbd容器，当前长连接session **25514**，双层20秒保活。
PID3738已经结束，总exit=0；f526与a201真实头文件各776项CPU语义全部通过，
两版ACLNN包/direct/C++ example原生构建成功，三份完整JSON已下载并校验。
见 `reports/native_validation_20261116.json`；尚未运行NPU正确性或任何性能测试。

新私有Python环境准备已正常通过审批后启动，PID **7638**（不要重复启动），
脚本 `/tmp/t5_sources_20261116/prepare_private_python.sh`，
日志 `/tmp/t5_prepare_private_python_20261116.log`，
目标 `/workspace/t5_qkv_tasks/venv_t5_py312_torch210_20261116`。
下一步先看setup.exit及metadata_verified.json；确认官方wheel SHA、版本和git5dd8后
再构建两版绑定。现有其他工程torch2.8环境未改。

绑定脚本已本地review并排队上传 `/tmp/t5_sources_20261116/build_binding_20261116.sh`，
当前SHA41115edbb8eea50ae6fa83158c8b2868c3f0263d4cbae7ba38b33510ad335170。
它保留已验证的CANN/Python动态库路径，仅前置新venv及本target库；尚未执行。

本机报告查找已经完成含近期generic文件名的补查：未找到新五次复测原始JSON。
旧提交包只有70.22155/70.2012证据，不能作为本轮原始结果。搜索索引在
artifacts/remote_20261116；需要按当前机器重新建立对照时，与旧验收分开标记。
下面“结果未回收”“未安装调用”是此前断线时的历史快照。

---

# 2026-11-16 新 A3 已部署，后台结果待授权恢复后收取

新授权曾连接 199.142.52.52 / 容器 248a9b8f1bbd，官方 SoC 为 Ascend910_9382，
CANN9.1.0、driver26.1.1。当前映射 card1/chip0=physical2、chip1=physical3，
两个 runtime selector 为0/1；尚未为NPU测试选卡。已见整板无任务，端口见结构化报告。
新机器无原T5目录和本次复测原始报告。已完整验证并新建 c9/f526/a201 三份源码目录，
保留所有原本地基线、历史二进制和交付件。具体SHA/文件数见 reports/remote_preparation_20261116.json。

后台准备 PID **3738** 已启动：CPU两版语义检查通过后才依次编译 f526/a201 原生产物，
不调用NPU。**尚未收回结果，不能宣称CPU语义或CANN编译通过，也不得重新启动。**
- 外层日志：`/tmp/t5_cpu_native_pipeline_20261116.log`
- 总退出码：`/workspace/t5_qkv_tasks/preparation_20261116.exit`
- CPU摘要：`/workspace/t5_qkv_tasks/host_semantics_20261116/summary.json`
- 各源码目录下：`artifacts/validation/native_build.log`、`.exit`、`native_binary_manifest.json`

SSH会话41021最后成功状态1554.2秒、77次心跳；1572秒时失效。复用授权重连99632被
跳板明确拒绝 platform authorization denied。停止重试，已请求刷新同容器授权。
当前没有SSH长连接；双层20秒保活和远端20秒心跳不能阻止平台撤销授权。

默认Python3.12.13缺torch/torch_npu/ml_dtypes；现有其他工程venv是torch2.8，未改动。
已准备全新任务私有Python3.12/Torch2.10环境脚本和官方wheel校验。该调用因自动审批服务断流
未执行，文件未上传、环境未安装；之后SSH也断开。重连后先检查路径再正常执行。

用户认为复测报告应在本机，已查78个T5目录和Desktop/Downloads/Documents相关文件。
目前只找到旧f526性能70.22155/70.2012与本轮反馈摘要，没有新五次原始JSON。
搜索索引保存在artifacts/remote_20261116，正在补查近期generic文件名；不把旧包当新证据。

恢复后的第一步是取回已有任务状态及日志，然后继续环境/正确性验证；任何性能对照都
需源码/二进制身份明确、设备清场，并与原历史验收分别记账。原固定性能稳定10/10目标未完成。

---

# 2026-11-16 新机器连接停在跳板认证前

用户已授权 199.142.52.52，要求保持 SSH 长连接、先收复测原始证据、保留 c9/f526712。
Paramiko 与系统 OpenSSH 均在 113.47.8.48:2234 收到远端 SSH banner 前被关闭；
TCP 建立，但未进入认证、未连接目标机。不能据此断言令牌失效或目标型号。
两种客户端已给出同类证据，停止重试，等待平台状态恢复或新的连接信息。
本地失败辅助进程已按精确身份清理，无存续 SSH 连接，没有远端读写或设备操作。

连接记录见 `reports/ssh_connection_20261116.json`，未保存凭据。
候选源码仍为 a2013d56db4ff8367160b157335d2ff670aad411，源码归档与 SHA 清单
已准备；恢复后先核对环境及取回已有五次/五轮原始结果，不能直接重跑性能。
交互式长期会话须使用 `exec_command tty=true`；非交互会话没有可复用的 stdin。

---

# 2026-11-16 离线开发候选已准备，机器稍后提供

用户要求先完成开发修改，再提供机器。当前候选仅修改 `op_kernel/t5_copy.h` 的
读/写 DMA 对齐条件；上机脚本及验证边界见 [候选说明](CANDIDATE_20261116.md)。
冻结 reference 与 CPU 地址模型通过，原内核和候选内核的真实头文件主机编译通过。
Windows 应用控制拒绝执行测试 EXE，776 个主机语义场景尚未运行；CANN 编译、
NPU 正确性/工程/内存及重复性能均待上机。没有修改原交付包或发布性能通过声明。

下一次先读取已有复测原始证据并核对设备，再按证据运行一个 ABBA 区分实验。
正式验收通过后，新增阶段要求五个独立原始十例进程全部通过；首个失败即停。
下面“无内核修改”的段落记录的是开始排查时的历史状态。

---

# 2026-11-16 性能复测问题重新打开

用户反馈 5 轮中 3 轮失败，大缓存 007/017 最差 75.11/78.10 μs，精度、工程和内存通过。
这些是待收取原始数据的用户摘要；“同一 .so 八个档位由对齐路径切换导致”尚待地址与
实际加载内核证据确认。原 f526712 单次 10/10 是历史结果，不能替代重复验收稳定性。

本次工作区为 `t5_qkv_revalidation_20261116`，分支 `codex/t5-qkv-alignment-revalidation-20261116`，
基于 7e88ff5；11 个运行源码文件仍与 f526712 一致，尚无候选内核改动或本轮 NPU 执行。
原 `t5_qkv_task`、c9/f526712、旧二进制和交付 ZIP 全部保留。
旧 SSH 会话不可用，当前需 Ascend910_9382/A3 的新连接及本次复测报告路径。
具体证据、排除项和后续区分实验见 [本轮接续](REVALIDATION_20261116.md)。

上游实现草稿 PR #2656 已在 2026-11-03 创建，移植代码 4649db2 尚未进行 NPU 复测；
它与原实测 f526712 是不同提交。以下均为此前历史记录。

---

# 2026-11-03 个人实现仓已公开发布

用户明确批准公开工程及完整历史后，已创建 `https://github.com/wangzhao-11a/t5-qkv-append-cache` 并推送 `codex/t5-qkv-append-cache`；匿名访问核实 216 个文件及 874f2bb/f526712/c9decf2 提交。固定交付源码 `874f2bbbb385bc032d004735ae524244401a29ce`，算子目录为仓库根目录 `.`，链接汇总见 `SUBMISSION_LINKS.md`。运行源码和测试证据未变。上游实现 PR、最新设计同步和社区评审仍待完成。下面“未发布”的记录为发布前审计快照。

---

# 2026-11-03 交付完整性复核

本轮仅修订交付材料：设计更新到 f526712、社区草稿撤去旧 5/10 状态、NumPy 摘要按实际阶段证据改为 2.2.6，新增交付逐项清单和离线审计工具。运行实现与 10/10 证据不变。任务书要求的个人实现仓地址、实现 PR 及设计评审仍未完成，不能将本地材料齐全解释为全部交付流程结束。详见 docs/DELIVERY_REVIEW_20261103.md 与 reports/publication_status_20261103.json。旧 ZIP 和 c9 基线保留。

---

# 2026-11-01 最终状态：固定性能 10/10 通过

交付材料已按用户再次提供的官方 task_submission.zip 直接套用原始三份 Excel 模板，四步复现说明和七件文件名已对齐；目录为 outputs/01a18867-1217-7502-95aa-e2b665f9a437/template_aligned/task_submission。模板来源与哈希见 reports/template_alignment_20261101.json，数值复核见 reports/workbook_template_verification_20261101.json。此次仅调整交付材料，运行源码与 10/10 原始证据不变，未重跑设备测试。无现场截图的字段明确留空，独立对照结果不与固定成绩混算。

运行源码 f52671207769bf5f334972c997743eb6aa6f91b3 已完整通过。大缓存 70.22155 / 70.20120 μs，精度、工程、内存通过。完整证据 65 项已下载校验；当前运行代码保留，无后续候选待跑。详见 [最终验收](ACCEPTANCE_20261101.md) 和 [结构化状态](../reports/STATUS_latest.json)。SSH 40068 保留；PID 365687 已结束，总退出码 0，设备与端口清场已核对。下方全部为历史快照，不再代表当前待办。

---

# 2026-11-01 当前接续（优先于下方旧快照）

正在执行对照 22：f52671207769bf5f334972c997743eb6aa6f91b3，后台 PID 365687，根目录 /workspace/t5_qkv_tasks/t5_qkv_f52671207769；启动脚本 /tmp/t5_launch_aligned_fragments_20261101.sh，外层日志同名 .log。191 文件部署校验及 19 项 Linux 流程检查通过，构建前控制时效检查通过（925.5 秒，门限 1800 秒）。尚无最终 NPU/性能结果，接续先读 PID 与 .exit，勿重复启动。SSH 40068 保持。原 b661 当前窗口控制完整包已导入 .codex-tmp/t5-suffix-control-extracted-20261101，10 个归档成员及 receipt 中逐文件 SHA 核对通过。

最新状态：a980533（对照 21）全正确性/工程/内存通过，固定 8/10，大缓存 99.45625/99.60405 us，已撤销。63 文件证据已导入 .codex-tmp/t5-a980533-extracted-20261101，SHA256 9514679827c0e259a0bed2a2843c48f9f752de3585164c99fb9305d334fb290e。随后原 b661926 在当前窗口作一次时间变化控制（2026-11-01 19:21 北京时间），完整十例均执行，仍 8/10，大缓存 85.73060/85.98455 us；source/binary/live extension 校验通过。控制阶段 suffix_current_window_control_20261101 位于 a980 根目录，exit=0，PID 356562 已结束；这个 0 只代表完整控制结束，不代表性能全过。控制 JSON 已下载，压缩包 /tmp/t5_suffix_control_20261101.tar.gz 和 receipt 已生成（SHA ef03bcc1c45c2cb0ca947cfdd61e987ab22927214b4c7957d77470eaf6c434ff），尚需下载完整包。原 9/10 与循环拆分测试隔约 5.5 小时，不把全部差异归因于代码。会话 40068 正常。

本地对照 22 已准备：恢复 b661926，仅为大缓存、D/tile 均为 16 倍数且全部实际 GM 视图基址 32B 对齐时，初始化一次 alignedFragments_，跳过 Copy 中重复对齐判断；其他输入仍用原逐片段判断。CPU 374 个适用形状、2,864,106 个片段的地址/长度对齐检查通过。新增控制记录时效门禁在整板空闲检查后执行，要求同一源码、完整十例及 30 分钟以内记录；6 项 CPU 门禁通过。尚未部署本候选，不能称为已验证优化。

最新：对照 20（36bb83a）已结束，PID 338848 不在；全正确性/工程/内存通过，固定性能 8/10，大缓存 84.76055/86.75465 us。63 文件完整证据已导入 .codex-tmp/t5-36bb83a-extracted-20261101，SHA256 6a9ccd27d88154a24f1376bd4eed18e6c9ceb45776cb8c6229874558b90cd5e1。已撤销循环拆分，当前最好仍是 b661926 的 9/10。本地对照 21 仅去除缓存后缀判断中冗余下界比较；1130 有效形状、1,722,325 个 tile 的成员资格检查通过。尚未部署/实测，仍要求构建后设备 .text 必须变化才继续 NPU。会话 40068 保留。

新授权会话 40068 已连回同一 e60fcee5f79f 容器/卡 3/chip 1，整板当前空闲。b661926 流水线已结束（PID 113858 不在）：完整正确性、工程、内存通过，固定性能 **9/10**。FP16 大例 75.13725 us，仍比 75 us 高 0.13725 us；BF16 75.85725 us，低于 77 us。证据 SHA256 b2476bb037cf35f9e01ca0a97fb54aeab7eef2de855d95f9d948e01522dd7031，已下载校验至 .codex-tmp/t5-b661926-extracted-20261101；独立性能报告 reports/performance_b661926_container_e60_20261101.json。保留此候选及 c9/1bba 基线，不重跑碰门槛。旧 88471 后来返回所有待上传文件及心跳，原因仍未证明；已在 40068 正常后优雅关闭重复连接。设备映射 7 项和 Linux 阶段门禁 6 项均通过，实际解析 card=3/chip=1/physical=7。

对照 20 已启动：36bb83a94f330811391a61b2f9d9090ce7a8743b，后台 PID 338848，根目录 /workspace/t5_qkv_tasks/t5_qkv_36bb83a94f33。仅将每核心 Q/K/V 分类循环拆成三段，沿用同一 work 游标和步长，保持每核心的原 tile 序列。K 缓存后缀、字节预算、队列、主机分配和复用均不改。源包 SHA256 8d04177f710df99bbd1b74ef09c3ca34f8fc23c114f0529aa80b64bd244d0d7e。启动脚本 /tmp/t5_launch_loop_split_20261101.sh 在 build 后比较两 dtype 的 .text，与 b661 相同就停止，禁止无区别重复跑分。功能 selected 门禁使用已验证物理 7 映射，性能仍需整板空闲。尚无新 NPU 结果；接续先读阶段状态，勿重复启动，不得把 b661 的 9/10 当作新改动结果。

最新连接状态：88471 在第二个小文件 SFTP 上传时持续无响应，旧进程/TCP 尚在，不能断言远端任务已停止。保留旧会话，用同令牌新建只读连接 64770，被跳板明确拒绝 platform authorization denied / Administratively prohibited，64770 已退出。已请求刷新原 199.103.53.243 授权。用户已回复“我安排整板空闲窗口”，但尚未提供新令牌或确认窗口开始。恢复后先核对容器和 PID 113858、correctness_phase/performance_phase/collect_evidence 的日志及 .exit，禁止重跑已有阶段。最后可读状态为 correctness_phase 的整板等待第 43 次、chip 0 另一任务占用；构建和 smoke 已通过。当前固定验收仍为 8/10，新候选没有已取回的性能结果。

本地新增流程修复：selected 门禁从官方 npu-smi info -m 解析 runtime selector 与已确认物理 ID 的唯一对应，代替旧卡 0/chip 1 硬编码；当前只读映射确认 selector=1 对应 card=3/chip=1/physical=7。7 项离线检查通过，Linux 实测尚未完成。文件已尝试上传 /tmp/t5_device_mapping_guard_20261101；仅 resolve_device_mapping.py 上传成功，后续 test_device_mapping.py 上传无返回，其余上传请求还在旧会话队列中。当前已部署候选未修改。remote_session 新增上传父目录准备、60 秒 SFTP 请求超时（仅重建 SFTP 通道）与 25 秒跳板 TCP 连接超时，6 项离线传输门禁通过；旧 88471 仍运行旧代码，不具备这些新门禁。

正在执行：候选 b661926b6e5c833abeb1fa09d453f8ca89191abf 已部署至 /workspace/t5_qkv_tasks/t5_qkv_b661926b6e5c，源包 SHA256 702c1259fa55ccb33d8866e585c3dacc6333d6c66c01872e698ac8bfb8d14813，182 文件校验和 6 项流程回归通过，构建成功。smoke_phase 已通过（exit=0）；流水线 PID 113858 进入 correctness_phase，等待整板连续空闲，尚无候选固定性能结果。chip 0 最近存在其他任务 PID 136939；已异步请求用户安排整板空闲窗口，未终止其他进程。当前 SSH 88471 仍可复用，保持连接，接续先读取此 PID/各 .exit，禁止重复启动。当前 SDK 队列源码已证明两个缓冲会轮转，不再依据“第二缓冲未使用”假设改写流水线；见 queue_rotation_audit_20261101.json。

trace 完整证据已导入 .codex-tmp/t5-trace-e60-extracted-20261101，当前容器控制完整证据也已导入 .codex-tmp/t5-retained-e60-extracted-20261101，后者 SHA256 7ede7130a841ac06820365fdeff8f68f791a3faf25f2b24a8c18831c44a79ca0。collector v1 因手抄 shell-script hash 多一位被门禁拦下、未创建 archive；v2 改为从本地原文件自动生成 JSON 校验清单后成功。incident 已按要求入 memories。

最新：SSH 会话 88471 已连接原 199.103.53.243 / e60fcee5f79f，双层 keepalive 与心跳持续；已观察存活超过 13 分钟，反证“必定 5 分钟断开”的猜测。完整 trace 压缩证据已回收并校验（SHA256 027382878a360a5038e9d759eb920812767b4bcd30cd7f35638c76dfc5fdc01c），实际注册/启动的两内核均来自 8303bbb，48 AIV、workspace=0。无需重复 trace 或继续错载假设。

当前容器原 1bba 控制已结束：smoke 8×20 通过，初次 post-check 被其他 chip 0 PID 90835 阻断（exit=1 保留）；独立 smoke_clearance 成功后完成第一次固定性能，8/10，大例 103.48145/103.71650 us。性能 JSON 已下载；控制证据 collector 已准备，接续检查归档/导入状态。旧 wrapper PID 88492 与恢复 wrapper PID 100805 均已结束。下一候选为对照 19：保持原缓存字节预算，仅将 K 前缀换为末尾完整 tile；CPU 1130 形状预算边界和原地址模型通过，尚待 NPU 验证。详见优化记录。

随后用户提供 179.68.53.144；只读核对仍为 Ascend950PR（容器 7f778c5b6138、driver 25.7.rc1.10），未找到原两份任务目录。没有上传或执行 kernel，已关闭会话 97404，并请求原 199.103.53.243 的 910_9382 授权；若用户有意迁移，需要其明确说明。见 reports/target_mismatch_950pr_20261101.json。原 910 验收与待回收证据状态不变。

最新接续：用户刷新授权后，会话 97654 成功连接同地址，容器已变为 e60fcee5f79f；卡 3/chip 1、物理 7、PCIe 地址及 VDie 与 05d447771751 时一致，原源码、构建和私有 OPP 仍在。已执行一次 trace_kernel_8303bbb_20261101（PID 72141），两种大用例正确性通过、阶段 exit=0；原二进制清单、live 扩展和两份设备 .o 的 metadata SHA256 均核对通过。报告 JSON 已下载，见 reports/kernel_load_trace_20261101.json；原始日志仅下载了 35,291,136 字节的 .part，必须保留。已有片段列出的 T5 候选 binPath 正确，但完整设备加载记录尚未审查，不能把“候选路径正确”扩大为所有加载环节均已证明。

97654 在 300.8 秒、收到 14 次心跳后于 SFTP 下载期间断开；同令牌重连 60443 被跳板明确拒绝，已请求延长授权。两者均已退出，当前没有可复用 SSH 会话。断开原因未证明；不能把 300 秒观察直接宣称为平台固定超时。尚未运行新容器的性能测试。

恢复授权后先确认容器/进程/设备状态，不要重跑 trace。使用 artifacts/optimization_20261030/collect_trace_e60_20261101.py 压缩已有阶段证据，下载 /tmp/t5_trace_e60_20261101.receipt.json 和 .tar.gz，再用 tools/unpack_evidence.py 的 @receipt 校验导入。collector 尚未上传/执行；若 /tmp 原 trace 脚本丢失，先补传本地保留的原字节（collector 校验两个已知 SHA256）。新 remote_session.py 在传输前拒绝大于 8 MiB 的原始日志并拒绝覆盖已有 .part，prefetch 限 64，3 项离线检查通过。完整 trace 审查后，再运行 control_retained_e60_20261101.sh 的 smoke/performance 两阶段（均尚未启动、未完成远端 bash -n）；它复用原控制流程，只验证容器变化后原 1bba 二进制表现。若容器再次变化，该脚本会拒绝运行，须先重新核对。以上均不是新的优化候选。

目标仍为 Ascend910_9382，地址 199.103.53.243，容器 05d447771751。SSH 会话 32184 曾保持超过 74 分钟，后在本地会话中断后不可用；2026-11-01 接续时报告 Unknown process id。沙箱首先阻止网络套接字，经网络权限审批后尝试重连，跳板明确拒绝 platform authorization denied / Administratively prohibited；新会话 73223 已退出，已请求用户刷新授权。连接失效原因尚未确定，不把平台重连拒绝当作原连接断开的原因。上次确认分配为物理 6、7，runtime 可见编号 1 对应物理 7/logical 0。新分配控制组已完成：c9 为 7/10，大缓存 100.29210/103.59585 us；1bba 为 8/10，大缓存 84.80070/84.38320 us。完整证据已归档，不要重复启动已结束的控制流水线。

70a03ad 和 1ecd80e 均全正确性/工程/内存通过、固定性能 8/10，已撤销。900fba8 全正确性通过，但目标 CANN 分支不实现独立 PERSISTENT 策略，已在性能前撤销；旧 EXIT trap 误写 0 不代表完整验收。ea12acd 交换输出分配顺序也全正确性通过、固定 8/10，大缓存 117.21515/117.34680 us；同进程 ABBA 在内核代码相同、K/V 地址实际交换的前提下未见实质收益，已撤销。所有证据已下载校验，PID 188524/198391 已结束。

对照 18（8303bbb）已完成：全部正确性、工程、内存通过，包括新增 [15,17,2048,63]、storage_offset=1 的两 dtype / 两入口共 4 项精度检查。固定性能仍为 8/10，大缓存 118.32280/118.36085 us。完整证据已下载校验，SHA256 dd9072afc784634ec33710835677781011e75262a675b86bb44579eb6c6c3392；本地内核已恢复 1bba，保留新增测试。PID 222400 已结束，上次 npu-smi 确认整板空闲。

下一步先用 CANN 官方 debug 日志核对实际设备内核文件选择：已有宿主库映射核对通过，但不能据此直接断定设备 .o 的加载路径。8303bbb 的元数据含 sha256，已准备 trace_loaded_kernel_20261101.py/.sh（artifacts/optimization_20261030/）核对文件 hash、每种大用例 dtype 各执行一次正确性，禁止把开启日志的结果当性能数据。脚本尚未启动；恢复授权后先检查远端状态和上传文件，避免重复。当前没有设备内核加载错误的证据，不得宣称它是根因。不要重复已完成的分配顺序、读写覆盖转移或 PERSISTENT 实验。

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
