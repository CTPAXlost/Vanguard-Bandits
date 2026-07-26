class_name CombatCatalog
extends RefCounted

const ATTACKS: Dictionary = {
	"slash": {
		"label": "Порез",
		"fatigue": 5,
		"energy": 0,
		"range": 1,
		"multiplier": 1.0,
		"animation": "slash",
	},
	"lunge": {
		"label": "Выпад",
		"fatigue": 6,
		"energy": 0,
		"range": 1,
		"multiplier": 1.22,
		"animation": "lunge",
	},
	"long_lunge": {
		"label": "Длинный выпад",
		"fatigue": 7,
		"energy": 0,
		"range": 2,
		"multiplier": 1.22,
		"animation": "long_lunge",
	},
	"strong_slash": {
		"label": "Сильный порез",
		"fatigue": 15,
		"energy": 0,
		"range": 1,
		"multiplier": 1.62,
		"animation": "strong_slash",
	},
	"shoulder_bash": {
		"label": "Толчок плечом",
		"fatigue": 20,
		"energy": 0,
		"range": 1,
		"multiplier": 1.30,
		"animation": "shoulder_bash",
		"knockback": true,
	},
	"tornado": {
		"label": "Торнадо",
		"fatigue": 25,
		"energy": 0,
		"range": 1,
		"multiplier": 1.82,
		"animation": "tornado",
	},
	"ball_lightning": {
		"label": "Шаровая молния",
		"fatigue": 0,
		"energy": 30,
		"range": 1,
		"multiplier": 1.52,
		"animation": "ball_lightning",
	},
	"bright_bomb": {
		"label": "Яркая бомба",
		"fatigue": 50,
		"energy": 0,
		"range": 2,
		"multiplier": 2.35,
		"animation": "bright_bomb",
	},
	"fire_rain": {
		"label": "Град огня с неба",
		"fatigue": 0,
		"energy": 60,
		"range": 5,
		"range_mode": "up_to",
		"multiplier": 2.05,
		"animation": "fire_rain",
	},
	"earthquake": {
		"label": "Землетрясение",
		"fatigue": 0,
		"energy": 25,
		"range": 1,
		"multiplier": 1.68,
		"animation": "earthquake",
	},
	"desert_whirl": {
		"label": "Вихрь в пустыне",
		"fatigue": 0,
		"energy": 45,
		"range": 1,
		"multiplier": 1.95,
		"animation": "desert_whirl",
		"slow_turns": 3,
		"miss_debuff": 0.28,
	},
	"quicksand": {
		"label": "Зыбучие пески",
		"fatigue": 0,
		"energy": 35,
		"range": 4,
		"range_mode": "up_to",
		"multiplier": 0.0,
		"animation": "quicksand",
		"slow_turns": 2,
		"move_limit": 2,
	},
	"desert_storm": {
		"label": "Буря в пустыне",
		"fatigue": 0,
		"energy": 30,
		"range": 3,
		"range_mode": "up_to",
		"multiplier": 1.35,
		"animation": "desert_storm",
		"disorient_turns": 2,
		"friendly_fire_chance": 0.50,
	},
	"sticky_sandstorm": {
		"label": "Вязкая буря в песках",
		"fatigue": 0,
		"energy": 50,
		"range": 4,
		"range_mode": "up_to",
		"multiplier": 1.55,
		"animation": "sticky_sandstorm",
		"area_targets": 3,
		"block_strongest_turns": 2,
	},
	"healing_ban": {
		"label": "Магия: запрет на лечение",
		"fatigue": 0,
		"energy": 30,
		"range": 4,
		"range_mode": "up_to",
		"multiplier": 0.0,
		"animation": "healing_ban",
		"healing_block_turns": 3,
	},
	"spear_throw": {
		"label": "Бросок копья",
		"fatigue": 0,
		"energy": 25,
		"range": 5,
		"range_mode": "up_to",
		"multiplier": 1.55,
		"animation": "spear_throw",
	},
	"ice_rain": {
		"label": "Ледяной дождь",
		"fatigue": 0,
		"energy": 30,
		"range": 5,
		"range_mode": "up_to",
		"multiplier": 1.15,
		"animation": "ice_rain",
		"freeze_chance": 0.30,
		"freeze_turns": 2,
	},
	"ultrasound": {
		"label": "Ультразвук",
		"fatigue": 0,
		"energy": 30,
		"range": 5,
		"range_mode": "up_to",
		"multiplier": 0.85,
		"animation": "ultrasound",
		"disorient_turns": 2,
		"friendly_fire_chance": 0.50,
	},
	"slide": {
		"label": "Скольжение",
		"fatigue": 0,
		"energy": 80,
		"range": 5,
		"range_mode": "up_to",
		"multiplier": 3.20,
		"animation": "slide",
		"pass_through": true,
	},
	"sound_strike": {
		"label": "Звуковой удар",
		"fatigue": 0,
		"energy": 20,
		"range": 3,
		"range_mode": "up_to",
		"multiplier": 1.12,
		"animation": "sound_strike",
	},
	"wind_strike": {
		"label": "Удар ветра",
		"fatigue": 0,
		"energy": 25,
		"range": 4,
		"range_mode": "up_to",
		"multiplier": 1.32,
		"animation": "wind_strike",
	},
	"incinerate": {
		"label": "Испепелить",
		"fatigue": 0,
		"energy": 30,
		"range": 3,
		"range_mode": "up_to",
		"multiplier": 0.20,
		"animation": "incinerate",
		"fixed_damage_chance": 0.40,
		"fixed_damage": 400,
	},
	"guillotine": {
		"label": "Гильотина",
		"fatigue": 0,
		"energy": 40,
		"range": 1,
		"multiplier": 2.15,
		"animation": "guillotine",
		"disable_chance": 0.45,
		"disable_turns": 1,
	},
	"sharking_slash": {
		"label": "Порез",
		"fatigue": 0,
		"energy": 20,
		"range": 1,
		"multiplier": 1.18,
		"animation": "slash",
	},
	"sharking_strong_slash": {
		"label": "Сильный порез",
		"fatigue": 0,
		"energy": 35,
		"range": 1,
		"multiplier": 1.85,
		"animation": "strong_slash",
	},
	"force_field_throw": {
		"label": "Бросок силового поля",
		"fatigue": 0,
		"energy": 45,
		"range": 4,
		"range_mode": "up_to",
		"multiplier": 1.62,
		"animation": "force_field_throw",
	},
	"evil_heart": {"label":"Злое сердце","fatigue":0,"energy":45,"range":1,"multiplier":3.60,"animation":"strong_slash"},
	"frost": {"label":"Мороз","fatigue":0,"energy":30,"range":4,"range_mode":"up_to","multiplier":1.15,"animation":"ice_rain","freeze_chance":0.40,"freeze_turns":2},
	"storm_vortex": {"label":"Вихрь бури","fatigue":0,"energy":80,"range":5,"range_mode":"up_to","multiplier":3.10,"animation":"tornado"},
	"shot": {"label":"Выстрел","fatigue":0,"energy":5,"range":3,"range_mode":"up_to","multiplier":1.05,"animation":"spear_throw"},
	"precise_shot": {"label":"Точный выстрел","fatigue":0,"energy":15,"range":4,"range_mode":"up_to","multiplier":1.45,"animation":"spear_throw"},
	"rocket_shot": {"label":"Выстрел ракеты","fatigue":0,"energy":30,"range":3,"range_mode":"up_to","multiplier":1.80,"animation":"bright_bomb"},
	"ice_punch": {"label":"Ледяной удар кулаком","fatigue":0,"energy":15,"range":1,"multiplier":1.35,"animation":"shoulder_bash"},
	"ice_kick": {"label":"Удар ледяной ногой","fatigue":0,"energy":25,"range":1,"multiplier":1.65,"animation":"strong_slash"},
	"devlin_combo": {"label":"Комбо","fatigue":0,"energy":50,"range":3,"range_mode":"up_to","multiplier":3.45,"animation":"bright_bomb","unblockable":true},
	"iceberg": {"label":"Айсберг","fatigue":0,"energy":50,"range":5,"range_mode":"up_to","multiplier":2.20,"animation":"ice_rain","magic":true},

}

