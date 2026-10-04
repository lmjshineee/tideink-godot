# TideInk preview.16 · 发布验收

2026-10-04。用户授权继续工作、上传 GitHub 并编译运行包，选择新建私有仓库，再委托命名。游戏名 TideInk（潮墨），目标仓库 `lmjshineee/tideink-godot`。

1. [统一入口](full-checks-final.txt)：90 项通过、0 失败，先生产编译门与 265 资产完整性，再规则／场景检查。
2. [构建隔离检查](release-isolation-final.txt)：10 项通过；覆盖源码／PCK／应用新增文件变更、标签／源码提交错误、版本／架构不一致与证据目录越界。
3. [原生源码检查](source-native-verified.txt)及[JSON](source-native-verified/native-ui.json)：Metal / Forward+、arm64、真实移动射击、8／9／8，1280×720 与 960×540 / 110% 的菜单／配装／受控结算／返回主菜单通过。计时人为缩短，只算受控界面检查。

实际 arm64 导出、导出 PCK、原生应用与 ZIP 解压运行及 GitHub 上传尚在执行；仅在这些检查完成后上传。

初始 `full-checks.txt` 因沙箱不允许创建改名后的应用数据目录而在编译门停止，正常权限复验通过。`source-native`／`source-native-final` 为检查工具的中间失败记录（结果 UI 下一帧刷新、返回后场景重载），修正工具等待／引用后 `source-native-verified` 才是完整通过记录。初始隔离检查只因 macOS 临时目录符号链接路径比较失败，规范路径后最终通过。未改变生产玩法来绕过这些检查。

上一批 180 秒原生 5v5 与结果面积／积分显示证据见 [原生对局](../native-match-2026-10-04/summary.md)；其源码哈希保持原样，不以新名称冒充重新完成整场对局。

真人手感、全地图完整对局、配装平衡、长期温度、桥梁漏染和联网未验收。应用临时签名、未 Apple 公证。
