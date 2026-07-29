extends "res://scripts/battle_prototype.gd"

const MISSION_ONE_PATH: String = "res://data/maps/mission_01.json"
const MISSION_TWO_PATH: String = "res://data/maps/mission_02.json"
const CADOR_PORTRAIT: String = "res://assets/ui/portraits/cador.png"
const ANDREW_PORTRAIT: String = "res://assets/ui/portraits/andrew.png"

var mission_number: int = 1
var swamp_cells: Dictionary = {}
var active_attacker: Node3D
var victory_sequence_started: bool = false
var reinforcements_spawned: bool = false
var andrew_unit: Node3D
var andrew_joined: bool = false


func _ready() -> void:
	mission_number = maxi(1, CampaignState.current_mission)
	# Every inherited campaign layer must finish booting before mission-specific
	# dialogue or turn logic continues. Several chapters use awaited intros.
	await super._ready()
	if mission_number == 2:
		action_in_progress = true
		phase = Phase.DIALOGUE
		_clear_highlights()
		await _play_mission_two_intro()
		action_in_progress = false
		_begin_player_turn()


func _load_first_mission() -> void:
	var mission_path: String = MISSION_TWO_PATH if mission_number == 2 else MISSION_ONE_PATH
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(mission_path))
	if parsed is Dictionary:
		map_data = parsed as Dictionary
	else:
		map_data = {"width": 14, "height": 12}
	grid_width = int(map_data.get("width", 14))
	grid_height = int(map_data.get("height", 12))
	blocked_cells = _cell_set(map_data.get("blocked_cells", []))
	swamp_cells = _cell_set(map_data.get("swamp_cells", []))
	title_label.text = str(map_data.get("name", "Миссия"))
	var balance_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if balance_parsed is Dictionary:
		balance_data = balance_parsed as Dictionary


func _build_map() -> void:
	super._build_map()
	_create_cell_overlay_multimesh(
		"SwampSurface",
		swamp_cells,
		0.085,
		0.035,
		Color(0.10, 0.33, 0.26, 0.88),
		0.32,
		Color(0.03, 0.14, 0.10)
	)


func _spawn_mission_units() -> void:
	if mission_number == 1:
		_spawn_first_mission_units()
	else:
		_spawn_second_mission_units()


func _spawn_first_mission_units() -> void:
	var start: Vector2i = _array_to_cell(map_data.get("player_start", [3, 9]))
	player_unit = _spawn_character_unit("bastion", start, true, "ally")
	for enemy_value: Variant in map_data.get("enemies", []):
		var enemy_data: Dictionary = enemy_value as Dictionary
		_spawn_enemy_from_data(enemy_data)


func _spawn_second_mission_units() -> void:
	player_unit = _spawn_character_unit(
		"bastion", _array_to_cell(map_data.get("player_start", [7, 13])), true, "ally"
	)
	kamorge_spawned = true
	kamorge_unit = _spawn_character_unit(
		"kamorge", _array_to_cell(map_data.get("kamorge_start", [10, 13])), false, "ally"
	)
	andrew_unit = _spawn_character_unit(
		"andrew", _array_to_cell(map_data.get("andrew_cell", [9, 7])), false, "captive"
	)
	andrew_unit.set_meta("role", "Пленный рыцарь • окружён имперцами")
	for enemy_value: Variant in map_data.get("enemies", []):
		_spawn_enemy_from_data(enemy_value as Dictionary)


func _spawn_character_unit(
	character_id: String, cell: Vector2i, player_controlled: bool, team: String
) -> Node3D:
	var character: Dictionary = CampaignState.get_character(character_id)
	var profile: String = "bastion_alba"
	var role: String = "Главный герой"
	if character_id == "kamorge":
		profile = "kamorge_barazaph"
		role = "Отец Bastion • союзный ИИ"
	elif character_id == "andrew":
		profile = "andrew_vedocorban"
		role = "Рыцарь Vedocorban"
	elif character_id == "ione":
		profile = "ione_amphisia"
		role = "Партизанский разведчик"
	elif character_id == "reyna":
		profile = "reyna_haurol"
		role = "Копейщица партизанского отряда"
	elif character_id == "zeira":
		profile = "zeira_toreadore"
		role = "Предводитель партизан"
	var atac_slug: String = "barazaph" if character_id == "kamorge" and mission_number <= 3 else CampaignState.character_atac(character_id)
	var atac_name: String = str(
		(CampaignState.ATAC_DATA.get(atac_slug, {}) as Dictionary).get(
			"name", atac_slug.capitalize()
		)
	)
	var label: String = (
		"%s / %s" % [str(character.get("name", character_id.capitalize())), atac_name]
	)
	var unit: Node3D = _spawn_unit(
		label, role, atac_slug, cell, player_controlled, false, team, profile
	)
	unit.set_meta("character_id", character_id)
	var progressed: Dictionary = CampaignState.apply_character_progress(character_id, _stats(unit))
	unit.set_meta("stats", progressed)
	_refresh_hp_bar(unit)
	return unit


