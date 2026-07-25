extends "res://scripts/campaign_battle.gd"

const CombatCatalog = preload("res://scripts/combat_catalog.gd")
const BattleArenaDirectorScript = preload("res://scripts/battle_arena_director.gd")
const MISSION_THREE_PATH: String = "res://data/maps/mission_03.json"
const MISSION_FOUR_PATH: String = "res://data/maps/mission_04.json"
const STORY_SCENE_PATH: String = "res://scenes/StoryChapter.tscn"
const FAULKNER_PORTRAIT: String = "res://assets/ui/portraits/faulkner.png"
const DUYERE_PORTRAIT: String = "res://assets/ui/portraits/duyere.png"
const CAPTAIN_PORTRAIT: String = "res://assets/ui/portraits/captain_soldiers.png"
const IONE_PORTRAIT: String = "res://assets/ui/portraits/ione.png"
const REYNA_PORTRAIT: String = "res://assets/ui/portraits/reyna.png"
const ZEIRA_PORTRAIT: String = "res://assets/ui/portraits/zeira.png"
const COUNTER_DODGE_FATIGUE: int = 4
const CAPTURE_SURVIVAL_ROUNDS: int = 3

signal facing_selected
signal story_choice_selected
signal upgrade_closed

var river_cells: Dictionary = {}
var player_party: Array[Node3D] = []
var player_turn_index: int = 0
var player_round_active: bool = false
var target_selection_active: bool = false
var pending_attack_mode: String = ""
var eligible_attack_targets: Array[Node3D] = []
var facing_menu: PanelContainer
var facing_choice_pending: bool = false
var counter_menu: PanelContainer
var counter_defender: Node3D
var reaction_defender: Node3D
var upgrade_panel: PanelContainer
var upgrade_character_id: String = ""
var upgrade_title: Label
var upgrade_points_label: Label
var upgrade_button: Button
var story_choice_panel: PanelContainer
var pending_story_choice: String = ""
var mission_three_intro_pending: bool = false
var faulkner_unit: Node3D
var duyere_unit: Node3D
var captain_unit: Node3D
var bridge_vanguard: Array[Node3D] = []
var dynamic_attack_buttons: Array[Button] = []
var target_highlight_root: Node3D
var mission_four_intro_pending: bool = false
var eigol_unit: Node3D
var branch_combat_mode: String = ""
var branch_combat_active: bool = false
var branch_rounds_elapsed: int = 0
var branch_resolution_started: bool = false
var ione_unit: Node3D
var reyna_unit: Node3D
var zeira_unit: Node3D
var battle_arena: BattleArenaDirector
var target_picker_panel: PanelContainer
var target_picker_box: VBoxContainer
var target_picker_index: int = 0
var target_picker_buttons: Array[Button] = []
var undo_move_button: Button
var move_undo_snapshot: Dictionary = {}


func _ready() -> void:
	mission_three_intro_pending = CampaignState.current_mission == 3
	mission_four_intro_pending = CampaignState.current_mission == 4
	_build_v08_interface()
	battle_arena = null
	super._ready()
	ability_button.visible = false
	defend_button.visible = false
	dodge_button.visible = false
	if mission_number == 3:
		action_in_progress = true
		phase = Phase.DIALOGUE
		_clear_highlights()
		await _play_mission_three_intro()
		mission_three_intro_pending = false
		return
	if mission_number == 4:
		action_in_progress = true
		phase = Phase.DIALOGUE
		_clear_highlights()
		await _play_mission_four_intro()
		mission_four_intro_pending = false
		action_in_progress = false
		_begin_player_turn()

func _build_v08_interface() -> void:
	var attack_vbox: VBoxContainer = $HUD/AttackMenu/Margin/VBox
	for node_name: String in ["Slash", "Lunge", "LongLunge", "BallLightning"]:
		var old_button: Button = attack_vbox.get_node_or_null(node_name) as Button
		if old_button != null:
			old_button.visible = false
	var dynamic_box: VBoxContainer = VBoxContainer.new()
	dynamic_box.name = "DynamicAttacks"
	dynamic_box.add_theme_constant_override("separation", 7)
	attack_vbox.add_child(dynamic_box)
	attack_vbox.move_child(dynamic_box, 1)

	var actions: GridContainer = $HUD/CommandPanel/Margin/VBox/Actions
	upgrade_button = Button.new()
	upgrade_button.text = "Прокачка"
	upgrade_button.custom_minimum_size = Vector2(150, 44)
	upgrade_button.visible = false
	upgrade_button.pressed.connect(_open_current_upgrade)
	actions.add_child(upgrade_button)

	undo_move_button = Button.new()
	undo_move_button.text = "↶ Отменить перемещение"
	undo_move_button.custom_minimum_size = Vector2(210, 44)
	undo_move_button.disabled = true
	undo_move_button.pressed.connect(_undo_last_move)
	actions.add_child(undo_move_button)

	facing_menu = _new_popup_panel(Vector2(430, 300), Vector2(440, 285), "Поверните ATAC стрелками клавиатуры")
	var facing_box: VBoxContainer = facing_menu.get_node("Margin/VBox") as VBoxContainer
	var directions: GridContainer = GridContainer.new()
	directions.columns = 2
	directions.add_theme_constant_override("h_separation", 8)
	directions.add_theme_constant_override("v_separation", 8)
	facing_box.add_child(directions)
	_add_popup_button(directions, "↑ Верх карты", func(): _choose_facing(Vector2i(0, -1)))
	_add_popup_button(directions, "→ Право карты", func(): _choose_facing(Vector2i(1, 0)))
	_add_popup_button(directions, "↓ Низ карты", func(): _choose_facing(Vector2i(0, 1)))
	_add_popup_button(directions, "← Лево карты", func(): _choose_facing(Vector2i(-1, 0)))

	counter_menu = _new_popup_panel(Vector2(860, 335), Vector2(390, 240), "Ответный удар — расход усталости ×2")
	var counter_box: VBoxContainer = counter_menu.get_node("Margin/VBox") as VBoxContainer
	_add_popup_button(counter_box, "Порез — 10 усталости", func(): _finish_reaction("counter_slash"))
	_add_popup_button(counter_box, "Выпад — 12 усталости", func(): _finish_reaction("counter_lunge"))
	_add_popup_button(counter_box, "Назад", func(): counter_menu.visible = false)

	upgrade_panel = _new_popup_panel(Vector2(520, 175), Vector2(560, 530), "Прокачка в бою")
	upgrade_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var upgrade_box: VBoxContainer = upgrade_panel.get_node("Margin/VBox") as VBoxContainer
	upgrade_title = upgrade_box.get_child(0) as Label
	upgrade_points_label = Label.new()
	upgrade_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_points_label.add_theme_font_size_override("font_size", 20)
	upgrade_box.add_child(upgrade_points_label)
	var stat_grid: GridContainer = GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 8)
	upgrade_box.add_child(stat_grid)
	_add_popup_button(stat_grid, "+ Сила", func(): _allocate_battle_stat("strength"))
	_add_popup_button(stat_grid, "+ Ловкость", func(): _allocate_battle_stat("agility"))
	_add_popup_button(stat_grid, "+ Защита", func(): _allocate_battle_stat("defense"))
	_add_popup_button(stat_grid, "+ Умение атаки", func(): _allocate_battle_stat("attack_skill"))
	_add_popup_button(upgrade_box, "Закрыть", _close_upgrade_panel)

	story_choice_panel = _new_popup_panel(Vector2(420, 210), Vector2(760, 430), "Решение Bastion")
	var choice_box: VBoxContainer = story_choice_panel.get_node("Margin/VBox") as VBoxContainer
	var choice_text: Label = Label.new()
	choice_text.text = (
		"Kamorge требует уйти за помощью в Южное королевство. "
		+ "Выбор изменит дальнейшее прохождение кампании."
	)
	choice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_text.add_theme_font_size_override("font_size", 19)
	choice_box.add_child(choice_text)
	_add_popup_button(choice_box, "Согласиться и попытаться уйти за помощью", func(): _finish_story_choice("seek_southern_aid"))
	_add_popup_button(choice_box, "Остаться и сражаться рядом с отцом", func(): _finish_story_choice("stay_and_fight"))

	reaction_ability_button.text = "Ответный удар..."
	target_picker_panel = _new_popup_panel(Vector2(470, 155), Vector2(620, 600), "Выберите противника")
	target_picker_box = target_picker_panel.get_node("Margin/VBox") as VBoxContainer
	var target_help: Label = Label.new()
	target_help.text = "↑/↓ или A/D — сменить цель • Enter — подтвердить • Esc — отменить"
	target_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_picker_box.add_child(target_help)
	target_highlight_root = Node3D.new()
	target_highlight_root.name = "TargetHighlights"
	add_child(target_highlight_root)


func _new_popup_panel(position: Vector2, size: Vector2, title: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.visible = false
	panel.z_index = 45
	panel.position = position
	panel.size = size
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title_label_popup: Label = Label.new()
	title_label_popup.text = title
	title_label_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label_popup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label_popup.add_theme_font_size_override("font_size", 22)
	box.add_child(title_label_popup)
	$HUD.add_child(panel)
	return panel


func _add_popup_button(parent: Control, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _load_first_mission() -> void:
	if CampaignState.current_mission == 4:
		mission_number = 4
		var parsed_four: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSION_FOUR_PATH))
		map_data = parsed_four as Dictionary if parsed_four is Dictionary else {"width": 17, "height": 14}
		grid_width = int(map_data.get("width", 17))
		grid_height = int(map_data.get("height", 14))
		blocked_cells = _cell_set(map_data.get("blocked_cells", []))
		river_cells = {}
		swamp_cells = {}
		title_label.text = str(map_data.get("name", "Ветка Kamorge"))
		var balance_four: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
		if balance_four is Dictionary:
			balance_data = balance_four as Dictionary
		return
	if CampaignState.current_mission != 3:
		super._load_first_mission()
		return
	mission_number = 3
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSION_THREE_PATH))
	map_data = parsed as Dictionary if parsed is Dictionary else {"width": 22, "height": 15}
	grid_width = int(map_data.get("width", 22))
	grid_height = int(map_data.get("height", 15))
	blocked_cells = _cell_set(map_data.get("blocked_cells", []))
	river_cells = _cell_set(map_data.get("river_cells", []))
	swamp_cells = {}
	title_label.text = str(map_data.get("name", "Третья миссия"))
	var balance_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if balance_parsed is Dictionary:
		balance_data = balance_parsed as Dictionary

func _build_map() -> void:
	super._build_map()
	_create_cell_overlay_multimesh(
		"RiverSurface",
		river_cells,
		0.07,
		0.045,
		Color(0.08, 0.34, 0.63, 0.88),
		0.19,
		Color(0.02, 0.10, 0.24)
	)


func _spawn_mission_units() -> void:
	if mission_number == 4:
		_spawn_mission_four_units()
		_setup_player_party()
		return
	if mission_number != 3:
		super._spawn_mission_units()
		_setup_player_party()
		return
	_spawn_mission_three_units()
	_setup_player_party()

func _spawn_character_unit(character_id: String, cell: Vector2i, player_controlled: bool, team: String) -> Node3D:
	var unit: Node3D = super._spawn_character_unit(character_id, cell, player_controlled, team)
	unit.set_meta("combat_profile", character_id)
	unit.set_meta("passive_ability", "")
	unit.set_meta("portrait_path", str(CampaignState.get_character(character_id).get("portrait", "")))
	unit.set_meta("facing_chosen", false)
	unit.set_meta("reaction_system", "defend_dodge_counter")
	if character_id == "bastion":
		unit.set_meta("passive_ability", "auto_reflect")
	elif character_id == "andrew":
		unit.set_meta("passive_ability", "auto_dodge_60")
	elif character_id == "zeira":
		unit.set_meta("passive_ability", "toreadore_rear_kick")
		unit.set_meta("max_move_actions", 2)
		unit.set_meta("energy_restore_uses", 3)
		unit.set_meta("rear_kick_multiplier", 2.0)
		unit.set_meta("rear_kick_distance", 5)
	else:
		unit.set_meta("max_move_actions", 1)
	return unit


func _spawn_enemy_from_data(enemy_data: Dictionary) -> Node3D:
	var unit: Node3D = super._spawn_enemy_from_data(enemy_data)
	unit.set_meta("combat_profile", "imperial_soldier")
	unit.set_meta("portrait_path", IMPERIAL_PORTRAIT)
	unit.set_meta("facing_chosen", true)
	unit.set_meta("reaction_system", "ai_defend_dodge")
	return unit


