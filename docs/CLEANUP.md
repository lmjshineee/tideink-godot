# 独立 Godot 工程 · 2026-10-04

拆分前基线 `aaf038c`。本次仅调整工程、资源完整性检查、工具路径与文档，保留已有玩法、资产内容与 UID。

1. 项目提到根目录，删除 Next.js 页面／组件、Web 服务／协议测试、浏览器游戏源码／Three.js、Node 配置和 24 个 JavaScript 迁移工具。
2. 运行、原生规则检查和 macOS 导出不读 Web 源码；保留 Godot 资源、许可证、原生工具、人物实验与 Godot 历史记录。
3. 来源／输出检查替换为 265 个本地资产的 SHA256、大小与完整清单检查；新增／缺失／损坏／空清单均失败，导入元数据不计入清单。
4. 编译门和资源门均在规则／场景检查前执行，失败立即停止；资源基线只能在有意修改并验证后显式更新。
5. [GODOT_MAINTENANCE.md](GODOT_MAINTENANCE.md) 为 Web 差异与 AI 维护规范，根目录 [AGENTS.md](../AGENTS.md) 是自动发现入口。

## 本次验证

- [统一检查](../render-evidence/standalone-2026-10-04/full-checks.txt)：90 项通过，0 失败。旧 107 项包含 18 个 JS 转换器检查；本次保留 89 个 Godot 检查并增加一个原生资源门，数量变化不代表回归丢失。
- [编译及失败隔离](../render-evidence/standalone-2026-10-04/parse-gate.txt)：8 种情况，包括两道门的阻断和成功只运行一次。
- [资源门负例](../render-evidence/standalone-2026-10-04/asset-gate.txt)：6 种情况，验证损坏、缺失、新增、导入元数据和空清单。
- [运行／导入](../render-evidence/standalone-2026-10-04/runtime.txt)、[配置初始化](../render-evidence/standalone-2026-10-04/visual-config.txt)：缓存、失败重试与默认／注入 runSpeed 通过。
- [原生 Metal](../render-evidence/standalone-2026-10-04/native-metal.txt)：最终根目录工程的配装／对局 HUD／结算、两种窗口尺寸、资源复用与场景释放通过；最终首次导入与 [265 个资产核对](../render-evidence/standalone-2026-10-04/final-assets.txt) 在不含 Node 的进程 PATH 下通过。

独立目录入口为 `project.godot`，使用 `./run.sh` 和 `./tools/run_checks.sh`。当前工作树没有 Web 代码与 Node 包；历史资源来源字段只记录原始出处，不会被解析为依赖。Git 早期提交仍可用于追溯拆分前状态。

本次没有重做人工完整对局／平衡／温度测量，没有导出或发布新 `.app`。旧发布包和历史截图不代表本次源码。原始项目 `/Users/yunni/Joy/inkwave-game` 保持原状。
