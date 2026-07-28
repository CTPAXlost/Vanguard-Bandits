extends "res://scripts/campaign_battle_v08.gd"

const GALVAS_PORTRAIT: String = "res://assets/ui/portraits/galvas.png"
const ZAKOV_PORTRAIT: String = "res://assets/ui/portraits/zakov.png"
const KINGDOM_PORTRAIT: String = "res://assets/ui/portraits/kingdom_soldier.png"
const BASTION_PORTRAIT_V12: String = "res://assets/ui/portraits/bastion.png"
const ANDREW_PORTRAIT_V12: String = "res://assets/ui/portraits/andrew.png"
const HUB_SCENE_PATH: String = "res://scenes/CampaignHub.tscn"

var galvas_unit: Node3D
var zakov_unit: Node3D
var kingdom_units: Array[Node3D] = []
var castle_reinforcements_arrived: bool = false
var duyere_retreat_started: bool = false
var serata_aura_round: int = 0


func _build_map() -> void:
	super._build_map()
	if mission_number != 4:
		return
	_build_castle_geometry()


func _build_castle_geometry() -> void:
	var castle: Dictionary = map_data.get("castle", {}) as Dictionary
	var wall_x: int = int(castle.get("wall_x", 16))
	var min_z: int = int(castle.get("min_z", 1))
	var max_z: int = int(castle.get("max_z", 16))
	var min_x: int = int(castle.get("min_x", 16))
	var max_x: int = int(castle.get("max_x", 23))
	var wall_size := Vector3(0.92, 1.65, 0.92)
	var wall_transforms: Array[Transform3D] = []
	for z: int in range(min_z, max_z + 1):
		if z in [8, 9]:
			continue
		wall_transforms.append(
			Transform3D(Basis.IDENTITY, _cell_to_world(Vector2i(wall_x, z)) + Vector3(0, wall_size.y * 0.5, 0))
		)
	for x: int in range(min_x, max_x + 1):
		wall_transforms.append(
			Transform3D(Basis.IDENTITY, _cell_to_world(Vector2i(x, min_z)) + Vector3(0, wall_size.y * 0.5, 0))
		)
		wall_transforms.append(
			Transform3D(Basis.IDENTITY, _cell_to_world(Vector2i(x, max_z)) + Vector3(0, wall_size.y * 0.5, 0))
		)
	for z: int in range(min_z, max_z + 1):
		wall_transforms.append(
			Transform3D(Basis.IDENTITY, _cell_to_world(Vector2i(max_x, z)) + Vector3(0, wall_size.y * 0.5, 0))
		)
	_create_box_multimesh(
		"CastleWalls", wall_transforms, wall_size, Color(0.42, 0.43, 0.48), true
	)
	for tower_cell: Vector2i in [Vector2i(min_x, min_z), Vector2i(min_x, max_z), Vector2i(max_x, min_z), Vector2i(max_x, max_z)]:
		var tower: MeshInstance3D = MeshInstance3D.new()
		var tower_mesh: CylinderMesh = CylinderMesh.new()
		tower_mesh.top_radius = 0.65
		tower_mesh.bottom_radius = 0.78
		tower_mesh.height = 2.65
		tower_mesh.radial_segments = 8
		tower.mesh = tower_mesh
		tower.position = _cell_to_world(tower_cell) + Vector3(0, 1.32, 0)
		tower.material_override = _prop_material(Color(0.35, 0.36, 0.40))
		add_child(tower)
	var gate_arch: MeshInstance3D = MeshInstance3D.new()
	var gate_mesh: BoxMesh = BoxMesh.new()
	gate_mesh.size = Vector3(0.55, 0.42, 2.0)
	gate_arch.mesh = gate_mesh
	gate_arch.position = _cell_to_world(Vector2i(wall_x, 8)) + Vector3(0, 1.78, 0.5)
	gate_arch.material_override = _prop_material(Color(0.47, 0.39, 0.28))
	add_child(gate_arch)


func _create_castle_wall(cell: Vector2i, size: Vector3) -> void:
	var wall: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	wall.mesh = mesh
	wall.position = _cell_to_world(cell) + Vector3(0, size.y * 0.5, 0)
	wall.material_override = _prop_material(Color(0.42, 0.43, 0.48))
	add_child(wall)


