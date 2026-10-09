# 基础主武器击倒门槛 · 2026-10-09

本批在未提交的滚筒贴地与机器人回墨修改上继续，保留 120 HP、5v5 / 1v1、CPU 计分与玩家显式复活。未提交、导出、打包、推送或发布。比较依据和八武器实际值见 [COMBAT_BALANCE.md](../../docs/COMBAT_BALANCE.md)。

## 改动及原因

| 项目 | 之前 | 当前均衡天赋 |
| --- | --- | --- |
| 喷枪 | 近端 30，躯干四发、腿部五发 | 近端 42，所有部位三发；末端 32.76，四发 |
| 狙 | 满蓄 100，无法击倒基础满血目标 | 满蓄 150，可击倒无盾目标；98% 蓄力仍只扣 91.78 |
| 爆破 | 直击 82，溅射 55→24 | 直击 125，溅射 60→24；直击不重复溅射 |
| 滚筒 | 移动接触 60，甩墨 72→22 | 接触 125，甩墨 140→22；整轮仍有限预算 |
| 部位 | 头 ×1.08、腿 ×0.85 | 所有部位 ×1，真实潜墨胶囊与高度标签保留 |
| 全局上限 | 所有普通主武器单次最多 115 | 狙 180、滚筒／爆破 160，其余 115；甩墨整轮还共享本轮近端最终上限 |

机器人狙击／甩墨原先直接读基础武器，未读取低墨减伤后的配置，已改为消费发射时有效配置。兼容轻爆、墨弓显式保留 115 上限，避免继承基础武器的新上限。

位置 → 原因 → 修复 → 验证：`tidewater_combat.gd::_burst_blaster` 的墙面爆点沿目标方向偏移，起点可能位于薄墙内；默认射线忽略起点内的碰撞，造成墙后溅射。墙面爆点现在传入真实碰撞法线，从面外检查遮挡；实际薄墙反例原先失败，修复后通过。

## 无界面规则

`./tools/run_checks.sh`：**105 通过、0 失败，270 个本地资产完整**。见 [完整输出](checks-audited.txt)、[本轮伤害规则日志](audited-rule-logs/check_damage_contract.log) 与 [统一检查源码／测试快照](audited-checks-source.json)。随后仅补相关测试的退出清理，编译门及四项伤害专项复验通过，见下文与 [最终证据覆盖](final-source.json)。原生导入已生成新增工具 UID；此前 234 份 UID 和全部既有资产散列保持不变。

[原始规则快照](effective-rules.json)由 Godot 执行本地资产、规则叠加和装备扩展得到；[开始工作状态](starting-state.json)保存进入本批时 HEAD、未提交清单和文件散列，`before/` 保存有意修改的既有脚本。没有以 Git HEAD 覆盖上一批工作。

规则用例覆盖三种角色扣血入口（玩家、主机器人、附加队友）、三种命中高度、三发／四发门槛、满蓄与提前松开、60 点护盾、真实墙体、超射程、溢出不进伤害账本、整轮甩墨的低墨／增伤／易伤与中途变化、机器人有效配置和两队实际移动滚筒接触。部分预算用 300 HP 隔离目标以观察全部伤害，不代表生产生命改变。

原来的“慢武器命中后必须留血”、菜单伤害 30、护伞承受三发 100 的验收条件与本轮新设计冲突，已按实际新伤害更新；保留射击、耗墨、无敌、复活、墙体、友军穿伞、侧面暴露、破伞不穿透和冷却等断言。首轮受控规则也保留真实薄墙失败和夹具字段错误，旧日志不覆盖。

退出审计发现短命音频夹具在直接退出时遗留 ObjectDB 引用：旧区域／伤害日志为 8／23 个，统一重跑的机器人配装／战斗闭环为 18／24 个。详细日志将残留定位到 `AudioStreamWAV`／`AudioStreamPlaybackWAV`。测试清理现在先停止场景更新，等待已提交的播放，再停止音频、释放场景并等待退出；不改生产音频或战斗逻辑。

统一检查后这部分清理又有补充，因此最后单独复跑 [编译门](cleanup-final-parse-stdout.txt) 和四项专项：[伤害门槛](check_damage_contract-cleanup-final-stdout.txt)、[命中区域](check_damage_regions-cleanup-final-stdout.txt)、[机器人配装](check_tidewater_bot_loadout-cleanup-final-stdout.txt)、[战斗闭环](check_tidewater_combat_loop-cleanup-final-stdout.txt)，均通过且无退出警告，并再次运行最终原生鼠标／画面。最后的清理没有再跑一遍 105 项；完整回归快照与最后专项的散列分别保留。旧日志和中间诊断不覆盖。

