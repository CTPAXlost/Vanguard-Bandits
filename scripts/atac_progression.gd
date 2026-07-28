class_name AtacProgression
extends RefCounted

# Official level progression supplied by the project author.
# Tiers are cumulative: every attack from all tiers up to the current level is available.
const DATA: Dictionary = {
	"alba": {
		"name": "Alba", "max_level": 40,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge", "long_lunge"]},
			{"min": 6, "attacks": ["strong_slash", "ball_lightning"]},
			{"min": 11, "attacks": ["bright_bomb"]},
			{"min": 19, "attacks": ["alba_combo"]},
		],
		"abilities": [
			{"min": 6, "text": "Отражение атаки: 35%."},
			{"min": 11, "text": "Отражение атаки: 55%; каждый ход восстанавливает 35 HP."},
			{"min": 19, "text": "Каждый ход восстанавливает 100 HP."},
			{"min": 40, "text": "Отражение до 75%; шанс снижается против значительно более сильного противника."},
		],
	},
	"amphisia": {
		"name": "Amphisia", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["ice_laugh"]},
		],
	},
	"andoras_amphisia": {
		"name": "Andoras Amphisia", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["desert_storm"]},
		],
	},
	"barazaph": {
		"name": "Barazaph", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["tornado"]},
		],
	},
	"barbatos": {
		"name": "Barbatos", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["ball_lightning"]},
		],
	},
	"dantarius": {
		"name": "Dantarius", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["spear_throw"]},
		],
	},
	"eigol": {
		"name": "Eigol", "max_level": 30,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["desert_storm", "quicksand"]},
			{"min": 30, "attacks": ["sticky_sandstorm", "healing_ban"]},
		],
		"abilities": [{"min": 20, "text": "Отражение атаки: 50%."}],
	},
	"einlager": {
		"name": "Einlager", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["ball_lightning"]},
		],
	},
	"flaros": {
		"name": "Flaros", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["tornado"]},
		],
	},
	"glaive": {
		"name": "Glaive", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["ball_lightning"]},
		],
	},
	"haizuron": {
		"name": "Haizuron", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["tornado"]},
		],
	},
	"haurol": {
		"name": "Haurol", "max_level": 30,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge", "spear_throw"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["ice_rain"]},
			{"min": 30, "attacks": ["northern_lights"]},
		],
	},
	"korbelan": {
		"name": "Korbelan", "max_level": 50,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge", "strong_slash"]},
			{"min": 11, "attacks": ["incinerate"]},
			{"min": 25, "attacks": ["guillotine"]},
			{"min": 40, "attacks": ["honor_strike"]},
		],
		"abilities": [
			{"min": 6, "text": "Магия лечения: восстанавливает 150 HP и завершает ход."},
			{"min": 25, "text": "Стальная броня: 60% шанс снизить входящий урон на 50%."},
		],
	},
	"sylpheed": {
		"name": "Sylpheed", "max_level": 60,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge", "strong_slash"]},
			{"min": 11, "attacks": ["sound_strike"]},
			{"min": 25, "attacks": ["wind_strike"]},
			{"min": 35, "attacks": ["light_strike"]},
			{"min": 55, "attacks": ["fate_strike"]},
		],
		"abilities": [
			{"min": 6, "text": "Полёт: 60% уклонение с контратакой; со спины 80%."},
			{"min": 11, "text": "3× за миссию восстанавливает 50% энергии и завершает ход."},
			{"min": 55, "text": "Новая жизнь: 1× воскрешает союзника с 60% HP."},
		],
	},
	"number_69": {
		"name": "#69", "max_level": 60,
		"tiers": [
			{"min": 1, "attacks": ["punch_69"]},
			{"min": 20, "attacks": ["kick_69"]},
			{"min": 40, "attacks": ["combo_69"]},
		],
		"abilities": [
			{"min": 20, "text": "Апперкот: 65% шанс ударить первым; 50% шанс похитить 30 энергии."},
			{"min": 60, "text": "60% шанс отпрыгнуть от удара на клетку; повышенное уклонение."},
		],
	},
	"rahabar": {
		"name": "Rahabor", "max_level": 30,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["ball_lightning"]},
			{"min": 30, "attacks": ["bright_bomb"]},
		],
	},
	"ratatosk": {
		"name": "Ratatosk", "max_level": 30,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
		],
		"abilities": [{"min": 25, "text": "Повышенная броня: −20% входящего немагического урона."}],
	},
	"serata": {
		"name": "Serata", "max_level": 35,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash", "shoulder_bash"]},
			{"min": 20, "attacks": ["ball_lightning"]},
			{"min": 30, "attacks": ["bright_bomb"]},
		],
		"abilities": [
			{"min": 20, "text": "Аура: союзникам в радиусе 3 клеток +15 HP и энергии каждый ход."},
			{"min": 30, "text": "Усиленная аура: союзникам +35 HP и энергии каждый ход."},
		],
	},
	"sharking": {
		"name": "Sharking", "max_level": 55,
		"tiers": [
			{"min": 1, "attacks": ["sharking_slash"]},
			{"min": 20, "attacks": ["sharking_strong_slash"]},
			{"min": 30, "attacks": ["energy_wheel"]},
			{"min": 50, "attacks": ["shred"]},
		],
		"abilities": [
			{"min": 20, "text": "250 брони."},
			{"min": 30, "text": "250 брони и +50 брони каждый ход."},
			{"min": 50, "text": "70% шанс отбить атаку; «Нашинковать» нельзя защитить или уклонить."},
		],
	},
	"solarus": {
		"name": "Solarus", "max_level": 50,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 25, "attacks": ["ball_lightning"]},
			{"min": 35, "attacks": ["bright_bomb"]},
			{"min": 45, "attacks": ["shining_sky"]},
		],
		"abilities": [
			{"min": 11, "text": "Высокий шанс отражения атаки."},
			{"min": 35, "text": "Первая атака отражается со 100% шансом; далее шанс случайный."},
			{"min": 45, "text": "1× за раунд восстанавливает себе 300 HP."},
		],
	},
	"vedocorban": {
		"name": "Vedocorban", "max_level": 50,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash", "shoulder_bash"]},
			{"min": 25, "attacks": ["tornado"]},
			{"min": 35, "attacks": ["wind_strike"]},
			{"min": 50, "attacks": ["ninja_blade"]},
		],
		"abilities": [
			{"min": 11, "text": "60% шанс уклониться от любой атаки."},
			{"min": 25, "text": "80% шанс уклониться от любой атаки."},
			{"min": 50, "text": "3 ловушки за миссию: бомба 100–300 HP, капкан с кровотечением 55 HP/ход, сеть с пропуском хода."},
		],
	},
	"waiban": {
		"name": "Waiban", "max_level": 35,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash", "shoulder_bash"]},
			{"min": 20, "attacks": ["ball_lightning"]},
			{"min": 30, "attacks": ["bright_bomb"]},
		],
		"abilities": [
			{"min": 20, "text": "Аура: союзникам в радиусе 3 клеток +15 HP и энергии каждый ход."},
			{"min": 30, "text": "Усиленная аура: союзникам +35 HP и энергии каждый ход."},
		],
	},
	"yurangol": {
		"name": "Yurangol", "max_level": 20,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["desert_storm"]},
		],
	},
	"altagrave": {
		"name": "Altagrave", "max_level": 60, "max_energy": 155,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash", "ice_rain"]},
			{"min": 25, "attacks": ["frost"]},
			{"min": 35, "attacks": ["storm_vortex"]},
			{"min": 50, "attacks": ["ice_age"]},
		],
		"abilities": [
			{"min": 11, "text": "Полный иммунитет к любой вражеской магии."},
			{"min": 25, "text": "Каждый ход себе и союзникам +50 HP и +30 энергии."},
			{"min": 35, "text": "50% шанс ответного Айсберга с уроном 200% мощности."},
		],
	},
	"snow_soldier": {
		"name": "Snow Soldier", "max_level": 60,
		"tiers": [
			{"min": 1, "attacks": ["shot", "punch"]},
			{"min": 10, "attacks": ["precise_shot", "ice_punch", "frost"]},
			{"min": 25, "attacks": ["rocket_shot", "ice_kick"]},
			{"min": 35, "attacks": ["devlin_combo"]},
			{"min": 50, "attacks": ["area_rocket"]},
		],
		"abilities": [{"min": 50, "text": "1× за бой создаёт клона с 60% всех характеристик и HP."}],
	},
	"bahamut": {
		"name": "Bahamut", "max_level": 45,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["desert_storm", "quicksand"]},
			{"min": 30, "attacks": ["sticky_sandstorm", "healing_ban"]},
			{"min": 40, "attacks": ["earthquake_area"]},
		],
		"abilities": [{"min": 20, "text": "Отражение атаки: 50%."}],
	},
	"crimson": {
		"name": "Crimson", "max_level": 60, "max_energy": 160,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["ball_lightning"]},
			{"min": 30, "attacks": ["bright_bomb"]},
			{"min": 40, "attacks": ["evil_heart"]},
			{"min": 60, "attacks": ["geno_flame"]},
		],
		"abilities": [
			{"min": 11, "text": "Может отражать атаки."},
			{"min": 20, "text": "Всегда ходит два раза."},
			{"min": 30, "text": "2× за бой увеличивает урон себе или союзнику на 100%."},
		],
	},
	"roaring_lion": {
		"name": "Roaring Lion", "max_level": 60, "max_energy": 150,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["flame"]},
			{"min": 25, "attacks": ["ball_lightning", "bright_bomb"]},
			{"min": 40, "attacks": ["protuberance"]},
		],
		"abilities": [
			{"min": 11, "text": "Может отражать атаки."},
			{"min": 20, "text": "2× за миссию усиливает атаку в 2 раза."},
			{"min": 25, "text": "Щит спартанца: 50% шанс снизить урон на 45%; 1× за миссию может обнулить урон."},
		],
	},
	"sarbelas": {
		"name": "Sarbelas", "max_level": 40,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 25, "attacks": ["desert_storm", "tornado"]},
			{"min": 35, "attacks": ["sarbelas_spikes"]},
		],
	},
	"toreadore": {
		"name": "Toreadore", "max_level": 60,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge", "spear_throw"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 20, "attacks": ["ultrasound"]},
			{"min": 30, "attacks": ["wind_strike"]},
			{"min": 40, "attacks": ["slide"]},
			{"min": 60, "attacks": ["hoof_stomp"]},
		],
		"abilities": [
			{"min": 11, "text": "Двойное перемещение — до 15 клеток."},
			{"min": 20, "text": "Точечно восстанавливает союзнику 50% энергии."},
			{"min": 30, "text": "Удар копытами со спины: 250% мощности и отбрасывание на 4 клетки."},
		],
	},
	"tic_tac": {
		"name": "TIC-TAC", "max_level": 80, "max_energy": 250,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 25, "attacks": ["ice_storm"]},
			{"min": 35, "attacks": ["double_strike"]},
			{"min": 45, "attacks": ["heavy_rain"]},
			{"min": 60, "attacks": ["hyper_blizzard"]},
			{"min": 80, "attacks": ["mind_hypnosis"]},
		],
		"abilities": [
			{"min": 25, "text": "Холодная вода: 3× восстанавливает 80 энергии; 50% отражение и 30% контратака."},
			{"min": 45, "text": "Каждый ход себе и союзникам +150 HP."},
			{"min": 60, "text": "Водопад 1× за миссию: весь урон за круг хода равен нулю."},
		],
	},
	"zulwarn": {
		"name": "Zulwarn", "max_level": 100, "max_energy": 350,
		"tiers": [
			{"min": 1, "attacks": ["slash", "lunge"]},
			{"min": 6, "attacks": ["long_lunge"]},
			{"min": 11, "attacks": ["strong_slash"]},
			{"min": 25, "attacks": ["shadow_blades"]},
			{"min": 35, "attacks": ["dark_lightning"]},
			{"min": 45, "attacks": ["hell_gate"]},
			{"min": 60, "attacks": ["domination_magic"]},
			{"min": 80, "attacks": ["lord_dark_strike"]},
			{"min": 100, "attacks": ["summon_clone"]},
		],
		"abilities": [
			{"min": 11, "text": "70% шанс отразить атаку."},
			{"min": 25, "text": "Каждый ход восстанавливает 150 HP."},
			{"min": 100, "text": "Клон выбранного персонажа усиливается на 200%; на Cador не действует."},
		],
	},
}


