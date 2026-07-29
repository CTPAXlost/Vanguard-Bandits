extends "res://scripts/campaign_battle_v19.gd"

const MISSION_SEVEN_PATH: String = "res://data/maps/mission_07.json"
const MILEA_PORTRAIT: String = "res://assets/ui/portraits/milea.png"
const PUCK_PORTRAIT: String = "res://assets/ui/portraits/puck.png"
const GANLON_PORTRAIT: String = "res://assets/ui/portraits/ganlon.png"
const SUPPORT_MODES: Array[String] = [
	"engineer_heal", "engineer_armor", "engineer_energy", "engineer_shield",
	"panther_teleport", "waiban_decoys",
]

var mission_seven_boot_started: bool = false
var mission_seven_boot_finished: bool = false
var mission_seven_victory_started: bool = false
var relief_spawned: bool = false
var relief_spawning: bool = false
var mission_seven_initial_party_size: int = 0
var milea_unit: Node3D
var puck_unit: Node3D
var ganlon_unit: Node3D
var galvas_prisoner: Node3D
var mission_seven_decoys: Array[Node3D] = []
var runtime_test_balance_applied: bool = false
var runtime_test_balance_started: bool = false


func _ready() -> void:
	if CampaignState.current_mission == 7:
		call_deferred("_finalize_mission_seven_boot")
	await super._ready()
	if mission_number == 7:
		call_deferred("_finalize_mission_seven_boot")
	call_deferred("_apply_runtime_test_balance")


func _apply_runtime_test_balance() -> void:
	if runtime_test_balance_applied or runtime_test_balance_started or not CampaignState.test_level_scaling_enabled:
		return
	runtime_test_balance_started = true
	while is_inside_tree() and (units.is_empty() or player_party.is_empty()):
		await get_tree().process_frame
	if mission_number == 6:
		while is_inside_tree() and not mission_six_boot_finalized:
			await get_tree().process_frame
	elif mission_number == 7:
		while is_inside_tree() and not mission_seven_boot_finished:
			await get_tree().process_frame
	if not is_inside_tree() or units.is_empty():
		runtime_test_balance_started = false
		return
	var enemy_level_sum: int = 0
	var enemy_count: int = 0
	var enemy_maximum: int = 1
	for unit: Node3D in units:
		if not _is_alive(unit) or str(unit.get_meta("team", "")) != "enemy":
			continue
		var enemy_level: int = int(_stats(unit).get("level", 1))
		enemy_level_sum += enemy_level
		enemy_count += 1
		enemy_maximum = maxi(enemy_maximum, enemy_level)
	if enemy_count <= 0:
		runtime_test_balance_started = false
		return
	var enemy_average: int = maxi(1, int(round(float(enemy_level_sum) / float(enemy_count))))
	# Player-controlled ATACs remain a little weaker than the opposition, while
	# late-mission test launches no longer leave the full party at level 1.
	var player_floor: int = clampi(maxi(_runtime_level_floor(mission_number), enemy_average - 3), 1, 100)
	var allied_floor: int = clampi(maxi(1, player_floor - 1), 1, 100)
	for unit: Node3D in units:
		if not _is_alive(unit) or str(unit.get_meta("team", "")) != "ally":
			continue
		var target_level: int = player_floor if bool(unit.get_meta("player", false)) else allied_floor
		_scale_runtime_ally(unit, target_level)
	runtime_test_balance_applied = true
	runtime_test_balance_started = false
	CampaignState.request_save_game(0.20)
	print("TEST_LEVEL_SCALING_OK mission=%d enemy_avg=%d enemy_max=%d player_floor=%d" % [mission_number, enemy_average, enemy_maximum, player_floor])
	_refresh_ui()


func _runtime_level_floor(mission_id: int) -> int:
	return int({1: 1, 2: 4, 3: 8, 4: 14, 5: 18, 6: 18, 7: 26}.get(mission_id, 1))


func _scale_runtime_ally(unit: Node3D, requested_level: int) -> void:
	var stats: Dictionary = _stats(unit).duplicate(true)
	var old_level: int = maxi(1, int(stats.get("level", 1)))
	var character_id: String = str(unit.get_meta("character_id", ""))
	var model_slug: String = str(unit.get_meta("model_slug", "alba"))
	var target_level: int = requested_level
	if not character_id.is_empty() and not CampaignState.get_character(character_id).is_empty():
		target_level = CampaignState.raise_character_level_floor(character_id, requested_level)
		stats = CampaignState.apply_character_progress(character_id, stats)
	else:
		var maximum_level: int = AtacProgression.max_level(model_slug, 100)
		target_level = clampi(maxi(old_level, requested_level), 1, maximum_level)
		var atac_data: Dictionary = CampaignState.ATAC_DATA.get(model_slug, CampaignState.ATAC_DATA["alba"]) as Dictionary
		stats["level"] = target_level
		stats["max_level"] = maximum_level
		stats["max_hp"] = int(atac_data.get("base_hp", 180)) + (target_level - 1) * int(atac_data.get("hp_per_level", 8))
		stats["hp"] = int(stats["max_hp"])
		stats["experience"] = 0
		stats["experience_needed"] = 0 if target_level >= maximum_level else CampaignState.xp_needed(target_level)
		stats["stat_points"] = 0
	var level_gain: int = maxi(0, target_level - old_level)
	if level_gain > 0:
		stats["strength"] = int(stats.get("strength", 1)) + level_gain
		stats["agility"] = int(stats.get("agility", 1)) + int(round(float(level_gain) * 0.70))
		stats["defense"] = int(stats.get("defense", 1)) + int(round(float(level_gain) * 0.85))
		stats["attack_skill"] = int(stats.get("attack_skill", 1)) + level_gain
	stats["hp"] = int(stats.get("max_hp", stats.get("hp", 1)))
	unit.set_meta("stats", stats)
	_refresh_hp_bar(unit)