## 受控原生鼠标与画面

当前最终原生结果：[combat.json](native-verified/combat.json)、[stdout](native5-stdout.txt)、[引擎日志](native5-engine.txt)。Godot 4.8.dev6、macOS／Apple M5、Forward+／Metal、1280×720、arm64；65 个生产脚本和相关工程／资产清单／夹具／工具共 69 份散列，共用测试清理脚本另由最终审计绑定。

- 复用 26 个规则观察，并在真实绘制窗口中注入鼠标事件；固定位置、冻结对局与 AI、按 1/30 秒显式 tick，只算受控原生证据。
- [按住鼠标满蓄](native-verified/mouse-full-charge.png)：31 tick，未提前伤人。
- [松开鼠标击倒](native-verified/mouse-full-charge-splat.png)：实际耗墨 14，100→86，120 HP 无盾目标被击倒。
- [实际护盾反制](native-verified/mouse-shield-counterplay.png)：通过道具激活 60 护盾，同一满蓄输入命中后目标剩 30 HP、护盾耗尽。
- [真实鼠标悬停配装说明](native-verified/updated-loadout.png)：显示伤害 32→150、满蓄击倒与所有部位 ×1；不是仅检查字符串的静态截图。

没有失焦恢复。此前 `native/` 和 `native-final/` 保留中间结果：第一份画面遗留规则夹具的复活面板，后一份尚未展示悬停说明；`native-ui/` 已验证真实悬停，`native-audited/` 是首次清理后的重跑，随后补完整退出清理并复验，最终以 `native-verified/` 为准。

## 正常计时 180 秒对局

统一检查之后独立运行潮水码头喷枪 **5v5**，不与规则回归或其他原生夹具并行。自动键鼠驱动玩家，九名机器人使用生产 AI；正常 180 秒计时进入终场、结算，再返回首页。见 [match.json](match/match.json)、[stdout](match-stdout.txt)、[引擎日志](match-engine.txt) 和 [结算画面](match/results.png)。

- 实际战斗墙钟 180.54 秒；10 次自然死亡、10 次等待后显式确认并完成复活，无失焦恢复。
- 十个角色、十行战绩、个人到队伍的涂地账本、CPU 覆盖率与结算显示核对通过；双方覆盖率为 20.6571% / 23.5317%。结算画面已复核。
- 30 FPS 上限、1280×720、100% 渲染、Forward+／Metal；排除前五秒预热后共 5239 个样本，均值 29.84 FPS、P50 33.36 ms、P95 36.01 ms、P99 39.83 ms。
- 最长帧间隔 **823.23 ms**，7 帧超过 50 ms。采样包含工具截图与桌面调度，没有 GPU 时长或温度；长帧原因未定位，不能据此验收整体流畅度。
- 这是单局自动路线，玩家喷枪仅造成 126 伤害、0 击倒；不能用本局战绩推断真人瞄准、各武器强弱或胜率。基础击倒门槛由上面的隔离命中和真实输入证明。

当前生产代码与统一检查、最终受控原生、自然对局的散列一致。自然对局后仅补测试退出清理与文档，先重跑统一入口和受控原生，再对最后清理复跑编译门／四项专项与原生；[最终审计](final-audit.json)记录资源／UID、上一批源码和证据绑定。

## 复现

从项目根目录运行；两个原生命令须分别完成，输出目录必须是尚不存在的新目录，不覆盖本批证据。

```sh
./tools/run_checks.sh
```

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method forward_plus --rendering-driver metal \
  --script res://tools/capture/verify_primary_combat.gd -- \
  --output=/private/tmp/tideink-primary-combat-new
```

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method forward_plus --rendering-driver metal \
  --script res://tools/measure/measure_native_match.gd -- \
  --output=res://render-evidence/combat-new/match --map=tidewater --weapon=shooter
```

## 证据边界

八武器整体强弱、真人准星／瞄准手感、其他地图长局、长期温度和网络均未由本轮证明，823 ms 长帧也仍待定位。弓、双持、飞镖和伞保留原有伤害；爆破溅射通常仍需三次，属于较保守的本地设计。现有 `build/TideInk.app` 为旧 preview.20，本批运行入口是 `./run.sh`。
