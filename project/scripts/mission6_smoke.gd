extends Node

const BATTLE_SCENE := preload("res://scenes/BattlePrototype.tscn")

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
	var battle: Node = BATTLE_SCENE.instantiate()
	add_child(battle)
	for _frame: int in range(900):
		await get_tree().process_frame
		if bool(battle.get("battle_initialized")) and int(battle.get("mission_number")) == 6:
			break
	if not bool(battle.get("battle_initialized")) or int(battle.get("mission_number")) != 6:
		_fail("mission VI did not complete production initialisation for %s" % branch)
		return

	var units_value: Variant = battle.get("units")
	var party_value: Variant = battle.get("player_party")
	if not (units_value is Array) or (units_value as Array).is_empty():
		_fail("mission VI created no units")
		return
	if not (party_value is Array) or (party_value as Array).size() != 5:
		_fail("mission VI player party is incomplete: %s" % str(party_value))
		return
	var units: Array = units_value as Array
	var labels: Dictionary = {}
	var south_count := 0
	var north_count := 0
	var new_rigs := 0
	for value: Variant in units:
		var unit: Node3D = value as Node3D
		if unit == null:
			continue
		var label := str(unit.get_meta("label", ""))
		labels[label] = unit
		if label.contains("Южный рыцарь"):
			south_count += 1
		if label.contains("Северный боец"):
			north_count += 1
		var slug := str(unit.get_meta("model_slug", ""))
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
	var expected_ally := "Logan / Crimson" if branch == "south" else "Alden / Altagrave"
	var expected_enemy := "Alden / Altagrave" if branch == "south" else "Logan / Crimson"
	if str((labels[expected_ally] as Node3D).get_meta("team", "")) != "ally":
		_fail("chosen kingdom leader is not allied for %s" % branch)
		return
	if str((labels[expected_enemy] as Node3D).get_meta("team", "")) != "enemy":
		_fail("rejected kingdom leader is not hostile for %s" % branch)
		return
	if branch == "south":
		var south_bots_value: Variant = battle.get("south_bots")
		for bot_value: Variant in south_bots_value as Array:
			var bot: Node3D = bot_value as Node3D
			var stats: Dictionary = bot.get_meta("stats") as Dictionary
			stats["hp"] = 0
			bot.set_meta("stats", stats)
		var unit_count_before: int = units.size()
		battle.call("_check_south_reinforcement")
		await get_tree().process_frame
		if not bool(battle.get("southern_reinforcement_spawned")):
			_fail("second southern wave did not spawn")
			return
		var after_value: Variant = battle.get("units")
		var reinforcement_count: int = 0
		if after_value is Array:
			for reinforcement_value: Variant in after_value as Array:
				var reinforcement: Node3D = reinforcement_value as Node3D
				if reinforcement != null and str(reinforcement.get_meta("label", "")).contains("Южная подмога"):
					reinforcement_count += 1
		if reinforcement_count != 6 or not (after_value is Array) or (after_value as Array).size() < unit_count_before + 6:
			_fail("second southern wave composition is incomplete: %d/6" % reinforcement_count)
			return
	print("MISSION6_%s_BRANCH_OK" % branch.to_upper())
	battle.queue_free()
	for _frame: int in range(4):
		await get_tree().process_frame

func _fail(message: String) -> void:
	push_error("MISSION6_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
