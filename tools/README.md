# 原生验证与维护工具

从项目根目录运行 `./tools/run_checks.sh`。顺序：资源导入 → 编译预检 → 本地资源完整性 → 所有规则／场景检查。任一门失败立即停止；退出成功且有独立 `PASS:` 行才算通过，日志在 `.godot/`。不需要 Node、浏览器或 Web 源码。

脸发近景使用 `capture/capture_face_sculpt.gd -- --baseline=/保存四个旧派生GLB的绝对目录 --output=/新的绝对目录`（通过原生 Godot `--path . --script res://tools/capture/capture_face_sculpt.gd` 启动）。固定镜头／灯光／姿态对照旧、新模型，保存四种脸型的正面／三分之四／侧面、灰模、后脑／头顶、眨眼／表情及资源 SHA256；`comparison-front.png` 上排旧几何、下排新几何。旧模型以运行时 GLTF 导入并按骨骼名称匹配当前绑定，避免误用墨形的同名材质。这里只建立受控画面，不自动确认人工审美。完整运动／八武器／两队服装仍使用 `capture/capture_archetypes.gd`。

| 工具 | 用途 |
| --- | --- |
| `lib/runtime.sh` | 运行／验证／导出共用引擎发现与导入缓存 |
| `lib/source_inventory.gd` | 递归收集 `src/`，不让目录迁移导致漏检 |
| `lib/asset_inventory.gd` | 收集本地资源，排除 `.import`、`.uid` 与清单自身 |
| `../tests/godot/check_scripts_parse.gd` | `GDScript.reload()` 编译门；空目录失败 |
| `../tests/godot/check_asset_integrity.gd` | 完整资源清单、SHA256、大小与缺失／新增检测 |
| `../tests/python/test_parse_gate.py` | 故意坏脚本、坏依赖、两道门的失败隔离 |
| `../tests/python/test_asset_integrity.py` | 资源损坏／缺失／新增／空清单的失败验证 |
| `../tests/python/test_runtime.py` | 引擎指定、含空格路径、缓存／失败／重试 |
| `../tests/python/test_visual_config.py` | 两个隔离项目注入不同移动配置 |
| `../tests/python/test_release_metadata.py` | 旧版本、变更源码／PCK、错误源码提交与证据目录隔离负例 |
| `update_asset_integrity.py --write` | 有意资源修改验证后，记录新的本地资产基线 |
| `capture/`、`measure/` | 原生画面、回放和受控测量，按输出路径保留证据 |
| `measure/measure_native_match.gd` | 原生 180 秒上限 5v5，可用 `--map=<id>`、`--weapon=<id>`、`--rule=turf` 与 `--attribute-roll` 指定地图、武器、规则及赛前属性随机；自然死亡／确认复活、计分核对、双方属性点预算及整局保持、回墨观察、帧间隔与新证据目录 |
| `measure/measure_bot_idle.gd` | 七图受控移动记录，固定配装 RNG／均衡天赋，排除战斗、技能、补给与死亡等待；可指定 `--map`、`--seconds`、`--trace-actor`，必须使用新的绝对输出文件 |
| `capture/verify_bot_deployment.gd` | 两图原生受控机器人复活／队友／信标跳跃及玩家 J／Esc；新绝对证据目录，无导出或打包 |
| `capture/verify_loadout_tuning.gd` | 原生两尺寸／110% 画布输入、固定／自定义／ROLL；区域模式已移除；固定角色与人工涂墨，只算受控原生证据 |
| `capture/verify_attribute_allocation.gd` | 八属性／二十点实际鼠标加减、Enter／Esc、重置／属性与整套 ROLL、两尺寸、造型重载、有效射击耗墨和阶段关闭；受控原生，包内外分别核验 |
| `../tests/godot/check_bot_attribute_builds.gd` | 双方按武器／天赋加权属性 ROLL、同预算与整局锁定、Tab 只读摘要和敌方情报遮蔽；默认无界面规则，原生运行并传 `-- --output=新绝对目录` 保存两尺寸 1v1／5v5 四张图及报告 |
| `capture/capture_archetypes.gd` | 四套实际模型的正面／侧面／背面／跑动、脸部和各八武器持握；原生画面供审美复核 |
| `assets/build_character_archetypes.py`、`../tests/python/test_character_archetypes.py` | 从本地保留的 GLB 生成四套轮廓／服装剪裁；核对骨骼、蒙皮、语义 UV 和非角色几何不变 |
| `../tests/godot/check_loadout_tuning.gd` | 真实 132 HP 下四／五轮射击、弓追击与最终上限，200 次配装随机、锁定／冷却、两尺寸布局 |
| `../tests/godot/check_turf_rules.gd` | 全图两端计分、无区域控制／HUD、按时间结束和 CPU 覆盖率结算 |
| `capture/verify_ink_buddy.gd` | 原生两尺寸伙伴选择、实际右键／E、双方真实追击伤害、手雷预测与实爆对照、投放提示；固定角色和逐帧控制，只算受控原生证据 |
| `capture/verify_tidewater_ink_loop.gd` | 原生潮水码头 61 个计分面抽样、CPU／纹理／覆盖率核对；实际滚涂上下坡、潜墨回墨、干地／敌墨拒绝与爬墙越沿；固定位置和墨量、冻结机器人，只算受控原生证据 |
| `capture/verify_bot_ink_refill.gd` | 原生两队低墨寻路／停火／潜墨回补／恢复行动、干地敌墨与互斥负例、玩家实际 Shift 输入；固定资源与加速物理，只算受控原生证据 |
| `capture/verify_bot_beacons.gd` | 两队 AI 出生点拒绝／前方放置和真实玩家 E 输入；固定坐标、暂停对局物理、实际道具 tick，只算受控原生证据 |
| `assets/build_curated_maps.py`、`../tests/python/test_curated_maps.py` | 两张新图的碰撞／墨面／导航／小地图一致性、埋藏格及掩码／边／索引负例 |
| `capture/verify_curated_art.gd` | 两张新图实际鼠标选择、两尺寸原生 UI、W／射击及三种地图视角 |
| `../tests/godot/check_curated_map_routes.gd` | 双方从基地实际到达弧形高线与车站桥上／桥下，真实多边形／坡面碰撞和墨格一致，布景无额外碰撞 |
| `release/` | arm64 模板与本地打包 |

