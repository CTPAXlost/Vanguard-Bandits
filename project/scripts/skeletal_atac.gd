class_name SkeletalAtac
extends Node3D

# Version 1.7 tactical renderer.
# Every ATAC uses a real Skeleton3D with articulated armour segments.  The
# armour is attached to bones instead of being a camera-facing sheet, so it is
# complete and readable from every camera angle.  Meshes and materials are
# shared between units to keep memory and draw preparation under control.

const SUPPORTED_SLUGS: Array[String] = [
	"alba", "barbatos", "barazaph", "vedocorban", "cador", "solarus",
	"sarbelas", "einlager", "eigol", "amphisia", "haurol", "toreadore",
	"serata", "glaive",
]
const SAFE_AABB: AABB = AABB(Vector3(-1.8, -0.35, -1.8), Vector3(3.6, 3.8, 3.6))

static var MESH_CACHE: Dictionary = {}
static var MATERIAL_CACHE: Dictionary = {}

var slug: String = "alba"
var model_root: Node3D
var skeleton: Skeleton3D
var bone_indices: Dictionary = {}
var attachments: Dictionary = {}
var mesh_instances: Array[MeshInstance3D] = []
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
var base_model_scale: Vector3 = Vector3.ONE


static func supports(model_slug: String) -> bool:
	return SUPPORTED_SLUGS.has(model_slug.to_lower())


func configure(model_slug: String) -> void:
	slug = model_slug.to_lower()
	if not SUPPORTED_SLUGS.has(slug):
		slug = "alba"
	name = "%s_SkeletalRig" % slug.capitalize()
	set_meta("atac_slug", slug)
	set_meta("real_skeleton", true)
	set_meta("rig_status", "procedural_skeleton_v17")
	set_meta("reference_revision", "campaign_v17")

	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	add_child(model_root)

	# Compatibility pivots preserve all existing combat-animation calls while
	# the rotations are copied onto real bones in _process().
	right_arm_pivot = Node3D.new()
	right_arm_pivot.name = "RightArmPivot"
	model_root.add_child(right_arm_pivot)
	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	right_arm_pivot.add_child(weapon_pivot)
	left_arm_pivot = Node3D.new()
	left_arm_pivot.name = "LeftArmPivot"
	model_root.add_child(left_arm_pivot)
	second_weapon_pivot = Node3D.new()
	second_weapon_pivot.name = "SecondWeaponPivot"
	left_arm_pivot.add_child(second_weapon_pivot)
	right_leg_pivot = Node3D.new()
	right_leg_pivot.name = "RightLegPivot"
	model_root.add_child(right_leg_pivot)
	left_leg_pivot = Node3D.new()
	left_leg_pivot.name = "LeftLegPivot"
	model_root.add_child(left_leg_pivot)

	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	model_root.add_child(skeleton)
	_build_skeleton()
	_build_armour()
	_add_contact_shadow()

	var size_factor: float = _body_scale()
	base_model_scale = Vector3.ONE * size_factor
	model_root.scale = base_model_scale
	reset_pose()
	set_process(true)


func _build_skeleton() -> void:
	_add_bone("root", "", Vector3.ZERO)
	_add_bone("pelvis", "root", Vector3(0, 0.86, 0))
	_add_bone("spine", "pelvis", Vector3(0, 0.34, 0))
	_add_bone("chest", "spine", Vector3(0, 0.36, 0))
	_add_bone("neck", "chest", Vector3(0, 0.31, 0))
	_add_bone("head", "neck", Vector3(0, 0.17, 0))
	_add_bone("shoulder_l", "chest", Vector3(-0.34, 0.22, 0))
	_add_bone("upper_arm_l", "shoulder_l", Vector3(-0.18, -0.03, 0))
	_add_bone("lower_arm_l", "upper_arm_l", Vector3(-0.34, 0, 0))
	_add_bone("hand_l", "lower_arm_l", Vector3(-0.30, 0, 0))
	_add_bone("shoulder_r", "chest", Vector3(0.34, 0.22, 0))
	_add_bone("upper_arm_r", "shoulder_r", Vector3(0.18, -0.03, 0))
	_add_bone("lower_arm_r", "upper_arm_r", Vector3(0.34, 0, 0))
	_add_bone("hand_r", "lower_arm_r", Vector3(0.30, 0, 0))
	_add_bone("upper_leg_l", "pelvis", Vector3(-0.20, -0.18, 0))
	_add_bone("lower_leg_l", "upper_leg_l", Vector3(0, -0.47, 0))
	_add_bone("foot_l", "lower_leg_l", Vector3(0, -0.46, -0.03))
	_add_bone("upper_leg_r", "pelvis", Vector3(0.20, -0.18, 0))
	_add_bone("lower_leg_r", "upper_leg_r", Vector3(0, -0.47, 0))
	_add_bone("foot_r", "lower_leg_r", Vector3(0, -0.46, -0.03))
	_add_bone("rear_body", "pelvis", Vector3(0, -0.02, 0.43))
	_add_bone("rear_leg_l", "rear_body", Vector3(-0.25, -0.27, 0.34))
	_add_bone("rear_foot_l", "rear_leg_l", Vector3(0, -0.62, 0))
	_add_bone("rear_leg_r", "rear_body", Vector3(0.25, -0.27, 0.34))
	_add_bone("rear_foot_r", "rear_leg_r", Vector3(0, -0.62, 0))


