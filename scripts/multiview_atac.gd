class_name MultiViewAtac
extends Node3D

const VIEW_KEYS: Array[String] = ["front", "side", "back", "three_quarter"]
const VIEW_UPDATE_INTERVAL: float = 0.18
const SAFE_VISIBILITY_AABB: AABB = AABB(Vector3(-2.2, -1.2, -1.0), Vector3(4.4, 4.8, 2.0))
# Shared tactical height so every ATAC reads as the same class of machine on the map.
const TARGET_TACTICAL_HEIGHT: float = 1.68
const BASE_PIXEL_SIZE: float = 0.00210

static var SHARED_TEXTURES: Dictionary = {}
static var SHARED_SHADOW_MESH: CylinderMesh
static var SHARED_SHADOW_MATERIAL: StandardMaterial3D
const SUPPORTED_SLUGS: Array[String] = [
	"alba",
	"barbatos",
	"barazaph",
	"vedocorban",
	"cador",
	"solarus",
	"sarbelas",
	"einlager",
	"eigol",
	"amphisia",
	"haurol",
	"toreadore",
	"serata",
	"glaive",
	"sylpheed",
	"korbelan",
	"crimson",
	"rahabar",
	"altagrave",
	"snow_soldier",
	"ratatosk",
	"panther",
	"engineer",
	"waiban",
]

var slug: String = "alba"
var billboard_root: Node3D
var model_root: Node3D
var sprite: Sprite3D
var outline_sprite: Sprite3D
var weapon_pivot: Node3D
var second_weapon_pivot: Node3D
var right_arm_pivot: Node3D
var left_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var current_view: String = ""
var current_mirror: bool = false
var view_update_elapsed: float = 0.0
var arena_view_locked: bool = false
var base_sprite_position: Vector3 = Vector3(0, 0.84, 0)
var sync_elapsed: float = 0.0
var last_owner_position: Vector3 = Vector3(INF, INF, INF)
var last_camera_position: Vector3 = Vector3(INF, INF, INF)
var pose_kind: String = "idle"
var pose_progress: float = 0.0