func _spawn_enemy_from_data(enemy_data: Dictionary) -> Node3D:
	var commander: bool = bool(enemy_data.get("commander", false))
	var unit: Node3D = _spawn_unit(
		str(enemy_data.get("name", "Имперский солдат")),
		str(enemy_data.get("role", "Имперский солдат")),
		"barbatos",
		_array_to_cell(enemy_data.get("cell", [9, 3])),
		false,
		commander,
		"enemy",
		"imperial_commander" if commander else "imperial_soldier"
	)
	unit.set_meta("character_id", "")
	unit.set_meta("model_slug", "barbatos")
	_apply_enemy_level(unit, int(enemy_data.get("level", 1)))
	return unit


func _apply_enemy_level(unit: Node3D, level: int) -> void:
	var stats: Dictionary = _stats(unit)
	var commander: bool = bool(unit.get_meta("commander"))
	var base_hp: int = 110 if commander else 90
	var hp_growth: int = 15 if commander else 12
	stats["level"] = level
	stats["max_hp"] = base_hp + (level - 1) * hp_growth
	stats["hp"] = int(stats["max_hp"])
	stats["strength"] = int(stats.get("strength", 12)) + (level - 1) * 2
	stats["agility"] = int(stats.get("agility", 9)) + (level - 1)
	stats["defense"] = int(stats.get("defense", 8)) + (level - 1)
	stats["attack_skill"] = int(stats.get("attack_skill", 8)) + (level - 1) * 2
	stats["atac_name"] = "Barbatos"
	stats["equipment"] = "Имперская броня Barbatos %d" % level
	unit.set_meta("stats", stats)
	_refresh_hp_bar(unit)


func _resolve_attack(attacker: Node3D, target: Node3D, mode: String) -> void:
	active_attacker = attacker
	await super._resolve_attack(attacker, target, mode)
	active_attacker = null


func _damage_target(target: Node3D, damage: int) -> void:
	var was_alive: bool = _is_alive(target)
	var target_was_enemy: bool = str(target.get_meta("team")) == "enemy"
	var source: Node3D = active_attacker
	await super._damage_target(target, damage)
	var killed: bool = was_alive and not _is_alive(target)
	if source != null and is_instance_valid(source) and str(source.get_meta("team")) == "ally":
		_award_attack_experience(source, damage, killed and target_was_enemy)
	if mission_number == 2 and defeated_enemy_count >= 2 and not reinforcements_spawned:
		await _spawn_mission_two_reinforcements()


func _award_attack_experience(attacker: Node3D, damage: int, killed_enemy: bool) -> void:
	var character_id: String = str(attacker.get_meta("character_id", ""))
	if character_id.is_empty():
		return
	# A successful battle must visibly move the progress bar. Early builds awarded
	# so little XP that several eliminations could leave a level-1 hero unchanged.
	var damage_bonus: int = mini(20, maxi(0, int(float(damage) / 10.0)))
	var attack_xp: int = 12 + damage_bonus
	var total_xp: int = attack_xp + (80 if killed_enemy else 0)
	var previous_stats: Dictionary = _stats(attacker).duplicate(true)
	var attacks_before: Array[String] = CombatCatalog.attacks_for(attacker)
	var previous_hp: int = int(previous_stats.get("hp", 1))
	var previous_max_hp: int = int(previous_stats.get("max_hp", previous_hp))
	var result: Dictionary = CampaignState.award_experience(character_id, total_xp)
	_spawn_experience_label(attacker.global_position + Vector3(0, 2.65, 0), total_xp)
	var stats: Dictionary = CampaignState.apply_character_progress(character_id, previous_stats)
	var hp_growth: int = maxi(0, int(stats.get("max_hp", previous_max_hp)) - previous_max_hp)
	stats["hp"] = mini(int(stats.get("max_hp", previous_hp)), previous_hp + hp_growth)
	attacker.set_meta("stats", stats)
	_refresh_hp_bar(attacker)
	if int(result.get("levels", 0)) > 0:
		var attacks_after: Array[String] = CombatCatalog.attacks_for(attacker)
		var unlocked_labels: Array[String] = []
		for mode: String in attacks_after:
			if not attacks_before.has(mode):
				unlocked_labels.append(str(CombatCatalog.attack(mode).get("label", mode)))
		var unlock_text: String = ""
		if not unlocked_labels.is_empty():
			unlock_text = " Открыто: %s." % ", ".join(PackedStringArray(unlocked_labels))
		status_label.text = (
			"%s получает уровень %d и 3 очка прокачки!%s"
			% [str(attacker.get_meta("label")), int(result.get("level", 1)), unlock_text]
		)
		_spawn_level_up_effect(attacker.global_position + Vector3(0, 1.15, 0))
	_refresh_ui()


