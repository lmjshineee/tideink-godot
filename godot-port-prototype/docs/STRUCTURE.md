# 项目目录与代码职责

最终副本位于 `/Users/yunni/Joy/inkwave-game-cleaned`。原网页源码保留于仓库 `public/game/`，供移植导出与行为对照；原生项目入口在 `godot-port-prototype/`。

```text
godot-port-prototype/
├── project.godot             # Godot 项目配置
├── run.sh / export_macos.sh  # 运行与 arm64 导出
├── src/
│   ├── core/                # 参数、地图/配装选择、队色
│   ├── match/               # 对局阶段、角色状态、计分/伤害账本
│   ├── actors/              # 玩家控制、机器人、角色外观
│   ├── combat/              # 武器、弹丸与武器专属大招
│   ├── abilities/           # 道具、天赋、部署、情报与机动
│   ├── ui/                  # HUD、菜单、名单、小地图、设置
│   ├── world/               # 地图、导航、墨格与墨迹显示
│   ├── presentation/        # 音频、镜头和战斗反馈
│   └── legacy/              # 旧平地样机，正式导出排除
├── scenes/                  # match/、world/、legacy/ 场景
├── shaders/                 # characters/、world/ 着色器
├── assets/                  # 数据、模型、贴图、字体、音频
├── tests/
│   ├── godot/               # 规则检查；helpers/ 共享场景夹具
│   └── python/              # 解析门、启动缓存、隔离配置检查
├── tools/
│   ├── run_checks.sh        # 完整资源/规则验证入口
│   ├── exporters/           # 网页来源 → Godot 资源
│   ├── capture/             # 原生截图与回放；legacy/ 保存旧界面脚本
│   ├── measure/             # 受控测量和报告汇总
│   ├── release/             # arm64 模板与打包
│   └── lib/                 # 工具共享代码
├── experiments/             # 三个人物实验，独立于正式场景
├── docs/                    # 当前规则、结构、状态与历史
├── render-evidence/         # 已有验收记录，不进入资源导入
└── licenses/                # 资源许可
```

默认场景为 `scenes/match/tidewater_play.tscn`。从仓库根目录运行 `./godot-port-prototype/run.sh`；`--flat` 保留历史场景。移动后的 `.uid` 保持不变，脚本/场景/材质引用随路径一起更新。

角色/武器/道具修改进入对应 `src/` 子目录；新增回归放 `tests/godot/`，资源转换放 `tools/exporters/`，截图放 `tools/capture/`。根目录不再新增玩法脚本。跨模块规则边界见 [MIGRATION.md](MIGRATION.md)。

资源来源清单在目录移动后同步路径和散列，既有模型/音频/贴图没有重新烘焙；完整导出器 `--check` 验证来源和输出一致。
