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
	for _frame: int in range(30):
		await get_tree().process_frame
	var mission_number_value: int = int(battle.get("mission_number"))
	var player_party_value: Array = battle.get("player_party") as Array
	var found_sadira: bool = false
	var found_franco: bool = false
	var found_halak: bool = false
	var found_faulkner: bool = false
	var neutral_positions_ok: bool = true
	var equal_scale_ok: bool = true
	var units_value: Array = battle.get("units") as Array
	for unit_value: Variant in units_value:
		var unit: Node3D = unit_value as Node3D
		if unit == null:
			continue
		var label: String = str(unit.get_meta("label", ""))
		if label.begins_with("Sadira"):
			found_sadira = true
			neutral_positions_ok = neutral_positions_ok and unit.get_meta("cell") == Vector2i(8, 13)
		elif label.begins_with("Franco"):
			found_franco = true
			neutral_positions_ok = neutral_positions_ok and unit.get_meta("cell") == Vector2i(9, 12)
		elif label.begins_with("Halak"):
			found_halak = true
			neutral_positions_ok = neutral_positions_ok and unit.get_meta("cell") == Vector2i(9, 14)
		found_faulkner = found_faulkner or label.begins_with("Faulkner")
		var visual: Node3D = unit.get_node_or_null("ATACVisual") as Node3D
		if visual != null and bool(visual.get_meta("real_skeleton", false)):
			var scale_y: float = visual.scale.y
			if scale_y < 0.55 or scale_y > 1.15:
				equal_scale_ok = false
	if mission_number_value != 5 or player_party_value.size() < 7:
		_fail("mission or player party is incomplete")
		return
	if not (found_sadira and found_franco and found_halak and found_faulkner and equal_scale_ok and neutral_positions_ok):
		_fail(
			"requested forces, positions or normalized scale missing: sadira=%s franco=%s halak=%s faulkner=%s positions=%s scale=%s"
			% [str(found_sadira), str(found_franco), str(found_halak), str(found_faulkner), str(neutral_positions_ok), str(equal_scale_ok)]
		)
		return
	# Version 2.0.1 restored visible gate leaves, but they are swung fully outside
	# the corridor and contain no collision bodies. Verify the visual gate exists
	# instead of incorrectly requiring the whole gate root to be absent.
	for gate_name: String in ["DefenseCastleGateWest", "DefenseCastleGateEast"]:
		var gate_root: Node3D = battle.get_node_or_null(gate_name) as Node3D
		if gate_root == null:
			_fail("open visual gate is missing: %s" % gate_name)
			return
		for child_name: String in ["OpenLeafNorth", "OpenLeafSouth", "GateLintel"]:
			if gate_root.get_node_or_null(child_name) == null:
				_fail("open gate part is missing: %s/%s" % [gate_name, child_name])
				return
		if not gate_root.find_children("*", "CollisionObject3D", true, false).is_empty():
			_fail("open gate contains a collision object: %s" % gate_name)
			return
	var blocked_value: Dictionary = battle.get("blocked_cells") as Dictionary
	for gate_x: int in [10, 22]:
		for corridor_x: int in range(gate_x - 1, gate_x + 2):
			for gate_z: int in [6, 7, 8, 9, 10, 11]:
				if blocked_value.has(Vector2i(corridor_x, gate_z)):
					_fail("castle passage contains a blocked corridor cell")
					return
	print("MISSION5_DEFENSE_SMOKE_OK")
	print("MISSION5_NEUTRAL_GROUP_SMOKE_OK")
	print("MISSION5_NEUTRAL_POSITION_SMOKE_OK")
	print("MISSION5_GATE_SMOKE_OK")
	print("MISSION5_OPEN_GATE_VISUAL_SMOKE_OK")
	print("NORMALIZED_ATAC_SCALE_SMOKE_OK")

	# Force the real timed trigger. Clear all intro/resolution gates explicitly,
	# then verify the predicate before beginning the turn. This catches both a
	# broken trigger and a broken wave composition instead of reporting 0/0 only.
	battle.set("mission_five_intro_pending", false)
	battle.set("mission_five_resolution_started", false)
	battle.set("zakov_reinforcements_arrived", false)
	battle.set("zakov_reinforcements_spawning", false)
	battle.set("round_number", 4)
	if not bool(battle.call("_should_spawn_zakov_reinforcements")):
		_fail("round-four Zakov reinforcement trigger did not activate")
		return
	print("MISSION5_ZAKOV_TRIGGER_SMOKE_OK")
	battle.call("_begin_player_turn")
	for _frame: int in range(120):
		await get_tree().process_frame
	if not bool(battle.get("zakov_reinforcements_arrived")):
		_fail("Zakov trigger activated but the reinforcement coroutine never started")
		return
	var found_zakov: bool = false
	var captain_count: int = 0
	var reinforcement_barbatos_count: int = 0
	var sharking_armor_ok: bool = false
	units_value = battle.get("units") as Array
	for unit_value: Variant in units_value:
		var unit: Node3D = unit_value as Node3D
		if unit == null or not is_instance_valid(unit):
			continue
		var reinforcement_role: String = str(unit.get_meta("reinforcement_role", ""))
		if reinforcement_role == "zakov_commander":
			found_zakov = true
			var stats: Dictionary = unit.get_meta("stats") as Dictionary
			sharking_armor_ok = (
				str(unit.get_meta("model_slug", "")) == "sharking"
				and int(stats.get("armor", 0)) == 250
				and int(stats.get("max_armor", 0)) == 250
				and int(stats.get("move_range", 0)) == 10
			)
		elif reinforcement_role == "zakov_captain":
			captain_count += 1
		elif reinforcement_role == "zakov_barbatos":
			reinforcement_barbatos_count += 1
	var tracked_captains: Array = battle.get("zakov_captains") as Array
	var tracked_barbatos: Array = battle.get("zakov_barbatos") as Array
	if not found_zakov or captain_count != 2 or reinforcement_barbatos_count != 3 or tracked_captains.size() != 2 or tracked_barbatos.size() != 3:
		_fail(
			"Zakov reinforcement composition is incomplete: commander=%s captains=%d/%d barbatos=%d/%d"
			% [str(found_zakov), captain_count, tracked_captains.size(), reinforcement_barbatos_count, tracked_barbatos.size()]
		)
		return
	if not sharking_armor_ok:
		_fail("Sharking armor or movement profile is invalid")
		return
	print("MISSION5_ZAKOV_WAVE_SMOKE_OK")
	print("SHARKING_ARMOR_SMOKE_OK")
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.queue_free()
	for _frame: int in range(10):
		await get_tree().process_frame
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("MISSION5_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
