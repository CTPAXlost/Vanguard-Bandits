class_name CombatCatalog
extends RefCounted

const AtacProgression = preload("res://scripts/atac_progression.gd")

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
	"punch": {"label":"Удар кулаком","fatigue":0,"energy":0,"range":1,"multiplier":1.00,"animation":"shoulder_bash"},
	"precise_shot": {"label":"Точный выстрел","fatigue":0,"energy":15,"range":4,"range_mode":"up_to","multiplier":1.45,"animation":"spear_throw"},
	"rocket_shot": {"label":"Выстрел ракеты","fatigue":0,"energy":30,"range":3,"range_mode":"up_to","multiplier":1.80,"animation":"bright_bomb"},
	"ice_punch": {"label":"Ледяной удар кулаком","fatigue":0,"energy":15,"range":1,"multiplier":1.35,"animation":"shoulder_bash"},
	"ice_kick": {"label":"Удар ледяной ногой","fatigue":0,"energy":25,"range":1,"multiplier":1.65,"animation":"strong_slash"},
	"devlin_combo": {"label":"Комбо","fatigue":0,"energy":50,"range":3,"range_mode":"up_to","multiplier":3.45,"animation":"bright_bomb","unblockable":true},
	"iceberg": {"label":"Айсберг","fatigue":0,"energy":50,"range":5,"range_mode":"up_to","multiplier":2.20,"animation":"ice_rain","magic":true},
	"double_strike": {"label":"Двойной удар","fatigue":0,"energy":40,"range":1,"multiplier":1.80,"animation":"strong_slash","area_targets":2,"secondary_ratio":1.0},
	"heavy_rain": {"label":"Сильный ливень","fatigue":0,"energy":50,"range":4,"range_mode":"up_to","multiplier":1.70,"animation":"ice_rain","disable_chance":0.65,"disable_turns":2,"area_targets":3,"secondary_ratio":0.75,"magic":true},
	"hyper_blizzard": {"label":"Гипер снежная буря","fatigue":0,"energy":65,"range":4,"range_mode":"up_to","multiplier":3.00,"animation":"tornado","unblockable":true,"magic":true},
	"mind_hypnosis": {"label":"Силовой гипноз","fatigue":0,"energy":75,"range":4,"range_mode":"up_to","multiplier":0.0,"animation":"ultrasound","hypnosis_chance":0.60,"hypnosis_turns":3,"magic":true},
	"shadow_blades": {"label":"Тени","fatigue":0,"energy":35,"range":1,"multiplier":1.65,"animation":"strong_slash","magic":true},
	"dark_lightning": {"label":"Тёмная молния","fatigue":0,"energy":45,"range":4,"range_mode":"up_to","multiplier":1.95,"animation":"ball_lightning","magic":true},
	"hell_gate": {"label":"Врата ада","fatigue":0,"energy":55,"range":4,"range_mode":"up_to","multiplier":2.85,"animation":"bright_bomb","unblockable":true,"magic":true},
	"lord_dark_strike": {"label":"Тёмный удар Лорда","fatigue":0,"energy":80,"range":1,"multiplier":3.25,"animation":"bright_bomb","splash_ratio":0.50,"magic":true},
	"domination_magic": {"label":"Магия подчинения","fatigue":0,"energy":60,"range":4,"range_mode":"up_to","multiplier":0.0,"animation":"ultrasound","domination_chance":0.60,"domination_mission":true,"magic":true},
	"alba_combo": {"label":"Комбо Alba","fatigue":0,"energy":65,"range":2,"range_mode":"up_to","multiplier":3.25,"animation":"bright_bomb"},
	"ice_laugh": {"label":"Ледяной смех","fatigue":0,"energy":35,"range":4,"range_mode":"up_to","multiplier":1.85,"animation":"ice_rain","magic":true},
	"northern_lights": {"label":"Северное сияние","fatigue":0,"energy":55,"range":5,"range_mode":"up_to","multiplier":2.80,"animation":"ice_rain","magic":true},
	"honor_strike": {"label":"Удар чести","fatigue":0,"energy":65,"range":1,"multiplier":2.50,"animation":"strong_slash","unblockable":true},
	"light_strike": {"label":"Световой удар","fatigue":0,"energy":55,"range":4,"range_mode":"up_to","multiplier":1.85,"animation":"ball_lightning","blind_chance":0.60,"blind_turns":1,"magic":true},
	"fate_strike": {"label":"Удар судьбы","fatigue":0,"energy":80,"range":4,"range_mode":"up_to","multiplier":3.20,"animation":"bright_bomb","magic":true},
	"punch_69": {"label":"Удар кулаком","fatigue":0,"energy":10,"range":1,"multiplier":1.15,"animation":"shoulder_bash"},
	"kick_69": {"label":"Удар ногой","fatigue":0,"energy":15,"range":1,"multiplier":1.45,"animation":"strong_slash"},
	"combo_69": {"label":"Комбо-удар","fatigue":0,"energy":45,"range":1,"multiplier":2.85,"animation":"bright_bomb"},
	"energy_wheel": {"label":"Энергетическое колесо","fatigue":0,"energy":40,"range":5,"range_mode":"up_to","multiplier":2.35,"animation":"force_field_throw"},
	"shred": {"label":"Нашинковать","fatigue":0,"energy":60,"range":1,"multiplier":3.75,"animation":"strong_slash","unblockable":true},
	"shining_sky": {"label":"Сияющее небо","fatigue":0,"energy":0,"range":5,"range_mode":"up_to","multiplier":3.20,"animation":"bright_bomb","blind_chance":0.70,"blind_turns":2,"magic":true},
	"ninja_blade": {"label":"Лезвие ниндзя","fatigue":0,"energy":50,"range":3,"range_mode":"up_to","multiplier":3.00,"animation":"wind_strike"},
	"ice_age": {"label":"Ледниковый период","fatigue":0,"energy":55,"range":4,"range_mode":"up_to","multiplier":2.55,"animation":"ice_rain","freeze_chance":1.0,"freeze_turns":1,"area_targets":4,"magic":true},
	"area_rocket": {"label":"Ракетный выстрел по площади","fatigue":0,"energy":0,"range":5,"range_mode":"up_to","multiplier":2.45,"animation":"bright_bomb","area_targets":3},
	"earthquake_area": {"label":"Землетрясение по площади","fatigue":0,"energy":50,"range":5,"range_mode":"up_to","multiplier":2.25,"animation":"earthquake","area_targets":5,"magic":true},
	"geno_flame": {"label":"Гено-пламя","fatigue":0,"energy":0,"range":5,"range_mode":"up_to","multiplier":2.70,"animation":"fire_rain","area_targets":5,"magic":true},
	"flame": {"label":"Пламя","fatigue":0,"energy":0,"range":3,"range_mode":"up_to","multiplier":1.65,"animation":"ball_lightning","magic":true},
	"protuberance": {"label":"Протуберанец","fatigue":0,"energy":0,"range":1,"multiplier":3.45,"animation":"bright_bomb"},
	"sarbelas_spikes": {"label":"Шипы Sarbelas","fatigue":0,"energy":45,"range":4,"range_mode":"up_to","multiplier":2.35,"animation":"earthquake","bleed_damage":25},
	"hoof_stomp": {"label":"Топот копыт","fatigue":0,"energy":45,"range":2,"range_mode":"up_to","multiplier":2.25,"animation":"earthquake","area_targets":3},
	"ice_storm": {"label":"Ледяной шторм","fatigue":0,"energy":35,"range":4,"range_mode":"up_to","multiplier":1.90,"animation":"ice_rain","magic":true},
	"summon_clone": {"label":"Призвать клона","fatigue":0,"energy":0,"range":4,"range_mode":"up_to","multiplier":0.0,"animation":"ultrasound","magic":true},

}

