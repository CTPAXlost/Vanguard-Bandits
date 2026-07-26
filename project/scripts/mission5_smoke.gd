extends Node

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	CampaignState.reset_campaign()
	CampaignState.prepare_mission_for_test(5, "defend_castle")
	await get_tree().process_frame
	var packed_scene: PackedScene = load("res://scenes/BattlePrototype.tscn")
	var battle: Node = packed_scene.instantiate()
	add_child(battle)
	for _frame: int in range(20):
		await get_tree().process_frame
	var mission_number_value: int = int(battle.get("mission_number"))
	var player_party_value: Array = battle.get("player_party") as Array
	var found_sadira: bool = false
	var found_franco: bool = false
	var found_halak: bool = false
	var found_faulkner: bool = false
	var equal_scale_ok: bool = true
	var units_value: Array = battle.get("units") as Array
	for unit_value: Variant in units_value:
		var unit: Node3D = unit_value as Node3D
		if unit == null:
			continue
		var label: String = str(unit.get_meta("label", ""))
		found_sadira = found_sadira or label.begins_with("Sadira")
		found_franco = found_franco or label.begins_with("Franco")
		found_halak = found_halak or label.begins_with("Halak")
		found_faulkner = found_faulkner or label.begins_with("Faulkner")
		var visual: Node3D = unit.get_node_or_null("ATACVisual") as Node3D
		if visual != null and bool(visual.get_meta("real_skeleton", false)):
			var scale_y: float = visual.scale.y
			if scale_y < 0.55 or scale_y > 1.15:
				equal_scale_ok = false
	if mission_number_value != 5 or player_party_value.size() < 7:
		push_error("MISSION5_SMOKE_FAILED: mission or player party is incomplete")
		get_tree().quit(1)
		return
	if not (found_sadira and found_franco and found_halak and found_faulkner and equal_scale_ok):
		push_error("MISSION5_SMOKE_FAILED: requested forces or normalized ATAC scale missing")
		get_tree().quit(1)
		return
	print("MISSION5_DEFENSE_SMOKE_OK")
	print("MISSION5_NEUTRAL_GROUP_SMOKE_OK")
	print("NORMALIZED_ATAC_SCALE_SMOKE_OK")
	get_tree().quit()
