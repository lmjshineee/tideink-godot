# 地图、角色与墨迹显示

默认 Forward+ / Metal，`run.sh --compatibility` 切换兼容渲染。窗口、帧率、精度和 UI 比例由 `src/ui/tidewater_settings.gd` 管理，默认 30 FPS / 75% 精度。逐批记录见 [显示历史](history/2026-10-03-rendering.md) / [render-evidence/](../render-evidence/)。

## 权威与显示边界

`src/world/surface_ink.gd` 管理 CPU 归属、有效格和计分。`src/world/surface_ink_view.gd` 消费显示脏格，按需创建墨迹网格/纹理。`src/ui/turf_minimap.gd` 读取归属与网页像素映射，不消费显示层脏格。材质与 HUD 不得改变计分。

`src/world/tidewater_map.gd` / `scenes/world/tidewater_map.tscn` 生成地图碰撞；`src/world/tidewater_scenery.gd` 加载视觉网格，不重复建立碰撞。墨层与壁画保持独立偏移，避免深度争夺。

`src/actors/tidewater_character_visual.gd` 读取阵营/武器/形态/动作并加载角色数据；外观不决定伤害/生命。人物实验保留在 `character-*`，正式场景保持当前人物。

## 资源与工具

地图/墨面/导航/小地图、布景、角色/动作/材料、音频和 UI 分别由 `tools/export_*.mjs` 生成。`--check` 只读核对来源/输出哈希；部分重烘焙需要 Playwright / Chrome，见 [工具导航](../tools/README.md)。

`render-evidence/.gdignore` 隔离截图与测量，仍可用文件工具/Markdown 查看。正式导出继续排除工具、历史截图、人物实验和构建目录。

UI 创建/布局/刷新在 `src/ui/tidewater_hud.gd`，动态绘制在 `src/ui/tidewater_presentation.gd`，菜单在 `src/ui/tidewater_frontend.gd`。结果样式创建一次，尺寸布局在窗口/UI 比例变化时更新。

显示验收分别记录渲染模式、窗口尺寸、UI 比例和实际输入。数帧画面、无界面规则、自然对局只能证明各自覆盖的行为，不能替代真人手感/长期温度。
