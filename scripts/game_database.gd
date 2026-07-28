extends Node

const REPORT_PATH := "res://data/generated/import_report.json"
const ATAC_CATALOG_PATH := "res://data/catalogs/atacs.json"
const CHARACTER_CATALOG_PATH := "res://data/catalogs/characters.json"

var _atacs: Array = []
var _characters: Array = []
var _report: Dictionary = {}


func _ready() -> void:
	_atacs = _load_json_array(ATAC_CATALOG_PATH)
	_characters = _load_json_array(CHARACTER_CATALOG_PATH)
	_report = _load_json_dict(REPORT_PATH)


func get_import_report() -> Dictionary:
	return _report.duplicate(true)


func get_atacs() -> Array:
	return _atacs.duplicate(true)


func get_characters() -> Array:
	return _characters.duplicate(true)


func atac_name(atac_id: int) -> String:
	for item in _atacs:
		if int(item.get("id", -1)) == atac_id:
			return str(item.get("name", "Unknown"))
	return "Unknown ATAC %02X" % atac_id


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Array else []


func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
