extends Control

const AtacProgression = preload("res://scripts/atac_progression.gd")
const CombatCatalog = preload("res://scripts/combat_catalog.gd")
# Historical branch title: ЛЕСНОЙ ЛАГЕРЬ ПАРТИЗАН

var status_label: Label
var character_panel: PanelContainer
var portrait: TextureRect
var character_select: OptionButton
var atac_select: OptionButton
var character_stats: Label
var points_label: Label
var selected_character_id: String = "bastion"
var mission_button: Button
var title_label: Label
var subtitle_label: Label
var wallet_label: Label
var store_button: Button
var mode_button: Button


func _ready() -> void:
	_build_interface()
	_refresh_campaign_status()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.035, 0.055, 0.085)
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(930, 680)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 14)
	margin.add_child(root_box)

	title_label = Label.new()
	title_label.text = "ЛАГЕРЬ — ПОСЛЕ ПЕРВОЙ МИССИИ"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	root_box.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.text = "Подготовка отряда перед дорогой через лес и болото"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 20)
	root_box.add_child(subtitle_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(status_label)
	wallet_label = Label.new()
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet_label.add_theme_font_size_override("font_size", 23)
	wallet_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32))
	root_box.add_child(wallet_label)

	var buttons: GridContainer = GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("h_separation", 12)
	buttons.add_theme_constant_override("v_separation", 12)
	root_box.add_child(buttons)
	_add_button(buttons, "Сохранить достижение", _save_progress)
	store_button = _add_button(buttons, "Общий магазин", _open_shop)
	mode_button = _add_button(buttons, "Тактические анимации: ВКЛ", _show_tactical_animation_info)
	mode_button.disabled = false
	_add_button(buttons, "Персонажи и ATAC", _open_characters)
	_add_button(buttons, "Выбор пройденной миссии", _open_mission_select)
	mission_button = _add_button(buttons, "Начать следующую миссию", _start_next_mission)
	_add_button(buttons, "Главное меню", _return_to_main)
	_add_button(buttons, "Выход", func(): get_tree().quit())

	character_panel = PanelContainer.new()
	character_panel.visible = false
	character_panel.custom_minimum_size = Vector2(0, 390)
	root_box.add_child(character_panel)
	var character_margin: MarginContainer = MarginContainer.new()
	character_margin.add_theme_constant_override("margin_left", 18)
	character_margin.add_theme_constant_override("margin_right", 18)
	character_margin.add_theme_constant_override("margin_top", 16)
	character_margin.add_theme_constant_override("margin_bottom", 16)
	character_panel.add_child(character_margin)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	character_margin.add_child(columns)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(250, 250)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	columns.add_child(portrait)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	character_select = OptionButton.new()
	character_select.item_selected.connect(_on_character_selected)
	right.add_child(character_select)
	atac_select = OptionButton.new()
	atac_select.item_selected.connect(_on_atac_selected)
	right.add_child(atac_select)
	character_stats = Label.new()
	character_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(character_stats)
	points_label = Label.new()
	right.add_child(points_label)
	var stat_buttons: GridContainer = GridContainer.new()
	stat_buttons.columns = 2
	right.add_child(stat_buttons)
	_add_button(stat_buttons, "+ Сила", func(): _allocate("strength"))
	_add_button(stat_buttons, "+ Ловкость", func(): _allocate("agility"))
	_add_button(stat_buttons, "+ Защита", func(): _allocate("defense"))
	_add_button(stat_buttons, "+ Умение атаки", func(): _allocate("attack_skill"))
	_add_button(right, "Закрыть персонажей", func(): character_panel.visible = false)
	_populate_characters()


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _refresh_campaign_status() -> void:
	wallet_label.text = "Общий фонд команды: %d монет" % CampaignState.get_coin_balance()
	store_button.disabled = not CampaignState.is_shop_available()
	store_button.text = "Общий магазин — открыт" if CampaignState.is_shop_available() else "Общий магазин — закрыт"
	mode_button.text = "Тактические анимации: ВКЛ"
	if CampaignState.mission_6_complete:
		title_label.text = "СОЮЗ КОРОЛЕВСТВ ЗАКЛЮЧЁН"
		var side_name: String = "Южное" if CampaignState.kingdom_alliance == "south" else "Северное"
		subtitle_label.text = "%s королевство стало союзником Bastion" % side_name
		status_label.text = "Выбранная сторона согласилась помочь в дальнейшей войне. Следующая глава готовится."
		mission_button.text = "Следующая глава готовится"
		mission_button.disabled = true
	elif CampaignState.mission_5_complete:
		title_label.text = "ЗАМОК УДЕРЖАН — ВЕТКА KAMORGE"
		subtitle_label.text = "Kamorge жив; эта сюжетная линия продолжится в отдельной главе"
		status_label.text = "Глава VI «Война Севера и Юга» открывается только после гибели Kamorge в миссии 3А."
		mission_button.text = "Продолжение ветки Kamorge готовится"
		mission_button.disabled = true
	elif CampaignState.mission_4_complete:
		title_label.text = "ГЛАВА V — ЗАЩИТА ОСВОБОЖДЁННОГО ЗАМКА"
		subtitle_label.text = "Faulkner возвращается с новой армией"
		status_label.text = "Bastion и Andrew снова в отряде. Faulkner идёт на замок, а Sadira наблюдает за сражением."
		mission_button.text = "Начать пятую миссию — защита замка"
		mission_button.disabled = false
	elif CampaignState.mission_3_complete and CampaignState.story_branch == "seek_southern_aid":
		title_label.text = "ГЛАВА IV — ШТУРМ ИМПЕРСКОГО ЗАМКА"
		subtitle_label.text = "Kamorge выжил, нашёл Eigol и союзников"
		status_label.text = "Bastion и Andrew находятся в плену. Kamorge и партизаны готовят штурм."
		mission_button.text = "Начать четвёртую миссию — штурм замка"
		mission_button.disabled = false
	elif CampaignState.mission_3_complete:
		title_label.text = "ЛЕСНОЙ ПУТЬ К ДВУМ КОРОЛЕВСТВАМ"
		subtitle_label.text = "Kamorge погиб. Zeira ведёт спасённых Bastion и Andrew на юг"
		status_label.text = "Впереди война Северного и Южного королевств. Придётся выбрать будущего союзника."
		mission_button.text = "Начать главу VI — выбрать сторону"
		mission_button.disabled = false
	elif CampaignState.mission_2_complete:
		title_label.text = "ЛАГЕРЬ — ПОСЛЕ ВТОРОЙ МИССИИ"
		subtitle_label.text = "Andrew и Vedocorban присоединились к отряду"
		status_label.text = "Впереди мост и судьбоносный выбор Kamorge."
		mission_button.text = "Начать третью миссию"
		mission_button.disabled = false
	else:
		title_label.text = "ЛАГЕРЬ — ПОСЛЕ ПЕРВОЙ МИССИИ"
		subtitle_label.text = "Подготовка отряда перед дорогой через лес и болото"
		status_label.text = "Bastion и Kamorge готовятся освободить Andrew."
		mission_button.text = "Начать вторую миссию"
		mission_button.disabled = false


