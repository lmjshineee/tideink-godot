> 历史记录：此文保留对应 Godot 移植批次；旧 Web 来源、JS 工具和目录命令不属于当前工程。维护以 [GODOT_MAINTENANCE.md](../GODOT_MAINTENANCE.md) 为准。

# INKWAVE：Godot 特性选型与迁移规范

## 滚动配装、角色曲面细化与模块地图 · v0.3.0-preview.14 · 2026-10-01

1. 七武器、七道具、十二天赋在同页三个独立横向选择带：滚轮／双指滑动／滚动条／键盘焦点，保留单列浮动星级和真实详情；当前配装及当前地图自动滚入视区。新增双持喷枪、长管喷枪、轻爆枪，沿用源喷枪／爆破枪模型与动作族，双持补上左手模型。
2. 爆墨瓶、减速墨雾与医疗领域共用赛前选择、墨量、CD、阵营、楼层和遮挡规则，机器人可用。新增道具技师、命中回复、稳枪专注、循环墨泵；整局锁定、死亡和装备重摇不能清空 CD。
3. 原脸型、87 骨骼、肩袖／裆部修正、衣服和装饰保留，导出头／耳／圆角解析曲面提高采样，完整模型约 5.9 万 → 7.9 万三角（含潜墨与四个源武器）。独立人物视口 4×MSAA；新中文名称使用随包 OFL Noto Sans SC，避免缺字。
4. 七图十九套布局，新增模块港湾与阶梯花园。港湾按 3 种中央区 × 3 种镜像侧路组合，种子保持，“换图”保证换到另一组合；花园有 0／3／6 米平台与双侧连接坡道。碰撞、墨面、导航和小地图一起预导出，是有限模块组合库；任意运行时拼接另列 MAP-02。
5. 182 组生产攻击、84 组墨量配置见 [BALANCE_REPORT.md](../BALANCE_REPORT.md)。新三武器一轮对基础满血躯干目标留下 87／77／68 HP；保留普通伤害上限、部位和距离规则。

证据：[81 项回归](../../render-evidence/expand14-checks-final.txt)、[原生滚动／换图／小窗口](../../render-evidence/expand14-ui-final.txt)、[双方实际控制器 6 m 通行](../../render-evidence/expand14-check_garden_platforms.txt)、[两张新图各 90 秒自然回放](../../render-evidence/expand14-full-matches.json)、[本地导出](../../render-evidence/expand14-export.txt)、[导出 PCK](../../render-evidence/expand14-pck.txt)、[解压／签名／哈希](../../render-evidence/expand14-archive-verification.json)。人工手感、长期温度与多局配装平衡未验收。

后续按顺序：多局收益对照 → 双持独立持握／坡面脚部 IK → 侦察道具与正式图标／特效 → 更丰富模块和运行时断路回退 → 音乐分层／机器人自动跳跃。仅本地 arm64 包，不上传。

## 同页配装、队友／信标跳跃与受控配装测量 · v0.3.0-preview.13 · 2026-10-01

当前玩法与剩余工作以 [GAMEPLAY.md](../GAMEPLAY.md) 为准，以下 preview.12 及更早章节保留历史。

1. 四武器、四道具、八天赋同时显示在同一个配装页，直接选择、无需切换标签。保留地图主体、独立可动全身预览与单列浮动星级／真实详情，960×540 / 110% 已核验。
2. 死亡立即显示地点与 4 秒倒计时，点存活队友／己方信标一次排队，到零自动发射；Esc 取消，保留基地快速出场。存活按 J 选目标，1 秒可受伤／可取消蓄势，落地不回血、不补墨；落点公开，起飞／到达重新核验占位和实际楼层，信标要求己方墨地，失效回退。
3. 第四道具跳跃信标：CD 18 秒、消耗 35 墨水、45 秒／两次使用，每人一个、重放替换。死亡／换装保留 CD 和已放信标；敌墨／占位暂不可用。机器人可放置，自动跳跃与可被射击摧毁尚未接入。
4. [BALANCE_REPORT.md](../BALANCE_REPORT.md) 记录 72 组实际攻击与 32 组墨量配置。本批不改既有伤害数值；滚筒回归扩大至整轮墨滴生命周期。正式多局生存／涂地收益与人工手感仍待完成。

证据：**79 项通过、0 失败**，[全套检查](../../render-evidence/unified13-checks-final.txt)、[原生同页配装／小窗口／跳跃](../../render-evidence/unified13-ui-final.txt)、[回廊 90 秒自然回放](../../render-evidence/unified13-full-matches.json)、[本地导出](../../render-evidence/unified13-export.txt)、[导出 PCK](../../render-evidence/unified13-pck.txt)、[ZIP 解压／签名／哈希](../../render-evidence/unified13-archive-verification.json)。受控输入证明 6 m 落地，自然回放最高 8.89 m 含跳跃弧线；平均 29.84 FPS、P99 39.28 ms 含后台负载，非独占性能测量。人工手感／长期温度未验收。

后续：BAL-03 多局收益对照 → ITEM-02 进攻／侦察道具和资产 → ANIM-01／AUD-01；机器人自动跳跃继续列 DEPLOY-02 延伸项。只交付本地 arm64 包，不上传。

## 地图主体、可动 3D 人物与浮动星级 · v0.3.0-preview.12 · 2026-10-01

当前玩法见 [GAMEPLAY.md](../GAMEPLAY.md)，以下 preview.11 及更早内容仅用于追溯。

1. 地图选择为赛前主体：大幅实际地形 3D 预览、五张地图卡片，拖动／滚轮查看；切图保留武器／道具／天赋。静态地图按需刷新，窗口变更后重绘；入场关闭预览。
2. 人物独立 3D 舞台：旋转、缩放、点击跳跃，待机／跑动／试射，聚焦后 WASD 移动、空格跳跃；沿用实战原角色与动作，RANDOM 和队色保留。
3. 武器卡片取消左右分栏，五项星级放入单列悬浮详情，显示当前伤害、射程、射速、移速、涂墨、耗墨与大招；道具／天赋也有浮动说明，消耗计入节墨天赋。
4. 命中实际扣血数字弹起、上浮、淡出，颜色跟随攻击方队色；护盾和溢出已计入，快速连击合并，最多 24 标签复用、不透墙。

验证：**78 项通过、0 失败**，[全套回归](../../render-evidence/menu12-checks.txt)、[原生鼠标／键盘与 960×540 / 110%](../../render-evidence/menu12-ui-final.txt)、[导出](../../render-evidence/menu12-export.txt)、[PCK](../../render-evidence/menu12-pck.txt)、[ZIP 解压／签名／哈希](../../render-evidence/menu12-archive-verification.json)。原生 UI 与伤害为受控核验，旧版五图自然回放保留为玩法基线；人工手感和长期温度仍未验收。

下一批顺序保留：BAL-03 配装／高层地图对照 → DEPLOY-02 队友跳跃／信标 → ITEM-02 更多赛前道具 → ANIM-01／AUD-01。仅本地 arm64 包，不上传。

## 五地图、三层平台与锁定天赋 · v0.3.0-preview.11 · 2026-10-01

当前玩法见 [GAMEPLAY.md](../GAMEPLAY.md)，下面旧版内容仅用于追溯。

1. 新增珊瑚集市、回廊展馆、双层高架。回廊为地面／3 米／6 米三层站立平台与坡道；原两图可开启标准／木箱／矮墙随机布置。九套布局同步导出碰撞、有效墨面、导航与网页风格小地图。
2. 修复滚筒多滴叠伤，普通主武器不再一发击倒基础满血。喷枪 30、滚筒接触 60／近端甩墨预算 72、满蓄狙 100、爆破直击 82、手雷爆心 100；直接命中按头／躯干／腿 ×1.08／1／0.85，并保留距离、蓄力与爆炸遮挡规则。护盾后实际扣血和近期来源可见。
3. 八种赛前天赋，玩家自选、机器人随机，开战即锁定。死亡、复活和装备重摇均不改变天赋；150 HP／125 墨量等上限贯穿血条、治疗、阈值与重生。
4. 移植网页版双墨色 Logo、倾斜大导航、原图标与配装卡片；全身预览保留，四武器显示五项星级；随机重摇后和死亡界面明确显示当前配装。小窗口按钮与字号已调整。

