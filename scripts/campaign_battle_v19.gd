extends "res://scripts/campaign_battle_v18.gd"

const MISSION_SIX_PATH := "res://data/maps/mission_06.json"
const LOGAN_PORTRAIT := "res://assets/ui/portraits/logan.png"
const CLAIRE_PORTRAIT := "res://assets/ui/portraits/claire.png"
const SHION_PORTRAIT := "res://assets/ui/portraits/shion.png"
const ALDEN_PORTRAIT := "res://assets/ui/portraits/alden.png"
const DEVLIN_PORTRAIT := "res://assets/ui/portraits/devlin.png"
const BARLOW_PORTRAIT := "res://assets/ui/portraits/barlow.png"

var kingdom_choice := "south"
var south_bots: Array[Node3D] = []
var north_bots: Array[Node3D] = []
var southern_reinforcement_spawned := false
var alden_unit: Node3D
var devlin_unit: Node3D
var logan_unit: Node3D
var zeira_unit_five: Node3D
var devlin_clone: Node3D
var mission_six_finished := false
var mission_six_intro_pending := false
var choice_dialog_done := false
var mission_six_boot_started := false
var mission_six_boot_finalized := false
var mission_six_forced_choice: String = ""

func _ready() -> void:
	if CampaignState.current_mission == 6 and CampaignState.kamorge_alive and CampaignState.test_forced_branch not in ["south", "north"]:
		# Mission VI is exclusive to the branch where Kamorge died. Repair old
		# saves that were incorrectly routed here by version 1.9.4.
		CampaignState.current_mission = 5
		CampaignState.save_game()
		call_deferred("_return_to_campaign_hub")
		return
	if CampaignState.current_mission == 6:
		mission_six_intro_pending = true
		if CampaignState.test_forced_branch in ["south", "north"]:
			mission_six_forced_choice = CampaignState.test_forced_branch
			kingdom_choice = mission_six_forced_choice
			# Consume only the test/replay selector value. It chooses the branch but
			# must not suppress dialogue in a normal Windows playthrough.
			CampaignState.test_forced_branch = ""
		# Start chapter-VI finalisation independently from the inherited async
		# _ready() chain.  In 1.9.7 the inherited coroutine could finish its
		# synchronous map/unit boot yet never resume this override, leaving the
		# intro lock permanently enabled.  The deferred finaliser waits for the
		# real BattlePrototype state and therefore cannot race unit creation.
		call_deferred("_finalize_mission_six_boot")
	# Keep the inherited chapter initialisation intact.  The independent
	# finaliser above guarantees mission VI is unlocked even if an inherited
	# coroutine does not propagate completion back to this override.
	await super._ready()
	if mission_number == 6:
		call_deferred("_finalize_mission_six_boot")


func _finalize_mission_six_boot() -> void:
	if mission_six_boot_started or mission_six_boot_finalized:
		return
	mission_six_boot_started = true
	# Wait for the normal BattlePrototype lifecycle to create the map and all
	# five controllable heroes.  This is state-based, not a fixed delay.
	while is_inside_tree() and (mission_number != 6 or units.is_empty() or player_party.size() != 5):
		await get_tree().process_frame
	if not is_inside_tree() or mission_number != 6:
		mission_six_boot_started = false
		return
	action_in_progress = true
	phase = Phase.DIALOGUE
	if not _is_headless_or_smoke_runtime():
		await _play_mission_six_intro()
		if mission_six_forced_choice in ["south", "north"]:
			kingdom_choice = mission_six_forced_choice
		else:
			await _request_kingdom_choice()
	else:
		# CI and runtime smokes must never wait for UI input. The branch was
		# captured before the inherited ready chain entered the battle scene.
		if mission_six_forced_choice in ["south", "north"]:
			kingdom_choice = mission_six_forced_choice
	_apply_kingdom_choice()
	if not _is_headless_or_smoke_runtime():
		await _play_mission_six_choice_dialogue()
	mission_six_intro_pending = false
	action_in_progress = false
	mission_six_boot_finalized = true
	print("MISSION6_BOOT_FINALIZED branch=%s units=%d party=%d" % [kingdom_choice, units.size(), player_party.size()])
	mission_six_boot_started = false
	_begin_player_turn()