func _load_first_mission() -> void:
	if CampaignState.current_mission != 7:
		super._load_first_mission()
		return
	mission_number = 7
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSION_SEVEN_PATH))
	if parsed is Dictionary:
		map_data = parsed as Dictionary
	else:
		push_error("Mission VII map is missing or invalid: %s" % MISSION_SEVEN_PATH)
		map_data = {"name": "Глава VII — Штурм имперского замка", "width": 30, "height": 18}
	grid_width = int(map_data.get("width", 30))
	grid_height = int(map_data.get("height", 18))
	blocked_cells = _cell_set(map_data.get("blocked_cells", []))
	_open_castle_passages()
	river_cells = {}
	swamp_cells = {}
	title_label.text = str(map_data.get("name", "Глава VII — Штурм имперского замка"))
	var parsed_balance: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if parsed_balance is Dictionary:
		balance_data = parsed_balance as Dictionary


func _build_map() -> void:
	super._build_map()
	if mission_number == 7:
		_build_defense_castle_geometry()


func _spawn_mission_units() -> void:
	if mission_number != 7:
		super._spawn_mission_units()
		return
	_spawn_mission_seven_party()
	_spawn_mission_seven_prisoners()
	_spawn_mission_seven_enemies()
	_setup_player_party()


func _spawn_mission_seven_party() -> void:
	var starts: Dictionary = map_data.get("player_starts", {}) as Dictionary
	player_unit = _spawn_campaign_hero("bastion", "alba", _array_to_cell(starts.get("bastion", [3, 8])), "bastion_alba", BASTION_PORTRAIT_V12, "Наследник королевства • штурмовая группа")
	andrew_unit = _spawn_campaign_hero("andrew", "vedocorban", _array_to_cell(starts.get("andrew", [3, 10])), "andrew_vedocorban", ANDREW_PORTRAIT_V12, "Рыцарь Bastion • штурмовая группа")
	ione_unit = _spawn_campaign_hero("ione", "amphisia", _array_to_cell(starts.get("ione", [2, 6])), "ione_amphisia", IONE_PORTRAIT, "Разведчица • штурмовая группа")
	reyna_unit = _spawn_campaign_hero("reyna", "haurol", _array_to_cell(starts.get("reyna", [2, 12])), "reyna_haurol", REYNA_PORTRAIT, "Копейщица • штурмовая группа")
	zeira_unit_five = _spawn_campaign_hero("zeira", "toreadore", _array_to_cell(starts.get("zeira", [4, 7])), "zeira_toreadore", ZEIRA_PORTRAIT, "Предводитель партизан • штурмовая группа")
	if CampaignState.kingdom_alliance == "south":
		var claire: Node3D = _spawn_campaign_hero("claire", "rahabar", _array_to_cell(starts.get("claire", [4, 11])), "claire_rahabar", CLAIRE_PORTRAIT, "Принцесса Юга • постоянный союзник")
		var shion: Node3D = _spawn_campaign_hero("shion", "rahabar", _array_to_cell(starts.get("shion", [5, 12])), "shion_rahabar", SHION_PORTRAIT, "Телохранитель Claire • постоянный союзник")
		_apply_unit_level(claire, "rahabar", int(CampaignState.get_character("claire").get("level", 15)), 32, 31, 29, 33)
		_apply_unit_level(shion, "rahabar", int(CampaignState.get_character("shion").get("level", 22)), 42, 38, 37, 40)
	else:
		var barlow: Node3D = _spawn_campaign_hero("barlow", "ratatosk", _array_to_cell(starts.get("barlow", [4, 11])), "barlow_ratatosk", BARLOW_PORTRAIT, "Северный рыцарь • постоянный союзник")
		_apply_unit_level(barlow, "ratatosk", int(CampaignState.get_character("barlow").get("level", 14)), 31, 29, 33, 34)
		milea_unit = _spawn_campaign_hero("milea", "panther", _array_to_cell(starts.get("milea", [5, 6])), "milea_panther", MILEA_PORTRAIT, "Сестра Bastion • постоянный союзник")
		_apply_unit_level(milea_unit, "panther", 15, 36, 42, 31, 39)
		milea_unit.set_meta("teleport_uses", 2)
		milea_unit.set_meta("energy_steal_chance", 0.40)
		puck_unit = _spawn_campaign_hero("puck", "engineer", _array_to_cell(starts.get("puck", [5, 10])), "puck_engineer", PUCK_PORTRAIT, "Инженер поддержки • постоянный союзник")
		_apply_unit_level(puck_unit, "engineer", 35, 19, 28, 43, 31)
		puck_unit.set_meta("armor_uses", 1)
		puck_unit.set_meta("shield_uses", 3)


func _spawn_mission_seven_prisoners() -> void:
	var starts: Dictionary = map_data.get("prisoner_starts", {}) as Dictionary
	galvas_prisoner = _spawn_campaign_hero("galvas", "serata", _array_to_cell(starts.get("galvas", [18, 8])), "galvas_serata", GALVAS_PORTRAIT, "Пленный падший король")
	galvas_prisoner.set_meta("player", false)
	galvas_prisoner.set_meta("team", "captive")
	galvas_prisoner.set_meta("captive", true)
	_apply_unit_level(galvas_prisoner, "serata", 18, 39, 27, 35, 38)
	ganlon_unit = _spawn_campaign_hero("ganlon", "waiban", _array_to_cell(starts.get("ganlon", [18, 10])), "ganlon_waiban", GANLON_PORTRAIT, "Пленный верный соратник Galvas")
	ganlon_unit.set_meta("player", false)
	ganlon_unit.set_meta("team", "captive")
	ganlon_unit.set_meta("captive", true)
	ganlon_unit.set_meta("decoy_uses", 1)
	ganlon_unit.set_meta("attack_override", ["slash", "lunge", "long_lunge", "strong_slash", "ball_lightning", "waiban_decoys"])
	_apply_unit_level(ganlon_unit, "waiban", 16, 34, 30, 35, 36)


