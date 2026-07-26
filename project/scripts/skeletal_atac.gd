class_name SkeletalAtac
extends Node3D

# Version 1.7.1: the original ATAC skin is cut into articulated transparent
# armour layers and attached to a real Skeleton3D.  This preserves the exact
# silhouette, colours and armour artwork instead of rebuilding the machine from
# box primitives.  All repeated units reuse imported textures from Godot's
# resource cache.

const SUPPORTED_SLUGS: Array[String] = [
	"alba", "barbatos", "barazaph", "vedocorban", "cador", "solarus",
	"sarbelas", "einlager", "eigol", "amphisia", "haurol", "toreadore",
	"serata", "glaive", "sylpheed", "korbelan", "sharking",
]
const SAFE_AABB: AABB = AABB(Vector3(-2.4, -0.6, -1.0), Vector3(4.8, 4.6, 2.0))

static var TEXTURE_CACHE: Dictionary = {}

var slug: String = "alba"
var model_root: Node3D
var skeleton: Skeleton3D
var bone_indices: Dictionary = {}
var bone_global_positions: Dictionary = {}
var attachments: Dictionary = {}
var skin_sprites: Array[Sprite3D] = []
var right_arm_pivot: Node3D
var left_arm_pivot: Node3D
var right_leg_pivot: Node3D
var left_leg_pivot: Node3D
var weapon_pivot: Node3D
var second_weapon_pivot: Node3D
var pose_kind: String = "idle"
var pose_progress: float = 0.0
var walk_phase: float = 0.0
var walk_intensity: float = 0.0
var pose_scale: Vector3 = Vector3.ONE
var pose_offset_y: float = 0.0
var rig_data: Dictionary = {}
var skin_pixel_size: float = 0.0021
var bbox_width: float = 512.0
var bbox_height: float = 940.0


static func supports(model_slug: String) -> bool:
	return SUPPORTED_SLUGS.has(model_slug.to_lower())


func configure(model_slug: String) -> void:
	slug = model_slug.to_lower()
	if not SUPPORTED_SLUGS.has(slug):
		slug = "alba"
	name = "%s_OriginalSkinRig" % slug.capitalize()
	set_meta("atac_slug", slug)
	set_meta("real_skeleton", true)
	set_meta("original_skin_rig", true)
	set_meta("rig_status", "segmented_original_skin_v171")
	set_meta("reference_revision", "campaign_v171")

	rig_data = _load_rig_data()
	skin_pixel_size = float(rig_data.get("pixel_size", 0.0021))
	var alpha_bbox: Array = rig_data.get("alpha_bbox", [0, 0, 512, 940]) as Array
	bbox_width = float(alpha_bbox[2]) - float(alpha_bbox[0])
	bbox_height = float(alpha_bbox[3]) - float(alpha_bbox[1])
	var unscaled_height: float = maxf(0.1, bbox_height * skin_pixel_size)
	# All humanoid ATACs are normalized to the same tactical height. Their original
	# silhouettes remain intact, but oversized source sheets no longer dwarf allies.
	var target_height: float = 1.70
	set_meta("recommended_tactical_scale", clampf(target_height / unscaled_height, 0.68, 1.08))
	set_meta("source_front_path", str(rig_data.get("source", "")))
	set_meta("skin_pixel_size", skin_pixel_size)

	# ModelRoot is top-level so the exact 2.5D skin can always face the tactical
	# camera without inheriting the gameplay-facing direction used for back attacks.
	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	model_root.top_level = true
	add_child(model_root)

	# Compatibility pivots preserve old scene paths.  Their rotations are copied
	# to the corresponding bones every frame.
	right_arm_pivot = _new_pivot("RightArmPivot")
	model_root.add_child(right_arm_pivot)
	weapon_pivot = _new_pivot("WeaponPivot")
	right_arm_pivot.add_child(weapon_pivot)
	left_arm_pivot = _new_pivot("LeftArmPivot")
	model_root.add_child(left_arm_pivot)
	second_weapon_pivot = _new_pivot("SecondWeaponPivot")
	left_arm_pivot.add_child(second_weapon_pivot)
	right_leg_pivot = _new_pivot("RightLegPivot")
	model_root.add_child(right_leg_pivot)
	left_leg_pivot = _new_pivot("LeftLegPivot")
	model_root.add_child(left_leg_pivot)

	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	model_root.add_child(skeleton)
	_build_skeleton()
	_build_original_skin()
	_build_weapon_overlay()
	_add_contact_shadow()
	reset_pose()
	set_process(true)