func _play_mission_six_intro() -> void:
	await _show_dialogue("Zeira", "Здесь нас не найдут до рассвета. Ione, проверь северную тропу. Reyna, останься у реки.", ZEIRA_PORTRAIT)
	await _show_dialogue("Andrew", "Мы обязаны вам жизнью. Без вас имперцы закончили бы начатое у моста.", ANDREW_PORTRAIT_V12)
	await _show_dialogue("Ione", "На дороге тихо, но на юге поднимается дым. Там движется целая армия.", IONE_PORTRAIT)
	await _show_dialogue("Bastion", "Kamorge погиб, спасая нас. Я не позволю, чтобы его смерть оказалась напрасной.", BASTION_PORTRAIT_V12)
	await _show_dialogue("Bastion", "Zeira, помоги провести нас до Южного королевства. Король Logan знал союзников моего отца. Нам нужны люди и безопасный путь.", BASTION_PORTRAIT_V12)
	await _show_dialogue("Zeira", "Я не служу королям, Bastion. Но сейчас у нас общий враг. Мы с Ione и Reyna доведём вас до границы.", ZEIRA_PORTRAIT)
	await _show_dialogue("Reyna", "Тогда идём сейчас. Через старый лес быстрее, а тяжёлые ATAC империи там не пройдут.", REYNA_PORTRAIT)
	await _show_dialogue("Ione", "Стойте. Это не имперцы. На равнине сражаются Северное и Южное королевства.", IONE_PORTRAIT)
	await _show_dialogue("Logan", "Crimson, вперёд! Северяне не получат эту границу и не приблизятся к землям моей дочери.", LOGAN_PORTRAIT)
	await _show_dialogue("Claire", "Отец, их слишком много. Южные рыцари долго не удержат центр.", CLAIRE_PORTRAIT)
	await _show_dialogue("Shion", "Rahabor прикроет вас, госпожа. Пока я стою, ни один северный клинок вас не коснётся.", SHION_PORTRAIT)
	await _show_dialogue("Alden", "Logan снова называет захват защитой. Altagrave положит конец этой войне сегодня.", ALDEN_PORTRAIT)
	await _show_dialogue("Devlin", "Северный строй держать. Snow Soldier берёт центр, Ratatosk обходят южан с фланга.", DEVLIN_PORTRAIT)
	await _show_dialogue("Barlow", "Я рядом, Devlin. Но к полю подошёл ещё один отряд. Они не несут знамён ни Севера, ни Юга.", BARLOW_PORTRAIT)
	await _show_dialogue("Andrew", "Обе стороны заметили нас. Пройти незамеченными уже не получится.", ANDREW_PORTRAIT_V12)
	await _show_dialogue("Bastion", "Тогда решим сейчас. Тот, кому мы поможем, станет нашим будущим союзником. Отвергнутая сторона объявит врагами и нас.", BASTION_PORTRAIT_V12)