const MAGIC_ATTACKS: Array[String] = [
	"ball_lightning", "bright_bomb", "fire_rain", "earthquake",
	"desert_whirl", "quicksand", "desert_storm", "sticky_sandstorm",
	"healing_ban", "ice_rain", "ultrasound", "sound_strike",
	"wind_strike", "incinerate", "force_field_throw", "evil_heart",
	"frost", "storm_vortex", "iceberg", "heavy_rain", "hyper_blizzard",
	"mind_hypnosis", "shadow_blades", "dark_lightning", "hell_gate",
	"lord_dark_strike", "domination_magic", "ice_laugh", "northern_lights",
	"light_strike", "fate_strike", "shining_sky", "ice_age", "earthquake_area",
	"geno_flame", "flame", "ice_storm", "summon_clone",
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
	"devlin_snow_soldier": ["shot","precise_shot","rocket_shot","punch","ice_punch","ice_kick","devlin_combo","frost"],
	"barlow_ratatosk": ["slash","lunge","long_lunge","strong_slash","shoulder_bash","ice_rain","frost"],
	"matisse_ratatosk": ["slash","lunge","strong_slash","shoulder_bash"],
	"tic_tac": ["slash","lunge","long_lunge","strong_slash","ice_rain","double_strike","heavy_rain","hyper_blizzard","mind_hypnosis"],
	"zulwarn": ["slash","lunge","long_lunge","strong_slash","shadow_blades","dark_lightning","hell_gate","domination_magic","lord_dark_strike"],

}

