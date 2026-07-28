extends Node


func _ready() -> void:
	CampaignState.reset_campaign()
	CampaignState.complete_mission(1)
	CampaignState.complete_mission(2)
	CampaignState.complete_mission(3, "seek_southern_aid")
	CampaignState.current_mission = 4
	CampaignState.save_game()

	# Не вызываем смену сцены из _ready(): в этот момент родитель
	# ещё может добавлять узлы, из-за чего Godot выдаёт remove_child busy.
	await get_tree().process_frame
	var packed_scene: PackedScene = load("res://scenes/BattlePrototype.tscn")
	var battle_scene: Node = packed_scene.instantiate()
	add_child(battle_scene)
	await get_tree().process_frame
	print("MISSION4_SMOKE_OK")
	await get_tree().process_frame
	get_tree().quit()