func _spawn_mission_seven_enemies() -> void:
	var starts: Dictionary = map_data.get("enemy_starts", {}) as Dictionary
	faulkner_unit = _spawn_enemy_profile("Faulkner / Solarus", "Генерал имперской обороны • уровень 35", "solarus", _array_to_cell(starts.get("faulkner", [19, 8])), "faulkner_solarus", "faulkner", FAULKNER_PORTRAIT, true)
	_apply_unit_level(faulkner_unit, "solarus", 35, 62, 45, 56, 61)
	duyere_unit = _spawn_enemy_profile("Duyere / Sarbelas", "Принц Восточного королевства • уровень 28", "sarbelas", _array_to_cell(starts.get("duyere", [20, 10])), "duyere_sarbelas", "duyere", DUYERE_PORTRAIT, true)
	_apply_unit_level(duyere_unit, "sarbelas", 28, 51, 47, 43, 50)
	sadira_unit = _spawn_enemy_profile("Sadira / Sylpheed", "Сестра Duyere • защитник замка", "sylpheed", _array_to_cell(starts.get("sadira", [19, 5])), "sadira_sylpheed", "sadira_sylpheed", SADIRA_PORTRAIT, true)
	_apply_unit_level(sadira_unit, "sylpheed", 24, 43, 57, 39, 50)
	franco_unit = _spawn_enemy_profile("Franco / Korbelan", "Телохранитель Sadira", "korbelan", _array_to_cell(starts.get("franco", [20, 4])), "franco_korbelan", "franco_korbelan", FRANCO_PORTRAIT, true)
	_apply_unit_level(franco_unit, "korbelan", 32, 59, 37, 61, 56)
	halak_unit = _spawn_enemy_profile("Halak / Korbelan", "Телохранитель Sadira", "korbelan", _array_to_cell(starts.get("halak", [20, 13])), "halak_korbelan", "halak_korbelan", HALAK_PORTRAIT, true)
	_apply_unit_level(halak_unit, "korbelan", 32, 59, 37, 61, 56)
	var zakov: Node3D = _spawn_enemy_profile("Zakov / Sharking", "Тяжёлый имперский командир", "sharking", _array_to_cell(starts.get("zakov", [19, 12])), "zakov_sharking", "zakov_sharking", ZAKOV_PORTRAIT, true)
	_apply_unit_level(zakov, "sharking", 38, 68, 38, 68, 64)
	zakov.set_meta("force_field_armor", 250)
	zakov.set_meta("force_field_regen", 50)
	for index: int in range((starts.get("barbatos", []) as Array).size()):
		var soldier: Node3D = _spawn_enemy_profile("Имперский Barbatos %d" % (index + 1), "Страж замка", "barbatos", _array_to_cell((starts.get("barbatos", []) as Array)[index]), "imperial_soldier", "imperial_soldier", IMPERIAL_PORTRAIT, false)
		_apply_unit_level(soldier, "barbatos", 22 + index, 39 + index, 31 + index, 37 + index, 39 + index)


func _setup_player_party() -> void:
	if mission_number != 7:
		super._setup_player_party()
		return
	player_party.clear()
	for unit: Node3D in units:
		if not bool(unit.get_meta("player", false)) or str(unit.get_meta("team", "")) != "ally" or not _is_alive(unit):
			continue
		if not player_party.has(unit):
			player_party.append(unit)
	mission_seven_initial_party_size = player_party.size()


func _finalize_mission_seven_boot() -> void:
	if mission_seven_boot_started or mission_seven_boot_finished:
		return
	mission_seven_boot_started = true
	while is_inside_tree() and (mission_number != 7 or units.is_empty() or player_party.size() < 5):
		await get_tree().process_frame
	if not is_inside_tree() or mission_number != 7:
		mission_seven_boot_started = false
		return
	action_in_progress = true
	phase = Phase.DIALOGUE
	if not _is_headless_or_smoke_runtime():
		await _play_mission_seven_intro()
	mission_seven_boot_finished = true
	mission_seven_boot_started = false
	action_in_progress = false
	print("MISSION7_BOOT_OK alliance=%s party=%d enemies=%d" % [CampaignState.kingdom_alliance, player_party.size(), _alive_enemy_count_v20()])
	_begin_player_turn()