func _spawn_mission_four_units() -> void:
	var starts: Dictionary = map_data.get("player_starts", {}) as Dictionary
	kamorge_spawned = true
	player_unit = _spawn_campaign_hero(
		"kamorge", "eigol", _array_to_cell(starts.get("kamorge", [3, 9])), "kamorge_eigol", KAMORGE_PORTRAIT,
		"Пустынный генерал • управляется игроком"
	)
	kamorge_unit = player_unit
	eigol_unit = player_unit
	player_unit.set_meta("magic_uses", 3)
	reyna_unit = _spawn_campaign_hero(
		"reyna", "haurol", _array_to_cell(starts.get("reyna", [3, 7])), "reyna_haurol", REYNA_PORTRAIT,
		"Копейщица партизан • управляется игроком"
	)
	ione_unit = _spawn_campaign_hero(
		"ione", "amphisia", _array_to_cell(starts.get("ione", [2, 10])), "ione_amphisia", IONE_PORTRAIT,
		"Разведчица партизан • управляется игроком"
	)
	galvas_unit = _spawn_campaign_hero(
		"galvas", "serata", _array_to_cell(starts.get("galvas", [4, 11])), "galvas_serata", GALVAS_PORTRAIT,
		"Падший король • управляется игроком"
	)
	galvas_unit.set_meta("passive_ability", "serata_restoration_aura")

	var enemies: Dictionary = map_data.get("enemy_starts", {}) as Dictionary
	zakov_unit = _spawn_enemy_profile(
		"General Zakov / Einlager", "Генерал королевской армии", "einlager",
		_array_to_cell(enemies.get("zakov", [20, 8])), "zakov_einlager", "zakov", ZAKOV_PORTRAIT, true
	)
	zakov_unit.set_meta("passive_ability", "zakov_trap")
	zakov_unit.set_meta("trap_last_round", -99)
	duyere_unit = _spawn_enemy_profile(
		"Duyere / Sarbelas", "Принц Восточного королевства", "sarbelas",
		_array_to_cell(enemies.get("duyere", [21, 10])), "duyere_sarbelas", "duyere", DUYERE_PORTRAIT, true
	)
	for index: int in range((enemies.get("captains", []) as Array).size()):
		var cell: Vector2i = _array_to_cell((enemies.get("captains", []) as Array)[index])
		_spawn_enemy_profile(
			"Captain Soldiers %d / Einlager" % (index + 1), "Капитан имперской стражи • уровень 20", "einlager",
			cell, "captain_einlager_20", "captain_soldiers", CAPTAIN_PORTRAIT, true
		)
	for cell_value: Variant in enemies.get("barbatos", []):
		var soldier: Node3D = _spawn_unit(
			"Страж замка / Barbatos", "Имперский солдат • уровень 10", "barbatos", _array_to_cell(cell_value),
			false, false, "enemy", "imperial_soldier"
		)
		soldier.set_meta("character_id", "")
		soldier.set_meta("combat_profile", "imperial_soldier")
		soldier.set_meta("portrait_path", IMPERIAL_PORTRAIT)
		_apply_enemy_level(soldier, 10)


func _spawn_campaign_hero(character_id: String, slug: String, cell: Vector2i, profile: String, portrait_path: String, role: String) -> Node3D:
	var character: Dictionary = CampaignState.get_character(character_id)
	var label: String = "%s / %s" % [str(character.get("name", character_id.capitalize())), str((CampaignState.ATAC_DATA.get(slug, {}) as Dictionary).get("name", slug.capitalize()))]
	var unit: Node3D = _spawn_unit(label, role, slug, cell, true, false, "ally", profile)
	if unit == null:
		push_error("Failed to spawn campaign hero: %s / %s" % [character_id, slug])
		return null
	unit.set_meta("character_id", character_id)
	unit.set_meta("combat_profile", profile)
	unit.set_meta("portrait_path", portrait_path)
	unit.set_meta("model_slug", slug)
	unit.set_meta("facing_chosen", false)
	unit.set_meta("reaction_system", "defend_dodge_counter")
	unit.set_meta("max_move_actions", 1)
	unit.set_meta("stats", CampaignState.apply_equipment_bonuses(character_id, _stats(unit)))
	_refresh_hp_bar(unit)
	return unit


