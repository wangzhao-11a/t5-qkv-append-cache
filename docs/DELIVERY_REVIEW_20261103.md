# 2026-11-03 任务书交付复核

结论：本次修订后的本地工程交付材料齐备，含完整源码和 `.run` 安装包；个人实现仓已发布并经匿名访问验证；上游实现 PR 和社区评审尚未完成，不能称全部交付流程已结束。运行实现仍为 `f52671207769bf5f334972c997743eb6aa6f91b3`，没有改动内核、重编二进制或重跑 NPU。

## 对照依据

- 冻结任务书：`reference/T5QKV拆分与缓存追加算子任务书.md` 第 2、3、4、5 节，SHA256 `e65bf0cc08fcb170bf9b15caac0922fa3cde539f4a58c23722c15fe3bdb7ca57`。
- 原包 `reference/README.md`、`case.json`、`coverage_requirements.json`、`performance_targets.json` 和公开检查器。
- 用户提供的官方七件模板：`https://cann-op.obs.cn-north-4.myhuaweicloud.com/task_submission.zip`；包内 `evidence/template/task_submission.zip`，SHA256 `609b502f03a090009ec8649bf85ff4988ff8ae88d4c1772b5eee20bad518420b`。
- 前一交付包 `t5_qkv_delivery_fcf36e2.zip` 保留，SHA256 `586e91f23735d71cad0fc8278e8f20afc71166b0c0922714d7566f756cb03d85`。

## 逐项清单（路径相对于解压后的 t5_qkv_task/）

| 任务书要求 | 交付位置及核查内容 | 状态 |
|---|---|---|
| 4.1 算子设计：算法、地址推导、分核、片上缓冲、工作区、接口 | `docs/design.md`；已对照 f526712 源码补充 K 后缀缓存、对齐条件前移及 executor 复用，保留数值/地址、128 KiB UB、workspace=0、stream 与生命周期说明 | 本地已齐 |
| 4.1 正式社区设计评审 | 设计 PR #2604 已提交；旧版文档尚未同步，正式 reviews 列表为空，未合入 | 待跟进 |
| 4.2 公开用例、独立标杆、验证器 | `reference/case.json`（35 例）、`golden.py`、`generate_data.py`、`verify.py`；原字节及 SHA256 保持 | 已齐 |
| 4.2 扩展及工程测试 | `tests/npu_suite.py`、`tests/compare_baseline.py`、`examples/aclnn_example.cpp`、`tools/check_coverage.py`；12 个额外输入×两入口、28 类非法输入×三入口、3 类反例、双 stream、元数据拒绝、生命周期、连续追加、内存回收 | 已齐，原始记录离线复核 |
| 4.2 复现步骤 | `task_submission/1 自验证步骤说明.md`、`docs/SELF_VALIDATION_20261101.md`，含构建、样例、功能及性能四步；保留实际启动脚本 | 已齐；命令中的原环境路径须在新主机对应调整 |
| 4.3 官方七件及同名 ZIP | `task_submission/` 下精确七个文件，`task_submission.zip` 内同名七件逐字节一致 | 已齐 |
| 4.3 精度、性能、内存真实数据和原始日志 | 3 份 XLSX、3 份日志；`reports/accepted_f526712/` 和 `evidence/accepted/`；固定性能全部五轮及设备事件时间，同机基线对照另附 | 已齐；不混算不同进程 |
| 4.3 环境和源码指纹 | `reports/STATUS_latest.json`、`evidence/tested/reports/environment_*_phase.json`、`DELIVERY_MANIFEST.json`、`artifacts/source_f52671207769.tar` 及清单、二进制清单和 ldd/readelf | 已齐，已修正 NumPy 摘要 |
| 4.4 完整 ACLNN 工程 | `op_kernel/`、`op_host/`、`common/`、`op_project.json`、`scripts/build.sh`，msopgen 生成可构建工程 | 已齐 |
| 4.4 私有安装脚本和 .run | `scripts/build.sh`、`artifacts/custom_opp_openEuler_aarch64.run`，包内含 install.sh；不覆盖系统 CANN | 已齐，安装包及内嵌 payload 哈希通过 |
| 4.4 两阶段 API | .run 内 `packages/vendors/t5qkv/op_api/include/aclnn_t5_split_qkv_append_cache.h` 及 `op_api/lib/libcust_opapi.so`；包含 GetWorkspaceSize 和执行函数 | 已齐，未运行安装器即可核实 |
| 4.4 独立 C++ 样例、框架封装、直调 | `examples/`、`solution.py`、`csrc/torch_binding.cpp`、`setup.py`、`direct/`；实测二进制在 `artifacts/binaries/` | 已齐 |
| 4.4 个人实现仓地址、分支、算子目录和固定 commit | 个人仓 `https://github.com/wangzhao-11a/t5-qkv-append-cache`，分支 `codex/t5-qkv-append-cache`，算子目录为仓库根目录 `.`，固定交付提交 `874f2bbbb385bc032d004735ae524244401a29ce`，实测运行提交 f526712；详见 `SUBMISSION_LINKS.md` | 已公开发布并验证 |
| 第 5 节实现 PR 申请合入 | 目标 `xLLM-AI/xllm/xllm/core/kernels/npu/xllm_ops`；现有 #2604 只有设计文件 | **实现 PR 尚未提交** |

## 本轮修订

1. 旧 `docs/design.md` 停留在 c9 附近的 L2 绕过方案，未描述最终实现；已按源码补齐。
2. 旧 `docs/community_review_draft.md` 仍把 c9 的 5/10 写成当前结果；已更新为本地待发布草稿，并明确没有同步到 GitHub。
3. `reports/STATUS_latest.json` 原 NumPy 1.26.4 与实际阶段证据不符。correctness/performance/before/final 四份快照均为 2.2.6，现按阶段原始证据修正；原日志不改。
4. 增加 `reports/publication_status_20261103.json`，把实现仓、分支、目录、commit 及发布缺项集中记录；不将设计仓地址伪装成实现仓地址。
5. 增加 `tools/audit_delivery.py`：校验 ZIP/全文件 SHA256、七件一致性、源码/二进制溯源、.run 两阶段 API、原始测试覆盖和环境摘要一致性。它只做离线审计，外部流程未完时明确返回 local_materials_complete_external_publication_pending。

## 必须保留的边界

- 实际驱动 26.1.1 为用户接受的环境差异，题目指定 25.5.t6.b001 未测试；不能声明严格指定环境已通过。
- 任务书 3.3 的“比值”文字与固定微秒表存在矛盾。按同包 README、performance_targets.json 和原检查器执行固定门槛 10/10；另附同机 views/concat 配对数据，不自行编造比值阈值。
- 模板示例截图已移除，无现场截图字段留空，提供原始日志；模板基线内存字段没有实测数据，不虚填。它们不是任务书列明的独立交付件。
- 原包 SHA256SUMS 对任务书的文件名/哈希有一条原生不一致，导入后的 12 份 reference 字节未变；保留原问题记录。
- 原 c9 基线、旧报告和旧交付包保留；本轮只修订交付说明、元数据和离线核查工具。

本地校验通过本身不代表社区批准或实现 PR 合入。个人仓的公开访问和固定提交已单独核实，证据见 `reports/publication_verification_20261103.json`；完整发布状态见 `reports/publication_status_20261103.json`。