func _play_mission_six_choice_dialogue() -> void:
	if kingdom_choice == "south":
		await _show_dialogue("Bastion", "Мы поддержим Южное королевство. Logan, примите наш отряд в бой.", BASTION_PORTRAIT_V12)
		await _show_dialogue("Logan", "Сражайся рядом с Crimson и докажи свои слова, Bastion. Выстоим — поговорим о союзе и военной помощи.", LOGAN_PORTRAIT)
		await _show_dialogue("Claire", "Южные рыцари, освободите им место. Сегодня они сражаются рядом с нами.", CLAIRE_PORTRAIT)
		await _show_dialogue("Shion", "Я прикрою Claire. Не мешайте моей линии атаки — и Rahabor прикроет вашу.", SHION_PORTRAIT)
		await _show_dialogue("Alden", "Вы выбрали сторону Logan. С этого мгновения Север считает ваш отряд противником.", ALDEN_PORTRAIT)
		await _show_dialogue("Devlin", "Цели подтверждены: южная армия и отряд Bastion. Никого не выпускать с поля.", DEVLIN_PORTRAIT)
	else:
		await _show_dialogue("Bastion", "Мы поддержим Северное королевство. Alden, примите наш отряд в бой.", BASTION_PORTRAIT_V12)
		await _show_dialogue("Alden", "Север помнит тех, кто приходит в тяжёлый час. Победим — обсудим союз и помощь твоему королевству.", ALDEN_PORTRAIT)
		await _show_dialogue("Devlin", "Отряд Bastion входит в северный строй. Snow Soldier и Ratatosk не атакуют новых союзников.", DEVLIN_PORTRAIT)
		await _show_dialogue("Barlow", "Хорошо. Держитесь рядом, и мы прорвём южный центр вместе.", BARLOW_PORTRAIT)
		await _show_dialogue("Logan", "Ты пришёл просить помощи и поднял оружие против Юга. Crimson ответит за это без пощады.", LOGAN_PORTRAIT)
		await _show_dialogue("Claire", "Отец, они сделали выбор. Южным рыцарям придётся остановить и их.", CLAIRE_PORTRAIT)
		await _show_dialogue("Shion", "Все, кто угрожает Claire, становятся моими целями. Даже наследник павшего королевства.", SHION_PORTRAIT)

func _load_first_mission() -> void:
	if CampaignState.current_mission != 6:
		super._load_first_mission()
		return
	mission_number = 6
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSION_SIX_PATH))
	if parsed is Dictionary:
		map_data = parsed as Dictionary
	else:
		push_error("Mission VI map is missing or invalid: %s" % MISSION_SIX_PATH)
		map_data = {"name": "Глава VI — Война Севера и Юга", "width": 32, "height": 18, "player_starts": {}, "south_starts": {"bots": []}, "north_starts": {"bots": []}, "south_reinforcements": []}
	grid_width = int(map_data.get("width", 32))
	grid_height = int(map_data.get("height", 18))
	blocked_cells = {}
	river_cells = {}
	swamp_cells = {}
	title_label.text = str(map_data.get("name","Глава VI — Война Севера и Юга"))
	var parsed_balance: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if parsed_balance is Dictionary:
		balance_data = parsed_balance as Dictionary

func _spawn_mission_units() -> void:
	if mission_number != 6:
		super._spawn_mission_units()
		return
	var p: Dictionary = map_data.get("player_starts",{})
	player_unit = _spawn_campaign_hero("bastion","alba",_array_to_cell(p.get("bastion",[15,14])),"bastion_alba",BASTION_PORTRAIT_V12,"Наследник королевства • игрок")
	andrew_unit = _spawn_campaign_hero("andrew","vedocorban",_array_to_cell(p.get("andrew",[14,15])),"andrew_vedocorban",ANDREW_PORTRAIT_V12,"Соратник Bastion • игрок")
	zeira_unit_five = _spawn_campaign_hero("zeira","toreadore",_array_to_cell(p.get("zeira",[16,15])),"zeira_toreadore",ZEIRA_PORTRAIT,"Предводитель партизан • игрок")
	ione_unit = _spawn_campaign_hero("ione","amphisia",_array_to_cell(p.get("ione",[13,14])),"ione_amphisia",IONE_PORTRAIT,"Разведчица • игрок")
	reyna_unit = _spawn_campaign_hero("reyna","haurol",_array_to_cell(p.get("reyna",[17,14])),"reyna_haurol",REYNA_PORTRAIT,"Копейщица • игрок")
	_spawn_south()
	_spawn_north()
	# Mission VI bypasses the inherited chapter-specific spawn branches, so the
	# five controllable heroes must be registered here before the first turn.
	_setup_player_party()

