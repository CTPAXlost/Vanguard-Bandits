extends Node


func _ready() -> void:
	CampaignState.reset_campaign()
	CampaignState.complete_mission(1)
	CampaignState.complete_mission(2)
	CampaignState.complete_mission(3, "stay_and_fight")
	CampaignState.current_mission = 5
	CampaignState.save_game()
	get_tree().change_scene_to_file("res://scenes/StoryChapter.tscn")
