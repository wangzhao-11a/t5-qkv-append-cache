# T5 QKV 拆分与缓存追加

本工程对应用户提供的 2026-10-23 固定耗时目标任务包。

## 实现

- `op_host/`：OpDef、shape/dtype 推导、输入输出元数据检查及 tiling。
- `op_kernel/`：16 位原样搬运内核，纯 AIV，64 KiB 双缓冲，显式全局工作区为 0。
- `direct/`：复用内核主体的 Kernel launch 工程。
- `csrc/torch_binding.cpp`、`solution.py`：正式 ACLNN / 直调 / prepare 入口。
- `examples/`：独立 ACLNN C++ 样例及 5 类非法元数据拒绝检查。
- `reference/`：从原始 ZIP 导入的 12 个文件，保持内容字节不变。
- `tests/`：CPU 地址模型及 NPU 扩展检查、同机基线对照。
- `task_submission/`：官方模板字段对应的七件自验证材料。

## 构建与测试

必须在 aarch64 CANN 9.1.0 开发环境运行；Windows 仅用于源码和材料准备。

```bash
source /usr/local/Ascend/cann-9.1.0/set_env.sh
export PATH=/usr/local/python3.12.13/bin:$PATH
export T5_OPP_ROOT=$HOME/.local/t5_qkv_opp
bash -n scripts/build.sh
bash scripts/build.sh > build.log 2>&1
source "$T5_OPP_ROOT/vendors/t5qkv/bin/set_env.bash"
export ASCEND_RT_VISIBLE_DEVICES=<已分配且确认空闲的单个设备>
python3 tools/preflight.py --output reports/environment_before.json
export T5_DEVICE_CONFIRMED=1
bash scripts/validate.sh > validation.log 2>&1
```

脚本先生成官方 msopgen 工程，再覆盖本题实现并编译私有 `.run`；不会修改系统 CANN。构建前保留既有 build 目录，拒绝静默覆盖。设备测试从独立 C++ 最小调用开始，经公开精度、扩展精度、稳定性和内存检查后才测性能。具体步骤见 `task_submission/1 自验证步骤说明.md`。

```python
import solution
query, key, value = solution.run([qkv, past_key, past_value], {"headNum": H, "headDim": D})
query2, key2, value2 = solution.run_direct([qkv, past_key, past_value], {})
plan = solution.prepare([qkv, past_key, past_value], {})
query3, key3, value3 = plan([qkv, past_key, past_value])
```

prepare 只保存元数据，不保存输入或输出。每次执行仍验证元数据、获取当前 stream 并分配三份独立输出。未知属性、布尔/浮点/字符串属性、尺寸越界、非连续及内部阻塞格式输入均拒绝。

## 原始材料差异

1. 原 ZIP 中任务书为 `T5QKV拆分与缓存追加算子任务书.md`，哈希 `e65bf0cc08fcb170bf9b15caac0922fa3cde539f4a58c23722c15fe3bdb7ca57`。原清单期待另一个带“题目3-”前缀的名字和哈希；该条不匹配。其余 10 项匹配。详见 `reference_manifest.json`。
2. README、`performance_targets.json`、原检查器明确规定固定微秒上限。任务书第 3.3 节混入“耗时比”文字，且没有可用的比值阈值。本工程执行固定目标检查，同时另测同机基线并报告比值，不自行发明比值验收线。

## 证据范围

`reports/cpu_address_model.json` 是 CPU 地址映射检查，不代表 CANN 编译或 NPU 通过。正式报告只使用实际设备 JSON 和日志；缺失结果显示待验证。环境、构建和设备状态以 `reports/`、`artifacts/` 中的原始证据为准。

提交个人仓库 URL、正式社区设计评审和 PR 属于后续发布事项。本地工程不伪造仓库地址、评审或合入结果。
