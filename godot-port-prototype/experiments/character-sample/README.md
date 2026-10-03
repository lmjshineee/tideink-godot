# 人物造型样板 A

**状态：已被用户否决，停止此造型路线。** 脸仍继承旧网格，触须曲面形成帽盖／薄片效果；技术检查通过不代表造型合格。此目录只保留失败实验用于对照，不得作为默认人物或接入实战。下一步先确认角色设计参考，再重建头脸和头发网格。

2026-10-01。独立的 Godot 3D 人物对照，不需要 Blender。双击本目录的 `预览人物.command`，或在 Godot 打开 `studio.tscn` 按 F6。

- 左边：当前实战角色。右边：Wave 候选样板。两者使用同一灯光和同一套动作。
- 拖动空白处旋转、滚轮缩放；按钮或 1/2/3 切换待机、跑步、射击；按钮切换全身/脸部、队色和复位。Esc 退出。
- 候选使用更短的肩颈比例、重新贴合头面的较窄眉眼、五束重新生成的宽触须、简化的皮肤/眼睛/头发材质和深色服装。
- 身体、装备、87 骨骼及动作仍来自项目 Web 原资产；这是可复现的程序化美术实验，不是全新人工雕刻人物，也不是最终美术验收。
- 原网页、生产人物 GLB、控制器和默认场景不变。候选尚未接入实战；坡面 IK、独立新动作和最终造型另行处理。

生成：`node godot-port-prototype/tools/exporters/export_character_sample.mjs`。源模型是 `assets/characters/kid_0.glb`，候选输出为本目录 `wave.glb`；`manifest.json` 记录源、生成器和输出哈希。该 GLB 保留骨架，可以以后导入 Blender继续手工编辑。

验证：生成器 `--check`，本目录 `check.gd`，原角色检查 `tools/check_tidewater_original_character.gd`；原生截图用 `studio.tscn -- --capture`。截图位于 `render-evidence/sample-*.png`，原生图形检查不代表完整对局或长期性能验收。
