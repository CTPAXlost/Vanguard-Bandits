extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for branch: String in ["stay_and_fight", "seek_southern_aid"]:
		var ok: bool = await _verify_branch_can_move(branch)
		if not ok:
			push_error("MISSION3_MOVEMENT_SMOKE_FAILED: %s" % branch)
			get_tree().quit(1)
			return
	print("MISSION3_MOVEMENT_UNLOCK_OK")
	print("MISSION3_BRANCH_3A_MOVEMENT_OK")
	print("MISSION3_BRANCH_3B_MOVEMENT_OK")
	print("MISSION3_SMOKE_OK")
	get_tree().quit()


func _verify_branch_can_move(branch: String) -> bool:
	CampaignState.reset_campaign()
	CampaignState.prepare_mission_for_test(3, branch)
	await get_tree().process_frame
	var packed_scene: PackedScene = load("res://scenes/BattlePrototype.tscn")
	var battle: Node = packed_scene.instantiate()
	add_child(battle)

	# All story lines are advanced automatically in the headless test. The actual
	# branch setup, scripted duel, death/escape sequence and first player turn still
	# run normally, so this catches the old lock that left Mission 3A/3B immobile.
	var ready_for_input: bool = false
	for _frame: int in range(1800):
		await get_tree().process_frame
		var dialogue_panel: Control = battle.get_node_or_null("HUD/DialoguePanel") as Control
		if dialogue_panel != null and dialogue_panel.visible:
			battle.emit_signal("dialogue_advanced")
		var player: Node3D = battle.get("player_unit") as Node3D
		var reachable: Dictionary = battle.get("reachable_cells") as Dictionary
		if (
			player != null
			and not bool(battle.get("mission_three_intro_pending"))
			and bool(battle.get("branch_combat_active"))
			and not bool(battle.get("action_in_progress"))
			and not reachable.is_empty()
		):
			ready_for_input = true
			break
	if not ready_for_input:
		battle.queue_free()
		await get_tree().process_frame
		return false

	var player: Node3D = battle.get("player_unit") as Node3D
	var start_cell: Vector2i = player.get_meta("cell", Vector2i.ZERO)
	var destination: Vector2i = start_cell
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var reachable: Dictionary = battle.get("reachable_cells") as Dictionary
	var battle_camera: Camera3D = battle.get("camera") as Camera3D
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
		battle.queue_free()
		await get_tree().process_frame
		return false

	var destination_world: Vector3 = battle.call("_cell_to_world", destination)
	var click_position: Vector2 = battle_camera.unproject_position(destination_world)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = click_position
	click.pressed = true
	battle.call("_unhandled_input", click)
	var moved: bool = false
	for _frame: int in range(360):
		await get_tree().process_frame
		if player.get_meta("cell", Vector2i.ZERO) == destination:
			moved = true
			break
	battle.queue_free()
	await get_tree().process_frame
	return moved
