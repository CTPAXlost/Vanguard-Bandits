extends "res://scripts/campaign_battle_v12.gd"

const MISSION_FIVE_PATH: String = "res://data/maps/mission_05.json"
const SADIRA_PORTRAIT: String = "res://assets/ui/portraits/sadira.png"
const FRANCO_PORTRAIT: String = "res://assets/ui/portraits/franco.png"
const HALAK_PORTRAIT: String = "res://assets/ui/portraits/halak.png"
const SHARKING_REINFORCEMENT_ROUND: int = 4

var mission_five_intro_pending: bool = false
var mission_five_choice_pending: bool = false
var mission_five_resolution_started: bool = false
var neutral_group_activated: bool = false
var neutral_group_team: String = "neutral"
var sadira_unit: Node3D
var franco_unit: Node3D
var halak_unit: Node3D
var mission_five_neutrals: Array[Node3D] = []
var mission_five_choice_dialog: ConfirmationDialog
var mission_five_choice_result: String = ""
var mission_five_aura_round: int = -1
var zakov_reinforcements_arrived: bool = false
var zakov_reinforcements_spawning: bool = false
var zakov_captains: Array[Node3D] = []
var zakov_barbatos: Array[Node3D] = []


func _ready() -> void:
	mission_five_intro_pending = CampaignState.current_mission == 5
	await super._ready()
	if mission_number != 5:
		return
	action_in_progress = true
	phase = Phase.DIALOGUE
	_clear_highlights()
	if not OS.has_feature("headless"):
		await _play_mission_five_intro()
	var forced_choice: String = CampaignState.test_forced_branch
	CampaignState.test_forced_branch = ""
	if forced_choice == "leave_castle":
		mission_five_choice_result = "leave_castle"
	elif forced_choice == "defend_castle" or OS.has_feature("headless"):
		mission_five_choice_result = "defend_castle"
	else:
		await _request_castle_choice()
	mission_five_intro_pending = false
	if mission_five_choice_result == "leave_castle":
		await _leave_castle_before_battle()
		return
	action_in_progress = false
	status_label.text = "Удержите оба входа в замок и уничтожьте армию Faulkner."
	_begin_player_turn()


func _load_first_mission() -> void:
	if CampaignState.current_mission != 5:
		super._load_first_mission()
		return
	mission_number = 5
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSION_FIVE_PATH))
	map_data = parsed as Dictionary if parsed is Dictionary else {"width": 30, "height": 18}
	grid_width = int(map_data.get("width", 30))
	grid_height = int(map_data.get("height", 18))
	blocked_cells = _cell_set(map_data.get("blocked_cells", []))
	river_cells = {}
	swamp_cells = {}
	title_label.text = str(map_data.get("name", "Глава V — Защита замка"))
	var parsed_balance: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if parsed_balance is Dictionary:
		balance_data = parsed_balance as Dictionary


func _build_map() -> void:
	super._build_map()
	if mission_number == 5:
		_build_defense_castle_geometry()


func _build_defense_castle_geometry() -> void:
	var castle: Dictionary = map_data.get("castle", {}) as Dictionary
	var min_x: int = int(castle.get("min_x", 10))
	var max_x: int = int(castle.get("max_x", 22))
	var min_z: int = int(castle.get("min_z", 1))
	var max_z: int = int(castle.get("max_z", 16))
	var west_x: int = int(castle.get("west_wall_x", min_x))
	var east_x: int = int(castle.get("east_wall_x", max_x))
	var gate_z_values: Array = castle.get("gate_z", [8, 9]) as Array
	var wall_size := Vector3(0.92, 1.65, 0.92)
	var wall_transforms: Array[Transform3D] = []
	for z: int in range(min_z, max_z + 1):
		if not gate_z_values.has(z):
			wall_transforms.append(Transform3D(Basis.IDENTITY, _cell_to_world(Vector2i(west_x, z)) + Vector3(0, wall_size.y * 0.5, 0)))
			wall_transforms.append(Transform3D(Basis.IDENTITY, _cell_to_world(Vector2i(east_x, z)) + Vector3(0, wall_size.y * 0.5, 0)))
	for x: int in range(min_x, max_x + 1):
		wall_transforms.append(Transform3D(Basis.IDENTITY, _cell_to_world(Vector2i(x, min_z)) + Vector3(0, wall_size.y * 0.5, 0)))
		wall_transforms.append(Transform3D(Basis.IDENTITY, _cell_to_world(Vector2i(x, max_z)) + Vector3(0, wall_size.y * 0.5, 0)))
	_create_box_multimesh("DefenseCastleWalls", wall_transforms, wall_size, Color(0.40, 0.42, 0.48), true)
	for tower_cell: Vector2i in [
		Vector2i(min_x, min_z), Vector2i(min_x, max_z),
		Vector2i(max_x, min_z), Vector2i(max_x, max_z)
	]:
		var tower: MeshInstance3D = MeshInstance3D.new()
		var tower_mesh: CylinderMesh = CylinderMesh.new()
		tower_mesh.top_radius = 0.68
		tower_mesh.bottom_radius = 0.82
		tower_mesh.height = 2.75
		tower_mesh.radial_segments = 8
		tower.mesh = tower_mesh
		tower.position = _cell_to_world(tower_cell) + Vector3(0, 1.37, 0)
		tower.material_override = _prop_material(Color(0.34, 0.36, 0.42))
		add_child(tower)
	_create_castle_gate("DefenseCastleGateWest", west_x, gate_z_values, true)
	_create_castle_gate("DefenseCastleGateEast", east_x, gate_z_values, false)


func _create_castle_gate(_gate_name: String, _gate_x: int, _gate_z_values: Array, _opens_west: bool) -> void:
	# The castle passage is deliberately completely open: no leaves, posts, lintel,
	# teeth or invisible blockers are created in the traversable gate cells.
	return


func _spawn_mission_units() -> void:
	if mission_number != 5:
		super._spawn_mission_units()
		return
	_spawn_mission_five_units()
	_setup_player_party()