func _spawn_enemy_profile(label: String, role: String, slug: String, cell: Vector2i, profile: String, combat_profile: String, portrait_path: String, commander: bool) -> Node3D:
	var unit: Node3D = _spawn_unit(label, role, slug, cell, false, commander, "enemy", profile)
	if unit == null:
		push_error("Failed to spawn enemy profile: %s / %s" % [label, slug])
		return null
	unit.set_meta("character_id", "")
	unit.set_meta("combat_profile", combat_profile)
	unit.set_meta("portrait_path", portrait_path)
	unit.set_meta("model_slug", slug)
	unit.set_meta("facing_chosen", true)
	unit.set_meta("reaction_system", "ai_defend_dodge")
	return unit


func _setup_player_party() -> void:
	if mission_number != 4:
		super._setup_player_party()
		return
	player_party.clear()
	for member: Node3D in [player_unit, reyna_unit, ione_unit, galvas_unit]:
		if member != null:
			member.set_meta("player", true)
			player_party.append(member)


func _begin_player_turn() -> void:
	if mission_number == 4 and serata_aura_round != round_number and not mission_four_intro_pending:
		serata_aura_round = round_number
		_apply_serata_aura()
	super._begin_player_turn()


func _apply_serata_aura() -> void:
	if galvas_unit == null or not _is_alive(galvas_unit):
		return
	var restored: int = 0
	for ally: Node3D in units:
		if not _is_alive(ally) or str(ally.get_meta("team")) != "ally":
			continue
		if _grid_distance(galvas_unit, ally) > 3:
			continue
		if int(ally.get_meta("healing_block_turns", 0)) > 0:
			continue
		var stats: Dictionary = _stats(ally)
		var before_hp: int = int(stats.get("hp", 0))
		var before_energy: int = int(stats.get("energy", 0))
		stats["hp"] = mini(int(stats.get("max_hp", before_hp)), before_hp + 15)
		stats["energy"] = mini(int(stats.get("max_energy", before_energy)), before_energy + 15)
		ally.set_meta("stats", stats)
		_refresh_hp_bar(ally)
		if int(stats["hp"]) > before_hp or int(stats["energy"]) > before_energy:
			restored += 1
			_spawn_heal_effect(ally.global_position + Vector3(0, 1.0, 0))
	if restored > 0:
		status_label.text = "Serata создаёт ауру восстановления: +15 HP и энергии союзникам в радиусе 3 клеток."


func _activate_player_member(member: Node3D) -> void:
	super._activate_player_member(member)
	if int(member.get_meta("disabled_turns", 0)) > 0:
		member.set_meta("disabled_turns", maxi(0, int(member.get_meta("disabled_turns", 0)) - 1))
		action_in_progress = true
		status_label.text = "%s обездвижен ловушкой Zakov и пропускает ход." % str(member.get_meta("label"))
		member.set_meta("facing_chosen", true)
		call_deferred("_finish_disabled_player_turn")


func _finish_disabled_player_turn() -> void:
	await get_tree().create_timer(0.75).timeout
	action_in_progress = false
	await _end_player_turn()


func _run_smart_ai_turn(unit: Node3D) -> void:
	if int(unit.get_meta("disabled_turns", 0)) > 0:
		unit.set_meta("disabled_turns", maxi(0, int(unit.get_meta("disabled_turns", 0)) - 1))
		status_label.text = "%s пропускает ход из-за ловушки." % str(unit.get_meta("label"))
		await get_tree().create_timer(0.45).timeout
		return
	await super._run_smart_ai_turn(unit)


func _run_ally_phase() -> void:
	if mission_number == 4 and not castle_reinforcements_arrived and round_number >= 3:
		await _spawn_castle_reinforcements()
	await super._run_ally_phase()


