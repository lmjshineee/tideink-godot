# 属性加点与人物差异 · preview.24 验收

本批已生成并打开 `build/TideInk.app`，版本 `0.3.0-preview.24`／build `0.3.24`，仅 arm64。用户选择潮墨街头风和体型差异；产品流程改为直接加点，四种造型使用不同的真实几何。设计与操作见 [属性与人物说明](../../docs/ATTRIBUTES_CHARACTERS.md)。

2026-10-10 人工外观反馈：用户明确拒绝本批造型，指出外观需要改正。自动规则／输入通过不等于审美通过；下一批重做服装本体和头身轮廓。当前加点与 App 构建证据保留。

## 可玩的变化

1. 准备页「属性 · 加点」打开潮汐之镜：20 点、八属性、各 0—8 级，可加减、返还、免费重置和 ROLL。生命／墨量／跑速／潜泳／省墨／回墨／充能／副武器冷却均接入实际规则；伤害不增加。均衡零加点仍为 132 HP／110 墨量；满生命分配最高 155.76 HP，能够接住 150 的满蓄精准狙击。
2. 队友、对手在首次入场前独立随机分配，与玩家实际已花点数相同。玩家花 20 点，每个机器人也花 20；只花 13 点，机器人也各花 13。整局固定，死亡和主副重摇不重置，保留玩家主动选择复活和跨死亡冷却。
3. 礁跑、鳍影、港工、电涂四个本地 GLB 改变体型、脸型、发型和服装剪裁／鞋型／附件。共用保留的 87 骨骼，原始四个 GLB 不变；并非四套从零新建骨架。菜单与对局使用同一造型，可鼠标或 Enter 切换。外观不修改战斗胶囊、命中倍率、速度或计分。

## 规则与源码证据

- [最终完整回归](checks-committable.txt)：110 通过、0 失败，解析与资源门先行。输入提交 `d6d2087d5c70b0643f7849ada399f71d4d59987e`；[冻结清单](frozen-production.json) 保存 626 个生产输入。
- 之后只把两个 UI 字串「装备省墨／装备重摇」改成「属性省墨／配装重摇」。[变更边界](copy-only-ui.json)、[最终解析](post-copy-parse.txt)、[配装专项](post-copy-loadout.txt) 通过；最终包内规则／原生组覆盖这一文案版本，没有把旧全回归说成最终字节的全回归。
- [属性专项](source-rule-logs/check_attribute_allocation.log)：非法／超预算／超等级／别名负例、200 次 ROLL、真实八属性与八武器主射消耗、生命和墨量上限、机器人相同预算、整局锁定及死亡／重载保留通过。
- [模型 Python 语义](model-semantic-final.txt)、[原始骨架规则](original-rig.txt) 和 [新造型运行规则](source-rule-logs/check_character_archetypes.log) 在显式追加资源清单前通过；只新增四条，原 270 条内容保持，最终 274 条。432 个既有资产文件除这一清单外保持原字节，285 个既有 UID 原值保留，其中五个随文件改名迁移。见 [保护输入核对](protected-inputs.json)。
- [解析门负例](parse-negative.txt)、[资产负例](integrity-negative.txt)、[11 项构建收据负例](release-negative.txt) 通过。

## 原生输入与自然对局

[最终源码输入](native-fixed/attributes.json) 与 [包内输入](app-verification-final/attribute-native/attributes.json) 验证实际 GUI 鼠标加减／重置／ROLL、Enter／Esc、1280×720 和 960×540／110% 设置、规则和造型重载保留、真实全局主射输入扣除 0.8041 墨、开战后拒绝再编辑。预览与外观按钮保留间隔，避免可拖动区域挡住按钮。

[独立自然自动对局](natural-match/match.json)：潮水码头 5v5 区域争夺自然运行 179.97 秒，15 次自然死亡、14 次确认并完成复活；十名角色各 20 点且整局快照保持。自然计时、结算、个人累计面积加总、CPU 覆盖与重开通过。没有与无界面回归并行。30 FPS 限制下帧间隔 p50 33.35 ms、p95 35.36 ms、p99 38.25 ms，3 帧超过 50 ms；统计含截图、桌面调度，排除前 5 秒。它不是 GPU 时间或温度验收，也不是真人平衡。

[实际包内模型画面](app-verification-final/art-native/characters.json) 有 40 张图：四人同队色正面／侧面／背面／跑动、四张脸部和每种造型八种持武器。[同队色造型图](app-verification-final/art-native/lineup-three-quarter.png) 和 [加点 UI](app-verification-final/attribute-native/attributes-1280.png) 已检查；用户审美仍待人工试玩反馈。

## 实际导出与旧版备份

- 导出生产提交 `6ca5df5f080153c7709fd199acf8b651584a68a2`；工具验收夹具随后单独修正，不改变应用生产输入。PCK SHA-256 `396841b2ea91069d392118921aa1bcbf51f0312039a29c83efc25331f85b738d`。ad-hoc 签名通过严格核验，只有 arm64。
- [最终实际 PCK 验证](app-verification-final/verification.json)：31 项规则、六组原生 UI／墨仔／主射／配装／加点／人物画面通过。夹具在临时目录由匹配的 Godot 编辑器显式加载此 PCK；实际 App 启动另行进行，没有混同两种方法。
- [工程外实际 Metal 启动](standalone-metal.json)：捆绑可执行文件从临时目录运行 45 帧，无 `--path`／脚本／主包覆盖；Apple M5／Metal，无 Godot 错误或警告。[新版打开记录](app-open.json) 确认新进程，旧实例未被关闭。
- 本次在覆盖前核验并备份 preview.23：`build/TideInk-preview.23.app`、两份旧收据的七个应用文件全部匹配旧收据。见 [备份记录](backup-preview23.json)。它不回写 preview.23 当时未建立备份的历史事实。
- [最终审计](final-audit.json) 再次核对版本、626 个生产输入、全部应用文件、PCK、旧版备份与保护资源。没有压缩／上传／推送／发布。

## 已记录的失败与边界

初期导入类型推断、图标路径和相对日志路径问题已修正，保留原日志。原生输入曾受到 OS 光标 warp 延迟事件影响；夹具改成同序 GUI 按下／松开事件，并保持真实主射的全局 Input 路径。最初的两个尺寸比较错误沿用前一次 ROLL 的随机天赋，已逐尺寸设置均衡作为基准。

首次包内验收停在旧配装夹具：它把 ROLL 后的生命／墨量仍固定为 132／110，而正确画面实际为 147／128 和 144／124。修改为核对当前有效上限，并检查已用 20 点；未修改游戏数值或重导出，最终同一 PCK 全部通过。初次失败证据保留在 [原记录](app-verification/loadout-native/loadout.json)。

无界面源码 24 项夹具、包内 8 项规则和实际 App headless 启动存在 ObjectDB 退出引用警告；导出 stdout 也有两个退出引用警告。[审计清单](final-audit.json) 保留逐日志记录，不声明无警告。最终六组原生、自然对局及工程外 Metal 记录没有 Godot 警告。这不证明长时间运行不存在资源增长。

加点只在本次会话保存：地图／规则／造型重载和结算重开保留，退出 App 后没有磁盘属性存档。没有跨局货币、解锁树、真实玩家平衡／审美验收、其他地图长局或长期性能／温度验收。
