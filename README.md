# TideInk（潮墨）· Godot

独立的 Godot 4.8.dev6 原生涂墨对战项目。项目入口 `project.godot` 就在仓库根目录；当前单机支持 1v1 / 5v5、90 / 180 秒、全图涂地战、五张精选地图、八武器、十一副武器和八天赋。配装可选固定套装或自定义，八项属性可分配 20 点，支持开战前随机 ROLL，并提供四种不同体型、非触须发型与服装混搭的潮墨街头造型。

原 INKWAVE 原生项目现名 TideInk。资源来源、许可证和历史记录保留；本地工程目录仍为 `inkwave-game-cleaned`。

当前源码继续按功能推进，未递增版本号。双方 AI 加点现在按武器与天赋带倾向地 ROLL，沿用玩家已用点数预算和整局锁定；Tab 重做为中央地图、双方分列卡片，显示真实武器图标、玩家高亮、情报状态、已用点数及最高三项等级。见 [AI 配点与战术卡片](docs/BOT_ATTRIBUTE_BUILDS.md) 和 [本批验收](render-evidence/bot-builds-2026-10-10/summary.md)。

最终 111 项源码检查及两尺寸 1v1／5v5 原生 Tab 输入／画面通过；32 项无界面夹具有退出引用警告，新增专项和最终原生没有 Godot 告警。440 个既有资产文件与 288 个 UID 保持，人工审美、配点平衡和长期性能仍待验收。

已有 `build/TideInk.app` 是生产提交 `7f2368c` 的主题色服装混搭版本，仅 arm64；本次精选地图／脸发改动尚未导出。版本字串保持，以提交／构建收据区分应用。应用历史验收见 [服装混搭记录](render-evidence/performance-wardrobe-2026-10-10/summary.md)，最新源码状态见 [当前状态](docs/COORDINATION.md)。

私有源码仓库：[lmjshineee/tideink-godot](https://github.com/lmjshineee/tideink-godot)。preview.16 的构建与启动证据见下方发布验收。

运行、检查与导出均不使用网页源码、Node、Next.js、Three.js 或浏览器服务。角色、地图、字体与声音的 Godot 资源以及许可证保留在本项目中。

零加点均衡仍为 132 HP／110 墨量／5% 移动加成，普通射击近距四轮、远距五轮。准备页点「属性 · 加点」调整生命、墨量、奔跑、潜泳、省墨、回墨、充能和副武器冷却，各项最多 8 级、收益递减；伤害不加点。满生命均衡最高 155.76 HP，可接住 150 的精准狙击。整局固定、死亡保留；地图／规则／造型重载保留本次会话分配，退出 App 后没有磁盘加点存档。见 [属性和人物](docs/ATTRIBUTES_CHARACTERS.md) 与 [战斗规则](docs/COMBAT_BALANCE.md)。

2026-10-10 源码新增弧形高线／圆场的日落滑场、悬空斜交大厅／桥下通路的灯轨车站，更新墙贴、脸型与四种发型，并移除中央区域模式；已有 App 尚未更新。见 [地图与人物设计](docs/CURATED_ART.md)。

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
```

统一入口只要求 Godot 和系统 shell：导入 → 生产脚本编译 → 本地资源完整性 → 规则／场景检查。Python 用于隔离负例、资源清单更新和 arm64 打包。日志保存在 `.godot/`；macOS 构建输出在 `build/`。

## 项目入口

- [Web 差异与 AI 维护规范](docs/GODOT_MAINTENANCE.md)：当前规范，AI 从根目录 [AGENTS.md](AGENTS.md) 进入。
- [文件结构](docs/STRUCTURE.md)、[模块与权威边界](docs/MIGRATION.md)、[显示边界](docs/RENDERING.md)。
- [玩法](docs/GAMEPLAY.md)、[创意配装](docs/CREATIVE_LOADOUTS.md)、[工作状态](docs/COORDINATION.md)。
- [验证与工具](tools/README.md)、[本次独立工程验证](docs/CLEANUP.md)、[许可证](THIRD_PARTY_NOTICES.md)。
- [原生完整对局与结算验收](render-evidence/native-match-2026-10-04/summary.md)：180 秒 5v5 受控基线、帧间隔及面积／积分展示修正。
- [机器人出场跳跃验收](render-evidence/bot-deployment-2026-10-05/summary.md)：91 项统一检查、两队负例与两个原生 Metal 受控场景。

`docs/history/`、`render-evidence/` 和 `experiments/` 保留 Godot 历史记录与人物实验，正式导出排除。真实手感、长期温度、全地图长时机器人策略与联网仍需验收。源码与已有应用的交付状态见 [当前状态](docs/COORDINATION.md)；本批源码未导出，没有创建分发压缩包、推送或发布。