func _load_rig_data() -> Dictionary:
	var path: String = "res://assets/atac_rigged/%s/rig.json" % slug
	if not FileAccess.file_exists(path):
		push_error("Missing articulated skin data: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("Invalid articulated skin JSON: %s" % path)
	return {}


func _new_pivot(pivot_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = pivot_name
	return pivot


func _build_skeleton() -> void:
	var joints: Dictionary = rig_data.get("joints", {}) as Dictionary
	_add_bone_global("root", "", _joint_point(joints, "root", Vector2(0.5, 1.0)))
	_add_bone_global("pelvis", "root", _joint_point(joints, "pelvis", Vector2(0.5, 0.56)))
	_add_bone_global("spine", "pelvis", _joint_point(joints, "spine", Vector2(0.5, 0.45)))
	_add_bone_global("chest", "spine", _joint_point(joints, "chest", Vector2(0.5, 0.335)))
	_add_bone_global("neck", "chest", _joint_point(joints, "neck", Vector2(0.5, 0.225)))
	_add_bone_global("head", "neck", _joint_point(joints, "head", Vector2(0.5, 0.155)))
	_add_bone_global("shoulder_l", "chest", _joint_point(joints, "shoulder_l", Vector2(0.34, 0.285)))
	_add_bone_global("upper_arm_l", "shoulder_l", _joint_point(joints, "upper_arm_l", Vector2(0.285, 0.335)))
	_add_bone_global("lower_arm_l", "upper_arm_l", _joint_point(joints, "lower_arm_l", Vector2(0.18, 0.47)))
	_add_bone_global("hand_l", "lower_arm_l", _joint_point(joints, "hand_l", Vector2(0.105, 0.565)))
	_add_bone_global("shoulder_r", "chest", _joint_point(joints, "shoulder_r", Vector2(0.66, 0.285)))
	_add_bone_global("upper_arm_r", "shoulder_r", _joint_point(joints, "upper_arm_r", Vector2(0.715, 0.335)))
	_add_bone_global("lower_arm_r", "upper_arm_r", _joint_point(joints, "lower_arm_r", Vector2(0.82, 0.47)))
	_add_bone_global("hand_r", "lower_arm_r", _joint_point(joints, "hand_r", Vector2(0.895, 0.565)))
	_add_bone_global("upper_leg_l", "pelvis", _joint_point(joints, "upper_leg_l", Vector2(0.405, 0.625)))
	_add_bone_global("lower_leg_l", "upper_leg_l", _joint_point(joints, "lower_leg_l", Vector2(0.37, 0.79)))
	_add_bone_global("foot_l", "lower_leg_l", _joint_point(joints, "foot_l", Vector2(0.36, 0.955)))
	_add_bone_global("upper_leg_r", "pelvis", _joint_point(joints, "upper_leg_r", Vector2(0.595, 0.625)))
	_add_bone_global("lower_leg_r", "upper_leg_r", _joint_point(joints, "lower_leg_r", Vector2(0.63, 0.79)))
	_add_bone_global("foot_r", "lower_leg_r", _joint_point(joints, "foot_r", Vector2(0.64, 0.955)))
	# Extra bones keep the rig extensible and preserve the existing smoke contract.
	_add_bone_global("rear_body", "pelvis", _point_from_normalized(Vector2(0.5, 0.62)) + Vector3(0, 0, 0.02))
	_add_bone_global("rear_leg_l", "rear_body", _point_from_normalized(Vector2(0.34, 0.76)) + Vector3(0, 0, 0.02))
	_add_bone_global("rear_foot_l", "rear_leg_l", _point_from_normalized(Vector2(0.31, 0.96)) + Vector3(0, 0, 0.02))
	_add_bone_global("rear_leg_r", "rear_body", _point_from_normalized(Vector2(0.66, 0.76)) + Vector3(0, 0, 0.02))
	_add_bone_global("rear_foot_r", "rear_leg_r", _point_from_normalized(Vector2(0.69, 0.96)) + Vector3(0, 0, 0.02))


func _joint_point(joints: Dictionary, key: String, fallback: Vector2) -> Vector3:
	var raw: Variant = joints.get(key, [fallback.x, fallback.y])
	if raw is Array and (raw as Array).size() >= 2:
		var values: Array = raw as Array
		return _point_from_normalized(Vector2(float(values[0]), float(values[1])))
	return _point_from_normalized(fallback)


func _point_from_normalized(point: Vector2) -> Vector3:
	return Vector3(
		(point.x - 0.5) * bbox_width * skin_pixel_size,
		(1.0 - point.y) * bbox_height * skin_pixel_size,
		0.0
	)


func _add_bone_global(bone_name: String, parent_name: String, global_position_value: Vector3) -> void:
	var index: int = skeleton.add_bone(bone_name)
	bone_indices[bone_name] = index
	bone_global_positions[bone_name] = global_position_value
	var local_position: Vector3 = global_position_value
	if not parent_name.is_empty():
		skeleton.set_bone_parent(index, int(bone_indices[parent_name]))
		local_position -= bone_global_positions[parent_name]
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, local_position))