func _spawn_castle_reinforcements() -> void:
	castle_reinforcements_arrived = true
	var starts: Dictionary = map_data.get("reinforcement_starts", {}) as Dictionary
	await _show_dialogue("Zeira", "Мы вернулись. Пятеро королевских гвардейцев всё ещё верны Galvas. Открываем второй фронт!", ZEIRA_PORTRAIT)
	zeira_unit = _spawn_campaign_hero(
		"zeira", "toreadore", _array_to_cell(starts.get("zeira", [1, 5])), "zeira_toreadore", ZEIRA_PORTRAIT,
		"Предводитель партизан • союзный ИИ"
	)
	zeira_unit.set_meta("player", false)
	zeira_unit.set_meta("passive_ability", "toreadore_rear_kick")
	zeira_unit.set_meta("max_move_actions", 2)
	zeira_unit.set_meta("energy_restore_uses", 3)
	zeira_unit.set_meta("rear_kick_multiplier", 2.0)
	zeira_unit.set_meta("rear_kick_distance", 5)
	_spawn_arrival_effect(zeira_unit.global_position + Vector3(0, 1.0, 0))
	var kingdom_cells: Array = starts.get("kingdom", []) as Array
	for index: int in range(kingdom_cells.size()):
		var guard: Node3D = _spawn_unit(
			"Королевский гвардеец %d / Glaive" % (index + 1), "Верный королю солдат • союзный ИИ", "glaive",
			_array_to_cell(kingdom_cells[index]), false, false, "ally", "kingdom_glaive"
		)
		guard.set_meta("character_id", "")
		guard.set_meta("combat_profile", "kingdom_glaive")
		guard.set_meta("portrait_path", KINGDOM_PORTRAIT)
		guard.set_meta("model_slug", "glaive")
		kingdom_units.append(guard)
		_spawn_arrival_effect(guard.global_position + Vector3(0, 0.9, 0))


func _can_use_attack(unit: Node3D, mode: String, counterattack: bool = false) -> bool:
	if int(unit.get_meta("strongest_block_turns", 0)) > 0 and mode == _strongest_attack_mode(unit):
		if bool(unit.get_meta("player", false)):
			status_label.text = "«%s» временно заблокирована вязкой бурей." % str(CombatCatalog.attack(mode).get("label", mode))
		return false
	return super._can_use_attack(unit, mode, counterattack)


func _strongest_attack_mode(unit: Node3D) -> String:
	var result: String = "slash"
	var best: float = -1.0
	for mode: String in CombatCatalog.attacks_for(unit):
		var multiplier: float = float(CombatCatalog.attack(mode).get("multiplier", 0.0))
		if multiplier > best:
			best = multiplier
			result = mode
	return result


func _calculate_damage(attacker: Node3D, target: Node3D, multiplier: float) -> int:
	var damage: int = super._calculate_damage(attacker, target, multiplier)
	var character_id: String = str(attacker.get_meta("character_id", ""))
	if not character_id.is_empty() and CampaignState.character_has_opal(character_id):
		# The currently resolved mode is stored before the base calculation.
		if str(attacker.get_meta("resolving_attack_mode", "")) == "bright_bomb":
			damage = maxi(1, int(round(float(damage) * 1.10)))
	return damage


func _damage_target(target: Node3D, damage: int) -> void:
	if mission_number == 4 and target == duyere_unit and not duyere_retreat_started and _is_alive(target):
		var stats: Dictionary = _stats(target)
		var hp: int = int(stats.get("hp", 1))
		var threshold: int = maxi(1, int(floor(float(stats.get("max_hp", 1)) * 0.40)))
		if hp - damage <= threshold:
			damage = maxi(0, hp - maxi(1, threshold - 1))
	await super._damage_target(target, damage)
	if target == duyere_unit:
		await _check_duyere_retreat()