func _play_mission_seven_intro() -> void:
	await _show_dialogue("Bastion", "На этот раз в клетках не мы. Galvas и Ganlon удерживаются в центре замка. Мы вытащим их и закончим этот бой.", BASTION_PORTRAIT_V12)
	await _show_dialogue("Zeira", "Faulkner собрал всех сильнейших защитников: Duyere, Sadira, Franco, Halak и Zakov. Это будет тяжёлый штурм.", ZEIRA_PORTRAIT)
	if CampaignState.kingdom_alliance == "south":
		await _show_dialogue("Claire", "Отец знает, куда мы идём. Если строй рухнет, Logan приведёт Crimson и южных Nordilian.", CLAIRE_PORTRAIT)
		await _show_dialogue("Shion", "До этого момента мы с Claire остаёмся в первой линии. Rahabor не отступит.", SHION_PORTRAIT)
	else:
		await _show_dialogue("Milea", "Брат, мы слишком долго были разделены. Panther откроет дорогу к пленникам.", MILEA_PORTRAIT)
		await _show_dialogue("Puck", "Engineer держит ремонтный контур. Я могу лечить, усиливать броню, возвращать энергию и ставить щит.", PUCK_PORTRAIT)
	await _show_dialogue("Faulkner", "Снова штурмуешь мой замок, Bastion? На этот раз внутри тебя ждёт вся имперская гвардия.", FAULKNER_PORTRAIT)
	await _show_dialogue("Ganlon", "Galvas, слышишь? Они пришли. Waiban ещё способен сражаться — только снимите блокировку камеры.", GANLON_PORTRAIT)


func _begin_player_turn() -> void:
	if mission_number == 7 and not mission_seven_boot_finished:
		return
	if mission_number == 7:
		_clear_expired_support_effects()
		if not relief_spawned and not relief_spawning and _mission_seven_needs_relief():
			relief_spawning = true
			action_in_progress = true
			phase = Phase.DIALOGUE
			_spawn_royal_relief_async()
			return
	super._begin_player_turn()


func _mission_seven_needs_relief() -> bool:
	if round_number >= 5:
		return true
	var alive_party: int = 0
	var ally_power: float = 0.0
	var enemy_power: float = 0.0
	for unit: Node3D in units:
		if not _is_alive(unit):
			continue
		var level: int = int(_stats(unit).get("level", 1))
		if str(unit.get_meta("team", "")) == "ally":
			ally_power += float(level)
			if bool(unit.get_meta("player", false)):
				alive_party += 1
		elif str(unit.get_meta("team", "")) == "enemy":
			enemy_power += float(level)
	if alive_party <= maxi(2, int(ceil(float(mission_seven_initial_party_size) * 0.50))):
		return true
	return round_number >= 2 and enemy_power > ally_power * 1.35


func _spawn_royal_relief_async() -> void:
	if not _is_headless_or_smoke_runtime():
		if CampaignState.kingdom_alliance == "south":
			await _show_dialogue("Logan", "Юг не забывает союзников. Crimson и шесть Rahabor входят в бой — теперь командуй нами, Bastion.", LOGAN_PORTRAIT)
		else:
			await _show_dialogue("Alden", "Север прибыл в обещанный час. Altagrave, Devlin и шесть Matisse переходят под твоё командование.", ALDEN_PORTRAIT)
	var enemy_level: int = _mission_seven_enemy_level()
	if CampaignState.kingdom_alliance == "south":
		_spawn_south_relief(enemy_level)
	else:
		_spawn_north_relief(enemy_level)
	relief_spawned = true
	relief_spawning = false
	action_in_progress = false
	phase = Phase.PLAYER_MOVE
	print("MISSION7_RELIEF_OK alliance=%s enemy_level=%d party=%d" % [CampaignState.kingdom_alliance, enemy_level, player_party.size()])
	_begin_player_turn()


func _spawn_south_relief(enemy_level: int) -> void:
	var starts: Dictionary = map_data.get("south_relief", {}) as Dictionary
	var leader_level: int = clampi(maxi(25, enemy_level), 25, 100)
	var bot_level: int = clampi(maxi(15, enemy_level - 5), 15, 100)
	var logan: Node3D = _spawn_campaign_hero("logan", "crimson", _array_to_cell(starts.get("logan", [1, 8])), "logan_crimson", LOGAN_PORTRAIT, "Король Юга • управляется игроком")
	_apply_scaled_relief_stats(logan, "crimson", leader_level, 22)
	logan.set_meta("damage_magic_uses", 2)
	logan.set_meta("double_turn", true)
	_register_relief_player(logan)
	for index: int in range((starts.get("bots", []) as Array).size()):
		var bot: Node3D = _spawn_unit("Nordilian %d / Rahabor" % (index + 1), "Южное подкрепление • управляется игроком", "rahabar", _array_to_cell((starts.get("bots", []) as Array)[index]), true, false, "ally", "nordilian_rahabar")
		bot.set_meta("portrait_path", "res://assets/ui/portraits/nordilian.png")
		_apply_scaled_relief_stats(bot, "rahabar", bot_level + index % 3, 14)
		_register_relief_player(bot)


func _spawn_north_relief(enemy_level: int) -> void:
	var starts: Dictionary = map_data.get("north_relief", {}) as Dictionary
	var leader_level: int = clampi(maxi(24, enemy_level), 24, 100)
	var devlin_level: int = clampi(maxi(19, enemy_level - 2), 19, 100)
	var bot_level: int = clampi(maxi(15, enemy_level - 5), 15, 100)
	var alden: Node3D = _spawn_campaign_hero("alden", "altagrave", _array_to_cell(starts.get("alden", [1, 8])), "alden_altagrave", ALDEN_PORTRAIT, "Король Севера • управляется игроком")
	_apply_scaled_relief_stats(alden, "altagrave", leader_level, 21)
	alden.set_meta("magic_immune", true)
	_register_relief_player(alden)
	var devlin: Node3D = _spawn_campaign_hero("devlin", "snow_soldier", _array_to_cell(starts.get("devlin", [1, 10])), "devlin_snow_soldier", DEVLIN_PORTRAIT, "Генерал Севера • управляется игроком")
	_apply_scaled_relief_stats(devlin, "snow_soldier", devlin_level, 18)
	devlin.set_meta("clone_uses", 1)
	_register_relief_player(devlin)
	for index: int in range((starts.get("bots", []) as Array).size()):
		var bot: Node3D = _spawn_unit("Matisse %d / Ratatosk" % (index + 1), "Северное подкрепление • управляется игроком", "ratatosk", _array_to_cell((starts.get("bots", []) as Array)[index]), true, false, "ally", "matisse_ratatosk")
		bot.set_meta("portrait_path", "res://assets/ui/portraits/matisse.png")
		_apply_scaled_relief_stats(bot, "ratatosk", bot_level + index % 3, 14)
		_register_relief_player(bot)


