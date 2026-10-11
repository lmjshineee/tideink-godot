# 脸型雕形与头发贴合 · 2026-10-11

本批回应「脸型没怎么做，继续，高标准」和「还要注意头发」。四个派生角色的脸／发实际网格及材质已更新；地图、模式、服装和已有未提交工作保持。本记录不自动认定用户的审美验收通过。

## 实际修改

1. 四个下颌轮廓分别为短鹅蛋、宽颧／窄下巴、宽下颌／平下巴和较长椭圆。鼻梁、鼻翼、眼眶、颧骨及唇下转折进入 Skin 网格，法线由最终三角形重建并缝合重复点。灰模复查减弱下半脸的强凹陷和局部凸起。
2. 杏仁形眼睛贴合同一脸面，眉毛缩薄并重新定位。四个眼／眉骨骼及相应逆绑定矩阵同步调整；其余节点、87 骨骼层级、原动作和服装绑定保持。正常／闭眼蒙皮后的眼心漂移小于 0.1mm。
3. 发束改用连续传输截面、封闭发尾和实际曲面法线。唯一头发基面与发根沿雕好的完整头部网格拟合，缝合后脑 UV 接缝并闭合顶部极点。短发补顶部流向，波波头补完整顶部发缝，卷发沿头皮法线分布 183 束并延续到后脑，后束波浪添加实物发圈。原发帽／触须与皮肤假发际线保持移除，原眉毛及配饰保留。
4. 皮肤／头发减少过强高光，保留队色和现有脸颊特征。原 `kid_0..3.glb` 不改，不引入外部运行依赖，也不修改命中胶囊、属性、CPU 墨格或玩法权威。

本地工具为 `tools/assets/face_geometry.py`、`hairstyle_geometry.py` 和 `build_character_archetypes.py`；捕获工具为 `tools/capture/capture_face_sculpt.gd`。

## 最终检查

- `./tools/run_checks.sh`：**113 通过、0 失败**。聚合 [`final-full-checks.log`](final-full-checks.log)，113 个独立 stdout 保存在 [`final-v3-check-logs/`](final-v3-check-logs/)。
- `python3 -m unittest discover -s tests/python -v`：**19 项通过**，见 [`final-v3-python.log`](final-v3-python.log)。人物专项七项覆盖实际鼻／眼眶深度、归一化下颌差异、眨眼锚点与错误锚点负例、发束／基面朝向和反向三角形负例、后脑接缝，以及既有衣片／绑定契约。
- 资源完整性、坏脚本／坏依赖解析门、运行辅助及 owner 配置的四个独立 Python 程序在前一阶段通过；这四组夹具代码及相关门限代码未变。它们不是本次最终完整回归的重复运行。
- 最终 **26** 个无界面夹具有 ObjectDB 退出引用警告，不声称无界面整体无警告。最终三组原生 **0 Godot 错误／警告**；各 stdout 的 macOS 输入法 `IMKCFRunLoopWakeUpReliable` 行单独记录。完整结果见 [`final-verification.json`](final-verification.json)。

## 原生画面与输入

Apple M5、arm64、Godot 4.8.dev6、Forward+／Metal 4.0。

- [`final-portraits-v3/`](final-portraits-v3/)：60 张独立原生图及四张汇总图。四种角色固定相机／灯光的旧、新模型正面／三分之四／侧面、灰模、后脑、头顶，以及专注／蓄力／疲惫／闭眼；旧、新都使用当前材质。对照 [`comparison-front.png`](final-portraits-v3/comparison-front.png) 上排旧模型、下排新模型。
- [`final-motion-v3/`](final-motion-v3/)：46 张原生图，包含四角色正面／三分之四／背面／跑动、四张近景、32 张八武器持握和两队六张服装混搭。
- [`final-input-v3/`](final-input-v3/)：实际鼠标、Enter／Esc；1280×720／100% 和 960×540／110%，换角色后预览及开战加载、属性保持、真实主武器耗墨和开战锁定通过。五张画面与 `attributes.json` 保留。此工具冻结 AI 并显式控制场景，只算受控输入。

已查看最后一版同镜头四脸对照、正面／侧面总表、灰模、波波头顶部、卷发后脑、闭眼／蓄力、跑动和两队代表服装图。照片数量与规则通过不代表用户审美认可。

## 保存与输入绑定

- 最终 [`final-inputs.json`](final-inputs.json) 冻结 1,036 个生产／验证文件，完整检查后逐文件复核，文件集合和 SHA256 均未漂移。
- 近景／动作各 82 个关键输入哈希、真实输入 73 个生产脚本哈希匹配最终冻结文件；见 [`final-preservation.json`](final-preservation.json)。
- 起始指纹覆盖的 274 个既有 UID、所有生产 GDScript／地图和四个原始模型保持；派生模型颈部以下 Skin、全部服装的位置／法线／关节／权重逐项与本批起始模型一致。
- 在几何语义和最后原生近景通过后显式更新资产清单，仍为 286 个逻辑资产；本批有意变化仅四个派生 GLB，见 [`final-asset-review.json`](final-asset-review.json)。
- 头顶／灰模复查推动了最后的几何修订，重新生成、导入、冻结后重复完整回归和原生动作／输入，见 [`final-refinement.json`](final-refinement.json)。此前冻结文件、通过日志、失败过程及 [`summary-pre-crown.md`](summary-pre-crown.md) 保留为阶段记录；最后一版仅以上述 `final-*` 输入／结果为准。

本批在源码，现有 `build/TideInk.app` 尚未重打包；使用根目录 `./run.sh` 查看新脸发。未提交、导出、推送或发布。新头发使用更多几何，现有自动 LOD 保留；本批未新增自然整局、长期帧时间／温度或用户审美验收。