func _build_original_skin() -> void:
	var parts: Array = rig_data.get("parts", []) as Array
	for part_value: Variant in parts:
		if not (part_value is Dictionary):
			continue
		var part: Dictionary = part_value as Dictionary
		var bone_name: String = str(part.get("bone", "chest"))
		var path: String = str(part.get("texture", ""))
		if path.is_empty():
			continue
		var sprite: Sprite3D = Sprite3D.new()
		sprite.name = str(part.get("name", "SkinPart")).capitalize().replace("_", "")
		sprite.texture = _shared_texture(path)
		sprite.pixel_size = skin_pixel_size
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		sprite.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		sprite.shaded = false
		sprite.double_sided = true
		sprite.no_depth_test = false
		sprite.fixed_size = false
		sprite.custom_aabb = SAFE_AABB
		sprite.render_priority = int(part.get("priority", 1))
		var position_values: Array = part.get("position", [0.0, 1.0, 0.0]) as Array
		var target_position: Vector3 = Vector3(
			float(position_values[0]), float(position_values[1]), float(position_values[2])
		)
		var rest_position: Vector3 = bone_global_positions.get(bone_name, Vector3.ZERO)
		sprite.position = target_position - rest_position
		_attachment(bone_name).add_child(sprite)
		skin_sprites.append(sprite)


func _build_weapon_overlay() -> void:
	# These original skins already include their weapon in the artwork. Adding an
	# extra sword made it float beside the wrist, so they keep the integral blade.
	if slug in ["haurol", "toreadore", "sarbelas", "sylpheed", "sharking"]:
		return
	var path: String = "res://assets/atac_views/sword_level_1.png"
	var pixel_size: float = 0.00116
	var local_position := Vector3(0.015, 0.265, 0.012)
	var local_rotation: float = -12.0
	if slug == "solarus":
		path = "res://assets/atac_views/weapons/black_red_sword.png"
		pixel_size = 0.00104
		local_position = Vector3(0.008, 0.235, 0.012)
		local_rotation = -10.0
	elif slug == "einlager":
		path = "res://assets/atac_views/weapons/einlager_sword.png"
		local_position = Vector3(0.010, 0.250, 0.012)
		local_rotation = -11.0
	elif slug == "korbelan":
		local_position = Vector3(0.012, 0.278, 0.012)
		local_rotation = -8.0
	var weapon: Sprite3D = Sprite3D.new()
	weapon.name = "RiggedWeapon"
	weapon.texture = _shared_texture(path)
	weapon.pixel_size = pixel_size
	weapon.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	weapon.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	weapon.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	weapon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	weapon.shaded = false
	weapon.double_sided = true
	weapon.custom_aabb = SAFE_AABB
	weapon.render_priority = 10
	# The grip of the vertical sword texture is below its centre. Positive local Y
	# aligns that grip with hand_r, so the blade follows every skeletal animation.
	weapon.position = local_position
	weapon.rotation_degrees.z = local_rotation
	_attachment("hand_r").add_child(weapon)
	skin_sprites.append(weapon)


