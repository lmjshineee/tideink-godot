# 渲染实现与验证 · 2026-09-30

## 试玩反馈修复候选 · v0.3.0-preview.2 · 2026-09-30

发布暂停，先修复真实试玩问题。原 v0.3.0-preview.1 的 51 项规则检查不能证明角色动画、脚底高度、阴影或持续温度正确。

- **腿部入地**：`hips` 静止位置为 `(0,0.64,0)`，旧动画每帧写到约 0，使脚落到 -0.55 米。修为静止位置加起伏；新增骨盆/脚底高度检查。
- **武器抽搐**：固定瞄准时旧 30 Hz 朝向弹簧每帧持续跳动 0.2118 rad（约 12 度）。以 120 Hz 子步积分保留源速度/加速度上限，稳态跳动归零；30/60 Hz 回归。原作两臂 IK 离线采样四武器持握/瞄准/动作，运行时四元数平滑混合；甩墨动作与蓄力起点对齐。并非实时完整原作 IK。
- **墨鱼/卡模**：玩家 Shift 检查己方墨面或己方墨墙，低顶安全退出规则保留；新回归覆盖敌墨退出。台阶升起前检查完整身体，低顶拒绝时回退安全位置；真实输入低顶台阶检查通过。铁网独立层，墨鱼/弹丸穿过，仍不可涂。
- **HUD**：Tab 展开地图、队伍状态，投影保持比例、出生点在底部；隐藏时不刷新第二张地图。重排设置、增加持久化 75/100% 画面精度。
- **负载/阴影**：启动即 30 FPS，默认 75% 3D 分辨率（像素数为原来的 56.25%），关闭 SSAO，1024 / 35 m 硬阴影消除滤波噪点。旧/新相同 1280×720、十人场景的 65 帧短采样记录：旧启动 253 ms、TIME_PROCESS 平均 33.49 ms/最大 341.93 ms；新启动 246 ms、平均 29.06 ms/最大 30.64 ms。采样含启动、滤波最终又做过调整，无 GPU 稳态对照和传感器温度，不据此承诺长期温度下降或精确性能提升。
- **桥梁边界**：双地图 61 + 59 个硬质地面面的有效墨格可涂，不能替代用户未定位桥梁的视觉复现；此项保留待验收。尚未进行人工完整对局或定位全部卡模位置。

最终 54 项入口以及隔离用例、原生短核验见 `render-evidence/feedback-*`。重建 arm64 本地候选包，未推送或公开发布。源码快照到具体公开仓库的推送此前被自动审批拒绝，本轮不重试。


## 最新候选：v0.3.0-preview.1 双地图团队版

角色原版几何/蒙皮、HUD 与菜单、5v5 和 Kelpline 本批完成。见 [README](README.md) 的当前功能与迁移边界；下方 42/41/34/32 项及 1v1 是历史结果。

- **工作区与独立发布快照均为 51 项通过、0 失败**（10 个导出校验 + 41 个短测）。最终规则入口：[release-checks.txt](render-evidence/release-checks.txt)。另有解析门槛五项隔离用例和跑速 6/12 非默认初始化检查。
- 新增两个团队短测：十角色敌我命中/群体伤害/保护重生/原版骨骼与双地图权威计分；九机器人在两地图六秒模拟时间内全部离开出生区。设置两项短测从上一发布版并回。
- 原生 Forward+ / Metal 短验收：[release-gui.txt](render-evidence/release-gui.txt)。鼠标开始、结果再开、设置保存和 110% 缩放；地图下拉以 PopupMenu 选择信号触发。1280×720 与 960×540 均检查菜单控件在边界内。
- 截图：[角色](render-evidence/release-characters.png)、[Tidewater 菜单](render-evidence/release-tidewater-menu.png)、[缩放](render-evidence/release-tidewater-small.png)、[名单](render-evidence/release-tidewater-roster.png)、[战斗](render-evidence/release-tidewater-battle.png)、[结果](render-evidence/release-tidewater-results.png)；[Kelpline 菜单](render-evidence/release-kelpline-menu.png)、[战斗](render-evidence/release-kelpline-battle.png)、[结果](render-evidence/release-kelpline-results.png)及[设置](render-evidence/release-settings.png)。均已目视核验。
- GUI 场景为短时自动验收：中场位置和数秒出生保护是截图条件，intro 等待缩短；没有把短流程或源码规则检查当作人工手感、完整图形对局、长期性能或温度验证。
- 发布应用仅 Apple Silicon / arm64，临时签名、未经 Apple 公证；导出、签名/架构/无界面启动和 12 帧原生应用启动通过；ZIP 解压后再次校验签名与 arm64。见 [导出日志](render-evidence/release-export.txt)、[应用启动](render-evidence/release-app.txt)及 [构建/ZIP 哈希](render-evidence/release-build.json)。相同版本引擎直接加载最终 PCK 的两地图/十角色检查也通过，见 [PCK 检查](render-evidence/release-pck-check.txt)；这与应用本身的短启动是两项不同证据。


