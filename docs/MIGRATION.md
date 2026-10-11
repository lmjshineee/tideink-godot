# Godot 结构与修改约定

默认场景 `scenes/match/tidewater_play.tscn`，引擎 Godot 4.8.dev6。当前玩法见 [GAMEPLAY.md](GAMEPLAY.md)；逐批记录完整保存在 [迁移历史](history/2026-10-03-migration.md)。

## 结构

| 职责 | 入口 |
| --- | --- |
| 阶段、演员状态、生命、涂地账本 | `src/match/tidewater_play.gd` |
| HUD 创建、布局、刷新、暂停/设置面板 | `src/ui/tidewater_hud.gd` |
| 主菜单、配装与地图/人物预览 | `src/ui/tidewater_frontend.gd`、`menu_*_preview.gd` |
| 战斗、弹丸、专用武器/大招 | `src/combat/tidewater_combat.gd`、`src/combat/tidewater_bow.gd`、`src/combat/tidewater_canopy.gd` 等 |
| 移动、墨墙、形态与跳跃 | `src/actors/tidewater_walker.gd` |
| 机器人、导航与大招 | `src/actors/tidewater_bot.gd`、`src/world/team_navigation.gd`、`src/combat/tidewater_bot_specials.gd` |
| 道具、天赋与复活/跳跃 | `src/abilities/tidewater_items.gd`、`src/abilities/tidewater_perks.gd`、`src/abilities/tidewater_deployment.gd`；机器人出场状态在 `tidewater_bot_deployment.gd` |
| CPU 墨格与显示 | `src/world/surface_ink.gd`、`src/world/surface_ink_view.gd` |
| 战绩/地图、动态表现、声音 | `src/ui/tidewater_tactics.gd`、`src/ui/tidewater_presentation.gd`、`src/presentation/tidewater_audio.gd` |
| 配置与地图选择 | `assets/weapons.json`、`src/core/gameplay_rules.gd`、`src/core/match_setup.gd`、`src/core/map_catalog.gd` |

对局控制器保留 UI 引用和少量转发入口，供现有输入、菜单和检查使用。HUD 不持有第二份玩法状态；后续迁移引用时逐个调整调用者，避免同时改动玩法与 UI 接口。

## 修改约定

1. CPU 墨格是归属/覆盖率的唯一权威；材质、纹理、小地图和 HUD 不参与计分，不消费彼此的脏格。
2. 当前本地 `assets/`、`src/core/gameplay_rules.gd` 和装备模块是维护依据；历史 Web 来源不参与运行或检查。已有基础配置先经本地平衡覆盖及装备扩展，不能仅改 JSON 就认为有效数值已改变。资产内容由 `assets/integrity.json` 核对；语义由规则／场景检查核对。
3. 改地图时同时核对碰撞、可涂/计分面、导航、布景、小地图。视觉道具不重复建立地图碰撞。
4. 阶段为 home → setup → intro → playing → finish → results；终场暂停 2.6 秒后直接展示最终结果。历史 judge 展示不再适用。
5. UI 尺寸布局在窗口/设置变化时更新，每帧只刷新实时状态。隐藏战术名单不查询敌方情报或格式化行文字。
6. 复活继续由玩家选择，道具冷却跨死亡/重摇保留，天赋整局锁定。
7. 玩家部署模块提供只读队友／信标落位查询。机器人自动选择、蓄力和飞行状态独立，仅真实复活后启用；信标时间／次数仍只有一份账本，UI 不消费次数。机器人选择不读取隐藏敌方位置。

## 验证与交付

先运行 [统一检查](../tools/run_checks.sh)。解析门必须用 `GDScript.reload()` 判断编译；独立失败用例见 [test_parse_gate.py](../tests/python/test_parse_gate.py)。按变更补原生画面/真实输入；无界面模拟不能证明人工手感或长期温度。

运行、验证、导出共用 [运行辅助](../tools/lib/runtime.sh)，通过 `GODOT` 指定引擎。导出仅 arm64；`.godot/` / `build/` 不提交，历史记录和人物实验不进资源包。实际导出后才记录包的架构、签名、哈希和启动证据。

与 Web 版的差异及 AI 工作流程以 [GODOT_MAINTENANCE.md](GODOT_MAINTENANCE.md) 为准。

2026-10-11 动作／防御批次：潜墨翻滚／墨墙冲刺状态由玩家移动控制器持有，启动无敌沿现有演员生命时钟，主射矩形散布与双持独立取样继续归战斗模块。伞大招由 `tidewater_push_wall.gd` 持有实体、耐久和推进；普通伞保持独立冷却／修复账本。当前规则见 [ACTION_COMBAT.md](ACTION_COMBAT.md)，源码未导出状态见 [本批验收](../render-evidence/action-defense-2026-10-11/summary.md)。

2026-10-11 方框乱数与抵消：`src/core/weapon_accuracy.gd` 共用实际射击与 HUD 精度查询；`src/combat/tidewater_ink_clash.gd` 拥有同帧敌我主射扫掠抵消，不写墨格；`src/combat/tidewater_special_guard.gd` 只显示既有生命时钟，死亡／终场立即清除。墨翼状态、耗墨和直接升降归 `src/abilities/tidewater_wings.gd`，HUD 只读。见 [当前规则](ACTION_COMBAT.md)。
