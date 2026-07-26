extends Control

const BATTLE_SCENE: String = "res://scenes/BattlePrototype.tscn"

var wallet_label: Label
var details_label: Label


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.045, 0.075)
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040, 900)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "ВЫБОР МИССИИ — РЕЖИМ ТЕСТИРОВАНИЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "Пройденные задания можно запускать повторно. Для третьей и пятой миссий доступны отдельные сюжетные варианты."
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

	details_label = Label.new()
	details_label.text = (
		"Награды: обычный ATAC — 25 монет, командир — 50, элитный ATAC — 75. "
		+ "За первое прохождение миссий: 200 / 300 / 500 / 800 / 1200 монет. Все награды поступают в общий фонд команды. Повторные бои сохраняют награды за уничтоженные ATAC."
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


func _add_mission_button(parent: VBoxContainer, title: String, description: String, mission_id: int, forced_branch: String) -> void:
	var button: Button = Button.new()
	button.text = "%s\n%s" % [title, description]
	button.custom_minimum_size = Vector2(0, 105)
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
