extends Node

const BATTLE_SCENE := preload("res://scenes/BattlePrototype.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Dictionary] = [
		{"mission": 1, "branch": ""},
		{"mission": 2, "branch": ""},
		{"mission": 3, "branch": "stay_and_fight"},
		{"mission": 4, "branch": "seek_southern_aid"},
		{"mission": 5, "branch": "defend_castle"},
		{"mission": 6, "branch": "south"},
	]
	for case: Dictionary in cases:
		await _check_mission(int(case["mission"]), str(case["branch"]))
	print("BATTLE_STARTUP_SMOKE_OK")
	get_tree().quit()

func _check_mission(mission_id: int, branch: String) -> void:
	CampaignState.reset_campaign()
	CampaignState.prepare_mission_for_test(mission_id, branch)
	await get_tree().process_frame
	var battle: Node = BATTLE_SCENE.instantiate()
	add_child(battle)
	for _frame: int in range(600):
		await get_tree().process_frame
		if bool(battle.get("battle_initialized")):
			break
	var units_value: Variant = battle.get("units")
	var player_value: Variant = battle.get("player_unit")
	if not bool(battle.get("battle_initialized")):
		_fail("mission %d never reached battle_initialized" % mission_id)
		return
	if int(battle.get("mission_number")) != mission_id:
		_fail("mission %d loaded controller mission %s" % [mission_id, str(battle.get("mission_number"))])
		return
	if not (units_value is Array) or (units_value as Array).is_empty():
		_fail("mission %d created no units" % mission_id)
		return
	if not (player_value is Node3D) or not is_instance_valid(player_value):
		_fail("mission %d created no player unit" % mission_id)
		return
	print("BATTLE_STARTUP_MISSION_%d_OK units=%d" % [mission_id, (units_value as Array).size()])
	battle.queue_free()
	for _frame: int in range(4):
		await get_tree().process_frame

func _fail(message: String) -> void:
	push_error("BATTLE_STARTUP_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
