extends RefCounted

# Shared by source checks and measurement provenance; tests/tools are outside src/.
static func scripts(directory: String = "res://src") -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"):
			files.append(directory.path_join(file))
	for child in DirAccess.get_directories_at(directory):
		var path := directory.path_join(child)
		if not child.begins_with(".") and not FileAccess.file_exists(path.path_join(".gdignore")):
			files.append_array(scripts(path))
	files.sort()
	return files