func _apply_scaled_relief_stats(unit: Node3D, slug: String, level: int, base: int) -> void:
	var growth: int = int(round(float(level) * 1.25))
	_apply_unit_level(unit, slug, level, base + growth, base + int(growth * 0.72), base + int(growth * 0.85), base + int(growth * 0.90))


func _register_relief_player(unit: Node3D) -> void:
	if unit == null:
		return
	unit.set_meta("player", true)
	unit.set_meta("team", "ally")
	unit.set_meta("royal_relief", true)
	if not player_party.has(unit):
		player_party.append(unit)
	_spawn_arrival_effect(unit.global_position + Vector3(0, 1.0, 0))


func _mission_seven_enemy_level() -> int:
	var maximum: int = 1
	for unit: Node3D in units:
		if _is_alive(unit) and str(unit.get_meta("team", "")) == "enemy":
			maximum = maxi(maximum, int(_stats(unit).get("level", 1)))
	return maximum


func _alive_enemy_count_v20() -> int:
	var count: int = 0
	for unit: Node3D in units:
		if _is_alive(unit) and str(unit.get_meta("team", "")) == "enemy":
			count += 1
	return count


func _eligible_targets(attacker: Node3D, mode: String) -> Array[Node3D]:
	if mission_number != 7:
		return super._eligible_targets(attacker, mode)
	if mode not in SUPPORT_MODES:
		var combat_targets: Array[Node3D] = super._eligible_targets(attacker, mode)
		var filtered_targets: Array[Node3D] = []
		for combat_target: Node3D in combat_targets:
			if not bool(combat_target.get_meta("captive", false)):
				filtered_targets.append(combat_target)
		return filtered_targets
	var result: Array[Node3D] = []
	var required_range: int = int(CombatCatalog.attack(mode).get("range", 4))
	if mode == "waiban_decoys":
		if int(attacker.get_meta("decoy_uses", 0)) > 0:
			result.append(attacker)
		return result
	if mode == "panther_teleport":
		if int(attacker.get_meta("teleport_uses", 0)) <= 0:
			return result
		result.append(attacker)
		for unit: Node3D in units:
			if _is_alive(unit) and str(unit.get_meta("team", "")) == "enemy" and _grid_distance(attacker, unit) <= required_range:
				result.append(unit)
		return result
	for unit: Node3D in units:
		if not _is_alive(unit) or str(unit.get_meta("team", "")) != str(attacker.get_meta("team", "")):
			continue
		if _grid_distance(attacker, unit) > required_range:
			continue
		var stats: Dictionary = _stats(unit)
		if mode == "engineer_heal" and int(stats.get("hp", 0)) >= int(stats.get("max_hp", 1)):
			continue
		if mode == "engineer_energy" and int(stats.get("energy", 0)) >= int(stats.get("max_energy", 0)):
			continue
		if mode == "engineer_armor" and int(attacker.get_meta("armor_uses", 0)) <= 0:
			continue
		if mode == "engineer_shield" and int(attacker.get_meta("shield_uses", 0)) <= 0:
			continue
		result.append(unit)
	return result


func _player_attack_target(mode: String = "slash") -> Node3D:
	if mission_number == 7 and mode in SUPPORT_MODES:
		var acting_unit: Node3D = player_unit
		if acting_unit != null and selected_unit != null and _eligible_targets(acting_unit, mode).has(selected_unit):
			return selected_unit
		return null
	return super._player_attack_target(mode)


func _resolve_attack(attacker: Node3D, target: Node3D, mode: String) -> void:
	if mission_number == 7 and mode in SUPPORT_MODES:
		await _resolve_support_action(attacker, target, mode)
		return
	if mission_number == 7 and target == ganlon_unit and _grid_distance(attacker, target) <= 1:
		var decoy: Node3D = _first_alive_decoy()
		if decoy != null:
			status_label.text = "Клон Waiban принимает ближний удар вместо Ganlon!"
			target = decoy
	await super._resolve_attack(attacker, target, mode)
	if mission_number == 7 and attacker == milea_unit and _is_alive(target) and rng.randf() <= 0.40:
		var stolen: int = rng.randi_range(20, 40)
		var target_stats: Dictionary = _stats(target)
		var attacker_stats: Dictionary = _stats(attacker)
		var actual: int = mini(stolen, int(target_stats.get("energy", 0)))
		target_stats["energy"] = maxi(0, int(target_stats.get("energy", 0)) - actual)
		attacker_stats["energy"] = mini(int(attacker_stats.get("max_energy", 0)), int(attacker_stats.get("energy", 0)) + actual)
		target.set_meta("stats", target_stats)
		attacker.set_meta("stats", attacker_stats)
		status_label.text = "Panther похищает %d энергии противника." % actual
	if mission_number == 7 and int(CombatCatalog.attack(mode).get("area_targets", 0)) > 1:
		await _apply_secondary_area_damage(attacker, target, mode)