证据：**76 项通过、0 失败**，[全套回归](../../render-evidence/balance11-checks.txt)、[三层实际控制器通行](../../render-evidence/balance11-gallery-platforms.txt)、[原生 UI](../../render-evidence/balance11-ui.txt)、[五图自然计时回放](../../render-evidence/balance11-full-matches.json)、[本地 arm64 导出](../../render-evidence/balance11-export.txt)、[PCK](../../render-evidence/balance11-pck.txt)、[ZIP 解压／签名／哈希](../../render-evidence/balance11-archive-verification.json)。界面测试包含受控伤害／阶段；自然对局不强制伤害与结束。人工手感和长期温度仍未验收，未知位置桥梁漏染待定位。

下一批：BAL-03 配装与高层地图对照 → DEPLOY-02 存活队友跳跃／信标 → ITEM-02 更多副武器 → ANIM-01／AUD-01。安全变体已完成本批范围，任意地形生成与联网仍列后续。仅本地包，不上传。

## 主菜单、随机配装与基地发射 · v0.3.0-preview.10 · 2026-10-01

preview.9 的地图点选再确认复活、拾取补给库存方案已撤回。当前以 [GAMEPLAY.md](../GAMEPLAY.md) 为准。

1. 应用先进入主菜单，再配装／开战；移植网页导航、字体、墨色和四武器图标。全身预览与实战相同，RANDOM 生成外观／装饰／队色，无外观下拉。菜单关闭主地图 3D 绘制。
2. 死亡立即进入基地发射视角，同时显示 4 秒倒计时，可边等边选，鼠标／WASD 瞄准，左键／空格／Enter 一次出场；空格可提前准备，死亡 R 重摇自己的配装。
3. 赛前选一个道具，右键／E 使用，手雷／补充剂／护盾 CD 6／12／16 秒，无地图拾取库存。全部机器人默认随机武器和道具，默认复活重摇，可关闭；各道具 CD 跨死亡／重摇保留，手雷保存攻击者与阵营。
4. 全部角色名字从网页池随机无重复分配，头顶／HUD／名单／击倒／结算统一，重生固定；机器人涂地充大招，有重击预告／墨雨与基本躲雨。保留稳定编号、血条、击倒来源、源地图小地图、120 HP 与大招强化；修复随机慢速滚筒在 1v1 平台边缘的体积穿模。CPU 墨迹计分与源资产导出不变。

证据：[69 项回归通过](../../render-evidence/frontend10-checks.txt)、[原生鼠标菜单／RANDOM／发射／道具／小窗口](../../render-evidence/frontend10-ui.txt)、[最终两图 180 秒自然对局](../../render-evidence/frontend10-full-matches180.json)、[本地打包](../../render-evidence/frontend10-build.json)。原生 UI 为受控条件，完整对局自然推进；人工手感与温度仍未验收。基础大招与躲雨已完成；后续平衡对照 → MAP-01 → DEPLOY-02 → ITEM-02，详见 GAMEPLAY.md。

以下为历史记录，旧复活／补给操作已失效。

## 手动复活、道具与战斗平衡 · v0.3.0-preview.9 · 2026-10-01

1. 死亡后由玩家点击己方墨地、确认落点，或明确选择回基地；4 秒倒计时结束后等待确认。落点被覆盖时要求重选，不随机替玩家部署。赛前可选基地左／中／右入口。
2. Shift 墨墙攀爬加快并补齐横向靠墙；右键炸弹保留，E 补充剂恢复墨水／生命、C 个人护盾有库存、冷却和吸收上限；机器人共用规则，每局成对随机补给布局。
3. 全员 120 HP，喷溅枪近端四发击倒、末端伤害衰减；大招回满墨水，重击范围／冲击反馈与 8 秒可见墨雨强化。网页导出参数保留，本地调整集中在 `gameplay_rules.gd`。
4. 最终结算显示地图、双方比例与全部角色编号／武器／击倒／阵亡／有效伤害，保留结果舞蹈。具体参数、Splatoon 3 参考范围与后续任务见 [GAMEPLAY.md](../GAMEPLAY.md)。

验证：[68 项检查、0 失败](../../render-evidence/gameplay9-checks.txt)、[双地图玩法短测](../../render-evidence/gameplay9-deployment.txt)、[横向墨墙输入](../../render-evidence/gameplay9-climb.txt)、[6／12 隔离配置](../../render-evidence/gameplay9-isolated.txt)、[原生鼠标选点／确认／道具／双尺寸结算](../../render-evidence/gameplay9-ui.txt)、[两图 90 秒自然对局](../../render-evidence/gameplay9-full-matches.json)。原生 UI 检查使用受控伤害／阶段；完整对局通过实际输入和自然计时推进。人工手感、温度和新平衡 180 秒仍待验收。

本地 arm64 导出、PCK 与 ZIP 校验记录：[导出](../../render-evidence/gameplay9-export.txt)、[最终 PCK](../../render-evidence/gameplay9-pck.txt)、[应用启动](../../render-evidence/gameplay9-app.txt)、[打包](../../render-evidence/gameplay9-build.json)。仅本地交付，不上传。

下一批按顺序：BAL-02 试玩平衡／机器人用大招 → MAP-01 离线安全地形变体 → DEPLOY-02 存活超级跳跃／信标 → ITEM-02 队伍补给与正式资产。完整随机地图生成器、脚部 IK、音乐分层和联网保留计划；地形随机性本轮尚未完成。

以下为历史记录，当前玩法与计划以本节和 GAMEPLAY.md 为准。

## 反馈修复与随机装饰 · v0.3.0-preview.8 · 2026-09-30

- 血条填充在 +Z，旧 `look_at` 让 -Z 朝向相机，导致底板遮挡填充；现在正面朝向当前相机，各角色独立血量即时更新。所有角色稳定 ID：5v5 己方 01–05、对方 06–10，1v1 为 01／02；头顶、顶部 HUD、名单、小地图统一标号，重生保持。
- 直接导出原版网页的小地图底图和像素到墨格映射，保留地形遮挡、桥梁／坡面与海面。GPU 双线性采样权威墨格，6 Hz 墨色刷新、每帧角色方向／编号／死亡和投弹／墨雨位置；不消耗 `SurfaceInk` 的渲染脏格，不影响计分。
- 三角警告牌贴图与墨层原先同为 12 mm，产生深度争夺；墙墨改为 24 mm，壁画独立保持 4 mm，地面仍 12 mm。实景坐标 `(-9.8,1.7,-43.4)` / Tidewater face 34，已截取未涂及三个涂色观察角度。
- 快速鼠标点击缓存到下一物理帧，支持物理空格；保留原有跳跃缓冲／土狼时间。射击冷却保留余量，按原版每帧最多补发三发，避免 30 Hz 量化；机器人使用原版跳跃／下落边、路线代价和玩家起跳／重力配置，遇阻重新规划。
- 墨镜改为星星、短线、闪电、波纹、菱形、花瓣、点阵、月牙八种脸颊装饰。独立 RNG 随机样式、颜色、尺寸、倾角、位置、单双侧，不改变武器随机数；入场／对局／重生／结算共享种子，一局内保持、下一局重选。保留眼睛、眉毛、表情与身体。导出适配器可重建该材质，源／输出哈希有校验。
- 命中、击倒、潜墨、起跳与枪口液滴限额 96 粒、两次批量绘制。四武器、爆破范围、滚刷、炸弹和大招传递攻击者；死亡界面和击倒消息显示真实编号／名字／武器。弹丸保存发射时武器，攻击者中途换武器不影响提示，落水单独显示原因。

验证：全套 **67 项通过、0 失败**：[feedback8-checks.txt](../../render-evidence/feedback8-checks.txt)，另有 [血条／ID／随机种子](../../render-evidence/feedback8-health.txt)、[四武器击倒来源](../../render-evidence/feedback8-attribution.txt)、[配置 6／12 隔离](../../render-evidence/feedback8-isolated.txt)、[警告牌／血条原生画面](../../render-evidence/feedback8-warning.txt)、[随机装饰／表情](../../render-evidence/feedback8-ornament.txt)、[死亡来源与鼠标 UI／音频](../../render-evidence/feedback8-presentation.txt)。

