extends Node

const BattleArenaDirectorScript = preload("res://scripts/battle_arena_director.gd")


func _ready() -> void:
	var director := BattleArenaDirectorScript.new()
	add_child(director)

	# First pass intentionally marks the attacker as AI. Version 1.5 must open
	# the same arena presentation for allied AI, enemies and player-controlled units.
	var attacker: Node3D = Node3D.new()
	attacker.set_meta("label", "Союзный ИИ / Serata")
	attacker.set_meta("model_slug", "serata")
	attacker.set_meta("player", false)
	add_child(attacker)
	var target: Node3D = Node3D.new()
	target.set_meta("label", "Страж / Barbatos")
	target.set_meta("model_slug", "barbatos")
	target.set_meta("player", true)
	add_child(target)

	await get_tree().process_frame
	await director.play_attack(attacker, target, "strong_slash", "Сильный порез")

	# Second pass covers a projectile/magic effect and reversed real/multiview sides.
	attacker.set_meta("label", "Вражеский ИИ / Barbatos")
	attacker.set_meta("model_slug", "barbatos")
	target.set_meta("label", "Королевский гвардеец / Glaive")
	target.set_meta("model_slug", "glaive")
	await director.play_attack(attacker, target, "ball_lightning", "Шаровая молния")

	print("ARENA_V15_AI_OK")
	print("ARENA_SMOKE_OK")
	get_tree().quit()