func _spawn_mission_three_units() -> void:
	player_unit = _spawn_character_unit("bastion", _array_to_cell(map_data.get("player_start", [15, 8])), true, "ally")
	andrew_unit = _spawn_character_unit("andrew", _array_to_cell(map_data.get("andrew_start", [16, 9])), true, "ally")
	andrew_unit.set_meta("role", "Союзный рыцарь • управляется игроком")
	kamorge_spawned = true
	kamorge_unit = _spawn_character_unit("kamorge", _array_to_cell(map_data.get("kamorge_start", [12, 7])), false, "ally")
	kamorge_unit.set_meta("role", "Отец Bastion • союзный ИИ")
	faulkner_unit = _spawn_named_villain(
		"Faulkner / Solarus",
		"Генерал восточной армии",
		"solarus",
		_array_to_cell(map_data.get("faulkner_cell", [8, 7])),
		"faulkner_solarus",
		"faulkner",
		FAULKNER_PORTRAIT
	)
	faulkner_unit.set_meta("passive_ability", "auto_reflect")
	duyere_unit = _spawn_named_villain(
		"Duyere / Sarbelas",
		"Принц Восточного королевства",
		"sarbelas",
		_array_to_cell(map_data.get("duyere_cell", [18, 12])),
		"duyere_sarbelas",
		"duyere",
		DUYERE_PORTRAIT
	)
	captain_unit = _spawn_named_villain(
		"Captain Soldiers / Einlager",
		"Капитан имперского отряда",
		"einlager",
		_array_to_cell(map_data.get("captain_cell", [19, 10])),
		"captain_einlager",
		"captain_soldiers",
		CAPTAIN_PORTRAIT
	)
	for enemy_value: Variant in map_data.get("faulkner_vanguard", []):
		var vanguard: Node3D = _spawn_enemy_from_data(enemy_value as Dictionary)
		vanguard.set_meta("scripted_bridge", true)
		bridge_vanguard.append(vanguard)
	for enemy_value: Variant in map_data.get("faulkner_troops", []):
		_spawn_enemy_from_data(enemy_value as Dictionary)
	for enemy_value: Variant in map_data.get("duyere_troops", []):
		_spawn_enemy_from_data(enemy_value as Dictionary)


func _spawn_mission_four_units() -> void:
	var start: Vector2i = _array_to_cell(map_data.get("eigol_cell", [5, 8]))
	player_unit = _spawn_unit(
		"Kamorge / Eigol",
		"Пустынный королевский генерал • управляется игроком",
		"eigol",
		start,
		true,
		false,
		"ally",
		"kamorge_eigol"
	)
	player_unit.set_meta("character_id", "kamorge")
	player_unit.set_meta("combat_profile", "kamorge_eigol")
	player_unit.set_meta("portrait_path", KAMORGE_PORTRAIT)
	player_unit.set_meta("model_slug", "eigol")
	player_unit.set_meta("magic_uses", 3)
	var stats: Dictionary = _stats(player_unit)
	stats["level"] = 20
	stats["max_hp"] = 501
	stats["hp"] = 501
	stats["strength"] = 35
	stats["agility"] = 24
	stats["defense"] = 31
	stats["attack_skill"] = 34
	stats["weapon_power"] = 18
	stats["max_energy"] = 100
	stats["energy"] = 100
	stats["move_range"] = 5
	stats["atac_name"] = "Eigol"
	stats["equipment"] = "Броня пустынного королевского генерала"
	player_unit.set_meta("stats", stats)
	eigol_unit = player_unit
	var visual: Node3D = player_unit.get_node_or_null("ATACVisual") as Node3D
	if visual != null:
		visual.visible = false
	for enemy_value: Variant in map_data.get("enemies", []):
		_spawn_enemy_from_data(enemy_value as Dictionary)
	_refresh_hp_bar(player_unit)


func _spawn_named_villain(label: String, role: String, slug: String, cell: Vector2i, profile: String, combat_profile: String, portrait_path: String) -> Node3D:
	var unit: Node3D = _spawn_unit(label, role, slug, cell, false, true, "enemy", profile)
	unit.set_meta("character_id", "")
	unit.set_meta("combat_profile", combat_profile)
	unit.set_meta("portrait_path", portrait_path)
	unit.set_meta("model_slug", slug)
	unit.set_meta("facing_chosen", true)
	return unit


func _setup_player_party() -> void:
	player_party.clear()
	if player_unit != null:
		player_party.append(player_unit)
	if mission_number >= 3 and andrew_unit != null and _is_alive(andrew_unit):
		andrew_unit.set_meta("player", true)
		player_party.append(andrew_unit)


func _begin_player_turn() -> void:
	if mission_three_intro_pending or mission_four_intro_pending:
		return
	var living_party: Array[Node3D] = []
	for member: Node3D in player_party:
		if _is_alive(member):
			living_party.append(member)
	player_party = living_party
	if player_party.is_empty():
		_show_defeat()
		return
	player_round_active = true
	player_turn_index = 0
	for member: Node3D in player_party:
		member.set_meta("round_done", false)
		member.set_meta("moved", false)
		member.set_meta("moves_taken", 0)
		member.set_meta("acted", false)
		member.set_meta("facing_chosen", false)
		_recover_fatigue(member, FATIGUE_RECOVERY)
		_recover_energy(member, 5)
		_tick_status_effects(member)
	_activate_player_member(player_party[0])


func _activate_player_member(member: Node3D) -> void:
	player_unit = member
	phase = Phase.PLAYER_MOVE
	action_in_progress = false
	target_selection_active = false
	pending_attack_mode = ""
	_close_attack_menu()
	_close_ability_menu()
	_select_unit(member)
	_show_reachable_cells(member, _available_move_range(member))
	phase_label.text = "ХОД ИГРОКА"
	phase_label.modulate = Color(0.42, 0.95, 1.0)
	var character_name: String = str(member.get_meta("label"))
	status_label.text = "%s: выберите зелёную клетку или действие." % character_name
	turn_info.text = "Раунд %d • герой %d/%d" % [round_number, player_turn_index + 1, player_party.size()]
	move_undo_snapshot = {}
	if undo_move_button != null:
		undo_move_button.disabled = true
	_refresh_ui()


func _end_player_turn() -> void:
	if action_in_progress and phase != Phase.ENEMY_TURN:
		return
	if player_unit != null and not bool(player_unit.get_meta("facing_chosen", false)):
		await _request_facing_choice(player_unit)
	_close_attack_menu()
	_close_ability_menu()
	_cancel_target_selection()
	_clear_highlights()
	player_unit.set_meta("round_done", true)
	var next_index: int = player_turn_index + 1
	while next_index < player_party.size() and not _is_alive(player_party[next_index]):
		next_index += 1
	if next_index < player_party.size():
		player_turn_index = next_index
		_activate_player_member(player_party[player_turn_index])
		return
	player_round_active = false
	await _run_ally_phase()


func _move_player_to(cell: Vector2i) -> void:
	if player_unit == null:
		return
	var max_moves: int = maxi(1, int(player_unit.get_meta("max_move_actions", 1)))
	var moves_taken: int = int(player_unit.get_meta("moves_taken", 0))
	if moves_taken >= max_moves:
		return
	move_undo_snapshot = {
		"unit": player_unit,
		"cell": player_unit.get_meta("cell"),
		"position": player_unit.position,
		"stats": (_stats(player_unit) as Dictionary).duplicate(true),
		"moves_taken": int(player_unit.get_meta("moves_taken", 0)),
		"moved": bool(player_unit.get_meta("moved", false)),
		"facing": player_unit.get_meta("facing", Vector2i(0, 1))
	}
	action_in_progress = true
	_cancel_target_selection()
	_close_attack_menu()
	_clear_highlights()
	var start: Vector2i = player_unit.get_meta("cell")
	var path: Array = _find_path(start, cell, player_unit)
	if path.is_empty() and start != cell:
		action_in_progress = false
		_show_reachable_cells(player_unit, _available_move_range(player_unit))
		return
	var fatigue_cost: int = path.size() * FATIGUE_MOVE_PER_CELL
	if not _can_spend_fatigue(player_unit, fatigue_cost):
		action_in_progress = false
		status_label.text = "Не хватает выносливости для этого маршрута."
		_show_reachable_cells(player_unit, _available_move_range(player_unit))
		return
	await _animate_path(player_unit, path, 0.22)
	_spend_fatigue(player_unit, fatigue_cost)
	moves_taken += 1
	player_unit.set_meta("moves_taken", moves_taken)
	player_unit.set_meta("moved", moves_taken >= max_moves)
	if moves_taken >= max_moves:
		phase = Phase.PLAYER_ACTION
		await _request_facing_choice(player_unit)
		status_label.text = "Направление выбрано. Выберите цель и действие."
	else:
		phase = Phase.PLAYER_MOVE
		status_label.text = (
			"Toreadore может переместиться ещё раз (до 15 клеток) или сразу атаковать."
		)
		_show_reachable_cells(player_unit, _available_move_range(player_unit))
	action_in_progress = false
	_select_unit(player_unit)
	if undo_move_button != null:
		undo_move_button.disabled = false
	phase_label.text = "ДЕЙСТВИЕ" if phase == Phase.PLAYER_ACTION else "ВТОРОЕ ПЕРЕМЕЩЕНИЕ"
	_refresh_ui()


func _request_facing_choice(unit: Node3D) -> void:
	if unit == null or not _is_alive(unit):
		return
	facing_choice_pending = true
	facing_menu.visible = true
	status_label.text = "Поверните ATAC стрелками: ↑ верх карты, ↓ низ, ← лево, → право. Это определит перед и спину."
	await facing_selected
	facing_choice_pending = false
	facing_menu.visible = false
	unit.set_meta("facing_chosen", true)


func _choose_facing(direction: Vector2i) -> void:
	if not facing_choice_pending or player_unit == null:
		return
	player_unit.set_meta("facing", direction)
	player_unit.rotation.y = atan2(float(direction.x), float(direction.y))
	facing_selected.emit()


func _handle_click(screen_position: Vector2) -> void:
	if target_selection_active:
		var clicked: Node3D = _unit_from_screen_position(screen_position)
		if clicked != null and eligible_attack_targets.has(clicked):
			_select_unit(clicked)
			target_selection_active = false
			_clear_target_highlights()
			await _request_player_attack(pending_attack_mode)
		else:
			status_label.text = "Выберите одну из подсвеченных целей."
		return
	await super._handle_click(screen_position)


func _unit_from_screen_position(screen_position: Vector2) -> Node3D:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return null
	var distance_to_plane: float = -origin.y / direction.y
	if distance_to_plane <= 0.0:
		return null
	var point: Vector3 = origin + direction * distance_to_plane
	var cell: Vector2i = Vector2i(roundi(point.x / TILE_SIZE), roundi(point.z / TILE_SIZE))
	return _unit_at(cell)


func _toggle_attack_menu() -> void:
	if attack_button.disabled:
		return
	_cancel_target_selection()
	attack_menu.visible = not attack_menu.visible
	if attack_menu.visible:
		_rebuild_dynamic_attack_menu()


func _rebuild_dynamic_attack_menu() -> void:
	var box: VBoxContainer = $HUD/AttackMenu/Margin/VBox/DynamicAttacks
	for child: Node in box.get_children():
		child.queue_free()
	dynamic_attack_buttons.clear()
	if player_unit == null:
		return
	for mode: String in CombatCatalog.attacks_for(player_unit):
		var data: Dictionary = CombatCatalog.attack(mode)
		var cost: Dictionary = CombatCatalog.resource_cost(mode)
		var cost_text: String = ""
		if int(cost.get("fatigue", 0)) > 0:
			cost_text = "%d усталости" % int(cost.get("fatigue", 0))
		elif int(cost.get("energy", 0)) > 0:
			cost_text = "%d энергии" % int(cost.get("energy", 0))
		var button: Button = Button.new()
		button.text = "%s — %s" % [str(data.get("label", mode)), cost_text]
		button.custom_minimum_size = Vector2(360, 40)
		button.disabled = not _can_use_attack(player_unit, mode)
		button.pressed.connect(_choose_attack_v08.bind(mode))
		box.add_child(button)
		dynamic_attack_buttons.append(button)
	if str(player_unit.get_meta("combat_profile", "")) == "zeira_toreadore":
		var magic_button: Button = Button.new()
		var uses: int = int(player_unit.get_meta("energy_restore_uses", 0))
		magic_button.text = "Магия: восстановить 50% энергии — %d/3" % uses
		magic_button.custom_minimum_size = Vector2(360, 40)
		var stats: Dictionary = _stats(player_unit)
		magic_button.disabled = uses <= 0 or int(stats.get("energy", 0)) >= int(stats.get("max_energy", 0))
		magic_button.pressed.connect(_use_toreadore_energy_magic)
		box.add_child(magic_button)
		dynamic_attack_buttons.append(magic_button)


