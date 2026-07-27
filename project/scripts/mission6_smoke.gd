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

	# Use only the normal BattlePrototype scene lifecycle. No test fixture may call
	# private setup methods to conceal a broken _ready chain.
	var ready: bool = await _wait_for_mission_six(battle, 1200, branch)
	if not ready:
		_fail("mission six normal lifecycle timed out for %s" % branch)
		return
	var units_value: Variant = battle.get("units")

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
	var party_value: Variant = battle.get("player_party")
	if not (party_value is Array) or (party_value as Array).size() != 5:
		_fail("mission six player party must contain exactly five heroes")
		return
	var expected_party_ids: Dictionary = {"bastion": true, "andrew": true, "zeira": true, "ione": true, "reyna": true}
	var actual_party_ids: Dictionary = {}
	var party_members: Array = party_value as Array
	for party_member_value: Variant in party_members:
		var party_member: Node3D = party_member_value as Node3D
		if party_member == null or not bool(party_member.get_meta("player", false)) or str(party_member.get_meta("team", "")) != "ally":
			_fail("mission six party contains a non-player or non-allied unit")
			return
		actual_party_ids[str(party_member.get_meta("character_id", ""))] = true
	if actual_party_ids.size() != expected_party_ids.size():
		_fail("mission six party roster has the wrong size: %s" % str(actual_party_ids.keys()))
		return
	for expected_id: String in expected_party_ids:
		if not actual_party_ids.has(expected_id):
			_fail("mission six party is missing %s" % expected_id)
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
	for leader: Node3D in [logan, alden, devlin]:
		if leader == null or bool(leader.get_meta("player", true)):
			_fail("kingdom leaders must be AI-controlled")
			return
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
		var first_wave_size: int = (south_bots_value as Array).size()
		for bot_value: Variant in (south_bots_value as Array).duplicate():
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
		var reinforced_value: Variant = battle.get("south_bots")
		if not (reinforced_value is Array) or (reinforced_value as Array).size() != first_wave_size + 6:
			_fail("southern reinforcement must add exactly six Rahabor")
			return

	# Persist and reload the chosen kingdom. This is the same save path used by
	# the campaign hub and future chapters.
	CampaignState.complete_mission(6, branch)
	if CampaignState.kingdom_alliance != branch:
		_fail("alliance was not stored in campaign state")
		return
	CampaignState.kingdom_alliance = ""
	if not CampaignState.load_game() or CampaignState.kingdom_alliance != branch:
		_fail("alliance did not survive save/load")
		return
	print("MISSION6_SAVE_%s_OK" % branch.to_upper())
	print("MISSION6_%s_BRANCH_OK" % branch.to_upper())
	battle.queue_free()
	for _frame: int in range(3):
		await get_tree().process_frame


func _wait_for_mission_six(battle: Node, frames: int, branch: String) -> bool:
	for _frame: int in range(frames):
		await get_tree().process_frame
		var units_value: Variant = battle.get("units")
		var party_value: Variant = battle.get("player_party")
		if int(battle.get("mission_number")) != 6:
			continue
		if not (units_value is Array) or (units_value as Array).is_empty():
			continue
		if not (party_value is Array) or (party_value as Array).size() != 5:
			continue
		if bool(battle.get("mission_six_intro_pending")):
			continue
		if str(battle.get("kingdom_choice")) != branch:
			continue
		return true
	return false


func _fail(message: String) -> void:
	push_error("MISSION6_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