func _spawn_experience_label(world_position: Vector3, amount: int) -> void:
	var label := Label3D.new()
	label.text = "+%d опыта" % amount
	label.font_size = 42
	label.outline_size = 8
	label.modulate = Color(0.98, 0.88, 0.28)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = world_position
	_register_transient_fx(label, 1.5)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.65, 0.75)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.75)
	tween.tween_callback(Callable(label, "queue_free"))


func _spawn_level_up_effect(position: Vector3) -> void:
	for index: int in range(6):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.26 + index * 0.075
		torus.outer_radius = 0.30 + index * 0.075
		torus.rings = 24
		torus.ring_segments = 6
		ring.mesh = torus
		ring.position = position
		ring.rotation_degrees = Vector3(90, index * 27, 0)
		ring.material_override = _effect_material(Color(1.0, 0.82, 0.18, 0.82))
		_register_transient_fx(ring, 1.8)
		var tween := create_tween()
		ring.scale = Vector3.ONE * 0.25
		tween.tween_property(ring, "scale", Vector3.ONE * 1.45, 0.35 + index * 0.03)
		tween.parallel().tween_property(ring, "position:y", position.y + 1.25, 0.52)
		tween.tween_property(ring, "scale", Vector3.ZERO, 0.18)
		tween.tween_callback(Callable(ring, "queue_free"))


func _run_ally_phase() -> void:
	var allies: Array[Node3D] = []
	for unit: Node3D in units:
		if unit == player_unit or not _is_alive(unit):
			continue
		if str(unit.get_meta("team")) == "ally":
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
		await _run_single_ally_ai(ally)
	action_in_progress = false
	if _all_enemies_defeated():
		_show_victory()
		return
	await _run_enemy_phase()


func _run_single_ally_ai(ally: Node3D) -> void:
	_recover_fatigue(ally, FATIGUE_RECOVERY)
	_recover_energy(ally, 10)
	_select_unit(ally)
	status_label.text = "%s действует самостоятельно." % str(ally.get_meta("label"))
	var target: Node3D = _nearest_enemy(ally)
	if target == null:
		return
	var distance: int = _grid_distance(ally, target)
	if distance > 1:
		var goals: Array = _free_adjacent_cells(target, ally)
		var path: Array = _find_path_to_any(ally.get_meta("cell"), goals, ally)
		var steps: int = mini(int(_stats(ally).get("move_range", 5)), path.size())
		if steps > 0:
			await _animate_path(ally, path.slice(0, steps), 0.14)
	distance = _grid_distance(ally, target)
	if distance != 1 or not _is_alive(target):
		return
	var character_id: String = str(ally.get_meta("character_id", ""))
	if character_id == "kamorge" and _can_spend_energy(ally, ENERGY_BALL_LIGHTNING):
		await _animate_ball_lightning(ally, target)
		_spend_energy(ally, ENERGY_BALL_LIGHTNING)
		await _resolve_attack(ally, target, "ball_lightning")
	elif character_id == "andrew":
		await _animate_long_lunge(ally, target)
		await _resolve_attack(ally, target, "lunge")
	else:
		await _animate_lunge(ally, target)
		await _resolve_attack(ally, target, "lunge")