### 完整时长回放

原生 Forward+ / Metal、1280×720、30 FPS / 75% 精度。输入通过事件进入正常控制流程；从出生点移动，不瞬移、不强制伤害／结束计时。两图各 90 秒及一次 180 秒 5v5，自然死亡／重生换武器、四武器、跳跃、潜墨和自然结果重开均已记录。[数据](../../render-evidence/feedback8-full-matches.json)，[最终回放日志](../../render-evidence/feedback8-full-matches.txt)。

| 场次 | 平均 FPS | P95 帧间隔 | P99 帧间隔 | 自然死亡 | 覆盖 |
| --- | --- | --- | --- | --- | --- |
| tidewater / 90 秒 | 29.96 | 36.09 ms | 40.68 ms | 6 | 四武器 / 跳跃 / 潜墨 / 结果重开 |
| kelpline / 90 秒 | 29.98 | 35.62 ms | 42.04 ms | 5 | 四武器 / 跳跃 / 潜墨 / 结果重开 |
| tidewater / 180 秒 | 29.98 | 35.36 ms | 41.36 ms | 10 | 四武器 / 跳跃 / 潜墨 / 结果重开 |

原生合成鼠标在场景重建后两次未触发预期按钮，保留 [第一次](../../render-evidence/feedback8-full-matches-first-attempt.txt) 与 [第二次](../../render-evidence/feedback8-full-matches-second-attempt.txt) 失败记录；后两局改用游戏支持的 Enter 完成开始／重开。短时原生鼠标开始、死亡换武器及重开另行通过。帧间隔采样含后台 headless 检查／导出负载，不代表独占 GPU 基准；人工手感和传感器温度未验收。击倒来源补丁在完整回放之后加入，随后通过独立四武器与原生死亡界面回归。

桥梁 CPU 计分／表面可涂回归保留；用户此前未定位的漏染桥梁尚无具体坐标，不能据此声明所有桥梁视觉问题解决。

本地 arm64 应用、ZIP 和 SHA256： [导出](../../render-evidence/feedback8-export.txt)、[最终 PCK](../../render-evidence/feedback8-pck.txt)、[应用 Metal 启动](../../render-evidence/feedback8-app.txt)、[打包](../../render-evidence/feedback8-build.json)。按用户选择仅保留本地包，没有推送或公开发布。

### 后续按顺序推进

1. QA-03 的完整自动化回放已交付；人工手感／温度与未知桥梁坐标继续保留待验收。
2. BOT-01 的源跳跃边／代价和真实碰撞已完成，两图各一条起跳落地短测及完整对局通过；潜墨和更复杂策略尚未实现。
3. VFX-01 的基础命中／击倒／潜墨／起跳已完成并记录整局粒子事件；其他原版屏幕／环境特效后续补充。
4. 下一项 ANIM-01：坡面／台阶脚部 IK 与极端瞄准持握，再做 AUD-01 音乐分层／节拍过渡；NET-01 仍先评估方案再实施。

以下为历史记录，当前版本／人物和计划以本节为准。

## 清理与发布 · v0.3.0-preview.7 · 2026-09-30

清理已弃用的外部人物加载分支、Quaternius 资产与许可、对应捕获脚本/检查，以及精灵脸、麻将牌与花色面罩的实验截图。保留当前原人物、身体与服装修正、四武器、5v5/1v1、双地图、全屏 UI 和原版音频。旧构建目录清理后仅保留当前 arm64 应用、ZIP 和 SHA256 校验文件。

- 验证：**61 项通过、0 失败**（移除两项仅服务弃用人物实验的检查），[clean-checks.txt](../../render-evidence/clean-checks.txt)、[隔离配置](../../render-evidence/clean-visual-isolated.txt)、[原生 UI/音频流程](../../render-evidence/clean-presentation-gui.txt)。
- 编译包：[导出](../../render-evidence/clean-export.txt)、[最终 PCK](../../render-evidence/clean-pck.txt)、[原生应用启动](../../render-evidence/clean-app.txt)、[打包校验](../../render-evidence/clean-build.json)。
- 交付方式：按用户最新选择，仅保留本地 arm64 应用、ZIP 与校验文件。没有公开 Release 或推送源码；记录见 [clean-publication.json](../../render-evidence/clean-publication.json)。

## 恢复原人脸 · v0.3.0-preview.6 · 2026-09-30

按用户要求恢复到 preview.5 的人脸：原眼睛、眉毛、眼罩、嘴部与状态表情重新启用，撤回后续精灵脸、花色面罩、编号及随机脸部变化。身体、肩袖与短裤裆部修正、四外观、87 骨骼、四武器和既有动作保留。本轮人物脸部修改到此停止。

- 全套 **63 项通过、0 失败**：[restored-checks.txt](../../render-evidence/restored-checks.txt)，包含原眼睛可见与原眼睛着色器回归。
- 原生 Forward+ / Metal：[四外观](../../render-evidence/restored-three-quarter.png)、[人脸](../../render-evidence/restored-face-idle.png)，[短时画面核验](../../render-evidence/restored-gui.txt)。恢复后的正面脸部、四人物和跑步 PNG 与 preview.5 对应截图逐字节一致。
- arm64 应用与 preview.6 ZIP：[导出](../../render-evidence/restored-export.txt)、[打包](../../render-evidence/restored-build.json)、[应用启动](../../render-evidence/restored-app.txt)、[最终 PCK](../../render-evidence/restored-pck.txt)。

全屏入场、死亡、结算与原版音乐音效保留；碰撞、武器数值和 CPU 墨迹计分沿用既有实现。下方 preview.5 说明是恢复后的形体与材质基础。

## 原人形修正基础 · v0.3.0-preview.5 · 2026-09-30

默认恢复网页的四种墨鱼人物、87 骨骼与四武器。此前外部人物实验已在 preview.7 清理。原版服装的颜色、徽标、缝线、口袋、袜子和鞋面细节通过独立布料/皮肤/眼睛着色器迁入；站姿、走路和跑步改用原版离线 IK 采样，保留连续眨眼、七种状态表情及结果舞蹈。

本轮对照真实网页渲染，确认球状肩袖、封口骨盆和圆头也存在于网页源模型。`tools/lib/character_anatomy.mjs` 在导出副本上修正：胸部开袖笼并连接开放袖管；短裤用一个腰口、两个裤口和共享裆部曲面替换球体叠管；头部用连续形变调整头颅、下半脸和下颌，眼睛重新贴合解析头面，耳朵、发根和脸部骨骼同步定位。脸部动作按新静止位置偏移，避免眨眼或表情把五官拉回旧位置。原网页文件保持原样。