const MAGIC_ATTACKS: Array[String] = [
	"ball_lightning", "bright_bomb", "fire_rain", "earthquake",
	"desert_whirl", "quicksand", "desert_storm", "sticky_sandstorm",
	"healing_ban", "ice_rain", "ultrasound", "sound_strike",
	"wind_strike", "incinerate", "force_field_throw", "evil_heart",
	"frost", "storm_vortex", "iceberg",
]

const LOADOUTS: Dictionary = {
	"bastion": ["slash", "lunge", "long_lunge"],
	"kamorge": ["slash", "lunge", "long_lunge", "ball_lightning"],
	"kamorge_eigol": ["slash", "lunge", "strong_slash", "desert_storm", "quicksand", "sticky_sandstorm", "healing_ban"],
	"ione": ["slash", "lunge", "long_lunge"],
	"ione_amphisia": ["slash", "lunge", "long_lunge"],
	"reyna": ["slash", "lunge", "long_lunge", "spear_throw", "ice_rain"],
	"reyna_haurol": ["slash", "lunge", "long_lunge", "spear_throw", "ice_rain"],
	"zeira": ["slash", "lunge", "long_lunge", "spear_throw", "ultrasound", "slide"],
	"zeira_toreadore": ["slash", "lunge", "long_lunge", "spear_throw", "ultrasound", "slide"],
	"andrew": [
		"slash",
		"lunge",
		"long_lunge",
		"strong_slash",
		"shoulder_bash",
		"tornado",
	],
	"galvas": ["slash", "lunge", "strong_slash", "shoulder_bash", "ball_lightning", "bright_bomb"],
	"galvas_serata": ["slash", "lunge", "strong_slash", "shoulder_bash", "ball_lightning", "bright_bomb"],
	"kingdom_glaive": ["slash", "lunge", "long_lunge", "strong_slash"],
	"zakov": ["slash", "lunge", "long_lunge", "strong_slash", "ball_lightning"],
	"zakov_sharking": ["sharking_slash", "sharking_strong_slash", "force_field_throw"],
	"imperial_soldier": ["slash", "lunge", "long_lunge"],
	"captain_soldiers": [
		"slash",
		"lunge",
		"long_lunge",
		"strong_slash",
		"ball_lightning",
	],
	"faulkner": [
		"slash",
		"lunge",
		"long_lunge",
		"strong_slash",
		"ball_lightning",
		"bright_bomb",
		"fire_rain",
	],
	"duyere": ["slash", "lunge", "earthquake"],
	"sadira_sylpheed": ["slash", "lunge", "long_lunge", "sound_strike", "wind_strike"],
	"franco_korbelan": ["slash", "lunge", "long_lunge", "strong_slash", "incinerate", "guillotine"],
	"halak_korbelan": ["slash", "lunge", "long_lunge", "strong_slash", "incinerate", "guillotine"],
	"korbelan_guard": ["slash", "lunge", "long_lunge", "strong_slash", "incinerate", "guillotine"],
	"logan_crimson": ["slash","lunge","strong_slash","ball_lightning","bright_bomb","evil_heart"],
	"claire_rahabar": ["slash","lunge","strong_slash","ball_lightning"],
	"shion_rahabar": ["slash","lunge","strong_slash","ball_lightning","bright_bomb"],
	"nordilian_rahabar": ["slash","lunge","strong_slash","ball_lightning"],
	"alden_altagrave": ["slash","lunge","long_lunge","strong_slash","frost","ice_rain","iceberg","storm_vortex"],
	"devlin_snow_soldier": ["shot","precise_shot","rocket_shot","ice_punch","ice_kick","devlin_combo","frost"],
	"barlow_ratatosk": ["slash","lunge","long_lunge","strong_slash","shoulder_bash","ice_rain","frost"],
	"matisse_ratatosk": ["slash","lunge","strong_slash","shoulder_bash"],

}


