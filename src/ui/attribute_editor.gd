extends Control

const Catalog := preload("res://src/core/attribute_catalog.gd")
var game: Node3D
var frontend: Control
var panel: Panel
var title: Label
var hint: Label
var budget_label: Label
var description: Label
var summary: Label
var close_button: Button
var roll_button: Button
var clear_button: Button
var row_labels: Dictionary = {}
var rank_labels: Dictionary = {}
var value_labels: Dictionary = {}
var minus_buttons: Dictionary = {}
var plus_buttons: Dictionary = {}

func setup(owner_game: Node3D, owner_frontend: Control) -> void:
	game = owner_game; frontend = owner_frontend
	visible = false; mouse_filter = MOUSE_FILTER_STOP; z_index = 90
	panel = Panel.new(); add_child(panel)
	panel.add_theme_stylebox_override("panel", game._ui_style(Color("151c28"), Color("6f8191"), 2, 18))
	title = frontend._label(panel, "潮汐之镜 / 属性加点", 26, true)
	hint = frontend._label(panel, "每级消耗 1 点 · 每项最多 8 级 · 收益递减 · 开战后固定，死亡保留", 14)
	budget_label = frontend._label(panel, "", 20, true)
	close_button = frontend._button(panel, "完成 / 返回", close)
	for ability in Catalog.ABILITIES:
		row_labels[ability] = frontend._label(panel, Catalog.LABELS[ability], 18, true)
		rank_labels[ability] = frontend._label(panel, "", 15)
		value_labels[ability] = frontend._label(panel, "", 16)
		minus_buttons[ability] = frontend._button(panel, "−", _adjust.bind(ability, -1))
		plus_buttons[ability] = frontend._button(panel, "+", _adjust.bind(ability, 1))
		for button in [minus_buttons[ability], plus_buttons[ability]]:
			button.mouse_entered.connect(_describe.bind(ability))
			button.focus_entered.connect(_describe.bind(ability))
	description = frontend._label(panel, Catalog.DESCRIPTIONS.health, 14)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary = frontend._label(panel, "", 14); summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roll_button = frontend._button(panel, "ROLL · 分配 20 点", _roll)
	clear_button = frontend._button(panel, "重置 · 返还点数", _clear)

func open() -> void:
	if game.phase != "setup" or not game.attributes.can_edit(): return
	visible = true; frontend._end_hover(); frontend.sync()
	plus_buttons.health.grab_focus()

func close() -> void:
	visible = false; frontend.sync(); frontend.attribute_button.grab_focus()

func _describe(ability: String) -> void:
	description.text = Catalog.LABELS[ability] + "：" + Catalog.DESCRIPTIONS[ability]

func _adjust(ability: String, delta: int) -> void:
	if game.attributes.adjust(ability, delta): frontend.sync()

func _roll() -> void:
	if game.attributes.roll_player(): frontend.sync()

func _clear() -> void:
	if game.attributes.select_player(Catalog.empty()): frontend.sync()

func _value(actor: Node3D, ability: String) -> String:
	var bonus: float = game.attributes.bonus(actor, ability)
	var base: Dictionary = game.get_node("Combat").weapon_data.player
	match ability:
		"health": return "%.1f HP" % game.actor_max_health(actor)
		"ink_capacity": return "%.1f 墨" % game.actor_ink_max(actor)
		"run_speed": return "%.2f m/s" % (float(base.runSpeed) * game.perks.movement(actor))
		"swim_speed": return "%.2f m/s" % (float(base.swimSpeed) * game.perks.movement(actor, true))
		"ink_recovery": return "%.1f 墨/s · 潜泳" % (float(base.inkRefillSwim) * game.perks.refill(actor))
	return "%s%.1f%%" % ["−" if ability in ["main_saver", "sub_cooldown"] else "+", bonus * 100]

func sync() -> void:
	if game.phase != "setup": visible = false
	if not visible: return
	size = frontend.size
	var u := clampf(minf(size.x / 1280.0, size.y / 720.0), .60, 1.4)
	panel.position = size * Vector2(.08, .035); panel.size = size * Vector2(.84, .93)
	var width := panel.size.x
	frontend._place(title, Vector2(28, 17) * u, Vector2(width - 206 * u, 38 * u), maxi(18, int(26 * u)))
	frontend._place(hint, Vector2(28, 61) * u, Vector2(width - 56 * u, 28 * u), maxi(11, int(14 * u)))
	frontend._place(close_button, Vector2(width - 166 * u, 20 * u), Vector2(138, 38) * u, maxi(11, int(16 * u)))
	var actor: Node3D = game.get_node("World/Walker")
	var value: Dictionary = game.attributes.loadout(actor)
	var left: int = Catalog.BUDGET - Catalog.spent(value)
	budget_label.text = "可用 %d / %d 点" % [left, Catalog.BUDGET]
	frontend._place(budget_label, Vector2(28, 97) * u, Vector2(width - 56 * u, 30 * u), maxi(15, int(20 * u)))
	for index in Catalog.ABILITIES.size():
		var ability: String = Catalog.ABILITIES[index]
		var y := (142 + 47 * index) * u
		frontend._place(row_labels[ability], Vector2(28 * u, y), Vector2(width * .22, 36 * u), maxi(12, int(18 * u)))
		rank_labels[ability].text = "Lv.%d / 8    %s" % [value[ability], "●".repeat(value[ability]) + "○".repeat(8 - value[ability])]
		frontend._place(rank_labels[ability], Vector2(width * .25, y), Vector2(width * .30, 36 * u), maxi(11, int(15 * u)))
		value_labels[ability].text = _value(actor, ability)
		frontend._place(value_labels[ability], Vector2(width * .56, y), Vector2(width * .25, 36 * u), maxi(11, int(16 * u)))
		frontend._place(minus_buttons[ability], Vector2(width - 130 * u, y), Vector2(42, 36) * u, maxi(16, int(22 * u)))
		frontend._place(plus_buttons[ability], Vector2(width - 77 * u, y), Vector2(42, 36) * u, maxi(16, int(22 * u)))
		minus_buttons[ability].disabled = not game.attributes.can_edit() or value[ability] <= 0
		plus_buttons[ability].disabled = not game.attributes.can_edit() or value[ability] >= Catalog.MAX_RANK or left == 0
	frontend._place(description, Vector2(28, 526) * u, Vector2(width - 56 * u, 52 * u), maxi(11, int(14 * u)))
	summary.text = "已用 %d 点 · 重置免费 · 外观独立选择" % Catalog.spent(value)
	frontend._place(summary, Vector2(28 * u, panel.size.y - 76 * u), Vector2(width - 446 * u, 58 * u), maxi(11, int(14 * u)))
	frontend._place(roll_button, Vector2(width - 411 * u, panel.size.y - 67 * u), Vector2(183, 42) * u, maxi(11, int(15 * u)))
	frontend._place(clear_button, Vector2(width - 213 * u, panel.size.y - 67 * u), Vector2(185, 42) * u, maxi(11, int(15 * u)))
	roll_button.disabled = not game.attributes.can_edit(); clear_button.disabled = roll_button.disabled
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, .82))