func _spawn_mission_five_units() -> void:
	var starts: Dictionary = map_data.get("player_starts", {}) as Dictionary
	player_unit = _spawn_campaign_hero("bastion", "alba", _array_to_cell(starts.get("bastion", [15, 8])), "bastion_alba", BASTION_PORTRAIT_V12, "Наследник королевства • управляется игроком")
	_apply_unit_level(player_unit, "alba", int(CampaignState.get_character("bastion").get("level", 1)), 18, 18, 18, 18)
	var bastion_unit: Node3D = player_unit
	kamorge_unit = _spawn_campaign_hero("kamorge", "eigol", _array_to_cell(starts.get("kamorge", [16, 7])), "kamorge_eigol", KAMORGE_PORTRAIT, "Пустынный генерал • управляется игроком")
	_apply_unit_level(kamorge_unit, "eigol", 20, 35, 24, 31, 34)
	kamorge_unit.set_meta("magic_uses", 3)
	andrew_unit = _spawn_campaign_hero("andrew", "vedocorban", _array_to_cell(starts.get("andrew", [15, 10])), "andrew_vedocorban", ANDREW_PORTRAIT_V12, "Освобождённый рыцарь • управляется игроком")
	_apply_unit_level(andrew_unit, "vedocorban", 14, 29, 31, 24, 30)
	ione_unit = _spawn_campaign_hero("ione", "amphisia", _array_to_cell(starts.get("ione", [17, 6])), "ione_amphisia", IONE_PORTRAIT, "Разведчица партизан • управляется игроком")
	_apply_unit_level(ione_unit, "amphisia", 8, 22, 21, 23, 24)
	reyna_unit = _spawn_campaign_hero("reyna", "haurol", _array_to_cell(starts.get("reyna", [17, 11])), "reyna_haurol", REYNA_PORTRAIT, "Копейщица партизан • управляется игроком")
	_apply_unit_level(reyna_unit, "haurol", 10, 25, 27, 25, 27)
	var zeira_start: Vector2i = _array_to_cell(starts.get("zeira", [19, 8]))
	var zeira_unit_five: Node3D = _spawn_campaign_hero("zeira", "toreadore", zeira_start, "zeira_toreadore", ZEIRA_PORTRAIT, "Предводитель партизан • управляется игроком")
	_apply_unit_level(zeira_unit_five, "toreadore", 18, 42, 32, 41, 40)
	zeira_unit_five.set_meta("passive_ability", "toreadore_rear_kick")
	zeira_unit_five.set_meta("max_move_actions", 2)
	zeira_unit_five.set_meta("energy_restore_uses", 3)
	zeira_unit_five.set_meta("rear_kick_multiplier", 2.0)
	zeira_unit_five.set_meta("rear_kick_distance", 5)
	galvas_unit = _spawn_campaign_hero("galvas", "serata", _array_to_cell(starts.get("galvas", [19, 10])), "galvas_serata", GALVAS_PORTRAIT, "Падший король • управляется игроком")
	_apply_unit_level(galvas_unit, "serata", 18, 39, 27, 35, 38)
	galvas_unit.set_meta("passive_ability", "serata_restoration_aura")

	var enemies: Dictionary = map_data.get("enemy_starts", {}) as Dictionary
	faulkner_unit = _spawn_enemy_profile("Faulkner / Solarus", "Генерал восточной армии • уровень 25", "solarus", _array_to_cell(enemies.get("faulkner", [3, 8])), "faulkner_solarus", "faulkner", FAULKNER_PORTRAIT, true)
	_apply_unit_level(faulkner_unit, "solarus", 25, 48, 34, 42, 46)
	faulkner_unit.set_meta("heals_remaining", 3)
	faulkner_unit.set_meta("initial_castle_attacker", true)
	duyere_unit = _spawn_enemy_profile("Duyere / Sarbelas", "Принц Восточного королевства • уровень 12", "sarbelas", _array_to_cell(enemies.get("duyere", [4, 10])), "duyere_sarbelas", "duyere", DUYERE_PORTRAIT, true)
	_apply_unit_level(duyere_unit, "sarbelas", 12, 27, 29, 24, 28)
	duyere_unit.set_meta("initial_castle_attacker", true)
	for index: int in range((enemies.get("barbatos", []) as Array).size()):
		var barbatos: Node3D = _spawn_enemy_profile(
			"Barbatos %d" % (index + 1),
			"Штурмовой солдат Faulkner • уровень 12",
			"barbatos",
			_array_to_cell((enemies.get("barbatos", []) as Array)[index]),
			"imperial_soldier",
			"imperial_soldier",
			IMPERIAL_PORTRAIT,
			false
		)
		_apply_unit_level(barbatos, "barbatos", 12, 25, 18, 22, 24)
		barbatos.set_meta("initial_castle_attacker", true)

	var neutrals: Dictionary = map_data.get("neutral_starts", {}) as Dictionary
	sadira_unit = _spawn_neutral_profile("Sadira / Sylpheed", "Сестра Duyere • нейтральный наблюдатель • уровень 8", "sylpheed", _array_to_cell(neutrals.get("sadira", [17, 17])), "sadira_sylpheed", SADIRA_PORTRAIT)
	_apply_unit_level(sadira_unit, "sylpheed", 8, 23, 34, 20, 29)
	sadira_unit.set_meta("passive_ability", "sylpheed_air_counter")
	sadira_unit.set_meta("energy_restore_uses", 3)
	franco_unit = _spawn_neutral_profile("Franco / Korbelan", "Телохранитель Sadira • нейтральный • уровень 25", "korbelan", _array_to_cell(neutrals.get("franco", [15, 17])), "franco_korbelan", FRANCO_PORTRAIT)
	_apply_unit_level(franco_unit, "korbelan", 25, 47, 25, 46, 43)
	franco_unit.set_meta("passive_ability", "steel_armor")
	halak_unit = _spawn_neutral_profile("Halak / Korbelan", "Телохранитель Sadira • нейтральный • уровень 25", "korbelan", _array_to_cell(neutrals.get("halak", [19, 17])), "halak_korbelan", HALAK_PORTRAIT)
	_apply_unit_level(halak_unit, "korbelan", 25, 47, 25, 46, 43)
	halak_unit.set_meta("passive_ability", "steel_armor")
	mission_five_neutrals = [sadira_unit, franco_unit, halak_unit]
	# Keep an explicit reference to avoid an unused local warning in strict builds.
	bastion_unit.set_meta("castle_defender", true)


func _spawn_neutral_profile(label: String, role: String, slug: String, cell: Vector2i, profile: String, portrait_path: String) -> Node3D:
	var unit: Node3D = _spawn_unit(label, role, slug, cell, false, true, "neutral", profile)
	if unit == null:
		push_error("Failed to spawn neutral profile: %s / %s" % [label, slug])
		return null
	unit.set_meta("character_id", label.to_lower().split(" / ")[0])
	unit.set_meta("combat_profile", profile)
	unit.set_meta("portrait_path", portrait_path)
	unit.set_meta("model_slug", slug)
	unit.set_meta("facing_chosen", true)
	unit.set_meta("reaction_system", "ai_defend_dodge")
	unit.set_meta("neutral_observer", true)
	var ring: MeshInstance3D = unit.get_node_or_null("SelectionRing") as MeshInstance3D
	if ring != null:
		var ring_material: StandardMaterial3D = StandardMaterial3D.new()
		ring_material.albedo_color = Color(0.92, 0.76, 0.25)
		ring_material.emission_enabled = true
		ring_material.emission = Color(0.62, 0.42, 0.08)
		ring.material_override = ring_material
	return unit