func _resolve_support_action(attacker: Node3D, target: Node3D, mode: String) -> void:
	match mode:
		"engineer_heal":
			for ally: Node3D in units:
				if not _is_alive(ally) or str(ally.get_meta("team", "")) != str(attacker.get_meta("team", "")) or _grid_distance(attacker, ally) > 4:
					continue
				var stats: Dictionary = _stats(ally)
				stats["hp"] = mini(int(stats.get("max_hp", 1)), int(stats.get("hp", 0)) + 100)
				ally.set_meta("stats", stats)
				_refresh_hp_bar(ally)
				_spawn_guard_flash(ally.global_position + Vector3(0, 1.0, 0), Color(0.25, 1.0, 0.55))
			status_label.text = "Engineer ремонтирует всех союзников в радиусе четырёх клеток: +100 HP."
		"engineer_armor":
			target.set_meta("temporary_armor", int(target.get_meta("temporary_armor", 0)) + 200)
			attacker.set_meta("armor_uses", maxi(0, int(attacker.get_meta("armor_uses", 0)) - 1))
			_spawn_guard_flash(target.global_position + Vector3(0, 1.0, 0), Color(0.95, 0.78, 0.22))
			status_label.text = "%s получает 200 брони." % str(target.get_meta("label"))
		"engineer_energy":
			var stats: Dictionary = _stats(target)
			stats["energy"] = mini(int(stats.get("max_energy", 0)), int(stats.get("energy", 0)) + 50)
			target.set_meta("stats", stats)
			_spawn_guard_flash(target.global_position + Vector3(0, 1.0, 0), Color(0.35, 0.80, 1.0))
			status_label.text = "%s восстанавливает 50 энергии." % str(target.get_meta("label"))
		"engineer_shield":
			target.set_meta("engineer_shield_until_round", round_number + 1)
			attacker.set_meta("shield_uses", maxi(0, int(attacker.get_meta("shield_uses", 0)) - 1))
			_spawn_guard_flash(target.global_position + Vector3(0, 1.0, 0), Color(0.40, 0.95, 1.0))
			status_label.text = "Щит Engineer снижает входящий урон %s на 40%." % str(target.get_meta("label"))
		"panther_teleport":
			attacker.set_meta("teleport_uses", maxi(0, int(attacker.get_meta("teleport_uses", 0)) - 1))
			var destination: Vector2i = _safe_teleport_cell(target, target == attacker)
			_spawn_arrival_effect(target.global_position + Vector3(0, 1.0, 0))
			target.set_meta("cell", destination)
			target.position = _cell_to_world(destination)
			_spawn_arrival_effect(target.global_position + Vector3(0, 1.0, 0))
			status_label.text = "Panther телепортирует %s на клетку %d,%d." % [str(target.get_meta("label")), destination.x, destination.y]
		"waiban_decoys":
			_spawn_ganlon_decoys(attacker)
			attacker.set_meta("decoy_uses", maxi(0, int(attacker.get_meta("decoy_uses", 0)) - 1))
			status_label.text = "Waiban окружает Ganlon клонами-приманками по 100 HP."
	_refresh_ui()
	await get_tree().create_timer(0.35).timeout


func _damage_target(target: Node3D, damage: int) -> void:
	if mission_number == 7 and bool(target.get_meta("captive", false)):
		status_label.text = "%s защищён тюремным силовым полем до освобождения." % str(target.get_meta("label"))
		return
	await super._damage_target(target, damage)


func _calculate_damage(attacker: Node3D, target: Node3D, multiplier: float) -> int:
	var damage: int = super._calculate_damage(attacker, target, multiplier)
	var armor: int = int(target.get_meta("temporary_armor", 0))
	if armor > 0:
		var absorbed: int = mini(armor, damage)
		target.set_meta("temporary_armor", armor - absorbed)
		damage -= absorbed
	if round_number <= int(target.get_meta("engineer_shield_until_round", -1)):
		damage = int(round(float(damage) * 0.60))
	return maxi(0, damage)


func _safe_teleport_cell(target: Node3D, self_cast: bool) -> Vector2i:
	var best: Vector2i = target.get_meta("cell")
	var best_score: int = -999999
	for x: int in range(1, grid_width - 1):
		for y: int in range(1, grid_height - 1):
			var cell := Vector2i(x, y)
			if blocked_cells.has(cell) or _unit_at(cell) != null:
				continue
			var score: int = 0
			for unit: Node3D in units:
				if not _is_alive(unit) or unit == target:
					continue
				var unit_cell: Vector2i = unit.get_meta("cell")
				var distance_score: int = int(round(cell.distance_to(unit_cell)))
				if self_cast and str(unit.get_meta("team", "")) == "enemy":
					score += distance_score
				elif not self_cast and str(unit.get_meta("team", "")) == str(target.get_meta("team", "")):
					score += distance_score
			if score > best_score:
				best_score = score
				best = cell
	return best


func _spawn_ganlon_decoys(owner: Node3D) -> void:
	var owner_cell: Vector2i = owner.get_meta("cell")
	for delta: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		var cell: Vector2i = owner_cell + delta
		if not _cell_in_bounds(cell) or blocked_cells.has(cell) or _unit_at(cell) != null:
			continue
		var decoy: Node3D = _spawn_unit("Клон Waiban", "Приманка • не атакует", "waiban", cell, false, false, str(owner.get_meta("team", "ally")), "waiban_decoy")
		var stats: Dictionary = _stats(decoy)
		stats["hp"] = 100
		stats["max_hp"] = 100
		stats["strength"] = 0
		stats["attack_skill"] = 0
		stats["move_range"] = 0
		decoy.set_meta("stats", stats)
		decoy.set_meta("decoy", true)
		decoy.set_meta("attack_override", [])
		mission_seven_decoys.append(decoy)
		_refresh_hp_bar(decoy)


