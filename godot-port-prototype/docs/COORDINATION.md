# 当前工作状态

更新时间：2026-10-03。工作树分支：`codex/godot-cleanup`。

## 本批整理

1. 从主目录的最新移植状态建立检查点 `5a8455a`；2,219 个源码、资源和既有证据文件逐字节核对。主目录原始改动保留，本分支承接整理。最终成果位于独立目录 `/Users/yunni/Joy/inkwave-game-cleaned`。
2. HUD 从对局控制器独立，减少每帧样式分配和隐藏名单查询；三个命令入口共用引擎发现与素材导入。
3. 当前文档改为结构/操作入口，逐批过程完整存档至 [docs/history/](history/)；保留截图目录已有的 Godot 导入隔离。

验证和边界见 [docs/CLEANUP.md](CLEANUP.md)。本次没有导出新 `.app` 或公开发布；旧文档记录的公开应用为 preview.15，不能代表本分支源码。

## 后续入口

先读 [MIGRATION.md](MIGRATION.md) 和对应模块；玩法及未完成项见 [GAMEPLAY.md](GAMEPLAY.md) / [CREATIVE_LOADOUTS.md](CREATIVE_LOADOUTS.md)。一个工作树同时推进一项任务，提交前运行统一检查，并按变更补原生画面/输入验证。

保留人物实验、历史证据和主目录的未提交改动。只交付本地 arm64 包；人工平衡、长期温度、机器人自动队友跳跃与联网仍有未完成工作。

整理前的分工和逐批记录见 [协作历史](history/2026-10-03-coordination.md)。历史任务表不作为本分支当前任务清单。