func _add_bone(bone_name: String, parent_name: String, rest_position: Vector3) -> void:
	var index: int = skeleton.add_bone(bone_name)
	bone_indices[bone_name] = index
	if not parent_name.is_empty():
		skeleton.set_bone_parent(index, int(bone_indices[parent_name]))
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, rest_position))


func _build_armour() -> void:
	var palette: Dictionary = _palette()
	var primary: StandardMaterial3D = _shared_material("primary", palette["primary"])
	var secondary: StandardMaterial3D = _shared_material("secondary", palette["secondary"])
	var trim: StandardMaterial3D = _shared_material("trim", palette["trim"])
	var inner: StandardMaterial3D = _shared_material("inner", palette["inner"])
	var glow: StandardMaterial3D = _shared_material("glow", palette["glow"], true)
	var bulky: float = 1.12 if slug in ["barazaph", "eigol", "cador", "toreadore"] else 1.0
	var slender: float = 0.90 if slug in ["amphisia", "haurol", "serata"] else 1.0

	# Core chassis.
	_add_box("pelvis", "PelvisCore", Vector3(0.55 * bulky, 0.30, 0.34), primary, Vector3(0, -0.05, 0))
	_add_box("spine", "Abdomen", Vector3(0.38 * slender, 0.42, 0.28), inner, Vector3(0, 0.16, 0))
	_add_box("chest", "ChestCore", Vector3(0.76 * bulky, 0.48, 0.38), primary, Vector3(0, 0.05, 0))
	_add_box("chest", "ChestPlate", Vector3(0.58 * bulky, 0.30, 0.10), secondary, Vector3(0, 0.04, -0.23), Vector3(8, 0, 0))
	_add_box("chest", "ChestTrim", Vector3(0.24, 0.10, 0.08), trim, Vector3(0, 0.06, -0.30))
	_add_box("head", "Helmet", Vector3(0.31, 0.35, 0.31), secondary, Vector3(0, 0.13, 0))
	_add_box("head", "FaceVisor", Vector3(0.23, 0.07, 0.035), glow, Vector3(0, 0.13, -0.18), Vector3(-5, 0, 0))
	_add_box("head", "Crest", Vector3(0.08, 0.28, 0.16), trim, Vector3(0, 0.40, 0.02), Vector3(0, 0, 8))

	# Shoulders and articulated arms.
	for side: String in ["l", "r"]:
		var sign_value: float = -1.0 if side == "l" else 1.0
		_add_box("shoulder_%s" % side, "Shoulder_%s" % side, Vector3(0.34, 0.25, 0.43), secondary, Vector3(sign_value * 0.09, 0, 0), Vector3(0, 0, sign_value * -10.0))
		_add_box("upper_arm_%s" % side, "UpperArm_%s" % side, Vector3(0.38, 0.19, 0.22), inner, Vector3(sign_value * 0.18, 0, 0))
		_add_box("upper_arm_%s" % side, "UpperArmPlate_%s" % side, Vector3(0.26, 0.24, 0.29), primary, Vector3(sign_value * 0.18, 0, -0.01))
		_add_box("lower_arm_%s" % side, "Forearm_%s" % side, Vector3(0.34, 0.18, 0.21), inner, Vector3(sign_value * 0.16, 0, 0))
		_add_box("lower_arm_%s" % side, "ForearmGuard_%s" % side, Vector3(0.24, 0.24, 0.31), secondary, Vector3(sign_value * 0.16, 0, -0.01))
		_add_box("hand_%s" % side, "Hand_%s" % side, Vector3(0.18, 0.17, 0.19), inner, Vector3(sign_value * 0.08, 0, 0))

	# Articulated legs, large enough to read at tactical zoom.
	for side: String in ["l", "r"]:
		var sign_value: float = -1.0 if side == "l" else 1.0
		_add_box("upper_leg_%s" % side, "Thigh_%s" % side, Vector3(0.29, 0.48, 0.32), inner, Vector3(0, -0.23, 0))
		_add_box("upper_leg_%s" % side, "ThighPlate_%s" % side, Vector3(0.36, 0.39, 0.37), primary, Vector3(0, -0.21, -0.01), Vector3(0, 0, sign_value * 3.0))
		_add_box("lower_leg_%s" % side, "Shin_%s" % side, Vector3(0.28, 0.48, 0.30), inner, Vector3(0, -0.23, 0))
		_add_box("lower_leg_%s" % side, "ShinGuard_%s" % side, Vector3(0.36, 0.40, 0.36), secondary, Vector3(0, -0.21, -0.02))
		_add_box("foot_%s" % side, "Foot_%s" % side, Vector3(0.36, 0.19, 0.52), primary, Vector3(0, -0.08, -0.12))
		_add_box("foot_%s" % side, "ToeTrim_%s" % side, Vector3(0.24, 0.08, 0.16), trim, Vector3(0, -0.08, -0.40))

	# Waist armour and silhouette plates.
	_add_box("pelvis", "WaistFront", Vector3(0.34, 0.48, 0.10), secondary, Vector3(0, -0.25, -0.28), Vector3(10, 0, 0))
	_add_box("pelvis", "WaistLeft", Vector3(0.16, 0.44, 0.30), primary, Vector3(-0.34, -0.20, 0), Vector3(0, 0, -8))
	_add_box("pelvis", "WaistRight", Vector3(0.16, 0.44, 0.30), primary, Vector3(0.34, -0.20, 0), Vector3(0, 0, 8))

	_build_weapon(primary, secondary, trim, glow)
	_build_signature_parts(primary, secondary, trim, glow)
	if slug == "toreadore":
		_build_centaur_rear(primary, secondary, inner, trim)


