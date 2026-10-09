# preview.21 · 伤害续批与可玩应用

已交付：`build/TideInk.app`，`0.3.0-preview.21`，约 320 MB；106 项源码回归、27 项实际 PCK 规则和原生输入／实际应用启动通过。旧 preview.20 保留在 `build/TideInk-preview.20.app`。仅 Apple Silicon / arm64，保留 5v5 / 1v1。

## 设计与实现

120 HP 保持不变。喷枪三发、双持三轮靠持续准确命中；满蓄狙、爆破直击和近距滚筒奖励蓄力、精度或接近风险。双持每弹 21、轮间隔 .16 秒／1.4 墨；弓每箭 17→42，满蓄三箭 126，原 .4／.8 秒蓄力、2.5→6 墨和弹道保留。弓整轮 130 出手／140 最终预算，防止飞行途中增伤／易伤累加突破。

弓漏一箭剩 36 HP、半蓄直接命中剩 31.5、60 护盾命中后剩 54、低墨减伤剩 19.2；遮挡仍有效。飞镖一次往返 82、伞六弹 90，保留追击与防御的设计。八武器当前参数与比较依据见 [COMBAT_BALANCE](../../docs/COMBAT_BALANCE.md)。这是待真人校准的设计假设。

应用还合并三批已有源码：[滚筒贴地](../ink-loop-2026-10-08/summary.md)、[机器人回墨](../bot-ink-2026-10-09/summary.md)、[基础伤害](../combat-balance-2026-10-09/summary.md)。进入本轮的 HEAD、未提交清单与哈希见 `starting-state.json`，原有资产／UID 保留审计见 `source-preservation.json`。

## 验证记录

- 三项最终专项：`check_extended_damage-final.txt`、`check_bow_precision-final.txt`、`check_creative_bow-final.txt`，均通过。覆盖玩家和两队 AI 实际弹丸、两弹／两箭漏射、半蓄、护盾、低墨、末端距离、强化／易伤及薄墙负例；300 HP 只用于观察 140 共享上限，不修改生产生命值。
- `source-suite.txt`：完整源码回归 106 项通过、0 失败，包含编译门与 270 个资产语义／完整性检查。
- `receipt-isolation.txt`：11 项构建收据隔离检查通过。
- 首次专项使用相对 `--log-file`，Godot 将日志放到 user:// 而遭权限拒绝；初次弓 AI 夹具还复用了已死亡目标。原日志保留，最终绝对路径日志和每例重置目标的检查取代它们。仅系统 CA 查询报错列为已知环境噪声，脚本／场景错误不忽略。

- 原生前三次检查的卡片悬停有失败，日志／画面保留在 `native-source`、`native-source-final`、`native-source-verified`。新增记录显示真实悬停已到正确卡片、内容正确，但浮层尚未满足 0.15 秒展示延迟；按帧等待不能保证实际时间。夹具保留实际鼠标事件，改为真实等待 0.25 秒，同时等初始延迟滚动并先离开旧卡片；未修改生产界面。`native-source-accepted` 通过三卡片实际悬停，但截图显示弓说明底部过长。随后仅压缩弓的说明措辞并增加完整面板边界检查；`native-source-delivery` 仍发现正文溢出，进一步压缩雨箭说明；该次弓释放未命中，固定瞄准夹具还未隔离原生光标回中造成的视角输入，因此关闭夹具角色的鼠标视角处理（按钮事件与生产 Combat.tick 仍实际执行），悬停按真实浮层状态有界等待。最终记录以 `native-source-ready` 为准。

- 106 项统一入口之后，仅压缩弓说明措辞、修正原生检查等待时序，未再改伤害。最终编译门和配装隔离检查见 `parse-delivery.txt`／`menu-cleanup-final.txt`；最终原生检查另覆盖鼠标狙／弓、护盾与三卡片实际悬停及完整面板边界。

