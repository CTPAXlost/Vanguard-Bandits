extends Control

const PRISON_ART: String = "res://assets/story/imperial_prison.png"
const BASTION_PORTRAIT: String = "res://assets/ui/portraits/bastion.png"
const ANDREW_PORTRAIT: String = "res://assets/ui/portraits/andrew.png"
const KAMORGE_PORTRAIT: String = "res://assets/ui/portraits/kamorge.png"
const IONE_PORTRAIT: String = "res://assets/ui/portraits/ione.png"
const REYNA_PORTRAIT: String = "res://assets/ui/portraits/reyna.png"
const ZEIRA_PORTRAIT: String = "res://assets/ui/portraits/zeira.png"

var entries: Array[Dictionary] = []
var entry_index: int = 0
var speaker_label: Label
var text_label: Label
var portrait: TextureRect
var next_button: Button
var chapter_label: Label


func _ready() -> void:
	_build_interface()
	_build_story()
	_show_entry()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if CampaignState.story_branch == "stay_and_fight":
		_build_forest_background()
	else:
		var background: TextureRect = TextureRect.new()
		background.texture = load(PRISON_ART)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(background)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.035, 0.30)
	add_child(shade)

	chapter_label = Label.new()
	chapter_label.position = Vector2(38, 28)
	chapter_label.size = Vector2(920, 56)
	chapter_label.text = (
		"Глава IV — Лесной лагерь партизан"
		if CampaignState.story_branch == "stay_and_fight"
		else "Глава IV — Имперская тюрьма"
	)
	chapter_label.add_theme_font_size_override("font_size", 30)
	chapter_label.add_theme_color_override("font_color", Color(0.94, 0.81, 0.52))
	add_child(chapter_label)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 28.0
	panel.offset_right = -28.0
	panel.offset_top = -270.0
	panel.offset_bottom = -24.0
	add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(190, 190)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 27)
	speaker_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	right.add_child(speaker_label)
	text_label = Label.new()
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 21)
	right.add_child(text_label)
	next_button = Button.new()
	next_button.text = "Далее"
	next_button.custom_minimum_size = Vector2(170, 48)
	next_button.pressed.connect(_advance)
	right.add_child(next_button)


func _build_forest_background() -> void:
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.12, 0.085)
	add_child(background)
	for index: int in range(18):
		var tree: Polygon2D = Polygon2D.new()
		var x: float = float((index * 173) % 1280)
		var height: float = 260.0 + float((index * 47) % 260)
		tree.polygon = PackedVector2Array([
			Vector2(x - 78.0, 720.0),
			Vector2(x, 720.0 - height),
			Vector2(x + 78.0, 720.0),
		])
		tree.color = Color(0.02, 0.20 + float(index % 3) * 0.025, 0.12, 0.72)
		add_child(tree)
	var fire_glow: Polygon2D = Polygon2D.new()
	fire_glow.polygon = PackedVector2Array([
		Vector2(500, 720), Vector2(640, 450), Vector2(780, 720)
	])
	fire_glow.color = Color(0.72, 0.28, 0.08, 0.18)
	add_child(fire_glow)


func _build_story() -> void:
	if CampaignState.story_branch == "stay_and_fight":
		entries = [
			{
				"speaker": "Bastion",
				"portrait": BASTION_PORTRAIT,
				"text": "Отец сражался до конца. Faulkner не убил его одним ударом — они обменялись ударами как равные. Я всё равно не смог его спасти.",
			},
			{
				"speaker": "Zeira",
				"portrait": ZEIRA_PORTRAIT,
				"text": "Не превращай память о Kamorge в цепь. Он выиграл время, а мы использовали его, чтобы вывести вас с моста. В нашем лесу империя не диктует правила.",
			},
			{
				"speaker": "Ione",
				"portrait": IONE_PORTRAIT,
				"text": "Amphisia проверена, следы замаскированы. Имперский дозор не найдёт лагерь до рассвета. Здесь ты сможешь восстановить Alba.",
			},
			{
				"speaker": "Reyna",
				"portrait": REYNA_PORTRAIT,
				"text": "Haurol заморозил переправу за нами. Captain Soldiers потерял отряд, а Faulkner теперь знает: в лесу у Bastion появились союзники.",
			},
			{
				"speaker": "Andrew",
				"portrait": ANDREW_PORTRAIT,
				"text": "Ione, Reyna и Zeira спасли нас не ради благодарности. Им тоже нужна свободная земля. Отныне мы воюем вместе.",
			},
			{
				"speaker": "Bastion",
				"portrait": BASTION_PORTRAIT,
				"text": "Я запомню мост и последние слова отца. Но сначала мы защитим этот лагерь и подготовим удар по империи.",
			},
		]
	else:
		entries = [
			{
				"speaker": "Bastion",
				"portrait": BASTION_PORTRAIT,
				"text": "Мы продержались, сколько смогли. Никто не пришёл из леса, а имперские подкрепления сомкнули кольцо. Теперь мы в плену.",
			},
			{
				"speaker": "Andrew",
				"portrait": ANDREW_PORTRAIT,
				"text": "Ты послушал отца и дал ему шанс уйти. Kamorge отключил Barazaph и прыгнул в реку. Мы не знаем, куда его вынесло течение, но тела имперцы не нашли.",
			},
			{
				"speaker": "Bastion",
				"portrait": BASTION_PORTRAIT,
				"text": "Значит, он жив. Даже без ATAC отец найдёт путь. А мы найдём слабое место этой тюрьмы.",
			},
			{
				"speaker": "Andrew",
				"portrait": ANDREW_PORTRAIT,
				"text": "Сначала восстановим силы, изучим смену караула и дождёмся момента. Плен — не конец боя, а только новая позиция.",
			},
			{
				"speaker": "Kamorge — неизвестно где",
				"portrait": KAMORGE_PORTRAIT,
				"text": "Bastion... Barazaph потерян, но я ещё жив. Держись. Я найду другой путь к тебе.",
			},
		]


func _show_entry() -> void:
	if entry_index >= entries.size():
		CampaignState.mark_prison_seen()
		get_tree().change_scene_to_file("res://scenes/CampaignHub.tscn")
		return
	var entry: Dictionary = entries[entry_index]
	speaker_label.text = str(entry.get("speaker", ""))
	text_label.text = str(entry.get("text", ""))
	portrait.texture = load(str(entry.get("portrait", BASTION_PORTRAIT)))
	next_button.text = "В лагерь / продолжить" if entry_index == entries.size() - 1 else "Далее"


func _advance() -> void:
	entry_index += 1
	_show_entry()