static func has(slug: String) -> bool:
	return DATA.has(_normalize(slug))


static func max_level(slug: String, fallback: int = 99) -> int:
	var entry: Dictionary = DATA.get(_normalize(slug), {}) as Dictionary
	return int(entry.get("max_level", fallback))


static func max_energy(slug: String, fallback: int = 0) -> int:
	var entry: Dictionary = DATA.get(_normalize(slug), {}) as Dictionary
	return int(entry.get("max_energy", fallback))


static func attacks_for(slug: String, level: int, fallback: Array[String] = []) -> Array[String]:
	var entry: Dictionary = DATA.get(_normalize(slug), {}) as Dictionary
	if entry.is_empty():
		var fallback_copy: Array[String] = []
		for fallback_value: String in fallback:
			fallback_copy.append(fallback_value)
		return fallback_copy
	var result: Array[String] = []
	for tier_value: Variant in (entry.get("tiers", []) as Array):
		var tier: Dictionary = tier_value as Dictionary
		if level < int(tier.get("min", 1)):
			continue
		for attack_value: Variant in (tier.get("attacks", []) as Array):
			var attack_id: String = str(attack_value)
			if not result.has(attack_id):
				result.append(attack_id)
	return result


static func ability_summary(slug: String, level: int) -> String:
	var entry: Dictionary = DATA.get(_normalize(slug), {}) as Dictionary
	if entry.is_empty():
		return ""
	var latest: String = ""
	for ability_value: Variant in (entry.get("abilities", []) as Array):
		var ability: Dictionary = ability_value as Dictionary
		if level >= int(ability.get("min", 1)):
			latest = str(ability.get("text", ""))
	return latest


static func next_unlock(slug: String, level: int) -> Dictionary:
	var entry: Dictionary = DATA.get(_normalize(slug), {}) as Dictionary
	if entry.is_empty():
		return {}
	for tier_value: Variant in (entry.get("tiers", []) as Array):
		var tier: Dictionary = tier_value as Dictionary
		var required: int = int(tier.get("min", 1))
		if required <= level:
			continue
		return {"level": required, "attacks": (tier.get("attacks", []) as Array).duplicate()}
	return {}


static func display_name(slug: String) -> String:
	var entry: Dictionary = DATA.get(_normalize(slug), {}) as Dictionary
	return str(entry.get("name", slug.capitalize()))


static func _normalize(slug: String) -> String:
	var normalized: String = slug.to_lower().strip_edges().replace("-", "_").replace(" ", "_").replace(".", "")
	if normalized == "andoras":
		return "andoras_amphisia"
	if normalized in ["#69", "69", "no_86", "no86", "#86", "86"]:
		return "number_69"
	return normalized
