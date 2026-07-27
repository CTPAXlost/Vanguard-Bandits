extends Control

const BATTLE_SCENE: String = "res://scenes/BattlePrototype.tscn"

var wallet_label: Label
var details_label: Label
var mission_button_count: int = 0


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.045, 0.075)
	add_child(background)

	var safe_margin: MarginContainer = MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 24)
	safe_margin.add_theme_constant_override("margin_right", 24)
	safe_margin.add_theme_constant_override("margin_top", 20)
	safe_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(safe_margin)
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(760, 560)
	safe_margin.add_child(panel)
	var panel_margin: MarginContainer = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 26)
	panel_margin.add_theme_constant_override("margin_right", 26)
	panel_margin.add_theme_constant_override("margin_top", 22)
	panel_margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(panel_margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "MissionScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_margin.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "MissionList"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 13)
	scroll.add_child(box)

	var title: Label = Label.new()
	title.text = "ВЫБОР МИССИИ — РЕЖИМ ТЕСТИРОВАНИЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "Пройденные задания можно запускать повторно. Для третьей, пятой и шестой миссий доступны отдельные сюжетные варианты."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 19)
	box.add_child(subtitle)

	wallet_label = Label.new()
	wallet_label.text = "Общий фонд команды: %d монет" % CampaignState.get_coin_balance()
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet_label.add_theme_font_size_override("font_size", 24)
	wallet_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32))
	box.add_child(wallet_label)

	_add_mission_button(
		box,
		"Миссия 1 — Приграничная деревня",
		"Bastion защищает деревню. После первого уничтоженного ATAC приходит Kamorge.",
		1,
		""
	)
	_add_mission_button(
		box,
		"Миссия 2 — Лес и болото: спасение Andrew",
		"Bastion и Kamorge прорывают окружение и освобождают Andrew вместе с Vedocorban.",
		2,
		""
	)
	_add_mission_button(
		box,
		"Миссия 3А — Мост: остаться с Kamorge",
		"Bastion отказывается уходить. Kamorge сражается с Faulkner и погибает; затем приходят Ione, Reyna и Zeira.",
		3,
		"stay_and_fight"
	)
	_add_mission_button(
		box,
		"Миссия 3Б — Мост: послушать Kamorge",
		"Kamorge лишает Barazaph силы и прыгает в реку. Bastion и Andrew остаются без помощи и попадают в плен.",
		3,
		"seek_southern_aid"
	)
	_add_mission_button(
		box,
		"Миссия 4 — Штурм имперского замка",
		"Kamorge находит Eigol, объединяется с Galvas и партизанами и идёт освобождать Bastion и Andrew.",
		4,
		"seek_southern_aid"
	)
	_add_mission_button(
		box,
		"Миссия 5А — Защитить освобождённый замок",
		"Faulkner атакует замок. Sadira, Franco и Halak наблюдают с востока и вступят в бой против того, кто ударит их первым.",
		5,
		"defend_castle"
	)
	_add_mission_button(
		box,
		"Миссия 5Б — Покинуть замок и идти к Logan",
		"Отряд отказывается от тяжёлой обороны, уходит лесами на юг и начинает поиск помощи Logan.",
		5,
		"leave_castle"
	)

	_add_mission_button(
		box,
		"Миссия 6А — Война королевств: поддержать Юг",
		"После гибели Kamorge Zeira проводит Bastion и Andrew к месту боя. Logan, Claire, Shion и Rahabor становятся союзниками.",
		6,
		"south"
	)
	_add_mission_button(
		box,
		"Миссия 6Б — Война королевств: поддержать Север",
		"Отряд поддерживает Alden, Devlin, Barlow и северные Ratatosk. Южное королевство становится противником.",
		6,
		"north"
	)

	details_label = Label.new()
	details_label.text = (
		"Награды: обычный ATAC — 25 монет, командир — 50, элитный ATAC — 75. "
		+ "За первое прохождение миссий: 200 / 300 / 500 / 800 / 1200 / 1500 монет. Все награды поступают в общий фонд команды. Повторные бои сохраняют награды за уничтоженные ATAC."
	)
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.add_theme_font_size_override("font_size", 18)
	box.add_child(details_label)

	var back: Button = Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(0, 50)
	back.pressed.connect(_go_back)
	box.add_child(back)
	print("MISSION_SELECT_OK buttons=%d scroll=true" % mission_button_count)


func _add_mission_button(parent: VBoxContainer, title: String, description: String, mission_id: int, forced_branch: String) -> void:
	mission_button_count += 1
	var button: Button = Button.new()
	button.text = "%s\n%s" % [title, description]
	button.custom_minimum_size = Vector2(0, 94)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func(): _launch_mission(mission_id, forced_branch))
	parent.add_child(button)


func _launch_mission(mission_id: int, forced_branch: String) -> void:
	CampaignState.prepare_mission_for_test(mission_id, forced_branch)
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _go_back() -> void:
	var target: String = CampaignState.mission_selector_return_scene
	if target.is_empty():
		target = "res://scenes/Main.tscn"
	get_tree().change_scene_to_file(target)
