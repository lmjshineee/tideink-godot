# preview.22 伤害、配装与区域争夺验收

本批根据用户确认的宽容节奏、固定／自定义并存和两类涂地区域限制实现。源码规则与说明见 [COMBAT_BALANCE](../../docs/COMBAT_BALANCE.md)。

## 源码与受控规则

- `checks-final.txt`：统一入口 108 通过／0 失败，270 项语义资产；最终视觉标记与机器人套装同步另有 `parse-final.txt`、`loadout-final.txt`、`area-final.txt` 通过。最终完整源码复核 `checks-committable.txt` 同样 108 通过／0 失败。
- `release-negative.txt`：11 项构建收据隔离反例通过；`parse-negative.txt` 与 `asset-negative.txt` 记录坏脚本／依赖／空清单和资源损坏／缺失／新增等拒绝检查。
- `protected-inputs.json`：432 个资产文件和原有 250 个 UID 完全未改；arm64 模板缓存 SHA256 校验通过，不执行其他架构。

## 原生输入与画面

- `native-combat/combat.json`：真实左键持蓄／释放，132 HP 目标被狙准确击倒；实际 60 护盾使狙命中后剩 42 HP；满蓄弓剩 27 HP，实际再次蓄力追击击倒。悬停详情显示新数值且完整适配。
- `native-final/loadout.json`：最终源码的实际鼠标 ROLL、固定／自定义切换、主／副选择；1280×720 与 960×540／110% 画布输入；规则切换保留配装；人工涂墨验证区域控制／罚分／结算。该夹具冻结对局与 AI，不作为自然计时／真人体验证据。
- `native-loadout*` 保存中间失败与修复过程，不代表最终通过：前几轮菜单事件路由错误，后改为直接切换按钮；110% 画布点击应使用 `get_global_transform_with_canvas()`。最后修正截图的夹具暂停遮挡。

## 原生完整对局

`natural-area2/match.json`：Metal / Apple M5 / arm64、潮水码头、5v5、喷枪、180 秒。自动键鼠输入，生产机器人、自然时钟与伤害；10 次自然死亡、10 次显式选择并确认的复活，自然结算与重开通过。双方最佳计数 36.5667 / 100；个人面积／实时积分／团队账本与 CPU 最终覆盖核对通过。不是人工试玩。

本次墙钟 180.04 秒；排除前五秒后 5245 帧，平均 29.96 FPS，p95 35.49ms、p99 37.44ms、最长 138.55ms，3 帧超过 50ms。包括 30 FPS 上限、截图与桌面调度；没有温度或 GPU 执行时间采样。不同输入和模式不能据此认定 preview.21 的 823.23ms 长帧问题已修复。

## 实际导出

已本地导出 `build/TideInk.app`、`0.3.0-preview.22`、bundle build `0.3.22`，仅 arm64，严格签名检查通过。生产输入提交 `2cf1854f2c64c323c55e58dcbccd50f3d80fc57d`。旧 preview.21 App 及两份构建收据已分别保留，preview.20 也保留。

`app-verification/` 首次运行的 29 项实际 PCK 规则和两尺寸通用 UI 已通过；旧伙伴夹具的已锁定准备状态与 100 点校准墨量的闲置回补导致输入断言失败。已在夹具中恢复真实准备状态、使用画布坐标、固定瞄准并暂停校准过程的闲置回墨。没有修改生产 App 的字节来处理这些断言。`app-verification-final/verification.json` 最终 29 项实际 PCK 规则全部通过；实际包内通用 UI／伙伴右键和 E／鼠标蓄力射击与护盾／配装 ROLL、套装、规则切换和区域结算全部通过。实际 App 从工程外 headless 启动退出 0，无源码或脚本覆盖；`app-metal-startup.txt` 记录同样工程外 45 帧 Metal 原生启动退出 0。

PCK SHA256：`5b217f946d8214294d1561c395a5ba6af38e2d76c2617ca8c34d49a00f8dbe3c`。构建收据为 `build/export-receipt.json`；最终一致性核对写入 `final-audit.json`。四项旧规则夹具有退出引用警告（actor_turf_credit 14、gameplay_deployment 20、expanded_loadouts 20、map_routes26 2）。实际 App 无界面退出有两个音频引用；`app-headless45.txt` 的 verbose 对象为 Music 的 AudioStreamWAV／AudioStreamPlaybackWAV，未处理或掩盖此边界。最终原生输入与实际 Metal 启动没有 Godot 错误／警告；macOS IMKCFRunLoop 诊断保留原文，不计作 Godot 脚本告警。

已用 `open -n` 打开当前 preview.22，并通过完整可执行路径确认进程；证据见 `app-open.json`。没有推送、上传、压缩或发布。

真人平衡、其他地图长局、审美与长期性能／温度仍未验收。
