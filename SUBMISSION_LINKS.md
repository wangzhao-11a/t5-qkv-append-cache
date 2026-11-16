# 个人代码仓提交信息

## 2026-11-16 重复验收版本

- 仓库：[wangzhao-11a/t5-qkv-append-cache](https://github.com/wangzhao-11a/t5-qkv-append-cache)
- 分支：`codex/t5-qkv-alignment-revalidation-20261116`
- 算子目录：仓库根目录 `.`，包括 `op_kernel/`、`op_host/`、`common/`、`direct/`、`csrc/`、`examples/` 与 Python 封装。
- 固定实测运行提交：[a2013d56db4ff8367160b157335d2ff670aad411](https://github.com/wangzhao-11a/t5-qkv-append-cache/commit/a2013d56db4ff8367160b157335d2ff670aad411)
- 固定交付提交（源码和报告）：[a09f31fef90fc076e57e2ab4a5e05dc800a45093](https://github.com/wangzhao-11a/t5-qkv-append-cache/commit/a09f31fef90fc076e57e2ab4a5e05dc800a45093)，已推送并通过匿名Git访问核对。
- 本轮完整记录：[验收说明](docs/ACCEPTANCE_20261116.md)、[五次独立固定测试](reports/stability_validation_20261116.json)、[原始证据](reports/accepted_a201_20261116/)。包含交付材料的固定提交链接见新九文件包的 `00_submission_info.md`。
- `task_submission/` 与 `task_submission.zip` 为本轮七件；原目录七件已保留在 `evidence/baseline_c9decf2/task_submission/`。新九文件外层包一次上传，包含七件、提交信息和实测`.run`。
- 本轮独立工程的五个新进程均固定10/10；不能据此声称上游PR移植版已通过上板验收。c9/f526与旧ZIP保持保留。

## 2026-11-03 历史发布记录

2026-11-03 经用户明确授权公开发布，已通过匿名 GitHub REST 核实仓库、分支、固定提交和全部 216 个已跟踪文件。

| 字段 | 提交内容 |
|---|---|
| 个人代码仓 | [https://github.com/wangzhao-11a/t5-qkv-append-cache](https://github.com/wangzhao-11a/t5-qkv-append-cache) |
| 分支 | [codex/t5-qkv-append-cache](https://github.com/wangzhao-11a/t5-qkv-append-cache/tree/codex/t5-qkv-append-cache) |
| 算子目录 | [仓库根目录 `.`（固定提交）](https://github.com/wangzhao-11a/t5-qkv-append-cache/tree/874f2bbbb385bc032d004735ae524244401a29ce) |
| 固定交付源码 commit | [874f2bbbb385bc032d004735ae524244401a29ce](https://github.com/wangzhao-11a/t5-qkv-append-cache/commit/874f2bbbb385bc032d004735ae524244401a29ce) |
| 实际 NPU 验收运行 commit | [f52671207769bf5f334972c997743eb6aa6f91b3](https://github.com/wangzhao-11a/t5-qkv-append-cache/commit/f52671207769bf5f334972c997743eb6aa6f91b3) |
| 已保留基线 | [c9decf2](https://github.com/wangzhao-11a/t5-qkv-append-cache/commit/c9decf212667337d518e3a1d48dc3e07cd5fef0e) |

固定交付源码 874f2bb 与实测 f526712 的运行源码相同，新增内容为验收报告、设计说明和交付审计。后续发布信息提交不改变该固定快照或运行源码。目录中的 `op_kernel/`、`op_host/`、`common/`、`direct/`、`csrc/`、`examples/`、`solution.py`、`setup.py` 和 `op_project.json` 共同构成算子工程。

本仓保留原开发历史。下述记录及 `reports/STATUS.json` 为历史基线；2026-11-03当时的验收 JSON 为 `reports/accepted_f526712/`，模板七件及实测安装包位于当时的完整交付 ZIP。历史复现入口见 `docs/SELF_VALIDATION_20261101.md`，运行结果与环境边界见 `docs/ACCEPTANCE_20261101.md`。

上游 [实现 PR #2656](https://github.com/xLLM-AI/xllm/pull/2656) 已于 2026-11-03 提交，当前为 **Draft，未合入**。实现分支为 `wangzhao-11a/xllm:codex/t5-qkv-append-cache-implementation`，固定提交为 [4649db26897d128389140138e1821d14aa5fb5e0](https://github.com/wangzhao-11a/xllm/commit/4649db26897d128389140138e1821d14aa5fb5e0)，目录为 `xllm/core/kernels/npu/xllm_ops/t5_split_qkv_append_cache/`。移植代码通过本地静态、CPU 模型和提交钩子检查，尚未重新进行 CANN 编译与 NPU 验证；原 f526712 的 10/10 结果不能作为该移植提交的验收结果。

上游 [设计 PR #2604](https://github.com/xLLM-AI/xllm/pull/2604) 仍待同步最新文档及正式评审。

上传平台如提示解压文件数超限，请使用桌面 `task_submission_f526712_7files.zip`（7 份模板报告，43,463 字节）；如需另附安装包，使用 `t5_qkv_installer.zip`（1 个 `.run`）。七件报告包不是完整工程包，源码与完整证据仍由上面的固定仓库链接和已保留的完整交付包提供。平台是否接受拆分包尚待实际上传验证。