func _spawn_kamorge_event() -> void:
	kamorge_spawned = true
	phase = Phase.DIALOGUE
	action_in_progress = true
	_clear_highlights()
	await _show_dialogue(
		"Kamorge",
		"Ах вот ты где?!? Я пошёл найти дров, а ты удрал, удрал спасать деревню!",
		KAMORGE_PORTRAIT
	)
	await _show_dialogue("Bastion", "Отец, я справлюсь, не переживай за меня!", PLAYER_PORTRAIT)
	await _show_dialogue("Kamorge", "Ну уж нет, я иду.", KAMORGE_PORTRAIT)
	var spawn_cell: Vector2i = _array_to_cell(map_data.get("kamorge_spawn", [2, 9]))
	while _unit_at(spawn_cell) != null or blocked_cells.has(spawn_cell):
		spawn_cell += Vector2i.LEFT
	kamorge_unit = _spawn_character_unit("kamorge", spawn_cell, false, "ally")
	_spawn_arrival_effect(kamorge_unit.global_position + Vector3(0, 1.1, 0))
	_select_unit(kamorge_unit)
	status_label.text = "Kamorge присоединился к бою и действует самостоятельно."
	await get_tree().create_timer(0.7).timeout
	action_in_progress = false


func _spawn_mission_two_reinforcements() -> void:
	reinforcements_spawned = true
	phase = Phase.DIALOGUE
	action_in_progress = true
	await _show_dialogue(
		"Имперский командир",
		"Двое выведены из строя! Сигнальный огонь — вызывайте второй отряд!",
		IMPERIAL_PORTRAIT
	)
	await _show_dialogue(
		"Andrew",
		"Вы отвлекли их. Отлично... Теперь Vedocorban снова подчиняется мне.",
		ANDREW_PORTRAIT
	)
	for reinforcement_value: Variant in map_data.get("reinforcements", []):
		var reinforcement: Node3D = _spawn_enemy_from_data(reinforcement_value as Dictionary)
		_spawn_arrival_effect(reinforcement.global_position + Vector3(0, 1.1, 0))
	if andrew_unit != null and _is_alive(andrew_unit):
		andrew_unit.set_meta("team", "ally")
		andrew_unit.set_meta("role", "Освобождённый рыцарь • союзный ИИ")
		_recolor_selection_ring(andrew_unit, Color(0.40, 0.86, 1.0))
		andrew_joined = true
	await _show_dialogue(
		"Kamorge",
		"Шесть новых машин. Andrew, держи центр. Bastion, не отрывайся от нас.",
		KAMORGE_PORTRAIT
	)
	await _show_dialogue(
		"Bastion",
		"Понял! Сначала расчистим путь из болота, потом зажмём их у леса.",
		PLAYER_PORTRAIT
	)
	action_in_progress = false


func _recolor_selection_ring(unit: Node3D, color: Color) -> void:
	var marker := unit.get_node_or_null("SelectionRing") as MeshInstance3D
	if marker == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.85
	marker.material_override = material


func _play_mission_two_intro() -> void:
	await _show_dialogue(
		"Kamorge",
		"Следы ведут через лес к болоту. Держись рядом — почва здесь обманчивая.",
		KAMORGE_PORTRAIT
	)
	await _show_dialogue(
		"Bastion", "Там впереди имперцы. Они окружили рыцаря и его ATAC.", PLAYER_PORTRAIT
	)
	await _show_dialogue(
		"Имперский командир",
		"Пленник! Последний раз предлагаю: покинь Vedocorban и сложи оружие.",
		IMPERIAL_PORTRAIT
	)
	await _show_dialogue(
		"Andrew",
		"Чтобы я отдал Vedocorban? Подойдите и попробуйте забрать его сами.",
		ANDREW_PORTRAIT
	)
	await _show_dialogue("Bastion", "Отец, мы не можем его бросить.", PLAYER_PORTRAIT)
	await _show_dialogue(
		"Kamorge",
		"И не бросим. Разорвём окружение до того, как подойдёт подкрепление.",
		KAMORGE_PORTRAIT
	)


func _show_victory() -> void:
	if victory_sequence_started:
		return
	victory_sequence_started = true
	phase = Phase.VICTORY
	_clear_highlights()
	_set_action_buttons(true)
	call_deferred("_run_victory_sequence")


