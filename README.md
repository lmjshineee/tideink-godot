# TideInk（潮墨）· Godot

独立的 Godot 4.8.dev6 原生涂墨对战项目。项目入口 `project.godot` 就在仓库根目录；当前单机支持 1v1 / 5v5、90 / 180 秒、七张地图、八武器、九道具和八天赋。

原 INKWAVE 原生项目现名 TideInk。资源来源、许可证和历史记录保留；本地工程目录仍为 `inkwave-game-cleaned`。

运行、检查与导出均不使用网页源码、Node、Next.js、Three.js 或浏览器服务。角色、地图、字体与声音的 Godot 资源以及许可证保留在本项目中。

## 运行

```sh
./run.sh
./run.sh --compatibility
```

默认 Forward+ / Metal，第二条使用兼容渲染。设置 `GODOT=/path/to/godot` 可指定引擎；首次运行自动导入资源。也可打开 `project.godot` 按 F5。

WASD 移动、鼠标瞄准、左键射击、Shift 潜墨、空格跳跃、E / 右键道具、F / Q 大招、J 选择队友／信标跳跃、Tab 战术地图、Esc 暂停。死亡后主动选择复活目标。默认 30 FPS / 75% 精度，可在设置中调整。

## 检查与构建

```sh
./tools/run_checks.sh
python3 tests/python/test_parse_gate.py
python3 tests/python/test_asset_integrity.py
python3 tests/python/test_runtime.py
python3 tests/python/test_visual_config.py
python3 tests/python/test_release_metadata.py
# 先提交生产源码，再导出；构建收据绑定该提交与应用文件哈希。
./export_macos.sh
python3 tools/release/package_macos.py --version v0.3.0-preview.16
```

统一入口只要求 Godot 和系统 shell：导入 → 生产脚本编译 → 本地资源完整性 → 规则／场景检查。Python 用于隔离负例、资源清单更新和 arm64 打包。日志保存在 `.godot/`；macOS 构建输出在 `build/`。

## 项目入口

- [Web 差异与 AI 维护规范](docs/GODOT_MAINTENANCE.md)：当前规范，AI 从根目录 [AGENTS.md](AGENTS.md) 进入。
- [文件结构](docs/STRUCTURE.md)、[模块与权威边界](docs/MIGRATION.md)、[显示边界](docs/RENDERING.md)。
- [玩法](docs/GAMEPLAY.md)、[创意配装](docs/CREATIVE_LOADOUTS.md)、[工作状态](docs/COORDINATION.md)。
- [验证与工具](tools/README.md)、[本次独立工程验证](docs/CLEANUP.md)、[许可证](THIRD_PARTY_NOTICES.md)。
- [原生完整对局与结算验收](render-evidence/native-match-2026-10-04/summary.md)：180 秒 5v5 受控基线、帧间隔及面积／积分展示修正。

`docs/history/`、`render-evidence/` 和 `experiments/` 保留 Godot 历史记录与人物实验，正式导出排除。真实手感、长期温度、机器人自动队友／信标跳跃与联网仍有后续工作。当前 arm64 包与私有仓库交付状态见 [发布验收](render-evidence/release-preview16-2026-10-04/summary.md)。
