extends Node

var expected_mission: int = 1
var forced_branch: String = ""


func _enter_tree() -> void:
	expected_mission = clampi(int(OS.get_environment("VBR_SMOKE_MISSION")), 1, 6)
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
		print("MISSION_BOOT_SMOKE_OK mission=%d branch=%s units=%d party=%d" % [
			expected_mission,
			forced_branch,
			(units_value as Array).size(),
			(party_value as Array).size(),
		])
		get_tree().quit()
		return

	var units_value: Variant = battle.get("units")
	var party_value: Variant = battle.get("player_party")
	_fail("normal scene boot timed out; actual=%s units=%s party=%s" % [
		str(battle.get("mission_number")),
		str((units_value as Array).size() if units_value is Array else -1),
		str((party_value as Array).size() if party_value is Array else -1),
	])


func _fail(message: String) -> void:
	push_error("MISSION_BOOT_SMOKE_FAILED: mission=%d branch=%s; %s" % [expected_mission, forced_branch, message])
	get_tree().quit(1)