func _spawn_south() -> void:
	var s: Dictionary = map_data.get("south_starts",{})
	logan_unit = _spawn_campaign_hero("logan","crimson",_array_to_cell(s.get("logan",[25,8])),"logan_crimson",LOGAN_PORTRAIT,"Король Южного королевства")
	_prepare_kingdom_ai_unit(logan_unit, "south")
	_apply_unit_level(logan_unit, "crimson", 25, 52, 34, 45, 48)
	logan_unit.set_meta("passive_ability", "logan_reflect")
	logan_unit.set_meta("max_move_actions", 2)
	logan_unit.set_meta("double_turn", true)
	logan_unit.set_meta("damage_magic_uses", 2)
	var claire := _spawn_campaign_hero("claire","rahabar",_array_to_cell(s.get("claire",[27,7])),"claire_rahabar",CLAIRE_PORTRAIT,"Принцесса Юга")
	_prepare_kingdom_ai_unit(claire, "south")
	_apply_unit_level(claire,"rahabar",15,32,31,29,33)
	var shion := _spawn_campaign_hero("shion","rahabar",_array_to_cell(s.get("shion",[27,9])),"shion_rahabar",SHION_PORTRAIT,"Телохранитель Claire")
	_prepare_kingdom_ai_unit(shion, "south")
	_apply_unit_level(shion,"rahabar",22,42,38,37,40)
	for i in range((s.get("bots",[]) as Array).size()):
		var u := _spawn_unit("Южный рыцарь %d / Rahabor"%(i+1),"Nordilian • Южное королевство","rahabar",_array_to_cell((s.get("bots",[]) as Array)[i]),false,false,"south","nordilian_rahabar")
		_apply_unit_level(u, "rahabar", 10 + i % 6, 24 + i, 22 + i, 24 + i, 24 + i)
		u.set_meta("portrait_path", "res://assets/ui/portraits/nordilian.png")
		south_bots.append(u)

func _spawn_north() -> void:
	var n: Dictionary = map_data.get("north_starts",{})
	alden_unit = _spawn_campaign_hero("alden","altagrave",_array_to_cell(n.get("alden",[6,8])),"alden_altagrave",ALDEN_PORTRAIT,"Король Северного королевства")
	_prepare_kingdom_ai_unit(alden_unit, "north")
	_apply_unit_level(alden_unit, "altagrave", 24, 48, 36, 45, 48)
	alden_unit.set_meta("magic_immune", true)
	alden_unit.set_meta("passive_ability", "alden_iceberg")
	devlin_unit = _spawn_campaign_hero("devlin","snow_soldier",_array_to_cell(n.get("devlin",[4,7])),"devlin_snow_soldier",DEVLIN_PORTRAIT,"Генерал Севера")
	_prepare_kingdom_ai_unit(devlin_unit, "north")
	_apply_unit_level(devlin_unit, "snow_soldier", 19, 38, 35, 37, 43)
	devlin_unit.set_meta("clone_uses", 1)
	var barlow := _spawn_campaign_hero("barlow","ratatosk",_array_to_cell(n.get("barlow",[4,9])),"barlow_ratatosk",BARLOW_PORTRAIT,"Верный друг Devlin")
	_prepare_kingdom_ai_unit(barlow, "north")
	_apply_unit_level(barlow,"ratatosk",14,31,29,33,34)
	for i in range((n.get("bots",[]) as Array).size()):
		var u := _spawn_unit("Северный боец %d / Ratatosk"%(i+1),"Matisse • Северное королевство","ratatosk",_array_to_cell((n.get("bots",[]) as Array)[i]),false,false,"north","matisse_ratatosk")
		_apply_unit_level(u, "ratatosk", 10 + i % 6, 24 + i, 22 + i, 25 + i, 24 + i)
		u.set_meta("portrait_path", "res://assets/ui/portraits/matisse.png")
		north_bots.append(u)


func _prepare_kingdom_ai_unit(unit: Node3D, staging_team: String) -> void:
	if unit == null:
		return
	# _spawn_campaign_hero creates a controllable ally by default. Kingdom leaders
	# are AI units and must remain on their own side until the player's choice is
	# applied, otherwise both royal families become player allies.
	unit.set_meta("player", false)
	unit.set_meta("team", staging_team)
	unit.set_meta("round_done", false)