func _build_weapon(primary: StandardMaterial3D, secondary: StandardMaterial3D, trim: StandardMaterial3D, glow: StandardMaterial3D) -> void:
	if slug in ["haurol", "toreadore"]:
		_add_cylinder("hand_r", "SpearShaft", 0.035, 1.65, trim, Vector3(0.42, 0, 0), Vector3(0, 0, 90))
		_add_box("hand_r", "SpearHead", Vector3(0.34, 0.09, 0.12), glow, Vector3(1.22, 0, 0), Vector3(0, 0, -12))
	elif slug == "sarbelas":
		_add_blade("hand_r", "RightBlade", secondary, glow, 1.00, 1.0)
		_add_blade("hand_l", "LeftBlade", secondary, glow, 1.00, -1.0)
	else:
		var length: float = 1.12 if slug in ["barazaph", "eigol", "einlager"] else 0.94
		_add_blade("hand_r", "PrimaryBlade", secondary, glow, length, 1.0)
	if slug in ["alba", "glaive", "einlager", "amphisia"]:
		_add_box("lower_arm_l", "Shield", Vector3(0.10, 0.56, 0.46), primary, Vector3(-0.17, 0, -0.22), Vector3(0, 12, 0))
		_add_box("lower_arm_l", "ShieldTrim", Vector3(0.035, 0.38, 0.30), trim, Vector3(-0.23, 0, -0.24))


