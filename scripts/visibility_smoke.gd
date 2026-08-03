extends Node3D

const AtacFactory = preload("res://scripts/atac_factory.gd")

# Cover every tactical armour skin currently supported by MultiViewAtac.
# Tactical battles always use full-body multi-view sheets; segmented Skeleton3D
# skins are validated separately through the explicit "skeletal" factory context.
const SLUGS: Array[String] = [
	"alba", "barbatos", "barazaph", "vedocorban", "cador", "solarus",
	"sarbelas", "einlager", "eigol", "amphisia", "haurol", "toreadore",
	"serata", "glaive", "sylpheed", "korbelan", "crimson", "rahabar",
	"altagrave", "snow_soldier", "ratatosk", "panther", "engineer", "waiban",
]
const SKELETAL_SMOKE_SLUGS: Array[String] = [
	"barbatos", "cador", "glaive", "sylpheed", "korbelan",
]
const CAMERA_POSITIONS: Array[Vector3] = [
	Vector3(0, 2.5, 6.0),
	Vector3(6.0, 2.5, 0),
	Vector3(0, 2.5, -6.0),
	Vector3(-6.0, 2.5, 0),
]
const MULTIVIEW_KEYS: Array[String] = ["front", "side", "back", "three_quarter"]


func _ready() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.current = true
	add_child(camera)
	var multiview_count: int = 0
	var scale_samples: Array[float] = []

	for slug: String in SLUGS:
		var rig: Node3D = AtacFactory.create_atac(slug, "tactical")
		if rig == null:
			_fail("TACTICAL_VISIBILITY_FACTORY_NULL_%s" % slug)
			return
		rig.name = "Smoke_%s" % slug
		add_child(rig)
		await get_tree().process_frame

		if not bool(rig.get_meta("multiview_2_5d", false)):
			_fail("TACTICAL_VISIBILITY_EXPECTED_MULTIVIEW_%s" % slug)
			return
		multiview_count += 1
		var multiview_ok: bool = await _validate_multiview_rig(rig, slug)
		if not multiview_ok:
			return
		var recommended: float = float(rig.get_meta("recommended_tactical_scale", 0.0))
		if recommended < 0.55 or recommended > 0.95:
			_fail("TACTICAL_HEIGHT_NORMALIZATION_FAILED_%s scale=%.3f" % [slug, recommended])
			return
		scale_samples.append(recommended)

		for camera_position: Vector3 in CAMERA_POSITIONS:
			camera.position = camera_position
			camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
			rig.look_at(Vector3(camera_position.x, rig.global_position.y, camera_position.z), Vector3.UP, true)
			await get_tree().process_frame
			if not rig.visible or not rig.is_visible_in_tree():
				_fail("TACTICAL_VISIBILITY_EDGE_ON_FAILED_%s" % slug)
				return

		if not rig.has_method("set_combat_pose") or not rig.has_method("reset_pose"):
			_fail("TACTICAL_VISIBILITY_POSE_API_MISSING_%s" % slug)
			return
		for pose_name: String in ["slash", "lunge", "long_lunge", "strong_slash", "ball_lightning", "hit"]:
			rig.call("set_combat_pose", pose_name, 0.55)
			await get_tree().process_frame
		rig.call("reset_pose")
		rig.queue_free()
		await get_tree().process_frame

	if multiview_count != SLUGS.size():
		_fail("TACTICAL_VISIBILITY_RENDERER_COVERAGE_FAILED multiview=%d" % multiview_count)
		return
	if scale_samples.size() >= 2:
		var minimum: float = scale_samples[0]
		var maximum: float = scale_samples[0]
		for sample: float in scale_samples:
			minimum = minf(minimum, sample)
			maximum = maxf(maximum, sample)
		if maximum - minimum > 0.28:
			_fail("TACTICAL_HEIGHT_SPREAD_TOO_LARGE min=%.3f max=%.3f" % [minimum, maximum])
			return

	var skeletal_count: int = 0
	for slug: String in SKELETAL_SMOKE_SLUGS:
		var skeletal: Node3D = AtacFactory.create_atac(slug, "skeletal")
		if skeletal == null:
			_fail("SKELETAL_FACTORY_NULL_%s" % slug)
			return
		add_child(skeletal)
		await get_tree().process_frame
		if not _validate_skeletal_rig(skeletal, slug):
			return
		skeletal_count += 1
		skeletal.queue_free()
		await get_tree().process_frame

	print("TACTICAL_VISIBILITY_SMOKE_OK slugs=%d" % SLUGS.size())
	print("SKELETAL_ATAC_SMOKE_OK count=%d" % skeletal_count)
	print("MULTIVIEW_ATAC_SMOKE_OK count=%d" % multiview_count)
	print("ORIGINAL_SKIN_RIG_SMOKE_OK")
	print("BASIC_ATTACK_ANIMATION_SMOKE_OK")
	print("TACTICAL_HEIGHT_NORMALIZATION_OK")
	get_tree().quit()


func _validate_skeletal_rig(rig: Node3D, slug: String) -> bool:
	var skeleton: Skeleton3D = rig.get_node_or_null("ModelRoot/Skeleton3D") as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() < 20:
		_fail("TACTICAL_VISIBILITY_RIG_FAILED_%s" % slug)
		return false
	if not bool(rig.get_meta("original_skin_rig", false)):
		_fail("TACTICAL_VISIBILITY_ORIGINAL_SKIN_MISSING_%s" % slug)
		return false
	var sprites: Array[Node] = rig.find_children("*", "Sprite3D", true, false)
	if sprites.size() < 10:
		_fail("TACTICAL_VISIBILITY_INCOMPLETE_SKIN_%s" % slug)
		return false
	for sprite_node: Node in sprites:
		var skin_sprite: Sprite3D = sprite_node as Sprite3D
		if skin_sprite != null and skin_sprite.texture == null:
			_fail("TACTICAL_VISIBILITY_SKIN_TEXTURE_MISSING_%s" % slug)
			return false
	return true


func _validate_multiview_rig(rig: Node3D, slug: String) -> bool:
	if str(rig.get_meta("visibility_rig", "")) != "top_level_camera_facing":
		_fail("TACTICAL_VISIBILITY_MULTIVIEW_FACING_MISSING_%s" % slug)
		return false
	var sprite: Sprite3D = rig.get_node_or_null("CameraFacingRoot/ModelRoot/AtacSprite") as Sprite3D
	var outline: Sprite3D = rig.get_node_or_null("CameraFacingRoot/ModelRoot/AtacOutline") as Sprite3D
	if sprite == null or sprite.texture == null:
		_fail("TACTICAL_VISIBILITY_MULTIVIEW_TEXTURE_MISSING_%s" % slug)
		return false
	if outline == null or outline.texture == null:
		_fail("TACTICAL_VISIBILITY_MULTIVIEW_OUTLINE_MISSING_%s" % slug)
		return false
	if not rig.has_method("set_arena_view"):
		_fail("TACTICAL_VISIBILITY_VIEW_API_MISSING_%s" % slug)
		return false
	for view_key: String in MULTIVIEW_KEYS:
		rig.call("set_arena_view", view_key, false)
		await get_tree().process_frame
		if sprite.texture == null:
			_fail("TACTICAL_VIEW_SWAP_FAILED_%s_%s" % [slug, view_key])
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
