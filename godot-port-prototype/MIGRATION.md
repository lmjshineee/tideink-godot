# INKWAVE：Godot 特性选型与迁移规范

状态：2026-09-30。当前目录是可丢弃的 Godot 样机，**不是**网页游戏的等价实现。本文是后续代码评审与验收的约定；提到的目标能力不表示已经完成。当前迁移顺序是 **真实地图规则闭环 → 画面与素材 → 完整对局 → Mac 导出**。默认入口已是 `tidewater_play.tscn`；本批有带测试条件和加速等待的短时自动图形流程证据，没有人工手感或完整 90 秒图形对局证据。

本目录已纳入 Git（基线提交 `6ea0bef` 只做入库、未改内容），迁移批次在独立分支上做；批次记录见 §6。
验证的唯一入口是 [tools/run_checks.sh](tools/run_checks.sh)：素材导入 → 5 个导出器 `--check` → 解析预检及其余短测（本批共 36 项），任一失败即非 0 退出。**"已迁移"必须附该脚本的通过输出**，不接受只跑单个脚本或只看退出码。
地图场景已接入原版 144 处道具、18 面壁画和港口远景；视觉独立于碰撞与计分。渲染基础已切换为 Forward+，接入天空、方向光/阴影、SSAO、地图与角色受光材质及湿润墨迹；短测与截图证据见 [RENDERING.md](RENDERING.md)。整局性能与温度仍未验收；用户已明确排除 x86/Intel 路线。


## 2026-09-30 集成验收

DS-04、DS-05、CX-03 与 QA-02 本批范围已完成：解析预检可靠失败且提前停止；两队动画在配置就绪后读取跑速；五配色与色盲配色接通 HUD 名称、角色、弹丸、出生台与墨迹。墨迹 RGBA 是阵营掩码，不包含显示队色，shader 按选定队色着色；CPU 归属、敌方覆盖与覆盖率不受选色影响。局中切换和设置 UI 不属于本批。

唯一入口 **41 项通过、0 失败**，见 [candidate-checks.txt](render-evidence/candidate-checks.txt)。[原生自动图形短验收](render-evidence/candidate-qa.json)覆盖真实输入/物理更新中的移动、射击、潜墨回墨、滚筒、死亡重生、隔离台阶上下与结算重开；起点/涂墨/伤害为测试条件，阶段等待被缩短。arm64 应用已集中导出一次并核验架构、签名与短时图形启动，见 [RENDERING.md](RENDERING.md)。仍不宣称完整网页等价、人工操作手感、持续性能或温度达标；没有发布 Release。

## 执行摘要：本 Demo 实际要用什么

| 优先级 | Godot 特性 | 对应实现 | 算迁完的证据 |
| --- | --- | --- | --- |
| 当前核心 | `PackedScene` / `Node3D`、`StaticBody3D`、`CharacterBody3D`、物理射线 | Tidewater 地图、玩家移动、武器命中 | 默认场景能加载；坡道/墙面碰撞与命中点能定位同一 `face_id`；规则短测与短时画面验收分别记录 |
| 当前核心 | `PackedByteArray`、`Image` / `ImageTexture` | 每个可涂面的归属格和惰性创建的墨迹显示 | 重复涂、敌方覆盖、墙面不计分正确；关闭显示层后覆盖率仍一致；记录纹理上传次数和帧时间 |
| 当前核心 | `_physics_process`、`CanvasLayer` / `Control` | 固定步长移动与战斗、选武器卡片、HUD 和结算 | 赛前/重生可换武器，存活期间不可换；真实地图完成一局并正确冻结计分 |
| 下一批 | `InputMap`、独立的玩家/机器人场景、音频节点 | 可改键输入、复用生命规则、命中/阶段音效 | 鼠标键盘操作不再散落在对局控制器；机器人遵守同一伤害与重生入口；声音可单独静音 |
| 条件采用 | `NavigationAgent3D`、`.tres`、`Decal` / `Trail3D` | 需要动态绕障、编辑器共享参数或短时视觉特效时 | 与现有固定路线/JSON/简单特效比较，证明目标行为或帧时间收益后再接入 |
| 暂不采用 | `DrawableTexture2D`、4.8 新渲染功能、`MultiplayerAPI` | GPU 墨迹实验与联机均独立立项 | 不得替换 CPU 权威计分；单机 Demo 验收不依赖这些功能 |

