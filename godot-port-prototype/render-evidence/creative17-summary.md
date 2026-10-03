# 高低层交战与弓／挡墨伞 · 2026-10-02 · 当前源码

## 修复结果

| 位置 | 复现原因 | 当前处理 | 验证 |
| --- | --- | --- | --- |
| `tidewater_combat.gd::_aim_target` | 摄像机准星忽略敌人胶囊，取敌人后方远点；枪口与摄像机有视差，同层和高低层都会打偏 | 优先选最近的敌方胶囊或遮挡物，枪口朝真实三维目标发射 | 蓄力狙与弓：-3／0／+3／+6 m；喷枪、爆破、飞镖、伞弹：-3／0／+3 m 实际准星命中 |
| `tidewater_combat.gd::_spawn_flick_from` | 将方向高度分量清为零，再统一加 0.32 弧度，朝上／朝下完全一样 | 保留三维瞄准俯仰后添加抛物线初始角 | 上下瞄准发射角从都为 0.32 改为 -0.18／0.82 |
| `tidewater_bot.gd::_tick_team` | 机器人枪口姿态固定零俯仰 | 按目标实际高度设置枪口与武器姿态；恢复开火提示 | 向上目标枪口俯仰 0.56；原生上下层画面 |
| `tidewater_bot.gd` / `tidewater_play.gd::_build_roster` | 1v1 主机器人走旧 XZ 巡逻，没有团队模式的碰撞体、重力和高层路线 | 所有人数共用 CharacterBody3D 和三维导航，滚筒真实接触／阵营涂墨一起保留 | 1v1 与 5v5 均沿真实坡道到 6 m；自然 1v1 回放机器人最高 6.012 m |

Godot 使用 Y 轴表示高度。这里修的是交战与移动规则，地图高度本身已存在。真人对“立体感”的手感反馈尚未验收。

## 新武器

- **三弦墨弓**：左键蓄力／松开三箭，地面横向、空中纵向；1 秒满蓄、11→24 m、4.5→10 墨水、每箭 14→33。≥80% 蓄力的地形命中箭在 0.65 秒后爆裂；三支箭同轮溅射共用 32、单目标总预算 110，逆境后最多 115；真实墙／薄楼板遮挡。独立持握／箭矢模型、SVG 图标、详情与机器人规则。
- **推进挡墨伞**：点按发射六弹各 14／8 墨水；按住 0.28 秒展开 160 HP 实体伞面，每秒 3 墨水；按住至 1.2 秒额外 12 墨水推出，6 m/s、3 秒、撞墙结束。敌弹伤伞、友弹穿过、侧后方暴露；结束 CD 6 秒并跨死亡／重摇保留。实际开伞／推进模型、耐久／恢复 HUD、图标与机器人受击防御。
- 当前选择池 **8 武器／4 道具／4 天赋**。已停用的重复装备仍只保留旧规则兼容。两新武器的大招暂沿用墨雨／重击；雨箭等专属大招未实现。

## 验证与证据边界

- **90 项通过、0 失败**：[完整回归](creative17-checks.txt)、[解析](creative17-parse.txt)。首轮 89 通过／1 失败记录在 [首轮日志](creative17-checks-first.txt)：旧朝向断言要求 0.1 秒内精确转到 PI，已改为核验实际碰撞移动方向和允许的朝向平滑；同时补回主机器人开火提示。
- 修前复现：[战斗](vertical17-before.txt)、[1v1 导航](vertical17-navigation-before.txt)。最终实际规则：[上下层及六类攻击薄楼板遮挡](creative17-check_vertical_combat.txt)、[双方人数的 6 m 通行](creative17-check_vertical_navigation.txt)、[弓](creative17-check_creative_bow.txt)、[伞](creative17-check_creative_canopy.txt)。短测退出的 WAV/Playback ObjectDB 警告来自快速无界面音频退出；规则检查无脚本错误。
- Metal / Forward+：[原生日志](creative17-native.txt)，[弓配装](creative17-bow-loadout.png)、[实际持握](creative17-bow-held.png)、[瞄准高层](creative17-aim-upper-deck.png)、[箭矢](creative17-arrows-upper-deck.png)、[俯视低层](creative17-aim-lower-deck.png)、[开伞](creative17-canopy-open.png)、[推进](creative17-canopy-launch.png)。截图为受控角色落点和输入。
- **两局自然 90 秒**：[原始记录](creative17-full-matches.json)、[运行日志](creative17-matches.txt)。展馆 1v1 全局使用弓，自然死亡／复活 1 次，机器人到 6.012 m；花园 5v5 全局使用伞，玩家未死亡，九名机器人有自然战斗／死亡／重生，最高约 3.67 m。两局玩家跳跃弧线最高约 7.28 m，记录包含弧线，不能称为 7.28 m 站立平台。两局都自然计时、结算、Enter 返回主菜单，没有强制伤害／结束或传送玩家。
- 本机该次自动输入约 29.98／29.97 FPS，P99 帧间隔 36.82／40.15 ms；30 FPS / 75% 精度，后台同时运行 headless 回归。不能作为独占性能基准、真人平衡或长期温度验收。

公开应用仍是 **preview.15**；本批未提交、导出或发布。`run.sh` 运行当前源码，`tools/preview_creative.gd` 默认选弓与展馆，配装第 8 项为伞。人物实验继续暂停。
