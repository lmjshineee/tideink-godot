# INKWAVE Godot Demo

Godot 4.8.dev6 原生涂墨对战样机。主菜单 → 同页配装 → 对局 → 结算；支持 1v1 / 5v5、90 / 180 秒、七张地图、八武器、九道具、八天赋。CPU 墨格负责归属和计分，画面与 UI 读取该状态。

## 运行

在仓库根目录执行：

```sh
./godot-port-prototype/run.sh
./godot-port-prototype/run.sh --compatibility
```

默认 Forward+，第二条使用兼容渲染。可通过 `GODOT=/path/to/godot` 指定引擎。首次运行或素材变化后自动导入；运行/验证/导出共用导入缓存。也可用编辑器打开 `project.godot`，按 F5。

WASD 移动、鼠标瞄准、左键主武器、Shift 潜墨、空格跳跃、E / 右键道具、F / Q 大招、J 队友/信标跳跃、Tab 地图、Esc 暂停。死亡后主动选择复活目标；配装冷却保留，天赋整局固定。规则和墨翼操作见 [GAMEPLAY.md](docs/GAMEPLAY.md) / [CREATIVE_LOADOUTS.md](docs/CREATIVE_LOADOUTS.md)。

默认 30 FPS / 75% 精度；设置可调整帧率、精度、UI、灵敏度和音量。真实手感、长期温度与完整联机仍待验收。

## 验证与构建

```sh
./godot-port-prototype/tools/run_checks.sh
python3 godot-port-prototype/tests/python/test_parse_gate.py
python3 godot-port-prototype/tests/python/test_runtime.py
./godot-port-prototype/export_macos.sh
python3 godot-port-prototype/tools/release/package_macos.py --version <版本号>
```

顺序：导入 → 解析预检 → 导出来源/输出哈希 → 无界面规则检查。解析失败立即停止。默认单项超时 120 秒；地图通行含物理帧等待，不宜将全套统一压到 25 秒。导出只允许 Apple Silicon / arm64，输出在 `build/`。

既有发布包与本分支源码的状态见 [COORDINATION.md](docs/COORDINATION.md)；本次整理和验证见 [docs/CLEANUP.md](docs/CLEANUP.md)。

目录职责见 [docs/STRUCTURE.md](docs/STRUCTURE.md)。

## 项目导航

| 内容 | 入口 |
| --- | --- |
| 玩法与未完成项 | [GAMEPLAY.md](docs/GAMEPLAY.md) |
| 结构与修改约定 | [MIGRATION.md](docs/MIGRATION.md) |
| 墨迹、角色与地图显示 | [RENDERING.md](docs/RENDERING.md) |
| 验证、导出器、截图工具 | [tools/README.md](tools/README.md) |
| 当前分支状态 | [COORDINATION.md](docs/COORDINATION.md) |
| 整理前详细过程 | [docs/history/](docs/history/) |
| 既有截图与测量 | [render-evidence/](render-evidence/) |
| 许可与资源来源 | [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) |

`experiments/character-sample/`、`experiments/character-redesign/`、`experiments/character-sculpt/` 是独立人物实验；`run.sh --flat` 启动历史平地样机。实验和验证记录保留，正式导出排除这些目录。历史截图设有 `.gdignore`，Godot 不再将它们逐张导入为游戏资源。