这张表是选型，不是完成状态。当前已经有第一至第三行的部分实现与无界面短测；“算迁完”还需要对应画面和完整对局验收。

## 1. 版本与迁移边界

- **用户决定（2026-09-29）：只面向 Apple Silicon / arm64；不再构建、导出或测试 x86_64、Universal 和 Rosetta 路线，也不再把 Intel Mac 验收列为交付门槛。除非用户明确重新授权，否则不要恢复 x86 工作。**

- 本目录已在 Git 管理下（`godot-port-prototype/`，`.godot/` 与 `build/` 已忽略）。改动前先确认工作区干净；迁移批次用独立分支，并在提交信息里写清"改了什么规则、依据哪个源文件行、跑了什么验证"。
- 当前本机为 **Godot 4.8.dev6**，`project.godot` 已写入 `4.8` 特性标记。4.8 仍是预览版；每次换引擎版本前，先把 `project.godot`、场景、脚本和资源纳入 Git 或保存独立快照，再执行导入。`.godot/` 是生成缓存，不作为源码提交。[4.8 dev6 发布说明](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-6/)
- 一个迁移批次只使用一个明确记录的 Godot 版本。若要回到稳定版，先在独立副本恢复对应版本的项目文件，再重新导入资源；不把 4.8 编辑后的唯一副本直接交给旧版继续编辑。跨越 4.7 时核对[官方 4.6→4.7 迁移清单](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html)。
- 保留网页游戏为行为基准。Godot 默认场景现为 Tidewater 地图、90 秒、1v1；旧平地样机可用 `run.sh --flat` 启动。网页配置的默认对局是 **180 秒、每队 5 人**，另有 90 秒选项。迁移每项规则时注明“与网页一致”或“样机简化”。依据：[config.js](../public/game/src/config.js)、[match.js](../public/game/src/game/match.js)。

## 2. 值得用的 Godot 特性