func _resolve_attack(attacker: Node3D, target: Node3D, mode: String) -> void:
	attacker.set_meta("resolving_attack_mode", mode)
	if mode == "quicksand":
		_apply_sand_status(target, 3, 2, 0.0)
		status_label.text = "%s замедлен зыбучими песками на 2 хода: движение 1–2 клетки." % str(target.get_meta("label"))
		attacker.set_meta("resolving_attack_mode", "")
		return
	if mode == "healing_ban":
		target.set_meta("healing_block_turns", 3)
		status_label.text = "%s не сможет восстанавливать HP в течение 3 ходов." % str(target.get_meta("label"))
		_spawn_healing_ban_effect(target.global_position + Vector3(0, 1.1, 0))
		attacker.set_meta("resolving_attack_mode", "")
		return
	await super._resolve_attack(attacker, target, mode)
	if mode == "desert_storm" and _is_alive(target):
		target.set_meta("disoriented_turns", 2)
		target.set_meta("friendly_fire_chance", 0.50)
		status_label.text = "%s дезориентирован бурей и может атаковать союзника." % str(target.get_meta("label"))
	elif mode == "sticky_sandstorm":
		if _is_alive(target):
			target.set_meta("strongest_block_turns", 2)
		var secondary: int = 0
		for candidate: Node3D in units:
			if candidate == target or not _is_alive(candidate):
				continue
			if str(candidate.get_meta("team")) != str(target.get_meta("team")):
				continue
			if _grid_distance(target, candidate) > 2:
				continue
			candidate.set_meta("strongest_block_turns", 2)
			await _damage_target(candidate, maxi(1, int(float(_calculate_damage(attacker, candidate, 1.15)))))
			secondary += 1
			if secondary >= 2:
				break
	attacker.set_meta("resolving_attack_mode", "")
	await _check_duyere_retreat()


func _try_automatic_passive(defender: Node3D, attacker: Node3D, back_attack: bool) -> String:
	if str(defender.get_meta("passive_ability", "")) == "zakov_trap":
		var last_round: int = int(defender.get_meta("trap_last_round", -99))
		if round_number % 5 == 0 and last_round != round_number:
			defender.set_meta("trap_last_round", round_number)
			attacker.set_meta("disabled_turns", maxi(1, int(attacker.get_meta("disabled_turns", 0))))
			status_label.text = "Zakov активирует ловушку: %s выведен из строя на один ход!" % str(attacker.get_meta("label"))
			_spawn_trap_effect(attacker.global_position)
			await get_tree().create_timer(0.55).timeout
			return "avoided"
	return await super._try_automatic_passive(defender, attacker, back_attack)


func _tick_status_effects(unit: Node3D) -> void:
	super._tick_status_effects(unit)
	for key: String in ["healing_block_turns", "strongest_block_turns"]:
		var turns: int = int(unit.get_meta(key, 0))
		if turns > 0:
			unit.set_meta(key, turns - 1)


func _play_attack_animation(attacker: Node3D, target: Node3D, mode: String) -> void:
	# Version 1.6 removes the separate 3D arena. Every action is presented directly
	# on the tactical battlefield, keeping positioning readable and uninterrupted.
	if attacker == null or target == null:
		return
	var attack_data: Dictionary = CombatCatalog.attack(mode)
	var attack_name: String = str(attack_data.get("label", mode.capitalize()))
	await _begin_tactical_attack_presentation(attacker, target, attack_name, mode)
	match mode:
		"desert_storm":
			await _animate_desert_storm_v12(attacker, target)
		"sticky_sandstorm":
			await _animate_sticky_sandstorm(attacker, target)
		"healing_ban":
			await _animate_healing_ban(attacker, target)
		_:
			await super._play_attack_animation(attacker, target, mode)
	await _finish_tactical_attack_presentation(attacker, target, mode)


func _begin_tactical_attack_presentation(attacker: Node3D, target: Node3D, attack_name: String, mode: String) -> void:
	_face_target(attacker, target)
	_face_target(target, attacker)
	status_label.text = "%s применяет «%s»" % [str(attacker.get_meta("label")), attack_name]
	_spawn_focus_ring(attacker.global_position, _attack_color(mode), 0.78)
	_spawn_focus_ring(target.global_position, Color(1.0, 0.25, 0.22, 0.92), 0.62)
	var attacker_visual: Node3D = attacker.get_node_or_null("ATACVisual") as Node3D
	var target_visual: Node3D = target.get_node_or_null("ATACVisual") as Node3D
	var prep: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if attacker_visual != null:
		var attacker_base: Vector3 = attacker_visual.get_meta("base_tactical_scale", attacker_visual.scale)
		prep.tween_property(attacker_visual, "scale", attacker_base * 1.10, 0.12)
	if target_visual != null:
		var target_base: Vector3 = target_visual.get_meta("base_tactical_scale", target_visual.scale)
		prep.tween_property(target_visual, "scale", target_base * 1.04, 0.12)
	await prep.finished
	await get_tree().create_timer(0.055).timeout


