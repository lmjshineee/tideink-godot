# TideInk（潮墨）· Godot

独立的 Godot 4.8.dev6 原生涂墨对战项目。项目入口 `project.godot` 就在仓库根目录；当前单机支持 1v1 / 5v5、90 / 180 秒、全图涂地／中央争夺、七张地图、八武器、十一副武器和八天赋。配装可选固定套装或自定义，八项属性可分配 20 点，支持开战前随机 ROLL，并提供四种不同体型与服装剪裁的潮墨街头造型。

原 INKWAVE 原生项目现名 TideInk。资源来源、许可证和历史记录保留；本地工程目录仍为 `inkwave-game-cleaned`。

当前可玩应用：`build/TideInk.app`（`0.3.0-preview.24`，arm64），已打开。改为 20 点／八属性的直接加点、返还／重置／ROLL，队友和对手按玩家已用点数独立随机；四种人物使用不同的真实几何。110 项源码回归、31 项实际 PCK 规则、六组原生及独立 180 秒区域自动对局通过；末尾两个 UI 文案修改另有专项与包内覆盖。preview.23 App 和收据已核验备份；无界面退出引用警告仍有记录，真人审美／平衡尚未验收。见 [本批验收](render-evidence/attributes-characters-2026-10-09/summary.md)。

私有源码仓库：[lmjshineee/tideink-godot](https://github.com/lmjshineee/tideink-godot)。preview.16 的构建与启动证据见下方发布验收。

运行、检查与导出均不使用网页源码、Node、Next.js、Three.js 或浏览器服务。角色、地图、字体与声音的 Godot 资源以及许可证保留在本项目中。

当前源码为 preview.24：零加点均衡仍为 132 HP／110 墨量／5% 移动加成，普通射击近距四轮、远距五轮。准备页点「属性 · 加点」调整生命、墨量、奔跑、潜泳、省墨、回墨、充能和副武器冷却，各项最多 8 级、收益递减；伤害不加点。满生命均衡最高 155.76 HP，可接住 150 的精准狙击。整局固定、死亡保留；地图／规则／造型重载保留本次会话分配，退出 App 后没有磁盘加点存档。见 [属性和人物](docs/ATTRIBUTES_CHARACTERS.md) 与 [战斗规则](docs/COMBAT_BALANCE.md)。

## 运行

```sh
./run.sh
./run.sh --compatibility
```

默认 Forward+ / Metal，第二条使用兼容渲染。设置 `GODOT=/path/to/godot` 可指定引擎；首次运行自动导入资源。也可打开 `project.godot` 按 F5。

WASD 移动、鼠标瞄准、左键射击、Shift 潜墨、空格跳跃、E / 右键道具、F / Q 大招、J 选择队友／信标跳跃、Tab 战术地图、Esc 暂停。死亡后主动选择复活目标。新设置默认 30 FPS / 100% 精度，保留已有用户设置，可在设置中调整。

2026-10-08–09 源码修正滚筒上下坡贴地涂墨，104 项检查及原生 180 秒滚筒 5v5 验收见 [本批记录](render-evidence/ink-loop-2026-10-08/summary.md)。本批当时未导出；后续 preview.21 合并此修改，交付状态见上方应用验收。

2026-10-09 源码增加两队机器人低墨寻找可达己墨、停火潜墨回补及恢复推进；105 项检查和独立原生 180 秒对局通过，见 [回墨验收](render-evidence/bot-ink-2026-10-09/summary.md)。本批当时未重新导出，后续 preview.21 合并此修改。

机器人完成复活倒计时后，可从出生区自动跳向前方队友或己方信标；蓄力、公开预告、实际楼层和失效回退见 [玩法](docs/GAMEPLAY.md)。玩家继续手动选择。

机器人巡逻保持目的地，发现敌人、补给或危险时切换路线；导航按实际胶囊头顶净空绕开低坡道底部；信标在推进后尝试部署，避免基地浪费和近旁重复放置。全十九套布局出生区、七地图选定平台与双层高架原生整局记录见 [AI 通行验收](render-evidence/bot-routes-2026-10-05/summary.md)。

准备页新增“墨仔伙伴”：右键按住预览、松开投出，E 快投；落地后追击可见敌人，可被敌弹击毁。手雷增加弹跳轨迹、预计爆点和爆炸范围，六类部署道具显示实际放置点。设计与操作见 [召唤伙伴和投放提示](docs/SUMMON_DESIGN.md)。

## 检查与构建

```sh
./tools/run_checks.sh
python3 tests/python/test_parse_gate.py
python3 tests/python/test_asset_integrity.py
python3 tests/python/test_runtime.py
python3 tests/python/test_visual_config.py
python3 tests/python/test_release_metadata.py
python3 tests/python/test_character_archetypes.py
# 先提交生产源码，再导出；构建收据绑定该提交与应用文件哈希。
./export_macos.sh
python3 tools/release/package_macos.py --version v0.3.0-preview.24
```

统一入口只要求 Godot 和系统 shell：导入 → 生产脚本编译 → 本地资源完整性 → 规则／场景检查。Python 用于隔离负例、资源清单更新和 arm64 打包。日志保存在 `.godot/`；macOS 构建输出在 `build/`。

## 项目入口

- [Web 差异与 AI 维护规范](docs/GODOT_MAINTENANCE.md)：当前规范，AI 从根目录 [AGENTS.md](AGENTS.md) 进入。
- [文件结构](docs/STRUCTURE.md)、[模块与权威边界](docs/MIGRATION.md)、[显示边界](docs/RENDERING.md)。
- [玩法](docs/GAMEPLAY.md)、[创意配装](docs/CREATIVE_LOADOUTS.md)、[工作状态](docs/COORDINATION.md)。
- [验证与工具](tools/README.md)、[本次独立工程验证](docs/CLEANUP.md)、[许可证](THIRD_PARTY_NOTICES.md)。
- [原生完整对局与结算验收](render-evidence/native-match-2026-10-04/summary.md)：180 秒 5v5 受控基线、帧间隔及面积／积分展示修正。
- [机器人出场跳跃验收](render-evidence/bot-deployment-2026-10-05/summary.md)：91 项统一检查、两队负例与两个原生 Metal 受控场景。

`docs/history/`、`render-evidence/` 和 `experiments/` 保留 Godot 历史记录与人物实验，正式导出排除。真实手感、长期温度、全地图长时机器人策略与联网仍需验收。最新应用为 `build/TideInk.app`，交付状态见 [当前状态](docs/COORDINATION.md)；本轮仅本地提交与 arm64 应用导出，没有创建压缩包、推送或发布 Release。