| 特性 | 在 INKWAVE 中的用途 | 采用条件 |
| --- | --- | --- |
| `SceneTree`、`Node3D`、独立场景 | 地图、角色、武器表现、HUD 分场景；对局状态由单独控制器管理 | 已有独立 [地图场景](tidewater_map.tscn)、[步行场](tidewater_walk.tscn)和默认[对局场景](tidewater_play.tscn)；后续把输入/HUD 从 `tidewater_play.gd` 拆出，避免继续扩大单个脚本 |
| `CharacterBody3D`、`StaticBody3D`、`CollisionShape3D`、射线查询 | 地图碰撞、坡道行走、跳跃、墙面接触与命中后定位可涂面 | 地图碰撞、水平加减速/转向、跳跃缓冲/离地宽限、低矮潜墨体积和基础己方墨墙攀爬已有短测；0.35 m 台阶、下台阶和临边足迹已有短测；高速落地减速/恢复已通过短测，人工攀爬/移动手感仍未验收。参考 [CharacterBody3D](https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html) |
| `InputMap` 动作 | 将移动、潜墨、射击、跳跃和选武器从硬编码键位抽离，便于键盘与手柄共用 | 拆分当前对局控制器的输入读取时一起迁；动作名使用 `snake_case`，保留现有键鼠默认操作。[官方输入示例](https://docs.godotengine.org/en/4.7/tutorials/inputs/input_examples.html) |
| `Resource` / `.tres` 数据 | 武器参数、地图描述、队伍配色等可编辑配置 | 多场景复用时使用；保留 `config.js` 中稳定的武器 ID 和单位，不在节点脚本中各存一份参数 |
| `PackedByteArray` + `Image` / `ImageTexture` + `ShaderMaterial` | 每表面 CPU 归属格负责规则；材质和纹理只显示归属结果 | [真实地图实验场](tidewater_play.tscn)已用 [多表面归属格](surface_ink.gd)驱动 [ImageTexture 显示层](surface_ink_view.gd)和计分。显示资源在首次涂墨时创建，最多 285 张独立纹理；长期帧成本未测，不能视为最终渲染方案 |
| `DrawableTexture2D` | 将来试验纹理绘制和减少整张纹理上传 | 只做隔离实验：该绘制 API 仍标为实验性，且 GPU 画面不能替代 CPU 的归属与得分数据。[官方类文档](https://docs.godotengine.org/en/4.7/classes/class_drawabletexture2d.html) |
| `CanvasLayer`、`Control`、`Label`、`ProgressBar` | 武器卡片、HUD、结算与响应式布局 | Tidewater 默认场景已有四图标卡片、顶部计时/覆盖率、墨量/生命/大招进度条、结果面板与中央准星；节点和数据绑定通过无界面短测，真实画面与完整 HUD 动画未验收。迁完整 UI 时保留可读性和中英文字体回退；4.8 的 `Label.auto_font_size` 可在长文本出现时试用。[4.8 dev4 说明](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-4/) |
| `Decal`、`Trail3D` | 命中贴花、弹道尾迹等短时特效 | 只用于视觉层，不能代替永久墨迹归属。**官方文档明确 Decals 只在 Forward+ 与 Mobile 可用**，Compatibility 不提供；此前本文写成"兼容渲染器支持贴花"是错的，已按 §2「渲染路线决策」纠正。[使用贴花](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html) |
| `NavigationAgent3D`、音频节点 | 后续机器人寻路、音乐和音效 | 当前 [临时蓝队](tidewater_bot.gd)沿安全路线巡逻，短距离看到玩家时在碰撞/地面检查后追击，失去目标沿追击路径退回；复杂绕障与动态目标点仍需导航，不以新增节点数量判断完成度 |
| `MultiplayerAPI` / RPC | 后续原生版联机 | 单机规则和状态边界稳定后单独设计。现有 Web/P2P 会话协议不会因改用 Godot 自动兼容；权威方必须校验伤害、涂墨与结果。[官方联机文档](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html) |

4.8 的纹理流送面向较多大纹理；当前是少量 SVG 图标、平地样机的一张动态纹理，以及真实地图的多张小墨迹纹理，暂不启用。接触阴影同样不属于旧无光照基线的瓶颈。[dev5](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-5/)、[dev6](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-6/)

**当前优先使用**：`CharacterBody3D`/静态碰撞、固定步长、CPU 归属格、`ImageTexture`、独立场景和 `Control`。**需要时再用**：`InputMap`（替换目前的直接键位读取）、`.tres`（需要编辑器中共享调参时）、导航和音频。**隔离实验**：`DrawableTexture2D`、贴花、`Trail3D` 与 4.8 新渲染能力；先证明画质或帧时间收益，再接入正式场景。`project.godot` 已切换为 Forward+；`run.sh --compatibility` 保留无 SSAO 的兼容启动方式。当前未接入 Decal、Trail3D 或 GPU 权威墨迹。详见本节末尾「渲染路线决策」。

### 本项目的数据与场景接口

| 原网页模块 | Godot 中的对应物 | 当前状态与下一步 |
| --- | --- | --- |
| [maps.js](../public/game/src/world/maps.js) + [level.js](../public/game/src/world/level.js) | `tools/export_tidewater_map.mjs` → `assets/maps/tidewater.json` → [tidewater_map.tscn](tidewater_map.tscn) | 63 个结构块、10 个坡道、两个出生点及碰撞已短测；地图已接入默认对局场景，画面和完整对局未验收 |
| `Level._buildFaces` + [paint.js](../public/game/src/world/paint.js) | `tools/export_tidewater_surfaces.mjs` → `assets/maps/tidewater_surfaces.json` → [surface_ink.gd](surface_ink.gd) + [surface_ink_view.gd](surface_ink_view.gd) | 289 个表面、285 个可涂面、61 个计分面与 **69,366 个有效计分格**；归属、覆盖、重涂、拉伸墨形与逐面纹理同步已短测，墨迹图形未试玩 |
| [actor.js](../public/game/src/game/actor.js) + [physics.js](../public/game/src/game/physics.js) | [tidewater_walker.gd](tidewater_walker.gd) + [tidewater_play.gd](tidewater_play.gd) → 后续正式玩家场景 | 已短测落地、坡道、水平运动、跳跃窗口、低矮潜墨碰撞体与安全站立、己方墨墙攀爬、敌墨伤害上限/延迟回血/重生保护及简化死亡重生；0.35 m 台阶/下台阶/临边足迹和蓝队基础生命规则已有短测；高速落地恢复已有短测；仍需原作伤害反应与人工手感验收 |
| [weapons.js](../public/game/src/game/weapons.js) + [config.js](../public/game/src/config.js) | `tools/export_weapon_config.mjs` → `assets/weapons.json` → [tidewater_combat.gd](tidewater_combat.gd) | 四主武器、炸弹及冲击波/墨雨使用源码参数；选武器、墨耗、命中/涂墨、炸弹、大招充能及两类大招的核心事件已有无界面短测；完整弹道、命中判定、动画与特效待迁 |

数据流固定为“网页源码 → 导出脚本 → 带 `schema` 与稳定 ID 的 JSON → Godot 场景/规则”。JSON 是生成物，改地图或表面规则时改原源码和导出器，再运行 `--check`；不要在 JSON、场景和脚本中分别手改同一份几何。射线命中以碰撞体的 `source_id`、命中点和法线查表面 ID，再把局部 `u/v` 交给归属格。运行时可以为性能建立 block→face 索引，但索引不得改变表面 ID 或计分结果。

### 新代码的接口约定

1. [tidewater_map.gd](tidewater_map.gd)只负责几何、碰撞、出生点和 `source_id → face_id` 定位；不计算归属或伤害。[surface_ink.gd](surface_ink.gd)只持有格子归属和面积计数；显示与音效不得写回它的内部数组。[surface_ink_view.gd](surface_ink_view.gd)消费脏格更新纹理；删掉或替换显示层，不得改变 `coverage()` 结果。
2. [tidewater_combat.gd](tidewater_combat.gd)按武器 ID 产生射击、命中、涂墨和伤害事件；[tidewater_play.gd](tidewater_play.gd)编排对局阶段、生命、重生和结算；[tidewater_bot.gd](tidewater_bot.gd)持有临时蓝队的巡逻、短距离追击、涂墨和攻击间隔。继续迁移时，把输入读取也从对局控制器移出，避免继续扩大单个脚本。每次拆分后，原有短测仍应通过。
3. 对外数据保持 `schema`、地图/武器稳定 ID、队伍编号（橙队 0、蓝队 1）和 `coverage` 的 0–1 语义。距离用米、时间用秒、速度用米/秒；跨层接口显式命名 `face_id`、`local_u`、`local_v`，不把纹理像素坐标或 HUD 百分数传入规则层。新增导出字段时，先更新导出器和读取校验，再更新消费者及对应短测。
4. 场景负责节点连接，规则脚本负责状态变更，视觉脚本负责表现；引用其他模块时优先传明确的地图、墨迹或角色对象。`get_meta("source_id")` 仅用于命中后的来源定位，不把节点名或子节点顺序当成持久 ID。测试不得只断言节点数量，还要核对可观察的归属、伤害、重生或计分结果。

### 渲染路线决策：Forward+（基础已实现，持续负载待验收）

**决定（2026-09-27）：目标渲染器为 Forward+，不再把 GL Compatibility 作为正式路线。**
2026-09-29 已将 `project.godot` 的两个渲染器字段改为 `forward_plus`，本机图形日志确认使用 Metal 4.0 / Apple M5。配置、规则检查、短时截图与导出结果见 [RENDERING.md](RENDERING.md)；该记录不代替持续帧时间或温度验收。
Forward+ 使用 RenderingDevice；在 macOS 上应按实际 Godot 版本和设备检查 Metal 后端，不能把 Forward+ 等同于 Vulkan。[Godot 渲染器说明](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

依据：

1. 交付目标是 macOS 单机应用（`export_macos.sh` 产出 arm64 `.app`），不是 Web 导出。Compatibility 的主要优势（最广硬件兼容、Web 导出必需）不在目标内。
2. 画面路线是 **Godot 干净简约风**（见 §4），但"墨迹显示要好看"恰好依赖 Compatibility 缺失的能力：
   - **MRT / 多渲染目标**：网页 [texlib.js](../public/game/src/world/texlib.js) 一次渲染写 albedo / normal / orm 三个附件；Compatibility 不支持 MRT。
   - **Decal**：官方文档明确 Decals 只在 Forward+ 与 Mobile 可用（见 §2 贴花一行），命中贴花不能按 Compatibility 推断。
   - **SSAO/SSIL 与后处理**：网页 [screenfx.js](../public/game/src/fx/screenfx.js) 的 GTAO + bloom + 色彩分级 + 暗角，在 Forward+ 对应 `WorldEnvironment` 的 SSAO/glow/Adjustment 或后处理 quad。
3. 温度仍以本机实测为准。Forward+ 的基础渲染开销可能高于 Compatibility；帧率上限、渲染分辨率和后处理也会影响负载。先保留当前低负载基线，切换时在同一场景比较帧时间和温度，不能预设哪项影响最大。

执行与验收清单（逐项证据见 RENDERING.md；未测项目保留为门槛）：

1. `project.godot` 的 `rendering/renderer/rendering_method` 与 `.mobile` 改为 `forward_plus`；确认真实入口仍是 `tidewater_play.tscn`。
2. 重新导入素材后运行 [tools/run_checks.sh](tools/run_checks.sh)。渲染器不影响规则层，**必须仍然全部通过**；任何失败都按规则回归处理，不要改断言迁就。
3. 图形启动一次，确认窗口、分辨率、HUD 布局、中文与 SVG 图标无回归；在同一 Mac、同窗口大小、同 1280×720、同墨迹覆盖率下记录帧时间，作为后续画面比较的基准。
4. 用 `export_macos.sh` 重新导出，确认 **arm64 能启动**（用户已排除 x86 路线），签名与短启动检查通过。

必须记录的风险：

- **设备兼容与负载都要验收。** 导出预设仅为 arm64，不再构建或验收 x86/Intel 路径。Apple Silicon 上仍需比较切换前后的画面、帧时间和温度。若未通过，保留 Compatibility 作为可玩的交付路线，并记录不能使用的 Forward+ 效果。
- 切换后所有按 Compatibility 推断的结论作废（例如"4.8 兼容渲染器支持贴花"）；§2 与 §4 里相关描述要跟着改。
- 不要把 Forward+ 当作"可以照搬网页全部特效"的许可：网页的渲染器、后处理参数与质量档（[config.js](../public/game/src/config.js) 的 `QUALITY`）仍需逐项对照，且必须先满足 §5 的帧时间与温度门槛。

## 3. 行为迁移规则

1. **先迁数据语义，再迁画面。** [config.js](../public/game/src/config.js) 是速度、伤害、射速、墨耗、对局时长与武器 ID 的来源；单位保持米、秒、每秒值。修改参数时记录原值、Godot 值及差异原因。
2. **运动用固定步长。** 原 [actor.js](../public/game/src/game/actor.js) 的水平加减速、反向制动、转向、跳跃缓冲、离地宽限、顶点/下落重力和终端下落速度已按源码参数迁入 `_physics_process`，墙面攀爬也有基础实现。kid 与潜墨体按源码的高度、半径和抬升量生成胶囊体，潜墨轴段退化为球体；kid 下边界为 `stepUp`，潜墨下边界为 `squidBodyLift`，站起前检查站立体是否有空间。已对照原 [physics.js](../public/game/src/game/physics.js) 接入 `stepUp`、`stepDown` 与 `footRadius` 足迹探针，并验证 0.35 m 台阶、下台阶和临边支撑；已接通 `hardLandSpeed`、`hardLandSlow` 与 `hardLandTime` 的减速和恢复，并有隔离短测。显示帧率与物理更新频率分别配置；规则短测不能替代实际手感验收。
3. **涂墨逻辑只有一个权威状态。** 原 [paint.js](../public/game/src/world/paint.js) 按可涂表面保存约 0.25 米的格子归属；地面/坡面的有效 turf 格用于面积计分，墙面可涂供攀爬但不计入 turf。Godot 的纹理、贴花和粒子只从该状态生成，不反向决定归属。重复涂己方格不加分，敌方重涂同时更新双方计数；被地图几何**或场景道具碰撞盒**遮挡的格子不计入分母——导出器必须用与运行时相同的 `Level` 构造（含 `dressingFor()` 的道具碰撞盒，见 `tools/lib/runtime_level.mjs`），漏掉道具会把分母从 69,366 抬到 70,180（+1.16 %），使每个对局的覆盖率整体偏低。掠射命中的墨团会沿射击方向拉伸，该拉伸同时作用于计分格，不能只做视觉。`coverage(team)` 对规则层返回 **0–1 比例**，HUD 才乘以 100 显示百分数。
4. **区分样机网格与正式地图。** 旧平地场景的 [paint_field.gd](paint_field.gd) 是 40×40 米、256²、仅地面的简化格。默认真实地图场景已用 [surface_ink.gd](surface_ink.gd) 的表面 ID、局部坐标和格子归属驱动己方墨速度、敌墨减速/伤害、基础墙面攀爬、低矮潜墨碰撞体、HUD 及计分；接完整玩家时还要加入伤害反馈与正式裁判。不要把平地 `x/z` 采样直接套到墙面。墨迹视觉的扩张动画和甩墨拉伸需分别对照网页实现，不能用当前格子显示宣称已完成。
5. **武器按状态和事件迁。** 射手连续射击、滚筒滚动/甩墨、蓄力狙按住/松开发射、爆破枪飞行/爆炸各保留其原始墨耗、冷却、伤害和涂墨事件；共用墨水炸弹按住/松开投掷、碰地引信、爆炸涂墨和距离伤害已有短测。玩家造成的新涂墨面积向所选武器的大招充能；冲击波与墨雨使用源码持续时间、范围和伤害参数，死亡充能减半。大招规则已有无界面短测，完整画面、粒子、音效及手感仍待验收。命中判定与特效分开，以 [weapons.js](../public/game/src/game/weapons.js)、[actor.js](../public/game/src/game/actor.js) 和 `config.js` 对照。遵照本项目选择：赛前及重生等待期间可换武器，活着的对局过程中不切换。
6. **对局状态显式化。** 原 [match.js](../public/game/src/game/match.js) 的状态是 `intro → playing → finish → judge → results`，没有独立 `countdown` 状态；`intro` 的原作表现是镜头/队伍介绍，数字倒计时发生在 `playing` 的最后 10 秒。真实地图样机额外有赛前 `setup`，按 Enter 后等待 4.2 秒才开始扣 90 秒对局时间；目前 `intro` 只显示简化文字倒数，尚未移植镜头与队伍介绍。终场冻结 2.6 秒后取权威墨迹覆盖率，裁判阶段约 5.1 秒，再进入结果。最后 10 秒提示与对局时长都从 `assets/weapons.json` 的 `match.finalCountdown` / `match.durations` 读取（`ROUND_DURATION_OPTION` 选择第几个选项），不再在脚本里硬编码。原作覆盖率相同时随机决定胜方，样机也保持这一规则。90 秒和 1v1 仍是样机选项，原作默认 180 秒、每队 5 人。
7. **生命规则读同一墨迹状态。** 真实地图玩家使用 [actor.js](../public/game/src/game/actor.js) 的敌墨每秒伤害、累计上限、最低 1 点生命、离墨后衰减、延迟回血、己方墨潜行加速回血与重生保护；原作初次站在出生平台时无敌时间为 0，只有重生后使用 `spawnInvuln`。落海死亡不受无敌保护阻挡。临时蓝队现已使用相同的敌墨伤害、累计上限、普通回血和重生保护配置；其简单 AI 没有潜墨形态，因此没有潜墨加速回血。新增普通命中伤害时经过统一的玩家受伤入口；敌墨按非致死规则扣血，并分别验证无敌、致死和重生状态。

## 4. 地图、素材与 UI 规范

- 网页地图由几何定义生成，Godot 版需要重建几何、碰撞和可涂面映射。[两张 PNG 光照图](../public/game/assets/lightmaps/)依赖原地图 UV；只有 UV 对齐并核验画面后才复用，不能直接铺到样机地面。
- 四个武器图标从 [ui-icons.js](../public/game/src/ui/ui-icons.js) 导出为 `assets/ui/*.svg`；两份 WOFF2 字体复制到 `assets/fonts/`。导出脚本是图标的再生成入口，手工修改图标需同步源或注明分叉。中文字体使用可验证的回退方案。
- 网页的 CSS/Canvas 动效与程序化角色、场景纹理不是现成贴图。Godot 里按功能重建：先清晰可用的卡片/HUD，再做装饰动画。比较界面时固定 1280×720，并额外检查窗口缩放和中文溢出。
- 当前 [角色外观脚本](tidewater_character_visual.gd)按原角色的脚底、面朝方向和头部高度生成低面数人形，加入阵营色、墨罐、潜墨体和四种武器轮廓。它响应 `set_form`/`set_weapon` 和只复制跑速标量的 `configure_animation`，读取速度/位置差分以驱动基础待机/行走动作，规则状态仍由控制器和战斗脚本决定；替换成正式模型时保持这个单向接口，并核对第三人称镜头遮挡、动作方向与低矮潜墨碰撞体。无界面 [外观短测](tools/check_tidewater_visual.gd)不等于画面验收。

## 5. 性能与验证门槛

- 默认样机和真实地图实验场均将显示帧率及物理步长设为 30；这只是负载上限，**不是温度承诺**。旧 [paint_field.gd](paint_field.gd) 墨迹变脏时上传整张 256² 纹理；新显示层启动时不创建墨迹网格/纹理，只为首次涂墨的面创建资源，此后仅上传发生改变的面。最多仍可能达到 285 个独立网格与纹理。后续记录涂墨次数、CPU 脚本时间、帧时间和纹理上传频率，再决定是否合并材质/网格、改用 atlas 或试验新纹理 API。[Godot Profiler](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/the_profiler.html)
- 当前设备运行 Godot 曾达到 90°C 以上，因此日常批次只做静态检查和必要的短时无界面规则检查，**不自动启动编辑器或持续游戏试玩**。2026-09-27 做过数帧图形截图，目视检查了赛前/开局静态布局并据此修复菜单溢出；这只能证明这些时刻的渲染，不能声明整局画面可玩。完整 90/180 秒对局和温度测试独立安排；在相同 Mac、窗口大小、帧率与场景下比较，记录传感器名、室温、运行时长和最高温。设备再次明显升温时停止该次测试。
- **渲染器切换的验证门槛（Forward+，见 §2「渲染路线决策」）**：切换后规则短测必须仍然全部通过（渲染器不影响规则层，失败即视为回归）；必须验证 arm64 的导出程序能启动（x86 已由用户排除）；帧时间与温度要与切换前在同一 Mac、同窗口大小、同分辨率、同墨迹覆盖程度下比较，不能只报"能跑"。
- 对照用例至少覆盖：空地/己方/敌方墨的速度和回墨、覆盖率重涂、四种武器的墨耗/命中/涂墨、死亡后换武器、时间结束结算。声明“已移植”必须同时附对应的可重现用例与结果；截图只能证明画面，不证明手感或性能。
- **先跑唯一入口**：`NODE=<node> godot-port-prototype/tools/run_checks.sh`。它会依次做素材导入、5 个导出器 `--check`（都是只读的，不得写生成物）、解析预检（失败立即停止）和其余 `tools/check_*.gd`，输出 `PASS/FAIL` 汇总表并以非 0 退出表示失败。逐个手跑脚本是这套东西漂移的原因：曾经有 2 个短测长期失败而文档仍写"通过"。
- 判定一个短测通过：退出码为 0、输出含 `PASS`、且日志中没有脚本或解析错误；仅看退出码不足以证明 GDScript 已加载。runner 对每个检查有超时看门狗（`CHECK_TIMEOUT`，默认 120 秒）：脚本错误会让 SceneTree 不走到 `quit()`，没有超时会整个套件无输出地挂住。
- 若 CLI 名称不是 `godot`，用对应的 Godot 4.8 可执行文件；node 不在 PATH 时用 `NODE=` 指定。规则短测重点看大招 [check_tidewater_special.gd](tools/check_tidewater_special.gd)、HUD [check_tidewater_hud.gd](tools/check_tidewater_hud.gd) 与整局时间模拟 [check_tidewater_full_round.gd](tools/check_tidewater_full_round.gd)。加速时间模拟不能证明真实帧率或手感；导出器 `--check` 只能证明数据与网页源码一致，不能证明规则正确。

## 6. 可交付批次

| 批次 | 完成条件 |
| --- | --- |
| A：当前样机 | 平地单机循环、四武器核心行为、HUD；保留简化标识。已做短流程验证，完整对局和温度未验收 |
| B：真实地图与移动 | 一张地图的几何/碰撞、坡道与墙面、独立可涂面、攀爬；同一涂墨状态驱动移动和裁判 |
| C：规则与内容 | 完整四武器行为、炸弹与大招、机器人、正式对局状态和人数；逐项记录与网页差异。炸弹和两类大招的核心事件已短测，完整表现、机器人策略和人数仍在迁移 |
| D：Mac 应用 | [导出预设](export_presets.cfg)与[无界面导出脚本](export_macos.sh)已添加，本机已安装官方 4.8.dev6 模板；当前仅导出 arm64 `.app`（早期 Universal 记录不再作为当前路线）；签名、资源包及两帧无界面启动通过。仍需窗口画面、输入、整局和温度验收。向他人分发时再处理正式签名与公证。[macOS 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html) |
| E：联机 | 单独立项：明确权威方、同步哪些输入/涂墨事件及 Web 版是否互通；不得把单机样机视为已有联机能力 |

历史批次状态（2026-09-28，以 `tools/run_checks.sh` 全部通过为证）：

- **已完成**：基线入库；统一验证入口；导出分母修正（含道具碰撞盒）与两个导出器共用同一 `Level` 构造；配置改为整体导出并真正消费 `match`；弹道拖尾涂墨、圆盘散布与 bloom、CPU 拉伸、滚筒碾压冷却与起速曲线、弹丸逐类型存活时间/重力/阻力、命中体改为身体胶囊；空墨回墨死锁与潜墨开火丢失；射手按 30 Hz 弹体更新补偿发射角；蓝队四武器核心攻击与玩家共用弹体、射线、地形命中、伤害和涂墨通道，墨耗/回墨读同一配置；蓝队从同一墨迹网格读取敌墨伤害，按玩家配置处理伤害上限、普通回血、重生时长与无敌保护；玩家 `stepUp`、`stepDown` 与 `footRadius` 足迹探针、10 个朝向弹簧参数通过隔离场景短测；爆破枪 `burstRadius` 用于短暂可见爆炸球体。
- **未完成（B/C 剩余）**：蓝队尚未共用玩家的完整 WeaponRunner 状态、潜墨/潜墨加速回血，也仍沿固定路线涂墨；目前四武器是 1v1 样机的简化 AI，瞄准与蓄力/滚筒起手没有原版反应和动画。`ledgeAssist` 目前只参与落地探针，`squidBodyLift`/`hardLand*` 等移动手感字段尚未完整消费；足迹探针和朝向弹簧通过规则短测，实际手感仍需图形试玩。
- **独立门槛**：Forward+ 基础渲染已实现，见 [RENDERING.md](RENDERING.md)。完整图形试玩、整局帧时间与温度仍需独立验收。

上述 2026-09-28 未完成字段状态已由本页 2026-09-30 状态取代。当前决策：按授权已实现渲染基础与本批集成；B/C 剩余规则仍按原边界推进，不以画面升级声明规则迁完。Forward+ 已有短时画面证据；Mac 导出、持续图形试玩和温度分别记录验收状态。Godot 4.8 的新增视觉特性只在隔离实验中评估，不能替代这些规则门槛。

### 每个迁移批次的提交记录

1. **定基准。** 写出网页源码位置、输入、状态变化和可观察结果；参数从 `config.js` 等源文件导出，固定 ID、单位与默认值。若有简化，写明与网页的差异及原因。
2. **接完整链路。** 一次实现一个可观察事件链，例如“武器命中 → 归属格改变 → 面积变化 → HUD 读取”。地图/墨迹/战斗/对局/显示各由上文约定的模块负责，避免视觉反写规则。
3. **分层验证。** 导出器运行 `--check`；规则跑对应的短时无界面检查并检查日志；画面、输入、整局和温度另行验收。只有静态或无界面证据时，状态写“规则短测通过”，不要写“可玩已验收”。
4. **记录边界。** 每批留下网页源码、Godot 文件、可重复命令与结果，以及尚未验证的画面/性能问题。性能改动要在同一地图、分辨率、帧率、墨迹覆盖程度下比较，不用温度单值代替帧时间与脚本耗时。