func _finish_tactical_attack_presentation(attacker: Node3D, target: Node3D, mode: String) -> void:
	var color: Color = _attack_color(mode)
	_spawn_impact_sparks(target.global_position + Vector3(0, 1.0, 0), color, 10 if mode in ["slash", "lunge"] else 18)
	var attacker_visual: Node3D = attacker.get_node_or_null("ATACVisual") as Node3D
	var target_visual: Node3D = target.get_node_or_null("ATACVisual") as Node3D
	var finish: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if attacker_visual != null:
		var attacker_base: Vector3 = attacker_visual.get_meta("base_tactical_scale", attacker_visual.scale)
		finish.tween_property(attacker_visual, "scale", attacker_base, 0.18)
	if target_visual != null:
		var target_base: Vector3 = target_visual.get_meta("base_tactical_scale", target_visual.scale)
		finish.tween_property(target_visual, "scale", target_base, 0.22)
	await finish.finished


func _attack_color(mode: String) -> Color:
	match mode:
		"ice_rain": return Color(0.35, 0.84, 1.0, 0.95)
		"ball_lightning": return Color(0.45, 0.62, 1.0, 0.95)
		"bright_bomb": return Color(1.0, 0.82, 0.22, 0.95)
		"desert_storm", "desert_whirl", "quicksand", "sticky_sandstorm": return Color(0.92, 0.61, 0.20, 0.95)
		"ultrasound": return Color(0.75, 0.38, 1.0, 0.95)
		"spear_throw", "slide": return Color(0.86, 0.92, 1.0, 0.95)
		"strong_slash", "shoulder_bash", "earthquake": return Color(1.0, 0.28, 0.16, 0.95)
		_: return Color(0.52, 0.92, 1.0, 0.95)


func _spawn_focus_ring(position: Vector3, color: Color, scale_value: float) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.46
	mesh.outer_radius = 0.54
	ring.mesh = mesh
	ring.position = position + Vector3(0, 0.08, 0)
	ring.rotation_degrees.x = 90.0
	ring.material_override = _effect_material(color)
	add_child(ring)
	ring.scale = Vector3.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * scale_value, 0.13)
	tween.tween_property(ring, "scale", Vector3.ONE * scale_value * 1.35, 0.18)
	tween.tween_property(ring, "scale", Vector3.ZERO, 0.14)
	tween.tween_callback(Callable(ring, "queue_free"))


func _spawn_impact_sparks(position: Vector3, color: Color, count: int) -> void:
	for index: int in range(count):
		var spark: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.025, 0.025, 0.22 + float(index % 4) * 0.055)
		spark.mesh = mesh
		spark.position = position
		spark.rotation_degrees = Vector3(rng.randf_range(-45.0, 45.0), rng.randf_range(0.0, 360.0), rng.randf_range(-60.0, 60.0))
		spark.material_override = _effect_material(color)
		add_child(spark)
		var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.15, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(spark, "position", position + direction * rng.randf_range(0.45, 1.25), 0.24)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.28)
		tween.chain().tween_callback(Callable(spark, "queue_free"))


