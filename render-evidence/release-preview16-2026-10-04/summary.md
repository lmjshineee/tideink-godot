# TideInk preview.16 · 发布验收

2026-10-04 开始，2026-10-05 继续。用户授权继续工作、上传 GitHub 并编译运行包，选择新建私有仓库，再委托命名。游戏名 TideInk（潮墨），目标仓库 `lmjshineee/tideink-godot`。

1. [统一入口](full-checks-final.txt)：90 项通过、0 失败，先生产编译门与 265 资产完整性，再规则／场景检查。
2. [构建隔离检查](release-isolation-final.txt)：10 项通过；覆盖源码／PCK／应用新增文件变更、标签／源码提交错误、版本／架构不一致与证据目录越界。
3. [原生源码检查](source-native-verified.txt)及[JSON](source-native-verified/native-ui.json)：Metal / Forward+、arm64、真实移动射击、8／9／8，1280×720 与 960×540 / 110% 的菜单／配装／受控结算／返回主菜单通过。计时人为缩短，只算受控界面检查。

实际 arm64 导出、PCK 和原生应用已验证；ZIP 和 GitHub 交付的最终校验结果记录在源码仓库的本报告及发布页面。

初始 `full-checks.txt` 因沙箱不允许创建改名后的应用数据目录而在编译门停止，正常权限复验通过。`source-native`／`source-native-final` 为检查工具的中间失败记录（结果 UI 下一帧刷新、返回后场景重载），修正工具等待／引用后 `source-native-verified` 才是完整通过记录。初始隔离检查只因 macOS 临时目录符号链接路径比较失败，规范路径后最终通过。未改变生产玩法来绕过这些检查。

上一批 180 秒原生 5v5 与结果面积／积分显示证据见 [原生对局](../native-match-2026-10-04/summary.md)；其源码哈希保持原样，不以新名称冒充重新完成整场对局。

真人手感、全地图完整对局、配装平衡、长期温度、桥梁漏染和联网未验收。应用临时签名、未 Apple 公证。

导出启动实测发现 `surface_ink.gd` 预加载被排除的 `src/legacy/paint_field.gd`，原应用编译失败退出。共享脚本及 UID 移到 `src/world`、同步两个引用，新增导出排除依赖阻断负例；[重新统一检查](full-checks-export-fix.txt) 90 项通过、[构建隔离](release-isolation-export-fix.txt) 11 项通过。模板 Info.plist 同步只声明 arm64，不执行其他架构代码。

## 新应用与导出 PCK

- [导出](export-verified.txt)、[收据](export-receipt.json)：源码 `c96df23eb7710753b199eba04c4c7dd7fce9b578`，引擎 `4.8.dev6.official.8898c2b3d`，仅 arm64；应用名称 TideInk，版本 0.3.0 / build 0.3.16，codesign deep/strict 验证通过。
- [包检查](exported-pack-verified.txt)、[明细](exported-pack-verified/verification.json)：8 项真实 PCK 规则通过（面积／积分、部署、装备选择池、墨弓、推进伞、墨翼、高低层、出手者涂地归属）。外部脚本由同版本原生编辑器加载此新 PCK，工作目录在临时目录。
- [原生 PCK](exported-pack-verified/native/native-ui.json)：Metal / Forward+，8／9／8，两种尺寸，真实移动射击、受控短计时结算和返回菜单通过；home/setup/results 图像已目视复核。
- [实际应用启动](exported-pack-verified/app-startup.txt)：应用自身二进制、临时工作目录、未覆盖 PCK／脚本，退出 0。另以 `open -n build/TideInk.app` 启动正式应用，CUA 观察到 TideInk 窗口和实际对局／复活界面，日志为 [Metal 原生启动](app-native-launch.engine.txt)。只读观察，没有接管当前玩家输入。
- 导出命令退出时出现 2 个 ObjectDB 实例泄漏警告，保留在原始导出 stdout；导出／应用启动引擎日志无脚本或场景错误。未以警告为长期内存验收。
- 中间 `exported-app` 尝试把 `--main-pack` 传给发行模板，明确被禁用而失败；无覆盖参数的外部脚本尝试超时，也不计入通过证据。最终验证分开 PCK 检查与正式应用启动，未改编译模板来放开路径覆盖。

私有仓库已核验：<https://github.com/lmjshineee/tideink-godot>。Release 入口：<https://github.com/lmjshineee/tideink-godot/releases/tag/v0.3.0-preview.16>。上传状态以 GitHub 页面和最终交付记录为准。

## ZIP 最终校验

[打包记录](package.txt)、[解压核验](archive-verification.json)：153,101,499 bytes（约 146 MiB），SHA256 `a84767308322f292a7497f8d21425f25a1e0ee6cdd391917e5e18c95ec596496`。解压后 7 个应用文件与收据逐个一致，137 个证据文件与 BUILD.json 一致，arm64 架构与 deep/strict 签名通过，实际二进制启动退出 0、最终启动无脚本／场景错误及警告。

第一次解压核验只因启动退出时出现相同 2 个 ObjectDB 警告而拒绝，并非字节或签名失败；最终复验将该精确的退出警告单独记录，其他警告仍拒绝，实际此次无警告。两次原始启动日志均保留，不据此宣称长期内存稳定。

GitHub 首次推送因浅克隆的边界提交缺少父对象而被拒绝；从本地已有 Git 对象库补齐历史后重试，原项目工作树未改动，本项目运行／测试／导出仍只依赖当前本地工程。构建源码提交和 ZIP 字节未改变。

## GitHub 交付完成

[远端交付校验](github-delivery.json)：私有仓库源码和 `v0.3.0-preview.16` 标签已推送，标签指向实际构建源码 `c96df23eb7710753b199eba04c4c7dd7fce9b578`；Release 为已发布的 prerelease、非草稿。ZIP 与 SHA256SUMS 两个资产均为 uploaded，远端大小及 SHA256 digest 均与本地文件一致。文档与完整验收记录在当前分支，BUILD.json 仍保留真实构建提交。
