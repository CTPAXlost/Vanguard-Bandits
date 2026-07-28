extends Node

var _script_paths: Array[String] = []


func _ready() -> void:
	if not _collect_scripts("res://"):
		push_error("ALL_GDSCRIPT_COMPILE_FAILED: script directory traversal failed")
		get_tree().quit(1)
		return
	_script_paths.sort()
	var failed: Array[String] = []
	for script_path: String in _script_paths:
		var loaded: Resource = ResourceLoader.load(
			script_path,
			"Script",
			ResourceLoader.CACHE_MODE_REPLACE
		)
		if loaded == null or not (loaded is Script):
			failed.append("%s [resource did not load as Script]" % script_path)
			continue
		var script: Script = loaded as Script
		if not script.can_instantiate():
			failed.append("%s [Script.can_instantiate=false]" % script_path)
	if not failed.is_empty():
		push_error("ALL_GDSCRIPT_COMPILE_FAILED: %s" % str(failed))
		get_tree().quit(1)
		return
	print("ALL_GDSCRIPT_COMPILE_OK count=%d" % _script_paths.size())
	get_tree().quit(0)


func _collect_scripts(directory_path: String) -> bool:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return false
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var full_path: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				if entry != ".godot" and not _collect_scripts(full_path):
					directory.list_dir_end()
					return false
			elif entry.get_extension().to_lower() == "gd":
				_script_paths.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()
	return true