func _animate_desert_storm_v12(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s вызывает «Бурю в пустыне»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var visual: Node3D = attacker.get_node_or_null("ATACVisual") as Node3D
	if visual != null and visual.has_method("set_combat_pose"):
		visual.call("set_combat_pose", "desert_storm", 0.48)
	await CinematicVfx.play(self, "desert_storm", target.global_position + Vector3(0, 0.05, 0), 1.25, 0.11)
	for index: int in range(22):
		if visual != null and visual.has_method("set_combat_pose"):
			visual.call("set_combat_pose", "desert_storm", float(index) / 21.0)
		_spawn_sand_arc(target.global_position + Vector3(0, 0.5, 0), index)
		await get_tree().create_timer(0.025).timeout
	if visual != null and visual.has_method("reset_pose"):
		visual.call("reset_pose")
	_spawn_attack_burst(target.global_position + Vector3(0, 0.8, 0), Color(0.88, 0.60, 0.22), 1.6)


func _animate_sticky_sandstorm(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s поднимает «Вязкую бурю в песках»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var visual: Node3D = attacker.get_node_or_null("ATACVisual") as Node3D
	if visual != null and visual.has_method("set_combat_pose"):
		visual.call("set_combat_pose", "sticky_sandstorm", 0.52)
	await CinematicVfx.play(self, "sticky_sandstorm", target.global_position + Vector3(0, 0.04, 0), 1.28, 0.105)
	for index: int in range(30):
		_spawn_sand_arc(target.global_position + Vector3(0, 0.35, 0), index)
		if index % 4 == 0:
			_spawn_sand_column(target.global_position + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)))
		await get_tree().create_timer(0.022).timeout
	_camera_shake(0.45, 0.20)
	if visual != null and visual.has_method("reset_pose"):
		visual.call("reset_pose")


func _animate_healing_ban(attacker: Node3D, target: Node3D) -> void:
	_face_target(attacker, target)
	_spawn_healing_ban_effect(target.global_position + Vector3(0, 1.1, 0))
	await get_tree().create_timer(0.55).timeout


func _spawn_healing_ban_effect(position: Vector3) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.42
	mesh.outer_radius = 0.50
	ring.mesh = mesh
	ring.position = position
	ring.rotation_degrees.x = 90
	ring.material_override = _effect_material(Color(0.72, 0.10, 0.22, 0.88))
	add_child(ring)
	var tween: Tween = create_tween()
	ring.scale = Vector3.ZERO
	tween.tween_property(ring, "scale", Vector3.ONE * 1.6, 0.42)
	tween.parallel().tween_property(ring, "rotation_degrees:y", 220.0, 0.42)
	tween.tween_property(ring, "scale", Vector3.ZERO, 0.22)
	tween.tween_callback(Callable(ring, "queue_free"))


func _spawn_trap_effect(position: Vector3) -> void:
	for offset: Vector3 in [Vector3(0.45, 0.1, 0.45), Vector3(-0.45, 0.1, 0.45), Vector3(0.45, 0.1, -0.45), Vector3(-0.45, 0.1, -0.45)]:
		var spike: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.11
		cone.height = 0.55
		spike.mesh = cone
		spike.position = position + offset
		spike.material_override = _effect_material(Color(0.72, 0.72, 0.78, 0.95))
		add_child(spike)
		var tween: Tween = create_tween()
		spike.scale = Vector3(1, 0, 1)
		tween.tween_property(spike, "scale", Vector3.ONE, 0.18)
		tween.tween_interval(0.35)
		tween.tween_property(spike, "scale", Vector3(1, 0, 1), 0.18)
		tween.tween_callback(Callable(spike, "queue_free"))


func _check_duyere_retreat() -> void:
	if mission_number != 4 or duyere_retreat_started or duyere_unit == null or not _is_alive(duyere_unit):
		return
	var stats: Dictionary = _stats(duyere_unit)
	if float(stats.get("hp", 0)) > float(stats.get("max_hp", 1)) * 0.40:
		return
	duyere_retreat_started = true
	action_in_progress = true
	await _show_dialogue("Duyere", "Хватит. Я не стану умирать за замок, который Zakov всё равно не удержит. Откройте северный проход — я отступаю!", DUYERE_PORTRAIT)
	await _show_dialogue("Zakov", "Трус! Империя запомнит этот побег.", ZAKOV_PORTRAIT)
	var escape: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	escape.tween_property(duyere_unit, "position", duyere_unit.position + Vector3(3.5, 0, -3.5), 0.75)
	escape.parallel().tween_property(duyere_unit, "scale", Vector3.ZERO, 0.75)
	await escape.finished
	duyere_unit.set_meta("team", "retreated")
	stats["hp"] = 0
	duyere_unit.set_meta("stats", stats)
	_refresh_hp_bar(duyere_unit)
	action_in_progress = false


