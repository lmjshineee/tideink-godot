# 水润墨水与敌墨数字反馈 · 2026-10-05

最新可玩应用：[TideInk preview.18](../../build/TideInk.app)，仅 Apple Silicon / arm64，约 304.8 MiB。生产输入提交 `7393c7209dfa81c1906668cad1874f2c1fc7e5f7`，PCK SHA-256 `4916deb458a09b2849ccbabee9fb271031621dc9aa81c19a352f9bd52c63f26c`。

## 位置 → 原因 → 修复 → 验证

| 位置 | 原因 | 修复 | 验证 |
| --- | --- | --- | --- |
| `surface_ink.gdshader`、环境场景 | 大片墨面高光不够明显、视觉偏平；微细法线可能在远处闪动 | 降低粗糙度、增强湿润清漆、保留缓慢褶皱和墨边法线，启用 32 步场景反射；远处减弱细纹并提高粗糙度 | 同固定视角前后原生画面、实际 PCK 的俯视／低视角／角色脚下墨面 |
| `gameplay_rules.gd`、玩家／机器人 vitals | 显示的“5”是累计报告门槛，实际参数为 8 HP/s | 改为 2 HP/s，提示累计门槛改为 2；潜游天赋按既有减伤变为 0.6 HP/s，玩家和两条机器人路径一致 | 30／60／120 Hz 的实际损伤；累计上限、保护、最低 1 HP 和所有角色路径 |
| `incoming_attack.gd`、presentation | 地面每次扣血占用完整受击卡，持续遮挡且可能挤掉真正攻击来源 | 环境数字独立、弹起／上浮／淡出，0.8 秒消失，上限三条；保留武器的姓名／方向卡和死亡来源记录；忽略会舍入为零的极小显示量 | 实际敌墨仅 −2，武器受击同时保留，960×540／110% 及 1280×720 |
| `tidewater_play.gd` | 零碎敌墨损伤跨接触／重开累积；已扣除的损伤被再次按剩余血量截断 | 离开／死亡清算当前实际损失，复活／重开清零；已结算环境伤害不二次截断 | 短接触 0.5、真实两次射击阵亡、3→1 HP 实际提示 2、保护和 1 HP 不造伤害 |
| HUD／presentation | 连续扣血／回墨让整数有极小浮点偏差，ceil 会把 118 显示为 119 | 两个消费端使用同一整数容差，仅改显示 | 实际最终图显示 118；真实小数仍按原来的向上取整规则显示 |

CPU 墨格归属／计分、玩家主动复活选择、道具跨死亡冷却和本局天赋锁定保持原有权威。没有资产内容修改，没有重写完整性清单。

## 检查与原生证据

- 最终统一入口 96 项通过、0 失败；最后微量数字过滤与空 presentation 文本依赖调整后，重新运行完整生产脚本解析与 `check_ink_hazard_feedback` 通过。
- 构建收据 11 项隔离负例通过；真实导出架构、Info.plist、严格签名检查及收据字节核对通过。
- 13 项实际 PCK 规则、实际 PCK 原生主页／配装／移动射击／受控结算／返回主页、实际 app 无工程或脚本替换的 headless 启动通过。
- `packed-wet/` 由匹配版本的原生编辑器在工程外临时目录加载**实际导出 PCK**；外部工具只替换 fixture helper 路径及收据来源字段，测试与截图逻辑不变。真实敌墨损伤、独立数字／武器来源、两尺寸及水润墨面通过；报告绑定实际 PCK 与来源提交。
- 实际 app 可执行文件另从工程外临时目录以原生 Metal / Forward+ / Apple M5 运行 45 帧，退出 0，没有 Godot 错误。见 `actual-app-native.json`。
- `before/` 为原效果；`after/` 为首次优化；`final/` 已修正血量舍入和脚下视觉同步，发生在最后两行过滤／空引用处理之前；最终打包画面以 `packed-wet/` 为准。

## 帧时间与边界

固定低视角、停止 AI／角色物理、预热 30 帧后各记录 120 帧：优化前中位数 16.667 ms、P95 17.077 ms；最终源码样本中位数 16.666 ms、P95 16.969 ms。工具请求不限帧并关闭 VSync，但结果仍接近 60 Hz 显示节奏；不能据此断言 GPU 开销、温度或复杂对局没有变化。原生脚本仅在 fixture 中恢复失焦暂停，不改变正式暂停行为。

本次为受控规则／画面／实际应用检查，没有新增自然整局或真人试玩，没有审美、全地图长时 AI、长期温度或联网验收。大方向与可分批验收项目见 [完成度路线](../../docs/PLAYABILITY_ROADMAP.md)。

## 交付

复用既有 `.godot/arm64-template.zip`，SHA-256 `daf43479c6c792c06d47e22e59bdbac39170d27b6bc5e739871d17601ba2fce7`，前后未变。先导出暂存 `.app` 再安装最新应用，旧 preview.17 作为未压缩文件夹保留在 `build/TideInk-preview.17.app`；没有终止先前运行的旧进程。要体验新修改请重新打开当前 `build/TideInk.app`。

本地提交；未创建压缩包、推送 GitHub或发布 Release。本地 ad-hoc 签名，不声明已公证。

着色器与反射行为参考 Godot 官方 [Environment and post-processing](https://docs.godotengine.org/en/latest/tutorials/3d/environment_and_post_processing.html) 和 [3D antialiasing](https://docs.godotengine.org/en/4.5/tutorials/3d/3d_antialiasing.html)。