建模/蒙皮参考为 [Julien Kaspar 的 Snow 头部拓扑说明](https://julienkaspar.artstation.com/blog/M3LL/head-retopology-of-snow) 和 [Kiel Figgins 的权重与活动范围流程](https://www.3dfiggins.com/writeups/paintingWeights/)。使用其工作方法作为参考，没有复制教程的模型或图像。当前头部仍为原版解析网格与贴面眼睛，并非完整面部重拓扑或表情形状键。

- 全套 **63 项通过、0 失败**：[anatomy-checks.txt](../../render-evidence/anatomy-checks.txt)。新增连通/流形检查、相邻面朝向、衣服四个和短裤三个开放边界、共享接缝权重、五种动作有限性及脸部新挂点回归；源/输出哈希覆盖新增形体修正模块。
- 原生 Forward+ / Metal：[四外观](../../render-evidence/original-three-quarter.png)、[脸部](../../render-evidence/original-face-idle.png)、[跑步](../../render-evidence/original-running.png)、[抬臂瞄准](../../render-evidence/original-body-aim-0.65.png)。肩/胯正侧背面、七状态中的四种脸部特写和双地图入场镜头截图见 [anatomy-gui.txt](../../render-evidence/anatomy-gui.txt)。这些是短时固定条件核验，不代表人工完整对局或人物审美已获用户认可。
- 全屏入场/READY/GO、死亡/重生、结算和 62 音效/6 首音乐保留，短时鼠标流程与实际音频位置推进见 [original-presentation-gui.txt](../../render-evidence/original-presentation-gui.txt)。UI 是 Godot 适配，非网页逐像素复刻。
- 本地 arm64 应用与 preview.5 ZIP；导出、架构、签名和短启动记录 [anatomy-export.txt](../../render-evidence/anatomy-export.txt)，打包记录 [anatomy-build.json](../../render-evidence/anatomy-build.json)，导出 PCK 人物检查 [anatomy-pck.txt](../../render-evidence/anatomy-pck.txt)，应用本体 12 帧 Metal 启动 [anatomy-app.txt](../../render-evidence/anatomy-app.txt)。最终 ZIP 解压后再验 arm64 与签名通过；解析隔离用例五项、跑速 6/12 的隔离配置用例通过。未推送或公开发布。

本批只改视觉资源和动作适配；碰撞、战斗参数、CPU 墨迹归属与计分保持既有实现。下方 preview.4 及更早章节为历史，默认外观与完成状态以本节为准。


preview.4 的外部人物实验已撤回；对应代码、资产、测试与实验截图已在 preview.7 清理。

## 角色、全屏 UI 与原版音频 · v0.3.0-preview.3 · 2026-09-30

本批按本地网页原版继续移植：四外观/四武器沿用原网格，增加起跳、落地、受击、重生的全身/脸部采样和六种结果舞蹈；HUD 改为十人武器/死亡徽章、计时、散射准星/蓄力环/本地命中反馈与圆形大招/涂地点数。入场双方角色阵容、READY?/GO!、全屏死亡染色和重生环、时间到及裁判/结果展示覆盖整个画面，保留死亡换武器、Tab 地图和结算重开。

原版 62 个合成音效与 6 首完整音乐通过 Chromium OfflineAudioContext 导出为 22.05 kHz PCM。导出器按原调度器预调度步长推进，并检查每两个秒段有音频，避免单次跳时触发后台跳过逻辑。固定满强度配器；运动/蓄力循环可动态调音高，机器人射击为 Godot 3D 衰减；总音量、音乐和音效保存到用户设置。

- 全套入口：57 项通过、0 失败，见 [presentation-checks.txt](../../render-evidence/presentation-checks.txt)。新增源/输出音频校验、动作源校验和行为测试：68 音频资源可加载，阶段/最后一分钟音乐切换，六种逻辑尺寸/缩放全屏覆盖，死亡换武器/重生，音量保存/静音以及实际骨骼舞蹈变化。
- 原生 Metal 短验收：[presentation-gui.txt](../../render-evidence/presentation-gui.txt)。音频实际播放位置推进；真实鼠标开始、死亡换武器、结果重开；1280×720 与 960×540/110% UI 截图。阶段/伤害采用测试条件，不是完整对局或人工听感验收。
- [入场阵容](../../render-evidence/presentation-lineup.png)、[READY](../../render-evidence/presentation-ready.png)、[GO](../../render-evidence/presentation-go.png)、[HUD](../../render-evidence/presentation-hud.png)、[死亡](../../render-evidence/presentation-death.png)、[小窗口死亡](../../render-evidence/presentation-death-small.png)、[结果](../../render-evidence/presentation-results.png)、[声音设置](../../render-evidence/presentation-settings.png)。预览角色只在入场/结果运行，正常对战禁用第二视口和预览骨骼更新。
- 重建本地 arm64 应用和 preview.3 ZIP；没有推送或公开发布。导出/包证据见 `render-evidence/presentation-export.txt` 和 `presentation-build.json`。

仍未迁入实时完整脚部 IK、完整状态表情/特效、原版音乐实时分层/混响/节拍同步过渡和所有环境触发；UI 为 Godot 适配重建，并非网页逐像素等价。保持碰撞、战斗参数与 CPU 墨迹计分权威。下面 preview.2 及更早章节为历史。

## 试玩反馈修复候选 · v0.3.0-preview.2 · 2026-09-30

发布暂停，先修复真实试玩问题。原 v0.3.0-preview.1 的 51 项规则检查不能证明角色动画、脚底高度、阴影或持续温度正确。

- **腿部入地**：`hips` 静止位置为 `(0,0.64,0)`，旧动画每帧写到约 0，使脚落到 -0.55 米。修为静止位置加起伏；新增骨盆/脚底高度检查。
- **武器抽搐**：固定瞄准时旧 30 Hz 朝向弹簧每帧持续跳动 0.2118 rad（约 12 度）。以 120 Hz 子步积分保留源速度/加速度上限，稳态跳动归零；30/60 Hz 回归。原作两臂 IK 离线采样四武器持握/瞄准/动作，运行时四元数平滑混合；甩墨动作与蓄力起点对齐。并非实时完整原作 IK。
- **墨鱼/卡模**：玩家 Shift 检查己方墨面或己方墨墙，低顶安全退出规则保留；新回归覆盖敌墨退出。台阶升起前检查完整身体，低顶拒绝时回退安全位置；真实输入低顶台阶检查通过。铁网独立层，墨鱼/弹丸穿过，仍不可涂。
- **HUD**：Tab 展开地图、队伍状态，投影保持比例、出生点在底部；隐藏时不刷新第二张地图。重排设置、增加持久化 75/100% 画面精度。
- **负载/阴影**：启动即 30 FPS，默认 75% 3D 分辨率（像素数为原来的 56.25%），关闭 SSAO，1024 / 35 m 硬阴影消除滤波噪点。旧/新相同 1280×720、十人场景的 65 帧短采样记录：旧启动 253 ms、TIME_PROCESS 平均 33.49 ms/最大 341.93 ms；新启动 246 ms、平均 29.06 ms/最大 30.64 ms。采样含启动、滤波最终又做过调整，无 GPU 稳态对照和传感器温度，不据此承诺长期温度下降或精确性能提升。
- **桥梁边界**：双地图 61 + 59 个硬质地面面的有效墨格可涂，不能替代用户未定位桥梁的视觉复现；此项保留待验收。尚未进行人工完整对局或定位全部卡模位置。

最终 54 项入口以及隔离用例、原生短核验见 `render-evidence/feedback-*`。重建 arm64 本地候选包，未推送或公开发布。源码快照到具体公开仓库的推送此前被自动审批拒绝，本轮不重试。


## v0.3.0-preview.1：角色、HUD、5v5 与双地图 · 2026-09-30

用户已授权这一整批实现，并在完成后打包发布；此前“一项完成后停止”和“不发布”的边界是历史范围。

- 原版四外观/87 骨骼/蒙皮与四武器已导出接入；基础骨骼步态、瞄准、后坐力与甩墨/投弹动作，队色材质共用。完整 GLSL、IK、表情、舞蹈及全部动作层尚未迁入。
- 默认 5v5，保留 1v1；独立敌我、生命、保护重生、最近敌人命中与群体伤害，队友涂墨不奖励玩家个人点数/大招。原版导航图用于巡逻和寻路，跳跃边及完整策略尚未启用。
- Kelpline 的 141 碰撞块、307 可涂面、76,563 有效计分格以及 130 处道具/壁画/港口远景接入。Tidewater 仍为 145 碰撞块、285 可涂面、69,366 有效计分格；权威规则保持 CPU 归属。
- 菜单新增地图/5v5/发型和开始按钮；HUD 新增小地图、存活人数、击倒提示、Tab 十人名单、暂停和结果按钮。已发布的帧率/界面缩放/灵敏度设置并回，保留保存/重置/取消。
- 新检查覆盖两地图十人名单、友伤、最近命中、群体伤害与保护重生、机器人互相射击、真实骨骼动作和导航可达；九名机器人在两地图六秒模拟时间内全部离开出生区。

这批是可玩的单机团队预览版；音频、联网、完整动画/特效、人工完整对局及长期负载仍有明确缺口。最新证据见 [RENDERING.md](../RENDERING.md)，不引用下方历史检查数量作为当前结论。


状态：2026-09-30。当前目录是可丢弃的 Godot 样机，**不是**网页游戏的等价实现。本文是后续代码评审与验收的约定；提到的目标能力不表示已经完成。当前迁移顺序是 **真实地图规则闭环 → 画面与素材 → 完整对局 → Mac 导出**。默认入口已是 `tidewater_play.tscn`；本批有带测试条件和加速等待的短时自动图形流程证据，没有人工手感或完整 90 秒图形对局证据。

本目录已纳入 Git（基线提交 `6ea0bef` 只做入库、未改内容），迁移批次在独立分支上做；批次记录见 §6。
验证的唯一入口是 [tools/run_checks.sh](../../tools/run_checks.sh)：素材导入 → 5 个导出器 `--check` → 解析预检及其余短测（当前共 37 项），任一失败即非 0 退出。**"已迁移"必须附该脚本的通过输出**，不接受只跑单个脚本或只看退出码。
地图场景已接入原版 144 处道具、18 面壁画和港口远景；视觉独立于碰撞与计分。渲染基础已切换为 Forward+，接入天空、方向光/阴影、SSAO、地图与角色受光材质及湿润墨迹；短测与截图证据见 [RENDERING.md](../RENDERING.md)。整局性能与温度仍未验收；用户已明确排除 x86/Intel 路线。


## 2026-09-30 赛前操作批次

已实现三个菜单项：场景创建前的配色/色盲选择、从 `match.durations` 读取的时长选择、鼠标玩家/机器人武器选择。配色变更重建当前赛前场景，单次交接保留选中武器；时长偏好在当前进程内保存。初始仍为第一个时长选项（当前 90 秒）及 1v1；没有将样机改为原版默认 180 秒/5v5。`match_setup.gd` 在时长列表为空时读取 `match.defaultDuration`，对应豁免已删除；新增短测以注入 45 秒和空列表默认值 75 秒证明行为消费。

GUI 回调和键盘选择共用路径。进入 intro 后设置不可改，playing 活着时不能换主武器；重生等待仅可点选玩家武器。五配色及色盲模式仍在创建场景时初始化，未增加局中换色、持久化偏好或完整设置中心。

[全套检查](../../render-evidence/setup-checks.txt) **42 项通过、0 失败**。GUI 信号/重建/阶段限制由 `tools/check_setup_settings.gd` 覆盖；[原生图形日志](../../render-evidence/setup-gui.txt)核验真实鼠标按钮/复选框操作、PopupMenu 选择信号以及两种窗口尺寸，既有带测试条件/加速等待的对局短流程也通过。候选应用已更新并通过 arm64 架构/签名/无界面及图形短启动。完整 AI、完整战斗动画、人工手感及持续性能/温度仍未完成。

## 2026-09-30 前一批集成验收（历史）

DS-04、DS-05、CX-03 与 QA-02 本批范围已完成：解析预检可靠失败且提前停止；两队动画在配置就绪后读取跑速；五配色与色盲配色接通 HUD 名称、角色、弹丸、出生台与墨迹。墨迹 RGBA 是阵营掩码，不包含显示队色，shader 按选定队色着色；CPU 归属、敌方覆盖与覆盖率不受选色影响。局中切换和设置 UI 不属于本批。

唯一入口 **41 项通过、0 失败**，见 [candidate-checks.txt](../../render-evidence/candidate-checks.txt)。[原生自动图形短验收](../../render-evidence/candidate-qa.json)覆盖真实输入/物理更新中的移动、射击、潜墨回墨、滚筒、死亡重生、隔离台阶上下与结算重开；起点/涂墨/伤害为测试条件，阶段等待被缩短。arm64 应用已集中导出一次并核验架构、签名与短时图形启动，见 [RENDERING.md](../RENDERING.md)。仍不宣称完整网页等价、人工操作手感、持续性能或温度达标；没有发布 Release。

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
- 保留网页游戏为行为基准。Godot 默认场景现为 Tidewater 地图、初始 90 秒（可选 180 秒）、1v1；旧平地样机可用 `run.sh --flat` 启动。网页配置的默认对局是 **180 秒、每队 5 人**，另有 90 秒选项。迁移每项规则时注明“与网页一致”或“样机简化”。依据：`config.js`（历史来源路径：`../../../public/game/src/config.js`）、`match.js`（历史来源路径：`../../../public/game/src/game/match.js`）。

## 2. 值得用的 Godot 特性

| 特性 | 在 INKWAVE 中的用途 | 采用条件 |
| --- | --- | --- |
| `SceneTree`、`Node3D`、独立场景 | 地图、角色、武器表现、HUD 分场景；对局状态由单独控制器管理 | 已有独立 [地图场景](../../scenes/world/tidewater_map.tscn)、[步行场](../../scenes/world/tidewater_walk.tscn)和默认[对局场景](../../scenes/match/tidewater_play.tscn)；后续把输入/HUD 从 `tidewater_play.gd` 拆出，避免继续扩大单个脚本 |
| `CharacterBody3D`、`StaticBody3D`、`CollisionShape3D`、射线查询 | 地图碰撞、坡道行走、跳跃、墙面接触与命中后定位可涂面 | 地图碰撞、水平加减速/转向、跳跃缓冲/离地宽限、低矮潜墨体积和基础己方墨墙攀爬已有短测；0.35 m 台阶、下台阶和临边足迹已有短测；高速落地减速/恢复已通过短测，人工攀爬/移动手感仍未验收。参考 [CharacterBody3D](https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html) |
| `InputMap` 动作 | 将移动、潜墨、射击、跳跃和选武器从硬编码键位抽离，便于键盘与手柄共用 | 拆分当前对局控制器的输入读取时一起迁；动作名使用 `snake_case`，保留现有键鼠默认操作。[官方输入示例](https://docs.godotengine.org/en/4.7/tutorials/inputs/input_examples.html) |
| `Resource` / `.tres` 数据 | 武器参数、地图描述、队伍配色等可编辑配置 | 多场景复用时使用；保留 `config.js` 中稳定的武器 ID 和单位，不在节点脚本中各存一份参数 |
| `PackedByteArray` + `Image` / `ImageTexture` + `ShaderMaterial` | 每表面 CPU 归属格负责规则；材质和纹理只显示归属结果 | [真实地图实验场](../../scenes/match/tidewater_play.tscn)已用 [多表面归属格](../../src/world/surface_ink.gd)驱动 [ImageTexture 显示层](../../src/world/surface_ink_view.gd)和计分。显示资源在首次涂墨时创建，最多 285 张独立纹理；长期帧成本未测，不能视为最终渲染方案 |
| `DrawableTexture2D` | 将来试验纹理绘制和减少整张纹理上传 | 只做隔离实验：该绘制 API 仍标为实验性，且 GPU 画面不能替代 CPU 的归属与得分数据。[官方类文档](https://docs.godotengine.org/en/4.7/classes/class_drawabletexture2d.html) |
| `CanvasLayer`、`Control`、`Label`、`ProgressBar` | 武器卡片、HUD、结算与响应式布局 | Tidewater 默认场景已有四图标卡片、顶部计时/覆盖率、墨量/生命/大招进度条、结果面板与中央准星；节点和数据绑定通过无界面短测，真实画面与完整 HUD 动画未验收。迁完整 UI 时保留可读性和中英文字体回退；4.8 的 `Label.auto_font_size` 可在长文本出现时试用。[4.8 dev4 说明](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-4/) |
| `Decal`、`Trail3D` | 命中贴花、弹道尾迹等短时特效 | 只用于视觉层，不能代替永久墨迹归属。**官方文档明确 Decals 只在 Forward+ 与 Mobile 可用**，Compatibility 不提供；此前本文写成"兼容渲染器支持贴花"是错的，已按 §2「渲染路线决策」纠正。[使用贴花](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html) |
| `NavigationAgent3D`、音频节点 | 后续机器人寻路、音乐和音效 | 当前 [临时蓝队](../../src/actors/tidewater_bot.gd)沿安全路线巡逻，短距离看到玩家时在碰撞/地面检查后追击，失去目标沿追击路径退回；复杂绕障与动态目标点仍需导航，不以新增节点数量判断完成度 |
| `MultiplayerAPI` / RPC | 后续原生版联机 | 单机规则和状态边界稳定后单独设计。现有 Web/P2P 会话协议不会因改用 Godot 自动兼容；权威方必须校验伤害、涂墨与结果。[官方联机文档](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html) |

4.8 的纹理流送面向较多大纹理；当前是少量 SVG 图标、平地样机的一张动态纹理，以及真实地图的多张小墨迹纹理，暂不启用。接触阴影同样不属于旧无光照基线的瓶颈。[dev5](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-5/)、[dev6](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-6/)

**当前优先使用**：`CharacterBody3D`/静态碰撞、固定步长、CPU 归属格、`ImageTexture`、独立场景和 `Control`。**需要时再用**：`InputMap`（替换目前的直接键位读取）、`.tres`（需要编辑器中共享调参时）、导航和音频。**隔离实验**：`DrawableTexture2D`、贴花、`Trail3D` 与 4.8 新渲染能力；先证明画质或帧时间收益，再接入正式场景。`project.godot` 已切换为 Forward+；`run.sh --compatibility` 保留无 SSAO 的兼容启动方式。当前未接入 Decal、Trail3D 或 GPU 权威墨迹。详见本节末尾「渲染路线决策」。

### 本项目的数据与场景接口

| 原网页模块 | Godot 中的对应物 | 当前状态与下一步 |
| --- | --- | --- |
| `maps.js`（历史来源路径：`../../../public/game/src/world/maps.js`） + `level.js`（历史来源路径：`../../../public/game/src/world/level.js`） | `tools/export_tidewater_map.mjs` → `assets/maps/tidewater.json` → [tidewater_map.tscn](../../scenes/world/tidewater_map.tscn) | 63 个结构块、10 个坡道、两个出生点及碰撞已短测；地图已接入默认对局场景，画面和完整对局未验收 |
| `Level._buildFaces` + `paint.js`（历史来源路径：`../../../public/game/src/world/paint.js`） | `tools/export_tidewater_surfaces.mjs` → `assets/maps/tidewater_surfaces.json` → [surface_ink.gd](../../src/world/surface_ink.gd) + [surface_ink_view.gd](../../src/world/surface_ink_view.gd) | 289 个表面、285 个可涂面、61 个计分面与 **69,366 个有效计分格**；归属、覆盖、重涂、拉伸墨形与逐面纹理同步已短测，墨迹图形未试玩 |
| `actor.js`（历史来源路径：`../../../public/game/src/game/actor.js`） + `physics.js`（历史来源路径：`../../../public/game/src/game/physics.js`） | [tidewater_walker.gd](../../src/actors/tidewater_walker.gd) + [tidewater_play.gd](../../src/match/tidewater_play.gd) → 后续正式玩家场景 | 已短测落地、坡道、水平运动、跳跃窗口、低矮潜墨碰撞体与安全站立、己方墨墙攀爬、敌墨伤害上限/延迟回血/重生保护及简化死亡重生；0.35 m 台阶/下台阶/临边足迹和蓝队基础生命规则已有短测；高速落地恢复已有短测；仍需原作伤害反应与人工手感验收 |
| `weapons.js`（历史来源路径：`../../../public/game/src/game/weapons.js`） + `config.js`（历史来源路径：`../../../public/game/src/config.js`） | `tools/export_weapon_config.mjs` → `assets/weapons.json` → [tidewater_combat.gd](../../src/combat/tidewater_combat.gd) | 四主武器、炸弹及冲击波/墨雨使用源码参数；选武器、墨耗、命中/涂墨、炸弹、大招充能及两类大招的核心事件已有无界面短测；完整弹道、命中判定、动画与特效待迁 |

数据流固定为“网页源码 → 导出脚本 → 带 `schema` 与稳定 ID 的 JSON → Godot 场景/规则”。JSON 是生成物，改地图或表面规则时改原源码和导出器，再运行 `--check`；不要在 JSON、场景和脚本中分别手改同一份几何。射线命中以碰撞体的 `source_id`、命中点和法线查表面 ID，再把局部 `u/v` 交给归属格。运行时可以为性能建立 block→face 索引，但索引不得改变表面 ID 或计分结果。

### 新代码的接口约定

1. [tidewater_map.gd](../../src/world/tidewater_map.gd)只负责几何、碰撞、出生点和 `source_id → face_id` 定位；不计算归属或伤害。[surface_ink.gd](../../src/world/surface_ink.gd)只持有格子归属和面积计数；显示与音效不得写回它的内部数组。[surface_ink_view.gd](../../src/world/surface_ink_view.gd)消费脏格更新纹理；删掉或替换显示层，不得改变 `coverage()` 结果。
2. [tidewater_combat.gd](../../src/combat/tidewater_combat.gd)按武器 ID 产生射击、命中、涂墨和伤害事件；[tidewater_play.gd](../../src/match/tidewater_play.gd)编排对局阶段、生命、重生和结算；[tidewater_bot.gd](../../src/actors/tidewater_bot.gd)持有临时蓝队的巡逻、短距离追击、涂墨和攻击间隔。继续迁移时，把输入读取也从对局控制器移出，避免继续扩大单个脚本。每次拆分后，原有短测仍应通过。
3. 对外数据保持 `schema`、地图/武器稳定 ID、队伍编号（橙队 0、蓝队 1）和 `coverage` 的 0–1 语义。距离用米、时间用秒、速度用米/秒；跨层接口显式命名 `face_id`、`local_u`、`local_v`，不把纹理像素坐标或 HUD 百分数传入规则层。新增导出字段时，先更新导出器和读取校验，再更新消费者及对应短测。
4. 场景负责节点连接，规则脚本负责状态变更，视觉脚本负责表现；引用其他模块时优先传明确的地图、墨迹或角色对象。`get_meta("source_id")` 仅用于命中后的来源定位，不把节点名或子节点顺序当成持久 ID。测试不得只断言节点数量，还要核对可观察的归属、伤害、重生或计分结果。

### 渲染路线决策：Forward+（基础已实现，持续负载待验收）

**决定（2026-09-27）：目标渲染器为 Forward+，不再把 GL Compatibility 作为正式路线。**
2026-09-29 已将 `project.godot` 的两个渲染器字段改为 `forward_plus`，本机图形日志确认使用 Metal 4.0 / Apple M5。配置、规则检查、短时截图与导出结果见 [RENDERING.md](../RENDERING.md)；该记录不代替持续帧时间或温度验收。
Forward+ 使用 RenderingDevice；在 macOS 上应按实际 Godot 版本和设备检查 Metal 后端，不能把 Forward+ 等同于 Vulkan。[Godot 渲染器说明](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

依据：

1. 交付目标是 macOS 单机应用（`export_macos.sh` 产出 arm64 `.app`），不是 Web 导出。Compatibility 的主要优势（最广硬件兼容、Web 导出必需）不在目标内。
2. 画面路线是 **Godot 干净简约风**（见 §4），但"墨迹显示要好看"恰好依赖 Compatibility 缺失的能力：
   - **MRT / 多渲染目标**：网页 `texlib.js`（历史来源路径：`../../../public/game/src/world/texlib.js`） 一次渲染写 albedo / normal / orm 三个附件；Compatibility 不支持 MRT。
   - **Decal**：官方文档明确 Decals 只在 Forward+ 与 Mobile 可用（见 §2 贴花一行），命中贴花不能按 Compatibility 推断。
   - **SSAO/SSIL 与后处理**：网页 `screenfx.js`（历史来源路径：`../../../public/game/src/fx/screenfx.js`） 的 GTAO + bloom + 色彩分级 + 暗角，在 Forward+ 对应 `WorldEnvironment` 的 SSAO/glow/Adjustment 或后处理 quad。
3. 温度仍以本机实测为准。Forward+ 的基础渲染开销可能高于 Compatibility；帧率上限、渲染分辨率和后处理也会影响负载。先保留当前低负载基线，切换时在同一场景比较帧时间和温度，不能预设哪项影响最大。

执行与验收清单（逐项证据见 RENDERING.md；未测项目保留为门槛）：

1. `project.godot` 的 `rendering/renderer/rendering_method` 与 `.mobile` 改为 `forward_plus`；确认真实入口仍是 `tidewater_play.tscn`。
2. 重新导入素材后运行 [tools/run_checks.sh](../../tools/run_checks.sh)。渲染器不影响规则层，**必须仍然全部通过**；任何失败都按规则回归处理，不要改断言迁就。
3. 图形启动一次，确认窗口、分辨率、HUD 布局、中文与 SVG 图标无回归；在同一 Mac、同窗口大小、同 1280×720、同墨迹覆盖率下记录帧时间，作为后续画面比较的基准。
4. 用 `export_macos.sh` 重新导出，确认 **arm64 能启动**（用户已排除 x86 路线），签名与短启动检查通过。

必须记录的风险：

- **设备兼容与负载都要验收。** 导出预设仅为 arm64，不再构建或验收 x86/Intel 路径。Apple Silicon 上仍需比较切换前后的画面、帧时间和温度。若未通过，保留 Compatibility 作为可玩的交付路线，并记录不能使用的 Forward+ 效果。
- 切换后所有按 Compatibility 推断的结论作废（例如"4.8 兼容渲染器支持贴花"）；§2 与 §4 里相关描述要跟着改。
- 不要把 Forward+ 当作"可以照搬网页全部特效"的许可：网页的渲染器、后处理参数与质量档（`config.js`（历史来源路径：`../../../public/game/src/config.js`） 的 `QUALITY`）仍需逐项对照，且必须先满足 §5 的帧时间与温度门槛。

## 3. 行为迁移规则

1. **先迁数据语义，再迁画面。** `config.js`（历史来源路径：`../../../public/game/src/config.js`） 是速度、伤害、射速、墨耗、对局时长与武器 ID 的来源；单位保持米、秒、每秒值。修改参数时记录原值、Godot 值及差异原因。
2. **运动用固定步长。** 原 `actor.js`（历史来源路径：`../../../public/game/src/game/actor.js`） 的水平加减速、反向制动、转向、跳跃缓冲、离地宽限、顶点/下落重力和终端下落速度已按源码参数迁入 `_physics_process`，墙面攀爬也有基础实现。kid 与潜墨体按源码的高度、半径和抬升量生成胶囊体，潜墨轴段退化为球体；kid 下边界为 `stepUp`，潜墨下边界为 `squidBodyLift`，站起前检查站立体是否有空间。已对照原 `physics.js`（历史来源路径：`../../../public/game/src/game/physics.js`） 接入 `stepUp`、`stepDown` 与 `footRadius` 足迹探针，并验证 0.35 m 台阶、下台阶和临边支撑；已接通 `hardLandSpeed`、`hardLandSlow` 与 `hardLandTime` 的减速和恢复，并有隔离短测。显示帧率与物理更新频率分别配置；规则短测不能替代实际手感验收。
3. **涂墨逻辑只有一个权威状态。** 原 `paint.js`（历史来源路径：`../../../public/game/src/world/paint.js`） 按可涂表面保存约 0.25 米的格子归属；地面/坡面的有效 turf 格用于面积计分，墙面可涂供攀爬但不计入 turf。Godot 的纹理、贴花和粒子只从该状态生成，不反向决定归属。重复涂己方格不加分，敌方重涂同时更新双方计数；被地图几何**或场景道具碰撞盒**遮挡的格子不计入分母——导出器必须用与运行时相同的 `Level` 构造（含 `dressingFor()` 的道具碰撞盒，见 `tools/lib/runtime_level.mjs`），漏掉道具会把分母从 69,366 抬到 70,180（+1.16 %），使每个对局的覆盖率整体偏低。掠射命中的墨团会沿射击方向拉伸，该拉伸同时作用于计分格，不能只做视觉。`coverage(team)` 对规则层返回 **0–1 比例**，HUD 才乘以 100 显示百分数。
4. **区分样机网格与正式地图。** 旧平地场景的 [paint_field.gd](../../src/legacy/paint_field.gd) 是 40×40 米、256²、仅地面的简化格。默认真实地图场景已用 [surface_ink.gd](../../src/world/surface_ink.gd) 的表面 ID、局部坐标和格子归属驱动己方墨速度、敌墨减速/伤害、基础墙面攀爬、低矮潜墨碰撞体、HUD 及计分；接完整玩家时还要加入伤害反馈与正式裁判。不要把平地 `x/z` 采样直接套到墙面。墨迹视觉的扩张动画和甩墨拉伸需分别对照网页实现，不能用当前格子显示宣称已完成。
5. **武器按状态和事件迁。** 射手连续射击、滚筒滚动/甩墨、蓄力狙按住/松开发射、爆破枪飞行/爆炸各保留其原始墨耗、冷却、伤害和涂墨事件；共用墨水炸弹按住/松开投掷、碰地引信、爆炸涂墨和距离伤害已有短测。玩家造成的新涂墨面积向所选武器的大招充能；冲击波与墨雨使用源码持续时间、范围和伤害参数，死亡充能减半。大招规则已有无界面短测，完整画面、粒子、音效及手感仍待验收。命中判定与特效分开，以 `weapons.js`（历史来源路径：`../../../public/game/src/game/weapons.js`）、`actor.js`（历史来源路径：`../../../public/game/src/game/actor.js`） 和 `config.js` 对照。遵照本项目选择：赛前及重生等待期间可换武器，活着的对局过程中不切换。
6. **对局状态显式化。** 原 `match.js`（历史来源路径：`../../../public/game/src/game/match.js`） 的状态是 `intro → playing → finish → judge → results`，没有独立 `countdown` 状态；`intro` 的原作表现是镜头/队伍介绍，数字倒计时发生在 `playing` 的最后 10 秒。真实地图样机额外有赛前 `setup`，按 Enter 后等待 4.2 秒才开始扣 90 秒对局时间；目前 `intro` 只显示简化文字倒数，尚未移植镜头与队伍介绍。终场冻结 2.6 秒后取权威墨迹覆盖率，直接进入结果；2026-10-01 按用户要求移除了额外约 5.1 秒的裁判阶段与缓慢进度条（仅源码补丁，未重新编译）。最后 10 秒提示与对局时长都从 `assets/weapons.json` 的 `match.finalCountdown` / `match.durations` 读取（赛前菜单通过 `MatchSetup.duration_index` 选择时长选项），不再在脚本里硬编码。原作覆盖率相同时随机决定胜方，样机也保持这一规则。90 秒和 1v1 仍是样机选项，原作默认 180 秒、每队 5 人。
7. **生命规则读同一墨迹状态。** 真实地图玩家使用 `actor.js`（历史来源路径：`../../../public/game/src/game/actor.js`） 的敌墨每秒伤害、累计上限、最低 1 点生命、离墨后衰减、延迟回血、己方墨潜行加速回血与重生保护；原作初次站在出生平台时无敌时间为 0，只有重生后使用 `spawnInvuln`。落海死亡不受无敌保护阻挡。临时蓝队现已使用相同的敌墨伤害、累计上限、普通回血和重生保护配置；其简单 AI 没有潜墨形态，因此没有潜墨加速回血。新增普通命中伤害时经过统一的玩家受伤入口；敌墨按非致死规则扣血，并分别验证无敌、致死和重生状态。

## 4. 地图、素材与 UI 规范

- 网页地图由几何定义生成，Godot 版需要重建几何、碰撞和可涂面映射。`两张 PNG 光照图`（历史来源路径：`../../../public/game/assets/lightmaps/`）依赖原地图 UV；只有 UV 对齐并核验画面后才复用，不能直接铺到样机地面。
- 四个武器图标从 `ui-icons.js`（历史来源路径：`../../../public/game/src/ui/ui-icons.js`） 导出为 `assets/ui/*.svg`；两份 WOFF2 字体复制到 `assets/fonts/`。导出脚本是图标的再生成入口，手工修改图标需同步源或注明分叉。中文字体使用可验证的回退方案。
- 网页的 CSS/Canvas 动效与程序化角色、场景纹理不是现成贴图。Godot 里按功能重建：先清晰可用的卡片/HUD，再做装饰动画。比较界面时固定 1280×720，并额外检查窗口缩放和中文溢出。
- 当前 [角色外观脚本](../../src/actors/tidewater_character_visual.gd)按原角色的脚底、面朝方向和头部高度生成低面数人形，加入阵营色、墨罐、潜墨体和四种武器轮廓。它响应 `set_form`/`set_weapon` 和只复制跑速标量的 `configure_animation`，读取速度/位置差分以驱动基础待机/行走动作，规则状态仍由控制器和战斗脚本决定；替换成正式模型时保持这个单向接口，并核对第三人称镜头遮挡、动作方向与低矮潜墨碰撞体。无界面 [外观短测](../../tests/godot/check_tidewater_visual.gd)不等于画面验收。

## 5. 性能与验证门槛

- 默认样机和真实地图实验场均将显示帧率及物理步长设为 30；这只是负载上限，**不是温度承诺**。旧 [paint_field.gd](../../src/legacy/paint_field.gd) 墨迹变脏时上传整张 256² 纹理；新显示层启动时不创建墨迹网格/纹理，只为首次涂墨的面创建资源，此后仅上传发生改变的面。最多仍可能达到 285 个独立网格与纹理。后续记录涂墨次数、CPU 脚本时间、帧时间和纹理上传频率，再决定是否合并材质/网格、改用 atlas 或试验新纹理 API。[Godot Profiler](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/the_profiler.html)
- 当前设备运行 Godot 曾达到 90°C 以上，因此日常批次只做静态检查和必要的短时无界面规则检查，**不自动启动编辑器或持续游戏试玩**。2026-09-27 做过数帧图形截图，目视检查了赛前/开局静态布局并据此修复菜单溢出；这只能证明这些时刻的渲染，不能声明整局画面可玩。完整 90/180 秒对局和温度测试独立安排；在相同 Mac、窗口大小、帧率与场景下比较，记录传感器名、室温、运行时长和最高温。设备再次明显升温时停止该次测试。
- **渲染器切换的验证门槛（Forward+，见 §2「渲染路线决策」）**：切换后规则短测必须仍然全部通过（渲染器不影响规则层，失败即视为回归）；必须验证 arm64 的导出程序能启动（x86 已由用户排除）；帧时间与温度要与切换前在同一 Mac、同窗口大小、同分辨率、同墨迹覆盖程度下比较，不能只报"能跑"。
- 对照用例至少覆盖：空地/己方/敌方墨的速度和回墨、覆盖率重涂、四种武器的墨耗/命中/涂墨、死亡后换武器、时间结束结算。声明“已移植”必须同时附对应的可重现用例与结果；截图只能证明画面，不证明手感或性能。
- **先跑唯一入口**：`NODE=<node> godot-port-prototype/tools/run_checks.sh`。它会依次做素材导入、5 个导出器 `--check`（都是只读的，不得写生成物）、解析预检（失败立即停止）和其余 `tools/check_*.gd`，输出 `PASS/FAIL` 汇总表并以非 0 退出表示失败。逐个手跑脚本是这套东西漂移的原因：曾经有 2 个短测长期失败而文档仍写"通过"。
- 判定一个短测通过：退出码为 0、输出含 `PASS`、且日志中没有脚本或解析错误；仅看退出码不足以证明 GDScript 已加载。runner 对每个检查有超时看门狗（`CHECK_TIMEOUT`，默认 120 秒）：脚本错误会让 SceneTree 不走到 `quit()`，没有超时会整个套件无输出地挂住。
- 若 CLI 名称不是 `godot`，用对应的 Godot 4.8 可执行文件；node 不在 PATH 时用 `NODE=` 指定。规则短测重点看大招 [check_tidewater_special.gd](../../tests/godot/check_tidewater_special.gd)、HUD [check_tidewater_hud.gd](../../tests/godot/check_tidewater_hud.gd) 与整局时间模拟 [check_tidewater_full_round.gd](../../tests/godot/check_tidewater_full_round.gd)。加速时间模拟不能证明真实帧率或手感；导出器 `--check` 只能证明数据与网页源码一致，不能证明规则正确。

## 6. 可交付批次

| 批次 | 完成条件 |
| --- | --- |
| A：当前样机 | 平地单机循环、四武器核心行为、HUD；保留简化标识。已做短流程验证，完整对局和温度未验收 |
| B：真实地图与移动 | 一张地图的几何/碰撞、坡道与墙面、独立可涂面、攀爬；同一涂墨状态驱动移动和裁判 |
| C：规则与内容 | 完整四武器行为、炸弹与大招、机器人、正式对局状态和人数；逐项记录与网页差异。炸弹和两类大招的核心事件已短测，完整表现、机器人策略和人数仍在迁移 |
| D：Mac 应用 | [导出预设](../../export_presets.cfg)与[无界面导出脚本](../../export_macos.sh)已添加，本机已安装官方 4.8.dev6 模板；当前仅导出 arm64 `.app`（早期 Universal 记录不再作为当前路线）；签名、资源包及两帧无界面启动通过。仍需窗口画面、输入、整局和温度验收。向他人分发时再处理正式签名与公证。[macOS 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html) |
| E：联机 | 单独立项：明确权威方、同步哪些输入/涂墨事件及 Web 版是否互通；不得把单机样机视为已有联机能力 |

历史批次状态（2026-09-28，以 `tools/run_checks.sh` 全部通过为证）：

- **已完成**：基线入库；统一验证入口；导出分母修正（含道具碰撞盒）与两个导出器共用同一 `Level` 构造；配置改为整体导出并真正消费 `match`；弹道拖尾涂墨、圆盘散布与 bloom、CPU 拉伸、滚筒碾压冷却与起速曲线、弹丸逐类型存活时间/重力/阻力、命中体改为身体胶囊；空墨回墨死锁与潜墨开火丢失；射手按 30 Hz 弹体更新补偿发射角；蓝队四武器核心攻击与玩家共用弹体、射线、地形命中、伤害和涂墨通道，墨耗/回墨读同一配置；蓝队从同一墨迹网格读取敌墨伤害，按玩家配置处理伤害上限、普通回血、重生时长与无敌保护；玩家 `stepUp`、`stepDown` 与 `footRadius` 足迹探针、10 个朝向弹簧参数通过隔离场景短测；爆破枪 `burstRadius` 用于短暂可见爆炸球体。
- **未完成（B/C 剩余）**：蓝队尚未共用玩家的完整 WeaponRunner 状态、潜墨/潜墨加速回血，也仍沿固定路线涂墨；目前四武器是 1v1 样机的简化 AI，瞄准与蓄力/滚筒起手没有原版反应和动画。`ledgeAssist` 目前只参与落地探针，`squidBodyLift`/`hardLand*` 等移动手感字段尚未完整消费；足迹探针和朝向弹簧通过规则短测，实际手感仍需图形试玩。
- **独立门槛**：Forward+ 基础渲染已实现，见 [RENDERING.md](../RENDERING.md)。完整图形试玩、整局帧时间与温度仍需独立验收。

上述 2026-09-28 未完成字段状态已由本页 2026-09-30 状态取代。当前决策：按授权已实现渲染基础与本批集成；B/C 剩余规则仍按原边界推进，不以画面升级声明规则迁完。Forward+ 已有短时画面证据；Mac 导出、持续图形试玩和温度分别记录验收状态。Godot 4.8 的新增视觉特性只在隔离实验中评估，不能替代这些规则门槛。

### 每个迁移批次的提交记录

1. **定基准。** 写出网页源码位置、输入、状态变化和可观察结果；参数从 `config.js` 等源文件导出，固定 ID、单位与默认值。若有简化，写明与网页的差异及原因。
2. **接完整链路。** 一次实现一个可观察事件链，例如“武器命中 → 归属格改变 → 面积变化 → HUD 读取”。地图/墨迹/战斗/对局/显示各由上文约定的模块负责，避免视觉反写规则。
3. **分层验证。** 导出器运行 `--check`；规则跑对应的短时无界面检查并检查日志；画面、输入、整局和温度另行验收。只有静态或无界面证据时，状态写“规则短测通过”，不要写“可玩已验收”。
4. **记录边界。** 每批留下网页源码、Godot 文件、可重复命令与结果，以及尚未验证的画面/性能问题。性能改动要在同一地图、分辨率、帧率、墨迹覆盖程度下比较，不用温度单值代替帧时间与脚本耗时。
