extends Node

const SAVE_PATH: String = "user://vanguard_campaign_save.json"
const SAVE_VERSION: int = 18
const MISSION_COMPLETION_REWARDS: Dictionary = {
	1: 200,
	2: 300,
	3: 500,
	4: 800,
	5: 1200,
}
const STANDARD_ATAC_REWARD: int = 25
const COMMANDER_ATAC_REWARD: int = 50
const ELITE_ATAC_REWARD: int = 75
const ELITE_ATACS: Array[String] = ["solarus", "sarbelas", "einlager", "eigol", "toreadore", "serata", "sylpheed", "korbelan", "sharking"]
const SHOP_ITEMS: Dictionary = {
	"steel_sword_i": {
		"name": "Стальной меч I",
		"icon": "res://assets/ui/shop/steel_sword_i.png",
		"description": "Старое оружие. Можно продать в общий фонд.",
		"category": "weapon",
		"price": 100,
		"buyable": false,
		"bonuses": {"weapon_power": 1},
	},
	"copper_amulet": {
		"name": "Медный амулет",
		"icon": "res://assets/ui/shop/copper_amulet.png",
		"description": "Старый амулет из начального снаряжения.",
		"category": "amulet",
		"price": 80,
		"buyable": false,
		"bonuses": {"agility": 1},
	},
	"improved_sword_ii": {
		"name": "Улучшенный меч II",
		"icon": "res://assets/ui/shop/improved_sword_ii.png",
		"description": "Увеличивает силу оружия на 2.",
		"category": "weapon",
		"price": 300,
		"buyable": true,
		"bonuses": {"weapon_power": 2},
	},
	"royal_sword_iii": {
		"name": "Королевский меч III",
		"icon": "res://assets/ui/shop/royal_sword_iii.png",
		"description": "Увеличивает силу оружия на 4.",
		"category": "weapon",
		"price": 650,
		"buyable": true,
		"bonuses": {"weapon_power": 4},
	},
	"unity_amulet": {
		"name": "Амулет единства",
		"icon": "res://assets/ui/shop/unity_amulet.png",
		"description": "Даёт +1 к силе, ловкости, защите и умению атаки. Не меняет уровень, HP и энергию.",
		"category": "amulet",
		"price": 450,
		"buyable": true,
		"bonuses": {"strength": 1, "agility": 1, "defense": 1, "attack_skill": 1},
	},
	"opal_skill_stone": {
		"name": "Камень умения — Опал",
		"icon": "res://assets/ui/shop/opal_skill_stone.png",
		"description": "Усиливает «Яркую бомбу» на 10%. Подходит всем неуникальным ATAC.",
		"category": "stone",
		"price": 500,
		"buyable": true,
		"effect": "bright_bomb_10",
	},
	"castle_guard_blade": {
		"name": "Клинок защитника замка",
		"icon": "res://assets/ui/shop/castle_guard_blade.png",
		"description": "Наградное оружие защитников. Сила оружия +6.",
		"category": "weapon", "price": 950, "buyable": true,
		"requires_castle_defense": true, "bonuses": {"weapon_power": 6},
	},
	"royal_vanguard_blade": {
		"name": "Клинок королевского авангарда",
		"icon": "res://assets/ui/shop/royal_vanguard_blade.png",
		"description": "Редкий меч из оружейной замка. Сила оружия +8.",
		"category": "weapon", "price": 1400, "buyable": true,
		"requires_castle_defense": true, "bonuses": {"weapon_power": 8},
	},
	"castle_oath_amulet": {
		"name": "Амулет клятвы замка",
		"icon": "res://assets/ui/shop/castle_oath_amulet.png",
		"description": "+2 к силе, ловкости, защите и умению атаки.",
		"category": "amulet", "price": 1100, "buyable": true,
		"requires_castle_defense": true,
		"bonuses": {"strength": 2, "agility": 2, "defense": 2, "attack_skill": 2},
	},
	"wind_guard_amulet": {
		"name": "Амулет стража ветра",
		"icon": "res://assets/ui/shop/wind_guard_amulet.png",
		"description": "+3 к ловкости и +1 к защите.",
		"category": "amulet", "price": 850, "buyable": true,
		"requires_castle_defense": true, "bonuses": {"agility": 3, "defense": 1},
	},
	"ruby_skill_stone": {
		"name": "Камень умения — Рубин",
		"icon": "res://assets/ui/shop/ruby_skill_stone.png",
		"description": "Усиливает «Сильный порез» на 10%.",
		"category": "stone", "price": 750, "buyable": true,
		"requires_castle_defense": true, "effect": "strong_slash_10",
	},
	"sapphire_skill_stone": {
		"name": "Камень умения — Сапфир",
		"icon": "res://assets/ui/shop/sapphire_skill_stone.png",
		"description": "Усиливает ледяные и электрические атаки на 10%.",
		"category": "stone", "price": 900, "buyable": true,
		"requires_castle_defense": true, "effect": "elemental_10",
	},
}
const UNIQUE_ATACS: Array[String] = ["toreadore"]

