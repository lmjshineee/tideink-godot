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
| 道具、天赋与复活/跳跃 | `src/abilities/tidewater_items.gd`、`src/abilities/tidewater_perks.gd`、`src/abilities/tidewater_deployment.gd` |
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

## 验证与交付

先运行 [统一检查](../tools/run_checks.sh)。解析门必须用 `GDScript.reload()` 判断编译；独立失败用例见 [test_parse_gate.py](../tests/python/test_parse_gate.py)。按变更补原生画面/真实输入；无界面模拟不能证明人工手感或长期温度。

运行、验证、导出共用 [运行辅助](../tools/lib/runtime.sh)，通过 `GODOT` 指定引擎。导出仅 arm64；`.godot/` / `build/` 不提交，历史记录和人物实验不进资源包。实际导出后才记录包的架构、签名、哈希和启动证据。

与 Web 版的差异及 AI 工作流程以 [GODOT_MAINTENANCE.md](GODOT_MAINTENANCE.md) 为准。
