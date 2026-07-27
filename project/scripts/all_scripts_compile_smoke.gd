extends Node

var _script_paths: Array[String] = []


func _ready() -> void:
	_collect_scripts("res://")
	_script_paths.sort()
	var failed: Array[String] = []
	for script_path: String in _script_paths:
		var loaded: Resource = load(script_path)
		if loaded == null:
			failed.append(script_path)
	if not failed.is_empty():
		push_error("ALL_GDSCRIPT_COMPILE_FAILED: %s" % str(failed))
		get_tree().quit(1)
		return
	print("ALL_GDSCRIPT_COMPILE_OK count=%d" % _script_paths.size())
	get_tree().quit(0)


func _collect_scripts(directory_path: String) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		push_error("ALL_GDSCRIPT_COMPILE_FAILED: cannot open %s" % directory_path)
		get_tree().quit(1)
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var full_path: String = directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_scripts(full_path)
		elif entry.ends_with(".gd"):
			_script_paths.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()