const ATAC_DATA: Dictionary = {
	"alba": {
		"name": "Alba",
		"base_hp": 180,
		"hp_per_level": 12,
		"move_range": 6,
		"equipment": "Лёгкая броня Alba",
	},
	"barazaph": {
		"name": "Barazaph",
		"base_hp": 255,
		"hp_per_level": 5,
		"move_range": 5,
		"equipment": "Усиленная броня Barazaph",
	},
	"vedocorban": {
		"name": "Vedocorban",
		"base_hp": 240,
		"hp_per_level": 6,
		"move_range": 6,
		"equipment": "Ниндзя-броня Vedocorban",
	},
	"solarus": {
		"name": "Solarus",
		"base_hp": 310,
		"hp_per_level": 9,
		"move_range": 6,
		"equipment": "Генеральская броня Solarus",
	},
	"sarbelas": {
		"name": "Sarbelas",
		"base_hp": 205,
		"hp_per_level": 7,
		"move_range": 6,
		"equipment": "Двухкосная броня Sarbelas",
	},
	"einlager": {
		"name": "Einlager",
		"base_hp": 285,
		"hp_per_level": 8,
		"move_range": 5,
		"equipment": "Капитанская броня Einlager",
	},
	"eigol": {
		"name": "Eigol",
		"base_hp": 330,
		"hp_per_level": 9,
		"move_range": 5,
		"equipment": "Броня пустынного королевского генерала",
	},
	"amphisia": {
		"name": "Amphisia",
		"base_hp": 206,
		"hp_per_level": 8,
		"move_range": 6,
		"equipment": "Белая рыцарская броня Amphisia",
	},
	"haurol": {
		"name": "Haurol",
		"base_hp": 228,
		"hp_per_level": 9,
		"move_range": 7,
		"equipment": "Копейная броня Haurol",
	},
	"toreadore": {
		"name": "Toreadore",
		"base_hp": 330,
		"hp_per_level": 11,
		"move_range": 15,
		"equipment": "Уникальная броня Toreadore с золотым копьём",
	},
	"serata": {
		"name": "Serata",
		"base_hp": 300,
		"hp_per_level": 8,
		"move_range": 6,
		"equipment": "Оранжевая королевская броня Serata",
	},
	"glaive": {
		"name": "Glaive",
		"base_hp": 230,
		"hp_per_level": 7,
		"move_range": 6,
		"equipment": "Золотая броня королевской гвардии Glaive",
	},
	"sylpheed": {
		"name": "Sylpheed", "base_hp": 218, "hp_per_level": 8, "move_range": 8,
		"equipment": "Летающая броня Sylpheed",
	},
	"korbelan": {
		"name": "Korbelan", "base_hp": 340, "hp_per_level": 10, "move_range": 6,
		"equipment": "Стальная генеральская броня Korbelan",
	},
	"sharking": {
		"name": "Sharking", "base_hp": 360, "hp_per_level": 10, "move_range": 10,
		"equipment": "Тяжёлая броня Sharking с регенерирующим силовым полем",
	},
}

var current_mission: int = 1
var mission_1_complete: bool = false
var mission_2_complete: bool = false
var mission_3_complete: bool = false
# Fourth chapter: Kamorge, Eigol and the assault on the imperial castle.
var mission_4_complete: bool = false
var mission_5_complete: bool = false
var mission_5_result: String = ""
var southern_route_pending: bool = false
var prison_seen: bool = false
var story_branch: String = ""
var kamorge_alive: bool = true
var kamorge_lost_atac: bool = false
var partisans_joined: bool = false
var characters: Dictionary = {}
var unlocked_atacs: Array[String] = ["alba"]
var coins: int = 0
var mission_reward_claimed: Dictionary = {}
var shop_unlocked: bool = false
var inventory: Dictionary = {}
var equipped_items: Dictionary = {}
var experimental_3d_enabled: bool = false
var arena_battles_enabled: bool = false
# Runtime-only test helpers. They are intentionally not written into the save file.
var test_forced_branch: String = ""
var mission_selector_return_scene: String = "res://scenes/Main.tscn"


func _ready() -> void:
	if not load_game():
		reset_campaign()


