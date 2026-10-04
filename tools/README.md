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
| `update_asset_integrity.py --write` | 有意资源修改验证后，记录新的本地资产基线 |
| `capture/`、`measure/` | 原生画面、回放和受控测量，按输出路径保留证据 |
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
