extends RefCounted

# Cohesive base / print / panel / collar-and-cuff palettes.
const DESIGNS := [
	{"name":"深海波纹","colors":["26374b","f0e4cf","335b68","f9b754"]},
	{"name":"薄荷拼色","colors":["a6d4c1","29434a","edf2dd","29434a"]},
	{"name":"熔橙竞速","colors":["d86b47","ffe7c8","28364a","ffe7c8"]},
	{"name":"紫调棋盘","colors":["aaa2ce","30344b","ece7df","30344b"]},
	{"name":"奶油涂鸦","colors":["e6d7b7","354957","df866c","eee5d3"]},
	{"name":"午夜电流","colors":["282d36","68d6bd","373c48","dce4d4"]},
	{"name":"珊瑚日落","colors":["d9a2a8","664658","eddbcb","664658"]},
	{"name":"冰蓝轨道","colors":["9abdd7","294b65","eef0df","294b65"]}
]

static func configure(material: ShaderMaterial,index: int) -> void:
	var design: Dictionary=DESIGNS[posmod(index,DESIGNS.size())]
	material.set_shader_parameter("tee_design",posmod(index,DESIGNS.size()))
	for i in 4:
		material.set_shader_parameter(["shirt_color","graphic_color","panel_color","trim_color"][i],Color(design.colors[i]))
