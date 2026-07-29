extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	CampaignState.reset_campaign()
	CampaignState.prepare_mission_for_test(4)
	await get_tree().process_frame
	var packed_scene: PackedScene = load("res://scenes/BattlePrototype.tscn") as PackedScene
	if packed_scene == null:
		await _fail("BattlePrototype could not be loaded")
		return
	var battle: Node = packed_scene.instantiate()
	add_child(battle)

	var ready_for_input: bool = false
	for _frame: int in range(1800):
		await get_tree().process_frame
		var dialogue_panel: Control = battle.get_node_or_null("HUD/DialoguePanel") as Control
		if dialogue_panel != null and dialogue_panel.visible:
			battle.emit_signal("dialogue_advanced")
		var party_value: Variant = battle.get("player_party")
		var reachable_value: Variant = battle.get("reachable_cells")
		if (
			int(battle.get("mission_number")) == 4
			and bool(battle.get("battle_initialized"))
			and party_value is Array
			and (party_value as Array).size() == 4
			and not bool(battle.get("mission_four_intro_pending"))
			and not bool(battle.get("action_in_progress"))
			and int(battle.get("phase")) != 4
			and bool(battle.get("runtime_test_balance_applied"))
			and reachable_value is Dictionary
			and not (reachable_value as Dictionary).is_empty()
		):
			ready_for_input = true
			break
	if not ready_for_input:
		await _fail("normal mission-IV lifecycle never reached a controllable turn")
		return

	var party: Array = battle.get("player_party") as Array
	var kamorge: Node3D = battle.get("kamorge_unit") as Node3D
	if kamorge == null or str(kamorge.get_meta("character_id", "")) != "kamorge":
		await _fail("Kamorge is missing from mission IV")
		return
	if str(kamorge.get_meta("model_slug", "")) != "eigol":
		await _fail("Kamorge must use Eigol only after surviving mission III")
		return
	var player_stats: Dictionary = (party[0] as Node3D).get_meta("stats", {}) as Dictionary
	if int(player_stats.get("level", 1)) < 14:
		await _fail("mission-IV test scaling left a player below level 14")
		return
	if int(player_stats.get("experience_needed", 0)) <= 0:
		await _fail("mission-IV player progression fields are missing")
		return

	var start_cell: Vector2i = kamorge.get_meta("cell", Vector2i.ZERO)
	var destination: Vector2i = start_cell
	for raw_cell: Variant in (battle.get("reachable_cells") as Dictionary).keys():
		var candidate: Vector2i = raw_cell
		if candidate != start_cell:
			destination = candidate
			break
	if destination == start_cell:
		await _fail("mission-IV player has no reachable destination")
		return
	await battle.call("_animate_path", kamorge, [destination], 0.02)
	if kamorge.get_meta("cell", Vector2i.ZERO) != destination:
		await _fail("mission-IV player cannot move after the intro")
		return

	print("MISSION4_BOOT_AND_MOVEMENT_OK party=%d level=%d atac=%s" % [
		party.size(), int(player_stats.get("level", 1)), str(kamorge.get_meta("model_slug", "")),
	])
	print("MISSION4_SMOKE_OK")
	await _clean_shutdown(battle, 0)


func _fail(message: String) -> void:
	push_error("MISSION4_SMOKE_FAILED: %s" % message)
	var battle: Node = get_node_or_null("BattlePrototype")
	await _clean_shutdown(battle, 1)


func _clean_shutdown(battle: Node, exit_code: int) -> void:
	if battle != null and is_instance_valid(battle):
		battle.set_process(false)
		battle.set_physics_process(false)
		battle.queue_free()
	for _frame: int in range(10):
		await get_tree().process_frame
	get_tree().quit(exit_code)
