# 原作参考与本地耗墨调整

查阅：2026-10-11。当前 Godot 有效参数来自本地资产、`gameplay_rules.gd` 和 `equipment_catalog.gd` 叠加；下列资料作为设计参考，不覆盖本地生命、场地单位、计分或配装。

## 系列动作来源

- 《斯普拉遁 1》[Nintendo Wii U 电子说明书](https://www.nintendo.com/eu/media/downloads/games_8/emanuals/wii_u_6/splatoon_3/ElectronicManual_WiiU_Splatoon_EN.pdf)：潜墨移动、回墨、主副武器与涂墨积攒特殊武器是系列基础。URL 里的 `splatoon_3` 是站点目录，PDF 是 Wii U 首作说明书。
- 《斯普拉遁 2》[Nintendo 2017 武器介绍](https://www.nintendo.com/en-gb/News/2017/July/Update-from-the-Squid-Research-Lab-the-weapons-of-Splatoon-2-part-2-1241314.html)：双持高速滑步、狙击蓄力的墨耗和暴露窗口。当前保留双持两次滑步与滑后精度奖励；本批让机器人狙击最后 0.24 秒锁定瞄准点，使侧移具有真实躲避窗口。
- 《斯普拉遁 3》[Nintendo 动作介绍](https://splatoon.nintendo.com/en/gameplay/)与[对战技巧](https://www.nintendo.com/en-gb/News/2024/September/Beginner-basics-for-Splatoon-3-tips-for-improving-in-battle-2640849.html)：Squid Roll／Squid Surge 作为潜墨转向翻滚、墨墙蓄力冲刺的参考。

墙面蹬跳、全大招有限启动无敌、普通墨弹一对一抵消及矩形均匀乱数是本地选择；不能据此描述原作全部武器或大招。墨翼按用户反馈采用直接升降，属于本地副武器。

## 数值来源与单位

使用 [Leanny/splat3 原始参数仓库](https://github.com/Leanny/splat3/tree/main/data/parameter/1130/weapon)的 `1130`（11.3.0）快照。它是社区直接提取的游戏参数，不是 Nintendo 发布的平衡表，也不保证是最新补丁；本次没有混用多个版本或引用二手攻略的数字。七份原始JSON和对应URL／SHA256保存在 [原始快照记录](../render-evidence/accuracy-ink-2026-10-11/reference-1130/sources.json)。

原作 `InkConsume=0.0092` 表示满墨槽的 0.92%。表中统一按 100 单位墨槽换算；TideInk 基础槽是 100，均衡实际是 110，属性／天赋再作用于实际消耗。原作伤害参数的缩放、坐标距离和帧数另有游戏语义，不能直接当成本地 HP、米或秒。

| 原作参数文件 | 11.3.0 参考耗墨 | TideInk 当前消耗 | 本地选择 |
| --- | --- | --- | --- |
| [ShooterNormal](https://raw.githubusercontent.com/Leanny/splat3/main/data/parameter/1130/weapon/WeaponShooterNormal.game__GameParameterTable.json) | 0.92% / 发 | 0.92 / 发 | 原 0.85 略上调，近距四发伤害保留 |
| [ManeuverNormal](https://raw.githubusercontent.com/Leanny/splat3/main/data/parameter/1130/weapon/WeaponManeuverNormal.game__GameParameterTable.json) | 0.72% / 弹；滑步 7% | 1.6 / 两弹一轮；滑步 12 | 原一轮 1.4 上调；本地滑步已有较强位移，未照搬 7 |
| [RollerNormal](https://raw.githubusercontent.com/Leanny/splat3/main/data/parameter/1130/weapon/WeaponRollerNormal.game__GameParameterTable.json) | 甩墨 8.5% | 甩墨 9 | 保持本地值；持续滚刷仍按距离消耗 |
| [ChargerNormal](https://raw.githubusercontent.com/Leanny/splat3/main/data/parameter/1130/weapon/WeaponChargerNormal.game__GameParameterTable.json) | 轻点 2.25%；满蓄 18% | 2.5 → 18 | 原满蓄 14 上调；伤害降低，增加射后空档 |
| [BlasterMiddle](https://raw.githubusercontent.com/Leanny/splat3/main/data/parameter/1130/weapon/WeaponBlasterMiddle.game__GameParameterTable.json) | 10% / 发 | 9 / 发 | 原 7 上调，保留略低成本补偿本地较长击倒节奏 |
| [StringerNormal](https://raw.githubusercontent.com/Leanny/splat3/main/data/parameter/1130/weapon/WeaponStringerNormal.game__GameParameterTable.json) | 轻点 5%、中蓄 6%、满蓄 8.5% | 2.5 → 8.5，半蓄 5.5 | 原满蓄 6 上调；保留本地低成本轻点涂地 |
| [ShelterNormal](https://raw.githubusercontent.com/Leanny/splat3/main/data/parameter/1130/weapon/WeaponShelterNormal.game__GameParameterTable.json) | 主射 5%；伞推出 30% | 主射 5、维持 0.9/s、推出 6 | 原主射 4.5 上调；本地伞强调防御，未照搬昂贵推出 |

飞镖为本地原创，保持每枚 6 墨。110 墨的均衡角色不计回血／回墨、额外能力或省墨时，约可发射喷枪 119 发、双持 68 轮、甩墨 12 次、满蓄狙 6 次、爆破 12 发、满蓄弓 12 轮、伞 22 轮、飞镖 18 枚。伞的维持／推出和双持滑步会额外消耗，不能把这些次数当对局续航结论。

## 乱数与狙击选择

原始喷枪 `Stand_DegSwerve=4.86`、`Jump_DegSwerve=11.66`，双持地面 2°／空中 7.5°，作为武器间与地空精度差异参考。TideInk 喷枪采用 4.8°／11.6°，双持 2°／7.5°；真正的取样分布按用户要求改成水平与垂直独立的方框，框小更准。原始参数里的角度不足以证明原作采用同样分布。

原作普通狙击满蓄伤害可达到 160（原参数 1600 的游戏缩放），本地用户明确反馈秒杀过强，因此采用 28→115、最终伤害上限 118；默认均衡 132 满蓄后剩 17 HP，受伤敌人仍可被收掉。蓄力 1.15 秒、释放恢复 0.40 秒、最大射程 24m、射线半径 0.04m。原 0.14m 容错缩小，44cm 偏射回归能落空；不把原作 100 HP 的一击节奏套到本地。

本批保留己墨回补 42/s、人形 9/s、开火后延迟 0.7 秒及现有墨槽／省墨属性。没有取得原作回墨参数完整快照，故不宣称这些数值对应原作。

当前规则、实际操作和验证边界见 [动作与防御](ACTION_COMBAT.md)、[伤害与配装](COMBAT_BALANCE.md)及[本批验收](../render-evidence/accuracy-ink-2026-10-11/summary.md)。