默认 Tidewater 场景已接入 Forward+。**交付只面向 Apple Silicon / arm64；按用户最新要求，不再构建或验证 x86_64、Universal 或 Rosetta。**画面采用简约受光材质：天空/环境反射、方向光及阴影、轻量 SSAO、2× MSAA、地图表面的细缝、角色高光，以及湿润的橙蓝墨迹。旧网页与 CPU 归属/计分规则没有修改。

![当前战斗画面](preview-rendering.png)


## 当前候选：赛前操作批次（2026-09-30）

1. **三项交付：** 菜单加入五配色/色盲开关、导出的 90/180 秒选择和鼠标玩家/机器人武器选择。配色切换重建赛前场景，保留已选武器与时长；偏好限当前进程。开局后禁止改设置和活着换武器，重生只允许玩家武器选择。
2. **42 项通过、0 失败**（5 个导出器 + 37 短测），[全套输出](render-evidence/setup-checks.txt)。新增 `check_setup_settings.gd` 验证 GUI 信号、非默认时长、defaultDuration 回退、重建后的选项保留、intro/playing/respawn 的限制。
3. **原生 GUI 短验收：** [1280×720 菜单](render-evidence/setup-menu.png)、[960×540 色盲模式](render-evidence/setup-small-colorblind.png)、[重生武器选择](render-evidence/setup-respawn.png)。真实鼠标事件点选玩家/机器人按钮和色盲复选框；配色和时长以 PopupMenu.index_pressed 信号触发下拉选择路径（没有模拟 OS 下拉弹窗点选）。已目视核验文字和布局，并断言缩放后各设置控件均在菜单边界内。[GUI 日志](render-evidence/setup-gui.txt)。
4. **对局回归：** [自动原生输入/物理流程日志](render-evidence/setup-play.txt)、[机器记录](render-evidence/setup-play-qa.json)，原来的七项流程均通过。测试条件与缩短等待同前一批，不宣称人工手感或完整 90/180 秒图形对局验收。前一批的截图和记录保留。
5. **更新候选应用一次：** [导出/签名/无界面短启动](render-evidence/setup-export.txt)及 [12 帧图形启动](render-evidence/setup-app.txt)通过，Metal / Forward+，只含 arm64；[构建哈希与架构/签名记录](render-evidence/setup-build.json)。应用仍为 `build/INKWAVE Demo.app`，未发布 Release。没有恢复其他架构或进行长期温度测试。

来源：`public/game/src/ui/menus.js` 的时长选项/色盲设置及 `config.js` 的配色、时长、武器顺序；Godot 使用既有导出数据。完整 AI、完整战斗动作/特效和持续负载仍为后续范围。

复现入口：

```sh
NODE=$(command -v node) CHECK_TIMEOUT=20 ./godot-port-prototype/tools/run_checks.sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot-port-prototype --script res://tools/capture_setup.gd
/Applications/Godot.app/Contents/MacOS/Godot --path godot-port-prototype --script res://tools/capture_candidate.gd -- --label=setup-play
./godot-port-prototype/export_macos.sh
```

## 前一批候选：CX-03 与 QA-02（2026-09-30，历史）

剩余两项已完成，本批停止。下方 2026-09-29 的 34/32 项结果和旧停止点保留为历史，不是最新验收。

