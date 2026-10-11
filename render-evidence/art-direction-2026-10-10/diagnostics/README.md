# 历史路线夹具失败的隔离诊断

完整回归的旧 viaduct 桥下测试失败，失败原文保留在上层 `bold-full-map-route-failure.log`。

`debug_underpass.gd`：新场景／满墨、单独执行桥下目标，固定 seed=21 的伞通过。
`debug_sequence.gd`：保留此前上桥和侧坡的连续顺序，固定 seed=21 并令 Bot 使用滚筒；失败复现。

连续案例中墨量 110 → 65.53 → 40.19；桥下第 123 步降到 23.28 并从 patrol 切换到 ink。补墨后重新巡逻，故未到达夹具目标。导航终点误差只有 0.58m，排除目标不可达；孤立场景可达，排除静态结构变化。

修复仅在 `tests/godot/check_map_routes26.gd`：每段恢复墨量并重置 ink_brain，固定滚筒覆盖已知失败；不改变生产 AI 的低墨优先级。最终重验见上层 `final-map-routes.log` 和 `final-full-checks.log`。

这些是归档调试／复现脚本，不属于生产路径或正式检查入口。