func _run_victory_sequence() -> void:
	phase_label.text = "ПОБЕДА"
	phase_label.modulate = Color(0.42, 1.0, 0.55)
	if mission_number == 1:
		status_label.text = "Деревня освобождена."
		var kamorge_final_text: String = (
			"Это было безрассудно и слишком опасно! Я буду следить за тобой, "
			+ "больше ты не ускользнёшь! Не останешься без присмотра!"
		)
		await _show_dialogue("Kamorge", kamorge_final_text, KAMORGE_PORTRAIT)
		await _show_dialogue("Bastion", "Прости отец, хорошо.", PLAYER_PORTRAIT)
		await _animate_heroes_leave()
		await _show_cador_cameo()
		CampaignState.complete_mission(1)
		get_tree().change_scene_to_file("res://scenes/CampaignHub.tscn")
	else:
		status_label.text = "Имперский отряд и подкрепление уничтожены."
		await _show_dialogue(
			"Andrew",
			"Я обязан вам свободой и жизнью Vedocorban. Разрешите продолжить путь вместе с вами.",
			ANDREW_PORTRAIT
		)
		await _show_dialogue(
			"Kamorge",
			"Сначала выберемся из болота. Потом расскажешь, почему империя охотилась именно за тобой.",
			KAMORGE_PORTRAIT
		)
		await _show_dialogue("Bastion", "Добро пожаловать в отряд, Andrew.", PLAYER_PORTRAIT)
		CampaignState.complete_mission(2)
		get_tree().change_scene_to_file("res://scenes/CampaignHub.tscn")


func _animate_heroes_leave() -> void:
	var heroes: Array[Node3D] = [player_unit]
	if kamorge_unit != null and _is_alive(kamorge_unit):
		heroes.append(kamorge_unit)
	for hero: Node3D in heroes:
		var destination := hero.position + Vector3(-5.5, 0, 3.5)
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(hero, "position", destination, 1.25)
		tween.parallel().tween_property(hero, "scale", Vector3.ONE * 0.18, 1.25)
	await get_tree().create_timer(1.35).timeout


func _show_cador_cameo() -> void:
	var cell: Vector2i = _array_to_cell(map_data.get("cador_spawn", [12, 2]))
	var cador := Node3D.new()
	cador.name = "Cador_Cameo"
	cador.position = _cell_to_world(cell)
	var visual: Node3D = AtacFactory.create_atac("cador", "tactical")
	visual.name = "ATACVisual"
	visual.scale = Vector3.ONE * 0.84
	cador.add_child(visual)
	add_child(cador)
	cador.scale = Vector3.ZERO
	_spawn_arrival_effect(cador.global_position + Vector3(0, 1.2, 0))
	var appear := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(cador, "scale", Vector3.ONE, 0.45)
	await appear.finished
	await _show_dialogue(
		"Cador — мысли", "Хммм... Я прослежу, чтобы никто не дошёл до конца.", CADOR_PORTRAIT
	)
	var disappear := create_tween()
	disappear.tween_property(cador, "scale", Vector3.ZERO, 0.36)
	await disappear.finished
	cador.queue_free()


func _refresh_ui() -> void:
	if selected_unit != null:
		_sync_runtime_progress_fields(selected_unit)
	super._refresh_ui()
	if selected_unit == null:
		return
	var character_id: String = str(selected_unit.get_meta("character_id", ""))
	if character_id == "bastion":
		portrait.texture = load(PLAYER_PORTRAIT)
	elif character_id == "kamorge":
		portrait.texture = load(KAMORGE_PORTRAIT)
	elif character_id == "andrew":
		portrait.texture = load(ANDREW_PORTRAIT)
	var stats: Dictionary = _stats(selected_unit)
	if not character_id.is_empty():
		stats_label.text += (
			"\nОпыт: %d / %d\nОчки прокачки: %d"
			% [
				int(stats.get("experience", 0)),
				int(stats.get("experience_needed", 0)),
				int(stats.get("stat_points", 0)),
			]
		)


func _sync_runtime_progress_fields(unit: Node3D) -> void:
	var character_id: String = str(unit.get_meta("character_id", ""))
	if character_id.is_empty():
		return
	var character: Dictionary = CampaignState.get_character(character_id)
	if character.is_empty():
		return
	var stats: Dictionary = _stats(unit)
	var level: int = int(character.get("level", int(stats.get("level", 1))))
	var atac_id: String = str(character.get("atac", unit.get_meta("model_slug", "alba")))
	stats["level"] = level
	stats["max_level"] = AtacProgression.max_level(atac_id, 100)
	stats["experience"] = int(character.get("experience", 0))
	stats["experience_needed"] = 0 if level >= int(stats["max_level"]) else CampaignState.xp_needed(level)
	stats["stat_points"] = int(character.get("stat_points", 0))
	unit.set_meta("stats", stats)


