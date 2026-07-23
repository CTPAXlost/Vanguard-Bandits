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
}

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
	],
	"duyere": ["slash", "lunge", "earthquake"],
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
	if key.is_empty():
		key = "imperial_soldier"
	var values: Array = LOADOUTS.get(key, LOADOUTS["imperial_soldier"]) as Array
	var result: Array[String] = []
	for value: Variant in values:
		result.append(str(value))
	return result


static func resource_cost(mode: String, counterattack: bool = false) -> Dictionary:
	var data: Dictionary = attack(mode)
	var multiplier: int = 2 if counterattack else 1
	return {
		"fatigue": int(data.get("fatigue", 0)) * multiplier,
		"energy": int(data.get("energy", 0)) * multiplier,
	}
