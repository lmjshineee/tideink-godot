# 地图、角色与墨迹显示

默认 Forward+ / Metal，`./run.sh --compatibility` 使用兼容渲染。窗口、帧率、精度和 UI 由 `src/ui/tidewater_settings.gd` 管理，默认 30 FPS / 75% 精度。

## 状态权威

`src/world/surface_ink.gd` 是 CPU 归属、有效格和计分的权威；`surface_ink_view.gd` 只消费显示脏格、创建墨迹网格／纹理。`src/ui/turf_minimap.gd` 读取同一归属及本地像素映射，不消费显示层脏格。材质、纹理和 HUD 不得参与计分。

`tidewater_map.gd` / `scenes/world/tidewater_map.tscn` 生成碰撞；`tidewater_scenery.gd` 加载本地视觉网格，避免重复建立碰撞。墨层与壁画保持独立深度偏移。

`src/actors/tidewater_character_visual.gd` 读取阵营、武器、形态和动作，并加载本地模型／骨骼／动作数据。身体、脸部、服装与头发的既有外观保持；实验在 `experiments/`，未经用户确认不得替换正式人物。

## 本地资源与验证

地图／导航／墨面／小地图、布景、角色／动作／材质、音频／UI 都由本项目 `assets/` 提供。旧 Web 生成器已移除；当前维护本地 Godot 资源，更改多份相关产物时先核对语义，再显式更新 `assets/integrity.json`。

UI 创建、布局与刷新在 `src/ui/tidewater_hud.gd`；动态绘制在 `tidewater_presentation.gd`；菜单在 `tidewater_frontend.gd`。结果样式复用，尺寸布局只随窗口／设置变化更新。

`render-evidence/.gdignore` 隔离截图导入；正式导出排除工具、验证记录、历史和人物实验。截图仍可通过文件工具查看。

显示验收记录渲染模式、窗口、UI 比例与实际输入。短时受控画面、自动对局和无界面规则各有证据边界，不能替代真人手感或长期温度。既往记录见 [history/](history/) 和 [render-evidence/](../render-evidence/)。