1. **规则检查：41 项通过、0 失败**（5 个导出器 + 36 个短测），见 [完整输出](render-evidence/candidate-checks.txt)。`check_team_palette.gd` 对五组配色和色盲配色逐一创建场景，核对两队角色/弹丸/出生台、墨迹 shader 参数与 HUD/结算队名；同一涂墨输入的 CPU 归属和覆盖率完全一致。已去掉 `surface_ink_view.gd` 的队色副本豁免。
2. **墨迹编码：** RG 为两队归属通道，A 为覆盖，作为线性数据采样；shader 以 `mask.g / mask.a` 恢复第二队权重并用 `team_a/team_b` 着色。交界不再依赖某个配色的蓝色分量差，选色不改变 CPU 规则。配色在场景创建前选定，HUD/材质和 view 在初始化时取值；没有局中切换/UI。
3. **实际图形检查：** [非默认泡泡糖/薄荷](render-evidence/palette-mint-combat.png)、[色盲太阳/海洋](render-evidence/palette-colorblind-combat.png)和对应菜单截图；已目视核验角色、出生台、两队墨迹交界及中文队名。HUD 缩小队名字号以容纳四字队名。[配色日志](render-evidence/palette-mint.txt)、[色盲日志](render-evidence/palette-colorblind.txt)。这些画面冻结模拟，仅作颜色和布局证据。
4. **短时自动图形流程：** `tools/capture_candidate.gd` 使用 Input 状态和 Viewport 事件分发，实际运行玩家控制器及对局物理；移动、射击涂地、Shift 潜墨回墨、滚筒、击倒重生、可见隔离 0.35 m 台阶上下、结算和 Enter 重开均通过。[机器可读记录](render-evidence/candidate-qa.json)、[日志](render-evidence/candidate-qa.txt)、[滚筒画面](render-evidence/candidate-live.png)、[结算](render-evidence/candidate-results.png)、[重开](render-evidence/candidate-restart.png)。为保持短时运行，起点/墨量/涂墨/伤害是测试条件，intro/respawn/finish/judge 等待被缩短；不是人工手感或真实 90 秒对局验收。事件分发接口见 [Godot Viewport.push_input](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-push-input)。
5. **一次 arm64 候选导出：** [导出、签名及无界面短启动](render-evidence/candidate-export.txt)成功；[候选 .app 图形启动](render-evidence/candidate-app.txt)为 Metal 4.0 / Forward+、12 帧后退出 0，`lipo -archs` 只返回 `arm64`。文件为 `build/INKWAVE Demo.app`，未发布 Release，未运行其他架构。

未补做长期帧率、温度、人工键鼠手感和完整图形对局验收。以前的短时帧时间仅是历史采样，本次不据此声称性能提升。

复现剩余两项的入口（仓库根目录，图形命令不要加 `--headless`）：

```sh
NODE=$(command -v node) CHECK_TIMEOUT=20 ./godot-port-prototype/tools/run_checks.sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot-port-prototype --script res://tools/capture_candidate.gd
/Applications/Godot.app/Contents/MacOS/Godot --path godot-port-prototype --script res://tools/capture_rendering.gd -- --minimal --label=palette-mint --palette=1
/Applications/Godot.app/Contents/MacOS/Godot --path godot-port-prototype --script res://tools/capture_rendering.gd -- --minimal --label=palette-colorblind --colorblind
./godot-port-prototype/export_macos.sh
```

## 2026-09-29 交付：地图与场景渲染（历史）

本批已完成，按用户要求在此停止。场景直接复用原网页程序化模型与 Canvas 图案：144 处道具布置，加上装饰与港口远景，按材质合并为 27 个网格；另接入 18 面壁画、旗帜图案与轻微摆动、出生台图案、原地图不同地面材质，以及原生海面。已有 82 个道具碰撞块和 CPU 计分保持不变。

- **34 项通过、0 失败**（5 个导出器 + 29 个短测）：[检查输出](render-evidence/scenery-checks.txt)。新增检查覆盖视觉不增加碰撞、原碰撞和计分面保留、旗帜材质与出生台对齐。
- 实际图形截图：[战斗](render-evidence/render-scenery-combat.png)、[出生区壁画](render-evidence/render-scenery-spawn.png)、[小店和自动售货机](render-evidence/render-scenery-kiosk.png)、[俯瞰](render-evidence/render-scenery-overview.png)、[菜单](render-evidence/render-scenery-menu.png)、[缩放](render-evidence/render-scenery-small.png)、[墙面](render-evidence/render-scenery-wall.png)、[坡道](render-evidence/render-scenery-ramp.png)。
- 最终应用通过 arm64 导出、签名和无界面启动；另完成 12 帧原生图形启动，Metal 4.0 / Forward+，退出 0。[图形启动日志](render-evidence/scenery-app.txt)
- Apple M5、1280×720、30 FPS 上限，固定画面 30 帧：[原始采样](render-evidence/render-scenery.json)。帧间隔中位数 **33.325 ms**、P95 **33.542 ms**；视口渲染 GPU 中位数 **7.226 ms**、CPU 中位数 **0.132 ms**。这是冻结场景的短时检查，不代表完整对局、长期帧率或温度。

