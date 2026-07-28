extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_branch("south")
	await _check_branch("north")
	print("MISSION7_SMOKE_OK")
	get_tree().quit(0)


func _check_branch(branch: String) -> void:
	CampaignState.reset_campaign()
	CampaignState.prepare_mission_for_test(7, branch)
	await get_tree().process_frame
	var packed_scene: PackedScene = load("res://scenes/BattlePrototype.tscn")
	var battle: Node = packed_scene.instantiate()
	add_child(battle)
	var boot_ready: bool = await _wait_for_boot(battle, 1500)
	if not boot_ready:
		_fail("normal lifecycle timed out for %s" % branch)
		return
	if int(battle.get("mission_number")) != 7:
		_fail("mission VII did not load")
		return
	if CampaignState.kingdom_alliance != branch:
		_fail("alliance mismatch for %s" % branch)
		return
	var units_value: Variant = battle.get("units")
	var party_value: Variant = battle.get("player_party")
	if not (units_value is Array) or not (party_value is Array):
		_fail("unit collections are unavailable")
		return
	var units: Array = units_value as Array
	var party: Array = party_value as Array
	var expected_permanent: Array[String] = ["claire", "shion"] if branch == "south" else ["barlow", "milea", "puck"]
	var party_ids: Dictionary = {}
	for member_value: Variant in party:
		var member: Node3D = member_value as Node3D
		if member != null:
			party_ids[str(member.get_meta("character_id", ""))] = true
	var required_party_ids: Array[String] = ["bastion", "andrew", "ione", "reyna", "zeira"]
	required_party_ids.append_array(expected_permanent)
	for character_id: String in required_party_ids:
		if not party_ids.has(character_id):
			_fail("permanent party missing %s in %s branch" % [character_id, branch])
			return
	var labels: Dictionary = {}
	var enemy_count: int = 0
	var captive_count: int = 0
	for unit_value: Variant in units:
		var unit: Node3D = unit_value as Node3D
		if unit == null:
			continue
		labels[str(unit.get_meta("label", ""))] = true
		if str(unit.get_meta("team", "")) == "enemy":
			enemy_count += 1
		if bool(unit.get_meta("captive", false)):
			captive_count += 1
	if enemy_count != 11:
		_fail("mission VII must start with 11 enemies, got %d" % enemy_count)
		return
	if captive_count != 2 or not labels.has("Galvas / Serata") or not labels.has("Ganlon / Waiban"):
		_fail("Galvas and Ganlon prisoners are incomplete")
		return
	for required_label: String in ["Faulkner / Solarus", "Duyere / Sarbelas", "Sadira / Sylpheed", "Franco / Korbelan", "Halak / Korbelan", "Zakov / Sharking"]:
		if not labels.has(required_label):
			_fail("castle defence missing %s" % required_label)
			return
	if branch == "north":
		var milea: Node3D = battle.get("milea_unit") as Node3D
		var puck: Node3D = battle.get("puck_unit") as Node3D
		if milea == null or puck == null:
			_fail("Milea/Puck are missing")
			return
		var milea_attacks: Array[String] = CombatCatalog.attacks_for(milea)
		for mode: String in ["slash", "strong_slash", "panther_throw", "claw_release", "predator_assault", "panther_teleport"]:
			if not milea_attacks.has(mode):
				_fail("Panther kit missing %s" % mode)
				return
		var puck_attacks: Array[String] = CombatCatalog.attacks_for(puck)
		for mode: String in ["wrench_hit", "engineer_heal", "engineer_armor", "engineer_energy", "engineer_shield"]:
			if not puck_attacks.has(mode):
				_fail("Engineer kit missing %s" % mode)
				return
	battle.set("round_number", 5)
	battle.call("_begin_player_turn")
	var relief_ready: bool = await _wait_for_relief(battle, 1000)
	if not relief_ready:
		_fail("royal relief did not arrive for %s" % branch)
		return
	party_value = battle.get("player_party")
	party = party_value as Array
	var relief_count: int = 0
	var leader_found: bool = false
	var general_found: bool = branch == "south"
	for member_value: Variant in party:
		var member: Node3D = member_value as Node3D
		if member == null or not bool(member.get_meta("royal_relief", false)):
			continue
		relief_count += 1
		var character_id: String = str(member.get_meta("character_id", ""))
		var level: int = int((member.get_meta("stats", {}) as Dictionary).get("level", 1))
		if branch == "south" and character_id == "logan":
			leader_found = level >= 25
		elif branch == "north" and character_id == "alden":
			leader_found = level >= 24
		elif branch == "north" and character_id == "devlin":
			general_found = level >= 19
	if relief_count != (7 if branch == "south" else 8) or not leader_found or not general_found:
		_fail("relief composition is wrong for %s: count=%d leader=%s general=%s" % [branch, relief_count, str(leader_found), str(general_found)])
		return
	print("MISSION7_%s_BRANCH_OK party=%d relief=%d" % [branch.to_upper(), party.size(), relief_count])
	battle.queue_free()
	for _frame: int in range(4):
		await get_tree().process_frame


func _wait_for_boot(battle: Node, frames: int) -> bool:
	for _frame: int in range(frames):
		await get_tree().process_frame
		if int(battle.get("mission_number")) == 7 and bool(battle.get("mission_seven_boot_finished")):
			var party_value: Variant = battle.get("player_party")
			if party_value is Array and (party_value as Array).size() >= 7:
				return true
	return false


func _wait_for_relief(battle: Node, frames: int) -> bool:
	for _frame: int in range(frames):
		await get_tree().process_frame
		if bool(battle.get("relief_spawned")) and not bool(battle.get("relief_spawning")):
			return true
	return false


func _fail(message: String) -> void:
	push_error("MISSION7_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
