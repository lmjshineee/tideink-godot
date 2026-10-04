extends SceneTree
const Inventory := preload("res://tools/lib/asset_inventory.gd")

func _initialize() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Inventory.MANIFEST))
	if not data is Dictionary or data.get("schema_version") != 1 or not data.get("files") is Dictionary:
		_fail("missing or invalid assets/integrity.json")
		return
	var expected: Dictionary = data.files
	if expected.is_empty():
		_fail("asset integrity inventory must not be empty")
		return
	var actual := Inventory.files()
	var names: Array[String] = []
	for path in actual:
		names.append(path.trim_prefix("res://"))
	for name in expected:
		if not names.has(name):
			_fail("missing asset: " + String(name))
			return
	for name in names:
		if not expected.has(name):
			_fail("unrecorded asset: " + name)
			return
		var info: Variant = expected[name]
		var path := "res://" + name
		if not info is Dictionary or FileAccess.get_sha256(path) != info.get("sha256", ""):
			_fail("asset hash mismatch: " + name)
			return
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() != int(info.get("bytes", -1)):
			_fail("asset size mismatch: " + name)
			return
	print("PASS: %d local asset hashes, sizes and complete inventory; no web sources required" % names.size())
	quit()

func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	quit(1)