func _apply_unit_level(unit: Node3D, slug: String, level: int, strength: int, agility: int, defense: int, attack_skill: int) -> void:
	if unit == null:
		return
	var data: Dictionary = CampaignState.ATAC_DATA.get(slug, CampaignState.ATAC_DATA["alba"]) as Dictionary
	var stats: Dictionary = _stats(unit)
	stats["level"] = level
	stats["max_hp"] = int(data.get("base_hp", 180)) + (level - 1) * int(data.get("hp_per_level", 8))
	stats["hp"] = int(stats["max_hp"])
	stats["strength"] = strength
	stats["agility"] = agility
	stats["defense"] = defense
	stats["attack_skill"] = attack_skill
	stats["weapon_power"] = maxi(int(stats.get("weapon_power", 0)), int(round(float(level) * 0.75)))
	stats["max_energy"] = 100
	stats["energy"] = 100
	stats["max_fatigue"] = 100
	stats["fatigue"] = 0
	stats["move_range"] = int(data.get("move_range", 6))
	stats["atac_name"] = str(data.get("name", slug.capitalize()))
	stats["equipment"] = str(data.get("equipment", "Броня ATAC"))
	unit.set_meta("stats", stats)
	_refresh_hp_bar(unit)


func _setup_player_party() -> void:
	if mission_number != 5:
		super._setup_player_party()
		return
	player_party.clear()
	for member: Node3D in [player_unit, kamorge_unit, andrew_unit, ione_unit, reyna_unit, galvas_unit]:
		if member != null:
			member.set_meta("player", true)
			player_party.append(member)
	# Zeira is located by character id because v12 keeps her in a local variable.
	for candidate: Node3D in units:
		if str(candidate.get_meta("character_id", "")) == "zeira":
			candidate.set_meta("player", true)
			player_party.append(candidate)
			break


func _begin_player_turn() -> void:
	if mission_five_intro_pending:
		return
	if mission_number == 5 and _should_spawn_zakov_reinforcements():
		if not zakov_reinforcements_spawning:
			zakov_reinforcements_spawning = true
			action_in_progress = true
			phase = Phase.DIALOGUE
			# Start the coroutine immediately. The old deferred string call could be
			# skipped while the turn state changed in the same frame, leaving the
			# entire Zakov wave absent both in-game and in the runtime smoke test.
			_start_zakov_reinforcement_spawn()
		return
	if mission_number == 5 and mission_five_aura_round != round_number:
		mission_five_aura_round = round_number
		_apply_serata_aura()
	super._begin_player_turn()


func _start_zakov_reinforcement_spawn() -> void:
	# Calling an async GDScript function starts it immediately and it continues
	# after each await. In headless mode the dialogue awaits are skipped, so the
	# complete six-unit wave is created in the same frame.
	_spawn_zakov_reinforcements_async()


func _should_spawn_zakov_reinforcements() -> bool:
	if mission_number != 5 or zakov_reinforcements_arrived or zakov_reinforcements_spawning or mission_five_resolution_started:
		return false
	if round_number >= SHARKING_REINFORCEMENT_ROUND:
		return true
	if faulkner_unit != null and is_instance_valid(faulkner_unit) and _is_alive(faulkner_unit):
		var faulkner_stats: Dictionary = _stats(faulkner_unit)
		if int(faulkner_stats.get("hp", 0)) <= int(float(faulkner_stats.get("max_hp", 1)) * 0.60):
			return true
	return _initial_assault_defeated()


func _initial_assault_defeated() -> bool:
	var found_initial: bool = false
	for unit: Node3D in units:
		if not bool(unit.get_meta("initial_castle_attacker", false)):
			continue
		found_initial = true
		if _is_alive(unit):
			return false
	return found_initial


func _spawn_zakov_reinforcements_async() -> void:
	if zakov_reinforcements_arrived or mission_five_resolution_started:
		zakov_reinforcements_spawning = false
		return
	zakov_reinforcements_arrived = true
	_clear_highlights()
	phase_label.text = "ПОДКРЕПЛЕНИЕ ВРАГА"
	status_label.text = "К полю боя подходит Zakov на тяжёлом ATAC Sharking."
	var starts: Dictionary = map_data.get("reinforcement_starts", {}) as Dictionary
	zakov_unit = _spawn_enemy_profile(
		"Zakov / Sharking",
		"Генерал подкрепления • уровень 25 • силовая броня",
		"sharking",
		_array_to_cell(starts.get("zakov", [1, 9])),
		"zakov_sharking",
		"zakov",
		ZAKOV_PORTRAIT,
		true
	)
	_apply_unit_level(zakov_unit, "sharking", 25, 50, 28, 48, 48)
	if zakov_unit != null:
		var sharking_stats: Dictionary = _stats(zakov_unit)
		sharking_stats["armor"] = 250
		sharking_stats["max_armor"] = 250
		sharking_stats["move_range"] = 10
		sharking_stats["energy"] = 100
		sharking_stats["max_energy"] = 100
		zakov_unit.set_meta("stats", sharking_stats)
		zakov_unit.set_meta("passive_ability", "sharking_front_reflect")
		zakov_unit.set_meta("armor_regen", 50)
		zakov_unit.set_meta("reinforcement_wave", true)
		zakov_unit.set_meta("reinforcement_role", "zakov_commander")
		zakov_unit.set_meta("character_id", "zakov")
		zakov_unit.set_meta("combat_profile", "zakov")
		_refresh_hp_bar(zakov_unit)
	# The wave composition is fixed by design. Do not derive the unit count from
	# the JSON array length: malformed or stale map data must not silently remove
	# one of Zakov's escorts and block the Windows build.
	zakov_captains.clear()
	var captain_defaults: Array = [[1, 6], [1, 12]]
	var captain_starts: Array = starts.get("captains", captain_defaults) as Array
	for index: int in range(2):
		var raw_captain_cell: Variant = captain_starts[index] if index < captain_starts.size() else captain_defaults[index]
		var captain: Node3D = _spawn_enemy_profile(
			"Captain Soldier %d" % (index + 1),
			"Элитный капитан Zakov • уровень 25",
			"einlager",
			_array_to_cell(raw_captain_cell),
			"captain_einlager_25",
			"captain_soldiers",
			CAPTAIN_PORTRAIT,
			true
		)
		_apply_unit_level(captain, "einlager", 25, 45, 28, 41, 44)
		if captain != null:
			captain.set_meta("reinforcement_wave", true)
			captain.set_meta("reinforcement_role", "zakov_captain")
			captain.set_meta("reinforcement_index", index)
			zakov_captains.append(captain)
	zakov_barbatos.clear()
	var barbatos_defaults: Array = [[0, 4], [0, 8], [0, 14]]
	var barbatos_starts: Array = starts.get("barbatos", barbatos_defaults) as Array
	for index: int in range(3):
		var raw_barbatos_cell: Variant = barbatos_starts[index] if index < barbatos_starts.size() else barbatos_defaults[index]
		var barbatos: Node3D = _spawn_enemy_profile(
			"Barbatos подкрепления %d" % (index + 1),
			"Штурмовой солдат Zakov • уровень 12",
			"barbatos",
			_array_to_cell(raw_barbatos_cell),
			"imperial_soldier",
			"imperial_soldier",
			IMPERIAL_PORTRAIT,
			false
		)
		_apply_unit_level(barbatos, "barbatos", 12, 25, 18, 22, 24)
		if barbatos != null:
			barbatos.set_meta("reinforcement_wave", true)
			barbatos.set_meta("reinforcement_role", "zakov_barbatos")
			barbatos.set_meta("reinforcement_index", index)
			zakov_barbatos.append(barbatos)
	_refresh_ui()
	if not OS.has_feature("headless"):
		await _show_dialogue("Zakov", "Вы слишком рано решили, что победили. Sharking разнесёт ваши ворота вместе с защитниками.", ZAKOV_PORTRAIT)
		if _is_alive(faulkner_unit):
			await _show_dialogue("Faulkner", "Наконец-то. Сломай их оборону и не оставь Bastion пути к отступлению.", FAULKNER_PORTRAIT)
		await _show_dialogue("Bastion", "Ещё один генерал и пять машин. Всем занять позиции у ворот!", BASTION_PORTRAIT_V12)
		await _show_dialogue("Kamorge", "Пусть подходит. У каждой брони есть предел — даже у Sharking.", KAMORGE_PORTRAIT)
	zakov_reinforcements_spawning = false
	action_in_progress = false
	if mission_five_aura_round != round_number:
		mission_five_aura_round = round_number
		_apply_serata_aura()
	super._begin_player_turn()