func _populate_characters() -> void:
	character_select.clear()
	var ids: Array[String] = CampaignState.get_unlocked_character_ids()
	for character_id: String in ids:
		var data: Dictionary = CampaignState.get_character(character_id)
		character_select.add_item(str(data.get("name", character_id)))
		character_select.set_item_metadata(character_select.item_count - 1, character_id)
	if not ids.is_empty():
		selected_character_id = ids[0]
		_refresh_character_panel()


func _on_character_selected(index: int) -> void:
	selected_character_id = str(character_select.get_item_metadata(index))
	_refresh_character_panel()


func _refresh_character_panel() -> void:
	var data: Dictionary = CampaignState.get_character(selected_character_id)
	if data.is_empty():
		return
	portrait.texture = load(str(data.get("portrait", "")))
	atac_select.clear()
	var selected_atac: String = str(data.get("atac", "alba"))
	var selected_index: int = 0
	for atac_id: String in CampaignState.unlocked_atacs:
		var atac_data: Dictionary = CampaignState.ATAC_DATA.get(atac_id, {}) as Dictionary
		atac_select.add_item(str(atac_data.get("name", atac_id.capitalize())))
		atac_select.set_item_metadata(atac_select.item_count - 1, atac_id)
		if atac_id == selected_atac:
			selected_index = atac_select.item_count - 1
	atac_select.select(selected_index)
	var stored_level: int = int(data.get("level", 1))
	var maximum_level: int = AtacProgression.max_level(selected_atac, 99)
	var level: int = mini(stored_level, maximum_level)
	var next_data: Dictionary = AtacProgression.next_unlock(selected_atac, level)
	var next_unlock_text: String = "Все приёмы открыты"
	if not next_data.is_empty():
		var attack_labels: Array[String] = []
		for attack_value: Variant in (next_data.get("attacks", []) as Array):
			attack_labels.append(str(CombatCatalog.attack(str(attack_value)).get("label", str(attack_value))))
		next_unlock_text = "ур. %d — %s" % [int(next_data.get("level", 1)), ", ".join(PackedStringArray(attack_labels))]
	var experience_text: String = "MAX" if level >= maximum_level else "%d / %d" % [int(data.get("experience", 0)), CampaignState.xp_needed(level)]
	character_stats.text = (
		(
			"Уровень персонажа / ATAC: %d / %d\nОпыт: %s\nТекущий ATAC: %s\n"
			+ "Следующий приём: %s\n"
			+ "Бонус силы: +%d • ловкости: +%d • защиты: +%d • умения атаки: +%d\n"
			+ "За каждый новый уровень выдаётся 3 очка. HP растёт вместе с уровнем установленного ATAC."
		)
		% [
			level,
			maximum_level,
			experience_text,
			str((CampaignState.ATAC_DATA.get(selected_atac, {}) as Dictionary).get("name", selected_atac)),
			next_unlock_text,
			int(data.get("strength_bonus", 0)),
			int(data.get("agility_bonus", 0)),
			int(data.get("defense_bonus", 0)),
			int(data.get("attack_skill_bonus", 0)),
		]
	)
	points_label.text = "Свободные очки прокачки: %d" % int(data.get("stat_points", 0))