func _add_blade(bone_name: String, node_name: String, metal: StandardMaterial3D, glow: StandardMaterial3D, length: float, direction_sign: float) -> void:
	_add_cylinder(bone_name, "%sGrip" % node_name, 0.045, 0.28, metal, Vector3(direction_sign * 0.18, 0, 0), Vector3(0, 0, 90))
	_add_box(bone_name, node_name, Vector3(length, 0.09, 0.08), glow, Vector3(direction_sign * (0.30 + length * 0.50), 0, 0), Vector3(0, 0, direction_sign * -4.0))


func _build_signature_parts(primary: StandardMaterial3D, secondary: StandardMaterial3D, trim: StandardMaterial3D, glow: StandardMaterial3D) -> void:
	# Distinct silhouette accents keep every campaign ATAC recognizable even at
	# tactical zoom while all pieces remain attached to the common animation rig.
	match slug:
		"barbatos":
			_add_box("shoulder_l", "ImperialWingL", Vector3(0.42, 0.12, 0.54), primary, Vector3(-0.12, 0.10, 0.10), Vector3(0, 16, -18))
			_add_box("shoulder_r", "ImperialWingR", Vector3(0.42, 0.12, 0.54), primary, Vector3(0.12, 0.10, 0.10), Vector3(0, -16, 18))
			_add_box("chest", "ImperialCore", Vector3(0.18, 0.18, 0.08), glow, Vector3(0, 0.04, -0.31))
		"barazaph":
			for offset: float in [-0.18, 0.0, 0.18]:
				_add_box("head", "CrownSpike_%s" % str(offset), Vector3(0.08, 0.36, 0.10), primary, Vector3(offset, 0.43, 0.03), Vector3(0, 0, offset * 55.0))
			_add_box("chest", "HeavyBreastplate", Vector3(0.88, 0.22, 0.18), secondary, Vector3(0, 0.10, -0.23))
		"vedocorban":
			_add_box("shoulder_l", "VioletMantleL", Vector3(0.25, 0.52, 0.55), primary, Vector3(-0.14, -0.04, 0.02), Vector3(0, 0, -12))
			_add_box("shoulder_r", "VioletMantleR", Vector3(0.25, 0.52, 0.55), primary, Vector3(0.14, -0.04, 0.02), Vector3(0, 0, 12))
			_add_box("pelvis", "VioletSkirt", Vector3(0.62, 0.48, 0.12), primary, Vector3(0, -0.30, -0.18))
		"cador":
			_add_box("head", "HornL", Vector3(0.07, 0.42, 0.09), trim, Vector3(-0.18, 0.34, 0.02), Vector3(0, 0, -24))
			_add_box("head", "HornR", Vector3(0.07, 0.42, 0.09), trim, Vector3(0.18, 0.34, 0.02), Vector3(0, 0, 24))
			_add_box("chest", "EmeraldCore", Vector3(0.28, 0.15, 0.08), glow, Vector3(0, 0.02, -0.31))
		"solarus":
			_add_box("chest", "SolarBreastplate", Vector3(0.88, 0.26, 0.16), secondary, Vector3(0, 0.12, -0.25))
			_add_box("shoulder_l", "SolarFinL", Vector3(0.16, 0.50, 0.36), trim, Vector3(-0.18, 0.18, 0.08), Vector3(0, 0, -20))
			_add_box("shoulder_r", "SolarFinR", Vector3(0.16, 0.50, 0.36), trim, Vector3(0.18, 0.18, 0.08), Vector3(0, 0, 20))
		"sarbelas":
			_add_box("pelvis", "BladeSkirtL", Vector3(0.15, 0.64, 0.18), primary, Vector3(-0.32, -0.30, 0), Vector3(0, 0, -10))
			_add_box("pelvis", "BladeSkirtR", Vector3(0.15, 0.64, 0.18), primary, Vector3(0.32, -0.30, 0), Vector3(0, 0, 10))
			_add_box("head", "DuelistCrest", Vector3(0.07, 0.44, 0.10), glow, Vector3(0, 0.42, 0))
		"einlager":
			_add_box("shoulder_l", "RoyalShieldL", Vector3(0.12, 0.48, 0.42), secondary, Vector3(-0.20, 0, -0.18))
			_add_box("shoulder_r", "RoyalShieldR", Vector3(0.12, 0.48, 0.42), secondary, Vector3(0.20, 0, -0.18))
			_add_box("chest", "RoyalMark", Vector3(0.12, 0.28, 0.07), trim, Vector3(0, 0.02, -0.32))
		"eigol":
			_add_box("pelvis", "DesertCoatL", Vector3(0.24, 0.70, 0.18), primary, Vector3(-0.31, -0.36, 0.04), Vector3(0, 0, -7))
			_add_box("pelvis", "DesertCoatR", Vector3(0.24, 0.70, 0.18), primary, Vector3(0.31, -0.36, 0.04), Vector3(0, 0, 7))
			_add_box("head", "DesertHelm", Vector3(0.36, 0.18, 0.42), secondary, Vector3(0, 0.23, 0.06), Vector3(-12, 0, 0))
		"amphisia":
			_add_box("shoulder_l", "AegisWingL", Vector3(0.38, 0.14, 0.50), trim, Vector3(-0.12, 0.11, 0.04), Vector3(0, 12, -18))
			_add_box("shoulder_r", "AegisWingR", Vector3(0.38, 0.14, 0.50), trim, Vector3(0.12, 0.11, 0.04), Vector3(0, -12, 18))
			_add_box("chest", "AegisGem", Vector3(0.16, 0.16, 0.07), glow, Vector3(0, 0.04, -0.32), Vector3(0, 0, 45))
		"haurol":
			_add_box("head", "LancerCrest", Vector3(0.09, 0.52, 0.12), primary, Vector3(0, 0.48, 0.03), Vector3(0, 0, -7))
			_add_box("shoulder_l", "LancerGuardL", Vector3(0.28, 0.20, 0.58), secondary, Vector3(-0.10, 0.06, 0.06))
			_add_box("shoulder_r", "LancerGuardR", Vector3(0.28, 0.20, 0.58), secondary, Vector3(0.10, 0.06, 0.06))
		"serata":
			for offset: float in [-0.17, 0.0, 0.17]:
				_add_box("head", "SerataCrown_%s" % str(offset), Vector3(0.09, 0.42, 0.11), primary, Vector3(offset, 0.43, 0.02), Vector3(0, 0, offset * 70.0))
			_add_box("chest", "SerataCore", Vector3(0.28, 0.18, 0.08), glow, Vector3(0, 0.03, -0.31))
		"glaive":
			_add_box("shoulder_l", "KingdomPlateL", Vector3(0.34, 0.40, 0.42), primary, Vector3(-0.09, 0, 0))
			_add_box("shoulder_r", "KingdomPlateR", Vector3(0.34, 0.40, 0.42), primary, Vector3(0.09, 0, 0))
			_add_box("chest", "KingdomCrossV", Vector3(0.08, 0.34, 0.07), secondary, Vector3(0, 0.02, -0.32))
			_add_box("chest", "KingdomCrossH", Vector3(0.30, 0.08, 0.07), secondary, Vector3(0, 0.06, -0.32))
		_:
			pass