`tools/export_tidewater_visuals.mjs` 在本地浏览器运行原版 `props.js`、`decor.js`、`environment.js` 和壁画生成代码，导出 `assets/scenery/tidewater_visuals.glb` 与 `murals.png`。浏览器仅用于离线生成素材；Godot 运行不依赖浏览器。普通 `node tools/export_tidewater_visuals.mjs --check` 只核对源文件与产物指纹、布置数量及碰撞数量，不启动浏览器，也不重新生成素材。重新生成时设置 `PLAYWRIGHT_MODULE` 为本机 Playwright 模块入口，运行该导出器而不带 `--check`。

**仍有的视觉差距：** 海水与出生台采用 Godot 近似着色；原作天空云层、出生屏障、灯塔光束、远景楼窗效果未迁入；船、海鸥等保留静态模型。角色仍是简化模型，完整角色动作、武器动画、喷射/命中/大招特效与动态 HUD 尚未完成。本批不宣称已达到原版全部效果。接续见 [COORDINATION.md](COORDINATION.md)。

以下记录保留为此前渲染基础批次的实现和对照证据；其中 32 项结果与旧采样并非本次最新结果。

## 渲染基础批次的实现边界

1. `tidewater_environment.tscn` 为地图、步行场和默认游戏共用的环境。保留 1280×720、30 FPS 和 30 Hz 物理更新；没有开启额外的 GI、SSR、体积雾或全屏粒子。
2. `tidewater_surface.gdshader` 按物体尺寸生成原图案对应的瓷砖、混凝土、木板、集装箱波纹、坡道防滑与安全条纹，地图仍使用原 JSON 的几何、碰撞与配色。角色保留原低面数模型，改用受光和 clearcoat 材质；HUD 保持原数值来源。
3. `surface_ink.gdshader` 读取同一份 CPU 归属纹理：插值轮廓、按阵营权重确定交界、少量边缘抗锯齿、法线细纹与高光。**视觉轮廓与 0.25 米规则格存在约半格的偏差**；格中心归属、速度、攀爬和计分仍由 CPU 决定。没有流动/扩张动画，没有新增 GPU 权威状态。
4. 显示网格补齐每个面的法线、切线和顺时针三角形朝向。原无光照版本的朝向在受光后会翻转法线，导致墨迹颜色被反射吞没；已通过所有 285 个可涂面的几何检查和墙/坡截图验证。墨迹接收阴影但不投射阴影，避免覆盖层给底面造成错误阴影。
5. 保留按需创建资源、只上传脏面的机制；`texture_upload_count` 可观测更新次数。检查覆盖首次创建、敌方覆盖、空更新零上传和删除显示层后归属/分数不变。
6. `run.sh --compatibility` 提供备用启动方式。实测可以显示新材质和阴影，但没有 SSAO，色调与 Forward+ 存在差别。旧平地样机仍可通过 `--flat` 启动。