func _on_atac_selected(index: int) -> void:
	var atac_id: String = str(atac_select.get_item_metadata(index))
	if CampaignState.assign_atac(selected_character_id, atac_id):
		status_label.text = (
			"ATAC назначен. Если он был у другого союзника, "
			+ "роботы автоматически обменялись владельцами."
		)
		_refresh_character_panel()


func _allocate(stat_key: String) -> void:
	if CampaignState.allocate_stat(selected_character_id, stat_key):
		status_label.text = "Очко характеристики распределено."
	else:
		status_label.text = "Нет свободных очков прокачки."
	_refresh_character_panel()


func _start_next_mission() -> void:
	if CampaignState.mission_6_complete:
		return
	if CampaignState.mission_5_complete:
		# Mission VI is not part of the surviving-Kamorge branch.
		return
	if CampaignState.mission_4_complete:
		CampaignState.current_mission = 5
		CampaignState.save_game()
		get_tree().change_scene_to_file("res://scenes/BattlePrototype.tscn")
		return
	if CampaignState.mission_3_complete and CampaignState.story_branch == "stay_and_fight":
		CampaignState.current_mission = 6
		CampaignState.save_game()
		get_tree().change_scene_to_file("res://scenes/BattlePrototype.tscn")
		return
	if CampaignState.mission_3_complete and CampaignState.story_branch == "seek_southern_aid":
		CampaignState.current_mission = 4
		CampaignState.save_game()
		get_tree().change_scene_to_file("res://scenes/BattlePrototype.tscn")
		return
	CampaignState.current_mission = 3 if CampaignState.mission_2_complete else 2
	CampaignState.save_game()
	get_tree().change_scene_to_file("res://scenes/BattlePrototype.tscn")


func _save_progress() -> void:
	CampaignState.save_game()
	_set_status("Прогресс кампании сохранён.")


func _open_characters() -> void:
	character_panel.visible = true
	_populate_characters()
	_set_status("Открыта настройка персонажей и ATAC.")


func _open_shop() -> void:
	if not CampaignState.is_shop_available():
		status_label.text = "Магазин ещё закрыт."
		return
	get_tree().change_scene_to_file("res://scenes/Shop.tscn")


func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message


func _show_tactical_animation_info() -> void:
	_set_status("Отдельная 3D-арена удалена. Все игроки и боты используют индивидуальные анимации прямо на тактическом поле.")


func _return_to_main() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _open_mission_select() -> void:
	CampaignState.mission_selector_return_scene = "res://scenes/CampaignHub.tscn"
	get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")