func _set_mission_six_combat_team(unit: Node3D, team: String) -> void:
	if unit == null:
		return
	unit.set_meta("team", team)
	unit.set_meta("player", false)
	var visual: Node3D = unit.get_node_or_null("ATACVisual") as Node3D
	if visual != null:
		visual.rotation_degrees.y = 180.0 if bool(visual.get_meta("multiview_2_5d", false)) else (180.0 if team == "ally" else 0.0)
	var ring: MeshInstance3D = unit.get_node_or_null("SelectionRing") as MeshInstance3D
	if ring != null:
		var ring_material := StandardMaterial3D.new()
		ring_material.albedo_color = Color(0.36, 0.86, 1.0) if team == "ally" else Color(0.95, 0.24, 0.18)
		ring_material.emission_enabled = true
		ring_material.emission = ring_material.albedo_color * 0.85
		ring.material_override = ring_material
	var hp_bar: Label3D = unit.get_node_or_null("HPBar") as Label3D
	if hp_bar != null:
		hp_bar.modulate = Color(0.72, 0.95, 1.0) if team == "ally" else Color(1.0, 0.82, 0.72)

func _setup_player_party() -> void:
	if mission_number != 6:
		super._setup_player_party()
		return
	player_party.clear()
	for u: Node3D in [player_unit, andrew_unit, zeira_unit_five, ione_unit, reyna_unit]:
		if u != null and is_instance_valid(u) and _is_alive(u) and not player_party.has(u):
			u.set_meta("player", true)
			u.set_meta("team", "ally")
			player_party.append(u)
	if player_party.size() != 5:
		push_error("Mission VI player party is incomplete: expected 5, got %d." % player_party.size())

func _request_kingdom_choice() -> void:
	choice_dialog_done = false
	var dialog := ConfirmationDialog.new()
	dialog.title = "Выбор союзника"
	dialog.dialog_text = "Кому помочь в войне королевств?"
	dialog.ok_button_text = "Южному королевству"
	dialog.add_button("Северному королевству", false, "north")
	add_child(dialog)
	dialog.confirmed.connect(_choose_south)
	dialog.custom_action.connect(_choose_custom_kingdom)
	dialog.canceled.connect(_choose_south)
	dialog.popup_centered(Vector2i(540, 240))
	while not choice_dialog_done:
		await get_tree().process_frame
	dialog.queue_free()


func _choose_south() -> void:
	kingdom_choice = "south"
	choice_dialog_done = true


func _choose_custom_kingdom(action: StringName) -> void:
	if str(action) == "north":
		kingdom_choice = "north"
	choice_dialog_done = true

func _apply_kingdom_choice() -> void:
	for u: Node3D in units:
		var team := str(u.get_meta("team"))
		if team == "south":
			_set_mission_six_combat_team(u, "ally" if kingdom_choice == "south" else "enemy")
		elif team == "north":
			_set_mission_six_combat_team(u, "ally" if kingdom_choice == "north" else "enemy")
	var side_label := "Южному" if kingdom_choice == "south" else "Северному"
	status_label.text = "Вы помогаете %s королевству. Отвергнутая сторона атакует и ваш отряд." % side_label

func _begin_player_turn() -> void:
	if mission_number == 6 and mission_six_intro_pending:
		return
	if mission_number == 6:
		_check_south_reinforcement()
	super._begin_player_turn()


func _apply_alden_aura() -> void:
	if alden_unit == null or not _is_alive(alden_unit):
		return
	var team := str(alden_unit.get_meta("team"))
	for u: Node3D in units:
		if not _is_alive(u) or str(u.get_meta("team")) != team:
			continue
		var st := _stats(u)
		st["hp"] = mini(int(st.get("max_hp", 1)), int(st.get("hp", 0)) + 50)
		st["energy"] = mini(int(st.get("max_energy", 100)), int(st.get("energy", 0)) + 30)
		u.set_meta("stats", st)
		_refresh_hp_bar(u)


