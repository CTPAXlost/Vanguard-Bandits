class_name RealModelAtac
extends Node3D

const MODEL_SLUGS: Array[String] = ["alba", "serata", "glaive"]
const SAFE_MODEL_AABB: AABB = AABB(Vector3(-2.2, -0.8, -2.2), Vector3(4.4, 4.6, 4.4))

var slug: String = "alba"
var model_root: Node3D
var mesh_instance: MeshInstance3D
var mesh_instances: Array[MeshInstance3D] = []
var right_arm_pivot: Node3D
var left_arm_pivot: Node3D
var weapon_pivot: Node3D
var base_position: Vector3 = Vector3.ZERO
var base_rotation: Vector3 = Vector3.ZERO
var base_scale: Vector3 = Vector3.ONE


static func supports(model_slug: String) -> bool:
	return MODEL_SLUGS.has(model_slug.to_lower())


func configure(model_slug: String) -> void:
	slug = model_slug.to_lower()
	name = "%s_Real3DRig" % slug.capitalize()
	set_meta("atac_slug", slug)
	set_meta("real_3d_model", true)
	set_meta("experimental_3d", true)
	set_meta("reference_revision", "campaign_v15")
	set_meta("rig_status", "optimized_static_mesh_cinematic_pose_rig")

	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	add_child(model_root)

	left_arm_pivot = Node3D.new()
	left_arm_pivot.name = "LeftArmPivot"
	model_root.add_child(left_arm_pivot)
	right_arm_pivot = Node3D.new()
	right_arm_pivot.name = "RightArmPivot"
	model_root.add_child(right_arm_pivot)
	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	right_arm_pivot.add_child(weapon_pivot)

	var optimized_path: String = "res://assets/imported/models/optimized/%s_optimized.glb" % slug
	var packed: PackedScene = ResourceLoader.load(
		optimized_path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE
	) as PackedScene
	if packed != null:
		var imported_root: Node = packed.instantiate()
		imported_root.name = "OptimizedImportedModel"
		model_root.add_child(imported_root)
		_collect_meshes(imported_root)
	else:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "ImportedStaticMeshFallback"
		var mesh_path: String = "res://assets/imported/models/%s/%s.obj" % [slug, slug]
		mesh_instance.mesh = ResourceLoader.load(
			mesh_path, "Mesh", ResourceLoader.CACHE_MODE_REUSE
		) as Mesh
		model_root.add_child(mesh_instance)
		mesh_instances.append(mesh_instance)
	if not mesh_instances.is_empty():
		mesh_instance = mesh_instances[0]
	for mesh_node: MeshInstance3D in mesh_instances:
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_node.visibility_range_end = 0.0
		mesh_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mesh_node.custom_aabb = SAFE_MODEL_AABB
	_add_contact_shadow()

	# Imported reconstruction models are normalized to roughly two metres.
	model_root.rotation_degrees = Vector3(0, 180, 0)
	model_root.scale = Vector3.ONE * 1.22
	base_position = model_root.position
	base_rotation = model_root.rotation
	base_scale = model_root.scale


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		mesh_instances.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child)


func _add_contact_shadow() -> void:
	var shadow: MeshInstance3D = MeshInstance3D.new()
	shadow.name = "ContactShadow"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.38
	disc.bottom_radius = 0.44
	disc.height = 0.018
	disc.radial_segments = 20
	shadow.mesh = disc
	shadow.position = Vector3(0, 0.018, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.025, 0.03, 0.04, 0.20)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	add_child(shadow)


func set_arena_facing(is_attacker: bool) -> void:
	# Exact inward yaw: left combatant looks to +X, right combatant to -X.
	rotation_degrees = Vector3(0, -90.0 if is_attacker else 90.0, 0)