func _build_centaur_rear(primary: StandardMaterial3D, secondary: StandardMaterial3D, inner: StandardMaterial3D, trim: StandardMaterial3D) -> void:
	_add_box("rear_body", "RearBody", Vector3(0.68, 0.45, 0.92), primary, Vector3(0, 0, 0.35))
	_add_box("rear_body", "RearArmour", Vector3(0.58, 0.25, 0.75), secondary, Vector3(0, 0.20, 0.35))
	for side: String in ["l", "r"]:
		_add_box("rear_leg_%s" % side, "RearUpper_%s" % side, Vector3(0.28, 0.62, 0.30), inner, Vector3(0, -0.30, 0))
		_add_box("rear_leg_%s" % side, "RearPlate_%s" % side, Vector3(0.36, 0.50, 0.37), primary, Vector3(0, -0.28, 0))
		_add_box("rear_foot_%s" % side, "RearFoot_%s" % side, Vector3(0.38, 0.22, 0.52), secondary, Vector3(0, -0.10, -0.10))
	_add_box("rear_body", "Tail", Vector3(0.12, 0.12, 0.74), trim, Vector3(0, 0.05, 0.90), Vector3(-18, 0, 0))


func _attachment(bone_name: String) -> BoneAttachment3D:
	if attachments.has(bone_name):
		return attachments[bone_name] as BoneAttachment3D
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "%sAttachment" % bone_name.capitalize()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	attachments[bone_name] = attachment
	return attachment


