# 当前源码 arm64 App 编译与验收

2026-10-10，用户要求「编译app」，后续「继续」完成剩余原生验收。输出 `build/TideInk.app`，包含新 Tab 战术卡片、双方 AI 武器／天赋倾向加点及第七轮人物修正。没有递增版本、创建分发压缩包、推送或公开发布。

## 构建身份

- 生产提交：`25fa67ecbb86f588e4624fb402a0a2d6356482ad`。
- 生产输入：626 个，指纹 `3fa5973064f057644eae0612c11845eb7684beb723b5239ed3c798b6b2522cfb`。
- PCK：`62148277cfecaefc5a7659e2ecbea910a76bdee99ab167c0c47c024bcdef1dc0`。
- 引擎：`4.8.dev6.official.8898c2b3d`；arm64，Forward+／Metal／Apple M5。
- 项目 `0.3.0-preview.24`、bundle build `0.3.24` 保持；同一版本字串不能区分新旧包，以上源码提交／PCK 哈希才是本次身份。
- `./export_macos.sh` 退出 0，arm64 架构、plist 与严格 ad-hoc 签名检查通过。仅使用本地安装的模板生成 arm64 缓存，未下载。源收据和应用七文件收据保留于本目录，`audit.json` 再次核对实际 App 字节、626 个输入、440 个资产文件与 289 个 UID。

导出前冻结输入逐项匹配上一批最终 `./tools/run_checks.sh` 的 111 项通过／0 失败及四张源码原生图。规则夹具没有改动，生产输入没有漂移，因此复用该源码回归；本次新增验证针对实际导出包。32 项旧源码夹具的 ObjectDB 退出引用警告仍是既有边界。

## 实际 PCK 与应用

`verify_app.py` 在工程外临时目录显式加载本次 PCK，32 项规则全部通过，包含新 AI 加点、属性预算／锁定、CPU 区域计分、伤害／遮挡、道具与人物。基础 UI 和伙伴两组原生先通过；在旧主武器夹具的悬浮输入处停止。修正夹具后由 `verify_remaining_native_v3.py` 复用同一 PCK 的上述通过结果，仅续跑主武器、配装、属性、人物四组，退出 0。完整汇总为 `verification.json`，六组原生均通过；未把最初整条命令的失败写成成功。

四项包内规则仍有 ObjectDB 退出引用警告：涂地点数 8、扩展配装 20、个人涂地 14、团队导航 2 个实例。六组最终原生没有 Godot ERROR／WARNING，stdout 保留 macOS IMK 输入法 mach port 诊断。导入／导出／初次 smoke 日志保留既有 macOS CA 诊断 `ret != noErr`，按仓库原有精确白名单处理，没有修改或隐藏日志。

`verify_tactical_pck.py` 再从明确 PCK 运行真实 Tab 按下／松开，验证 1280×720／100%、960×540／110% 的 5v5／1v1 卡片、字体、图标、情报限制、缓存复用与布局；四张图均已查看。其外部夹具仅替换测试继承路径并去掉捕获分支的源码清单依赖，生产游戏资源完全来自 PCK。变换、原始／外部脚本哈希见 `tactical-fixture-transform.json`。

- [5v5 大窗口](tactical-native/tab-5v5-1280.png)、[小窗口](tactical-native/tab-5v5-960.png)
- [1v1 大窗口](tactical-native/tab-1v1-1280.png)、[小窗口](tactical-native/tab-1v1-960.png)

实际 App 可执行文件在工程外 headless 四帧及 Metal 90 帧启动均退出 0；没有 `--path`、`--script` 或 `--main-pack` 覆盖，无 Godot 错误或警告。见 `tactical-and-metal.json` 和 `remaining-native-3/app-startup.txt`。

## 失败、修复与审批记录

初次 `primary-native`：狙击伤害说明内容正确，但悬浮框不显示。只同步系统光标的第二次重验中狙和弓通过，双持仍失败；新增记录显示 `mouse_mode=2`，实际光标停在窗口中心。原因是旧夹具从冻结战斗直接 `show_preparation()`，没有释放此前主动开启的捕获模式；正常菜单进入不经过这一合成路径。工具现调用既有 `_set_pointer_lock(false)`，断言光标可见，并同步系统光标／注入事件及核对实际目标位置；最终三个悬浮均显示，位置误差小于 3 px，全部战斗鼠标检查仍通过。只改变验证工具，没有改变生产源码／本次 App。

修复过程中一次外部夹具因 `hover_point` 未显式声明 `Vector2` 解析失败，已补齐。原始夹具、解析失败夹具及两次悬浮失败的原始日志／图均保留，成功输出在新的 `remaining-native-3/`。第一次续跑完整修正时，自动审批因账户额度无法完成审核，动作未执行；用户后续要求继续，正常审批重试获准后完成验证。未绕过审批。

## 备份与验收边界

导出前及导出后首次核对，`build/TideInk-preview.24.app` 的七文件与旧收据逐项相同；旧来源为 `6ca5df5`、PCK `396841b2ea91069d392118921aa1bcbf51f0312039a29c83efc25331f85b738d`。中途暂停后继续，最终核对发现旧 App 备份及两个备份收据均不在原位；当前 build 只保留新 App 和新收据。没有执行删除备份的操作，也不能从现有证据判断缺失原因。差异见 `backup-inventory-difference.json`；`audit.json` 明确记录缺失，不声称旧备份现在仍存在。新 App 和生产输入核验通过。

人物专项从实际 PCK 生成四种轮廓的正／侧／背／跑动、四脸与各八武器共 40 张图，代表性正面／背面／跑动三图已查看。生成及加载通过，不表示衣服接缝、全部关节动态或人工审美通过。没有新增自然整局、真人手感／配点平衡、全图策略、帧时间或长期温度验收；此前旧 App 的 180 秒对局不属于新包证据。
