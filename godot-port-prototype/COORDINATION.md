# Godot Demo：Codex × DeepSeek 协作计划

## DS-04 完成 · 2026-09-30

按引用审查计划，本轮由 Codex 执行第一项 DS-04，完成后停止。`tools/check_scripts_parse.gd` 改用 `GDScript.reload()` 的编译返回码检查，避免非空但解析失败的资源误报；`tools/run_checks.sh` 在所有场景短测之前单独执行解析预检，失败立即退出，成功后不重复执行。保留 runner 既有五导出器改动及其他未提交渲染文件。

验证：`python3 godot-port-prototype/tools/test_parse_gate.py` 的五项隔离用例通过（正常脚本、语法错误非零且无 PASS、坏 preload 依赖定位、失败不启动排序更早的哨兵场景、成功只跑一次预检后继续）；当前实际工程直接执行解析检查通过；`sh -n` 和 `git diff --check` 通过。隔离 runner 的导出器为桩，仅验证预检顺序与退出行为。执行主机为 arm64；未跑全套、图形试玩、导出或发布。本次解析日志在 `/private/tmp/inkwave-ds04-parse.engine.log`，长期可复现入口为上述 Python 短测。

下一项为 **DS-05：角色动画跑速初始化**；下面 2026-09-29 的审查表与结论保留作依据，DS-04 的待办状态由本节取代。