func set_walk_pose(phase_value: float, intensity: float = 1.0) -> void:
	if model_root == null:
		return
	var sway: float = sin(phase_value * TAU) * 0.052 * intensity
	var bob: float = absf(sin(phase_value * PI)) * 0.062 * intensity
	model_root.position = base_position + Vector3(sway * 0.26, bob, 0)
	model_root.rotation = base_rotation + Vector3(-bob * 0.18, sway * 0.24, sway)


func set_combat_pose(kind: String, progress: float) -> void:
	if model_root == null:
		return
	var p: float = clampf(progress, 0.0, 1.0)
	var wave: float = sin(p * PI)
	var snap: float = sin(smoothstep(0.30, 0.78, p) * PI)
	match kind:
		"slash":
			model_root.rotation = base_rotation + Vector3(-0.05 * wave, 0.28 * wave, -0.20 * snap)
			model_root.position = base_position + Vector3(0, 0.06 * wave, -0.12 * wave)
		"strong_slash":
			model_root.rotation = base_rotation + Vector3(-0.10 * wave, 0.42 * wave, -0.32 * snap)
			model_root.position = base_position + Vector3(0, 0.12 * wave, -0.20 * wave)
			model_root.scale = base_scale * (1.0 + 0.065 * wave)
		"lunge", "long_lunge", "slide":
			model_root.rotation = base_rotation + Vector3(-0.17 * wave, 0.08 * wave, -0.06 * wave)
			model_root.position = base_position + Vector3(0, 0.045 * wave, -0.28 * wave)
			model_root.scale = base_scale * Vector3(1.0, 1.0 - 0.055 * wave, 1.0 + 0.075 * wave)
		"shoulder_bash":
			model_root.rotation = base_rotation + Vector3(-0.22 * wave, 0.12 * wave, -0.10 * wave)
			model_root.position = base_position + Vector3(0, 0.06 * wave, -0.24 * wave)
		"tornado", "desert_whirl", "desert_storm", "sticky_sandstorm":
			model_root.rotation = base_rotation + Vector3(-0.04 * wave, p * TAU * 1.3, -0.06 * wave)
			model_root.position = base_position + Vector3(0, 0.16 * wave, 0)
			model_root.scale = base_scale * (1.0 + 0.075 * wave)
		"earthquake":
			model_root.position = base_position + Vector3(0, -0.14 * wave, 0)
			model_root.scale = base_scale * Vector3(1.10, 0.88, 1.10).lerp(Vector3.ONE, p)
		"hit":
			model_root.rotation = base_rotation + Vector3(0.08 * wave, -0.14 * wave, 0.18 * wave)
			model_root.position = base_position + Vector3(0, 0.04 * wave, 0.16 * wave)
		_:
			model_root.rotation = base_rotation + Vector3(-0.07 * wave, 0.12 * wave, -0.08 * wave)
			model_root.position = base_position + Vector3(0, 0.10 * wave, -0.10 * wave)
	right_arm_pivot.rotation_degrees.z = -48.0 * wave
	left_arm_pivot.rotation_degrees.z = 20.0 * wave
	weapon_pivot.rotation_degrees.x = 62.0 * wave


func reset_pose() -> void:
	if model_root == null:
		return
	model_root.position = base_position
	model_root.rotation = base_rotation
	model_root.scale = base_scale
	if right_arm_pivot != null:
		right_arm_pivot.rotation = Vector3.ZERO
	if left_arm_pivot != null:
		left_arm_pivot.rotation = Vector3.ZERO
	if weapon_pivot != null:
		weapon_pivot.rotation = Vector3.ZERO


func flash(color: Color, duration: float = 0.14) -> void:
	if mesh_instances.is_empty():
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 2.2
	material.emission_energy_multiplier = 1.45
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mesh_node: MeshInstance3D in mesh_instances:
		mesh_node.material_override = material
	get_tree().create_timer(duration).timeout.connect(func():
		for mesh_node: MeshInstance3D in mesh_instances:
			if is_instance_valid(mesh_node):
				mesh_node.material_override = null
	)
