# 原生验证与维护工具

从项目根目录运行 `./tools/run_checks.sh`。顺序：资源导入 → 编译预检 → 本地资源完整性 → 所有规则／场景检查。任一门失败立即停止；退出成功且有独立 `PASS:` 行才算通过，日志在 `.godot/`。不需要 Node、浏览器或 Web 源码。

| 工具 | 用途 |
| --- | --- |
| `lib/runtime.sh` | 运行／验证／导出共用引擎发现与导入缓存 |
| `lib/source_inventory.gd` | 递归收集 `src/`，不让目录迁移导致漏检 |
| `lib/asset_inventory.gd` | 收集本地资源，排除 `.import`、`.uid` 与清单自身 |
| `../tests/godot/check_scripts_parse.gd` | `GDScript.reload()` 编译门；空目录失败 |
| `../tests/godot/check_asset_integrity.gd` | 完整资源清单、SHA256、大小与缺失／新增检测 |
| `../tests/python/test_parse_gate.py` | 故意坏脚本、坏依赖、两道门的失败隔离 |
| `../tests/python/test_asset_integrity.py` | 资源损坏／缺失／新增／空清单的失败验证 |
| `../tests/python/test_runtime.py` | 引擎指定、含空格路径、缓存／失败／重试 |
| `../tests/python/test_visual_config.py` | 两个隔离项目注入不同移动配置 |
| `../tests/python/test_release_metadata.py` | 旧版本、变更源码／PCK、错误源码提交与证据目录隔离负例 |
| `update_asset_integrity.py --write` | 有意资源修改验证后，记录新的本地资产基线 |
| `capture/`、`measure/` | 原生画面、回放和受控测量，按输出路径保留证据 |
| `measure/measure_native_match.gd` | 原生 180 秒 5v5、自然死亡／显式复活确认、计分核对、帧间隔与新证据目录 |
| `release/` | arm64 模板与本地打包 |

单项检查：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/inkwave-check.log --script res://tests/godot/check_tidewater_hud.gd
```

更改模型／纹理／音频／地图数据后，先运行相关语义检查与必要的原生预览，确认变化有意且有效，再执行：

```sh
python3 tools/update_asset_integrity.py --write
git diff -- assets/integrity.json
./tools/run_checks.sh
```

哈希只确认内容一致，不能证明碰撞、命中、模型、音效或玩法正确。禁止为了让检查通过而盲目改清单。

原生截图不用 `--headless`；旧工具可能覆盖历史证据，先检查／指定新输出路径。`capture/legacy/` 保存旧分页菜单脚本，仅用于相应历史提交；历史测量汇总可能因源码变更而拒绝复用，不能改旧数据哈希伪造新的结果。

JavaScript 转换器已删除。旧来源记录仅说明资源历史；未来维护本地资产，若需新的原生生成器，独立实现并补同步产物检查。

## 原生完整对局与帧时间基线

先通过统一检查，再单独运行，测量时避免同时运行其他测试。每次使用新的输出目录；已有 `match.json` 会被拒绝，旧证据不会覆盖。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method forward_plus --rendering-driver metal \
  --log-file /tmp/inkwave-native-match.engine.txt \
  --script res://tools/measure/measure_native_match.gd -- \
  --output=res://render-evidence/native-match-<新批次>
```

工具从 home 经 Enter 进入配装／开局，以键盘、鼠标事件驱动移动和战斗，使用原生机器人与自然 180 秒计时。自然死亡后，复活倒计时完成仍等待至少 0.8 秒，再用 Enter 明确确认基地落点；没有完整确认复活、实际移动、自然终场、十人结算或正确计分账本都会失败。整局结束时尚未复活的死亡单独记录，不要求结束后继续出场。

`match.json` 保存环境、实际装备、源码哈希、阶段、死亡／确认／落地时间、个人面积／积分、逐秒 CPU／静态内存采样及逐帧间隔；PNG 保存主菜单、配装、对局、复活选择、结果和回到主菜单，结算另拍 960×540／110% UI。帧间隔包含 30 FPS 限制、截图与系统调度影响，前五秒预热排除；它不是 GPU 执行时间。桌面失焦导致的暂停只在回放工具里恢复，并逐次记录，正式游戏的失焦暂停逻辑保持原样。

此工具要求原生 arm64 显示，会拒绝 headless。一局自动输入只建立受控原生基线，不能证明真人手感、配装平衡、长期温度、联网或新导出包已验收。

## arm64 导出与打包

先提交生产源码，再运行 `./export_macos.sh`。它读取项目名称／版本，输出 `build/TideInk.app`，捕获真实源码提交，检查架构、签名、启动日志后生成 `build/export-receipt.json`。

```sh
python3 tests/python/test_release_metadata.py
./export_macos.sh
python3 tools/release/package_macos.py --version v0.3.0-preview.16 \
  --evidence render-evidence/native-match-2026-10-04 \
  --evidence render-evidence/release-preview16-2026-10-04
```

打包工具会核对生产输入及所有应用文件与收据一致；拒绝任意改变的源码、PCK、版本或伪造的 `--source-commit`。随包 `BUILD.json` 记录引擎、源码提交、输入／应用／证据文件哈希，ZIP 附 SHA256SUMS。原生画面与解压后的实际启动另行验证；临时签名不表示 Apple 公证。
