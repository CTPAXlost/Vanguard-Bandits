extends Node

const BATTLE_SCENE := preload("res://scenes/BattlePrototype.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	CampaignState.reset_campaign()
	CampaignState.prepare_mission_for_test(1)
	await get_tree().process_frame
	var battle: Node = BATTLE_SCENE.instantiate()
	add_child(battle)

	for _frame: int in range(600):
		await get_tree().process_frame
		if bool(battle.get("battle_initialized")):
			break
	if not bool(battle.get("battle_initialized")):
		_fail(battle, "production battle initialisation did not complete")
		return

	var player: Node3D = battle.get("player_unit") as Node3D
	if player == null or not is_instance_valid(player):
		_fail(battle, "player unit is missing")
		return
	var reachable_value: Variant = battle.get("reachable_cells")
	if not (reachable_value is Dictionary) or (reachable_value as Dictionary).is_empty():
		_fail(battle, "reachable cells are missing after normal initialisation")
		return
	var reachable: Dictionary = reachable_value as Dictionary
	var start_cell: Vector2i = player.get_meta("cell", Vector2i.ZERO)
	var destination: Vector2i = start_cell
	for raw_cell: Variant in reachable.keys():
		var candidate: Vector2i = raw_cell
		if candidate != start_cell:
			destination = candidate
			break
	if destination == start_cell:
		_fail(battle, "no reachable destination cell")
		return

	var path_value: Variant = battle.call("_find_path", start_cell, destination, player)
	if not (path_value is Array) or (path_value as Array).is_empty():
		_fail(battle, "production pathfinder returned no path")
		return
	await battle.call("_animate_path", player, path_value as Array, 0.001)
	if player.get_meta("cell", Vector2i.ZERO) != destination:
		_fail(battle, "movement did not reach destination")
		return
	print("MOVEMENT_INPUT_SMOKE_OK")
	get_tree().quit()

func _fail(battle: Node, reason: String) -> void:
	var mission_value: Variant = battle.get("mission_number")
	var units_value: Variant = battle.get("units")
	var unit_count: int = units_value.size() if units_value is Array else -1
	push_error("MOVEMENT_INPUT_SMOKE_FAILED: %s; mission=%s units=%d children=%d" % [
		reason, str(mission_value), unit_count, battle.get_child_count()
	])
	get_tree().quit(1)