- `native-source-ready/combat.json`：最终 Metal 原生验证通过，69 个运行／检查文件哈希与当前源码完全匹配；真实鼠标满蓄狙消耗 14、60 护盾命中剩 30 HP，满蓄弓消耗 6／击倒；三种实际悬停与完整正文边界通过，失焦恢复 0 次。固定瞄准、冻结 AI 与输入步进不等于自然真人操作。
- `final-source.json`：432 个原资产文件和全部 249 份旧 UID 未改，新增一份测试 UID。模板缓存 SHA 保持原值；270 个计数是资产完整性清单的语义资产数，不与文件数混用。

- 首次最终配装专项 `menu-delivery.txt` 规则通过，但退出时有 4 个音频 ObjectDB 引用警告。仅测试夹具采用与其他创意检查一致的停播／释放等待；后续最终记录见 `menu-cleanup-final.txt`。此改动不属于生产输入，不改变已导出应用。

## 实际应用与包内验证

生产输入本地提交：`e8e2c49256e0de84f34c750321b2bdf7063d88b6`。复用原 `.godot/arm64-template.zip`，哈希 `daf43479c6c792c06d47e22e59bdbac39170d27b6bc5e739871d17601ba2fce7` 未改变。先导出到新目录，再保留旧应用并替换；架构、版本、签名、输入及应用字节由 `export-receipt.json` 绑定。应用 PCK SHA-256：`74e2ad68cc7d231e33ad88bd18fcb838f51fec75de1c6e8950510e3892e16ac0`。

1. `./tools/run_checks.sh`：106 通过、0 失败。统一入口之后只有说明文字／检查夹具清理变更；最终编译门、配装专项和最终原生画面另记录，不将 106 项伪称为最后清理后的重新全量执行。
2. `python3 tools/release/verify_app.py --output render-evidence/app-preview21-2026-10-09/exported-app`：从临时目录使用同版本原生编辑器显式加载**实际导出 PCK**，27 项规则通过，包含回墨、坡道支撑、身体倍率和基础／续批伤害。外部夹具不是生产包的一部分；包内运行时来自 PCK。报告见 `exported-app/verification.json`，与相同收据／PCK 哈希绑定。
3. `exported-app/native/native-ui.json`：实际 PCK 原生 Metal 的首页、配装、1280×720／960×540 界面、实际 WASD／射击移动 5.17m、受控短计时结算和重开通过。伙伴／投放、实际鼠标狙／弓蓄力释放、60 护盾、三卡片悬停与完整正文另通过；见 `buddy-native`／`primary-native`。图像已查看；PCK 弓说明未截断。
4. 实际 `.app` 可执行文件在临时工作目录、无 `--path`／脚本覆盖独立启动：headless 4 帧及 Metal／Forward+ 45 帧均退出 0，Godot 脚本／场景错误和警告为 0；日志见 `app-startup`／`actual-app-metal.txt`。原生启动有 macOS IMK mach-port 提示，不是 Godot 脚本错误。随后用 `open -n` 打开新版供试玩。
5. `codesign --verify --deep --strict` 通过，`lipo -archs` 仅 arm64；本地 ad-hoc 签名，未公证。11 项收据隔离检查通过。旧版 PCK 哈希经移动前后核对未变，见 `delivery-bundle.json`。

两项旧包内规则夹具退出仍有 ObjectDB 引用警告：`check_tidewater_turf_points` 8 个、`check_gameplay_deployment` 20 个；规则断言通过，未忽略任何脚本错误。其他包内规则和最终原生／实际应用日志无 Godot 警告；不能把整个夹具集合描述为无警告退出。当前生产输入和实际应用未因此变更。

仅本地源码／验收提交与 `.app` 交付；没有压缩、推送或发布。后续文档／测试清理提交不改变构建来源，构建仍绑定上述生产提交。

## 边界

固定位置、冻结 AI／对局和显式输入步进只算受控原生验证。上一批独立自然 180 秒 5v5 属于其当时源码；本轮未新增自然整局。真人命中手感、八武器胜率和配装收益、长期温度／GPU 性能、联网均未证明。上一批最长 823.23ms 帧间隔仍未定位；本轮不宣称已经修复。
