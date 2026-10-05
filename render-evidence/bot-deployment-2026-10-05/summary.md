# 机器人复活后的队友／信标跳跃

2026-10-05，独立 TideInk Godot 源码。用户要求继续实现并本地 commit，不发布 Release、不创建本地压缩包。本轮也不推送或导出新应用；已有 preview.16 应用不包含本轮修改。

## 行为与边界

1. 真实机器人复活倒计时结束、正常恢复资源后，短暂从出生区选择前方存活队友或己方信标；无合适目标就继续导航。初始阵容、玩家复活和任意战场位置不会被自动选择。
2. 机器人有独立的一秒蓄力／弧线飞行状态，公开落点预告。实际楼层、可涂地面、净空／占位及信标己方墨地在选择、起飞和到达重新核验。起飞前失效原地取消，途中失效回己方出生点；信标仅成功落地扣一次使用。
3. 跳跃不再次补生命／墨量、不续出生保护；道具冷却和整局天赋保留。跳跃冷却四秒，在死亡期间计时；暂停冻结，死亡和终场清理，其他道具／机动／大招互斥。
4. 自动避险只使用队伍实际发现或尚有效的最后接触，不读取隐藏敌人坐标。地图只画己方或实际可见的敌方预告。玩家仍通过自己的 J／选择界面／确认操作控制部署。

## 验证

- `./tools/run_checks.sh`：**91 通过，0 失败**，含 GDScript 编译门、265 本地资产完整性与既有玩家手动复活／跳跃、导航、装备、战斗、账本回归。[统一输出](checks.txt)。资产及清单未修改。
- 新增专项最终通过：两队自选／敌方／死亡／空中／低墨／出生区范围／占位负例、队伍接触避险、蓄力受伤、暂停、能力互斥、无额外回血补墨、CD／天赋保留、目标死亡取消、飞行失效回基地、真实控制器复活触发、死亡冷却计时、六米信标、敌队／过期／耗尽／敌墨覆盖信标、两个机器人争最后一次使用、终场清理。[专项输出](specialist.txt)。
- 原生 **macOS / Apple Silicon arm64 / Forward+ / Metal**，Godot `4.8.dev6.official.8898c2b3d`，Apple M5，1280×720、30 FPS / 75% 精度。玩家 J 打开手动选择、Esc 取消的真实键盘事件通过；实际复活控制器／物理帧完成潮水码头队友跳跃及棱镜画廊己方信标跳跃。[机器报告](report.json)、[原生日志](native.txt)。
- 潮水码头：队伍 0，目标 `actor:1`，完成一次、回退零次，落位 `(1.3, 0.05, -24.0)`；约 6.40 秒包含真实四秒复活倒计时。
- 棱镜画廊：队伍 1，目标 `beacon:1`，完成一次、回退零次，落位 `(-7.2, 6.05, -3.0)`，信标使用从二降为一；约 6.44 秒。最终原生运行失焦恢复 **0 次**。
- 生产源码哈希在 `report.json`；本目录图像由同次运行生成，未改历史证据。最终专项退出无资源泄漏警告，`git diff --check` 通过。

## 原生画面

- [玩家手动选择](player-manual-selector.png)
- 潮水码头：[蓄力预告](tidewater-windup.png)、[飞行](tidewater-flight.png)、[落地](tidewater-landed.png)
- 棱镜画廊：[蓄力预告](prism_gallery-windup.png)、[飞行](prism_gallery-flight.png)、[六米平台落地](prism_gallery-landed.png)

## 复现与限制

```sh
./tools/run_checks.sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/tideink-bot-rules.log \
  --script res://tests/godot/check_bot_deployment.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method forward_plus --rendering-driver metal \
  --log-file /tmp/tideink-bot-native.log \
  --script res://tools/capture/verify_bot_deployment.gd -- \
  --output=/绝对路径/尚不存在的证据目录
```

原生工具固定摆放队友／信标，并用两次受伤制造真实死亡；其他机器人被停放／设置长复活等待，之后由正式复活控制器及物理帧推进。初次夹具错误释放鼠标触发暂停，并低估了每次伤害 115 的封顶；仅修正夹具的解锁恢复和两次攻击后重跑，正式暂停／伤害规则未改。快速无界面模拟的声音在夹具退出前等待并停止，避免音频播放尚在排队时释放场景。失败运行保留在忽略的 `.godot/`，本目录仅成功证据。

本轮未测全地图自然对局中的策略质量、真人手感／配装平衡、帧时间／长期温度、联网或实际新导出包。任意战场位置机器人自动撤回未实现；未知位置桥梁漏染、坡面 IK 等独立后续任务保持开放。