func _all_enemies_defeated() -> bool:
	if mission_number == 5 and not zakov_reinforcements_arrived:
		return false
	return super._all_enemies_defeated()


func _request_castle_choice() -> void:
	mission_five_choice_pending = true
	mission_five_choice_dialog = ConfirmationDialog.new()
	mission_five_choice_dialog.title = "Решение у освобождённого замка"
	mission_five_choice_dialog.dialog_text = (
		"Разведчики сообщают: Faulkner ведёт новую армию к воротам.\n\n"
		+ "Защитить замок — принять тяжёлый бой и сохранить оружейную.\n"
		+ "Покинуть замок — сохранить отряд и уйти на юг к Logan."
	)
	mission_five_choice_dialog.ok_button_text = "Защитить замок"
	mission_five_choice_dialog.cancel_button_text = "Покинуть замок"
	mission_five_choice_dialog.confirmed.connect(_on_defend_castle_selected)
	mission_five_choice_dialog.canceled.connect(_on_leave_castle_selected)
	add_child(mission_five_choice_dialog)
	mission_five_choice_dialog.popup_centered(Vector2i(720, 360))
	await mission_five_choice_dialog.tree_exited
	mission_five_choice_pending = false


func _on_defend_castle_selected() -> void:
	mission_five_choice_result = "defend_castle"
	if mission_five_choice_dialog != null:
		mission_five_choice_dialog.queue_free()


func _on_leave_castle_selected() -> void:
	mission_five_choice_result = "leave_castle"
	if mission_five_choice_dialog != null:
		mission_five_choice_dialog.queue_free()


func _play_mission_five_intro() -> void:
	await _show_dialogue("Galvas", "Bastion и Andrew свободны. Но дозор сообщает о новой армии у западной дороги. Faulkner идёт вернуть замок.", GALVAS_PORTRAIT)
	await _show_dialogue("Bastion", "Мы только что вернули эти стены. Если отступим сейчас, людям снова некуда будет возвращаться.", BASTION_PORTRAIT_V12)
	await _show_dialogue("Kamorge", "Faulkner двадцать пятого уровня. Он не даст нам времени восстановиться, но Eigol готов держать ворота.", KAMORGE_PORTRAIT)
	await _show_dialogue("Faulkner", "Замок не принадлежит беглому королю. Отдайте Bastion и сложите оружие — иначе стены станут вашей могилой.", FAULKNER_PORTRAIT)
	await _show_dialogue("Duyere", "На этот раз я не уйду первым. Sadira наблюдает справа от южной стены... хотя никогда не выбирает сторону.", DUYERE_PORTRAIT)
	await _show_dialogue("Sadira", "Я пришла увидеть, ради чего брат снова рискует жизнью. Franco, Halak — не вмешиваться. Пока нас не тронут.", SADIRA_PORTRAIT)
	await _show_dialogue("Franco", "Korbelan останется в боевой готовности. Любой, кто поднимет оружие на госпожу, станет нашей целью.", FRANCO_PORTRAIT)
	await _show_dialogue("Halak", "И неважно, под каким знаменем он пришёл.", HALAK_PORTRAIT)


func _leave_castle_before_battle() -> void:
	mission_five_resolution_started = true
	phase = Phase.DEFEAT
	_set_action_buttons(true)
	phase_label.text = "ОТРЯД ПОКИДАЕТ ЗАМОК"
	status_label.text = "Герои сохраняют силы и уходят через южную лесную дорогу."
	if not OS.has_feature("headless"):
		await _show_dialogue("Galvas", "Мне тяжело снова оставить собственный замок. Но мёртвый король никому не поможет.", GALVAS_PORTRAIT)
		await _show_dialogue("Bastion", "На юге живёт Logan. Если старые клятвы ещё что-то значат, он даст нам людей и безопасный путь.", BASTION_PORTRAIT_V12)
		await _show_dialogue("Kamorge", "Тогда идём лесами. Вернёмся сюда с армией, которую Faulkner уже не сможет раздавить.", KAMORGE_PORTRAIT)
	CampaignState.complete_mission(5, "left_castle")
	call_deferred("_return_to_campaign_hub")


func _return_to_campaign_hub() -> void:
	get_tree().change_scene_to_file(HUB_SCENE_PATH)


func _eligible_targets(attacker: Node3D, mode: String) -> Array[Node3D]:
	var result: Array[Node3D] = super._eligible_targets(attacker, mode)
	if mission_number != 5 or neutral_group_activated:
		return result
	var data: Dictionary = CombatCatalog.attack(mode)
	var required_range: int = int(data.get("range", 1))
	var range_mode: String = str(data.get("range_mode", "exact"))
	for neutral: Node3D in mission_five_neutrals:
		if not _is_alive(neutral):
			continue
		var distance: int = _grid_distance(attacker, neutral)
		if range_mode == "up_to":
			if distance < 1 or distance > required_range:
				continue
		elif distance != required_range:
			continue
		if mode in ["long_lunge", "bright_bomb"] and required_range == 2 and not _has_clear_long_lunge_line(attacker, neutral):
			continue
		if not result.has(neutral):
			result.append(neutral)
	return result


func _player_attack_target(mode: String = "slash") -> Node3D:
	if selected_unit == null or not _is_alive(selected_unit):
		return null
	var selected_team: String = str(selected_unit.get_meta("team"))
	if selected_team not in ["enemy", "neutral"]:
		return null
	return selected_unit if _eligible_targets(player_unit, mode).has(selected_unit) else null


func _nearest_opponent(unit: Node3D) -> Node3D:
	var normal_target: Node3D = super._nearest_opponent(unit)
	if mission_number != 5 or neutral_group_activated:
		return normal_target
	if str(unit.get_meta("team")) not in ["ally", "enemy"]:
		return normal_target
	var nearest_neutral: Node3D
	var nearest_distance: int = 9999
	for neutral: Node3D in mission_five_neutrals:
		if not _is_alive(neutral):
			continue
		var distance: int = _grid_distance(unit, neutral)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_neutral = neutral
	if nearest_neutral == null:
		return normal_target
	if normal_target == null or nearest_distance + 1 < _grid_distance(unit, normal_target):
		return nearest_neutral
	return normal_target


