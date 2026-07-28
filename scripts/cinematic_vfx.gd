class_name CinematicVfx
extends RefCounted

# Storyboard-driven field effects.  The source frames are processed with a
# transparent background and are displayed as camera-facing luminous layers.
# Only one Sprite3D and one short-lived light are allocated per attack.

static var TEXTURE_CACHE: Dictionary = {}


static func play(parent: Node3D, mode: String, world_position: Vector3, size: float = 1.0, frame_time: float = 0.11) -> void:
	var frames: Array = _frames(mode)
	if frames.is_empty() or parent == null or not is_instance_valid(parent):
		return
	var root: Node3D = Node3D.new()
	root.name = "CinematicVFX_%s" % mode
	root.position = world_position
	parent.add_child(root)

	var sprite: Sprite3D = Sprite3D.new()
	sprite.name = "EffectLayer"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.double_sided = true
	sprite.no_depth_test = true
	sprite.render_priority = 20
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
		sprite.scale = Vector3.ONE * lerpf(0.78, 1.18, ratio)
		sprite.modulate.a = 0.78 if index == 0 else 1.0
		light.light_energy = lerpf(1.1, 3.4, ratio)
		root.rotation_degrees.y = ratio * 5.0
		await parent.get_tree().create_timer(frame_time).timeout

	var fade: Tween = parent.create_tween().set_parallel(true)
	fade.tween_property(sprite, "modulate:a", 0.0, 0.18)
	fade.tween_property(sprite, "scale", sprite.scale * 1.18, 0.18)
	fade.tween_property(light, "light_energy", 0.0, 0.16)
	await fade.finished
	if is_instance_valid(root):
		root.queue_free()


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
		"bright_bomb": return Color(1.0, 0.36, 0.08)
		"sticky_sandstorm", "quicksand", "desert_storm": return Color(1.0, 0.62, 0.18)
		"ice_rain": return Color(0.34, 0.72, 1.0)
		"ball_lightning": return Color(0.35, 0.48, 1.0)
		_: return Color(0.65, 0.88, 1.0)
