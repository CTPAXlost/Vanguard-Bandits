class_name CinematicVfx
extends RefCounted

# Storyboard-driven field effects.  The source frames are processed with a
# transparent background and are displayed as camera-facing luminous layers.
# Missing storyboard packs fall back to procedural CombatFx bursts so magic
# and special attacks never play "empty".

const CombatFx = preload("res://scripts/combat_fx.gd")

static var TEXTURE_CACHE: Dictionary = {}


static func play(parent: Node3D, mode: String, world_position: Vector3, size: float = 1.0, frame_time: float = 0.11) -> void:
	var frames: Array = _frames(mode)
	if parent == null or not is_instance_valid(parent):
		return
	if frames.is_empty():
		await _procedural_fallback(parent, mode, world_position, size)
		return
	var root: Node3D = Node3D.new()
	root.name = "CinematicVFX_%s" % mode
	root.position = world_position
	if parent.has_method("_register_transient_fx"):
		parent.call("_register_transient_fx", root, 2.5)
	else:
		parent.add_child(root)

	var sprite: Sprite3D = Sprite3D.new()
	sprite.name = "EffectLayer"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.double_sided = true
	sprite.no_depth_test = true
	sprite.render_priority = 20
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = 0.0047 * size
	sprite.position = Vector3(0, 0.68, 0)
	sprite.modulate = Color(1.12, 1.12, 1.12, 0.0)
	root.add_child(sprite)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "ImpactLight"
	light.omni_range = 4.2 * size
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.light_color = _mode_color(mode)
	light.position = Vector3(0, 0.72, 0)
	root.add_child(light)

	for index: int in range(frames.size()):
		if not is_instance_valid(root):
			return
		sprite.texture = frames[index]
		var ratio: float = float(index) / float(maxi(1, frames.size() - 1))
		sprite.scale = Vector3.ONE * lerpf(0.78, 1.22, ratio)
		sprite.modulate.a = 0.78 if index == 0 else 1.0
		light.light_energy = lerpf(1.35, 4.2, ratio)
		root.rotation_degrees.y = ratio * 8.0
		await parent.get_tree().create_timer(frame_time).timeout

	CombatFx.impact_burst(parent, world_position + Vector3(0, 0.7, 0), _mode_color(mode), 1.05 * size, 12)
	var fade: Tween = parent.create_tween().set_parallel(true)
	fade.tween_property(sprite, "modulate:a", 0.0, 0.18)
	fade.tween_property(sprite, "scale", sprite.scale * 1.22, 0.18)
	fade.tween_property(light, "light_energy", 0.0, 0.16)
	await fade.finished
	if is_instance_valid(root):
		root.queue_free()


static func _procedural_fallback(parent: Node3D, mode: String, world_position: Vector3, size: float) -> void:
	var color: Color = _mode_color(mode)
	match mode:
		"ball_lightning", "ultrasound", "northern_lights":
			await CombatFx.magic_orb(parent, world_position + Vector3(0, 1.4, 0), world_position + Vector3(0, 0.9, 0), color, 0.18 * size)
		"bright_bomb", "rocket_shot", "area_rocket", "geno_flame", "evil_heart":
			CombatFx.slash_ribbon(parent, world_position + Vector3(0, 0.9, 0), color, 1.2 * size)
			CombatFx.impact_burst(parent, world_position + Vector3(0, 0.8, 0), color, 1.35 * size, 18)
			await parent.get_tree().create_timer(0.22).timeout
		"ice_rain", "frost", "ice_age":
			for index: int in range(5):
				CombatFx.impact_burst(parent, world_position + Vector3(randf_range(-0.35, 0.35), 0.4 + index * 0.12, randf_range(-0.35, 0.35)), color, 0.55 * size, 6)
				await parent.get_tree().create_timer(0.05).timeout
		"sticky_sandstorm", "quicksand", "desert_storm", "storm_vortex":
			for index: int in range(6):
				CombatFx.slash_ribbon(parent, world_position + Vector3(0, 0.35 + index * 0.08, 0), color, 0.75 + index * 0.08)
				await parent.get_tree().create_timer(0.045).timeout
			CombatFx.impact_burst(parent, world_position + Vector3(0, 0.7, 0), color, 1.2 * size, 14)
		_:
			CombatFx.impact_burst(parent, world_position + Vector3(0, 0.75, 0), color, 1.1 * size, 14)
			await parent.get_tree().create_timer(0.18).timeout


static func _frames(mode: String) -> Array:
	if TEXTURE_CACHE.has(mode):
		return TEXTURE_CACHE[mode]
	var result: Array = []
	for index: int in range(1, 5):
		var path: String = "res://assets/vfx/storyboard/%s/%d.png" % [mode, index]
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		if texture != null:
			result.append(texture)
	TEXTURE_CACHE[mode] = result
	return result


static func _mode_color(mode: String) -> Color:
	match mode:
		"bright_bomb", "rocket_shot", "area_rocket", "geno_flame": return Color(1.0, 0.30, 0.06)
		"evil_heart": return Color(1.0, 0.04, 0.18)
		"sticky_sandstorm", "quicksand", "desert_storm": return Color(1.0, 0.62, 0.18)
		"ice_rain", "frost", "ice_age": return Color(0.34, 0.72, 1.0)
		"storm_vortex": return Color(0.26, 0.48, 1.0)
		"ball_lightning": return Color(0.35, 0.48, 1.0)
		_: return Color(0.65, 0.88, 1.0)
