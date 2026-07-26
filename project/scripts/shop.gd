extends Control

var wallet_label: Label
var item_list: ItemList
var details_label: Label
var item_preview: TextureRect
var inventory_label: Label
var character_select: OptionButton
var equipment_label: Label
var message_label: Label
var item_ids: Array[String] = []
var character_ids: Array[String] = []
var selected_item_id: String = ""
var selected_character_id: String = ""


func _ready() -> void:
	_build_interface()
	_refresh_all()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.040, 0.070)
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 760)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	panel.add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title: Label = Label.new()
	title.text = "ОБЩИЙ МАГАЗИН ОТРЯДА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)
	wallet_label = Label.new()
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet_label.add_theme_font_size_override("font_size", 25)
	wallet_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	root.add_child(wallet_label)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	root.add_child(columns)

	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(510, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var stock_title: Label = Label.new()
	stock_title.text = "Товары и общий склад"
	stock_title.add_theme_font_size_override("font_size", 23)
	left.add_child(stock_title)
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.fixed_icon_size = Vector2i(68, 68)
	item_list.icon_mode = ItemList.ICON_MODE_LEFT
	item_list.item_selected.connect(_on_item_selected)
	left.add_child(item_list)
	var item_details_row: HBoxContainer = HBoxContainer.new()
	item_details_row.add_theme_constant_override("separation", 14)
	left.add_child(item_details_row)
	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(142, 142)
	item_details_row.add_child(preview_panel)
	var preview_margin: MarginContainer = MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_top", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 8)
	preview_panel.add_child(preview_margin)
	item_preview = TextureRect.new()
	item_preview.custom_minimum_size = Vector2(126, 126)
	item_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	item_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_margin.add_child(item_preview)
	details_label = Label.new()
	details_label.custom_minimum_size = Vector2(0, 142)
	details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_details_row.add_child(details_label)
	inventory_label = Label.new()
	left.add_child(inventory_label)
	var item_buttons: GridContainer = GridContainer.new()
	item_buttons.columns = 2
	left.add_child(item_buttons)
	_add_button(item_buttons, "Купить в общий склад", _buy_selected)
	_add_button(item_buttons, "Продать за 40%", _sell_selected)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var equip_title: Label = Label.new()
	equip_title.text = "Снаряжение персонажа"
	equip_title.add_theme_font_size_override("font_size", 23)
	right.add_child(equip_title)
	character_select = OptionButton.new()
	character_select.item_selected.connect(_on_character_selected)
	right.add_child(character_select)
	equipment_label = Label.new()
	equipment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(equipment_label)
	_add_button(right, "Экипировать выбранный предмет", _equip_selected)
	var unequip: GridContainer = GridContainer.new()
	unequip.columns = 3
	right.add_child(unequip)
	_add_button(unequip, "Снять меч", func(): _unequip("weapon"))
	_add_button(unequip, "Снять амулет", func(): _unequip("amulet"))
	_add_button(unequip, "Снять камень", func(): _unequip("stone"))
	var note: Label = Label.new()
	note.text = (
		"Монеты и склад общие для всей команды. Амулет единства даёт +1 к силе, ловкости, защите и умению атаки, "
		+ "не меняя уровень, HP и энергию. Опал усиливает «Яркую бомбу» на 10% и не подходит уникальным ATAC."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(message_label)
	_add_button(root, "Вернуться в лагерь", func(): get_tree().change_scene_to_file("res://scenes/CampaignHub.tscn"))


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _refresh_all() -> void:
	wallet_label.text = "Общий фонд команды: %d монет" % CampaignState.get_coin_balance()
	_refresh_items()
	_refresh_characters()
	_refresh_equipment()


func _refresh_items() -> void:
	var previous: String = selected_item_id
	item_list.clear()
	item_ids.clear()
	for item_id_value: Variant in CampaignState.SHOP_ITEMS.keys():
		var item_id: String = str(item_id_value)
		if not CampaignState.is_item_available(item_id) and CampaignState.get_inventory_count(item_id) <= 0:
			continue
		var data: Dictionary = CampaignState.SHOP_ITEMS[item_id] as Dictionary
		var owned: int = CampaignState.get_inventory_count(item_id)
		var buy_text: String = "%d монет" % int(data.get("price", 0)) if bool(data.get("buyable", true)) else "только продажа"
		var icon_path: String = str(data.get("icon", ""))
		var icon: Texture2D = (load(icon_path) as Texture2D) if not icon_path.is_empty() else null
		item_list.add_item("%s — %s • склад: %d" % [str(data.get("name", item_id)), buy_text, owned], icon)
		item_ids.append(item_id)
	if item_ids.is_empty():
		return
	var index: int = item_ids.find(previous)
	if index < 0:
		index = 0
	item_list.select(index)
	_on_item_selected(index)


func _refresh_characters() -> void:
	var previous: String = selected_character_id
	character_select.clear()
	character_ids = CampaignState.get_unlocked_character_ids()
	for character_id: String in character_ids:
		var data: Dictionary = CampaignState.get_character(character_id)
		character_select.add_item(str(data.get("name", character_id.capitalize())))
	if character_ids.is_empty():
		selected_character_id = ""
		return
	var index: int = character_ids.find(previous)
	if index < 0:
		index = 0
	character_select.select(index)
	selected_character_id = character_ids[index]


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= item_ids.size():
		return
	selected_item_id = item_ids[index]
	var data: Dictionary = CampaignState.SHOP_ITEMS[selected_item_id] as Dictionary
	var icon_path: String = str(data.get("icon", ""))
	item_preview.texture = (load(icon_path) as Texture2D) if not icon_path.is_empty() else null
	details_label.text = "%s\n\nЦена продажи: %d монет." % [str(data.get("description", "")), CampaignState.get_sell_price(selected_item_id)]
	inventory_label.text = "Свободно на общем складе: %d" % CampaignState.get_inventory_count(selected_item_id)


func _on_character_selected(index: int) -> void:
	if index < 0 or index >= character_ids.size():
		return
	selected_character_id = character_ids[index]
	_refresh_equipment()


func _refresh_equipment() -> void:
	if selected_character_id.is_empty():
		equipment_label.text = "Нет доступных персонажей."
		return
	var data: Dictionary = CampaignState.get_character(selected_character_id)
	var atac_id: String = CampaignState.character_atac(selected_character_id)
	equipment_label.text = (
		"%s • ATAC %s\n\nМеч: %s\nАмулет: %s\nКамень умения: %s"
		% [
			str(data.get("name", selected_character_id.capitalize())),
			str((CampaignState.ATAC_DATA.get(atac_id, {}) as Dictionary).get("name", atac_id.capitalize())),
			_item_name(CampaignState.equipped_item(selected_character_id, "weapon")),
			_item_name(CampaignState.equipped_item(selected_character_id, "amulet")),
			_item_name(CampaignState.equipped_item(selected_character_id, "stone")),
		]
	)


func _item_name(item_id: String) -> String:
	if item_id.is_empty():
		return "—"
	return str((CampaignState.SHOP_ITEMS.get(item_id, {}) as Dictionary).get("name", item_id))


func _buy_selected() -> void:
	_show_result(CampaignState.buy_item(selected_item_id))


func _sell_selected() -> void:
	_show_result(CampaignState.sell_item(selected_item_id))


func _equip_selected() -> void:
	_show_result(CampaignState.equip_item(selected_character_id, selected_item_id))


func _unequip(category: String) -> void:
	_show_result(CampaignState.unequip_item(selected_character_id, category))


func _show_result(result: Dictionary) -> void:
	message_label.text = str(result.get("message", ""))
	message_label.modulate = Color(0.48, 1.0, 0.60) if bool(result.get("ok", false)) else Color(1.0, 0.52, 0.44)
	_refresh_all()
