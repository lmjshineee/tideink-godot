# 验证与资源工具

从仓库根目录运行 `./godot-port-prototype/tools/run_checks.sh`。顺序为导入 → 编译预检 → 导出器哈希 → 所有 `check_*.gd`，日志在 `.godot/`。退出成功且有独立 `PASS:` 行才算规则检查通过。

| 工具 | 用途 |
| --- | --- |
| `test_runtime.py` | 指定引擎、含空格路径、导入缓存/失败/重试 |
| `lib/runtime.sh` | 运行/验证/导出共用引擎发现与导入缓存 |
| `check_scripts_parse.gd` / `test_parse_gate.py` | 编译预检、故意坏脚本、失败立即停止 |
| `check_*.gd` | 地图/角色/武器/道具/对局/UI 回归 |
| `export_tidewater_{map,surfaces,visuals}.mjs` / `export_arenas.mjs` | 地图来源与额外布局 |
| `export_navigation.mjs` / `export_minimap.mjs` | 导航、小地图基图/墨格映射 |
| `export_characters.mjs` / `export_character_*.mjs` / `export_weapon_poses.mjs` | 角色、动作、材质、持握 |
| `export_weapon_config.mjs` / `export_ui_icons.mjs` / `export_menu_art.mjs` / `export_audio.mjs` | 参数与 UI/声音 |
| `capture_*.gd` / `measure_*.gd` | 各批画面、测量或回放；覆盖范围见脚本和报告 |
| `prepare_arm64_template.py` / `package_macos.py` | arm64 模板与本地包校验 |

目录分组见 [项目结构](../docs/STRUCTURE.md)：规则检查在 `tests/godot/`，隔离检查在 `tests/python/`，转换/截图/测量/发布在各 `tools/` 子目录。

单项执行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless   --log-file /tmp/inkwave-check.log --path godot-port-prototype   --script res://tests/godot/check_tidewater_hud.gd
```

`node godot-port-prototype/tools/exporters/<名称>.mjs --check` 只读核对；去掉 `--check` 会重建资源，部分工具需要 Playwright / Chrome。临时人物实验不自动加入正式回归。

原生截图不能用 `--headless`。历史截图工具可能覆盖既有证据，复测前指定新输出路径。`.gdignore` 不影响 FileAccess 读写测量数据。

`capture/legacy/` 保存依赖旧分页菜单的 `capture_menu12.gd`，用整理前提交复核；当前同页菜单从 `capture_unified13.gd` 及后续工具验证。源文件检查和新测量共用 `lib/source_inventory.gd`，递归收集 `src/`，避免目录搬迁后漏检。