func configure(model_slug: String) -> void:
	slug = _normalize_slug(model_slug)
	name = "%s_MultiViewRig" % slug.capitalize()
	set_meta("atac_slug", slug)
	set_meta("multiview_2_5d", true)
	set_meta("reference_revision", "campaign_v206")
	set_meta("visibility_rig", "top_level_camera_facing")
	set_meta("full_body_tactical", true)

	# The camera-facing root is top-level on purpose. It follows the unit position,
	# but does not inherit the tactical unit's Y rotation. This removes the old
	# edge-on/disappearing sprite bug when the player rotates the tactical camera.
	billboard_root = Node3D.new()
	billboard_root.name = "CameraFacingRoot"
	billboard_root.top_level = true
	add_child(billboard_root)

	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	billboard_root.add_child(model_root)

	left_leg_pivot = _new_pivot("LeftLegPivot")
	model_root.add_child(left_leg_pivot)
	right_leg_pivot = _new_pivot("RightLegPivot")
	model_root.add_child(right_leg_pivot)
	left_arm_pivot = _new_pivot("LeftArmPivot")
	model_root.add_child(left_arm_pivot)
	right_arm_pivot = _new_pivot("RightArmPivot")
	right_arm_pivot.name = "RightArmPivot"
	model_root.add_child(right_arm_pivot)

	outline_sprite = _new_character_sprite("AtacOutline")
	outline_sprite.pixel_size = BASE_PIXEL_SIZE * 1.026
	outline_sprite.position = base_sprite_position + Vector3(0, 0, -0.018)
	outline_sprite.modulate = Color(0.015, 0.02, 0.035, 0.66)
	outline_sprite.render_priority = 1
	# Legacy v0.9 used: outline_sprite.visible = false. V1.5 deliberately keeps
	# the subtle silhouette enabled to improve readability against bright terrain.
	outline_sprite.visible = true
	model_root.add_child(outline_sprite)

	sprite = _new_character_sprite("AtacSprite")
	# Kept explicit for validation and readability; the helper already applies it.
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.shaded = false
	sprite.pixel_size = BASE_PIXEL_SIZE
	sprite.position = base_sprite_position
	sprite.render_priority = 2
	model_root.add_child(sprite)

	# Load only the currently needed view. Every repeated ATAC reuses the same
	# imported texture resource instead of holding a private copy in memory.
	_set_view("front", true)
	_refresh_height_normalization()

	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.position = Vector3(0.58, 0.98, -0.035)
	right_arm_pivot.add_child(weapon_pivot)
	second_weapon_pivot = Node3D.new()
	second_weapon_pivot.name = "SecondWeaponPivot"
	second_weapon_pivot.position = Vector3(-0.58, 0.98, -0.035)
	left_arm_pivot.add_child(second_weapon_pivot)
	_build_weapons()

	var shadow: MeshInstance3D = MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = _shared_shadow_mesh()
	shadow.position = Vector3(0, 0.018, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.material_override = _shared_shadow_material()
	add_child(shadow)
	set_process(true)


static func _shared_shadow_mesh() -> CylinderMesh:
	if SHARED_SHADOW_MESH == null:
		SHARED_SHADOW_MESH = CylinderMesh.new()
		SHARED_SHADOW_MESH.top_radius = 0.38
		SHARED_SHADOW_MESH.bottom_radius = 0.43
		SHARED_SHADOW_MESH.height = 0.018
		SHARED_SHADOW_MESH.radial_segments = 12
	return SHARED_SHADOW_MESH


static func _shared_shadow_material() -> StandardMaterial3D:
	if SHARED_SHADOW_MATERIAL == null:
		SHARED_SHADOW_MATERIAL = StandardMaterial3D.new()
		SHARED_SHADOW_MATERIAL.albedo_color = Color(0.03, 0.035, 0.04, 0.16)
		SHARED_SHADOW_MATERIAL.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		SHARED_SHADOW_MATERIAL.roughness = 1.0
		SHARED_SHADOW_MATERIAL.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return SHARED_SHADOW_MATERIAL


func _new_character_sprite(sprite_name: String) -> Sprite3D:
	var result: Sprite3D = Sprite3D.new()
	result.name = sprite_name
	# Manual camera facing is used instead of Sprite3D billboard mode. Mixing
	# parent rotations, built-in billboarding and view swapping caused some ATACs
	# to be rendered edge-on or culled from particular camera angles.
	result.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	result.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	result.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	result.shaded = false
	result.double_sided = true
	result.no_depth_test = false
	result.fixed_size = false
	result.custom_aabb = SAFE_VISIBILITY_AABB
	return result


func _new_pivot(pivot_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = pivot_name
	return pivot


func _pixel_size() -> float:
	# One base pixel size; final on-map height is normalized via recommended_tactical_scale.
	return BASE_PIXEL_SIZE


func _refresh_height_normalization() -> void:
	var texture: Texture2D = sprite.texture if sprite != null else null
	var content_height: float = 940.0
	if texture != null:
		content_height = float(maxi(1, texture.get_height()))
		var image: Image = texture.get_image()
		if image != null and not image.is_empty():
			var used: Rect2i = image.get_used_rect()
			if used.size.y > 8:
				content_height = float(used.size.y)
	var world_height: float = content_height * BASE_PIXEL_SIZE
	var recommended: float = TARGET_TACTICAL_HEIGHT / maxf(world_height, 0.1)
	# Keep ATAC readable but never so large they swallow neighbouring tiles.
	recommended = clampf(recommended, 0.58, 0.92)
	set_meta("recommended_tactical_scale", recommended)
	set_meta("source_front_path", "res://assets/atac_views/%s/front.png" % slug)
	set_meta("skin_pixel_size", BASE_PIXEL_SIZE)
	# Anchor the sprite so feet sit near the ground regardless of sheet padding.
	base_sprite_position = Vector3(0, TARGET_TACTICAL_HEIGHT * 0.50, 0)
	if sprite != null:
		sprite.position = base_sprite_position
	if outline_sprite != null:
		outline_sprite.position = base_sprite_position + Vector3(0, 0, -0.018)


func _build_weapons() -> void:
	# These sheets already contain their original weapon in every view.
	if slug in [
		"cador", "amphisia", "haurol", "toreadore", "serata", "glaive",
		"crimson", "rahabar", "altagrave", "snow_soldier", "ratatosk",
		"panther", "engineer", "waiban",
	]:
		return
	var primary_path: String = "res://assets/atac_views/sword_level_1.png"
	var primary_scale: float = 0.00155
	if slug == "solarus":
		primary_path = "res://assets/atac_views/weapons/black_red_sword.png"
		primary_scale = 0.00142
	elif slug == "sarbelas":
		primary_path = "res://assets/atac_views/weapons/scythe.png"
		primary_scale = 0.00136
	elif slug == "einlager":
		primary_path = "res://assets/atac_views/weapons/einlager_sword.png"
		primary_scale = 0.00140
	var first: Sprite3D = _weapon_sprite(primary_path, primary_scale)
	first.name = "PrimaryWeapon"
	weapon_pivot.add_child(first)
	if slug == "sarbelas":
		var second: Sprite3D = _weapon_sprite(primary_path, primary_scale)
		second.name = "SecondaryScythe"
		second.flip_h = true
		second.rotation_degrees.z = 18.0
		second_weapon_pivot.add_child(second)


func _weapon_sprite(path: String, pixel_size: float) -> Sprite3D:
	var weapon: Sprite3D = Sprite3D.new()
	weapon.texture = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	weapon.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	weapon.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	weapon.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	weapon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	weapon.shaded = false
	weapon.double_sided = true
	weapon.pixel_size = pixel_size
	weapon.position = Vector3(0, 0.12, -0.01)
	weapon.rotation_degrees.z = -8.0
	weapon.custom_aabb = SAFE_VISIBILITY_AABB
	weapon.render_priority = 3
	return weapon


func _process(delta: float) -> void:
	if billboard_root == null or not is_inside_tree():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	sync_elapsed += delta
	var owner_moved: bool = global_position.distance_squared_to(last_owner_position) > 0.000025
	var camera_moved: bool = camera.global_position.distance_squared_to(last_camera_position) > 0.0004
	# Static ATACs no longer execute look_at() every rendered frame. Moving units
	# still follow smoothly, while idle formations update at a modest cadence.
	if owner_moved or camera_moved or sync_elapsed >= 0.12:
		sync_elapsed = 0.0
		last_owner_position = global_position
		last_camera_position = camera.global_position
		_sync_camera_facing(camera)
	if arena_view_locked:
		return
	view_update_elapsed += delta
	if not camera_moved and not owner_moved and view_update_elapsed < VIEW_UPDATE_INTERVAL:
		return
	view_update_elapsed = 0.0
	_process_view_direction(camera, false)


func _sync_camera_facing(camera: Camera3D) -> void:
	# Follow the owner every frame, including movement tweens, while keeping a
	# stable upright plane that cannot turn edge-on to the camera.
	billboard_root.global_position = global_position
	var target: Vector3 = camera.global_position
	target.y = billboard_root.global_position.y
	if billboard_root.global_position.distance_squared_to(target) > 0.0001:
		billboard_root.look_at(target, Vector3.UP, true)


func _process_view_direction(camera: Camera3D, force: bool) -> void:
	if sprite == null or not is_visible_in_tree():
		return
	var camera_delta: Vector3 = camera.global_position - global_position
	if camera_delta.length_squared() <= 0.000001:
		return
	var world_basis: Basis = global_transform.basis
	# During cleanup / scale tweens a tactical visual may briefly have a singular
	# transform. Inverting that basis floods headless runs with det == 0 errors.
	# Skip only that transient frame and use an orthonormal basis otherwise so
	# view selection is independent from tactical display scale.
	if absf(world_basis.determinant()) <= 0.000001:
		return
	var to_camera: Vector3 = camera_delta.normalized()
	var local_direction: Vector3 = world_basis.orthonormalized().inverse() * to_camera
	# The Ratatosk and Rahabar sheets were authored with the opposite forward
	# axis. Correct both formations so Matisse and Nordilian units do not walk
	# visually backwards while the remaining ATAC keep their normal orientation.
	if slug in ["ratatosk", "rahabar"]:
		local_direction = Basis(Vector3.UP, PI) * local_direction
	var angle: float = rad_to_deg(atan2(local_direction.x, -local_direction.z))
	var absolute_angle: float = absf(angle)
	var key: String = "front"
	if absolute_angle >= 150.0:
		key = "back"
	elif absolute_angle >= 74.0 and absolute_angle < 116.0:
		key = "side"
	elif absolute_angle >= 30.0:
		key = "three_quarter"
	_set_view(key, force)
	var mirror: bool = angle < 0.0
	_apply_mirror(mirror, force)


func _apply_mirror(mirror: bool, force: bool = false) -> void:
	if not force and mirror == current_mirror:
		return
	current_mirror = mirror
	if sprite != null:
		sprite.flip_h = mirror
	if outline_sprite != null:
		outline_sprite.flip_h = mirror
	if weapon_pivot != null:
		weapon_pivot.position.x = -0.58 if mirror else 0.58
	if second_weapon_pivot != null:
		second_weapon_pivot.position.x = 0.58 if mirror else -0.58


func _set_view(key: String, force: bool = false) -> void:
	if not force and key == current_view and sprite.texture != null:
		return
	current_view = key
	var texture: Texture2D = _shared_texture(slug, key)
	if texture != null:
		sprite.texture = texture
		outline_sprite.texture = texture


static func _shared_texture(model_slug: String, key: String) -> Texture2D:
	var cache_key: String = "%s/%s" % [model_slug, key]
	if SHARED_TEXTURES.has(cache_key):
		return SHARED_TEXTURES[cache_key] as Texture2D
	var texture_path: String = "res://assets/atac_views/%s/%s.png" % [model_slug, key]
	var texture: Texture2D = ResourceLoader.load(
		texture_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE
	) as Texture2D
	SHARED_TEXTURES[cache_key] = texture
	return texture


func set_walk_pose(phase_value: float, intensity: float = 1.0) -> void:
	var swing: float = sin(phase_value * TAU)
	var double_step: float = sin(phase_value * TAU * 2.0)
	var lift: float = absf(sin(phase_value * TAU))
	var impact: float = maxf(0.0, -double_step)
	model_root.position.y = (lift * 0.085 - impact * 0.018) * intensity
	model_root.rotation_degrees.z = swing * 2.35 * intensity
	model_root.rotation_degrees.x = (-lift * 1.35 + double_step * 0.45) * intensity
	sprite.position = base_sprite_position + Vector3(swing * 0.025, lift * 0.018, 0) * intensity
	outline_sprite.position = sprite.position + Vector3(0, 0, -0.018)
	sprite.rotation_degrees.z = -swing * 1.65 * intensity
	outline_sprite.rotation_degrees.z = sprite.rotation_degrees.z
	sprite.scale = Vector3(1.0 + impact * 0.012, 1.0 - impact * 0.018 + lift * 0.008, 1.0)
	outline_sprite.scale = sprite.scale
	left_leg_pivot.rotation_degrees.x = swing * 20.0 * intensity
	right_leg_pivot.rotation_degrees.x = -swing * 20.0 * intensity
	left_arm_pivot.rotation_degrees.x = -swing * 13.0 * intensity
	right_arm_pivot.rotation_degrees.x = swing * 13.0 * intensity
	weapon_pivot.rotation_degrees.z = -8.0 + swing * 7.0 * intensity
	second_weapon_pivot.rotation_degrees.z = 8.0 - swing * 7.0 * intensity


func reset_pose() -> void:
	pose_kind = "idle"
	pose_progress = 0.0
	model_root.position = Vector3.ZERO
	model_root.rotation_degrees = Vector3.ZERO
	model_root.scale = Vector3.ONE
	sprite.position = base_sprite_position
	outline_sprite.position = base_sprite_position + Vector3(0, 0, -0.018)
	sprite.rotation_degrees = Vector3.ZERO
	outline_sprite.rotation_degrees = Vector3.ZERO
	sprite.scale = Vector3.ONE
	outline_sprite.scale = Vector3.ONE
	sprite.modulate = Color.WHITE
	outline_sprite.modulate = Color(0.015, 0.02, 0.035, 0.66)
	left_leg_pivot.rotation_degrees = Vector3.ZERO
	right_leg_pivot.rotation_degrees = Vector3.ZERO
	left_arm_pivot.rotation_degrees = Vector3.ZERO
	right_arm_pivot.rotation_degrees = Vector3.ZERO
	weapon_pivot.rotation_degrees = Vector3.ZERO
	second_weapon_pivot.rotation_degrees = Vector3.ZERO


func set_combat_pose(kind: String, progress: float) -> void:
	# Readable anticipation → strike → recovery for full-body PS1 sheets.
	pose_kind = kind
	pose_progress = clampf(progress, 0.0, 1.0)
	var p: float = pose_progress
	var strike: float = smoothstep(0.28, 0.72, p)
	var recover: float = 1.0 - smoothstep(0.68, 1.0, p)
	var punch: float = sin(clampf((p - 0.28) / 0.44, 0.0, 1.0) * PI)
	match kind:
		"slash":
			model_root.rotation_degrees.z = lerpf(-18.0, 24.0, strike) * recover
			model_root.rotation_degrees.x = -6.0 * punch
			sprite.rotation_degrees.z = lerpf(12.0, -18.0, strike) * recover
			sprite.position = base_sprite_position + Vector3(lerpf(-0.06, 0.10, strike), punch * 0.04, 0)
			weapon_pivot.rotation_degrees.z = lerpf(-110.0, 95.0, strike)
			right_arm_pivot.rotation_degrees.z = lerpf(-35.0, 48.0, strike)
			model_root.scale = Vector3(1.0 + punch * 0.08, 1.0 - punch * 0.05, 1.0)
		"lunge", "long_lunge", "slide":
			var reach: float = 1.15 if kind == "long_lunge" or kind == "slide" else 1.0
			model_root.rotation_degrees.x = lerpf(8.0, -18.0 * reach, strike) * recover
			model_root.rotation_degrees.z = -5.0 * punch
			model_root.position.z = -0.05 * punch * reach
			model_root.scale = Vector3(1.0 + 0.09 * punch * reach, 1.0 - 0.07 * punch, 1.0)
			weapon_pivot.rotation_degrees.z = lerpf(-40.0, -118.0, strike)
			right_arm_pivot.rotation_degrees.x = lerpf(10.0, -55.0, strike)
			sprite.position = base_sprite_position + Vector3(0, punch * 0.05, 0)
		"strong_slash":
			model_root.rotation_degrees.z = lerpf(-28.0, 34.0, strike) * recover
			model_root.rotation_degrees.x = -10.0 * punch
			model_root.scale = Vector3(1.0 + 0.12 * punch, 1.0 - 0.09 * punch, 1.0)
			sprite.rotation_degrees.z = lerpf(16.0, -22.0, strike) * recover
			weapon_pivot.rotation_degrees.z = lerpf(-140.0, 125.0, strike)
			right_arm_pivot.rotation_degrees.z = lerpf(-55.0, 70.0, strike)
			sprite.modulate = Color(1.0, lerpf(1.0, 0.82, punch), lerpf(1.0, 0.72, punch), 1.0)
		"shoulder_bash":
			model_root.rotation_degrees.x = lerpf(6.0, -24.0, strike) * recover
			model_root.scale = Vector3(1.16, 0.88, 1.0).lerp(Vector3.ONE, 1.0 - recover)
			sprite.position = base_sprite_position + Vector3(0.04 * punch, punch * 0.03, 0)
		"tornado", "desert_whirl", "desert_storm", "sticky_sandstorm":
			model_root.rotation_degrees.y = p * 900.0
			model_root.position.y = sin(p * PI) * 0.16
			model_root.scale = Vector3.ONE * (1.0 + sin(p * PI) * 0.14)
			sprite.modulate = Color(1.05, 0.95, 0.75, 1.0).lerp(Color.WHITE, 1.0 - punch)
		"earthquake":
			model_root.position.y = -sin(p * PI) * 0.16
			model_root.scale = Vector3(1.12, 0.84, 1.12).lerp(Vector3.ONE, p)
		"ball_lightning", "bright_bomb", "spear_throw", "ice_rain", "ultrasound", "quicksand", "healing_ban", "fire_rain":
			model_root.rotation_degrees.z = -sin(p * PI) * 9.0
			model_root.position.y = sin(p * PI) * 0.11
			weapon_pivot.rotation_degrees.z = -70.0 * sin(p * PI)
			right_arm_pivot.rotation_degrees.z = -25.0 * sin(p * PI)
			sprite.modulate = Color(0.85 + 0.2 * punch, 0.9 + 0.1 * punch, 1.15, 1.0)
		"hit":
			model_root.rotation_degrees.z = 18.0 * sin(smoothstep(0.05, 0.85, p) * PI)
			model_root.position.x = 0.08 * sin(p * PI)
			model_root.scale = Vector3(1.0 + punch * 0.04, 1.0 - punch * 0.08, 1.0)
			sprite.modulate = Color(1.0, 0.55, 0.45, 1.0).lerp(Color.WHITE, smoothstep(0.45, 1.0, p))
		_:
			model_root.rotation_degrees.z = sin(p * PI) * 7.0
			model_root.scale = Vector3(1.0 + punch * 0.04, 1.0 - punch * 0.03, 1.0)
	outline_sprite.position = sprite.position + Vector3(0, 0, -0.018)
	outline_sprite.rotation_degrees = sprite.rotation_degrees
	outline_sprite.scale = sprite.scale


func flash(color: Color, duration: float = 0.14) -> void:
	if sprite == null:
		return
	var original: Color = sprite.modulate
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", color, duration * 0.35)
	tween.tween_property(sprite, "modulate", Color.WHITE, duration * 0.25)
	tween.tween_property(sprite, "modulate", original, duration * 0.40)


func _normalize_slug(value: String) -> String:
	var normalized: String = value.to_lower().strip_edges()
	if normalized in ["imperial_red", "imperial_commander", "barbatos"]:
		return "barbatos"
	if normalized in ["kamorge_atac", "green_atac", "barazaph"]:
		return "barazaph"
	if normalized in ["andrew_atac", "vedocorban"]:
		return "vedocorban"
	if normalized in ["cador_atac", "cador"]:
		return "cador"
	if normalized in ["faulkner_atac", "solarus"]:
		return "solarus"
	if normalized in ["duyere_atac", "sarbelas"]:
		return "sarbelas"
	if normalized in ["captain_atac", "einlager"]:
		return "einlager"
	if normalized in ["eigol_atac", "desert_general", "eigol"]:
		return "eigol"
	if normalized in ["ione_atac", "amphisia"]:
		return "amphisia"
	if normalized in ["reyna_atac", "haurol"]:
		return "haurol"
	if normalized in ["zeira_atac", "toreadore"]:
		return "toreadore"
	return normalized if SUPPORTED_SLUGS.has(normalized) else "alba"


func set_arena_view(key: String = "three_quarter", mirror: bool = false) -> void:
	arena_view_locked = true
	_set_view(key, true)
	_apply_mirror(mirror, true)


func resume_camera_views() -> void:
	arena_view_locked = false
	view_update_elapsed = VIEW_UPDATE_INTERVAL