func _check_south_reinforcement() -> void:
	if southern_reinforcement_spawned:
		return
	for u: Node3D in south_bots:
		if _is_alive(u):
			return
	southern_reinforcement_spawned = true
	var cells: Array = map_data.get("south_reinforcements", [])
	for i: int in range(cells.size()):
		var team := "ally" if kingdom_choice == "south" else "enemy"
		var u := _spawn_unit(
			"Южная подмога %d / Rahabor" % (i + 1),
			"Nordilian • резерв",
			"rahabar",
			_array_to_cell(cells[i]),
			false, false, team, "nordilian_rahabar"
		)
		_apply_unit_level(u, "rahabar", 10 + i % 6, 25 + i, 23 + i, 25 + i, 25 + i)
		u.set_meta("portrait_path", "res://assets/ui/portraits/nordilian.png")
		south_bots.append(u)
	status_label.text = "К Южному королевству прибыла подмога из шести Rahabor!"

func _resolve_attack(attacker: Node3D, target: Node3D, mode: String) -> void:
	if target == alden_unit and str(attacker.get_meta("team", "")) != str(target.get_meta("team", "")) and bool(target.get_meta("magic_immune", false)) and CombatCatalog.is_magic(mode):
		status_label.text = "Altagrave полностью невосприимчив к вражеской магии."
		_spawn_guard_flash(target.global_position + Vector3(0, 1, 0), Color(0.5, 0.85, 1.0))
		await _try_alden_iceberg_retaliation(attacker)
		return
	if mode == "devlin_combo":
		status_label.text = "Комбо Snow Soldier невозможно заблокировать!"
		var combo_damage: int = _calculate_damage(attacker, target, float(CombatCatalog.attack(mode).get("multiplier", 3.45)))
		await _damage_target(target, combo_damage)
	else:
		await super._resolve_attack(attacker, target, mode)
	if float(attacker.get_meta("logan_damage_boost", 1.0)) > 1.0:
		attacker.set_meta("logan_damage_boost", 1.0)
	if target == alden_unit:
		await _try_alden_iceberg_retaliation(attacker)
	# Reinforcements must appear immediately when the original six Rahabor are
	# destroyed. Waiting until the next player turn could incorrectly finish the
	# battle first when the royal leaders had already fallen.
	if mission_number == 6 and not southern_reinforcement_spawned:
		_check_south_reinforcement()


func _try_alden_iceberg_retaliation(attacker: Node3D) -> void:
	if alden_unit == null or not _is_alive(alden_unit) or attacker == null or not _is_alive(attacker):
		return
	if str(attacker.get_meta("team", "")) == str(alden_unit.get_meta("team", "")):
		return
	if rng.randf() > 0.50:
		return
	status_label.text = "Ответная магия Alden: на атакующего падает айсберг!"
	await _animate_ice_rain(alden_unit, attacker)
	var retaliation: int = maxi(1, int(float(_stats(alden_unit).get("strength", 40)) * 2.0))
	await _damage_target(attacker, retaliation)


func _calculate_damage(attacker: Node3D, target: Node3D, multiplier: float) -> int:
	var damage: int = super._calculate_damage(attacker, target, multiplier)
	damage = maxi(1, int(round(float(damage) * float(attacker.get_meta("logan_damage_boost", 1.0)))))
	return damage


func _try_automatic_passive(defender: Node3D, attacker: Node3D, back_attack: bool) -> String:
	if str(defender.get_meta("passive_ability", "")) == "logan_reflect" and rng.randf() <= 0.45:
		status_label.text = "Crimson отражает атаку Logan!"
		await _animate_sharking_reflect(defender, attacker)
		return "avoided"
	return await super._try_automatic_passive(defender, attacker, back_attack)