func _add_box(bone_name: String, node_name: String, size: Vector3, material: Material, local_position: Vector3 = Vector3.ZERO, local_rotation: Vector3 = Vector3.ZERO) -> void:
	var key: String = "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	var mesh: BoxMesh
	if MESH_CACHE.has(key):
		mesh = MESH_CACHE[key] as BoxMesh
	else:
		mesh = BoxMesh.new()
		mesh.size = size
		MESH_CACHE[key] = mesh
	_add_mesh_instance(bone_name, node_name, mesh, material, local_position, local_rotation)


func _add_cylinder(bone_name: String, node_name: String, radius: float, height: float, material: Material, local_position: Vector3 = Vector3.ZERO, local_rotation: Vector3 = Vector3.ZERO) -> void:
	var key: String = "cyl_%.3f_%.3f" % [radius, height]
	var mesh: CylinderMesh
	if MESH_CACHE.has(key):
		mesh = MESH_CACHE[key] as CylinderMesh
	else:
		mesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 8
		MESH_CACHE[key] = mesh
	_add_mesh_instance(bone_name, node_name, mesh, material, local_position, local_rotation)


func _add_mesh_instance(bone_name: String, node_name: String, mesh: Mesh, material: Material, local_position: Vector3, local_rotation: Vector3) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.rotation_degrees = local_rotation
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.custom_aabb = SAFE_AABB
	_attachment(bone_name).add_child(instance)
	mesh_instances.append(instance)