func _resolve_attack(attacker: Node3D, target: Node3D, mode: String) -> void:
	if mission_number == 5 and str(target.get_meta("team")) == "neutral":
		await _activate_neutral_group(attacker)
	attacker.set_meta("resolving_attack_mode", mode)
	if mode == "incinerate" and rng.randf() <= 0.40:
		status_label.text = "«Испепелить» пробивает защиту и наносит ровно 400 HP!"
		await _damage_target(target, 400)
		attacker.set_meta("resolving_attack_mode", "")
		return
	await super._resolve_attack(attacker, target, mode)
	if mode == "guillotine" and _is_alive(target) and rng.randf() <= 0.45:
		target.set_meta("disabled_turns", maxi(1, int(target.get_meta("disabled_turns", 0))))
		status_label.text = "%s теряет управление ATAC на один ход!" % str(target.get_meta("label"))
		_spawn_trap_effect(target.global_position)
	attacker.set_meta("resolving_attack_mode", "")
	if target != null and is_instance_valid(target):
		target.set_meta("steel_armor_active", false)


func _activate_neutral_group(attacker: Node3D) -> void:
	if neutral_group_activated:
		return
	neutral_group_activated = true
	neutral_group_team = "enemy" if str(attacker.get_meta("team")) == "ally" else "ally"
	for neutral: Node3D in mission_five_neutrals:
		if neutral == null or not is_instance_valid(neutral):
			continue
		neutral.set_meta("team", neutral_group_team)
		neutral.set_meta("neutral_observer", false)
		neutral.set_meta("player", false)
		var ring: MeshInstance3D = neutral.get_node_or_null("SelectionRing") as MeshInstance3D
		if ring != null:
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.24, 0.18) if neutral_group_team == "enemy" else Color(0.30, 0.95, 0.55)
			mat.emission_enabled = true
			mat.emission = mat.albedo_color * 0.75
			ring.material_override = mat
	if not OS.has_feature("headless"):
		await _show_dialogue("Sadira", "Вы сделали свой выбор. Sylpheed поднимается в воздух — теперь мы вступаем в бой против того, кто ударил первым.", SADIRA_PORTRAIT)
		await _show_dialogue("Franco", "Korbelan, режим стальной брони. Защитить Sadira.", FRANCO_PORTRAIT)
		await _show_dialogue("Halak", "Гильотины готовы. Никто не уйдёт безнаказанным.", HALAK_PORTRAIT)
	status_label.text = "Отряд Sadira вступает в бой против стороны, которая его атаковала."


func _try_automatic_passive(defender: Node3D, attacker: Node3D, back_attack: bool) -> String:
	var passive: String = str(defender.get_meta("passive_ability", ""))
	if passive == "sylpheed_air_counter":
		var chance: float = 0.80 if back_attack else 0.60
		if rng.randf() <= chance:
			status_label.text = "Sylpheed взмывает в воздух, уклоняется и контратакует!"
			await _animate_sylpheed_air_dodge(defender, attacker)
			if _is_alive(attacker):
				var counter_mode: String = "wind_strike" if int(_stats(defender).get("energy", 0)) >= 25 else "lunge"
				if counter_mode == "wind_strike":
					_spend_energy(defender, 25)
				await _play_attack_animation(defender, attacker, counter_mode)
				await _damage_target(attacker, maxi(1, _calculate_damage(defender, attacker, 0.95)))
			return "avoided"
	if passive == "sharking_front_reflect" and _is_front_attack(attacker, defender) and rng.randf() <= 0.70:
		status_label.text = "Силовое поле Sharking отражает фронтальную атаку!"
		await _animate_sharking_reflect(defender, attacker)
		if _is_alive(attacker):
			await _damage_target(attacker, maxi(1, _calculate_damage(defender, attacker, 0.70)))
		return "avoided"
	if passive == "steel_armor" and rng.randf() <= 0.60:
		defender.set_meta("steel_armor_active", true)
		status_label.text = "Стальная броня Korbelan снижает входящий урон вдвое."
		_spawn_guard_flash(defender.global_position + Vector3(0, 1.0, 0), Color(0.80, 0.88, 1.0))
	return await super._try_automatic_passive(defender, attacker, back_attack)


func _is_front_attack(attacker: Node3D, defender: Node3D) -> bool:
	if attacker == null or defender == null:
		return false
	var direction_to_attacker: Vector3 = (attacker.position - defender.position).normalized()
	var defender_forward: Vector3 = -defender.global_transform.basis.z.normalized()
	return defender_forward.dot(direction_to_attacker) > 0.42