func _run_smart_ai_turn(unit: Node3D) -> void:
	if unit == alden_unit:
		_apply_alden_aura()
		await get_tree().create_timer(0.25).timeout
	if unit == devlin_unit and int(unit.get_meta("clone_uses", 0)) > 0 and devlin_clone == null:
		var clone_cell: Vector2i = _first_free_adjacent_cell(unit)
		if clone_cell.x >= 0:
			unit.set_meta("clone_uses", 0)
			devlin_clone = _spawn_unit(
				"Клон Devlin / Snow Soldier", "Ледяной клон 60%",
				"snow_soldier", clone_cell, false, false,
				str(unit.get_meta("team")), "devlin_snow_soldier"
			)
			var clone_stats: Dictionary = _stats(unit).duplicate(true)
			for key: String in ["hp", "max_hp", "strength", "agility", "defense", "attack_skill"]:
				clone_stats[key] = maxi(1, int(float(clone_stats.get(key, 1)) * 0.60))
			devlin_clone.set_meta("stats", clone_stats)
			devlin_clone.set_meta("clone_of_devlin", true)
			_refresh_hp_bar(devlin_clone)
			status_label.text = "Devlin создаёт ледяного клона с 60% характеристик."
			await get_tree().create_timer(0.4).timeout
			return
	if unit == logan_unit:
		await _try_logan_damage_magic()
		await super._run_smart_ai_turn(unit)
		if _is_alive(unit) and _nearest_opponent(unit) != null:
			status_label.text = "Crimson получает второй полноценный ход Logan."
			await get_tree().create_timer(0.18).timeout
			await super._run_smart_ai_turn(unit)
		return
	await super._run_smart_ai_turn(unit)


func _first_free_adjacent_cell(unit: Node3D) -> Vector2i:
	var origin: Vector2i = unit.get_meta("cell")
	for delta: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var candidate: Vector2i = origin + delta
		if _cell_in_bounds(candidate) and not blocked_cells.has(candidate) and _unit_at(candidate) == null:
			return candidate
	return Vector2i(-1, -1)


func _try_logan_damage_magic() -> void:
	var uses: int = int(logan_unit.get_meta("damage_magic_uses", 0)) if logan_unit != null else 0
	if uses <= 0 or round_number not in [1, 4]:
		return
	var team: String = str(logan_unit.get_meta("team"))
	var target: Node3D = logan_unit
	var best_strength: int = int(_stats(logan_unit).get("strength", 0))
	for candidate: Node3D in units:
		if not _is_alive(candidate) or str(candidate.get_meta("team")) != team:
			continue
		var strength: int = int(_stats(candidate).get("strength", 0))
		if strength > best_strength:
			target = candidate
			best_strength = strength
	target.set_meta("logan_damage_boost", 2.0)
	logan_unit.set_meta("damage_magic_uses", uses - 1)
	status_label.text = "Logan удваивает урон %s для следующей атаки." % str(target.get_meta("label"))
	_spawn_guard_flash(target.global_position + Vector3(0, 1.1, 0), Color(1.0, 0.20, 0.16))
	await get_tree().create_timer(0.35).timeout


func _choose_ai_attack(unit: Node3D, target: Node3D) -> String:
	var modes := CombatCatalog.attacks_for(unit)
	var distance := _grid_distance(unit, target)
	for mode: String in [
		"evil_heart", "storm_vortex", "iceberg", "devlin_combo", "bright_bomb",
		"rocket_shot", "ice_rain", "frost", "precise_shot", "shot",
		"ice_kick", "ice_punch", "punch", "ball_lightning",
		"strong_slash", "long_lunge", "lunge", "slash"
	]:
		if not modes.has(mode):
			continue
		var attack_data := CombatCatalog.attack(mode)
		var attack_range := int(attack_data.get("range", 1))
		var cost := int(CombatCatalog.resource_cost(mode).get("energy", 0))
		if distance <= attack_range and _can_spend_energy(unit, cost):
			return mode
	return super._choose_ai_attack(unit, target)