func _shared_texture(path: String) -> Texture2D:
	if TEXTURE_CACHE.has(path):
		return TEXTURE_CACHE[path] as Texture2D
	var texture: Texture2D = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	TEXTURE_CACHE[path] = texture
	return texture


func _attachment(bone_name: String) -> BoneAttachment3D:
	if attachments.has(bone_name):
		return attachments[bone_name] as BoneAttachment3D
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "%sAttachment" % bone_name.capitalize()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	attachments[bone_name] = attachment
	return attachment


func _add_contact_shadow() -> void:
	var shadow: MeshInstance3D = MeshInstance3D.new()
	shadow.name = "ContactShadow"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.40
	disc.bottom_radius = 0.47
	disc.height = 0.012
	disc.radial_segments = 16
	shadow.mesh = disc
	shadow.position = Vector3(0, 0.014, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.015, 0.02, 0.025, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = material
	add_child(shadow)


func _process(_delta: float) -> void:
	if model_root == null or not is_inside_tree():
		return
	_sync_camera_facing()
	_sync_compatibility_pivots()


func _sync_camera_facing() -> void:
	model_root.global_position = global_position + Vector3(0, pose_offset_y, 0)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var direction: Vector3 = camera.global_position - global_position
		if Vector2(direction.x, direction.z).length_squared() > 0.0001:
			model_root.rotation.y = atan2(direction.x, direction.z)
	# A top-level visual does not inherit the tactical unit's scale, so mirror it
	# explicitly.  This also preserves hit squash and death shrink animations.
	var inherited_scale: Vector3 = global_transform.basis.get_scale()
	model_root.scale = inherited_scale * pose_scale


func _sync_compatibility_pivots() -> void:
	if skeleton == null:
		return
	var arm_r: Quaternion = Quaternion.from_euler(right_arm_pivot.rotation)
	var arm_l: Quaternion = Quaternion.from_euler(left_arm_pivot.rotation)
	var leg_r: Quaternion = Quaternion.from_euler(right_leg_pivot.rotation)
	var leg_l: Quaternion = Quaternion.from_euler(left_leg_pivot.rotation)
	_set_bone_rotation("upper_arm_r", arm_r * _pose_rotation("upper_arm_r"))
	_set_bone_rotation("upper_arm_l", arm_l * _pose_rotation("upper_arm_l"))
	_set_bone_rotation("upper_leg_r", leg_r * _pose_rotation("upper_leg_r"))
	_set_bone_rotation("upper_leg_l", leg_l * _pose_rotation("upper_leg_l"))
	_set_bone_rotation("hand_r", Quaternion.from_euler(weapon_pivot.rotation) * _pose_rotation("hand_r"))
	_set_bone_rotation("hand_l", Quaternion.from_euler(second_weapon_pivot.rotation) * _pose_rotation("hand_l"))
	for bone_name: String in [
		"pelvis", "spine", "chest", "head", "lower_arm_r", "lower_arm_l",
		"lower_leg_r", "lower_leg_l", "foot_r", "foot_l", "rear_body",
		"rear_leg_r", "rear_leg_l"
	]:
		_set_bone_rotation(bone_name, _pose_rotation(bone_name))


func _attack_curve(start_angle: float, strike_angle: float, recover_angle: float, progress: float) -> float:
	if progress < 0.30:
		return lerpf(0.0, start_angle, smoothstep(0.0, 0.30, progress))
	if progress < 0.70:
		return lerpf(start_angle, strike_angle, smoothstep(0.30, 0.70, progress))
	return lerpf(strike_angle, recover_angle, smoothstep(0.70, 1.0, progress))


func _pose_rotation(bone_name: String) -> Quaternion:
	var p: float = clampf(pose_progress, 0.0, 1.0)
	var wave: float = sin(p * PI)
	if walk_intensity > 0.001:
		var gait: float = sin(walk_phase * TAU) * walk_intensity
		match bone_name:
			"upper_leg_l": return Quaternion(Vector3.FORWARD, gait * 0.20)
			"upper_leg_r": return Quaternion(Vector3.FORWARD, -gait * 0.20)
			"lower_leg_l": return Quaternion(Vector3.FORWARD, maxf(0.0, -gait) * 0.18)
			"lower_leg_r": return Quaternion(Vector3.FORWARD, maxf(0.0, gait) * 0.18)
			"upper_arm_l": return Quaternion(Vector3.FORWARD, -gait * 0.14)
			"upper_arm_r": return Quaternion(Vector3.FORWARD, gait * 0.14)
			"spine": return Quaternion(Vector3.FORWARD, gait * 0.025)
			_:
				return Quaternion.IDENTITY
	match pose_kind:
		"slash":
			if bone_name == "pelvis": return Quaternion(Vector3.FORWARD, _attack_curve(0.12, -0.12, 0.0, p))
			if bone_name == "chest": return Quaternion(Vector3.FORWARD, _attack_curve(-0.20, 0.28, 0.0, p))
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, _attack_curve(-1.25, 1.05, 0.0, p))
			if bone_name == "lower_arm_r": return Quaternion(Vector3.FORWARD, _attack_curve(-0.42, 0.52, 0.0, p))
			if bone_name == "hand_r": return Quaternion(Vector3.FORWARD, _attack_curve(-0.25, 0.32, 0.0, p))
			if bone_name == "upper_leg_l": return Quaternion(Vector3.FORWARD, 0.10 * wave)
			if bone_name == "upper_leg_r": return Quaternion(Vector3.FORWARD, -0.12 * wave)
		"strong_slash":
			if bone_name == "chest": return Quaternion(Vector3.FORWARD, _attack_curve(-0.34, 0.46, 0.0, p))
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, _attack_curve(-1.58, 1.30, 0.0, p))
			if bone_name == "lower_arm_r": return Quaternion(Vector3.FORWARD, _attack_curve(-0.58, 0.66, 0.0, p))
		"lunge":
			if bone_name == "pelvis": return Quaternion(Vector3.FORWARD, -0.10 * wave)
			if bone_name == "chest": return Quaternion(Vector3.FORWARD, -0.18 * wave)
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, _attack_curve(-0.30, -1.13, 0.0, p))
			if bone_name == "lower_arm_r": return Quaternion(Vector3.FORWARD, _attack_curve(-0.18, -0.08, 0.0, p))
			if bone_name == "hand_r": return Quaternion(Vector3.FORWARD, _attack_curve(0.18, 0.0, 0.0, p))
			if bone_name == "upper_leg_l": return Quaternion(Vector3.FORWARD, 0.26 * wave)
			if bone_name == "upper_leg_r": return Quaternion(Vector3.FORWARD, -0.34 * wave)
			if bone_name == "lower_leg_r": return Quaternion(Vector3.FORWARD, 0.20 * wave)
		"long_lunge", "slide":
			if bone_name == "pelvis": return Quaternion(Vector3.FORWARD, -0.16 * wave)
			if bone_name == "chest": return Quaternion(Vector3.FORWARD, -0.30 * wave)
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, _attack_curve(-0.44, -1.44, 0.0, p))
			if bone_name == "lower_arm_r": return Quaternion(Vector3.FORWARD, _attack_curve(-0.26, -0.03, 0.0, p))
			if bone_name == "hand_r": return Quaternion(Vector3.FORWARD, _attack_curve(0.22, 0.0, 0.0, p))
			if bone_name == "upper_leg_l": return Quaternion(Vector3.FORWARD, 0.42 * wave)
			if bone_name == "upper_leg_r": return Quaternion(Vector3.FORWARD, -0.48 * wave)
			if bone_name == "lower_leg_r": return Quaternion(Vector3.FORWARD, 0.28 * wave)
		"shoulder_bash":
			if bone_name == "chest": return Quaternion(Vector3.FORWARD, -0.30 * wave)
			if bone_name == "upper_arm_l": return Quaternion(Vector3.FORWARD, 0.42 * wave)
		"tornado", "desert_whirl", "desert_storm", "sticky_sandstorm":
			if bone_name == "chest": return Quaternion(Vector3.FORWARD, sin(p * TAU) * 0.20)
			if bone_name == "upper_arm_l": return Quaternion(Vector3.FORWARD, -0.55 * wave)
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, 0.55 * wave)
		"earthquake":
			if bone_name in ["upper_leg_l", "upper_leg_r"]: return Quaternion(Vector3.FORWARD, 0.28 * wave)
			if bone_name == "chest": return Quaternion(Vector3.FORWARD, 0.18 * wave)
		"bright_bomb", "ball_lightning", "ice_rain", "ultrasound", "quicksand", "healing_ban":
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, -0.92 * wave)
			if bone_name == "upper_arm_l": return Quaternion(Vector3.FORWARD, 0.32 * wave)
			if bone_name == "chest": return Quaternion(Vector3.FORWARD, -0.10 * wave)
		"hit":
			if bone_name == "chest": return Quaternion(Vector3.FORWARD, 0.30 * sin(smoothstep(0.10, 0.80, p) * PI))
			if bone_name in ["upper_arm_l", "upper_arm_r"]: return Quaternion(Vector3.FORWARD, 0.25 * wave)
		_:
			pass
	return Quaternion.IDENTITY