func _animate_slash(attacker: Node3D, target: Node3D) -> void:
	_spawn_afterimages(attacker, Color(0.45, 0.86, 1.0, 0.28))
	await super._animate_slash(attacker, target)
	_spawn_attack_burst(target.global_position + Vector3(0, 1.0, 0), Color(0.45, 0.86, 1.0), 0.72)
	_camera_shake(0.12, 0.055)


func _animate_lunge(attacker: Node3D, target: Node3D) -> void:
	_spawn_afterimages(attacker, Color(0.72, 0.92, 1.0, 0.32))
	await super._animate_lunge(attacker, target)
	_spawn_attack_burst(target.global_position + Vector3(0, 1.0, 0), Color(0.72, 0.92, 1.0), 0.88)
	_camera_shake(0.16, 0.07)


func _animate_long_lunge(attacker: Node3D, target: Node3D) -> void:
	_spawn_afterimages(attacker, Color(0.95, 0.78, 0.30, 0.34))
	await super._animate_long_lunge(attacker, target)
	_spawn_attack_burst(target.global_position + Vector3(0, 1.0, 0), Color(0.98, 0.72, 0.22), 1.05)
	_camera_shake(0.20, 0.09)


func _spawn_afterimages(unit: Node3D, tint: Color) -> void:
	var original := unit.get_node_or_null("ATACVisual/ModelRoot/AtacSprite") as Sprite3D
	var texture: Texture2D = null
	var pixel_size: float = 0.0021
	if original != null and original.texture != null:
		texture = original.texture
		pixel_size = original.pixel_size
	else:
		var visual: Node3D = unit.get_node_or_null("ATACVisual") as Node3D
		if visual != null:
			var source_path: String = str(visual.get_meta("source_front_path", ""))
			pixel_size = float(visual.get_meta("skin_pixel_size", 0.0021))
			if not source_path.is_empty():
				texture = ResourceLoader.load(source_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	if texture == null:
		return
	for index: int in range(2):
		var ghost := Sprite3D.new()
		ghost.texture = texture
		ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		ghost.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ghost.shaded = false
		ghost.double_sided = true
		ghost.pixel_size = pixel_size
		ghost.position = unit.global_position + Vector3(0, 1.08, 0)
		ghost.scale = Vector3.ONE * float(unit.get_node("ATACVisual").scale.x)
		ghost.modulate = Color(tint.r, tint.g, tint.b, maxf(0.05, tint.a - index * 0.07))
		ghost.no_depth_test = false
		_register_transient_fx(ghost, 1.0)
		var tween := create_tween()
		tween.tween_property(ghost, "position", ghost.position + Vector3(0, 0.12 + index * 0.05, 0), 0.28)
		tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.28)
		tween.tween_callback(Callable(ghost, "queue_free"))