func _play_mission_four_intro() -> void:
	await _show_dialogue("Kamorge", "Я выбрался... Река унесла Barazaph, но не мою клятву. Bastion всё ещё в плену, и времени почти не осталось.", KAMORGE_PORTRAIT)
	await _show_dialogue("Kamorge", "Среди деревьев — старый ангар. Этот ATAC покрыт песком, хотя вокруг северный лес... Eigol, машина генерала Пустынного королевства.", KAMORGE_PORTRAIT)
	var visual: Node3D = eigol_unit.get_node_or_null("ATACVisual") as Node3D
	if visual != null:
		visual.visible = true
		visual.scale = Vector3.ZERO
		var reveal: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(visual, "scale", visual.get_meta("base_tactical_scale", Vector3.ONE * 0.76), 0.78)
		await reveal.finished
	_spawn_arrival_effect(eigol_unit.global_position + Vector3(0, 1.0, 0))
	await _show_dialogue("Kamorge", "Eigol принял меня. Значит, я ещё могу исправить свою ошибку.", KAMORGE_PORTRAIT)
	await _show_dialogue("Zeira", "Остановись. Ещё один шаг — и Toreadore пробьёт твою броню.", ZEIRA_PORTRAIT)
	await _show_dialogue("Kamorge", "Мне не нужен бой с вами. Мой сын Bastion и Andrew находятся в имперском замке. Я прошу помощи.", KAMORGE_PORTRAIT)
	await _show_dialogue("Galvas", "Я — Galvas, король без трона. Империя отняла у меня корону, но не людей. Освободим твоего сына — и нанесём удар по тем, кто захватил моё королевство.", GALVAS_PORTRAIT)
	await _show_dialogue("Reyna", "Haurol готов. У стен замка держимся рядом и не даём капитанам окружить нас.", REYNA_PORTRAIT)
	await _show_dialogue("Ione", "Я разведала западные ворота. Через них пройдёт небольшой отряд.", IONE_PORTRAIT)
	await _show_dialogue("Zeira", "Начинайте штурм без меня. Я соберу тех солдат, которые ещё верны Galvas, и ударю с фланга.", ZEIRA_PORTRAIT)
	await _show_dialogue("Zakov", "Перед вами крепость империи. Сложите оружие, и, возможно, пленники останутся живы.", ZAKOV_PORTRAIT)
	await _show_dialogue("Galvas", "Ты защищаешь мой замок моими же солдатами, Zakov. Сегодня Serata вернёт королю дорогу домой.", GALVAS_PORTRAIT)
	await _show_dialogue("Duyere", "Kamorge всё-таки выжил... Капитаны, уничтожьте Eigol первым.", DUYERE_PORTRAIT)


func _show_victory() -> void:
	if mission_number != 4:
		await super._show_victory()
		return
	if victory_sequence_started:
		return
	victory_sequence_started = true
	phase = Phase.VICTORY
	_set_action_buttons(true)
	phase_label.text = "ЗАМОК ВЗЯТ"
	phase_label.modulate = Color(0.48, 1.0, 0.55)
	status_label.text = "Отряд входит в крепость и освобождает Bastion и Andrew."
	await _show_dialogue("Bastion", "Отец?.. Я видел, как ты прыгнул в реку. Я думал, что потерял тебя.", BASTION_PORTRAIT_V12)
	await _show_dialogue("Kamorge", "Я оставил тебя один раз. Второго не будет. Eigol помог мне вернуться.", KAMORGE_PORTRAIT)
	await _show_dialogue("Andrew", "А это, я полагаю, армия спасения. Хорошо, что вы пришли до следующего допроса.", ANDREW_PORTRAIT_V12)
	await _show_dialogue("Galvas", "Замок открыт, но война только начинается. Bastion и Andrew свободны; теперь мы вернём королевство.", GALVAS_PORTRAIT)
	await _show_dialogue("Zeira", "В лагере открылся общий магазин. Все монеты принадлежат отряду — оружие, амулеты и камни покупаются из единого фонда.", ZEIRA_PORTRAIT)
	CampaignState.complete_mission(4)
	get_tree().change_scene_to_file(HUB_SCENE_PATH)
