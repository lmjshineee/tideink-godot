# TideInk Godot · AI 工作入口

## 必须先读

1. [docs/GODOT_MAINTENANCE.md](docs/GODOT_MAINTENANCE.md)：与 Web 版的差异及完整维护规范。
2. [docs/COORDINATION.md](docs/COORDINATION.md)：当前状态和验证边界。
3. [docs/STRUCTURE.md](docs/STRUCTURE.md)、[docs/MIGRATION.md](docs/MIGRATION.md)：目录职责与状态权威。

## 不可破坏的约束

- 当前项目只有 Godot；不要引入网页壳、JS 导出器、Node 包、Web 服务或对旧仓库路径的运行／检查依赖。
- 根目录 `project.godot` 是入口。源码按 `src/` 职责分层；测试、工具、素材和文档分别存放。
- CPU 墨格负责归属与计分；视觉和 UI 不得修改账本。有效参数来自本地资产与 Godot 规则叠加，禁止照搬 Web 数值覆盖本地平衡。
- 玩家选择复活目标；不得改成静默自动选择。保留道具跨死亡冷却和整局天赋锁定。
- Apple Silicon / arm64 only；不得增加 x86_64、Universal 或 Rosetta 构建、导出、验证。
- 保存已有未提交修改和资源 UID；不要重置、清理或覆盖其他任务的工作。
- 资源清单更新必须是有意的资产变更，先做语义检查，再显式更新；不得通过重写哈希掩盖资源错误。
- 运行 `./tools/run_checks.sh`；按改动补隔离负例和原生输入／画面验证。单独说明无界面规则、受控画面、人工对局、性能温度和实际导出各自的证据。
- 不自动发布或推送；一次完成一个有明确验收条件的任务。

## 沟通

- 使用中文，先说结果或下一步；多步骤用简短编号。
- 调试按“位置 → 原因 → 修复 → 验证”说明。
- 实现任务优先执行；学习任务解释推理。报告修改原因、验证结果和未验证项，不给无关建议。