状态：2026-09-28。开发基线是本仓库 `codex/godot-playable-demo` 分支；`fd10b23` 是已发布 v0.1.0 的玩法代码。GitHub 的 [`lmjshineee/inkwave-godot-demo`](https://github.com/lmjshineee/inkwave-godot-demo) 是经过文件筛选的独立发布快照，**不是**本仓库的推送远端。对局目标是可玩的单机 1v1 Demo；不把联网、原作全部动画或 5v5 列为本轮完成条件。

## 1. 分工与顺序

| 负责人 | 拿什么任务 | 不改什么 |
| --- | --- | --- |
| DeepSeek | 有明确源码对照的独立小项：移动台阶/落地、朝向参数、导出器与素材数据；在独立分支提交代码和对应短测 | 对局总控、发布脚本、GitHub、渲染器；不改 Codex 正在编辑的文件 |
| Codex | 拆任务、给验收条件；负责战斗/蓝队生命规则、跨模块集成、差异审查、最终回归、Mac 导出和 Release | 不重复做 DeepSeek 已领且仍在进行的实现 |
| 用户 | 指出试玩中最影响体验的 1–3 个问题；决定是否接受渲染器切换和下一次发布范围 | 无需在每个短测后试玩 |

按**单人占用检出目录**工作：DeepSeek 和 Codex 不同时切换本仓库分支或编辑文件。DeepSeek 从当前集成分支建 `deepseek/<任务ID>`，只完成一个任务并提交，交回提交 SHA；Codex 审查后 cherry-pick 或要求在该分支修正。不要把两个代理的未提交修改混在一起。若真要并行，先给 DeepSeek 独立 worktree，再分配互不重叠的文件。

## 2. 近期可交付项

| ID | 负责人 | 范围 | 验收和停止点 |
| --- | --- | --- | --- |
| DS-01（已集成 `1b8aa41`） | DeepSeek | 只处理 `tidewater_walker.gd` 的 `stepUp`、`stepDown`、`footRadius`，新增或修改一个对应 `tools/check_*.gd` 短测；对照 `public/game/src/game/actor.js` 和导出的 `assets/weapons.json` | 跨 0.35 m 台阶、下台阶、临边三个可观察场景通过；不改战斗、蓝队和渲染器；提交后停止 |
| DS-02（已集成） | DeepSeek + Codex | DeepSeek 的 `1e0cacf` 朝向角弹簧已合入；Codex 接通鼠标瞄准与右键炸弹输入并加回归断言 | 朝向与输入目标短测通过，完整无界面回归 31 项通过；图形手感待验 |
| DS-03（待领取） | DeepSeek | 仅在 `tidewater_walker.gd` 接入 `hardLandSpeed`、`hardLandSlow`、`hardLandTime`，新增 `tools/check_tidewater_hard_land.gd` 短测 | 普通落地不触发；高速落地按源码设置减速权重；0.16 秒内恢复；潜墨速度不受普通形态减速；提交后停止 |
| CX-01（完成） | Codex | 蓝队敌墨伤害、回血、重生保护与玩家规则的差异收敛；代码只触及 `tidewater_bot.gd`、`tidewater_play.gd` 和对应短测 | `check_tidewater_bot_vitals.gd` 覆盖敌墨、回血、击倒、重生与保护；战斗和特殊技能短测通过 |
| CX-02（完成） | Codex | 蓝队四武器核心攻击与赛前选配；共用弹体、射线、墨迹和命中路径 | `check_tidewater_bot_loadout.gd` 覆盖爆破枪直击/溅射、蓄力狙、滚筒接触、赛前选配与重生保留；完整 AI 状态仍属后续范围 |
| QA-01 | Codex，用户提供试玩现象 | DS-02 已完成 31 项无界面回归；DS-03 集成后再做候选版导出与短时图形试玩 | 记录输入、HUD、射击、重生、结算是否走通，以及同机帧时间和温度；失败只修阻断问题 |

DS-01 和 DS-02 已集成；DS-02 鼠标瞄准/右键输入接线由 Codex 补齐，`tools/run_checks.sh` 为 31 项通过、0 失败。CX-01 与 CX-02 也已完成。下一步只交给 DeepSeek 一个 DS-03；Codex 在其交回提交前不改步行控制器，避免两边同时切换同一个检出目录。

## 3. 每项任务的最小交接

发给执行方的任务只包含五项：**基线分支/提交、目标行为、允许改的文件、一个短测、停止点**。执行方回报最多六行：提交 SHA、改动文件、源码依据、执行的检查及结果、已知风险、是否需要集成。不要贴长日志；失败时只贴首个相关错误及日志路径。

DS-03 交接提示（一次只发这一项）：

> 在 `/Users/yunni/Joy/inkwave-game` 阅读本文件，从 `codex/godot-playable-demo` 当前 HEAD 新建 `deepseek/DS-03`。只改 `godot-port-prototype/tidewater_walker.gd`、新增 `godot-port-prototype/tools/check_tidewater_hard_land.gd`（及 Godot 自动生成的 UID）。对照 `public/game/src/game/actor.js:241,388,508-512`：高速落地按 `hardLandSpeed` 设置权重，普通 kid 地面目标速度按 `hardLandSlow` 暂时降低，权重按 `hardLandTime` 衰减；保留现有跳跃、潜墨和冲击波行为。短测用隔离地面验证低速落地、高速落地减速及恢复、潜墨不受普通形态减速。只跑目标无界面短测，不启动图形界面，不改战斗/HUD/渲染/导出；通过后提交并停止。回报最多六行：SHA、改动文件、源码依据、测试结果、剩余风险、是否可集成。

DS-01 已执行的交接提示（留作记录，不再重复执行）：

> 在 `/Users/yunni/Joy/inkwave-game` 阅读 `godot-port-prototype/COORDINATION.md`，只做 DS-01。从 `codex/godot-playable-demo` 当前 HEAD 建 `deepseek/DS-01` 分支。对照 `public/game/src/game/actor.js`，把 `stepUp`、`stepDown`、`footRadius` 接入 `tidewater_walker.gd`；新增或更新一个短时无界面检查，覆盖上台阶、下台阶和临边。不要修改战斗、蓝队、渲染器、Release 或其他任务，不启动图形试玩。先运行目标短测；若通过则提交并停止。最后最多六行报告提交 SHA、文件、源码位置、测试结果、剩余风险。

## 4. 验证与发布门槛

1. 实现者只跑目标短测和必要的导出器 `--check`。Codex 集成后跑一次 `tools/run_checks.sh`；同一提交不重复跑全套。无界面通过不等于画面/温度通过。
2. Godot 图形试玩和 Mac 导出只在候选版成形或阻断问题修复后集中做。若设备温度快速升高，停止试玩，保留现象与日志；不为追求测试次数反复启动。
3. Forward+ 仍只是 `MIGRATION.md` 中的目标；先有同场景的 Compatibility 帧时间/温度基线，再单独比较，不能和玩法改动混成一个提交。
4. 只有 Codex 负责更新专用 GitHub 仓库和 Release。上传清单按 v0.1.0 的窄范围复核：Godot 工程、必要的导出器依赖、许可证；`.godot/`、`build/`、环境变量、账号连接代码不进 Git。应用 ZIP 只作为 Release 资产，并核对 SHA-256。原仓库 `origin` 是只读上游，不能直接推送。

管理方式：本文件的任务表就是本轮唯一待办；一项完成后更新其状态和下一项，不另建重复计划或大段会话总结。发现范围外问题只记录一行，不顺手扩项。