func _character_entry(name: String, portrait: String, level: int, atac: String, unlocked: bool = false) -> Dictionary:
	return {
		"name": name,
		"unlocked": unlocked,
		"portrait": portrait,
		"level": level,
		"experience": 0,
		"stat_points": 0,
		"strength_bonus": 0,
		"agility_bonus": 0,
		"defense_bonus": 0,
		"attack_skill_bonus": 0,
		"atac": atac,
	}


func _default_characters() -> Dictionary:
	return {
		"bastion": _character_entry(
			"Bastion", "res://assets/ui/portraits/bastion.png", 1, "alba", true
		),
		"kamorge": _character_entry(
			"Kamorge", "res://assets/ui/portraits/kamorge.png", 16, "barazaph"
		),
		"andrew": _character_entry(
			"Andrew", "res://assets/ui/portraits/andrew.png", 14, "vedocorban"
		),
		"ione": _character_entry(
			"Ione", "res://assets/ui/portraits/ione.png", 8, "amphisia"
		),
		"reyna": _character_entry(
			"Reyna", "res://assets/ui/portraits/reyna.png", 10, "haurol"
		),
		"zeira": _character_entry(
			"Zeira", "res://assets/ui/portraits/zeira.png", 18, "toreadore"
		),
		"galvas": _character_entry(
			"Galvas", "res://assets/ui/portraits/galvas.png", 18, "serata"
		),
		"sadira": _character_entry(
			"Sadira", "res://assets/ui/portraits/sadira.png", 8, "sylpheed"
		),
		"franco": _character_entry(
			"Franco", "res://assets/ui/portraits/franco.png", 25, "korbelan"
		),
		"halak": _character_entry(
			"Halak", "res://assets/ui/portraits/halak.png", 25, "korbelan"
		),
	}


func reset_campaign() -> void:
	current_mission = 1
	mission_1_complete = false
	mission_2_complete = false
	mission_3_complete = false
	mission_4_complete = false
	mission_5_complete = false
	mission_5_result = ""
	southern_route_pending = false
	prison_seen = false
	story_branch = ""
	kamorge_alive = true
	kamorge_lost_atac = false
	partisans_joined = false
	unlocked_atacs = ["alba"]
	coins = 0
	mission_reward_claimed = {}
	shop_unlocked = false
	inventory = {"steel_sword_i": 1, "copper_amulet": 1}
	equipped_items = {}
	experimental_3d_enabled = false
	arena_battles_enabled = false
	test_forced_branch = ""
	characters = _default_characters()


