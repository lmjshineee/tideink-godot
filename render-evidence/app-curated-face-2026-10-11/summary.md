# 最新精选地图／脸发 App · 2026-10-11

用户请求：commit、编译最新 App、删除之前的 App。已完成本地源码提交、arm64 导出、实际包验证和旧 App 清理；未推送、发布或创建分发压缩包。

## 交付

- App：`build/TideInk.app`，只保留这一份应用。
- 生产提交：`6747da72db01e3873a7645225c9924ebd34cf3b4`。
- PCK SHA256：`f39422f873145c2f64679c0ea38aeace3c2d502dc08a5e62180a2f3536efa77e`。
- 架构：仅 arm64，严格代码签名通过。650 个生产输入、七个应用文件与 [`export-receipt.json`](export-receipt.json) 逐项一致；原有版本字串保持，以源码提交及收据区分构建。
- 内容：五图选择池，包括原创日落滑场／灯轨车站；全图涂地，移除中央区域模式；四种实际脸型雕形／眉眼与四种非触须发型，以及既有服装、配点、八武器、道具和玩家主动复活。

复用已验证的本地 arm64 模板，哈希 `daf43479c6c792c06d47e22e59bdbac39170d27b6bc5e739871d17601ba2fce7`，见 [`template.json`](template.json)。导出先放新目录；验证架构、签名和实际启动后替换主 App，旧主包保留到完整验收完成。

## 验证

1. 生产输入与上一轮最终验证一致，复用 **113 项源码规则／0 失败**，stdout 归档 [`source-checks/`](source-checks/)；导出前重新运行 Python 全套，**19 项通过**，见 [`python-before-export.txt`](python-before-export.txt)。仅修改包外验证工具，不修改游戏生产输入。
2. 实际导出 PCK 从临时工作目录运行 **34 项规则**，包括全图计分、两张新图的实际通行、人物／蒙皮、伤害、部署、导航和伙伴；全部通过，见 [`pack-verification.txt`](pack-verification.txt) 及 [`exported-pack/`](exported-pack/)。同版本原生编辑器显式加载真实 PCK；此方法不同于实际发行 App 的直接启动。
3. **八组原生输入／画面通过**：UI、伙伴／投放、主武器、配装、属性、人物持握／两队服装、新地图。实际鼠标／键盘覆盖 1280×720／100%、960×540／110%，人物 46 张，新图两种尺寸选择、W 移动／射击、总览／中场／玩家视角。新图 [`curated-followup/`](curated-followup/)，人物 [`art-followup/`](art-followup/)，最终补验报告 [`remaining-verification.json`](remaining-verification.json)。已查看实际包的人物正面、新图玩家视角和车站中场图。
4. 实际 App 在工程外直接启动，不添加 `--path`／`--script`／`--main-pack`：headless 和 Metal 90 帧均退出 0。见 [`app-headless.txt`](app-headless.txt) 与 [`app-metal.txt`](app-metal.txt)。导出收据结束时与清理后再次核对一致。

环境：Apple M5、arm64、Godot 4.8.dev6、Forward+／Metal 4.0。受控输入及有限启动不代表自然整局、用户审美、新图平衡或长期帧时间／温度验收。

## 原生夹具修复与保留结果

首轮 34 项规则及前三组原生通过后，配装夹具在 1280×720 的首个 ROLL 点击未触达，未改变配装且属性仍为零；后续尺寸点击正常。旧夹具在按钮事件之间等待并使用系统光标 warp，窗口获取焦点时可能插入迟到的移动事件。

夹具补 `root.grab_focus()`，只发显式 GUI 移动，并连续发送按下／松开；增加实际悬停目标及点击状态记录，保留原按钮回调与完整 20 点属性断言。对同一 PCK 独立复验通过，第一条 trace 确认悬停 `ROLL · 随机配装`，20 点已分配；见 [`loadout-followup/`](loadout-followup/) 和 [`loadout-followup-fixture.json`](loadout-followup-fixture.json)。游戏与 App 字节不变，未重新导出。

已通过的 34 项规则及前三组原生不重复；随后完成剩余四组原生及实际 App 启动。原聚合失败／退出 1 保留，不称整条聚合成功。原聚合失败前没有输出结构化最终报告，其已删除临时夹具的精确哈希不可追回；保留 stdout／engine 日志与当时已提交的验证工具。补验的源／外部夹具哈希均单独登记，外部脚本归档 [`external-fixtures/`](external-fixtures/)。

四个实际 PCK 规则夹具有 ObjectDB 退出引用警告；实际 App headless 退出有两个 ObjectDB 引用。最终八组原生与 App Metal 无 Godot 错误／警告；macOS `IMKCFRunLoopWakeUpReliable` 行单独记录。见 [`pack-rule-warnings.json`](pack-rule-warnings.json) 和 [`final-diagnostics.json`](final-diagnostics.json)，不宣称所有无界面执行无警告。

## 旧 App 删除

先记录两份旧 App 的全部文件哈希，见 [`previous-apps.json`](previous-apps.json)。旧主 App 替换时临时移至 `TideInk-before-curated-6747da7.app`；在新包全部验证后，再次核对两份旧包与起始哈希一致并删除：

- `build/TideInk-before-curated-6747da7.app`（原 `build/TideInk.app`）。
- `build/TideInk-before-wardrobe-bb384b6.app`。

共删除 655,578,982 字节，当前 `build/` 仅有 `TideInk.app`；新 App 清理后仍匹配七文件收据。见 [`old-app-cleanup.json`](old-app-cleanup.json)。旧收据和验收记录保留为历史证据，应用二进制没有进入 Git。
