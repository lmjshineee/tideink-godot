extends RefCounted

# Authored skinned garments provide the silhouettes; no block accessories.
# Combat capsules and all attributes remain owned by actor/match rules.
const IDS := ["reef_runner", "fin_drifter", "dock_worker", "spark_writer"]
const LABELS := ["礁跑 · 侧扫碎发", "鳍影 · 层次波波", "港工 · 云朵卷发", "电涂 · 后束波浪"]
const SCALE := [.94, 1.06, .97, 1.01]
const SKIN_TINT := [Color("fff7ef"), Color("ead7cc"), Color("d1b498"), Color("ebc5ba")]

static func path(index: int) -> String:
	return "res://assets/characters/archetypes/%s.glb" % IDS[posmod(index, IDS.size())]

static func dress(visual: Node3D) -> void:
	var index := posmod(visual.style_index, IDS.size())
	visual.original_rig.scale = Vector3.ONE * SCALE[index]
	visual.set_meta("archetype", IDS[index])
	visual.set_meta("garments", "authored skinned cloth; repainted elbow/knee weights")
