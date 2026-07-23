extends Node


func _ready() -> void:
	CampaignState.reset_campaign()
	CampaignState.complete_mission(1)
	CampaignState.complete_mission(2)
	CampaignState.current_mission = 3
	CampaignState.save_game()

	# Сцену нельзя менять прямо во время добавления текущего узла в дерево.
	# Для smoke-теста безопасно создаём боевую сцену дочерним узлом
	# после завершения текущего кадра.
	await get_tree().process_frame
	var packed_scene: PackedScene = load("res://scenes/BattlePrototype.tscn")
	var battle_scene: Node = packed_scene.instantiate()
	add_child(battle_scene)
	await get_tree().process_frame
	print("MISSION3_SMOKE_OK")
	await get_tree().process_frame
	get_tree().quit()