单项检查：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/inkwave-check.log --script res://tests/godot/check_tidewater_hud.gd
```

更改模型／纹理／音频／地图数据后，先运行相关语义检查与必要的原生预览，确认变化有意且有效，再执行：

```sh
python3 tools/update_asset_integrity.py --write
git diff -- assets/integrity.json
./tools/run_checks.sh
```

哈希只确认内容一致，不能证明碰撞、命中、模型、音效或玩法正确。禁止为了让检查通过而盲目改清单。

原生截图不用 `--headless`；旧工具可能覆盖历史证据，先检查／指定新输出路径。`capture/legacy/` 保存旧分页菜单脚本，仅用于相应历史提交；历史测量汇总可能因源码变更而拒绝复用，不能改旧数据哈希伪造新的结果。

JavaScript 转换器已删除。旧来源记录仅说明资源历史；未来维护本地资产，若需新的原生生成器，独立实现并补同步产物检查。

机器人跳跃单独验收（固定放置／强制伤害，仅算受控原生证据）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method forward_plus --rendering-driver metal \
  --log-file /tmp/tideink-bot-deployment.engine.log \
  --script res://tools/capture/verify_bot_deployment.gd -- \
  --output=/绝对路径/新的证据目录
```

输出必须是尚不存在的绝对目录。工具拒绝 headless，记录 arm64 环境、生产源码哈希、键盘选择／取消、真实复活控制器驱动的蓄力／飞行／落地和任何夹具失焦恢复；不创建应用或压缩包。规则负例在 `tests/godot/check_bot_deployment.gd`，覆盖两队、死亡／暂停、净空、隐藏情报、信标失效和最后一次使用竞争。

## 原生完整对局与帧时间基线

先通过统一检查，再单独运行，测量时避免同时运行其他测试。每次使用新的输出目录；已有 `match.json` 会被拒绝，旧证据不会覆盖。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method forward_plus --rendering-driver metal \
  --log-file /tmp/inkwave-native-match.engine.txt \
  --script res://tools/measure/measure_native_match.gd -- \
  --output=res://render-evidence/native-match-<新批次>