func _add_contact_shadow() -> void:
	var shadow: MeshInstance3D = MeshInstance3D.new()
	shadow.name = "ContactShadow"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.43
	disc.bottom_radius = 0.50
	disc.height = 0.015
	disc.radial_segments = 16
	shadow.mesh = disc
	shadow.position = Vector3(0, 0.018, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.015, 0.02, 0.025, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = material
	add_child(shadow)


func _shared_material(role: String, color: Color, emissive: bool = false) -> StandardMaterial3D:
	var key: String = "%s_%s_%s" % [slug, role, str(emissive)]
	if MATERIAL_CACHE.has(key):
		return MATERIAL_CACHE[key] as StandardMaterial3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.72 if role != "inner" else 0.32
	material.roughness = 0.24 if role in ["trim", "glow"] else 0.36
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emissive:
		material.emission_enabled = true
		material.emission = color * 2.6
		material.emission_energy_multiplier = 1.25
	MATERIAL_CACHE[key] = material
	return material


func _palette() -> Dictionary:
	var palettes: Dictionary = {
		"alba": {"primary": Color("3559a8"), "secondary": Color("e7edf5"), "trim": Color("d8ab47"), "inner": Color("202b36"), "glow": Color("58d9ff")},
		"barbatos": {"primary": Color("9d2f3d"), "secondary": Color("d8d9dc"), "trim": Color("d1a24b"), "inner": Color("252a31"), "glow": Color("ff6b55")},
		"barazaph": {"primary": Color("e4771f"), "secondary": Color("6b2f65"), "trim": Color("e9d7aa"), "inner": Color("2b2630"), "glow": Color("ffd35a")},
		"vedocorban": {"primary": Color("8d65b3"), "secondary": Color("e2e2e9"), "trim": Color("b5c34a"), "inner": Color("282733"), "glow": Color("cf7fff")},
		"cador": {"primary": Color("3e735b"), "secondary": Color("d1b55f"), "trim": Color("f0e0a8"), "inner": Color("26382f"), "glow": Color("5fffe1")},
		"solarus": {"primary": Color("252833"), "secondary": Color("9c2732"), "trim": Color("e6aa45"), "inner": Color("11151c"), "glow": Color("ff3c46")},
		"sarbelas": {"primary": Color("6e3f8e"), "secondary": Color("c8c8d8"), "trim": Color("bd8fd8"), "inner": Color("20202c"), "glow": Color("bd6cff")},
		"einlager": {"primary": Color("d7aa4d"), "secondary": Color("e7e8eb"), "trim": Color("7e302d"), "inner": Color("2c3035"), "glow": Color("58cfff")},
		"eigol": {"primary": Color("6d4437"), "secondary": Color("d4ad62"), "trim": Color("b73939"), "inner": Color("294449"), "glow": Color("3ce5e3")},
		"amphisia": {"primary": Color("5b3637"), "secondary": Color("d6af62"), "trim": Color("d9c88b"), "inner": Color("29454a"), "glow": Color("40e6ef")},
		"haurol": {"primary": Color("a62f65"), "secondary": Color("c6b5dc"), "trim": Color("d8b044"), "inner": Color("334c3a"), "glow": Color("58ffcf")},
		"toreadore": {"primary": Color("e47b22"), "secondary": Color("6f3b82"), "trim": Color("e5d9b2"), "inner": Color("252833"), "glow": Color("ffd459")},
		"serata": {"primary": Color("d56b23"), "secondary": Color("76512f"), "trim": Color("d9c899"), "inner": Color("303238"), "glow": Color("ffad47")},
		"glaive": {"primary": Color("d5ae59"), "secondary": Color("e7e8eb"), "trim": Color("8d302a"), "inner": Color("2b3036"), "glow": Color("55d5ff")},
	}
	return (palettes.get(slug, palettes["alba"]) as Dictionary).duplicate()


func _body_scale() -> float:
	if slug == "toreadore":
		return 1.05
	if slug in ["cador", "barazaph", "eigol"]:
		return 1.10
	if slug in ["amphisia", "haurol", "serata"]:
		return 0.96
	return 1.0


func _process(_delta: float) -> void:
	_sync_compatibility_pivots()


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
	for bone_name: String in ["spine", "chest", "head", "lower_arm_r", "lower_arm_l", "lower_leg_r", "lower_leg_l", "foot_r", "foot_l", "rear_body", "rear_leg_r", "rear_leg_l"]:
		_set_bone_rotation(bone_name, _pose_rotation(bone_name))


func _pose_rotation(bone_name: String) -> Quaternion:
	var p: float = clampf(pose_progress, 0.0, 1.0)
	var wave: float = sin(p * PI)
	var snap: float = sin(smoothstep(0.18, 0.72, p) * PI)
	if walk_intensity > 0.001:
		var gait: float = sin(walk_phase * TAU) * walk_intensity
		match bone_name:
			"upper_leg_l": return Quaternion(Vector3.RIGHT, gait * 0.55)
			"upper_leg_r": return Quaternion(Vector3.RIGHT, -gait * 0.55)
			"lower_leg_l": return Quaternion(Vector3.RIGHT, maxf(0.0, -gait) * 0.48)
			"lower_leg_r": return Quaternion(Vector3.RIGHT, maxf(0.0, gait) * 0.48)
			"upper_arm_l": return Quaternion(Vector3.RIGHT, -gait * 0.36)
			"upper_arm_r": return Quaternion(Vector3.RIGHT, gait * 0.36)
			"spine": return Quaternion(Vector3.FORWARD, gait * 0.035)
			_:
				return Quaternion.IDENTITY
	match pose_kind:
		"slash":
			if bone_name == "spine": return Quaternion(Vector3.UP, -0.30 * wave) * Quaternion(Vector3.FORWARD, -0.12 * wave)
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, -1.35 + 2.45 * p) * Quaternion(Vector3.UP, 0.38 * wave)
			if bone_name == "lower_arm_r": return Quaternion(Vector3.FORWARD, -0.45 * wave)
		"strong_slash":
			if bone_name == "spine": return Quaternion(Vector3.UP, -0.52 + 1.04 * p) * Quaternion(Vector3.FORWARD, -0.22 * wave)
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, -1.75 + 3.15 * p)
			if bone_name == "lower_arm_r": return Quaternion(Vector3.FORWARD, -0.65 * wave)
		"lunge", "long_lunge", "slide":
			if bone_name == "spine": return Quaternion(Vector3.RIGHT, -0.28 * wave)
			if bone_name == "upper_arm_r": return Quaternion(Vector3.UP, -0.18) * Quaternion(Vector3.FORWARD, -1.35 * wave)
			if bone_name == "lower_arm_r": return Quaternion(Vector3.FORWARD, -0.55 * wave)
			if bone_name == "upper_leg_l": return Quaternion(Vector3.RIGHT, 0.34 * wave)
			if bone_name == "upper_leg_r": return Quaternion(Vector3.RIGHT, -0.44 * wave)
		"shoulder_bash":
			if bone_name == "spine": return Quaternion(Vector3.RIGHT, -0.45 * wave) * Quaternion(Vector3.FORWARD, 0.18 * wave)
			if bone_name == "upper_arm_l": return Quaternion(Vector3.FORWARD, 0.48 * wave)
		"tornado", "desert_whirl", "desert_storm", "sticky_sandstorm":
			if bone_name == "spine": return Quaternion(Vector3.UP, p * TAU * 1.7)
			if bone_name == "upper_arm_l": return Quaternion(Vector3.FORWARD, -0.55 * wave)
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, 0.55 * wave)
		"earthquake":
			if bone_name in ["upper_leg_l", "upper_leg_r"]: return Quaternion(Vector3.RIGHT, 0.42 * wave)
			if bone_name == "spine": return Quaternion(Vector3.RIGHT, 0.30 * wave)
		"bright_bomb", "ball_lightning", "ice_rain", "ultrasound", "quicksand", "healing_ban":
			if bone_name == "upper_arm_r": return Quaternion(Vector3.FORWARD, -0.95 * wave) * Quaternion(Vector3.UP, -0.30 * wave)
			if bone_name == "upper_arm_l": return Quaternion(Vector3.FORWARD, 0.35 * wave)
			if bone_name == "spine": return Quaternion(Vector3.RIGHT, -0.12 * wave)
		"hit":
			if bone_name == "spine": return Quaternion(Vector3.FORWARD, 0.34 * snap) * Quaternion(Vector3.RIGHT, 0.18 * wave)
			if bone_name in ["upper_arm_l", "upper_arm_r"]: return Quaternion(Vector3.RIGHT, 0.38 * wave)
		_:
			pass
	return Quaternion.IDENTITY


