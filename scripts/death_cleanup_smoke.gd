extends Node


func _ready() -> void:
	CampaignState.reset_campaign()
	CampaignState.current_mission = 1
	CampaignState.save_game()

	var packed_scene: PackedScene = load("res://scenes/BattlePrototype.tscn")
	var battle: Node = packed_scene.instantiate()
	add_child(battle)
	for _frame: int in range(10):
		await get_tree().process_frame

	# Prevent the first-mission reinforcement dialogue from interrupting this
	# focused cleanup test.
	battle.set("defeated_enemy_count", 1)
	var units: Array = battle.get("units") as Array
	var enemy: Node3D = null
	for candidate_value: Variant in units:
		var candidate: Node3D = candidate_value as Node3D
		if candidate != null and str(candidate.get_meta("team", "")) == "enemy":
			enemy = candidate
			break
	if enemy == null:
		_fail("DEATH_CLEANUP_SMOKE_FAILED: no enemy")
		return

	var enemy_reference: WeakRef = weakref(enemy)
	var enemy_instance_id: int = enemy.get_instance_id()
	var old_cell: Vector2i = enemy.get_meta("cell", Vector2i.ZERO)
	await battle.call("_damage_target", enemy, 999999)
	for _frame: int in range(8):
		await get_tree().process_frame

	var remaining: Array = battle.get("units") as Array
	for remaining_value: Variant in remaining:
		var remaining_unit: Node3D = remaining_value as Node3D
		if remaining_unit != null and is_instance_valid(remaining_unit) and remaining_unit.get_instance_id() == enemy_instance_id:
			_fail("DEATH_CLEANUP_SMOKE_FAILED: defeated unit remains in units")
			return
	if enemy_reference.get_ref() != null:
		var leftover: Node3D = enemy_reference.get_ref() as Node3D
		if leftover != null and leftover.visible:
			_fail("DEATH_CLEANUP_SMOKE_FAILED: defeated visual remains visible")
			return
	if battle.call("_unit_at", old_cell) != null:
		_fail("DEATH_CLEANUP_SMOKE_FAILED: defeated unit still blocks its cell")
		return

	print("DEATH_CLEANUP_SMOKE_OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
