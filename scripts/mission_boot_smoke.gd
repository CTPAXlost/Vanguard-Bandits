extends Node

var expected_mission: int = 1
var forced_branch: String = ""


func _enter_tree() -> void:
	expected_mission = clampi(int(OS.get_environment("VBR_SMOKE_MISSION")), 1, 7)
	forced_branch = OS.get_environment("VBR_SMOKE_BRANCH")
	CampaignState.reset_campaign()
	if expected_mission == 1:
		CampaignState.current_mission = 1
		CampaignState.test_forced_branch = ""
		CampaignState.save_game()
	else:
		CampaignState.prepare_mission_for_test(expected_mission, forced_branch)


func _ready() -> void:
	var battle: Node = get_node_or_null("BattlePrototype")
	if battle == null:
		_fail("pre-instanced BattlePrototype is missing")
		return

	for _frame: int in range(1200):
		await get_tree().process_frame
		var mission_value: int = int(battle.get("mission_number"))
		if not bool(battle.get("battle_initialized")):
			continue
		var units_value: Variant = battle.get("units")
		var party_value: Variant = battle.get("player_party")
		if mission_value != expected_mission:
			continue
		if not (units_value is Array) or (units_value as Array).is_empty():
			continue
		if not (party_value is Array) or (party_value as Array).is_empty():
			continue
		if expected_mission == 6 and (party_value as Array).size() != 5:
			continue
		if expected_mission == 6 and bool(battle.get("mission_six_intro_pending")):
			continue
		if expected_mission == 6 and str(battle.get("kingdom_choice")) != forced_branch:
			continue
		if expected_mission == 7 and not bool(battle.get("mission_seven_boot_finished")):
			continue
		if expected_mission == 7 and CampaignState.kingdom_alliance != forced_branch:
			continue
		if expected_mission >= 2 and not bool(battle.get("runtime_test_balance_applied")):
			continue
		if expected_mission >= 2:
			var first_player: Node3D = (party_value as Array)[0] as Node3D
			var player_stats: Dictionary = first_player.get_meta("stats", {}) as Dictionary
			if int(player_stats.get("level", 1)) < _expected_level_floor(expected_mission):
				continue
			if int(player_stats.get("experience_needed", 0)) <= 0 and int(player_stats.get("level", 1)) < int(player_stats.get("max_level", 100)):
				continue
		print("MISSION_BOOT_SMOKE_OK mission=%d branch=%s units=%d party=%d" % [
			expected_mission,
			forced_branch,
			(units_value as Array).size(),
			(party_value as Array).size(),
		])
		await _clean_shutdown(battle, 0)
		return

	var units_value: Variant = battle.get("units")
	var party_value: Variant = battle.get("player_party")
	_fail("normal scene boot timed out; actual=%s initialized=%s units=%s party=%s intro_pending=%s choice=%s boot_started=%s boot_finalized=%s action=%s phase=%s" % [
		str(battle.get("mission_number")),
		str(battle.get("battle_initialized")),
		str((units_value as Array).size() if units_value is Array else -1),
		str((party_value as Array).size() if party_value is Array else -1),
		str(battle.get("mission_six_intro_pending")),
		str(battle.get("kingdom_choice")),
		str(battle.get("mission_six_boot_started")),
		str(battle.get("mission_six_boot_finalized")),
		str(battle.get("action_in_progress")),
		str(battle.get("phase")),
	])


func _expected_level_floor(mission_id: int) -> int:
	return int({1: 1, 2: 4, 3: 8, 4: 14, 5: 18, 6: 18, 7: 26}.get(mission_id, 1))


func _fail(message: String) -> void:
	push_error("MISSION_BOOT_SMOKE_FAILED: mission=%d branch=%s; %s" % [expected_mission, forced_branch, message])
	var battle: Node = get_node_or_null("BattlePrototype")
	await _clean_shutdown(battle, 1)


func _clean_shutdown(battle: Node, exit_code: int) -> void:
	# Free the instantiated battle and allow renderer deletion queues to flush
	# before quitting.  Immediate quit in 1.9.7 left RID/ObjectDB leak errors in
	# every otherwise successful smoke log.
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
	for _frame: int in range(3):
		await get_tree().process_frame
	get_tree().quit(exit_code)