func _play_attack_animation(attacker: Node3D, target: Node3D, mode: String) -> void:
	match mode:
		"evil_heart":
			await _animate_strong_slash(attacker, target)
			_spawn_heavy_arc(target.global_position + Vector3(0, 1.0, 0), Color(0.85, 0.02, 0.08))
			_camera_shake(0.55, 0.24)
		"frost", "iceberg":
			await _animate_ice_rain(attacker, target)
		"storm_vortex":
			await _animate_tornado(attacker, target)
		"shot", "precise_shot":
			await _animate_northern_shot(attacker, target, mode == "precise_shot")
		"rocket_shot":
			await _animate_bright_bomb(attacker, target)
		"punch", "ice_punch", "ice_kick":
			await _animate_shoulder_bash(attacker, target)
			_spawn_ice_lock_effect(target.global_position + Vector3(0, 0.8, 0))
		"devlin_combo":
			await _animate_devlin_combo(attacker, target)
		_:
			await super._play_attack_animation(attacker, target, mode)


func _animate_northern_shot(attacker: Node3D, target: Node3D, precise: bool) -> void:
	_face_target(attacker, target)
	status_label.text = "%s выполняет %s" % [str(attacker.get_meta("label")), "точный выстрел" if precise else "выстрел"]
	var projectile := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.055 if precise else 0.075
	mesh.height = mesh.radius * 2.0
	projectile.mesh = mesh
	projectile.material_override = _effect_material(Color(0.55, 0.90, 1.0, 0.98))
	projectile.global_position = attacker.global_position + Vector3(0, 1.15, 0)
	add_child(projectile)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_property(projectile, "global_position", target.global_position + Vector3(0, 1.0, 0), 0.16 if precise else 0.23)
	await tween.finished
	_spawn_attack_burst(target.global_position + Vector3(0, 1.0, 0), Color(0.45, 0.85, 1.0), 1.0 if precise else 0.72)
	projectile.queue_free()


func _animate_devlin_combo(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s применяет неотражаемое комбо!" % str(attacker.get_meta("label"))
	await _animate_shoulder_bash(attacker, target)
	_spawn_ice_lock_effect(target.global_position + Vector3(0, 0.8, 0))
	await _animate_northern_shot(attacker, target, true)
	await _animate_bright_bomb(attacker, target)
	_camera_shake(0.70, 0.30)


func _show_victory() -> void:
	if mission_number != 6:
		await super._show_victory()
		return
	if mission_six_finished:
		return
	mission_six_finished = true
	phase = Phase.VICTORY
	phase_label.text = "СОЮЗ ЗАКЛЮЧЁН"
	status_label.text = "Выбранное королевство принимает Bastion как союзника."
	if not _is_headless_or_smoke_runtime():
		if kingdom_choice == "south":
			await _show_dialogue("Logan", "Ты сдержал слово, Bastion. Южное королевство признаёт твой отряд союзником. Когда позовёшь, мы обсудим войска и путь через наши земли.", LOGAN_PORTRAIT)
			await _show_dialogue("Claire", "Сегодня мы выжили вместе. Надеюсь, следующий раз встретимся не на поле боя.", CLAIRE_PORTRAIT)
			await _show_dialogue("Bastion", "Спасибо. Союз с Югом станет первым шагом к освобождению моего королевства.", BASTION_PORTRAIT_V12)
		else:
			await _show_dialogue("Alden", "Ты доказал верность выбором и оружием. Северное королевство признаёт твой отряд союзником и выслушает просьбу о военной помощи.", ALDEN_PORTRAIT)
			await _show_dialogue("Devlin", "Наши армии ещё не друзья, но с этого дня у них общий противник.", DEVLIN_PORTRAIT)
			await _show_dialogue("Bastion", "Спасибо. Союз с Севером станет первым шагом к освобождению моего королевства.", BASTION_PORTRAIT_V12)
	CampaignState.complete_mission(6, kingdom_choice)
	call_deferred("_return_to_campaign_hub")


func _show_defeat() -> void:
	if mission_number != 6:
		await super._show_defeat()
		return
	if mission_six_finished:
		return
	mission_six_finished = true
	phase = Phase.DEFEAT
	phase_label.text = "ОТРЯД РАЗБИТ"
	status_label.text = "Путь к союзу придётся начать заново."