func _damage_target(target: Node3D, damage: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	var stats: Dictionary = _stats(target)
	var armor: int = int(stats.get("armor", 0))
	if armor > 0 and damage > 0:
		var absorbed: int = mini(armor, damage)
		stats["armor"] = armor - absorbed
		target.set_meta("stats", stats)
		_refresh_hp_bar(target)
		_spawn_damage_label(target.global_position + Vector3(0, 2.65, 0), absorbed)
		_spawn_guard_flash(target.global_position + Vector3(0, 1.0, 0), Color(0.18, 0.72, 1.0))
		damage -= absorbed
		status_label.text = "Броня Sharking поглощает %d урона. Осталось брони: %d." % [absorbed, int(stats.get("armor", 0))]
		if damage <= 0:
			return
	await super._damage_target(target, damage)


func _refresh_hp_bar(unit: Node3D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var label: Label3D = unit.get_node_or_null("HPBar") as Label3D
	if label == null:
		return
	var stats: Dictionary = _stats(unit)
	var armor: int = int(stats.get("armor", 0))
	var max_armor: int = int(stats.get("max_armor", 0))
	if max_armor > 0:
		label.text = "БР %d | HP %d" % [armor, int(stats.get("hp", 0))]
		label.modulate = Color(0.38, 0.85, 1.0) if armor > 0 else Color.WHITE
		if int(stats.get("hp", 0)) <= int(stats.get("max_hp", 1)) / 3:
			label.modulate = Color(1.0, 0.32, 0.24)
		return
	super._refresh_hp_bar(unit)


func _refresh_ui() -> void:
	super._refresh_ui()
	if selected_unit == null or not is_instance_valid(selected_unit):
		return
	var stats: Dictionary = _stats(selected_unit)
	var max_armor: int = int(stats.get("max_armor", 0))
	if max_armor > 0:
		equipment_label.text += "\nБроня силового поля: %d / %d (+50 каждый ход)" % [int(stats.get("armor", 0)), max_armor]


func _calculate_damage(attacker: Node3D, target: Node3D, multiplier: float) -> int:
	var damage: int = super._calculate_damage(attacker, target, multiplier)
	if bool(target.get_meta("steel_armor_active", false)):
		damage = maxi(1, int(round(float(damage) * 0.50)))
	var character_id: String = str(attacker.get_meta("character_id", ""))
	var stone_effect: String = CampaignState.character_stone_effect(character_id) if not character_id.is_empty() else ""
	var mode: String = str(attacker.get_meta("resolving_attack_mode", ""))
	if stone_effect == "strong_slash_10" and mode == "strong_slash":
		damage = maxi(1, int(round(float(damage) * 1.10)))
	elif stone_effect == "elemental_10" and mode in ["ice_rain", "ball_lightning", "sound_strike", "wind_strike"]:
		damage = maxi(1, int(round(float(damage) * 1.10)))
	return damage


func _choose_ai_attack(unit: Node3D, target: Node3D) -> String:
	var modes: Array[String] = CombatCatalog.attacks_for(unit)
	var distance: int = _grid_distance(unit, target)
	for preferred: String in [
		"force_field_throw", "sharking_strong_slash", "sharking_slash",
		"guillotine", "incinerate", "wind_strike", "sound_strike",
		"slide", "ice_rain", "ultrasound", "spear_throw", "quicksand",
		"desert_storm", "sticky_sandstorm", "fire_rain", "bright_bomb", "earthquake",
		"tornado", "strong_slash", "ball_lightning", "long_lunge", "lunge", "slash"
	]:
		if not modes.has(preferred):
			continue
		var data: Dictionary = CombatCatalog.attack(preferred)
		var attack_range: int = int(data.get("range", 1))
		var range_mode: String = str(data.get("range_mode", "exact"))
		if range_mode == "up_to":
			if distance < 1 or distance > attack_range:
				continue
		elif distance != attack_range:
			continue
		var costs: Dictionary = CombatCatalog.resource_cost(preferred)
		if _can_spend_fatigue(unit, int(costs.get("fatigue", 0))) and _can_spend_energy(unit, int(costs.get("energy", 0))):
			return preferred
	return "slash"


func _run_smart_ai_turn(unit: Node3D) -> void:
	if mission_number == 5 and str(unit.get_meta("model_slug", "")) == "sharking":
		var last_regen_round: int = int(unit.get_meta("armor_regen_round", -1))
		if last_regen_round != round_number:
			unit.set_meta("armor_regen_round", round_number)
			var sharking_stats: Dictionary = _stats(unit)
			var max_armor: int = int(sharking_stats.get("max_armor", 250))
			var before_armor: int = int(sharking_stats.get("armor", 0))
			sharking_stats["armor"] = mini(max_armor, before_armor + int(unit.get_meta("armor_regen", 50)))
			unit.set_meta("stats", sharking_stats)
			_refresh_hp_bar(unit)
			if int(sharking_stats["armor"]) > before_armor:
				status_label.text = "Sharking восстанавливает %d брони." % (int(sharking_stats["armor"]) - before_armor)
				_spawn_guard_flash(unit.global_position + Vector3(0, 1.0, 0), Color(0.20, 0.78, 1.0))
				await get_tree().create_timer(0.22).timeout
	if mission_number == 5 and unit == sadira_unit and neutral_group_activated:
		var sadira_stats: Dictionary = _stats(unit)
		var restore_uses: int = int(unit.get_meta("energy_restore_uses", 0))
		if restore_uses > 0 and int(sadira_stats.get("energy", 0)) <= 45:
			sadira_stats["energy"] = mini(int(sadira_stats.get("max_energy", 100)), int(sadira_stats.get("energy", 0)) + 50)
			unit.set_meta("stats", sadira_stats)
			unit.set_meta("energy_restore_uses", restore_uses - 1)
			status_label.text = "Sadira восстанавливает 50% энергии и пропускает ход (%d применения осталось)." % (restore_uses - 1)
			_spawn_heal_effect(unit.global_position + Vector3(0, 1.2, 0))
			await get_tree().create_timer(0.65).timeout
			return
	if mission_number == 5 and unit in [franco_unit, halak_unit] and neutral_group_activated:
		var guard_stats: Dictionary = _stats(unit)
		if int(guard_stats.get("healing_block_turns", 0)) <= 0 and int(guard_stats.get("hp", 0)) < int(float(guard_stats.get("max_hp", 1)) * 0.48):
			guard_stats["hp"] = mini(int(guard_stats.get("max_hp", 1)), int(guard_stats.get("hp", 0)) + 150)
			unit.set_meta("stats", guard_stats)
			_refresh_hp_bar(unit)
			status_label.text = "%s применяет лечение: +150 HP и пропускает ход." % str(unit.get_meta("label"))
			_spawn_heal_effect(unit.global_position + Vector3(0, 1.2, 0))
			await get_tree().create_timer(0.65).timeout
			return
	await super._run_smart_ai_turn(unit)


func _try_disoriented_friendly_fire(unit: Node3D) -> bool:
	# Friendly fire is reached only from the explicit disorientation branch in
	# _run_enemy_phase. Zakov follows the same rule: never attacks allies during
	# normal AI, but can do so when a real disorientation effect is active.
	return await super._try_disoriented_friendly_fire(unit)


func _activate_player_member(member: Node3D) -> void:
	if int(member.get_meta("disabled_turns", 0)) > 0:
		member.set_meta("disabled_turns", maxi(0, int(member.get_meta("disabled_turns", 0)) - 1))
		action_in_progress = true
		status_label.text = "%s потерял управление и пропускает ход." % str(member.get_meta("label"))
		member.set_meta("facing_chosen", true)
		call_deferred("_finish_disabled_player_turn")
		return
	super._activate_player_member(member)


func _play_attack_animation(attacker: Node3D, target: Node3D, mode: String) -> void:
	match mode:
		"sound_strike":
			await _animate_sound_strike(attacker, target)
		"wind_strike":
			await _animate_wind_strike(attacker, target)
		"incinerate":
			await _animate_incinerate(attacker, target)
		"guillotine":
			await _animate_guillotine(attacker, target)
		"force_field_throw":
			await _animate_force_field_throw(attacker, target)
		"fire_rain":
			await _animate_fire_rain(attacker, target)
		"sharking_slash":
			await super._play_attack_animation(attacker, target, "slash")
		"sharking_strong_slash":
			await super._play_attack_animation(attacker, target, "strong_slash")
		_:
			await super._play_attack_animation(attacker, target, mode)


func _animate_fire_rain(attacker: Node3D, target: Node3D) -> void:
	_face_target(attacker, target)
	status_label.text = "%s использует «Град огня с неба»" % str(attacker.get_meta("label"))
	var centre: Vector3 = target.global_position + Vector3(0, 1.0, 0)
	for meteor_index: int in range(6):
		var meteor := MeshInstance3D.new()
		var meteor_mesh := SphereMesh.new()
		meteor_mesh.radius = 0.11 + float(meteor_index % 2) * 0.03
		meteor_mesh.height = meteor_mesh.radius * 2.0
		meteor.mesh = meteor_mesh
		meteor.global_position = centre + Vector3(rng.randf_range(-1.2, 1.2), 3.4 + float(meteor_index) * 0.18, rng.randf_range(-1.2, 1.2))
		meteor.material_override = _effect_material(Color(1.0, 0.34, 0.08, 0.95))
		add_child(meteor)
		var impact: Vector3 = centre + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.10, 0.30), rng.randf_range(-0.6, 0.6))
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_interval(float(meteor_index) * 0.055)
		tween.tween_property(meteor, "global_position", impact, 0.18)
		tween.tween_callback(Callable(self, "_spawn_incinerate_explosion").bind(impact))
		tween.tween_property(meteor, "scale", Vector3.ZERO, 0.05)
		tween.tween_callback(Callable(meteor, "queue_free"))
	await get_tree().create_timer(0.56).timeout
	_camera_shake(0.62, 0.28)


