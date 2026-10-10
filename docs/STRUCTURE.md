# 项目目录与代码职责

项目根目录为 `/Users/yunni/Joy/inkwave-game-cleaned`，直接打开根目录 `project.godot`。当前工作树仅包含 Godot 工程；Web 页面、服务器、JS 转换器与 Node 配置已移除。

```text
inkwave-game-cleaned/
├── project.godot / run.sh / export_macos.sh
├── AGENTS.md                # AI 自动发现的维护入口
├── src/
│   ├── core/                # 配置／平衡、地图／配装、队色
│   ├── match/               # 阶段、角色状态、生命、计分／伤害账本
│   ├── actors/              # 玩家、机器人和角色外观
│   ├── combat/              # 主武器、弹丸和武器专属大招
│   ├── abilities/           # 道具、天赋、部署、情报与机动
│   ├── ui/                  # 菜单、HUD、名单、设置和小地图
│   ├── world/               # 地图、导航、CPU 墨格和墨迹显示
│   ├── presentation/        # 音频、镜头和反馈
│   └── legacy/              # 历史平地样机，正式导出排除
├── scenes/                  # match/、world/、legacy/
├── shaders/                 # characters/、world/
├── assets/                  # 本地模型、地图数据、贴图、字体、音频
│   └── integrity.json       # 本地资产内容／体积清单
├── tests/                   # godot/ 回归；python/ 隔离负例
├── tools/
│   ├── run_checks.sh        # 原生统一验证，无 Node 依赖
│   ├── update_asset_integrity.py
│   ├── capture/             # 原生截图／回放，legacy/ 为旧界面
│   ├── measure/             # 受控测量与结果汇总
│   ├── release/             # arm64 模板与打包
│   └── lib/                 # 运行辅助、源码／资产清单
├── docs/                    # 当前规范和 history/ Godot 过程记录
├── render-evidence/         # 历史验收记录，隔离导入与导出
├── experiments/             # Godot 人物实验，正式导出排除
└── licenses/                # 随资源保留的许可
```

运行 `./run.sh`，默认场景 `scenes/match/tidewater_play.tscn`；`--flat` 仅用于旧样机。测试放 `tests/godot/`，工具按职责分组。新增玩法脚本不放根目录。

更改地图需同步碰撞、墨面、导航、小地图与布景；更改资产先验证实际场景和相关规则，再更新 `assets/integrity.json`。跨模块权威见 [MIGRATION.md](MIGRATION.md)，完整维护规范见 [GODOT_MAINTENANCE.md](GODOT_MAINTENANCE.md)。

部署模块位于 `src/abilities/`：`tidewater_deployment.gd` 拥有玩家选择／镜头及共用落位查询、信标账本；`tidewater_bot_deployment.gd` 拥有机器人复活后的自动选择／蓄力／飞行。`match/tidewater_play.gd` 转发真实复活、死亡、暂停与终场生命周期；小地图仅显示可见落点。

战斗体验模块：`core/bot_difficulty.gd` 给出双方共用难度参数；`combat/tidewater_weapon_specials.gd` 拥有速射、墨环和压力炮状态／真实弹丸，其余大招仍归各专属模块；`ui/incoming_attack.gd` 只持有命中时冻结的反馈，不创建队伍情报；`presentation/tidewater_feedback_fx.gd` 管理有限轨迹和预警显示。平衡与验收见 [EXPERIENCE_TUNING.md](EXPERIENCE_TUNING.md)。

召唤伙伴状态由 `abilities/tidewater_buddies.gd` 持有；`presentation/ink_buddy_visual.gd` 只读显示。`presentation/tidewater_item_preview.gd` 共用实际施放的只读查询；手雷步进归 `combat/tidewater_combat.gd`，放置／生命／墨格仍归既有模块。见 [召唤设计](SUMMON_DESIGN.md)。

`actors/tidewater_bot_ink.gd` 只持有低墨回补决策与有限的局部导航缓存，读取 CPU 墨格，不移动、涂墨或补资源；`tidewater_bot.gd` 执行物理移动、停火和真实回墨，`tidewater_perks.gd` 统一两种潜墨的形态／胶囊，情报和命中消费者读取此形态。见 [回墨验收](../render-evidence/bot-ink-2026-10-09/summary.md)。

主武器基础击倒门槛与单次上限归 `core/gameplay_rules.gd`；`match/tidewater_play.gd` 统一天赋／护盾／实际扣血账本，`combat/tidewater_combat.gd` 拥有真实命中、距离衰减、墙面溅射和滚筒整轮预算。部位标签只做反馈。见 [主武器比较](COMBAT_BALANCE.md)。


preview.22 新增：`src/core/loadout_rules.gd` 定义本地主武器／固定副武器映射；`src/match/area_control.gd` 根据可涂面和双方可达导航选中央区域，维护控制、倒数、罚分与加时。`src/world/surface_ink.gd` 仍是唯一涂墨账本，分别维护可奖励格与当前规则可计分格；墙壁视觉更新不依赖奖励值。

preview.24 属性与人物：`core/attribute_catalog.gd` 定义二十点、八属性和递减规则；`abilities/tidewater_attributes.gd` 拥有演员整局快照，`ui/attribute_editor.gd` 提供真实加减与剩余点数。`actors/character_archetypes.gd` 只配置视觉体型及造型标识，`assets/characters/archetypes/` 保存四套不同体型／脸型／头发／服装剪裁；本地生成工具在 `tools/assets/`，保留原件与骨骼。见 [设计与操作](ATTRIBUTES_CHARACTERS.md)。