static func attack(mode: String) -> Dictionary:
	if not ATTACKS.has(mode):
		return ATTACKS["slash"] as Dictionary
	return ATTACKS[mode] as Dictionary


static func attacks_for(unit: Node3D) -> Array[String]:
	var character_id: String = str(unit.get_meta("character_id", ""))
	var profile: String = str(unit.get_meta("combat_profile", ""))
	var model_slug: String = str(unit.get_meta("model_slug", ""))
	var key: String = character_id if LOADOUTS.has(character_id) else profile
	if character_id == "kamorge" and model_slug == "eigol":
		key = "kamorge_eigol"
	elif character_id == "zakov" and model_slug == "sharking":
		key = "zakov_sharking"
	if key.is_empty():
		key = "imperial_soldier"
	var values: Array = LOADOUTS.get(key, LOADOUTS["imperial_soldier"]) as Array
	var result: Array[String] = []
	for value: Variant in values:
		result.append(str(value))
	return result




static func is_magic(mode: String) -> bool:
	return MAGIC_ATTACKS.has(mode) or bool(attack(mode).get("magic", false))

static func resource_cost(mode: String, counterattack: bool = false) -> Dictionary:
	var data: Dictionary = attack(mode)
	var multiplier: int = 2 if counterattack else 1
	return {
		"fatigue": int(data.get("fatigue", 0)) * multiplier,
		"energy": int(data.get("energy", 0)) * multiplier,
	}