func save_game() -> bool:
	var payload: Dictionary = {
		"save_version": SAVE_VERSION,
		"current_mission": current_mission,
		"mission_1_complete": mission_1_complete,
		"mission_2_complete": mission_2_complete,
		"mission_3_complete": mission_3_complete,
		"mission_4_complete": mission_4_complete,
		"mission_5_complete": mission_5_complete,
		"mission_5_result": mission_5_result,
		"southern_route_pending": southern_route_pending,
		"prison_seen": prison_seen,
		"story_branch": story_branch,
		"kamorge_alive": kamorge_alive,
		"kamorge_lost_atac": kamorge_lost_atac,
		"partisans_joined": partisans_joined,
		"characters": characters,
		"unlocked_atacs": unlocked_atacs,
		"coins": coins,
		"mission_reward_claimed": mission_reward_claimed,
		"shop_unlocked": shop_unlocked,
		"inventory": inventory,
		"equipped_items": equipped_items,
		"experimental_3d_enabled": experimental_3d_enabled,
		"arena_battles_enabled": arena_battles_enabled,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed as Dictionary
	var loaded_version: int = int(data.get("save_version", 1))
	current_mission = int(data.get("current_mission", 1))
	mission_1_complete = bool(data.get("mission_1_complete", false))
	mission_2_complete = bool(data.get("mission_2_complete", false))
	mission_3_complete = bool(data.get("mission_3_complete", false))
	mission_4_complete = bool(data.get("mission_4_complete", false))
	mission_5_complete = bool(data.get("mission_5_complete", false))
	mission_5_result = str(data.get("mission_5_result", ""))
	southern_route_pending = bool(data.get("southern_route_pending", false))
	prison_seen = bool(data.get("prison_seen", false))
	story_branch = str(data.get("story_branch", ""))
	kamorge_alive = bool(data.get("kamorge_alive", true))
	kamorge_lost_atac = bool(data.get("kamorge_lost_atac", false))
	partisans_joined = bool(data.get("partisans_joined", false))
	coins = maxi(0, int(data.get("coins", 0)))
	mission_reward_claimed = {}
	var loaded_rewards: Variant = data.get("mission_reward_claimed", {})
	if loaded_rewards is Dictionary:
		for reward_key: Variant in (loaded_rewards as Dictionary).keys():
			mission_reward_claimed[str(reward_key)] = bool((loaded_rewards as Dictionary)[reward_key])
	shop_unlocked = bool(data.get("shop_unlocked", mission_3_complete))
	inventory = {"steel_sword_i": 1, "copper_amulet": 1}
	var loaded_inventory: Variant = data.get("inventory", {})
	if loaded_inventory is Dictionary:
		for item_key: Variant in (loaded_inventory as Dictionary).keys():
			inventory[str(item_key)] = maxi(0, int((loaded_inventory as Dictionary)[item_key]))
	equipped_items = {}
	var loaded_equipped: Variant = data.get("equipped_items", {})
	if loaded_equipped is Dictionary:
		equipped_items = (loaded_equipped as Dictionary).duplicate(true)
	experimental_3d_enabled = bool(data.get("experimental_3d_enabled", false))
	arena_battles_enabled = false

	characters = _default_characters()
	var loaded_characters: Variant = data.get("characters", {})
	if loaded_characters is Dictionary:
		for character_key: Variant in (loaded_characters as Dictionary).keys():
			var character_id: String = str(character_key)
			if not characters.has(character_id):
				continue
			var merged: Dictionary = (characters[character_id] as Dictionary).duplicate(true)
			var loaded_entry: Variant = (loaded_characters as Dictionary).get(character_id, {})
			if loaded_entry is Dictionary:
				for field_key: Variant in (loaded_entry as Dictionary).keys():
					merged[str(field_key)] = (loaded_entry as Dictionary)[field_key]
			characters[character_id] = merged

	unlocked_atacs.clear()
	var loaded_atacs: Variant = data.get("unlocked_atacs", ["alba"])
	if loaded_atacs is Array:
		for value: Variant in loaded_atacs as Array:
			var atac_id: String = str(value)
			if ATAC_DATA.has(atac_id) and not unlocked_atacs.has(atac_id):
				unlocked_atacs.append(atac_id)
	if not unlocked_atacs.has("alba"):
		unlocked_atacs.push_front("alba")

	_migrate_story_state(loaded_version)
	_migrate_coin_economy(loaded_version)
	_migrate_performance_settings(loaded_version)
	_rebuild_unlocks_from_progress()
	if loaded_version < SAVE_VERSION:
		save_game()
	return not characters.is_empty()


func _migrate_story_state(loaded_version: int) -> void:
	# Version 11 used mission_4_complete for the short forest Eigol prototype.
	# Version 12 replaces it with the full castle-rescue chapter, so old saves
	# are returned to the start of mission 4 instead of skipping new content.
	if loaded_version < 12 and mission_4_complete and story_branch == "seek_southern_aid":
		mission_4_complete = false
		mission_reward_claimed.erase(_mission_reward_key(4))
		current_mission = 4
	if not mission_3_complete:
		return
	if story_branch == "stay_and_fight":
		kamorge_alive = false
		kamorge_lost_atac = true
		partisans_joined = true
		current_mission = maxi(current_mission, 5)
	elif story_branch == "seek_southern_aid":
		kamorge_alive = true
		kamorge_lost_atac = true
		partisans_joined = mission_4_complete
		if mission_5_complete:
			current_mission = maxi(current_mission, 6)
		else:
			current_mission = 5 if mission_4_complete else 4
		shop_unlocked = true


func _migrate_performance_settings(loaded_version: int) -> void:
	# The first static 3D prototype was enabled by default in version 12.
	# Version 13 starts safely in optimized 2.5D; the user can enable GLB models manually.
	if loaded_version < 13:
		experimental_3d_enabled = false


func _migrate_coin_economy(loaded_version: int) -> void:
	if loaded_version >= 11:
		return
	# Saves from earlier builds had no wallet. Grant the mission bonuses that the
	# player would already have earned, so a completed campaign does not start at zero.
	if mission_1_complete:
		_award_mission_completion_once(1)
	if mission_2_complete:
		_award_mission_completion_once(2)
	if mission_3_complete:
		_award_mission_completion_once(3)
	if mission_4_complete:
		_award_mission_completion_once(4)
	if mission_5_complete:
		_award_mission_completion_once(5)


func get_coin_balance() -> int:
	return coins


func add_coins(amount: int) -> int:
	var safe_amount: int = maxi(0, amount)
	if safe_amount <= 0:
		return 0
	coins += safe_amount
	save_game()
	return safe_amount


func award_atac_elimination(model_slug: String, commander: bool = false) -> int:
	var reward: int = STANDARD_ATAC_REWARD
	if commander:
		reward = COMMANDER_ATAC_REWARD
	if ELITE_ATACS.has(model_slug):
		reward = ELITE_ATAC_REWARD
	coins += reward
	save_game()
	return reward


func _mission_reward_key(mission_id: int) -> String:
	return "mission_%d" % mission_id


func _award_mission_completion_once(mission_id: int) -> Dictionary:
	var reward_key: String = _mission_reward_key(mission_id)
	if bool(mission_reward_claimed.get(reward_key, false)):
		return {"awarded": 0, "already_claimed": true, "balance": coins}
	var amount: int = int(MISSION_COMPLETION_REWARDS.get(mission_id, 0))
	mission_reward_claimed[reward_key] = true
	coins += amount
	return {"awarded": amount, "already_claimed": false, "balance": coins}


func prepare_mission_for_test(mission_id: int, forced_branch: String = "") -> void:
	var safe_mission: int = clampi(mission_id, 1, 5)
	test_forced_branch = forced_branch if forced_branch in ["stay_and_fight", "seek_southern_aid", "defend_castle", "leave_castle"] else ""
	if safe_mission >= 2:
		mission_1_complete = true
		unlock_character("kamorge")
		kamorge_alive = true
		kamorge_lost_atac = false
		unlock_atac("barazaph")
	if safe_mission >= 3:
		mission_2_complete = true
		unlock_character("andrew")
		unlock_atac("vedocorban")
		mission_3_complete = false
		mission_4_complete = false
		prison_seen = false
		story_branch = ""
		partisans_joined = false
		for character_id: String in ["ione", "reyna", "zeira", "galvas"]:
			var data: Dictionary = characters[character_id] as Dictionary
			data["unlocked"] = false
			characters[character_id] = data
		for atac_id: String in ["amphisia", "haurol", "toreadore", "eigol", "serata", "glaive"]:
			_remove_atac(atac_id)
	if safe_mission == 4:
		mission_3_complete = true
		story_branch = "seek_southern_aid"
		prison_seen = true
		kamorge_alive = true
		kamorge_lost_atac = true
		shop_unlocked = true
		_remove_atac("barazaph")
		for character_id: String in ["kamorge", "ione", "reyna", "galvas"]:
			unlock_character(character_id)
		for atac_id: String in ["eigol", "amphisia", "haurol", "serata"]:
			unlock_atac(atac_id)
		var kamorge_data: Dictionary = characters["kamorge"] as Dictionary
		kamorge_data["atac"] = "eigol"
		characters["kamorge"] = kamorge_data
	if safe_mission == 5:
		mission_3_complete = true
		mission_4_complete = true
		mission_5_complete = false
		mission_5_result = ""
		southern_route_pending = false
		story_branch = "seek_southern_aid"
		prison_seen = true
		partisans_joined = true
		shop_unlocked = true
		kamorge_alive = true
		kamorge_lost_atac = true
		for character_id: String in ["bastion", "kamorge", "andrew", "ione", "reyna", "zeira", "galvas"]:
			unlock_character(character_id)
		for atac_id: String in ["alba", "eigol", "vedocorban", "amphisia", "haurol", "toreadore", "serata"]:
			unlock_atac(atac_id)
		var kamorge_data_five: Dictionary = characters["kamorge"] as Dictionary
		kamorge_data_five["atac"] = "eigol"
		characters["kamorge"] = kamorge_data_five
	current_mission = safe_mission
	save_game()


func _rebuild_unlocks_from_progress() -> void:
	if mission_1_complete and kamorge_alive and not kamorge_lost_atac:
		unlock_character("kamorge")
		unlock_atac("barazaph")
	if mission_2_complete:
		unlock_character("andrew")
		unlock_atac("vedocorban")
	if mission_3_complete and story_branch == "stay_and_fight":
		partisans_joined = true
		for character_id: String in ["ione", "reyna", "zeira"]:
			unlock_character(character_id)
		for atac_id: String in ["amphisia", "haurol", "toreadore"]:
			unlock_atac(atac_id)
	if mission_4_complete:
		partisans_joined = true
		shop_unlocked = true
		for character_id: String in ["kamorge", "andrew", "ione", "reyna", "zeira", "galvas"]:
			unlock_character(character_id)
		for atac_id: String in ["eigol", "vedocorban", "amphisia", "haurol", "toreadore", "serata", "glaive"]:
			unlock_atac(atac_id)
		var kamorge_data: Dictionary = characters["kamorge"] as Dictionary
		kamorge_data["atac"] = "eigol"
		characters["kamorge"] = kamorge_data
	if mission_5_complete and mission_5_result == "castle_defended":
		shop_unlocked = true
		for atac_id: String in ["sylpheed", "korbelan"]:
			unlock_atac(atac_id)
	if not kamorge_alive:
		mark_character_unavailable("kamorge")
	if kamorge_lost_atac:
		_remove_atac("barazaph")


func complete_mission(mission_id: int, branch: String = "") -> Dictionary:
	var coin_result: Dictionary = _award_mission_completion_once(mission_id)
	if mission_id == 1:
		mission_1_complete = true
		current_mission = 2
		unlock_character("kamorge")
		unlock_atac("barazaph")
	elif mission_id == 2:
		mission_2_complete = true
		current_mission = 3
		unlock_character("andrew")
		unlock_atac("vedocorban")
	elif mission_id == 3:
		mission_3_complete = true
		shop_unlocked = true
		current_mission = 5
		if not branch.is_empty():
			story_branch = branch
		kamorge_lost_atac = true
		_remove_atac("barazaph")
		if story_branch == "seek_southern_aid":
			current_mission = 4
			kamorge_alive = true
			partisans_joined = false
			mark_character_unavailable("kamorge")
			for character_id: String in ["ione", "reyna", "zeira"]:
				var partisan_data: Dictionary = characters[character_id] as Dictionary
				partisan_data["unlocked"] = false
				characters[character_id] = partisan_data
			for atac_id: String in ["amphisia", "haurol", "toreadore"]:
				_remove_atac(atac_id)
		elif story_branch == "stay_and_fight":
			kamorge_alive = false
			partisans_joined = true
			mark_character_unavailable("kamorge")
			for character_id: String in ["ione", "reyna", "zeira"]:
				unlock_character(character_id)
			for atac_id: String in ["amphisia", "haurol", "toreadore"]:
				unlock_atac(atac_id)
	elif mission_id == 4:
		mission_4_complete = true
		current_mission = 5
		prison_seen = true
		partisans_joined = true
		shop_unlocked = true
		for character_id: String in ["kamorge", "andrew", "ione", "reyna", "zeira", "galvas"]:
			unlock_character(character_id)
		for atac_id: String in ["eigol", "vedocorban", "amphisia", "haurol", "toreadore", "serata", "glaive"]:
			unlock_atac(atac_id)
		var kamorge_data: Dictionary = characters["kamorge"] as Dictionary
		kamorge_data["atac"] = "eigol"
		characters["kamorge"] = kamorge_data
	elif mission_id == 5:
		mission_5_complete = true
		mission_5_result = branch if branch in ["castle_defended", "castle_lost", "left_castle"] else "castle_lost"
		southern_route_pending = mission_5_result != "castle_defended"
		current_mission = 6
		shop_unlocked = true
		if mission_5_result == "castle_defended":
			for atac_id: String in ["sylpheed", "korbelan"]:
				unlock_atac(atac_id)
	save_game()
	return coin_result


func mark_character_unavailable(character_id: String) -> void:
	if not characters.has(character_id):
		return
	var data: Dictionary = characters[character_id] as Dictionary
	data["unlocked"] = false
	data["fallen"] = true
	characters[character_id] = data


func _remove_atac(atac_id: String) -> void:
	if unlocked_atacs.has(atac_id):
		unlocked_atacs.erase(atac_id)


func mark_prison_seen() -> void:
	prison_seen = true
	save_game()


func set_story_branch(branch: String) -> void:
	story_branch = branch
	save_game()


func unlock_character(character_id: String) -> void:
	if not characters.has(character_id):
		return
	var data: Dictionary = characters[character_id] as Dictionary
	data["unlocked"] = true
	data.erase("fallen")
	characters[character_id] = data


func unlock_atac(atac_id: String) -> void:
	if ATAC_DATA.has(atac_id) and not unlocked_atacs.has(atac_id):
		unlocked_atacs.append(atac_id)


func get_unlocked_character_ids() -> Array[String]:
	var result: Array[String] = []
	for character_id_value: Variant in characters.keys():
		var character_id: String = str(character_id_value)
		var data: Dictionary = characters[character_id] as Dictionary
		if bool(data.get("unlocked", false)):
			result.append(character_id)
	result.sort()
	return result


func get_character(character_id: String) -> Dictionary:
	if not characters.has(character_id):
		return {}
	return (characters[character_id] as Dictionary).duplicate(true)


func character_atac(character_id: String) -> String:
	return str(get_character(character_id).get("atac", "alba"))


func xp_needed(level: int) -> int:
	return 70 + level * 35


func award_experience(character_id: String, amount: int) -> Dictionary:
	if not characters.has(character_id) or amount <= 0:
		return {"gained": 0, "levels": 0}
	var data: Dictionary = characters[character_id] as Dictionary
	var level: int = int(data.get("level", 1))
	var experience: int = int(data.get("experience", 0)) + amount
	var levels_gained: int = 0
	while experience >= xp_needed(level):
		experience -= xp_needed(level)
		level += 1
		levels_gained += 1
		data["stat_points"] = int(data.get("stat_points", 0)) + 3
	data["experience"] = experience
	data["level"] = level
	characters[character_id] = data
	save_game()
	return {
		"gained": amount,
		"levels": levels_gained,
		"level": level,
		"experience": experience,
		"needed": xp_needed(level),
		"stat_points": int(data.get("stat_points", 0)),
	}


func allocate_stat(character_id: String, stat_key: String) -> bool:
	if not characters.has(character_id):
		return false
	if stat_key not in ["strength", "agility", "defense", "attack_skill"]:
		return false
	var data: Dictionary = characters[character_id] as Dictionary
	var points: int = int(data.get("stat_points", 0))
	if points <= 0:
		return false
	data["stat_points"] = points - 1
	var bonus_key: String = "%s_bonus" % stat_key
	data[bonus_key] = int(data.get(bonus_key, 0)) + 1
	characters[character_id] = data
	save_game()
	return true


func assign_atac(character_id: String, atac_id: String) -> bool:
	if not characters.has(character_id) or not unlocked_atacs.has(atac_id):
		return false
	var old_atac: String = character_atac(character_id)
	var other_id: String = ""
	for candidate_value: Variant in characters.keys():
		var candidate_id: String = str(candidate_value)
		if candidate_id == character_id:
			continue
		var other: Dictionary = characters[candidate_id] as Dictionary
		if bool(other.get("unlocked", false)) and str(other.get("atac", "")) == atac_id:
			other_id = candidate_id
			break
	var selected: Dictionary = characters[character_id] as Dictionary
	selected["atac"] = atac_id
	characters[character_id] = selected
	if not other_id.is_empty():
		var other_data: Dictionary = characters[other_id] as Dictionary
		other_data["atac"] = old_atac
		characters[other_id] = other_data
	save_game()
	return true


func apply_character_progress(character_id: String, base_stats: Dictionary) -> Dictionary:
	var result: Dictionary = base_stats.duplicate(true)
	var character: Dictionary = get_character(character_id)
	if character.is_empty():
		return result
	var level: int = int(character.get("level", int(result.get("level", 1))))
	var atac_id: String = str(character.get("atac", "alba"))
	var atac_data: Dictionary = ATAC_DATA.get(atac_id, ATAC_DATA["alba"]) as Dictionary
	result["level"] = level
	result["experience"] = int(character.get("experience", 0))
	result["experience_needed"] = xp_needed(level)
	result["stat_points"] = int(character.get("stat_points", 0))
	for stat_key: String in ["strength", "agility", "defense", "attack_skill"]:
		result[stat_key] = int(result.get(stat_key, 0)) + int(character.get("%s_bonus" % stat_key, 0))
	var maximum_hp: int = int(atac_data.get("base_hp", 100)) + (level - 1) * int(atac_data.get("hp_per_level", 5))
	result["max_hp"] = maximum_hp
	result["hp"] = maximum_hp
	result["move_range"] = int(atac_data.get("move_range", result.get("move_range", 5)))
	result["atac_name"] = str(atac_data.get("name", atac_id.capitalize()))
	result["equipment"] = str(atac_data.get("equipment", result.get("equipment", "Броня ATAC")))
	_apply_equipped_item_bonuses(character_id, result)
	return result


func apply_equipment_bonuses(character_id: String, base_stats: Dictionary) -> Dictionary:
	var result: Dictionary = base_stats.duplicate(true)
	_apply_equipped_item_bonuses(character_id, result)
	return result


func toggle_experimental_3d() -> bool:
	experimental_3d_enabled = not experimental_3d_enabled
	save_game()
	return experimental_3d_enabled


func toggle_arena_battles() -> bool:
	arena_battles_enabled = not arena_battles_enabled
	save_game()
	return arena_battles_enabled


func is_shop_available() -> bool:
	return shop_unlocked or mission_3_complete


func is_item_available(item_id: String) -> bool:
	return SHOP_ITEMS.has(item_id)


func get_inventory_count(item_id: String) -> int:
	return maxi(0, int(inventory.get(item_id, 0)))


func get_sell_price(item_id: String) -> int:
	var item: Dictionary = SHOP_ITEMS.get(item_id, {}) as Dictionary
	return int(floor(float(item.get("price", 0)) * 0.40))


func buy_item(item_id: String) -> Dictionary:
	if not is_shop_available() or not SHOP_ITEMS.has(item_id) or not is_item_available(item_id):
		return {"ok": false, "message": "Магазин ещё закрыт."}
	var item: Dictionary = SHOP_ITEMS[item_id] as Dictionary
	if not bool(item.get("buyable", true)):
		return {"ok": false, "message": "Этот старый предмет продаётся только со склада."}
	var price: int = int(item.get("price", 0))
	if coins < price:
		return {"ok": false, "message": "Недостаточно монет в общем фонде."}
	coins -= price
	inventory[item_id] = get_inventory_count(item_id) + 1
	save_game()
	return {"ok": true, "message": "Покупка добавлена на общий склад.", "balance": coins}


func sell_item(item_id: String) -> Dictionary:
	if not SHOP_ITEMS.has(item_id) or get_inventory_count(item_id) <= 0:
		return {"ok": false, "message": "На общем складе нет свободного предмета."}
	var amount: int = get_sell_price(item_id)
	inventory[item_id] = get_inventory_count(item_id) - 1
	coins += amount
	save_game()
	return {"ok": true, "message": "Предмет продан за %d монет (40%% стоимости)." % amount, "balance": coins}


func equip_item(character_id: String, item_id: String) -> Dictionary:
	if not characters.has(character_id) or not SHOP_ITEMS.has(item_id):
		return {"ok": false, "message": "Предмет или персонаж не найден."}
	if get_inventory_count(item_id) <= 0:
		return {"ok": false, "message": "Предмета нет на общем складе."}
	var item: Dictionary = SHOP_ITEMS[item_id] as Dictionary
	var category: String = str(item.get("category", ""))
	if category not in ["weapon", "amulet", "stone"]:
		return {"ok": false, "message": "Этот предмет нельзя экипировать."}
	var atac_id: String = character_atac(character_id)
	if category == "stone" and UNIQUE_ATACS.has(atac_id):
		return {"ok": false, "message": "Камни умения не подходят уникальному ATAC %s." % str((ATAC_DATA[atac_id] as Dictionary).get("name", atac_id))}
	var slots: Dictionary = equipped_items.get(character_id, {}) as Dictionary
	var old_item: String = str(slots.get(category, ""))
	if not old_item.is_empty():
		inventory[old_item] = get_inventory_count(old_item) + 1
	inventory[item_id] = get_inventory_count(item_id) - 1
	slots[category] = item_id
	equipped_items[character_id] = slots
	save_game()
	return {"ok": true, "message": "%s экипирован." % str(item.get("name", item_id))}


func unequip_item(character_id: String, category: String) -> Dictionary:
	var slots: Dictionary = equipped_items.get(character_id, {}) as Dictionary
	var old_item: String = str(slots.get(category, ""))
	if old_item.is_empty():
		return {"ok": false, "message": "Слот уже пуст."}
	inventory[old_item] = get_inventory_count(old_item) + 1
	slots[category] = ""
	equipped_items[character_id] = slots
	save_game()
	return {"ok": true, "message": "Предмет возвращён на общий склад."}


func equipped_item(character_id: String, category: String) -> String:
	var slots: Dictionary = equipped_items.get(character_id, {}) as Dictionary
	return str(slots.get(category, ""))


func character_has_opal(character_id: String) -> bool:
	return equipped_item(character_id, "stone") == "opal_skill_stone" and not UNIQUE_ATACS.has(character_atac(character_id))


func character_stone_effect(character_id: String) -> String:
	var item_id: String = equipped_item(character_id, "stone")
	if item_id.is_empty() or not SHOP_ITEMS.has(item_id) or UNIQUE_ATACS.has(character_atac(character_id)):
		return ""
	return str((SHOP_ITEMS[item_id] as Dictionary).get("effect", ""))


func _apply_equipped_item_bonuses(character_id: String, stats: Dictionary) -> void:
	var slots: Dictionary = equipped_items.get(character_id, {}) as Dictionary
	for category: String in ["weapon", "amulet"]:
		var item_id: String = str(slots.get(category, ""))
		if item_id.is_empty() or not SHOP_ITEMS.has(item_id):
			continue
		var item: Dictionary = SHOP_ITEMS[item_id] as Dictionary
		var bonuses: Dictionary = item.get("bonuses", {}) as Dictionary
		for stat_key_value: Variant in bonuses.keys():
			var stat_key: String = str(stat_key_value)
			stats[stat_key] = int(stats.get(stat_key, 0)) + int(bonuses[stat_key_value])
