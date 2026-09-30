extends SceneTree

# Fast, state-free gate: every production script must parse and load.
#
# Without it, one broken shared script turns into dozens of misleading failures. When
# tidewater_play.gd stopped parsing, every scene check reported "Nonexistent function
# '_start_round'", then sat in a wait loop until its watchdog fired, so a ten-second
# mistake took ten minutes and looked like a hang rather than a parse error. This runs in
# well under a second, needs no scene, and names the file once.
#
# It loads scripts; it does not instantiate them, so nothing here can touch game state.
func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var broken: Array = []
	for file in DirAccess.get_files_at("res://"):
		if not file.ends_with(".gd"):
			continue
		# load() can return a non-null GDScript even after a parse/compile error.
		# reload() checks compilation, including preloaded script dependencies,
		# without instantiating the script or executing its game logic.
		var script := load("res://" + file) as GDScript
		if script == null or script.reload() != OK:
			broken.append(file)
	if not broken.is_empty():
		broken.sort()
		printerr("FAIL: these production scripts do not parse: ", ", ".join(broken))
		printerr("Fix them first: every check that loads them will otherwise fail with "
			+ "unrelated errors and burn its whole watchdog.")
		quit(1)
		return
	print("PASS: every production script parses and loads")
	quit()
