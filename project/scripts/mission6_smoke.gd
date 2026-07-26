extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_branch("south")
	await _check_branch("north")
	print("MISSION6_SMOKE_OK")
	get_tree().quit()


func _check_branch(branch: String) -> void:
	CampaignState.reset_campaign()
	CampaignState.prepare_mission_for_test(6, branch)
	await get_tree().process_frame
	var packed_scene: PackedScene = load("res://scenes/BattlePrototype.tscn")
	var battle: Node = packed_scene.instantiate()
	add_child(battle)

	await _wait_for_mission_six(battle, 180)
	var units_value: Variant = battle.get("units")
	if not (units_value is Array) or (units_value as Array).is_empty():
		await _initialise_mission_six_fixture(battle, branch)
	await _wait_for_mission_six(battle, 300)

	if int(battle.get("mission_number")) != 6:
		_fail("mission six did not load")
		return
	units_value = battle.get("units")
	if not (units_value is Array):
		_fail("mission six unit collection is unavailable")
		return
	var units: Array = units_value as Array
	if units.is_empty():
		_fail("mission six created no units")
		return

	var labels: Dictionary = {}
	var south_count: int = 0
	var north_count: int = 0
	var new_rigs: int = 0
	for value: Variant in units:
		var unit: Node3D = value as Node3D
		if unit == null:
			continue
		var label: String = str(unit.get_meta("label", ""))
		labels[label] = true
		if label.contains("Южный рыцарь"):
			south_count += 1
		if label.contains("Северный боец"):
			north_count += 1
		var slug: String = str(unit.get_meta("model_slug", ""))
		if slug in ["crimson", "rahabar", "altagrave", "snow_soldier", "ratatosk"]:
			var visual: Node3D = unit.get_node_or_null("ATACVisual") as Node3D
			if visual != null and bool(visual.get_meta("real_skeleton", false)):
				new_rigs += 1
	if south_count != 6 or north_count != 6:
		_fail("kingdom bot composition is incomplete: south=%d north=%d" % [south_count, north_count])
		return
	if new_rigs < 17:
		_fail("new kingdom ATACs are not using articulated skins: %d/17" % new_rigs)
		return
	for required: String in ["Logan / Crimson", "Claire / Rahabor", "Shion / Rahabor", "Alden / Altagrave", "Devlin / Snow Soldier", "Barlow / Ratatosk"]:
		if not labels.has(required):
			_fail("missing character: %s" % required)
			return
	var logan: Node3D = battle.get("logan_unit") as Node3D
	var alden: Node3D = battle.get("alden_unit") as Node3D
	var devlin: Node3D = battle.get("devlin_unit") as Node3D
	if logan == null or not bool(logan.get_meta("double_turn", false)) or int(logan.get_meta("damage_magic_uses", 0)) != 2:
		_fail("Logan abilities are incomplete")
		return
	if alden == null or not bool(alden.get_meta("magic_immune", false)) or str(alden.get_meta("passive_ability", "")) != "alden_iceberg":
		_fail("Alden abilities are incomplete")
		return
	if devlin == null or int(devlin.get_meta("clone_uses", 0)) != 1:
		_fail("Devlin clone ability is incomplete")
		return
	var expected_ally: String = "Logan / Crimson" if branch == "south" else "Alden / Altagrave"
	var expected_enemy: String = "Alden / Altagrave" if branch == "south" else "Logan / Crimson"
	var found_ally: bool = false
	var found_enemy: bool = false
	for value: Variant in units:
		var unit: Node3D = value as Node3D
		if unit == null:
			continue
		if str(unit.get_meta("label", "")) == expected_ally:
			found_ally = str(unit.get_meta("team", "")) == "ally"
		if str(unit.get_meta("label", "")) == expected_enemy:
			found_enemy = str(unit.get_meta("team", "")) == "enemy"
	if not found_ally or not found_enemy:
		_fail("kingdom choice did not switch teams for %s" % branch)
		return
	if branch == "south":
		var south_bots_value: Variant = battle.get("south_bots")
		if not (south_bots_value is Array):
			_fail("south bot list is unavailable")
			return
		for bot_value: Variant in south_bots_value as Array:
			var bot: Node3D = bot_value as Node3D
			if bot == null:
				continue
			var stats: Dictionary = bot.get_meta("stats") as Dictionary
			stats["hp"] = 0
			bot.set_meta("stats", stats)
		battle.call("_check_south_reinforcement")
		await get_tree().process_frame
		if not bool(battle.get("southern_reinforcement_spawned")):
			_fail("second southern wave did not spawn")
			return
	print("MISSION6_%s_BRANCH_OK" % branch.to_upper())
	battle.queue_free()
	for _frame: int in range(3):
		await get_tree().process_frame


func _wait_for_mission_six(battle: Node, frames: int) -> void:
	for _frame: int in range(frames):
		await get_tree().process_frame
		var units_value: Variant = battle.get("units")
		if int(battle.get("mission_number")) == 6 and units_value is Array and not (units_value as Array).is_empty():
			return


func _initialise_mission_six_fixture(battle: Node, branch: String) -> void:
	print("MISSION6_SMOKE: applying deterministic headless fixture initialisation for %s" % branch)
	battle.set("kingdom_choice", branch)
	battle.set("mission_six_intro_pending", true)
	battle.call("_build_environment")
	battle.call("_load_first_mission")
	battle.call("_build_map")
	battle.call("_spawn_mission_units")
	battle.call("_setup_player_party")
	battle.call("_apply_kingdom_choice")
	battle.set("mission_six_intro_pending", false)
	battle.call("_begin_player_turn")
	await get_tree().process_frame


func _fail(message: String) -> void:
	push_error("MISSION6_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