const MODEL_PROGRESSIONS: Dictionary = {
	"tic_tac": [
		{"min": 1, "attacks": ["slash", "lunge"]},
		{"min": 6, "attacks": ["long_lunge"]},
		{"min": 11, "attacks": ["strong_slash"]},
		{"min": 25, "attacks": ["ice_rain"]},
		{"min": 35, "attacks": ["double_strike"]},
		{"min": 45, "attacks": ["heavy_rain"]},
		{"min": 60, "attacks": ["hyper_blizzard"]},
		{"min": 80, "attacks": ["mind_hypnosis"]},
	],
	"zulwarn": [
		{"min": 1, "attacks": ["slash", "lunge"]},
		{"min": 6, "attacks": ["long_lunge"]},
		{"min": 11, "attacks": ["strong_slash"]},
		{"min": 25, "attacks": ["shadow_blades"]},
		{"min": 35, "attacks": ["dark_lightning"]},
		{"min": 45, "attacks": ["hell_gate"]},
		{"min": 60, "attacks": ["domination_magic"]},
		{"min": 80, "attacks": ["lord_dark_strike"]},
	],
}

const MODEL_MAX_ENERGY: Dictionary = {
	"alden_altagrave": 155,
	"altagrave": 155,
	"claire_rahabar": 90,
	"crimson": 160,
	"devlin_snow_soldier": 140,
	"logan_crimson": 160,
	"rahabar": 100,
	"ratatosk": 100,
	"reyna_haurol": 110,
	"roaring_lion": 150,
	"serata": 120,
	"shion_rahabar": 120,
	"snow_soldier": 140,
	"tic_tac": 250,
	"toreadore": 120,
	"vedocorban": 100,
	"zeira_toreadore": 120,
	"zulwarn": 350,
}

const MODEL_MAGIC_SUMMARY: Dictionary = {
	"tic_tac": "Ледяной шторм, сильный ливень, гипер снежная буря, силовой гипноз",
	"zulwarn": "Тени, тёмная молния, врата ада, магия подчинения, тёмный удар Лорда",
	"altagrave": "Мороз, ледяной дождь, вихрь бури, айсберг",
	"snow_soldier": "Точный выстрел, ракета, мороз, ледяной клон",
	"crimson": "Шаровая молния, яркая бомба, злое сердце",
}

const MODEL_ABILITY_SUMMARY: Dictionary = {
	"tic_tac": "Холодная вода 3×, 50% отражение, 30% контратака, каждую фазу лечения +150 HP союзникам, водопад 1×.",
	"zulwarn": "70% отражение, +150 HP каждый ход, подчинение ATAC соперника, призыв клона +200% (кроме Cador).",
	"altagrave": "Иммунитет к магии, шанс 50% ответного айсберга, аура регенерации 50 HP / 30 энергии.",
	"snow_soldier": "Клон 60% характеристик 1× за бой, мороз может заморозить на 2 хода.",
	"crimson": "Всегда ходит 2 раза, 2× усиление урона на 100%, отражение атак.",
}


static func attack(mode: String) -> Dictionary:
	if not ATTACKS.has(mode):
		return ATTACKS["slash"] as Dictionary
	return ATTACKS[mode] as Dictionary


static func attacks_for(unit: Node3D) -> Array[String]:
	var character_id: String = str(unit.get_meta("character_id", ""))
	var profile: String = str(unit.get_meta("combat_profile", ""))
	var model_slug: String = str(unit.get_meta("model_slug", ""))
	var level: int = int((unit.get_meta("stats", {}) as Dictionary).get("level", 1))
	if AtacProgression.has(model_slug):
		return AtacProgression.attacks_for(model_slug, level)
	var key: String = character_id if LOADOUTS.has(character_id) else profile
	if character_id == "kamorge" and model_slug == "eigol":
		key = "kamorge_eigol"
	elif character_id == "zakov" and model_slug == "sharking":
		key = "zakov_sharking"
	elif key.is_empty() and LOADOUTS.has(model_slug):
		key = model_slug
	if key.is_empty():
		key = "imperial_soldier"
	var values: Array = LOADOUTS.get(key, LOADOUTS["imperial_soldier"]) as Array
	var result: Array[String] = []
	for value: Variant in values:
		result.append(str(value))
	return result


