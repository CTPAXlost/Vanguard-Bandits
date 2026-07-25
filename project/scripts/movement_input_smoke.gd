extends Node


func _ready() -> void:
	CampaignState.reset_campaign()
	CampaignState.current_mission = 1
	CampaignState.save_game()

	await get_tree().process_frame
	var packed_scene: PackedScene = load("res://scenes/BattlePrototype.tscn")
	var battle: Node = packed_scene.instantiate()
	add_child(battle)

	# Даём сцене создать карту, игрока и подсветку доступных клеток.
	for _frame: int in range(6):
		await get_tree().process_frame

	var player: Node3D = battle.get("player_unit") as Node3D
	if player == null:
		push_error("MOVEMENT_INPUT_SMOKE_FAILED: player unit is missing")
		get_tree().quit(1)
		return

	var start_cell: Vector2i = player.get_meta("cell", Vector2i.ZERO)
	var destination: Vector2i = start_cell
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var reachable: Dictionary = battle.get("reachable_cells") as Dictionary
	for raw_cell: Variant in reachable.keys():
		var candidate: Vector2i = raw_cell
		if candidate == start_cell:
			continue
		var world_position: Vector3 = battle.call("_cell_to_world", candidate)
		var battle_camera: Camera3D = battle.get("camera") as Camera3D
		if battle_camera.is_position_behind(world_position):
			continue
		var screen_position: Vector2 = battle_camera.unproject_position(world_position)
		if viewport_rect.has_point(screen_position):
			destination = candidate
			break

	if destination == start_cell:
		push_error("MOVEMENT_INPUT_SMOKE_FAILED: no visible reachable cell")
		get_tree().quit(1)
		return

	var camera: Camera3D = battle.get("camera") as Camera3D
	var destination_world: Vector3 = battle.call("_cell_to_world", destination)
	var click_position: Vector2 = camera.unproject_position(destination_world)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = click_position
	click.pressed = true
	battle.call("_unhandled_input", click)

	# Перемещение идёт через Tween, поэтому ждём его завершения.
	for _frame: int in range(240):
		await get_tree().process_frame
		if player.get_meta("cell", Vector2i.ZERO) == destination:
			print("MOVEMENT_INPUT_SMOKE_OK")
			get_tree().quit()
			return

	push_error("MOVEMENT_INPUT_SMOKE_FAILED: click did not move the unit")
	get_tree().quit(1)