func _animate_force_field_throw(attacker: Node3D, target: Node3D) -> void:
	_face_target(attacker, target)
	status_label.text = "%s использует «Бросок силового поля»" % str(attacker.get_meta("label"))
	var origin: Vector3 = attacker.global_position + Vector3(0, 1.10, 0)
	var finish: Vector3 = target.global_position + Vector3(0, 1.05, 0)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.43
	disc_mesh.bottom_radius = 0.43
	disc_mesh.height = 0.055
	disc_mesh.radial_segments = 32
	disc.mesh = disc_mesh
	disc.global_position = origin
	disc.look_at(finish, Vector3.UP)
	disc.rotation_degrees.x += 90.0
	disc.material_override = _effect_material(Color(0.14, 0.72, 1.0, 0.94))
	add_child(disc)
	for ring_index: int in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.24 + float(ring_index) * 0.08
		torus.outer_radius = 0.29 + float(ring_index) * 0.08
		torus.rings = 24
		torus.ring_segments = 7
		ring.mesh = torus
		ring.global_position = origin
		ring.rotation = disc.rotation
		ring.material_override = _effect_material(Color(0.55, 0.94, 1.0, 0.86))
		add_child(ring)
		var ring_tween: Tween = create_tween()
		ring_tween.tween_property(ring, "global_position", finish, 0.34 + float(ring_index) * 0.025)
		ring_tween.parallel().tween_property(ring, "rotation_degrees:z", 720.0 * (1.0 if ring_index % 2 == 0 else -1.0), 0.34)
		ring_tween.tween_property(ring, "scale", Vector3.ZERO, 0.08)
		ring_tween.tween_callback(Callable(ring, "queue_free"))
	var tween: Tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(disc, "global_position", finish, 0.34)
	tween.parallel().tween_property(disc, "rotation_degrees:z", 900.0, 0.34)
	tween.tween_callback(Callable(self, "_spawn_force_field_impact").bind(finish))
	tween.tween_property(disc, "scale", Vector3.ZERO, 0.07)
	tween.tween_callback(Callable(disc, "queue_free"))
	await tween.finished


func _spawn_force_field_impact(position: Vector3) -> void:
	for index: int in range(14):
		var angle: float = TAU * float(index) / 14.0
		_spawn_attack_burst(position + Vector3(cos(angle) * 0.36, sin(angle * 2.0) * 0.18, sin(angle) * 0.36), Color(0.18, 0.72 + float(index % 3) * 0.08, 1.0), 0.34 + float(index % 4) * 0.06)
	_spawn_guard_flash(position, Color(0.18, 0.78, 1.0))
	_camera_shake(0.42, 0.20)


func _animate_sharking_reflect(defender: Node3D, attacker: Node3D) -> void:
	var centre: Vector3 = defender.global_position + Vector3(0, 1.0, 0)
	for layer: int in range(3):
		var shell := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.58 + float(layer) * 0.10
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 24
		sphere.rings = 12
		shell.mesh = sphere
		shell.global_position = centre
		shell.material_override = _effect_material(Color(0.12 + float(layer) * 0.08, 0.64, 1.0, 0.25))
		add_child(shell)
		shell.scale = Vector3.ONE * 0.25
		var tween: Tween = create_tween()
		tween.tween_interval(float(layer) * 0.035)
		tween.tween_property(shell, "scale", Vector3.ONE * 1.15, 0.14)
		tween.tween_property(shell, "scale", Vector3.ZERO, 0.18)
		tween.tween_callback(Callable(shell, "queue_free"))
	var reflected_finish: Vector3 = attacker.global_position + Vector3(0, 1.0, 0)
	for index: int in range(7):
		var spark_position: Vector3 = centre.lerp(reflected_finish, float(index) / 6.0)
		_spawn_attack_burst(spark_position, Color(0.35, 0.88, 1.0), 0.22 + float(index) * 0.04)
	_camera_shake(0.30, 0.14)
	await get_tree().create_timer(0.36).timeout


func _animate_sylpheed_air_dodge(defender: Node3D, attacker: Node3D) -> void:
	var start: Vector3 = defender.position
	var side: Vector3 = Vector3(0.45, 1.25, 0.0)
	if attacker.position.x > defender.position.x:
		side.x = -0.45
	for index: int in range(5):
		_spawn_attack_burst(defender.global_position + Vector3(0, 0.45 + index * 0.20, 0), Color(0.45, 0.92, 1.0), 0.35 + index * 0.08)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(defender, "position", start + side, 0.22)
	tween.tween_interval(0.10)
	tween.tween_property(defender, "position", start, 0.24)
	await tween.finished


func _animate_sound_strike(attacker: Node3D, target: Node3D) -> void:
	_face_target(attacker, target)
	status_label.text = "%s использует «Звуковой удар»" % str(attacker.get_meta("label"))
	var origin: Vector3 = attacker.global_position + Vector3(0, 1.0, 0)
	var finish: Vector3 = target.global_position + Vector3(0, 1.0, 0)
	for index: int in range(5):
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.14 + index * 0.07
		torus.outer_radius = 0.18 + index * 0.07
		torus.rings = 28
		torus.ring_segments = 7
		ring.mesh = torus
		ring.global_position = origin
		ring.look_at(finish, Vector3.UP)
		ring.rotation_degrees.x += 90.0
		ring.material_override = _effect_material(Color(0.40, 0.90, 1.0, 0.90))
		add_child(ring)
		var delay: float = float(index) * 0.055
		var tween: Tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(ring, "global_position", finish, 0.27)
		tween.parallel().tween_property(ring, "scale", Vector3.ONE * 1.65, 0.27)
		tween.tween_property(ring, "scale", Vector3.ZERO, 0.10)
		tween.tween_callback(Callable(ring, "queue_free"))
	await get_tree().create_timer(0.45).timeout
	_camera_shake(0.22, 0.12)


func _animate_wind_strike(attacker: Node3D, target: Node3D) -> void:
	_face_target(attacker, target)
	status_label.text = "%s использует «Удар ветра»" % str(attacker.get_meta("label"))
	var start: Vector3 = attacker.global_position + Vector3(0, 0.9, 0)
	var finish: Vector3 = target.global_position + Vector3(0, 0.9, 0)
	for index: int in range(9):
		var slash: MeshInstance3D = MeshInstance3D.new()
		var mesh: QuadMesh = QuadMesh.new()
		mesh.size = Vector2(0.18 + index * 0.025, 1.0 + index * 0.06)
		slash.mesh = mesh
		slash.global_position = start.lerp(finish, float(index) / 9.0)
		slash.rotation_degrees = Vector3(-15, index * 27, 42)
		slash.material_override = _effect_material(Color(0.55, 1.0, 0.86, 0.82))
		add_child(slash)
		var tween: Tween = create_tween()
		tween.tween_property(slash, "global_position", finish, 0.22 + index * 0.012)
		tween.parallel().tween_property(slash, "scale", Vector3.ONE * 1.65, 0.22)
		tween.tween_property(slash, "scale", Vector3.ZERO, 0.08)
		tween.tween_callback(Callable(slash, "queue_free"))
	await get_tree().create_timer(0.40).timeout
	_spawn_heavy_arc(finish, Color(0.45, 1.0, 0.84))
	_camera_shake(0.30, 0.15)