static func _attacks_from_progression(model_slug: String, level: int) -> Array[String]:
	var rows: Array = MODEL_PROGRESSIONS.get(model_slug, []) as Array
	var result: Array[String] = []
	for row_value: Variant in rows:
		var row: Dictionary = row_value as Dictionary
		if level < int(row.get("min", 1)):
			continue
		for attack_id_value: Variant in (row.get("attacks", []) as Array):
			var attack_id: String = str(attack_id_value)
			if not result.has(attack_id):
				result.append(attack_id)
	return result


static func max_energy_for_model(model_slug: String, fallback: int = 0) -> int:
	if AtacProgression.has(model_slug):
		return AtacProgression.max_energy(model_slug, int(MODEL_MAX_ENERGY.get(model_slug, fallback)))
	return int(MODEL_MAX_ENERGY.get(model_slug, fallback))


static func magic_summary_for_unit(unit: Node3D) -> String:
	var stats: Dictionary = unit.get_meta("stats", {}) as Dictionary
	if int(stats.get("magic", 0)) <= 0 and int(stats.get("max_energy", 0)) <= 0:
		return "отключена"
	var model_slug: String = str(unit.get_meta("model_slug", ""))
	var labels: Array[String] = []
	for mode: String in attacks_for(unit):
		if not is_magic(mode):
			continue
		var label: String = str(attack(mode).get("label", mode))
		if not labels.has(label):
			labels.append(label)
	if not labels.is_empty():
		return ", ".join(PackedStringArray(labels))
	var progression_entry: Dictionary = AtacProgression.DATA.get(model_slug, {}) as Dictionary
	for tier_value: Variant in (progression_entry.get("tiers", []) as Array):
		var tier: Dictionary = tier_value as Dictionary
		var unlock_level: int = int(tier.get("min", 1))
		if unlock_level <= int(stats.get("level", 1)):
			continue
		var future_magic: Array[String] = []
		for attack_value: Variant in (tier.get("attacks", []) as Array):
			var future_mode: String = str(attack_value)
			if is_magic(future_mode):
				future_magic.append(str(attack(future_mode).get("label", future_mode)))
		if not future_magic.is_empty():
			return "откроется на ур. %d: %s" % [unlock_level, ", ".join(PackedStringArray(future_magic))]
	return str(MODEL_MAGIC_SUMMARY.get(model_slug, "нет активной магии на этом уровне"))


static func ability_summary_for_unit(unit: Node3D) -> String:
	var stats: Dictionary = unit.get_meta("stats", {}) as Dictionary
	var model_slug: String = str(unit.get_meta("model_slug", ""))
	var progression_summary: String = AtacProgression.ability_summary(model_slug, int(stats.get("level", 1)))
	if not progression_summary.is_empty():
		return progression_summary
	var from_stats: String = str(stats.get("ability", "")).strip_edges()
	if not from_stats.is_empty() and from_stats != "Нет":
		return from_stats
	return str(MODEL_ABILITY_SUMMARY.get(model_slug, "Нет"))


static func max_level_for_unit(unit: Node3D) -> int:
	var model_slug: String = str(unit.get_meta("model_slug", ""))
	return AtacProgression.max_level(model_slug, 99)


static func next_unlock_summary_for_unit(unit: Node3D) -> String:
	var stats: Dictionary = unit.get_meta("stats", {}) as Dictionary
	var model_slug: String = str(unit.get_meta("model_slug", ""))
	var next_data: Dictionary = AtacProgression.next_unlock(model_slug, int(stats.get("level", 1)))
	if next_data.is_empty():
		return "Все приёмы ATAC открыты"
	var labels: Array[String] = []
	for attack_value: Variant in (next_data.get("attacks", []) as Array):
		labels.append(str(attack(str(attack_value)).get("label", str(attack_value))))
	return "Ур. %d: %s" % [int(next_data.get("level", 1)), ", ".join(PackedStringArray(labels))]


static func is_magic(mode: String) -> bool:
	return MAGIC_ATTACKS.has(mode) or bool(attack(mode).get("magic", false))

static func resource_cost(mode: String, counterattack: bool = false) -> Dictionary:
	var data: Dictionary = attack(mode)
	var multiplier: int = 2 if counterattack else 1
	return {
		"fatigue": int(data.get("fatigue", 0)) * multiplier,
		"energy": int(data.get("energy", 0)) * multiplier,
	}
