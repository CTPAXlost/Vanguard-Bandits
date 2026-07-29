extends Node


func _enter_tree() -> void:
	CampaignState.reset_campaign()
	CampaignState.current_mission = 1
	CampaignState.test_forced_branch = ""
	CampaignState.save_game()


func _ready() -> void:
	var battle: Node = get_node_or_null("BattlePrototype")
	if battle == null:
		push_error("MOVEMENT_INPUT_SMOKE_FAILED: pre-instanced battle child is missing")
		get_tree().quit(1)
		return

	# The smoke test must use the real scene boot path. It deliberately has no
	# manual setup fallback: missing units are a blocking runtime failure.
	await _wait_for_units(battle, 600)

	var player: Node3D = null
	var reachable: Dictionary = {}
	for _frame: int in range(600):
		await get_tree().process_frame
		player = _find_player_unit(battle)
		var reachable_value: Variant = battle.get("reachable_cells")
		if reachable_value is Dictionary:
			reachable = reachable_value as Dictionary
		if player != null and not reachable.is_empty():
			break

	if player == null:
		_fail(battle, "player unit is missing after normal scene initialisation")
		return
	if reachable.is_empty():
		_fail(battle, "reachable cells are missing after battle initialisation")
		return

	var start_cell: Vector2i = player.get_meta("cell", Vector2i.ZERO)
	var destination: Vector2i = start_cell
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var battle_camera: Camera3D = battle.get("camera") as Camera3D
	if battle_camera == null:
		_fail(battle, "battle camera is missing")
		return

	for raw_cell: Variant in reachable.keys():
		var candidate: Vector2i = raw_cell
		if candidate == start_cell:
			continue
		var world_position: Vector3 = battle.call("_cell_to_world", candidate)
		if battle_camera.is_position_behind(world_position):
			continue
		var screen_position: Vector2 = battle_camera.unproject_position(world_position)
		if viewport_rect.has_point(screen_position):
			destination = candidate
			break

	if destination == start_cell:
		# Headless viewport projection can differ from the desktop renderer. The
		# production click path is still exercised below; use the first reachable
		# tile when none projects inside the synthetic viewport.
		for raw_cell: Variant in reachable.keys():
			var candidate: Vector2i = raw_cell
			if candidate != start_cell:
				destination = candidate
				break
	if destination == start_cell:
		_fail(battle, "no reachable destination cell")
		return

	var destination_world: Vector3 = battle.call("_cell_to_world", destination)
	var click_position: Vector2 = battle_camera.unproject_position(destination_world)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = click_position
	click.pressed = true
	battle.call("_unhandled_input", click)

	for _frame: int in range(900):
		await get_tree().process_frame
		if player.get_meta("cell", Vector2i.ZERO) == destination:
			player.set_meta("facing_chosen", false)
			battle.call("_choose_facing", Vector2i(1, 0))
			await get_tree().process_frame
			if not bool(player.get_meta("facing_chosen", false)) or player.get_meta("facing", Vector2i.ZERO) != Vector2i(1, 0):
				_fail(battle, "arrow-key facing did not persist east direction")
				return
			print("MOVEMENT_INPUT_SMOKE_OK facing=east")
			get_tree().quit()
			return

	_fail(battle, "movement did not reach %s from %s" % [str(destination), str(start_cell)])


func _wait_for_units(battle: Node, frames: int) -> void:
	for _frame: int in range(frames):
		await get_tree().process_frame
		if _find_player_unit(battle) != null:
			return


func _find_player_unit(battle: Node) -> Node3D:
	var direct_value: Variant = battle.get("player_unit")
	if direct_value is Node3D and is_instance_valid(direct_value):
		return direct_value as Node3D
	var unit_list_value: Variant = battle.get("units")
	if unit_list_value is Array:
		for value: Variant in unit_list_value as Array:
			if value is Node3D:
				var unit: Node3D = value as Node3D
				if is_instance_valid(unit) and bool(unit.get_meta("player", false)):
					return unit
	return null


func _fail(battle: Node, reason: String) -> void:
	var mission_value: Variant = battle.get("mission_number")
	var units_value: Variant = battle.get("units")
	var unit_count: int = units_value.size() if units_value is Array else -1
	push_error("MOVEMENT_INPUT_SMOKE_FAILED: %s; mission=%s units=%d children=%d" % [
		reason, str(mission_value), unit_count, battle.get_child_count()
	])
	get_tree().quit(1)
