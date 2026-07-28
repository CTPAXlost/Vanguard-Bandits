extends Node

const AtacProgression = preload("res://scripts/atac_progression.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for slug_value: Variant in AtacProgression.DATA.keys():
		var slug: String = str(slug_value)
		var entry: Dictionary = AtacProgression.DATA[slug] as Dictionary
		var maximum_level: int = int(entry.get("max_level", 0))
		if maximum_level <= 0:
			_fail("invalid max level for %s" % slug)
			return
		var previous_count: int = 0
		for tier_value: Variant in (entry.get("tiers", []) as Array):
			var tier: Dictionary = tier_value as Dictionary
			var tier_level: int = int(tier.get("min", 1))
			if tier_level > maximum_level:
				_fail("unlock above max level for %s" % slug)
				return
			for attack_value: Variant in (tier.get("attacks", []) as Array):
				var attack_id: String = str(attack_value)
				if not CombatCatalog.ATTACKS.has(attack_id):
					_fail("unknown attack %s in %s" % [attack_id, slug])
					return
			var current: Array[String] = AtacProgression.attacks_for(slug, tier_level)
			if current.size() < previous_count:
				_fail("attacks are not cumulative for %s" % slug)
				return
			previous_count = current.size()
	if AtacProgression.attacks_for("alba", 1) != ["slash", "lunge", "long_lunge"]:
		_fail("Alba level 1 progression is wrong")
		return
	if not AtacProgression.attacks_for("alba", 19).has("alba_combo"):
		_fail("Alba combo is not unlocked at level 19")
		return
	if AtacProgression.max_level("tic_tac") != 80 or AtacProgression.max_energy("tic_tac") != 250:
		_fail("TIC-TAC limits are wrong")
		return
	if not AtacProgression.attacks_for("tic_tac", 80).has("mind_hypnosis"):
		_fail("TIC-TAC hypnosis is not unlocked")
		return
	if AtacProgression.max_level("zulwarn") != 100 or AtacProgression.max_energy("zulwarn") != 350:
		_fail("Zulwarn limits are wrong")
		return
	if not AtacProgression.attacks_for("zulwarn", 100).has("summon_clone"):
		_fail("Zulwarn clone is not unlocked")
		return
	CampaignState.reset_campaign()
	var bastion: Dictionary = CampaignState.characters["bastion"] as Dictionary
	bastion["experience"] = CampaignState.xp_needed(1) - 1
	CampaignState.characters["bastion"] = bastion
	var result: Dictionary = CampaignState.award_experience("bastion", 1)
	if int(result.get("level", 0)) != 2 or int(result.get("stat_points", 0)) != 3:
		_fail("battle experience does not grant a level and 3 stat points")
		return
	print("ATAC_PROGRESSION_SMOKE_OK entries=%d" % AtacProgression.DATA.size())
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("ATAC_PROGRESSION_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