着色器接口依据 Godot 官方的 [Spatial shader 文档](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/spatial_shader.html)；环境属性依据 [Environment 文档](https://docs.godotengine.org/en/4.6/classes/class_environment.html)。最终可用性以上述版本的实际图形启动为证。

## 验证结果

环境：Godot `4.8.dev6.official.8898c2b3d`，Apple M5。原代码基线为 Git `5a86d09`；基线快照与新版本使用同一个 `capture_rendering.gd`，固定随机种子、相机、窗口尺寸与涂墨输入。

- 唯一规则入口：**通过 32，失败 0**（4 个导出器 + 28 个检查）。完整输出：[checks.txt](render-evidence/checks.txt)。新增几何检查包含墙面、地面和坡道；不以截图代替规则验证。
- 图形检查：[菜单](render-evidence/render-forward-menu.png)、[对战](render-evidence/render-forward-combat.png)、[俯瞰](render-evidence/render-forward-overview.png)、[960×540 缩放](render-evidence/render-forward-small.png)、[墙面覆盖](render-evidence/render-forward-wall.png)、[坡道覆盖](render-evidence/render-forward-ramp.png)。实际检查了天空/阴影、墨迹两队颜色、中文和武器图标。截图工具冻结模拟，不代表真实键鼠试玩或完整一局。
- [旧版对照](render-evidence/render-baseline-combat.png)与[备用渲染](render-evidence/render-fallback-combat.png)均保留。图形日志没有 shader/脚本错误。
- 导出目标已按用户要求从 Universal 改为仅 `arm64`；最终包已重新通过 `export_macos.sh`、签名及 arm64 短启动检查；`lipo -archs` 实测只返回 `arm64`。
- arm64 图形启动 12 帧，日志为 **Metal 4.0 / Forward+**，退出 0。用户要求停止前产生的 x86/Rosetta 记录仅作为历史保留，不再继续该路线，也不作为今后的验收门槛。[导出启动记录](render-evidence/export-checks.txt)

## 短时采样

固定战斗画面先预热 20 帧，再记录 30 帧。两队覆盖率分别为 `0.0028111755` 和 `0.0008938096`（0–1 比例），三组样本均为一个已创建墨迹面。额外墙/坡涂墨在测量完成后才生成。

| 样本 | 帧间隔中位数 | 帧间隔 P95 | 视口渲染 CPU 中位数 | 视口渲染 GPU 中位数 |
| --- | ---: | ---: | ---: | ---: |
| 原无光照 Compatibility | 33.383 ms | 35.603 ms | 1.989 ms | 未提供 |
| 新 Forward+ | 33.345 ms | 33.779 ms | 0.864 ms | 5.295 ms |
| 新材质 Compatibility 备用 | 33.306 ms | 34.491 ms | 5.660 ms | 未提供 |

原始数据：[baseline](render-evidence/render-baseline.json)、[forward](render-evidence/render-forward.json)、[fallback](render-evidence/render-fallback.json)。CPU/GPU 列是 Godot 视口渲染计时，不是总帧时间或游戏脚本时间；Compatibility 返回 GPU 计时 0，按缺失处理。帧间隔包含 30 FPS 限制等待。**这些短样本只能证明固定画面能按目标帧率呈现，不能用来宣称性能提升或长期稳定 30 FPS。**

没有进行 90/180 秒真实对局、持续负载、温度或完整输入手感验收；当前也没有帧时间/温度联合基准。保留兼容启动方式，持续负载仍是迁移规范的独立门槛。

## arm64 导出模板

本机 4.8.dev6 官方模板归档只包含合并架构二进制，直接选择 arm64 时 Godot 找不到 `godot_macos_release.arm64`。`export_macos.sh` 现在先调用 `tools/prepare_arm64_template.py`，从已安装模板中仅提取 arm64 原生部分，生成 `.godot/arm64-template.zip`；不修改已安装模板，不执行其他架构。导出脚本也会核对最终二进制只能含 arm64。项目已启用该导出目标要求的 ETC2/ASTC 纹理导入。

此步骤使用 macOS 的 `lipo` 与 `python3`；默认读取 `~/Library/Application Support/Godot/export_templates/<版本>/macos.zip`，可通过 `GODOT_TEMPLATE_DIR` 指定模板目录。

## 复现

在仓库根目录运行：

```sh
# 正常进入游戏；备用模式在末尾追加 --compatibility。
./godot-port-prototype/run.sh

# 全部规则检查。
NODE=$(command -v node) ./godot-port-prototype/tools/run_checks.sh

# 数秒后自动退出的图形截图；不要加 --headless。
/Applications/Godot.app/Contents/MacOS/Godot \
  --path godot-port-prototype --log-file .godot/render-forward.log \
  --script res://tools/capture_rendering.gd -- --label=forward

# 重新导出当前版本。
./godot-port-prototype/export_macos.sh
```

截图与 JSON 写到 `.godot/render-<label>*`；本次验收副本保存在 `render-evidence/`，该目录与预览图均排除在应用导出之外。旧原版截图 `preview.png` 与 `preview-tidewater.png` 保留。