func _first_alive_decoy() -> Node3D:
	for decoy: Node3D in mission_seven_decoys:
		if decoy != null and is_instance_valid(decoy) and _is_alive(decoy):
			return decoy
	return null


func _apply_secondary_area_damage(attacker: Node3D, primary: Node3D, mode: String) -> void:
	var data: Dictionary = CombatCatalog.attack(mode)
	var maximum: int = maxi(1, int(data.get("area_targets", 1)) - 1)
	var ratio: float = float(data.get("secondary_ratio", 0.55))
	var candidates: Array[Node3D] = []
	for unit: Node3D in units:
		if unit == primary or not _is_alive(unit) or str(unit.get_meta("team", "")) == str(attacker.get_meta("team", "")):
			continue
		if _grid_distance(primary, unit) <= 2:
			candidates.append(unit)
	candidates.sort_custom(func(a: Node3D, b: Node3D): return _grid_distance(primary, a) < _grid_distance(primary, b))
	for index: int in range(mini(maximum, candidates.size())):
		var secondary: Node3D = candidates[index]
		var damage: int = _calculate_damage(attacker, secondary, float(data.get("multiplier", 1.0)) * ratio)
		await _damage_target(secondary, damage)


func _clear_expired_support_effects() -> void:
	for unit: Node3D in units:
		if round_number > int(unit.get_meta("engineer_shield_until_round", -1)):
			unit.remove_meta("engineer_shield_until_round")


func _play_attack_animation(attacker: Node3D, target: Node3D, mode: String) -> void:
	match mode:
		"evil_heart":
			await _animate_evil_heart_v20(attacker, target)
		"geno_flame":
			await _animate_geno_flame_v20(attacker, target)
		"rocket_shot", "area_rocket":
			await _animate_rocket_v20(attacker, target, mode == "area_rocket")
		"frost", "iceberg", "ice_age", "northern_lights":
			await _animate_ice_field_v20(attacker, target, mode)
		"storm_vortex":
			await _animate_storm_vortex_v20(attacker, target)
		"engineer_heal", "engineer_armor", "engineer_energy", "engineer_shield", "panther_teleport", "waiban_decoys":
			await _animate_support_pulse_v20(attacker, target, mode)
		_:
			await super._play_attack_animation(attacker, target, mode)


func _animate_evil_heart_v20(attacker: Node3D, target: Node3D) -> void:
	_face_target(attacker, target)
	status_label.text = "%s выпускает «Злое сердце»" % str(attacker.get_meta("label"))
	var orb := Node3D.new()
	_register_transient_fx(orb, 2.0)
	orb.global_position = attacker.global_position + Vector3(0, 1.25, 0)
	for offset: Vector3 in [Vector3(-0.10, 0.08, 0), Vector3(0.10, 0.08, 0), Vector3(0, -0.08, 0)]:
		var part := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.14
		mesh.height = 0.28
		part.mesh = mesh
		part.position = offset
		part.material_override = _effect_material(Color(0.95, 0.01, 0.12, 0.95))
		orb.add_child(part)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_property(orb, "global_position", target.global_position + Vector3(0, 1.0, 0), 0.32)
	await tween.finished
	await CinematicVfx.play(self, "evil_heart", target.global_position + Vector3(0, 0.08, 0), 1.26, 0.095)
	for index: int in range(3):
		_spawn_heavy_arc(target.global_position + Vector3(0, 0.80 + index * 0.08, 0), Color(0.75, 0.0, 0.08))
	_camera_shake(0.72, 0.30)
	orb.queue_free()


func _animate_geno_flame_v20(attacker: Node3D, target: Node3D) -> void:
	_face_target(attacker, target)
	status_label.text = "%s возводит стену «Гено-пламени»" % str(attacker.get_meta("label"))
	var direction: Vector3 = (target.global_position - attacker.global_position).normalized()
	for index: int in range(6):
		var flame := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.05
		mesh.bottom_radius = 0.32
		mesh.height = 1.7
		flame.mesh = mesh
		flame.material_override = _effect_material(Color(1.0, 0.12 + index * 0.035, 0.01, 0.86))
		flame.global_position = attacker.global_position.lerp(target.global_position, float(index + 1) / 6.0) + Vector3(0, 0.85, 0) + Vector3(-direction.z, 0, direction.x) * sin(float(index)) * 0.35
		flame.scale = Vector3(0.1, 0.1, 0.1)
		_register_transient_fx(flame, 1.4)
		var tween := create_tween()
		tween.tween_property(flame, "scale", Vector3(1.0, 1.0 + float(index % 3) * 0.25, 1.0), 0.18)
		tween.tween_interval(0.22)
		tween.tween_property(flame, "scale", Vector3.ZERO, 0.20)
		tween.tween_callback(Callable(flame, "queue_free"))
	await CinematicVfx.play(self, "geno_flame", target.global_position + Vector3(0, 0.05, 0), 1.30, 0.095)
	_camera_shake(0.62, 0.28)


