# 个人代码仓提交信息

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

本仓保留原开发历史。根目录旧 `task_submission/` 和原 `reports/STATUS.json` 是 c9 基线，按 README 标注保留；最新验收 JSON 为 `reports/accepted_f526712/`，最新模板七件及实测安装包位于配套完整交付 ZIP。正式复现入口见 `docs/SELF_VALIDATION_20261101.md`，运行结果与环境边界见 `docs/ACCEPTANCE_20261101.md`。

上游 [设计 PR #2604](https://github.com/xLLM-AI/xllm/pull/2604) 仍待同步最新文档及正式评审；上游实现 PR 尚未提交。个人仓发布不代表上游实现 PR 已创建或合入。
