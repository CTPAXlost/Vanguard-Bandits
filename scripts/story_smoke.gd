extends Node


func _ready() -> void:
	# Do not replace the current scene from inside this smoke scene's _ready().
	# Godot is still attaching the scene root at that point, so change_scene_to_file()
	# attempts to remove a child while SceneTree is busy and then waits forever for UI.
	await get_tree().process_frame
	var forest_ok: bool = await _validate_branch("stay_and_fight", 6, "Глава IV — Лесной лагерь партизан")
	if not forest_ok:
		return
	var prison_ok: bool = await _validate_branch("seek_southern_aid", 5, "Глава IV — Имперская тюрьма")
	if not prison_ok:
		return
	print("STORY_SMOKE_OK")
	get_tree().quit()


func _validate_branch(branch: String, expected_entries: int, expected_title: String) -> bool:
	CampaignState.reset_campaign()
	CampaignState.complete_mission(1)
	CampaignState.complete_mission(2)
	CampaignState.complete_mission(3, branch)
	CampaignState.current_mission = 5
	CampaignState.save_game()

	var packed_scene: PackedScene = load("res://scenes/StoryChapter.tscn") as PackedScene
	if packed_scene == null:
		return _fail("STORY_SMOKE_FAILED: StoryChapter scene did not load")
	var chapter: Control = packed_scene.instantiate() as Control
	if chapter == null:
		return _fail("STORY_SMOKE_FAILED: StoryChapter scene did not instantiate")
	add_child(chapter)
	await get_tree().process_frame

	var entries_value: Variant = chapter.get("entries")
	if not (entries_value is Array):
		return _fail("STORY_SMOKE_FAILED: entries are missing for branch %s" % branch)
	var entries: Array = entries_value as Array
	if entries.size() != expected_entries:
		return _fail(
			"STORY_SMOKE_FAILED: branch %s entries=%d expected=%d"
			% [branch, entries.size(), expected_entries]
		)
	var chapter_label: Label = chapter.get("chapter_label") as Label
	if chapter_label == null or chapter_label.text != expected_title:
		return _fail("STORY_SMOKE_FAILED: wrong chapter title for branch %s" % branch)
	var speaker_label: Label = chapter.get("speaker_label") as Label
	var text_label: Label = chapter.get("text_label") as Label
	if speaker_label == null or speaker_label.text.strip_edges().is_empty():
		return _fail("STORY_SMOKE_FAILED: first speaker is empty for branch %s" % branch)
	if text_label == null or text_label.text.strip_edges().is_empty():
		return _fail("STORY_SMOKE_FAILED: first dialogue is empty for branch %s" % branch)

	chapter.queue_free()
	await get_tree().process_frame
	return true


func _fail(message: String) -> bool:
	push_error(message)
	get_tree().quit(1)
	return false