func _set_bone_rotation(bone_name: String, rotation_value: Quaternion) -> void:
	if bone_indices.has(bone_name):
		skeleton.set_bone_pose_rotation(int(bone_indices[bone_name]), rotation_value)


func set_walk_pose(phase_value: float, intensity: float = 1.0) -> void:
	walk_phase = phase_value
	walk_intensity = clampf(intensity, 0.0, 1.0)
	pose_kind = "idle"
	pose_progress = 0.0
	pose_offset_y = absf(sin(phase_value * PI)) * 0.035 * walk_intensity


func set_combat_pose(kind: String, progress: float) -> void:
	walk_intensity = 0.0
	pose_kind = kind
	pose_progress = clampf(progress, 0.0, 1.0)
	var wave: float = sin(pose_progress * PI)
	pose_scale = Vector3(1.0 + wave * 0.025, 1.0 - wave * 0.012, 1.0)
	if kind in ["desert_whirl", "desert_storm", "sticky_sandstorm", "tornado"]:
		pose_offset_y = 0.06 * wave
	else:
		pose_offset_y = 0.025 * wave


func reset_pose() -> void:
	pose_kind = "idle"
	pose_progress = 0.0
	walk_intensity = 0.0
	walk_phase = 0.0
	pose_scale = Vector3.ONE
	pose_offset_y = 0.0
	if model_root != null:
		# During factory configuration neither this node nor ModelRoot is in the
		# SceneTree yet. Accessing global transforms there produces errors in Godot.
		if is_inside_tree() and model_root.is_inside_tree():
			model_root.global_position = global_position
		else:
			model_root.position = Vector3.ZERO
		model_root.rotation.x = 0.0
		model_root.rotation.z = 0.0
	right_arm_pivot.rotation = Vector3.ZERO
	left_arm_pivot.rotation = Vector3.ZERO
	right_leg_pivot.rotation = Vector3.ZERO
	left_leg_pivot.rotation = Vector3.ZERO
	weapon_pivot.rotation = Vector3.ZERO
	second_weapon_pivot.rotation = Vector3.ZERO
	if skeleton != null:
		skeleton.reset_bone_poses()


func set_arena_facing(_is_attacker: bool) -> void:
	# Kept for compatibility; the tactical skin always faces the active camera.
	pass


func flash(color: Color, duration: float = 0.15) -> void:
	var originals: Array[Color] = []
	for sprite: Sprite3D in skin_sprites:
		originals.append(sprite.modulate)
		sprite.modulate = Color(color.r, color.g, color.b, maxf(color.a, 0.88))
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		for index: int in range(skin_sprites.size()):
			var sprite: Sprite3D = skin_sprites[index]
			if is_instance_valid(sprite):
				sprite.modulate = originals[index]
	)