func _animate_rocket_v20(attacker: Node3D, target: Node3D, area: bool) -> void:
	_face_target(attacker, target)
	status_label.text = "%s запускает %s" % [str(attacker.get_meta("label")), "ракетный залп" if area else "ракету"]
	var count: int = 3 if area else 1
	for index: int in range(count):
		var rocket := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.07
		mesh.height = 0.42
		rocket.mesh = mesh
		rocket.rotation_degrees.x = 90.0
		rocket.material_override = _effect_material(Color(1.0, 0.30, 0.04, 0.98))
		rocket.global_position = attacker.global_position + Vector3(0, 1.15 + index * 0.08, 0)
		_register_transient_fx(rocket, 1.5)
		var destination: Vector3 = target.global_position + Vector3(float(index - 1) * 0.32, 0.85, float(index % 2) * 0.18)
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(rocket, "global_position", destination + Vector3(0, 1.2, 0), 0.18)
		tween.tween_property(rocket, "global_position", destination, 0.12)
		await tween.finished
		_spawn_attack_burst(destination, Color(1.0, 0.25, 0.02), 1.35 if area else 0.95)
		rocket.queue_free()
	await CinematicVfx.play(self, "area_rocket" if area else "rocket_shot", target.global_position + Vector3(0, 0.08, 0), 1.22 if area else 1.08, 0.09)
	_camera_shake(0.58 if area else 0.35, 0.25)


func _animate_ice_field_v20(attacker: Node3D, target: Node3D, mode: String) -> void:
	_face_target(attacker, target)
	status_label.text = "%s применяет «%s»" % [str(attacker.get_meta("label")), str(CombatCatalog.attack(mode).get("label", mode))]
	var cinematic_mode: String = "ice_age" if mode == "ice_age" else "frost"
	var amount: int = 7 if mode == "ice_age" else 5
	for index: int in range(amount):
		var shard := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.16 + float(index % 3) * 0.05, 0.75 + float(index % 4) * 0.18, 0.18)
		shard.mesh = mesh
		var angle: float = TAU * float(index) / float(amount)
		var radius: float = 0.45 + float(index % 4) * 0.32
		shard.global_position = target.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		shard.rotation_degrees.y = rad_to_deg(angle)
		shard.material_override = _effect_material(Color(0.35, 0.78, 1.0, 0.88))
		shard.scale = Vector3(0.05, 0.05, 0.05)
		_register_transient_fx(shard, 1.5)
		var tween := create_tween()
		tween.tween_property(shard, "scale", Vector3.ONE, 0.16 + float(index % 3) * 0.03)
		tween.tween_interval(0.28)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.18)
		tween.tween_callback(Callable(shard, "queue_free"))
	await CinematicVfx.play(self, cinematic_mode, target.global_position + Vector3(0, 0.04, 0), 1.30 if mode == "ice_age" else 1.12, 0.10)
	_camera_shake(0.48, 0.22)


func _animate_storm_vortex_v20(attacker: Node3D, target: Node3D) -> void:
	await _animate_tornado(attacker, target)
	for index: int in range(4):
		var bolt := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.035, 0.75 + float(index % 3) * 0.2)
		bolt.mesh = mesh
		bolt.global_position = target.global_position + Vector3(cos(float(index)) * 0.75, 0.7 + float(index % 4) * 0.25, sin(float(index)) * 0.75)
		bolt.rotation_degrees = Vector3(25.0 + index * 5.0, index * 31.0, -35.0 + index * 6.0)
		bolt.material_override = _effect_material(Color(0.35, 0.65, 1.0, 0.92))
		_register_transient_fx(bolt, 1.2)
		var tween := create_tween()
		tween.tween_property(bolt, "scale", Vector3(1.0, 1.0, 1.5), 0.10)
		tween.tween_property(bolt, "scale", Vector3.ZERO, 0.16)
		tween.tween_callback(Callable(bolt, "queue_free"))
	await CinematicVfx.play(self, "storm_vortex", target.global_position + Vector3(0, 0.05, 0), 1.34, 0.10)
	_camera_shake(0.70, 0.30)


func _animate_support_pulse_v20(attacker: Node3D, target: Node3D, mode: String) -> void:
	_face_target(attacker, target)
	var color: Color = Color(0.30, 0.95, 1.0)
	if mode == "engineer_heal":
		color = Color(0.25, 1.0, 0.48)
	elif mode == "engineer_armor":
		color = Color(1.0, 0.78, 0.22)
	elif mode == "panther_teleport":
		color = Color(0.70, 0.20, 1.0)
	for index: int in range(5):
		_spawn_guard_flash(target.global_position + Vector3(0, 0.45 + index * 0.24, 0), color)
	await get_tree().create_timer(0.30).timeout


func _show_victory() -> void:
	if mission_number != 7:
		await super._show_victory()
		return
	if mission_seven_victory_started:
		return
	mission_seven_victory_started = true
	action_in_progress = true
	phase = Phase.DIALOGUE
	if galvas_prisoner != null and is_instance_valid(galvas_prisoner):
		galvas_prisoner.set_meta("team", "ally")
	if ganlon_unit != null and is_instance_valid(ganlon_unit):
		ganlon_unit.set_meta("team", "ally")
	if not _is_headless_or_smoke_runtime():
		await _show_dialogue("Galvas", "Ты вернулся за нами, Bastion. Сегодня падший король снова поднимет оружие рядом с твоим отрядом.", GALVAS_PORTRAIT)
		await _show_dialogue("Ganlon", "Waiban освобождён. Мои клоны и мой клинок теперь служат общему делу.", GANLON_PORTRAIT)
		if relief_spawned:
			await _show_dialogue("Bastion", "Мы выстояли только потому, что союз оказался настоящим. В следующей битве мы ответим тем же.", BASTION_PORTRAIT_V12)
	var reward: Dictionary = CampaignState.complete_mission(7)
	status_label.text = "Замок взят. Galvas и Ganlon спасены. Награда: %d монет." % int(reward.get("awarded", 0))
	print("MISSION7_VICTORY_OK relief=%s alliance=%s" % [str(relief_spawned), CampaignState.kingdom_alliance])
	await get_tree().create_timer(0.6).timeout
	_return_to_campaign_hub()