func _animate_incinerate(attacker: Node3D, target: Node3D) -> void:
	_face_target(attacker, target)
	status_label.text = "%s использует «Испепелить»" % str(attacker.get_meta("label"))
	var origin: Vector3 = attacker.global_position + Vector3(0, 1.15, 0)
	var finish: Vector3 = target.global_position + Vector3(0, 1.0, 0)
	var projectile: MeshInstance3D = MeshInstance3D.new()
	var projectile_mesh: CapsuleMesh = CapsuleMesh.new()
	projectile_mesh.radius = 0.13
	projectile_mesh.height = 0.58
	projectile.mesh = projectile_mesh
	projectile.global_position = origin
	projectile.look_at(finish, Vector3.UP)
	projectile.rotation_degrees.x += 90.0
	projectile.material_override = _effect_material(Color(1.0, 0.31, 0.04, 0.98))
	add_child(projectile)
	for index: int in range(7):
		_spawn_attack_burst(origin + Vector3(0, 0, -float(index) * 0.08), Color(1.0, 0.35, 0.03), 0.24 + index * 0.04)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(projectile, "global_position", finish, 0.28)
	tween.tween_callback(Callable(self, "_spawn_incinerate_explosion").bind(finish))
	tween.tween_property(projectile, "scale", Vector3.ZERO, 0.07)
	tween.tween_callback(Callable(projectile, "queue_free"))
	await tween.finished


func _spawn_incinerate_explosion(position: Vector3) -> void:
	for index: int in range(12):
		_spawn_attack_burst(position + Vector3(rng.randf_range(-0.36, 0.36), rng.randf_range(-0.15, 0.50), rng.randf_range(-0.36, 0.36)), Color(1.0, 0.22 + index * 0.018, 0.02), 0.42 + index * 0.035)
	_camera_shake(0.48, 0.24)


func _animate_guillotine(attacker: Node3D, target: Node3D) -> void:
	_face_target(attacker, target)
	status_label.text = "%s использует «Гильотина»" % str(attacker.get_meta("label"))
	var start_position: Vector3 = attacker.position
	var direction: Vector3 = (target.position - attacker.position).normalized()
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(attacker, "position", start_position - direction * 0.12, 0.18)
	tween.tween_property(attacker, "position", start_position + direction * 0.56, 0.16)
	tween.tween_callback(Callable(self, "_spawn_guillotine_arc").bind(target.global_position + Vector3(0, 1.15, 0)))
	tween.tween_interval(0.08)
	tween.tween_property(attacker, "position", start_position, 0.24)
	await tween.finished


func _spawn_guillotine_arc(position: Vector3) -> void:
	for index: int in range(7):
		var arc: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.12 + index * 0.045, 1.65 + index * 0.12)
		arc.mesh = quad
		arc.global_position = position + Vector3(0, 0.65, 0)
		arc.rotation_degrees = Vector3(0, index * 9, -24 + index * 8)
		arc.material_override = _effect_material(Color(1.0, 0.18 + index * 0.035, 0.08, 0.90))
		add_child(arc)
		var tween: Tween = create_tween()
		arc.scale = Vector3(0.2, 0.2, 0.2)
		tween.tween_property(arc, "scale", Vector3.ONE * 1.35, 0.12)
		tween.tween_property(arc, "scale", Vector3.ZERO, 0.16)
		tween.tween_callback(Callable(arc, "queue_free"))
	_spawn_heavy_arc(position, Color(1.0, 0.72, 0.14))
	_camera_shake(0.55, 0.25)


func _spawn_guard_flash(position: Vector3, color: Color) -> void:
	var shell: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.10
	shell.mesh = sphere
	shell.global_position = position
	shell.material_override = _effect_material(Color(color.r, color.g, color.b, 0.45))
	add_child(shell)
	shell.scale = Vector3.ONE * 0.25
	var tween: Tween = create_tween()
	tween.tween_property(shell, "scale", Vector3.ONE * 1.20, 0.16)
	tween.tween_property(shell, "scale", Vector3.ZERO, 0.18)
	tween.tween_callback(Callable(shell, "queue_free"))


func _show_victory() -> void:
	if mission_number != 5:
		await super._show_victory()
		return
	if mission_five_resolution_started:
		return
	mission_five_resolution_started = true
	phase = Phase.VICTORY
	_set_action_buttons(true)
	phase_label.text = "ЗАМОК ЗАЩИЩЁН"
	phase_label.modulate = Color(0.44, 1.0, 0.58)
	status_label.text = "Армия Faulkner разбита. Оружейная и торговые склады сохранены."
	if not OS.has_feature("headless"):
		await _show_dialogue("Bastion", "Эти стены больше не тюрьма. Сегодня они стали домом для тех, кто ещё верит в возвращение королевства.", BASTION_PORTRAIT_V12)
		await _show_dialogue("Galvas", "Оружейная уцелела. В общий магазин поступят редкие мечи, амулеты и камни умения защитников замка.", GALVAS_PORTRAIT)
		await _show_dialogue("Kamorge", "Faulkner отступил, но не исчез. В следующий раз он приведёт больше людей. Мы должны использовать эту победу.", KAMORGE_PORTRAIT)
		if not neutral_group_activated and _is_alive(sadira_unit):
			await _show_dialogue("Sadira", "Вы победили без моей помощи. Значит, брат выбрал опасного противника. Мы ещё встретимся.", SADIRA_PORTRAIT)
	CampaignState.complete_mission(5, "castle_defended")
	call_deferred("_return_to_campaign_hub")


func _show_defeat() -> void:
	if mission_number != 5:
		await super._show_defeat()
		return
	if mission_five_resolution_started:
		return
	mission_five_resolution_started = true
	phase = Phase.DEFEAT
	_set_action_buttons(true)
	phase_label.text = "ЗАМОК ПОТЕРЯН"
	phase_label.modulate = Color(1.0, 0.35, 0.30)
	status_label.text = "Выжившие отступают в лес и двигаются на юг за помощью Logan."
	if not OS.has_feature("headless"):
		await _show_dialogue("Andrew", "Западные ворота пали. Если останемся, Faulkner окружит нас во внутреннем дворе.", ANDREW_PORTRAIT_V12)
		await _show_dialogue("Bastion", "В лес. Потом на юг. Logan знал моего отца и хранит старые связи — он наша следующая надежда.", BASTION_PORTRAIT_V12)
		await _show_dialogue("Galvas", "Замок можно вернуть. Людей — нет. Отступаем и просим Logan собрать южные отряды.", GALVAS_PORTRAIT)
	CampaignState.complete_mission(5, "castle_lost")
	call_deferred("_return_to_campaign_hub")