func _unhandled_input(event: InputEvent) -> void:
	# В 1.6 обработчик выбора направления/цели перекрыл родительский
	# BattlePrototype._unhandled_input(). Из-за этого клики по клеткам, масштаб
	# колёсиком, фокус F и клики по целям вообще не доходили до поля боя.
	# Модальные режимы обрабатываем здесь, всё остальное обязательно передаём
	# базовому классу.
	if facing_choice_pending:
		if event.is_pressed() and not event.is_echo():
			if event.is_action_pressed("ui_up"):
				_choose_facing(Vector2i(0, -1))
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_down"):
				_choose_facing(Vector2i(0, 1))
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_left"):
				_choose_facing(Vector2i(-1, 0))
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_right"):
				_choose_facing(Vector2i(1, 0))
				get_viewport().set_input_as_handled()
		return

	if target_selection_active and not eligible_attack_targets.is_empty():
		if event.is_pressed() and not event.is_echo():
			var key_event: InputEventKey = event as InputEventKey
			var keycode: Key = key_event.keycode if key_event != null else KEY_NONE
			if event.is_action_pressed("ui_down") or keycode == KEY_D:
				target_picker_index = (target_picker_index + 1) % eligible_attack_targets.size()
				_refresh_target_picker_selection()
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("ui_up") or keycode == KEY_A:
				target_picker_index = (target_picker_index - 1 + eligible_attack_targets.size()) % eligible_attack_targets.size()
				_refresh_target_picker_selection()
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("ui_accept"):
				_confirm_target_picker(target_picker_index)
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("ui_cancel"):
				_cancel_target_selection()
				get_viewport().set_input_as_handled()
				return
		# Щелчок мышью должен пройти в базовый обработчик. Он вызовет
		# переопределённый _handle_click(), который подтвердит подсвеченную цель.
		super._unhandled_input(event)
		return

	# Обычный режим: движение по клеткам, выбор юнита, приближение камеры и F.
	super._unhandled_input(event)


func _open_target_picker() -> void:
	if target_picker_panel == null or target_picker_box == null:
		return
	for button: Button in target_picker_buttons:
		if is_instance_valid(button): button.queue_free()
	target_picker_buttons.clear()
	for index: int in range(eligible_attack_targets.size()):
		var target: Node3D = eligible_attack_targets[index]
		var stats: Dictionary = _stats(target)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.text = "%d. %s   HP %d/%d   • %d клеток" % [index + 1, str(target.get_meta("label")), int(stats.get("hp", 0)), int(stats.get("max_hp", 0)), _grid_distance(player_unit, target)]
		button.pressed.connect(_confirm_target_picker.bind(index))
		target_picker_box.add_child(button)
		target_picker_buttons.append(button)
	target_picker_panel.visible = true
	_refresh_target_picker_selection()


func _refresh_target_picker_selection() -> void:
	for index: int in range(target_picker_buttons.size()):
		var selected_now: bool = index == target_picker_index
		target_picker_buttons[index].modulate = Color(1.0, 0.88, 0.42) if selected_now else Color.WHITE
	if target_picker_index >= 0 and target_picker_index < eligible_attack_targets.size():
		_select_unit(eligible_attack_targets[target_picker_index])


func _confirm_target_picker(index: int) -> void:
	if not target_selection_active or index < 0 or index >= eligible_attack_targets.size():
		return
	var target: Node3D = eligible_attack_targets[index]
	_select_unit(target)
	target_selection_active = false
	if target_picker_panel != null: target_picker_panel.visible = false
	_clear_target_highlights()
	await _request_player_attack(pending_attack_mode)


func _undo_last_move() -> void:
	if move_undo_snapshot.is_empty() or action_in_progress or target_selection_active:
		return
	var unit: Node3D = move_undo_snapshot.get("unit") as Node3D
	if unit == null or unit != player_unit or bool(unit.get_meta("acted", false)):
		return
	action_in_progress = true
	_close_attack_menu()
	_clear_highlights()
	unit.set_meta("cell", move_undo_snapshot.get("cell"))
	unit.position = move_undo_snapshot.get("position")
	unit.set_meta("stats", (move_undo_snapshot.get("stats") as Dictionary).duplicate(true))
	unit.set_meta("moves_taken", int(move_undo_snapshot.get("moves_taken", 0)))
	unit.set_meta("moved", bool(move_undo_snapshot.get("moved", false)))
	unit.set_meta("facing", move_undo_snapshot.get("facing", Vector2i(0, 1)))
	unit.set_meta("facing_chosen", false)
	var facing: Vector2i = unit.get_meta("facing")
	unit.rotation.y = atan2(float(facing.x), float(facing.y))
	move_undo_snapshot = {}
	if undo_move_button != null: undo_move_button.disabled = true
	phase = Phase.PLAYER_MOVE
	action_in_progress = false
	_select_unit(unit)
	_show_reachable_cells(unit, _available_move_range(unit))
	status_label.text = "Перемещение отменено. Выберите другую клетку."
	_refresh_ui()


func _use_toreadore_energy_magic() -> void:
	if player_unit == null or action_in_progress:
		return
	var uses: int = int(player_unit.get_meta("energy_restore_uses", 0))
	if uses <= 0:
		status_label.text = "Магия Toreadore уже использована три раза за бой."
		return
	var stats: Dictionary = _stats(player_unit)
	var maximum: int = int(stats.get("max_energy", 0))
	var restored: int = maxi(1, int(float(maximum) * 0.50))
	stats["energy"] = mini(maximum, int(stats.get("energy", 0)) + restored)
	player_unit.set_meta("stats", stats)
	player_unit.set_meta("energy_restore_uses", uses - 1)
	_close_attack_menu()
	_spawn_arrival_effect(player_unit.global_position + Vector3(0, 1.0, 0))
	status_label.text = "Zeira восстанавливает 50% энергии Toreadore. Осталось применений: %d." % (uses - 1)
	player_unit.set_meta("acted", true)
	_refresh_ui()
	await get_tree().create_timer(0.35).timeout
	await _end_player_turn()


func _choose_attack_v08(mode: String) -> void:
	_close_attack_menu()
	pending_attack_mode = mode
	eligible_attack_targets = _eligible_targets(player_unit, mode)
	if eligible_attack_targets.is_empty():
		status_label.text = "Для «%s» нет доступной цели." % str(CombatCatalog.attack(mode).get("label", mode))
		return
	target_selection_active = true
	target_picker_index = 0
	_show_attack_targets(eligible_attack_targets)
	_open_target_picker()
	status_label.text = "Выберите цель для «%s»: используйте список или ↑/↓ и Enter." % str(CombatCatalog.attack(mode).get("label", mode))


func _cancel_target_selection() -> void:
	if target_picker_panel != null:
		target_picker_panel.visible = false
	target_selection_active = false
	pending_attack_mode = ""
	eligible_attack_targets.clear()
	_clear_target_highlights()


func _show_attack_targets(targets: Array[Node3D]) -> void:
	_clear_target_highlights()
	for target: Node3D in targets:
		var ring: MeshInstance3D = MeshInstance3D.new()
		var mesh: TorusMesh = TorusMesh.new()
		mesh.inner_radius = 0.53
		mesh.outer_radius = 0.64
		mesh.rings = 32
		mesh.ring_segments = 8
		ring.mesh = mesh
		ring.rotation_degrees.x = 90.0
		ring.position = target.position + Vector3(0, 0.08, 0)
		ring.material_override = _highlight_material(Color(1.0, 0.14, 0.08, 0.82))
		target_highlight_root.add_child(ring)


func _clear_target_highlights() -> void:
	if target_highlight_root == null:
		return
	for child: Node in target_highlight_root.get_children():
		child.queue_free()


