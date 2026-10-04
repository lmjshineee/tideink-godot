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
