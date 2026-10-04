# 第八批：正式能力图标与配装反馈 · 2026-10-03

既定 ITEM-02 的图标与反馈部分完成；仍为当前源码，公开应用保持 preview.15，本批未提交／导出／发布。人物与已有玩法数值保留。

## 改动

- 22 个独立矢量符号：9 道具／8 天赋／5 大招。原武器图标与能力图标共32个，由 [导出器](../tools/export_ui_icons.mjs) 和 [原创生成器](../tools/ui_ability_icons.mjs) 可重建；`--check` 只读比较文件内容。白色能力图标可随当前队色着色，缓存资源，旧ID回退问号。
- 配装卡片接入图标，道具名字和CD分两行；独立选择与完整悬停详情保留。大招细环上方显示专属图标与中文名字。
- 左下道具／天赋分行、无底板。图标细环反映持久CD，分别显示就绪／冷却／使用中／缺墨／动作锁；存量装置保留HP／库存／寿命等信息，详情过长按字符裁为省略号。墨翼显示剩余时间与升降按键，回溯锚空墨仍显示返回，超过18m提示超出范围。天赋沿用实际锁定／触发状态。
- `tidewater_items.hud_status()` 是只读显示快照，不花墨、不部署、不探测碰撞或改变计时；位置合法性仍由实际操作检查。暂停／死亡不画配装浮层，复活不会重置持久CD。

## 验证

先通过 [解析预检](creative23-parse.txt)，[最终完整回归](creative23-checks.txt) 102项通过、0失败，覆盖资源一致性／规则／菜单／阶段／多尺寸测试。`node tools/export_ui_icons.mjs --check` 确认32个生成物一致。

[最终 Metal](creative23-native.txt)、[最终兼容渲染](creative23-gl-native.txt) 通过。1280×720与960×540／UI110%两种尺寸，真实控件悬停与选择、所有道具／天赋按钮资源、22个48px与24px图标、真实E花40墨开启墨翼、飞行提示、实际1秒CD推进、死亡／复活仍保留17秒CD、已有锚在空墨时显示返回、21m时超范围提示均核验。连续读取20次快照不改变资源／CD／部署数。脚本 [capture_loadout_feedback.gd](../tools/capture_loadout_feedback.gd) 使用真实游戏模块；受控摆位／费用状态与自然对局分开，不把它当完整90秒回放。

截图：[所有图标](creative23-icons.png)、[小窗口卡片／详情](creative23-menu-item-small.png)、[就绪](creative23-ready.png)、[缺墨](creative23-low-ink.png)、[飞行中](creative23-active.png)、[冷却](creative23-cooldown.png)、[小窗口冷却](creative23-cooldown-small.png)、[空墨回溯](creative23-recall.png)、[死亡隐藏](creative23-death.png)。

## 修正与边界

- 原生检查发现小窗口道具圆环与天赋图标相叠，将道具行向上移动16px，复核两种渲染器。图标预览工具曾在设置忽略最小尺寸之前设置TextureRect大小，导致预览仍为128px；修正顺序后按48px／24px检查，生产直接绘制的图标没有该问题。
- 添加超范围提示时动态字典的distance类型推断失败，已改为显式float；[首次日志](creative23-checks-first.txt)保留99通过／3个解析依赖失败。修正后先过解析门，再重跑最终完整回归。
- 本批范围为图标与反馈，没有调整平衡或重跑自然90秒样本；此前自然对局证据见 [第七批](creative22-summary.md)。进一步特效与配装分组样本继续在计划中。