func _eligible_targets(attacker: Node3D, mode: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var data: Dictionary = CombatCatalog.attack(mode)
	var required_range: int = int(data.get("range", 1))
	var enemy_team: String = "enemy" if str(attacker.get_meta("team")) == "ally" else "ally"
	for unit: Node3D in units:
		if str(unit.get_meta("team")) != enemy_team or not _is_alive(unit):
			continue
		var distance: int = _grid_distance(attacker, unit)
		var range_mode: String = str(data.get("range_mode", "exact"))
		if mode == "quicksand" or range_mode == "up_to":
			if distance < 1 or distance > required_range:
				continue
		elif distance != required_range:
			continue
		if mode in ["long_lunge", "bright_bomb"] and required_range == 2:
			if not _has_clear_long_lunge_line(attacker, unit):
				continue
		result.append(unit)
	return result


func _player_attack_target(mode: String = "slash") -> Node3D:
	if selected_unit == null or not _is_alive(selected_unit):
		return null
	if str(selected_unit.get_meta("team")) != "enemy":
		return null
	return selected_unit if _eligible_targets(player_unit, mode).has(selected_unit) else null


func _can_use_attack(unit: Node3D, mode: String, counterattack: bool = false) -> bool:
	if mode == "quicksand" and int(unit.get_meta("magic_uses", 0)) <= 0:
		return false
	var costs: Dictionary = CombatCatalog.resource_cost(mode, counterattack)
	if not _can_spend_fatigue(unit, int(costs.get("fatigue", 0))):
		return false
	if not _can_spend_energy(unit, int(costs.get("energy", 0))):
		return false
	return not _eligible_targets(unit, mode).is_empty()


func _request_player_attack(mode: String) -> void:
	if action_in_progress or phase not in [Phase.PLAYER_MOVE, Phase.PLAYER_ACTION]:
		return
	var target: Node3D = _player_attack_target(mode)
	if target == null:
		status_label.text = "Сначала выберите цель для атаки."
		return
	if not _can_use_attack(player_unit, mode):
		status_label.text = "Не хватает усталости или энергии."
		return
	action_in_progress = true
	_cancel_target_selection()
	_close_attack_menu()
	_clear_highlights()
	var costs: Dictionary = CombatCatalog.resource_cost(mode)
	_spend_fatigue(player_unit, int(costs.get("fatigue", 0)))
	_spend_energy(player_unit, int(costs.get("energy", 0)))
	if mode == "quicksand":
		player_unit.set_meta("magic_uses", maxi(0, int(player_unit.get_meta("magic_uses", 0)) - 1))
	await _play_attack_animation(player_unit, target, mode)
	await _resolve_attack(player_unit, target, mode)
	player_unit.set_meta("acted", true)
	action_in_progress = false
	if _all_enemies_defeated():
		_show_victory()
		return
	await _end_player_turn()


func _update_attack_menu_buttons() -> void:
	if attack_menu.visible:
		_rebuild_dynamic_attack_menu()


func _open_reaction_ability() -> void:
	if not reaction_waiting or reaction_back_attack or reaction_defender == null:
		status_label.text = "Ответный удар невозможен при атаке со спины."
		return
	counter_defender = reaction_defender
	var slash_cost: Dictionary = CombatCatalog.resource_cost("slash", true)
	var lunge_cost: Dictionary = CombatCatalog.resource_cost("lunge", true)
	var buttons: Array[Node] = (counter_menu.get_node("Margin/VBox") as VBoxContainer).get_children()
	if buttons.size() >= 4:
		(buttons[1] as Button).disabled = not _can_spend_fatigue(counter_defender, int(slash_cost.get("fatigue", 10)))
		(buttons[2] as Button).disabled = not _can_spend_fatigue(counter_defender, int(lunge_cost.get("fatigue", 12)))
	counter_menu.visible = true


func _request_player_reaction(attacker: Node3D, back_attack: bool) -> String:
	reaction_waiting = true
	reaction_back_attack = back_attack
	reaction_defender = _pending_reaction_target()
	reaction_menu.visible = true
	counter_menu.visible = false
	reaction_title.text = "%s атакует%s" % [str(attacker.get_meta("label")), " со спины" if back_attack else ""]
	reaction_defend_button.disabled = back_attack
	reaction_ability_button.disabled = back_attack
	reaction_ability_button.text = "Ответный удар..." if not back_attack else "Ответный удар со спины невозможен"
	reaction_dodge_button.disabled = reaction_defender == null or not _can_spend_fatigue(reaction_defender, COUNTER_DODGE_FATIGUE)
	status_label.text = "Выберите реакцию. Со спины доступны только уклонение или принятие удара."
	await reaction_chosen
	var choice: String = pending_reaction_choice
	reaction_waiting = false
	reaction_menu.visible = false
	counter_menu.visible = false
	if choice == "dodge" and reaction_defender != null:
		_spend_fatigue(reaction_defender, COUNTER_DODGE_FATIGUE)
	elif choice == "counter_slash" and reaction_defender != null:
		_spend_fatigue(reaction_defender, int(CombatCatalog.resource_cost("slash", true).get("fatigue", 10)))
	elif choice == "counter_lunge" and reaction_defender != null:
		_spend_fatigue(reaction_defender, int(CombatCatalog.resource_cost("lunge", true).get("fatigue", 12)))
	return choice


func _pending_reaction_target() -> Node3D:
	for member: Node3D in player_party:
		if member == selected_unit and _is_alive(member):
			return member
	return player_unit


func _resolve_attack(attacker: Node3D, target: Node3D, mode: String) -> void:
	if not _is_alive(target):
		return
	var miss_chance: float = float(attacker.get_meta("miss_chance", 0.0))
	if miss_chance > 0.0 and rng.randf() <= miss_chance:
		status_label.text = "%s промахивается из-за песка!" % str(attacker.get_meta("label"))
		await _animate_miss(attacker)
		return
	if mode == "quicksand":
		_apply_sand_status(target, 3, 2, 0.18)
		status_label.text = "%s погружается в зыбучие пески на 3 хода." % str(target.get_meta("label"))
		return
	var back_attack: bool = _is_back_attack(attacker, target)
	var passive_result: String = await _try_automatic_passive(target, attacker, back_attack)
	if passive_result == "avoided" or passive_result == "reflected":
		return
	var reaction: String = "none"
	if bool(target.get_meta("player", false)):
		selected_unit = target
		reaction = await _request_player_reaction(attacker, back_attack)
	else:
		reaction = _choose_ai_reaction(target, attacker, back_attack)
	if reaction == "dodge":
		var evade_chance: float = _evasion_chance(target, attacker)
		if rng.randf() <= evade_chance:
			status_label.text = "%s уклоняется!" % str(target.get_meta("label"))
			await _animate_dodge(target)
			return
	var attack_data: Dictionary = CombatCatalog.attack(mode)
	var multiplier: float = float(attack_data.get("multiplier", 1.0))
	var damage: int = _calculate_damage(attacker, target, multiplier)
	if reaction == "defend" and not back_attack:
		damage = maxi(1, int(float(damage) * 0.55))
		await _animate_ai_guard(target)
	await _damage_target(target, damage)
	if mode == "desert_whirl" and _is_alive(target):
		_apply_sand_status(target, 3, 2, 0.28)
	elif mode == "ice_rain" and _is_alive(target):
		var freeze_chance: float = float(attack_data.get("freeze_chance", 0.30))
		if rng.randf() <= freeze_chance:
			var freeze_turns: int = int(attack_data.get("freeze_turns", 2))
			target.set_meta("frozen_turns", maxi(int(target.get_meta("frozen_turns", 0)), freeze_turns))
			status_label.text = "%s заморожен на %d хода!" % [str(target.get_meta("label")), freeze_turns]
			_spawn_ice_lock_effect(target.global_position + Vector3(0, 1.0, 0))
	elif mode == "ultrasound" and _is_alive(target):
		target.set_meta("disoriented_turns", int(attack_data.get("disorient_turns", 2)))
		target.set_meta("friendly_fire_chance", float(attack_data.get("friendly_fire_chance", 0.50)))
		status_label.text = "%s дезориентирован: 50%% шанс ударить своего." % str(target.get_meta("label"))
	if mode == "slide":
		await _complete_slide_pass_through(attacker, target)
	if reaction in ["counter_slash", "counter_lunge"] and _is_alive(target) and not back_attack:
		var counter_mode: String = "slash" if reaction == "counter_slash" else "lunge"
		status_label.text = "%s отвечает атакой!" % str(target.get_meta("label"))
		await _play_attack_animation(target, attacker, counter_mode)
		var counter_damage: int = _calculate_damage(target, attacker, float(CombatCatalog.attack(counter_mode).get("multiplier", 1.0)) * 0.82)
		await _damage_target(attacker, counter_damage)
	if bool(attack_data.get("knockback", false)) and _is_alive(target):
		await _attempt_knockback(attacker, target)


func _try_automatic_passive(defender: Node3D, attacker: Node3D, back_attack: bool) -> String:
	var passive: String = str(defender.get_meta("passive_ability", ""))
	if passive == "toreadore_rear_kick" and back_attack:
		status_label.text = "Toreadore автоматически отвечает задними копытами!"
		await _animate_rear_kick(defender, attacker)
		var multiplier: float = float(defender.get_meta("rear_kick_multiplier", 2.0))
		var kick_damage: int = _calculate_damage(defender, attacker, multiplier)
		await _damage_target(attacker, kick_damage)
		if _is_alive(attacker):
			await _attempt_knockback_distance(defender, attacker, int(defender.get_meta("rear_kick_distance", 5)))
		return "reflected"
	if passive == "auto_reflect" and not back_attack:
		var chance: float = _reflection_chance(defender, attacker)
		if rng.randf() <= chance:
			status_label.text = "%s автоматически отражает атаку!" % str(defender.get_meta("label"))
			await _animate_reflect(defender, attacker)
			await _damage_target(attacker, maxi(1, _calculate_damage(defender, attacker, 0.70)))
			return "reflected"
	if passive == "auto_dodge_60":
		var chance_dodge: float = 0.60
		if rng.randf() <= chance_dodge:
			status_label.text = "%s автоматически уходит от удара!" % str(defender.get_meta("label"))
			await _animate_dodge(defender)
			return "avoided"
	return "none"


func _choose_ai_reaction(defender: Node3D, attacker: Node3D, back_attack: bool) -> String:
	var agility_delta: int = _effective_stat(_stats(defender), "agility") - _effective_stat(_stats(attacker), "agility")
	var dodge_chance: float = clampf(0.18 + float(agility_delta) * 0.018, 0.08, 0.56)
	if rng.randf() <= dodge_chance:
		return "dodge"
	if back_attack:
		return "none"
	var defense_value: int = _effective_stat(_stats(defender), "defense")
	var defend_chance: float = clampf(0.18 + float(defense_value) * 0.008, 0.18, 0.48)
	return "defend" if rng.randf() <= defend_chance else "none"


func _animate_ai_guard(unit: Node3D) -> void:
	_spawn_guard_effect(unit.global_position + Vector3(0, 1.1, 0))
	var visual: Node3D = unit.get_node_or_null("ATACVisual") as Node3D
	if visual != null:
		var start_scale: Vector3 = visual.scale
		var tween: Tween = create_tween()
		tween.tween_property(visual, "scale", start_scale * Vector3(1.08, 0.94, 1.08), 0.12)
		tween.tween_property(visual, "scale", start_scale, 0.16)
		await tween.finished


func _run_ally_phase() -> void:
	var allies: Array[Node3D] = []
	for unit: Node3D in units:
		if not _is_alive(unit) or str(unit.get_meta("team")) != "ally":
			continue
		if bool(unit.get_meta("player", false)):
			continue
		allies.append(unit)
	if allies.is_empty() or _all_enemies_defeated():
		await _run_enemy_phase()
		return
	phase = Phase.ALLY_TURN
	phase_label.text = "ХОД СОЮЗНИКОВ"
	phase_label.modulate = Color(0.55, 1.0, 0.64)
	action_in_progress = true
	for ally: Node3D in allies:
		if _all_enemies_defeated():
			break
		_recover_fatigue(ally, FATIGUE_RECOVERY)
		_recover_energy(ally, 10)
		_tick_status_effects(ally)
		await _run_smart_ai_turn(ally)
	action_in_progress = false
	if _all_enemies_defeated():
		_show_victory()
		return
	await _run_enemy_phase()


func _run_enemy_phase() -> void:
	action_in_progress = true
	phase = Phase.ENEMY_TURN
	phase_label.text = "ХОД ПРОТИВНИКА"
	phase_label.modulate = Color(1.0, 0.45, 0.38)
	var enemy_index: int = 0
	for enemy: Node3D in units:
		if str(enemy.get_meta("team")) != "enemy" or not _is_alive(enemy):
			continue
		enemy_index += 1
		_recover_fatigue(enemy, FATIGUE_RECOVERY)
		_recover_energy(enemy, 10)
		_tick_status_effects(enemy)
		turn_info.text = "Раунд %d • враг %d" % [round_number, enemy_index]
		var frozen_turns: int = int(enemy.get_meta("frozen_turns", 0))
		if frozen_turns > 0:
			enemy.set_meta("frozen_turns", frozen_turns - 1)
			status_label.text = "%s скован льдом и пропускает ход." % str(enemy.get_meta("label"))
			await _animate_frozen_skip(enemy)
			continue
		var disoriented_turns: int = int(enemy.get_meta("disoriented_turns", 0))
		if disoriented_turns > 0:
			enemy.set_meta("disoriented_turns", disoriented_turns - 1)
			if await _try_disoriented_friendly_fire(enemy):
				continue
		if await _try_faulkner_heal(enemy):
			continue
		await _run_smart_ai_turn(enemy)
		if _living_player_members().is_empty():
			break
	if _living_player_members().is_empty():
		action_in_progress = false
		_show_defeat()
		return
	if branch_combat_active and branch_combat_mode == "capture_no_help":
		branch_rounds_elapsed += 1
		if branch_rounds_elapsed >= CAPTURE_SURVIVAL_ROUNDS or _all_enemies_defeated():
			action_in_progress = false
			await _play_forced_capture_outro()
			return
	if _all_enemies_defeated():
		action_in_progress = false
		_show_victory()
		return
	round_number += 1
	action_in_progress = false
	_begin_player_turn()


func _run_smart_ai_turn(unit: Node3D) -> void:
	_select_unit(unit)
	status_label.text = "%s оценивает поле боя." % str(unit.get_meta("label"))
	await get_tree().create_timer(0.12).timeout
	var target: Node3D = _nearest_opponent(unit)
	if target == null:
		return
	var chosen_mode: String = _choose_ai_attack(unit, target)
	var data: Dictionary = CombatCatalog.attack(chosen_mode)
	var desired_range: int = int(data.get("range", 1))
	var distance: int = _grid_distance(unit, target)
	if distance > desired_range:
		var goals: Array = _ai_attack_cells(target, unit, chosen_mode)
		var unit_cell: Vector2i = unit.get_meta("cell")
		var path: Array = _find_path_to_any(unit_cell, goals, unit)
		# A signature ranged attack may have no exact firing tile because an ally
		# blocks it. In that case the bot still advances toward a normal melee tile
		# instead of spending the whole battle in place.
		if path.is_empty():
			path = _find_path_to_any(unit_cell, _free_adjacent_cells(target, unit), unit)
		var steps: int = mini(_available_move_range(unit), path.size())
		if steps > 0:
			var partial: Array = path.slice(0, steps)
			await _animate_path(unit, partial, 0.18)
			_spend_fatigue(unit, partial.size() * FATIGUE_MOVE_PER_CELL)

	# Re-evaluate after movement: another opponent may now be the valid target.
	target = _nearest_opponent(unit)
	if target == null:
		return
	chosen_mode = _choose_ai_attack(unit, target)
	var attack_target: Node3D = _best_ai_target_for_mode(unit, chosen_mode)
	if attack_target == null:
		chosen_mode = "slash"
		attack_target = _best_ai_target_for_mode(unit, chosen_mode)
	if attack_target != null and _can_use_attack(unit, chosen_mode):
		var costs: Dictionary = CombatCatalog.resource_cost(chosen_mode)
		_spend_fatigue(unit, int(costs.get("fatigue", 0)))
		_spend_energy(unit, int(costs.get("energy", 0)))
		if chosen_mode == "quicksand":
			unit.set_meta("magic_uses", maxi(0, int(unit.get_meta("magic_uses", 0)) - 1))
		await _play_attack_animation(unit, attack_target, chosen_mode)
		await _resolve_attack(unit, attack_target, chosen_mode)
	else:
		_face_target(unit, target)
		status_label.text = "%s продвигается к врагу и занимает защитную позицию." % str(unit.get_meta("label"))
		await _animate_ai_guard(unit)


func _ai_attack_cells(target: Node3D, moving_unit: Node3D, mode: String) -> Array:
	var data: Dictionary = CombatCatalog.attack(mode)
	var maximum_range: int = maxi(1, int(data.get("range", 1)))
	var range_mode: String = str(data.get("range_mode", "exact"))
	var result: Array = []
	var first_range: int = 1 if range_mode == "up_to" else maximum_range
	for attack_range: int in range(first_range, maximum_range + 1):
		for cell: Variant in _cells_at_attack_range(target, moving_unit, attack_range):
			if not result.has(cell):
				result.append(cell)
	return result


func _best_ai_target_for_mode(unit: Node3D, mode: String) -> Node3D:
	var candidates: Array[Node3D] = _eligible_targets(unit, mode)
	var best: Node3D
	var best_distance: int = 9999
	for candidate: Node3D in candidates:
		var distance: int = _grid_distance(unit, candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _nearest_opponent(unit: Node3D) -> Node3D:
	var desired_team: String = "enemy" if str(unit.get_meta("team")) == "ally" else "ally"
	var start: Vector2i = unit.get_meta("cell")
	var reachable_best: Node3D = null
	var reachable_path_length: int = 999999
	var geometric_best: Node3D = null
	var geometric_distance: int = 999999
	for candidate: Node3D in units:
		if str(candidate.get_meta("team")) != desired_team or not _is_alive(candidate):
			continue
		var distance: int = _grid_distance(unit, candidate)
		if distance < geometric_distance:
			geometric_best = candidate
			geometric_distance = distance
		if distance <= 1:
			return candidate
		var goals: Array = _free_adjacent_cells(candidate, unit)
		if goals.is_empty():
			continue
		var path: Array = _find_path_to_any(start, goals, unit)
		if not path.is_empty() and path.size() < reachable_path_length:
			reachable_best = candidate
			reachable_path_length = path.size()
	# Prefer the opponent that can actually be reached through the castle gate.
	# Falling back to geometric distance still gives the AI a direction when every
	# adjacent tile is temporarily occupied by another unit.
	return reachable_best if reachable_best != null else geometric_best


func _choose_ai_attack(unit: Node3D, target: Node3D) -> String:
	var modes: Array[String] = CombatCatalog.attacks_for(unit)
	var distance: int = _grid_distance(unit, target)
	# Боссы и уникальные ATAC предпочитают фирменные приёмы, если хватает ресурсов.
	for preferred: String in ["slide", "ice_rain", "ultrasound", "spear_throw", "quicksand", "desert_whirl", "bright_bomb", "earthquake", "tornado", "strong_slash", "ball_lightning", "long_lunge", "lunge", "slash"]:
		if not modes.has(preferred):
			continue
		var data: Dictionary = CombatCatalog.attack(preferred)
		var attack_range: int = int(data.get("range", 1))
		var range_mode: String = str(data.get("range_mode", "exact"))
		if range_mode == "up_to":
			if distance < 1 or distance > attack_range:
				continue
		elif attack_range != distance:
			continue
		var costs: Dictionary = CombatCatalog.resource_cost(preferred)
		if _can_spend_fatigue(unit, int(costs.get("fatigue", 0))) and _can_spend_energy(unit, int(costs.get("energy", 0))):
			return preferred
	return "slash"


func _cells_at_attack_range(target: Node3D, moving_unit: Node3D, attack_range: int) -> Array:
	var cells: Array = []
	var target_cell: Vector2i = target.get_meta("cell")
	for x_offset: int in range(-attack_range, attack_range + 1):
		for z_offset: int in range(-attack_range, attack_range + 1):
			if abs(x_offset) + abs(z_offset) != attack_range:
				continue
			var cell: Vector2i = target_cell + Vector2i(x_offset, z_offset)
			var moving_cell: Vector2i = moving_unit.get_meta("cell")
			if _can_enter(cell, moving_unit, moving_cell):
				cells.append(cell)
	return cells


func _try_faulkner_heal(unit: Node3D) -> bool:
	if str(unit.get_meta("combat_profile", "")) != "faulkner":
		return false
	var stats: Dictionary = _stats(unit)
	var remaining: int = int(stats.get("heals_remaining", 0))
	if remaining <= 0 or int(stats.get("hp", 0)) > int(float(stats.get("max_hp", 1)) * 0.48):
		return false
	var heal: int = int(float(stats.get("max_hp", 1)) * 0.45)
	stats["hp"] = mini(int(stats.get("max_hp", 1)), int(stats.get("hp", 0)) + heal)
	stats["heals_remaining"] = remaining - 1
	unit.set_meta("stats", stats)
	_refresh_hp_bar(unit)
	status_label.text = "Faulkner применяет восстановительную магию: +%d HP (%d/3)." % [heal, 4 - remaining]
	_spawn_heal_effect(unit.global_position + Vector3(0, 1.2, 0))
	await get_tree().create_timer(0.65).timeout
	return true


func _spawn_heal_effect(position: Vector3) -> void:
	for index: int in range(5):
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.22 + index * 0.07
		torus.outer_radius = 0.25 + index * 0.07
		ring.mesh = torus
		ring.position = position
		ring.rotation_degrees = Vector3(90, index * 28, 0)
		ring.material_override = _effect_material(Color(0.35, 1.0, 0.62, 0.85))
		add_child(ring)
		var tween: Tween = create_tween()
		ring.scale = Vector3.ZERO
		tween.tween_property(ring, "scale", Vector3.ONE * 1.5, 0.45)
		tween.parallel().tween_property(ring, "position:y", position.y + 1.3, 0.55)
		tween.tween_property(ring, "scale", Vector3.ZERO, 0.18)
		tween.tween_callback(Callable(ring, "queue_free"))


func _living_player_members() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for member: Node3D in player_party:
		if _is_alive(member):
			result.append(member)
	return result


func _play_attack_animation(attacker: Node3D, target: Node3D, mode: String) -> void:
	match mode:
		"lunge":
			await _animate_lunge(attacker, target)
		"long_lunge":
			await _animate_long_lunge(attacker, target)
		"strong_slash":
			await _animate_strong_slash(attacker, target)
		"shoulder_bash":
			await _animate_shoulder_bash(attacker, target)
		"tornado":
			await _animate_tornado(attacker, target)
		"ball_lightning":
			await _animate_ball_lightning(attacker, target)
		"bright_bomb":
			await _animate_bright_bomb(attacker, target)
		"earthquake":
			await _animate_earthquake(attacker, target)
		"desert_whirl":
			await _animate_desert_whirl(attacker, target)
		"quicksand":
			await _animate_quicksand(attacker, target)
		"spear_throw":
			await _animate_spear_throw(attacker, target)
		"ice_rain":
			await _animate_ice_rain(attacker, target)
		"ultrasound":
			await _animate_ultrasound(attacker, target)
		"slide":
			await _animate_slide(attacker, target)
		_:
			await _animate_slash(attacker, target)


func _animate_path(unit: Node3D, path: Array, step_duration: float) -> void:
	var visual: Node3D = unit.get_node_or_null("ATACVisual") as Node3D
	var step_index: int = 0
	for next_cell_value: Variant in path:
		var next_cell: Vector2i = next_cell_value
		var current: Vector2i = unit.get_meta("cell")
		var delta_cell: Vector2i = next_cell - current
		if delta_cell != Vector2i.ZERO:
			unit.rotation.y = atan2(float(delta_cell.x), float(delta_cell.y))
			unit.set_meta("facing", delta_cell)
		var start_position: Vector3 = unit.position
		var target_position: Vector3 = _cell_to_world(next_cell)
		var substeps: int = 16
		for substep: int in range(substeps):
			var raw_ratio: float = float(substep + 1) / float(substeps)
			var ratio: float = smoothstep(0.0, 1.0, raw_ratio)
			var gait_phase: float = float(step_index) + raw_ratio
			if visual != null and visual.has_method("set_walk_pose"):
				visual.call("set_walk_pose", gait_phase, 1.0)
			var arc_height: float = sin(raw_ratio * PI) * 0.055
			var heel_impact: float = maxf(0.0, sin(raw_ratio * PI * 2.0)) * 0.012
			unit.position = start_position.lerp(target_position, ratio) + Vector3(0, arc_height - heel_impact, 0)
			await get_tree().create_timer(maxf(0.009, step_duration / float(substeps))).timeout
		_spawn_step_dust(target_position, step_index)
		unit.position = target_position
		unit.set_meta("cell", next_cell)
		step_index += 1
	if visual != null and visual.has_method("reset_pose"):
		visual.call("reset_pose")
	_refresh_hp_bar(unit)


func _spawn_step_dust(position: Vector3, step_index: int) -> void:
	var dust: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.08
	dust.mesh = mesh
	dust.position = position + Vector3(0.17 if step_index % 2 == 0 else -0.17, 0.05, 0)
	dust.material_override = _effect_material(Color(0.62, 0.57, 0.47, 0.45))
	add_child(dust)
	var tween: Tween = create_tween()
	dust.scale = Vector3(0.3, 0.2, 0.3)
	tween.tween_property(dust, "scale", Vector3(1.4, 0.25, 1.4), 0.24)
	tween.tween_callback(Callable(dust, "queue_free"))


func _animate_strong_slash(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Сильный порез»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var visual: Node3D = attacker.get_node_or_null("ATACVisual") as Node3D
	var arm: Node3D = attacker.get_node_or_null("ATACVisual/ModelRoot/RightArmPivot") as Node3D
	var weapon: Node3D = attacker.get_node_or_null("ATACVisual/ModelRoot/RightArmPivot/WeaponPivot") as Node3D
	var start_position: Vector3 = attacker.position
	var direction: Vector3 = (target.position - attacker.position).normalized()
	var windup: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if arm != null:
		windup.tween_property(arm, "rotation_degrees", Vector3(-40, -25, -110), 0.28)
	if weapon != null:
		windup.parallel().tween_property(weapon, "rotation_degrees", Vector3(0, 0, -65), 0.28)
	if visual != null:
		windup.parallel().tween_property(visual, "rotation_degrees:z", -9.0, 0.28)
	await windup.finished
	var strike: Tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	strike.tween_property(attacker, "position", start_position + direction * 0.34, 0.13)
	if arm != null:
		strike.parallel().tween_property(arm, "rotation_degrees", Vector3(28, 15, 92), 0.13)
	strike.tween_callback(Callable(self, "_spawn_heavy_arc").bind(target.global_position + Vector3(0, 1.05, 0), Color(1.0, 0.34, 0.18)))
	await strike.finished
	_camera_shake(0.25, 0.12)
	var recover: Tween = create_tween()
	recover.tween_property(attacker, "position", start_position, 0.25)
	if arm != null:
		recover.parallel().tween_property(arm, "rotation_degrees", Vector3.ZERO, 0.25)
	if weapon != null:
		recover.parallel().tween_property(weapon, "rotation_degrees", Vector3.ZERO, 0.25)
	if visual != null:
		recover.parallel().tween_property(visual, "rotation_degrees:z", 0.0, 0.25)
	await recover.finished


func _animate_shoulder_bash(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Толчок плечом»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var start: Vector3 = attacker.position
	var direction: Vector3 = (target.position - attacker.position).normalized()
	var visual: Node3D = attacker.get_node_or_null("ATACVisual") as Node3D
	var windup: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	windup.tween_property(attacker, "position", start - direction * 0.22, 0.16)
	if visual != null:
		windup.parallel().tween_property(visual, "rotation_degrees:x", -12.0, 0.16)
	await windup.finished
	var charge: Tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	charge.tween_property(attacker, "position", start + direction * 0.58, 0.16)
	await charge.finished
	_spawn_attack_burst(target.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.78, 0.28), 1.22)
	_camera_shake(0.24, 0.14)
	var recover: Tween = create_tween()
	recover.tween_property(attacker, "position", start, 0.28)
	if visual != null:
		recover.parallel().tween_property(visual, "rotation_degrees:x", 0.0, 0.28)
	await recover.finished


func _animate_tornado(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Торнадо»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var visual: Node3D = attacker.get_node_or_null("ATACVisual") as Node3D
	var start_rotation: Vector3 = visual.rotation_degrees if visual != null else Vector3.ZERO
	for index: int in range(5):
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.35 + index * 0.12
		torus.outer_radius = 0.39 + index * 0.12
		ring.mesh = torus
		ring.position = attacker.global_position + Vector3(0, 0.35 + index * 0.24, 0)
		ring.rotation_degrees.x = 90.0
		ring.material_override = _effect_material(Color(0.55, 0.92, 1.0, 0.65))
		add_child(ring)
		var ring_tween: Tween = create_tween()
		ring_tween.tween_property(ring, "rotation_degrees:y", 720.0, 0.72)
		ring_tween.parallel().tween_property(ring, "scale", Vector3.ONE * 1.45, 0.72)
		ring_tween.tween_property(ring, "scale", Vector3.ZERO, 0.14)
		ring_tween.tween_callback(Callable(ring, "queue_free"))
	var spin: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	if visual != null:
		spin.tween_property(visual, "rotation_degrees:y", start_rotation.y + 1080.0, 0.72)
	await spin.finished
	_spawn_heavy_arc(target.global_position + Vector3(0, 1.0, 0), Color(0.55, 0.92, 1.0))
	_spawn_attack_burst(target.global_position + Vector3(0, 1.0, 0), Color(0.45, 0.80, 1.0), 1.35)
	if visual != null:
		visual.rotation_degrees = start_rotation


func _animate_bright_bomb(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "Faulkner формирует «Яркую бомбу»"
	_face_target(attacker, target)
	var orb: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	orb.mesh = sphere
	orb.position = attacker.global_position + Vector3(0, 2.15, 0)
	orb.material_override = _effect_material(Color(1.0, 0.92, 0.38, 0.98))
	add_child(orb)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.25)
	light.light_energy = 22.0
	light.omni_range = 6.0
	orb.add_child(light)
	var charge: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	orb.scale = Vector3.ZERO
	charge.tween_property(orb, "scale", Vector3.ONE * 2.0, 0.55)
	await charge.finished
	var flight: Tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	flight.tween_property(orb, "position", target.global_position + Vector3(0, 1.0, 0), 0.42)
	await flight.finished
	_screen_flash(Color(1.0, 0.92, 0.55), 0.48, 0.32)
	_spawn_attack_burst(target.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.75, 0.18), 1.75)
	_camera_shake(0.44, 0.20)
	orb.queue_free()


func _animate_earthquake(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "Duyere вонзает обе косы: «Землетрясение»"
	_face_target(attacker, target)
	var visual: Node3D = attacker.get_node_or_null("ATACVisual") as Node3D
	var rise: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if visual != null:
		rise.tween_property(visual, "position:y", 0.32, 0.22)
	await rise.finished
	var slam: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if visual != null:
		slam.tween_property(visual, "position:y", 0.0, 0.16)
	await slam.finished
	for index: int in range(5):
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.22 + index * 0.18
		torus.outer_radius = 0.27 + index * 0.18
		ring.mesh = torus
		ring.position = attacker.global_position + Vector3(0, 0.08, 0)
		ring.rotation_degrees.x = 90.0
		ring.material_override = _effect_material(Color(0.68, 0.48, 0.24, 0.82))
		add_child(ring)
		var tween: Tween = create_tween()
		ring.scale = Vector3.ZERO
		tween.tween_property(ring, "scale", Vector3.ONE * (1.0 + index * 0.45), 0.32 + index * 0.05)
		tween.tween_property(ring, "scale", Vector3.ZERO, 0.12)
		tween.tween_callback(Callable(ring, "queue_free"))
	_spawn_attack_burst(target.global_position + Vector3(0, 0.7, 0), Color(0.74, 0.52, 0.28), 1.25)
	_camera_shake(0.38, 0.18)


func _spawn_heavy_arc(position: Vector3, color: Color) -> void:
	for index: int in range(4):
		var arc: MeshInstance3D = MeshInstance3D.new()
		var mesh: TorusMesh = TorusMesh.new()
		mesh.inner_radius = 0.38 + index * 0.06
		mesh.outer_radius = 0.43 + index * 0.06
		mesh.rings = 28
		mesh.ring_segments = 7
		arc.mesh = mesh
		arc.position = position
		arc.rotation_degrees = Vector3(90, index * 17, 25 + index * 8)
		arc.material_override = _effect_material(Color(color.r, color.g, color.b, 0.76 - index * 0.12))
		add_child(arc)
		var tween: Tween = create_tween()
		arc.scale = Vector3.ONE * 0.25
		tween.tween_property(arc, "scale", Vector3.ONE * 1.35, 0.18)
		tween.tween_property(arc, "scale", Vector3.ZERO, 0.16)
		tween.tween_callback(Callable(arc, "queue_free"))


func _attempt_knockback(attacker: Node3D, target: Node3D) -> void:
	var from_cell: Vector2i = attacker.get_meta("cell")
	var target_cell: Vector2i = target.get_meta("cell")
	var delta: Vector2i = target_cell - from_cell
	var destination: Vector2i = target_cell + delta
	if not _cell_in_bounds(destination) or blocked_cells.has(destination) or _unit_at(destination) != null:
		return
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "position", _cell_to_world(destination), 0.25)
	await tween.finished
	target.set_meta("cell", destination)
	_refresh_hp_bar(target)


func _open_current_upgrade() -> void:
	if player_unit == null:
		return
	var character_id: String = str(player_unit.get_meta("character_id", ""))
	if character_id.is_empty():
		return
	_open_upgrade_panel(character_id)


func _open_upgrade_panel(character_id: String) -> void:
	upgrade_character_id = character_id
	upgrade_panel.visible = true
	_refresh_upgrade_panel()


func _refresh_upgrade_panel() -> void:
	var data: Dictionary = CampaignState.get_character(upgrade_character_id)
	upgrade_title.text = "%s — прокачка" % str(data.get("name", upgrade_character_id))
	upgrade_points_label.text = (
		"Свободные очки: %d\nСила +%d • Ловкость +%d • Защита +%d • Умение атаки +%d"
		% [
			int(data.get("stat_points", 0)),
			int(data.get("strength_bonus", 0)),
			int(data.get("agility_bonus", 0)),
			int(data.get("defense_bonus", 0)),
			int(data.get("attack_skill_bonus", 0)),
		]
	)


func _allocate_battle_stat(stat_key: String) -> void:
	if CampaignState.allocate_stat(upgrade_character_id, stat_key):
		for unit: Node3D in units:
			if str(unit.get_meta("character_id", "")) != upgrade_character_id:
				continue
			var old_stats: Dictionary = _stats(unit)
			var old_hp: int = int(old_stats.get("hp", 1))
			var refreshed: Dictionary = CampaignState.apply_character_progress(upgrade_character_id, old_stats)
			refreshed["hp"] = mini(old_hp, int(refreshed.get("max_hp", old_hp)))
			unit.set_meta("stats", refreshed)
			_refresh_hp_bar(unit)
	_refresh_upgrade_panel()
	_refresh_ui()


func _close_upgrade_panel() -> void:
	upgrade_panel.visible = false
	upgrade_closed.emit()


func _award_attack_experience(attacker: Node3D, damage: int, killed_enemy: bool) -> void:
	var character_id: String = str(attacker.get_meta("character_id", ""))
	var before_level: int = int(CampaignState.get_character(character_id).get("level", 1)) if not character_id.is_empty() else 0
	super._award_attack_experience(attacker, damage, killed_enemy)
	if character_id.is_empty():
		return
	var after_data: Dictionary = CampaignState.get_character(character_id)
	if int(after_data.get("level", 1)) > before_level:
		upgrade_button.visible = true
		call_deferred("_open_upgrade_panel", character_id)


func _refresh_ui() -> void:
	super._refresh_ui()
	ability_button.visible = false
	if selected_unit == null:
		upgrade_button.visible = false
		return
	var portrait_path: String = str(selected_unit.get_meta("portrait_path", ""))
	if not portrait_path.is_empty():
		portrait.texture = load(portrait_path)
	var character_id: String = str(selected_unit.get_meta("character_id", ""))
	var character_data: Dictionary = CampaignState.get_character(character_id) if not character_id.is_empty() else {}
	if str(selected_unit.get_meta("model_slug", "")) == "eigol":
		equipment_label.text += "\nМагия: Зыбучие пески — %d / 3" % int(selected_unit.get_meta("magic_uses", 0))
	upgrade_button.visible = bool(selected_unit.get_meta("player", false)) and int(character_data.get("stat_points", 0)) > 0
	var can_player_act: bool = phase in [Phase.PLAYER_MOVE, Phase.PLAYER_ACTION] and not action_in_progress and selected_unit == player_unit
	var any_target: bool = false
	if can_player_act:
		for mode: String in CombatCatalog.attacks_for(player_unit):
			if not _eligible_targets(player_unit, mode).is_empty():
				any_target = true
				break
	attack_button.disabled = not (can_player_act and any_target)
	end_turn_button.disabled = not can_player_act


func _play_mission_three_intro() -> void:
	await _show_dialogue(
		"Faulkner",
		"Kamorge... Столько лет прошло, а ты всё ещё прячешься за старым клинком. Мой отец говорил, что когда-то ты был достойным противником.",
		FAULKNER_PORTRAIT
	)
	await _show_dialogue(
		"Kamorge",
		"Я знал твоего отца, когда ты едва удерживал меч. Он бы не одобрил, во что ты превратил его армию.",
		KAMORGE_PORTRAIT
	)
	await _show_dialogue(
		"Duyere",
		"Сентиментальность на поле боя — слабость. Закройте им путь к королевству и не оставляйте дороги назад.",
		DUYERE_PORTRAIT
	)
	await _show_dialogue(
		"Andrew",
		"Нас зажали между двумя отрядами. Мост узкий: на каждой стороне одновременно сможет сражаться только один ATAC.",
		ANDREW_PORTRAIT
	)
	await _show_dialogue(
		"Faulkner",
		"Первый солдат — на мост. Покажи старому рыцарю, что времена его побед закончились.",
		FAULKNER_PORTRAIT
	)
	for index: int in range(mini(2, bridge_vanguard.size())):
		await _scripted_bridge_duel(bridge_vanguard[index], index + 1)
	await _show_dialogue(
		"Kamorge",
		"Bastion, уходи! Иди в Южное королевство и проси помощи. Здесь силы не равны, а мост превратится в ловушку.",
		KAMORGE_PORTRAIT
	)
	pending_story_choice = ""
	if CampaignState.test_forced_branch in ["stay_and_fight", "seek_southern_aid"]:
		pending_story_choice = CampaignState.test_forced_branch
		CampaignState.test_forced_branch = ""
		await _show_dialogue(
			"Режим тестирования",
			(
				"Выбран исход: Bastion остаётся с Kamorge."
				if pending_story_choice == "stay_and_fight"
				else "Выбран исход: Bastion слушает Kamorge и отступает."
			),
			PLAYER_PORTRAIT
		)
	else:
		story_choice_panel.visible = true
		await story_choice_selected
		story_choice_panel.visible = false
	CampaignState.set_story_branch(pending_story_choice)
	if pending_story_choice == "seek_southern_aid":
		await _play_capture_branch()
	else:
		await _play_stand_branch()


func _scripted_bridge_duel(enemy: Node3D, sequence: int) -> void:
	if enemy == null or not _is_alive(enemy):
		return
	status_label.text = "Имперский солдат %d выходит на узкий мост." % sequence
	var goal: Vector2i = Vector2i(11, 7)
	var enemy_cell: Vector2i = enemy.get_meta("cell")
	var path: Array = _find_path(enemy_cell, goal, enemy)
	if not path.is_empty():
		await _animate_path(enemy, path, 0.24)
	await _animate_slash(enemy, kamorge_unit)
	_spawn_guard_effect(kamorge_unit.global_position + Vector3(0, 1.1, 0))
	await get_tree().create_timer(0.18).timeout
	await _animate_strong_slash(kamorge_unit, enemy)
	active_attacker = kamorge_unit
	await _damage_target(enemy, int(_stats(enemy).get("max_hp", 100)))
	active_attacker = null
	if sequence == 1:
		await _show_dialogue(
			"Faulkner",
			"Следующий. Не давайте ему перевести дыхание.",
			FAULKNER_PORTRAIT
		)
	else:
		await get_tree().create_timer(0.01).timeout


func _finish_story_choice(choice: String) -> void:
	pending_story_choice = choice
	story_choice_selected.emit()


func _play_capture_branch() -> void:
	await _show_dialogue("Bastion", "Хорошо, отец. Я послушаю тебя. Но мы ещё вернёмся за тобой.", PLAYER_PORTRAIT)
	await _show_dialogue(
		"Kamorge",
		"Не оглядывайся. Barazaph не должен достаться империи. Я лишу машину силы и уйду через реку.",
		KAMORGE_PORTRAIT
	)
	await _animate_kamorge_river_jump()
	await _show_dialogue(
		"Faulkner",
		"Он выбрал воду вместо плена. Duyere, оставим капитану молодых. Их нужно взять живыми.",
		FAULKNER_PORTRAIT
	)
	await _show_dialogue(
		"Duyere",
		"Captain Soldiers, сомкнуть строй. Bastion и Andrew должны оказаться в цепях, даже если придётся бросить сюда весь отряд.",
		DUYERE_PORTRAIT
	)
	await _fade_villains_out()
	await _show_dialogue(
		"Captain Soldiers",
		"Имперские ATAC, вперёд! Партизан здесь нет. Эти двое остаются одни.",
		CAPTAIN_PORTRAIT
	)
	await _advance_imperial_assault()
	branch_combat_mode = "capture_no_help"
	branch_combat_active = true
	branch_rounds_elapsed = 0
	branch_resolution_started = false
	action_in_progress = false
	phase = Phase.PLAYER_MOVE
	status_label.text = "Продержитесь три раунда. Помощь не придёт — исходом станет плен."
	_begin_player_turn()


func _play_stand_branch() -> void:
	await _show_dialogue("Bastion", "Нет. Я не оставлю тебя одного. Мы будем сражаться вместе.", PLAYER_PORTRAIT)
	await _show_dialogue(
		"Andrew",
		"Я рядом. Faulkner хочет быстрой расправы, но лёгкой победы он не получит.",
		ANDREW_PORTRAIT
	)
	await _show_dialogue(
		"Faulkner",
		"Тогда я лично закончу спор, который начался ещё между нашими отцами.",
		FAULKNER_PORTRAIT
	)
	await _play_faulkner_kamorge_duel()
	await _show_dialogue("Bastion", "Нее-е-ет! Отец!!!", PLAYER_PORTRAIT)
	await _show_dialogue(
		"Faulkner",
		"Он сражался достойно. Но этот мост принадлежит империи. Капитан, закончите дело.",
		FAULKNER_PORTRAIT
	)
	await _show_dialogue(
		"Duyere",
		"Мы уходим. Captain Soldiers, наступайте и не дайте Bastion скрыться в лесу.",
		DUYERE_PORTRAIT
	)
	await _fade_villains_out()
	await _show_dialogue(
		"Captain Soldiers",
		"Всем подразделениям — вперёд! Прижать Bastion и Andrew к реке!",
		CAPTAIN_PORTRAIT
	)
	await _advance_imperial_assault()
	await _spawn_partisan_reinforcements()
	branch_combat_mode = "partisan_rescue"
	branch_combat_active = true
	branch_rounds_elapsed = 0
	branch_resolution_started = false
	action_in_progress = false
	phase = Phase.PLAYER_MOVE
	status_label.text = "Ione, Reyna и Zeira присоединились. Разбейте имперский отряд."
	_begin_player_turn()


func _show_victory() -> void:
	if mission_number == 4:
		if victory_sequence_started:
			return
		victory_sequence_started = true
		phase = Phase.VICTORY
		_set_action_buttons(true)
		phase_label.text = "ПОБЕДА"
		status_label.text = "Лесной дозор уничтожен. Eigol снова шагает по земле."
		await _show_dialogue(
			"Kamorge",
			"Eigol... Ты не спас меня от прошлого, но дал шанс исправить будущее. Теперь я найду Bastion — даже если придётся пройти через всю империю.",
			KAMORGE_PORTRAIT
		)
		CampaignState.complete_mission(4)
		get_tree().change_scene_to_file(STORY_SCENE_PATH)
		return
	if mission_number != 3:
		super._show_victory()
		return
	if branch_resolution_started:
		return
	if branch_combat_mode == "capture_no_help":
		await _play_forced_capture_outro()
		return
	if branch_combat_mode != "partisan_rescue":
		return
	branch_resolution_started = true
	branch_combat_active = false
	phase = Phase.VICTORY
	_set_action_buttons(true)
	phase_label.text = "ПОБЕДА"
	phase_label.modulate = Color(0.42, 1.0, 0.55)
	status_label.text = "Имперский отряд разбит. Партизаны открыли путь в лес."
	await _show_dialogue(
		"Zeira",
		"Мост потерян, но вы живы. Наш отряд давно наблюдал за имперцами из леса. Теперь идёмте — до возвращения Faulkner нужно исчезнуть.",
		ZEIRA_PORTRAIT
	)
	await _show_dialogue(
		"Ione",
		"Amphisia прикроет следы. В лесу есть лагерь, где можно починить ATAC и решить, как ответить за Kamorge.",
		IONE_PORTRAIT
	)
	await _show_dialogue(
		"Reyna",
		"Haurol ещё не закончил охоту. В следующий раз имперцы не уйдут так легко.",
		REYNA_PORTRAIT
	)
	CampaignState.complete_mission(3, "stay_and_fight")
	get_tree().change_scene_to_file(STORY_SCENE_PATH)


func _play_mission_four_intro() -> void:
	await _show_dialogue(
		"Kamorge",
		"Barazaph остался у моста. Я покинул машину, которой доверял половину жизни... и оставил сына в руках империи.",
		KAMORGE_PORTRAIT
	)
	await _show_dialogue(
		"Kamorge",
		"Когда-то я служил на границе Пустынного королевства. Там рассказывали об Eigol — ATAC королевского генерала, исчезнувшего вместе с целым караваном. Что он делает здесь, в сыром северном лесу?",
		KAMORGE_PORTRAIT
	)
	var visual: Node3D = eigol_unit.get_node_or_null("ATACVisual") as Node3D
	if visual != null:
		visual.visible = true
		visual.scale = Vector3.ZERO
		var reveal: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(visual, "scale", Vector3.ONE * 0.60, 0.72)
		await reveal.finished
	_spawn_arrival_effect(eigol_unit.global_position + Vector3(0, 1.0, 0))
	await _show_dialogue(
		"Kamorge",
		"Система принимает меня... Значит, генерал оставил Eigol тому, кто ещё способен продолжить его путь. Bastion, жди меня.",
		KAMORGE_PORTRAIT
	)
	await _show_dialogue(
		"Имперский командир",
		"Неизвестный ATAC активирован! Четвёрка, окружить его и забрать машину неповреждённой!",
		IMPERIAL_PORTRAIT
	)


func _animate_atac_overload(unit: Node3D) -> void:
	if unit == null:
		return
	status_label.text = "Kamorge перегружает Barazaph и уходит в лес."
	for index: int in range(7):
		_spawn_attack_burst(unit.global_position + Vector3(0, 0.45 + index * 0.16, 0), Color(1.0, 0.34, 0.08), 0.55 + index * 0.10)
	await get_tree().create_timer(0.55).timeout
	var tween: Tween = create_tween()
	tween.tween_property(unit, "scale", Vector3.ZERO, 0.38)
	await tween.finished


func _animate_faulkner_final_strike() -> void:
	if faulkner_unit == null or kamorge_unit == null:
		return
	await _animate_lunge(faulkner_unit, kamorge_unit)
	_spawn_heavy_arc(kamorge_unit.global_position + Vector3(0, 1.0, 0), Color(0.95, 0.05, 0.08))
	_camera_shake(0.55, 0.25)
	var stats: Dictionary = _stats(kamorge_unit)
	stats["hp"] = 0
	kamorge_unit.set_meta("stats", stats)
	_refresh_hp_bar(kamorge_unit)
	var death: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death.tween_property(kamorge_unit, "rotation_degrees:z", 88.0, 0.60)
	death.parallel().tween_property(kamorge_unit, "position:y", kamorge_unit.position.y - 0.30, 0.60)
	death.tween_property(kamorge_unit, "scale", Vector3.ZERO, 0.35)
	await death.finished


func _fade_villains_out() -> void:
	var villains: Array[Node3D] = []
	if faulkner_unit != null:
		villains.append(faulkner_unit)
	if duyere_unit != null:
		villains.append(duyere_unit)
	for villain: Node3D in villains:
		var leave: Tween = create_tween()
		var side_offset: float = -4.0 if villain == faulkner_unit else 4.0
		leave.tween_property(villain, "position", villain.position + Vector3(side_offset, 0, -2.0), 0.70)
		leave.parallel().tween_property(villain, "scale", Vector3.ZERO, 0.70)
		await leave.finished
		villain.set_meta("team", "retreated")
		var stats: Dictionary = _stats(villain)
		stats["hp"] = 0
		villain.set_meta("stats", stats)
		_refresh_hp_bar(villain)



func _show_defeat() -> void:
	if mission_number == 3 and branch_combat_mode == "capture_no_help":
		await _play_forced_capture_outro()
		return
	super._show_defeat()


func _play_faulkner_kamorge_duel() -> void:
	if faulkner_unit == null or kamorge_unit == null:
		return
	status_label.text = "Faulkner и Kamorge сходятся на мосту."
	var goal: Vector2i = Vector2i(10, 7)
	var path: Array = _find_path(faulkner_unit.get_meta("cell"), goal, faulkner_unit)
	if not path.is_empty():
		await _animate_path(faulkner_unit, path, 0.28)
	await _animate_strong_slash(faulkner_unit, kamorge_unit)
	await _damage_target(kamorge_unit, maxi(1, int(float(_stats(kamorge_unit).get("max_hp", 1)) * 0.16)))
	await _show_dialogue(
		"Kamorge",
		"Ты стал сильнее, Faulkner. Но сила без чести превращает генерала в палача.",
		KAMORGE_PORTRAIT
	)
	await _animate_lunge(kamorge_unit, faulkner_unit)
	await _damage_target(faulkner_unit, maxi(1, int(float(_stats(faulkner_unit).get("max_hp", 1)) * 0.12)))
	await _show_dialogue(
		"Faulkner",
		"Я не пришёл за твоим уважением. Я пришёл закончить войну, которую ты оставил моему отцу.",
		FAULKNER_PORTRAIT
	)
	await _animate_ball_lightning(faulkner_unit, kamorge_unit)
	await _damage_target(kamorge_unit, maxi(1, int(float(_stats(kamorge_unit).get("max_hp", 1)) * 0.22)))
	await _animate_strong_slash(kamorge_unit, faulkner_unit)
	await _damage_target(faulkner_unit, maxi(1, int(float(_stats(faulkner_unit).get("max_hp", 1)) * 0.10)))
	await _show_dialogue(
		"Duyere",
		"Они всё ещё равны. Faulkner, затягивать бой опасно — лес наблюдает за нами.",
		DUYERE_PORTRAIT
	)
	await _animate_lunge(faulkner_unit, kamorge_unit)
	await _damage_target(kamorge_unit, maxi(1, int(float(_stats(kamorge_unit).get("max_hp", 1)) * 0.24)))
	await _show_dialogue(
		"Kamorge",
		"Bastion... я допустил ошибку. Я думал, что смогу один закрыть тебя от этой войны. Прости меня, сын. Я не смог защитить тебя...",
		KAMORGE_PORTRAIT
	)
	await _show_dialogue(
		"Faulkner",
		"Прощай, Kamorge. Сегодня победит не один удар — победит тот, кто выдержал весь бой.",
		FAULKNER_PORTRAIT
	)
	await _animate_faulkner_final_strike()


func _animate_kamorge_river_jump() -> void:
	if kamorge_unit == null:
		return
	status_label.text = "Kamorge отключает Barazaph и прыгает в реку."
	for index: int in range(5):
		_spawn_attack_burst(kamorge_unit.global_position + Vector3(0, 0.55 + index * 0.18, 0), Color(0.35, 0.72, 1.0), 0.50 + index * 0.08)
	await get_tree().create_timer(0.35).timeout
	var destination_cell: Vector2i = Vector2i(11, 8)
	var destination: Vector3 = _cell_to_world(destination_cell) + Vector3(0, -0.35, 0)
	var jump: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	jump.tween_property(kamorge_unit, "position", destination + Vector3(0, 1.1, 0), 0.32)
	jump.tween_property(kamorge_unit, "position", destination, 0.30)
	jump.parallel().tween_property(kamorge_unit, "scale", Vector3.ZERO, 0.30)
	await jump.finished
	_spawn_water_splash(destination + Vector3(0, 0.35, 0))
	kamorge_unit.set_meta("team", "escaped")
	kamorge_unit.set_meta("lost_atac", true)
	var stats: Dictionary = _stats(kamorge_unit)
	stats["hp"] = 0
	kamorge_unit.set_meta("stats", stats)
	_refresh_hp_bar(kamorge_unit)


func _spawn_water_splash(position: Vector3) -> void:
	for index: int in range(7):
		var drop: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.08
		mesh.height = 0.16
		drop.mesh = mesh
		drop.position = position
		drop.material_override = _effect_material(Color(0.38, 0.78, 1.0, 0.82))
		add_child(drop)
		var angle: float = TAU * float(index) / 7.0
		var target: Vector3 = position + Vector3(cos(angle) * 0.9, 0.55 + float(index % 2) * 0.25, sin(angle) * 0.9)
		var tween: Tween = create_tween()
		tween.tween_property(drop, "position", target, 0.32)
		tween.tween_property(drop, "scale", Vector3.ZERO, 0.18)
		tween.tween_callback(Callable(drop, "queue_free"))


func _advance_imperial_assault() -> void:
	var advanced: int = 0
	for enemy: Node3D in units:
		if str(enemy.get_meta("team")) != "enemy" or not _is_alive(enemy):
			continue
		var target: Node3D = _nearest_opponent(enemy)
		if target == null:
			continue
		var goals: Array = _free_adjacent_cells(target, enemy)
		var path: Array = _find_path_to_any(enemy.get_meta("cell"), goals, enemy)
		var steps: int = mini(2, path.size())
		if steps > 0:
			await _animate_path(enemy, path.slice(0, steps), 0.18)
		advanced += 1
		if advanced >= 3:
			break


func _spawn_partisan_reinforcements() -> void:
	await _show_dialogue(
		"Ione",
		"Не двигайтесь! Мы следили за имперским отрядом из леса. Amphisia, на мост!",
		IONE_PORTRAIT
	)
	var spawn_data: Dictionary = map_data.get("partisan_spawns", {}) as Dictionary
	ione_unit = _spawn_character_unit("ione", _resolve_spawn_cell(_array_to_cell(spawn_data.get("ione", [21, 3]))), true, "ally")
	reyna_unit = _spawn_character_unit("reyna", _resolve_spawn_cell(_array_to_cell(spawn_data.get("reyna", [20, 4]))), true, "ally")
	zeira_unit = _spawn_character_unit("zeira", _resolve_spawn_cell(_array_to_cell(spawn_data.get("zeira", [19, 4]))), true, "ally")
	for partisan: Node3D in [ione_unit, reyna_unit, zeira_unit]:
		partisan.set_meta("facing", Vector2i(-1, 0))
		partisan.rotation.y = atan2(-1.0, 0.0)
		partisan.set_meta("facing_chosen", false)
		if not player_party.has(partisan):
			player_party.append(partisan)
		_spawn_arrival_effect(partisan.global_position + Vector3(0, 1.0, 0))
	await _show_dialogue(
		"Reyna",
		"Haurol готов. Копьё достанет их с пяти клеток, а ледяной дождь остановит наступление.",
		REYNA_PORTRAIT
	)
	await _show_dialogue(
		"Zeira",
		"Я Zeira. Toreadore поведёт отряд: два перемещения за ход, золотое копьё и ни шага назад. Bastion, сражайся рядом с нами.",
		ZEIRA_PORTRAIT
	)


func _resolve_spawn_cell(preferred: Vector2i) -> Vector2i:
	for radius: int in range(0, 6):
		for x_offset: int in range(-radius, radius + 1):
			for y_offset: int in range(-radius, radius + 1):
				if abs(x_offset) + abs(y_offset) != radius:
					continue
				var candidate: Vector2i = preferred + Vector2i(x_offset, y_offset)
				if _cell_in_bounds(candidate) and not blocked_cells.has(candidate) and _unit_at(candidate) == null:
					return candidate
	return preferred


func _play_forced_capture_outro() -> void:
	if branch_resolution_started:
		return
	branch_resolution_started = true
	branch_combat_active = false
	action_in_progress = true
	phase = Phase.DIALOGUE
	_set_action_buttons(true)
	_restore_capture_survivor(_find_character_unit("bastion"))
	_restore_capture_survivor(_find_character_unit("andrew"))
	phase_label.text = "ПЛЕН"
	phase_label.modulate = Color(0.95, 0.62, 0.24)
	status_label.text = "Имперские подкрепления замкнули кольцо."
	await _show_dialogue(
		"Captain Soldiers",
		"Достаточно. Вы сражались достойно, но каждую потерянную машину заменит новая. Оружие на землю!",
		CAPTAIN_PORTRAIT
	)
	await _show_dialogue(
		"Andrew",
		"Bastion, мы одни. Если погибнем сейчас, выбраться из империи уже будет некому. Сдаёмся — пока.",
		ANDREW_PORTRAIT
	)
	await _show_dialogue(
		"Bastion",
		"Отец ушёл в реку и лишился ATAC, но я верю, что он жив. Мы переживём плен и найдём его.",
		PLAYER_PORTRAIT
	)
	CampaignState.complete_mission(3, "seek_southern_aid")
	get_tree().change_scene_to_file(STORY_SCENE_PATH)


func _find_character_unit(character_id: String) -> Node3D:
	for unit: Node3D in units:
		if str(unit.get_meta("character_id", "")) == character_id:
			return unit
	return null


func _restore_capture_survivor(unit: Node3D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var stats: Dictionary = _stats(unit)
	stats["hp"] = maxi(1, int(stats.get("hp", 1)))
	unit.set_meta("stats", stats)
	unit.scale = Vector3.ONE
	unit.rotation_degrees.z = 0.0
	unit.position = _cell_to_world(unit.get_meta("cell"))
	_refresh_hp_bar(unit)


func _try_disoriented_friendly_fire(unit: Node3D) -> bool:
	var chance: float = float(unit.get_meta("friendly_fire_chance", 0.50))
	if rng.randf() > chance:
		status_label.text = "%s сопротивляется дезориентации." % str(unit.get_meta("label"))
		return false
	var team: String = str(unit.get_meta("team"))
	var friendly: Node3D
	var best_distance: int = 999
	for candidate: Node3D in units:
		if candidate == unit or str(candidate.get_meta("team")) != team or not _is_alive(candidate):
			continue
		var distance: int = _grid_distance(unit, candidate)
		if distance < best_distance:
			best_distance = distance
			friendly = candidate
	if friendly == null:
		return false
	status_label.text = "%s теряет ориентацию и атакует своего!" % str(unit.get_meta("label"))
	if _grid_distance(unit, friendly) > 1:
		var goals: Array = _free_adjacent_cells(friendly, unit)
		var path: Array = _find_path_to_any(unit.get_meta("cell"), goals, unit)
		var steps: int = mini(_available_move_range(unit), path.size())
		if steps > 0:
			await _animate_path(unit, path.slice(0, steps), 0.20)
	if _grid_distance(unit, friendly) == 1 and _is_alive(friendly):
		await _animate_slash(unit, friendly)
		await _resolve_attack(unit, friendly, "slash")
	else:
		await _animate_miss(unit)
	return true


func _animate_frozen_skip(unit: Node3D) -> void:
	_spawn_ice_lock_effect(unit.global_position + Vector3(0, 1.0, 0))
	var start_scale: Vector3 = unit.scale
	var tween: Tween = create_tween()
	tween.tween_property(unit, "scale", start_scale * Vector3(0.96, 1.04, 0.96), 0.18)
	tween.tween_property(unit, "scale", start_scale, 0.22)
	await tween.finished


func _spawn_ice_lock_effect(position: Vector3) -> void:
	for index: int in range(6):
		var shard: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.10, 0.75 + float(index % 3) * 0.18, 0.10)
		shard.mesh = mesh
		var angle: float = TAU * float(index) / 6.0
		shard.position = position + Vector3(cos(angle) * 0.58, -0.25, sin(angle) * 0.58)
		shard.rotation_degrees = Vector3(0, rad_to_deg(angle), -12 + index * 4)
		shard.material_override = _effect_material(Color(0.42, 0.88, 1.0, 0.82))
		add_child(shard)
		shard.scale = Vector3.ZERO
		var tween: Tween = create_tween()
		tween.tween_property(shard, "scale", Vector3.ONE, 0.20)
		tween.tween_interval(0.35)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.18)
		tween.tween_callback(Callable(shard, "queue_free"))


func _animate_spear_throw(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Бросок копья»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var spear: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.055
	mesh.height = 1.65
	spear.mesh = mesh
	spear.position = attacker.global_position + Vector3(0, 1.15, 0)
	spear.material_override = _effect_material(Color(1.0, 0.78, 0.20, 0.95))
	add_child(spear)
	var direction: Vector3 = (target.global_position - attacker.global_position).normalized()
	spear.rotation = Vector3(PI / 2.0, atan2(direction.x, direction.z), 0)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(spear, "position", target.global_position + Vector3(0, 1.0, 0), 0.28)
	await tween.finished
	_spawn_attack_burst(target.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.72, 0.18), 1.05)
	spear.queue_free()


func _animate_ice_rain(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s вызывает «Ледяной дождь»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	for index: int in range(10):
		var shard: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.08, 0.72, 0.08)
		shard.mesh = mesh
		var x_offset: float = float((index % 5) - 2) * 0.27
		var z_offset: float = float((index / 5) - 1) * 0.35
		shard.position = target.global_position + Vector3(x_offset, 3.0 + float(index % 3) * 0.25, z_offset)
		shard.material_override = _effect_material(Color(0.48, 0.90, 1.0, 0.92))
		add_child(shard)
		var tween: Tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.tween_interval(float(index) * 0.025)
		tween.tween_property(shard, "position:y", target.global_position.y + 0.35, 0.30)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.12)
		tween.tween_callback(Callable(shard, "queue_free"))
	await get_tree().create_timer(0.58).timeout
	_spawn_attack_burst(target.global_position + Vector3(0, 0.8, 0), Color(0.36, 0.82, 1.0), 1.35)


func _animate_ultrasound(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Ультразвук»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	for index: int in range(6):
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.22
		torus.outer_radius = 0.27
		torus.rings = 28
		torus.ring_segments = 7
		ring.mesh = torus
		ring.position = attacker.global_position + Vector3(0, 1.1, 0)
		ring.look_at(target.global_position + Vector3(0, 1.1, 0), Vector3.UP)
		ring.material_override = _effect_material(Color(0.78, 0.42, 1.0, 0.76))
		add_child(ring)
		var tween: Tween = create_tween()
		tween.tween_interval(float(index) * 0.055)
		tween.tween_property(ring, "position", target.global_position + Vector3(0, 1.1, 0), 0.34)
		tween.parallel().tween_property(ring, "scale", Vector3.ONE * (1.2 + index * 0.12), 0.34)
		tween.tween_property(ring, "scale", Vector3.ZERO, 0.12)
		tween.tween_callback(Callable(ring, "queue_free"))
	await get_tree().create_timer(0.72).timeout
	_camera_shake(0.18, 0.08)


func _animate_slide(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Скольжение»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	attacker.set_meta("slide_origin_cell", attacker.get_meta("cell"))
	var direction: Vector3 = (target.position - attacker.position).normalized()
	var destination: Vector3 = target.position - direction * 0.22
	var tween: Tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(attacker, "position", destination, 0.22)
	await tween.finished
	_spawn_heavy_arc(target.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.72, 0.12))
	_spawn_attack_burst(target.global_position + Vector3(0, 0.85, 0), Color(0.82, 0.36, 1.0), 1.55)
	_camera_shake(0.45, 0.22)


func _complete_slide_pass_through(attacker: Node3D, target: Node3D) -> void:
	var origin_cell: Vector2i = attacker.get_meta("slide_origin_cell", attacker.get_meta("cell"))
	var target_cell: Vector2i = target.get_meta("cell")
	var direction: Vector2i = _cardinal_direction(origin_cell, target_cell)
	var destination: Vector2i = target_cell + direction
	if direction == Vector2i.ZERO or not _cell_in_bounds(destination) or blocked_cells.has(destination) or _unit_at(destination) != null:
		destination = origin_cell
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(attacker, "position", _cell_to_world(destination), 0.22)
	await tween.finished
	attacker.set_meta("cell", destination)
	attacker.remove_meta("slide_origin_cell")
	_refresh_hp_bar(attacker)


func _animate_rear_kick(defender: Node3D, attacker: Node3D) -> void:
	# The passive is an immediate backward strike, so Toreadore keeps its original facing.
	var start_rotation: Vector3 = defender.rotation_degrees
	var start_position: Vector3 = defender.position
	var direction: Vector3 = (attacker.position - defender.position).normalized()
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(defender, "rotation_degrees:y", defender.rotation_degrees.y + 170.0, 0.16)
	tween.parallel().tween_property(defender, "position", start_position - direction * 0.24, 0.16)
	await tween.finished
	_spawn_attack_burst(attacker.global_position + Vector3(0, 0.75, 0), Color(1.0, 0.62, 0.16), 1.35)
	_camera_shake(0.32, 0.15)
	var recover: Tween = create_tween()
	recover.tween_property(defender, "rotation_degrees", start_rotation, 0.22)
	recover.parallel().tween_property(defender, "position", start_position, 0.22)
	await recover.finished


func _attempt_knockback_distance(source: Node3D, target: Node3D, distance: int) -> void:
	var source_cell: Vector2i = source.get_meta("cell")
	var current: Vector2i = target.get_meta("cell")
	var direction: Vector2i = _cardinal_direction(source_cell, current)
	if direction == Vector2i.ZERO:
		return
	var destination: Vector2i = current
	for step: int in range(distance):
		var candidate: Vector2i = destination + direction
		if not _cell_in_bounds(candidate) or blocked_cells.has(candidate) or _unit_at(candidate) != null:
			break
		destination = candidate
	if destination == current:
		return
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "position", _cell_to_world(destination), 0.34)
	await tween.finished
	target.set_meta("cell", destination)
	_refresh_hp_bar(target)


func _cardinal_direction(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var delta: Vector2i = to_cell - from_cell
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		return Vector2i(1 if delta.x > 0 else -1, 0)
	return Vector2i(0, 1 if delta.y > 0 else -1)

func _apply_sand_status(target: Node3D, turns: int, move_limit: int, miss_chance: float) -> void:
	target.set_meta("slow_turns", turns)
	target.set_meta("slow_move_limit", move_limit)
	target.set_meta("miss_chance", miss_chance)
	_spawn_sand_column(target.global_position)


func _tick_status_effects(unit: Node3D) -> void:
	var turns: int = int(unit.get_meta("slow_turns", 0))
	if turns <= 0:
		return
	turns -= 1
	unit.set_meta("slow_turns", turns)
	if turns <= 0:
		unit.set_meta("slow_move_limit", 0)
		unit.set_meta("miss_chance", 0.0)


func _available_move_range(unit: Node3D) -> int:
	var normal_range: int = super._available_move_range(unit)
	var turns: int = int(unit.get_meta("slow_turns", 0))
	if turns > 0:
		return mini(normal_range, maxi(1, int(unit.get_meta("slow_move_limit", 2))))
	return normal_range


func _animate_miss(unit: Node3D) -> void:
	var start: Vector3 = unit.position
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(unit, "position:x", start.x + 0.12, 0.08)
	tween.tween_property(unit, "position:x", start.x - 0.10, 0.10)
	tween.tween_property(unit, "position", start, 0.10)
	await tween.finished


func _animate_desert_whirl(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Вихрь в пустыне»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var visual: Node3D = attacker.get_node_or_null("ATACVisual") as Node3D
	var start: Vector3 = attacker.position
	var direction: Vector3 = (target.position - attacker.position).normalized()
	for phase_index: int in range(18):
		if visual != null and visual.has_method("set_combat_pose"):
			visual.call("set_combat_pose", "desert_whirl", float(phase_index) / 17.0)
		_spawn_sand_arc(attacker.global_position + Vector3(0, 0.75, 0), phase_index)
		attacker.position = start + direction * sin(float(phase_index) / 17.0 * PI) * 0.65
		await get_tree().create_timer(0.035).timeout
	attacker.position = start
	if visual != null and visual.has_method("reset_pose"):
		visual.call("reset_pose")
	_spawn_attack_burst(target.global_position + Vector3(0, 0.8, 0), Color(0.82, 0.56, 0.20), 1.55)
	_camera_shake(0.34, 0.16)


func _animate_quicksand(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s применяет «Зыбучие пески»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var origin: Vector3 = target.global_position + Vector3(0, 0.04, 0)
	for index: int in range(6):
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.18 + index * 0.11
		torus.outer_radius = 0.23 + index * 0.11
		ring.mesh = torus
		ring.rotation_degrees.x = 90.0
		ring.position = origin
		ring.material_override = _effect_material(Color(0.69, 0.47, 0.20, 0.78 - index * 0.08))
		add_child(ring)
		var tween: Tween = create_tween()
		ring.scale = Vector3.ZERO
		tween.tween_property(ring, "scale", Vector3.ONE * 1.45, 0.45 + index * 0.04)
		tween.parallel().tween_property(ring, "position:y", origin.y + 0.12, 0.45)
		tween.tween_property(ring, "scale", Vector3.ZERO, 0.18)
		tween.tween_callback(Callable(ring, "queue_free"))
	await get_tree().create_timer(0.65).timeout


func _spawn_sand_arc(position: Vector3, index: int) -> void:
	var particle: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.08 + float(index % 3) * 0.025
	sphere.height = sphere.radius * 1.4
	particle.mesh = sphere
	var angle: float = float(index) * 1.67
	particle.position = position + Vector3(cos(angle) * 0.58, float(index % 4) * 0.08, sin(angle) * 0.58)
	particle.material_override = _effect_material(Color(0.78, 0.54, 0.24, 0.66))
	add_child(particle)
	var tween: Tween = create_tween()
	tween.tween_property(particle, "position:y", particle.position.y + 0.65, 0.28)
	tween.parallel().tween_property(particle, "scale", Vector3.ZERO, 0.28)
	tween.tween_callback(Callable(particle, "queue_free"))


func _spawn_sand_column(position: Vector3) -> void:
	for index: int in range(10):
		_spawn_sand_arc(position + Vector3(0, 0.12, 0), index)
