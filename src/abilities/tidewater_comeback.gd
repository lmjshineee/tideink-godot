extends Node
# Coverage is the actual share of all paintable area, including unpainted ground.
const ENTER_GAP := 20.0
const EXIT_GAP := 10.0
const ENTER_HOLD := 8.0
const EXIT_HOLD := 5.0
var game: Node3D
var team := -1
var candidate := -1
var pending := 0.0
var recovery := 0.0
var age := 0.0
var events := 0
var coverage := Vector2.ZERO
func setup(owner_game: Node3D) -> void: game = owner_game
func tick(delta: float) -> void:
	if game.phase != "playing" or game.paused: return
	age += delta
	coverage = Vector2(game.ink.coverage(0),game.ink.coverage(1))*100
	var difference := coverage.x-coverage.y
	var behind := 1 if difference > 0 else 0
	if team >= 0:
		var deficit := difference if team == 1 else -difference
		recovery = recovery+delta if deficit <= EXIT_GAP else 0.0
		if recovery >= EXIT_HOLD:
			team = -1; candidate = -1; recovery = 0; pending = 0
		return
	if age < 12 or absf(difference) < ENTER_GAP:
		candidate = -1; pending = 0; return
	if candidate != behind: candidate = behind; pending = 0
	pending += delta
	if pending >= ENTER_HOLD:
		team = behind; candidate = -1; pending = 0; recovery = 0; events += 1
		if game.presentation != null: game.presentation.notify_ability(game.team_names[team]+" · 逆风支援：回墨 +20% / 涂地充能 +15%")
func active(actor: Node3D) -> bool:
	return team >= 0 and game.phase == "playing" and game.actor_team(actor) == team
func refill(actor: Node3D) -> float: return 1.2 if active(actor) else 1.0
func charge(actor: Node3D) -> float: return 1.15 if active(actor) else 1.0
func reset() -> void:
	team = -1; candidate = -1; pending = 0; recovery = 0; age = 0; coverage = Vector2.ZERO
