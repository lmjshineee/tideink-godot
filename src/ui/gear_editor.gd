extends Control

const Catalog := preload("res://src/core/gear_catalog.gd")
var game: Node3D
var frontend: Control
var panel: Panel
var title: Label
var hint: Label
var selection: Label
var description: Label
var summary: Label
var close_button: Button
var roll_button: Button
var clear_button: Button
var piece_labels: Dictionary = {}
var slot_buttons: Dictionary = {}
var ability_buttons: Dictionary = {}
var selected_piece := "head"
var selected_index := 0

func setup(owner_game: Node3D, owner_frontend: Control) -> void:
	game = owner_game; frontend = owner_frontend
	visible = false; mouse_filter = MOUSE_FILTER_STOP; z_index = 90
	panel = Panel.new(); add_child(panel)
	panel.add_theme_stylebox_override("panel", game._ui_style(Color("171221"), Color("716b85"), 2, 18))
	title = frontend._label(panel, "GEAR / 装备能力", 26, true)
	hint = frontend._label(panel, "每件 1 主＋3 附加；主 10 点，附加 3 点，同类递减。双方槽位预算相同，开战后固定。", 14)
	close_button = frontend._button(panel, "完成 / 返回", close)
	for piece in Catalog.PIECES:
		piece_labels[piece] = frontend._label(panel, Catalog.PIECE_LABELS[piece], 20, true)
		for index in 4:
			var key := "%s:%d" % [piece, index]
			slot_buttons[key] = frontend._button(panel, "", _select_slot.bind(piece, index))
	selection = frontend._label(panel, "", 15, true)
	for ability in ["none"] + Catalog.ABILITIES:
		ability_buttons[ability] = frontend._button(panel, Catalog.LABELS[ability], _assign.bind(ability))
		ability_buttons[ability].mouse_entered.connect(_describe.bind(ability))
		ability_buttons[ability].focus_entered.connect(_describe.bind(ability))
	description = frontend._label(panel, "", 14); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary = frontend._label(panel, "", 14); summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roll_button = frontend._button(panel, "ROLL 全部装备", _roll)
	clear_button = frontend._button(panel, "清空能力", _clear)

func open() -> void:
	if game.phase != "setup" or not game.gear.can_edit(): return
	visible = true; frontend._end_hover(); frontend.sync()
	_select_slot(selected_piece, selected_index)

func close() -> void:
	visible = false; frontend.sync(); frontend.gear_button.grab_focus()

func _select_slot(piece: String, index: int) -> void:
	selected_piece = piece; selected_index = index
	var value: Dictionary = game.gear.loadout(game.get_node("World/Walker"))
	_describe(value[piece][index]); sync()

func _describe(ability: String) -> void:
	description.text = Catalog.LABELS[ability] + "：" + Catalog.DESCRIPTIONS[ability]

func _assign(ability: String) -> void:
	if game.gear.select_slot(selected_piece, selected_index, ability):
		_describe(ability); frontend.sync()

func _roll() -> void:
	if game.gear.roll_player():
		_select_slot(selected_piece, selected_index); frontend.sync()

func _clear() -> void:
	if game.gear.select_player(Catalog.empty()):
		_select_slot(selected_piece, selected_index); frontend.sync()

func sync() -> void:
	if game.phase != "setup": visible = false
	if not visible: return
	size = frontend.size
	var u := clampf(minf(size.x / 1280.0, size.y / 720.0), .60, 1.4)
	panel.position = size * Vector2(.04, .05); panel.size = size * Vector2(.92, .90)
	var width := panel.size.x
	frontend._place(title, Vector2(28, 18) * u, Vector2(width - 190 * u, 38 * u), maxi(18, int(26 * u)))
	frontend._place(hint, Vector2(28, 62) * u, Vector2(width - 56 * u, 42 * u), maxi(11, int(14 * u)))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frontend._place(close_button, Vector2(width - 156 * u, 20 * u), Vector2(128, 38) * u, maxi(11, int(16 * u)))
	var column := (width - 76 * u) / 3
	var value: Dictionary = game.gear.loadout(game.get_node("World/Walker"))
	for i in 3:
		var piece: String = Catalog.PIECES[i]
		var x := 28 * u + i * (column + 10 * u)
		frontend._place(piece_labels[piece], Vector2(x, 116 * u), Vector2(column, 28 * u), maxi(14, int(20 * u)))
		for index in 4:
			var button: Button = slot_buttons["%s:%d" % [piece, index]]
			button.text = "%s · %s" % ["主 10" if index == 0 else "附 %d · 3" % index, Catalog.LABELS[value[piece][index]]]
			button.disabled = not game.gear.can_edit()
			frontend._place(button, Vector2(x, (152 + 48 * index) * u), Vector2(column, 42 * u), maxi(11, int(16 * u)))
			frontend._selected(button, piece == selected_piece and index == selected_index)
	selection.text = "正在编辑：%s · %s能力；选择下方能力" % [Catalog.PIECE_LABELS[selected_piece], "主" if selected_index == 0 else "附加 %d" % selected_index]
	frontend._place(selection, Vector2(28, 346) * u, Vector2(width - 56 * u, 28 * u), maxi(11, int(15 * u)))
	var button_width := (width - 86 * u) / 4
	var abilities: Array = ["none"] + Catalog.ABILITIES
	for index in abilities.size():
		var ability: String = abilities[index]
		var button: Button = ability_buttons[ability]
		frontend._place(button, Vector2(28 * u + (index % 4) * (button_width + 10 * u), (382 + 44 * (index / 4)) * u), Vector2(button_width, 38 * u), maxi(11, int(15 * u)))
		button.disabled = not game.gear.can_edit()
		frontend._selected(button, value[selected_piece][selected_index] == ability)
	frontend._place(description, Vector2(28, 478) * u, Vector2(width - 56 * u, 60 * u), maxi(11, int(14 * u)))
	summary.text = "当前实际加成：" + game.gear.summary(game.get_node("World/Walker"))
	frontend._place(summary, Vector2(28 * u, panel.size.y - 88 * u), Vector2(width - 370 * u, 68 * u), maxi(11, int(14 * u)))
	frontend._place(roll_button, Vector2(width - 326 * u, panel.size.y - 68 * u), Vector2(170, 44) * u, maxi(11, int(16 * u)))
	frontend._place(clear_button, Vector2(width - 146 * u, panel.size.y - 68 * u), Vector2(118, 44) * u, maxi(11, int(16 * u)))
	roll_button.disabled = not game.gear.can_edit(); clear_button.disabled = roll_button.disabled
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, .82))