func _animate_ball_lightning(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Шаровая молния»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var origin: Vector3 = attacker.global_position + Vector3(0, 1.20, 0)
	var finish: Vector3 = target.global_position + Vector3(0, 1.10, 0)
	var charge_root := Node3D.new()
	charge_root.position = origin
	_register_transient_fx(charge_root, 2.5)
	for index: int in range(8):
		var spark := MeshInstance3D.new()
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.035
		spark_mesh.height = 0.07
		spark.mesh = spark_mesh
		var angle: float = TAU * float(index) / 8.0
		spark.position = Vector3(cos(angle) * 0.38, sin(angle * 2.0) * 0.16, sin(angle) * 0.38)
		spark.material_override = _effect_material(Color(0.50, 0.84, 1.0, 0.95))
		charge_root.add_child(spark)
	var charge_light := OmniLight3D.new()
	charge_light.light_color = Color(0.32, 0.66, 1.0)
	charge_light.light_energy = 9.0
	charge_light.omni_range = 3.2
	charge_root.add_child(charge_light)
	charge_root.scale = Vector3.ZERO
	var charge := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(charge_root, "scale", Vector3.ONE * 1.35, 0.62)
	charge.parallel().tween_property(charge_root, "rotation_degrees:y", 520.0, 0.62)
	await charge.finished

	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.68
	sphere.radial_segments = 24
	sphere.rings = 14
	orb.mesh = sphere
	orb.position = origin
	orb.material_override = _effect_material(Color(0.34, 0.72, 1.0, 0.98))
	_register_transient_fx(orb, 2.5)
	var orb_light := OmniLight3D.new()
	orb_light.light_color = Color(0.28, 0.64, 1.0)
	orb_light.light_energy = 20.0
	orb_light.omni_range = 5.5
	orb.add_child(orb_light)
	_screen_flash(Color(0.30, 0.62, 1.0), 0.20, 0.18)
	_spawn_lightning_chain(origin, finish)
	_spawn_lightning_chain(origin + Vector3(0.18, 0.16, -0.12), finish)
	var flight := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	flight.tween_property(orb, "position", finish, 0.58)
	flight.parallel().tween_property(orb, "scale", Vector3.ONE * 1.75, 0.58)
	await flight.finished
	_spawn_lightning_impact(finish)
	_screen_flash(Color(0.70, 0.88, 1.0), 0.34, 0.24)
	_spawn_attack_burst(finish, Color(0.35, 0.78, 1.0), 1.25)
	_spawn_lightning_chain(finish + Vector3(-0.8, 1.5, 0), finish)
	_spawn_lightning_chain(finish + Vector3(0.8, 1.7, 0.4), finish)
	_camera_shake(0.32, 0.14)
	orb.queue_free()
	charge_root.queue_free()
	await get_tree().create_timer(0.24).timeout


func _spawn_lightning_chain(start: Vector3, finish: Vector3) -> void:
	var root := Node3D.new()
	_register_transient_fx(root, 1.2)
	var previous: Vector3 = start
	var segments: int = 9
	for index: int in range(1, segments + 1):
		var ratio: float = float(index) / float(segments)
		var point: Vector3 = start.lerp(finish, ratio)
		if index < segments:
			point += Vector3(
				rng.randf_range(-0.12, 0.12),
				rng.randf_range(-0.10, 0.10),
				rng.randf_range(-0.12, 0.12)
			)
		var beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		var length: float = previous.distance_to(point)
		beam_mesh.size = Vector3(0.035, 0.035, length)
		beam.mesh = beam_mesh
		beam.position = (previous + point) * 0.5
		beam.look_at(point, Vector3.UP)
		beam.material_override = _effect_material(Color(0.72, 0.92, 1.0, 0.95))
		root.add_child(beam)
		previous = point
	var tween := create_tween()
	tween.tween_interval(0.16)
	tween.tween_property(root, "scale", Vector3.ZERO, 0.10)
	tween.tween_callback(Callable(root, "queue_free"))


func _spawn_attack_burst(world_position: Vector3, color: Color, scale_factor: float) -> void:
	var root := Node3D.new()
	root.position = world_position
	_register_transient_fx(root, 1.2)
	for index: int in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.20 + index * 0.11
		torus.outer_radius = 0.245 + index * 0.11
		torus.rings = 28
		torus.ring_segments = 8
		ring.mesh = torus
		ring.rotation_degrees = Vector3(90, index * 38, 0)
		ring.material_override = _effect_material(Color(color.r, color.g, color.b, 0.84))
		root.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 8.0 * scale_factor
	light.omni_range = 3.2 * scale_factor
	root.add_child(light)
	root.scale = Vector3.ONE * 0.18
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "scale", Vector3.ONE * scale_factor, 0.18)
	tween.tween_property(root, "scale", Vector3.ZERO, 0.18)
	tween.tween_callback(Callable(root, "queue_free"))


func _screen_flash(color: Color, peak_alpha: float, duration: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(color.r, color.g, color.b, 0.0)
	layer.add_child(flash)
	_register_transient_fx(layer, 1.0)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", peak_alpha, duration * 0.35)
	tween.tween_property(flash, "color:a", 0.0, duration * 0.65)
	tween.tween_callback(Callable(layer, "queue_free"))


func _camera_shake(duration: float, strength: float) -> void:
	var original: Vector3 = camera.position
	var tween := create_tween()
	var steps: int = maxi(2, int(duration / 0.04))
	for _index: int in range(steps):
		var offset := Vector3(
			rng.randf_range(-strength, strength), rng.randf_range(-strength, strength), 0
		)
		tween.tween_property(camera, "position", original + offset, duration / float(steps))
	tween.tween_property(camera, "position", original, 0.05)