func _set_bone_rotation(bone_name: String, rotation_value: Quaternion) -> void:
	if not bone_indices.has(bone_name):
		return
	skeleton.set_bone_pose_rotation(int(bone_indices[bone_name]), rotation_value)


func set_walk_pose(phase_value: float, intensity: float = 1.0) -> void:
	walk_phase = phase_value
	walk_intensity = clampf(intensity, 0.0, 1.0)
	pose_kind = "idle"
	pose_progress = 0.0
	model_root.position.y = absf(sin(phase_value * PI)) * 0.045 * walk_intensity


func set_combat_pose(kind: String, progress: float) -> void:
	walk_intensity = 0.0
	pose_kind = kind
	pose_progress = clampf(progress, 0.0, 1.0)
	var wave: float = sin(pose_progress * PI)
	if kind in ["lunge", "long_lunge", "slide", "shoulder_bash"]:
		model_root.position.z = -0.10 * wave
	elif kind in ["desert_whirl", "desert_storm", "sticky_sandstorm", "tornado"]:
		model_root.position.y = 0.08 * wave
	else:
		model_root.position.y = 0.035 * wave


func reset_pose() -> void:
	pose_kind = "idle"
	pose_progress = 0.0
	walk_intensity = 0.0
	walk_phase = 0.0
	model_root.position = Vector3.ZERO
	model_root.rotation = Vector3.ZERO
	model_root.scale = base_model_scale
	right_arm_pivot.rotation = Vector3.ZERO
	left_arm_pivot.rotation = Vector3.ZERO
	right_leg_pivot.rotation = Vector3.ZERO
	left_leg_pivot.rotation = Vector3.ZERO
	weapon_pivot.rotation = Vector3.ZERO
	second_weapon_pivot.rotation = Vector3.ZERO
	if skeleton != null:
		skeleton.reset_bone_poses()


func set_arena_facing(is_attacker: bool) -> void:
	rotation_degrees = Vector3(0, -90.0 if is_attacker else 90.0, 0)


func flash(color: Color, duration: float = 0.15) -> void:
	var overlay: StandardMaterial3D = StandardMaterial3D.new()
	overlay.albedo_color = color
	overlay.emission_enabled = true
	overlay.emission = color * 3.0
	overlay.emission_energy_multiplier = 1.6
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color.a = 0.72
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mesh_instance: MeshInstance3D in mesh_instances:
		mesh_instance.material_overlay = overlay
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		for mesh_instance: MeshInstance3D in mesh_instances:
			if is_instance_valid(mesh_instance):
				mesh_instance.material_overlay = null
	)
