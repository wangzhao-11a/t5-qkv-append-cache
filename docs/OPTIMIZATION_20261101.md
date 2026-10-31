# 2026-11-01：设备重新分配后的受控验证

目标仍是原固定性能 10/10，尚未完成。原 c9decf2 基线、历史报告和交付包均保留。

## 环境核对

- 179.68.53.144 为 Ascend950PR，容器 8dfcb46369c9；只读检查后离开，未部署候选、未计时。
- 用户随后提供 199.103.53.243。主机密钥与旧环境相同，但容器变为 05d447771751，分配改为卡 3、物理设备 6/7；驱动仍 26.1.1。
- CANN 官方接口返回 Ascend910_9382；设置 ASCEND_RT_VISIBLE_DEVICES=1 后可见一个运行时设备。ACL_DEV_ATTR_PHY_CHIP_ID 返回 3，此属性不能直接当作 npu-smi 的物理设备编号 6/7。
- 原 c9decf2、1bba0d0 目录和私有 OPP 均保留；两份 live 扩展与各自二进制清单哈希一致。未重建运行库或安装依赖。
- 未设置任务依赖 PYTHONPATH 时，探针看到 NumPy 1.26.4；正式脚本恢复原 python_deps 路径后断言 NumPy 2.2.6、Python 3.12.13、torch 2.10.0+cpu、torch_npu 2.10.0.post4/5dd8ef3、ml_dtypes 0.6.0，c9 smoke 已通过。
- 原始只读探针：[reallocation_probe_20261101.json](../reports/reallocation_probe_20261101.json)。监听端口为 22、6988、9500、9501、9508、45699。

## 控制组和候选

分配已经改变，不能直接将本轮测量与旧卡结果相减。使用原二进制分别重测 c9decf2 和 1bba0d0，先运行原 smoke 的四形状、两入口、各 20 次正确性/稳定性检查，再执行未改动的固定 benchmark。控制阶段日志和报告写入 1bba0d0 的 validation 目录，以 reallocation_ 开头，保留旧验收结果。

控制脚本使用整个可见板的空闲门禁。功能阶段新增 T5_FUNCTIONAL_DEVICE_SCOPE=board 选项，避免沿用旧卡 0/chip 1 的占用查询。正式性能门禁仍要求连续三次整板空闲。构建和功能/性能阶段新增 --require-soc Ascend910_9382，在初始化算子前拒绝错误 SoC 或非单设备配置。

待测内核/主机源码与 e1a4d2b 完全相同：保留执行器复用，只聚合进入 L2 的 K 前缀 tile 写入。后续提交仅增加环境门禁和记录，仍须完整构建、正确性、工程、内存及固定性能验证。

SSH 使用双层 20 秒 transport keepalive 和独立 shell 心跳；凭据仅用于会话认证，未写入项目。
