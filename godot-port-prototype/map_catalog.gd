extends RefCounted
const Setup:=preload("res://match_setup.gd")
const IDS:=["tidewater","kelpline","coral_market","prism_gallery","viaduct","modular_harbor","terrace_garden"]
const NAMES:=["潮水码头","海藻工坊","珊瑚集市","回廊展馆","双层高架","模块港湾","阶梯花园"]
const BLURBS:=["港口 / 高台 / 双侧路线","船坞 / 栅格桥 / 高低差","交错摊位 / 3.4m 屋顶绕侧","地面 / 3m 回廊 / 6m 上层","6m 悬桥 / 桥下穿行 / 侧坡夹击","中央区 × 侧路 / 9 种模块组合","花园回廊 / 3m 中层 / 6m 上层"]
const VARIANTS:={"tidewater":3,"kelpline":3,"modular_harbor":9}
static func supports_random(id:String) -> bool:return VARIANTS.has(id)
static func variant_count(id:String) -> int:return int(VARIANTS.get(id,1))
static func roll() -> void:
	var rng:=RandomNumberGenerator.new();rng.randomize()
	Setup.map_seed=int(rng.randi() & 0x7fffffff)
	Setup.map_variant=Setup.map_seed%variant_count(Setup.map_id) if Setup.random_map else 0
static func ensure_setup() -> void:
	if not IDS.has(Setup.map_id):Setup.map_id="tidewater"
	if Setup.map_seed<0:roll()
	Setup.map_variant=clampi(Setup.map_variant,0,variant_count(Setup.map_id)-1)
static func reroll() -> void:
	var before:=Setup.map_variant;roll()
	if Setup.random_map and variant_count(Setup.map_id)>1 and before==Setup.map_variant:
		Setup.map_seed+=1;Setup.map_variant=Setup.map_seed%variant_count(Setup.map_id)
static func asset_id() -> String:
	return Setup.map_id+"_v%d" % Setup.map_variant if Setup.random_map and supports_random(Setup.map_id) and Setup.map_variant>0 else Setup.map_id
static func scenery_id() -> String:return Setup.map_id
static func title() -> String:return NAMES[IDS.find(Setup.map_id)]
static func layout_name() -> String:
	if Setup.map_id=="modular_harbor":
		var variant:=Setup.map_variant if Setup.random_map else 0
		return ["低掩体广场","三米双坡台","双翼高台"][variant/3]+" + "+["货箱侧路","二米观景台","回廊与矮墙"][variant%3]+" · 种子 %d" % Setup.map_seed
	return ["原版布置","货箱布置","低墙布置"][Setup.map_variant] if Setup.random_map and supports_random(Setup.map_id) else "标准布置"