```

工具从 home 经 Enter 进入配装／开局，以键盘、鼠标事件驱动移动和战斗，使用原生机器人与自然 180 秒计时。自然死亡后，复活倒计时完成仍等待至少 0.8 秒，再用 Enter 明确确认基地落点；没有完整确认复活、实际移动、自然终场、十人结算或正确计分账本都会失败。整局结束时尚未复活的死亡单独记录，不要求结束后继续出场。

`match.json` 保存环境、实际装备、源码哈希、阶段、死亡／确认／落地时间、个人面积／积分、逐秒 CPU／静态内存采样及逐帧间隔；PNG 保存主菜单、配装、对局、复活选择、结果和回到主菜单，结算另拍 960×540／110% UI。帧间隔包含 30 FPS 限制、截图与系统调度影响，前五秒预热排除；它不是 GPU 执行时间。桌面失焦导致的暂停只在回放工具里恢复，并逐次记录，正式游戏的失焦暂停逻辑保持原样。

此工具要求原生 arm64 显示，会拒绝 headless。一局自动输入只建立受控原生基线，不能证明真人手感、配装平衡、长期温度、联网或新导出包已验收。

## arm64 导出与打包

先提交生产源码，再运行 `./export_macos.sh`。它读取项目名称／版本，输出 `build/TideInk.app`，捕获真实源码提交，检查架构、签名、启动日志后生成 `build/export-receipt.json`。

```sh
python3 tests/python/test_release_metadata.py
./export_macos.sh
python3 tools/release/verify_app.py --output render-evidence/<新批次>/exported-pack
python3 tools/release/package_macos.py --version v0.3.0-preview.16 \
  --evidence render-evidence/native-match-2026-10-04 \
  --evidence render-evidence/release-preview16-2026-10-04
```

打包工具会核对生产输入及所有应用文件与收据一致；拒绝任意改变的源码、PCK、版本或伪造的 `--source-commit`。随包 `BUILD.json` 记录引擎、源码提交、输入／应用／证据文件哈希，ZIP 附 SHA256SUMS。原生画面与解压后的实际启动另行验证；临时签名不表示 Apple 公证。

`verify_app.py` 要求新的证据子目录：同版本原生编辑器从临时工作目录显式加载导出 PCK，运行当前 34 项外部规则，包括全图涂地与两张新地图的实际路线；八组原生检查覆盖 UI、伙伴／投放、主武器、配装／属性、人物／服装及新图选择／移动／射击，再单独运行实际应用、不添加路径／脚本覆盖参数。外部人物／地图夹具移除仅源码可用的输入清单查询，保存原夹具与外部夹具哈希并绑定实际 PCK 收据。标准发行模板禁用路径覆盖，不能把 `--main-pack` 传给发行应用。默认编辑器可用 `--godot` 指定。

用户要求只导出 `.app`、不创建分发压缩包时，使用 `build_metadata.py prepare` → Godot `--export-release macOS <新临时目录>/TideInk.app` → 验证新应用后替换 `build/TideInk.app` → `build_metadata.py finish` → `verify_app.py`。复用已验证的 arm64 模板缓存；当前 `export_macos.sh` 仅输出 App 和收据，`package_macos.py` 才创建分发 ZIP。生产输入提交和收据验证要求保持不变；用户要求删除旧应用时，在新 App 验证通过后删除已盘点的旧包。

## 主武器伤害与原生输入

`tests/godot/check_damage_contract.gd` 覆盖三种角色扣血入口、部位一致性、击倒／非击倒门槛、护盾、薄墙、射程、滚筒共享最终预算与机器人有效天赋。`tools/capture/verify_primary_combat.gd` 复用这些隔离规则，再注入原生鼠标按住／松开，验证蓄力伤害、实际护盾和配装说明；只接受新的绝对输出目录，记录源码散列、环境和截图，不代表自然计时或真人手感。

```sh
Godot --path . --rendering-method forward_plus --rendering-driver metal \
  --script res://tools/capture/verify_primary_combat.gd -- \
  --output=/absolute/path/to/new-evidence-directory
```

180 秒自然计时对局继续使用 `tools/measure/measure_native_match.gd -- --output=res://render-evidence/<new>/match --map=tidewater --weapon=shooter`，不得与规则回归并行采集帧间隔。

`tests/godot/check_extended_damage.gd` 验证玩家与两队机器人双持／弓击倒门槛，以及漏箭、半蓄、低墨、护盾、共享上限、薄墙和飞镖／伞的定位。`capture/verify_primary_combat.gd` 记录实际鼠标满蓄狙／弓、释放耗墨、护盾以及三种武器详情；自动滚动到卡片属于受控准备，悬停使用鼠标事件。
