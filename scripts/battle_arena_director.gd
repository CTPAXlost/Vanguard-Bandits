class_name BattleArenaDirector
extends CanvasLayer

const AtacFactory = preload("res://scripts/atac_factory.gd")

const ATTACKER_START: Vector3 = Vector3(-2.55, 0.02, 0.10)
const TARGET_START: Vector3 = Vector3(2.55, 0.02, -0.10)
const CAMERA_REST: Vector3 = Vector3(0.0, 2.55, 7.65)
const CAMERA_INTRO: Vector3 = Vector3(0.0, 3.10, 9.35)
const CAMERA_LOOK: Vector3 = Vector3(0.0, 1.18, 0.0)

var overlay_root: Control
var viewport_container: SubViewportContainer
var arena_viewport: SubViewport
var arena_root: Node3D
var stage_root: Node3D
var effects_root: Node3D
var attacker_anchor: Node3D
var target_anchor: Node3D
var arena_camera: Camera3D
var attack_title: Label
var combatants_label: Label
var phase_label: Label
var fade_rect: ColorRect
var vignette_rect: ColorRect
var attacker_visual: Node3D
var target_visual: Node3D
var playing: bool = false
var camera_base_position: Vector3 = CAMERA_REST
var current_mode: String = "slash"


func _ready() -> void:
	layer = 70
	_build_overlay()
	overlay_root.visible = false


func _build_overlay() -> void:
	overlay_root = Control.new()
	overlay_root.name = "ArenaOverlay"
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay_root)

	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.006, 0.012, 0.026, 1.0)
	overlay_root.add_child(background)

	viewport_container = SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	overlay_root.add_child(viewport_container)

	arena_viewport = SubViewport.new()
	arena_viewport.name = "ArenaViewport"
	arena_viewport.size = Vector2i(1280, 720)
	arena_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	arena_viewport.own_world_3d = true
	arena_viewport.msaa_3d = Viewport.MSAA_4X
	arena_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	viewport_container.add_child(arena_viewport)

	arena_root = Node3D.new()
	arena_root.name = "ArenaWorld"
	arena_viewport.add_child(arena_root)

	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.038, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.34, 0.46, 0.68)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	environment.glow_bloom = 0.18
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.20, 0.34)
	environment.fog_light_energy = 0.45
	environment.fog_density = 0.012
	environment_node.environment = environment
	arena_root.add_child(environment_node)

	stage_root = Node3D.new()
	stage_root.name = "ArenaStage"
	arena_root.add_child(stage_root)
	_build_stage_geometry()
	_build_stage_lighting()

	attacker_anchor = Node3D.new()
	attacker_anchor.name = "AttackerAnchor"
	attacker_anchor.position = ATTACKER_START
	stage_root.add_child(attacker_anchor)
	target_anchor = Node3D.new()
	target_anchor.name = "TargetAnchor"
	target_anchor.position = TARGET_START
	stage_root.add_child(target_anchor)
	effects_root = Node3D.new()
	effects_root.name = "ArenaEffects"
	stage_root.add_child(effects_root)

	arena_camera = Camera3D.new()
	arena_camera.name = "ArenaCamera"
	arena_camera.position = CAMERA_REST
	arena_camera.fov = 43.0
	arena_camera.current = true
	arena_root.add_child(arena_camera)
	arena_camera.look_at(CAMERA_LOOK, Vector3.UP)
	camera_base_position = arena_camera.position

	_build_hud()

	vignette_rect = ColorRect.new()
	vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_rect.color = Color(0.02, 0.03, 0.06, 0.12)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(vignette_rect)

	fade_rect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(fade_rect)


func _build_stage_geometry() -> void:
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.name = "ArenaFloor"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(15.5, 8.8)
	floor_mesh.mesh = plane
	floor_mesh.material_override = _material(Color(0.075, 0.105, 0.16), false, 0.82)
	stage_root.add_child(floor_mesh)

	# A luminous duelling circle gives both silhouettes a strong contact point.
	for ring_index: int in range(4):
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 2.20 + float(ring_index) * 0.34
		torus.outer_radius = torus.inner_radius + 0.025
		torus.rings = 48
		torus.ring_segments = 8
		ring.mesh = torus
		ring.position = Vector3(0, 0.014 + ring_index * 0.002, 0)
		ring.rotation_degrees.x = 90
		ring.material_override = _material(Color(0.18, 0.47, 0.82, 0.24 - ring_index * 0.035), true, 0.5)
		stage_root.add_child(ring)

	for lane_index: int in range(-6, 7):
		var line: MeshInstance3D = MeshInstance3D.new()
		var line_mesh: BoxMesh = BoxMesh.new()
		line_mesh.size = Vector3(0.018, 0.012, 8.25)
		line.mesh = line_mesh
		line.position = Vector3(float(lane_index) * 0.66, 0.010, 0)
		line.material_override = _material(Color(0.16, 0.31, 0.49, 0.22), true, 0.6)
		stage_root.add_child(line)

	var back_wall: MeshInstance3D = MeshInstance3D.new()
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = Vector3(15.0, 5.2, 0.35)
	back_wall.mesh = wall_mesh
	back_wall.position = Vector3(0, 2.55, -3.6)
	back_wall.material_override = _material(Color(0.055, 0.075, 0.13), false, 0.78)
	stage_root.add_child(back_wall)

	for side: int in [-1, 1]:
		var pillar: MeshInstance3D = MeshInstance3D.new()
		var pillar_mesh: CylinderMesh = CylinderMesh.new()
		pillar_mesh.top_radius = 0.48
		pillar_mesh.bottom_radius = 0.66
		pillar_mesh.height = 4.5
		pillar_mesh.radial_segments = 10
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(float(side) * 5.75, 2.25, -2.0)
		pillar.material_override = _material(Color(0.13, 0.16, 0.24), false, 0.68)
		stage_root.add_child(pillar)

		var banner: MeshInstance3D = MeshInstance3D.new()
		var banner_mesh: BoxMesh = BoxMesh.new()
		banner_mesh.size = Vector3(1.15, 2.05, 0.06)
		banner.mesh = banner_mesh
		banner.position = Vector3(float(side) * 5.72, 2.65, -1.58)
		banner.material_override = _material(Color(0.24, 0.07, 0.12), false, 0.78)
		stage_root.add_child(banner)


func _build_stage_lighting() -> void:
	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48, -32, 0)
	key_light.light_energy = 1.65
	key_light.light_color = Color(1.0, 0.88, 0.68)
	key_light.shadow_enabled = true
	stage_root.add_child(key_light)

	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-28, 145, 0)
	fill_light.light_energy = 0.78
	fill_light.light_color = Color(0.32, 0.58, 1.0)
	stage_root.add_child(fill_light)

	for side: int in [-1, 1]:
		var rim: OmniLight3D = OmniLight3D.new()
		rim.position = Vector3(float(side) * 3.5, 2.4, -0.8)
		rim.omni_range = 5.5
		rim.light_energy = 4.0
		rim.light_color = Color(0.22, 0.52, 1.0) if side < 0 else Color(1.0, 0.34, 0.16)
		stage_root.add_child(rim)


func _build_hud() -> void:
	var header: PanelContainer = PanelContainer.new()
	header.anchor_left = 0.12
	header.anchor_right = 0.88
	header.offset_top = 22
	header.offset_bottom = 110
	overlay_root.add_child(header)
	var header_margin: MarginContainer = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 22)
	header_margin.add_theme_constant_override("margin_right", 22)
	header_margin.add_theme_constant_override("margin_top", 8)
	header_margin.add_theme_constant_override("margin_bottom", 8)
	header.add_child(header_margin)
	var header_box: VBoxContainer = VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 1)
	header_margin.add_child(header_box)
	attack_title = Label.new()
	attack_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_title.add_theme_font_size_override("font_size", 30)
	attack_title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.27))
	header_box.add_child(attack_title)
	combatants_label = Label.new()
	combatants_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combatants_label.add_theme_font_size_override("font_size", 18)
	header_box.add_child(combatants_label)

	phase_label = Label.new()
	phase_label.anchor_left = 0.28
	phase_label.anchor_right = 0.72
	phase_label.anchor_top = 1.0
	phase_label.anchor_bottom = 1.0
	phase_label.offset_top = -70
	phase_label.offset_bottom = -24
	phase_label.text = "ПОДГОТОВКА К УДАРУ"
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 19)
	phase_label.add_theme_color_override("font_color", Color(0.70, 0.84, 1.0))
	overlay_root.add_child(phase_label)


func play_attack(attacker_unit: Node3D, target_unit: Node3D, mode: String, display_name: String) -> void:
	if playing or attacker_unit == null or target_unit == null:
		return
	playing = true
	current_mode = mode
	_clear_combatants()
	attack_title.text = display_name
	combatants_label.text = "%s  ⚔  %s" % [str(attacker_unit.get_meta("label")), str(target_unit.get_meta("label"))]
	phase_label.text = "ПОДГОТОВКА К УДАРУ"
	_spawn_combatant_visuals(attacker_unit, target_unit)
	overlay_root.modulate = Color.WHITE
	arena_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	overlay_root.visible = true
	fade_rect.modulate = Color.WHITE
	arena_camera.position = CAMERA_INTRO
	arena_camera.look_at(CAMERA_LOOK, Vector3.UP)

	var fade_in: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, 0.22)
	await fade_in.finished
	await _camera_intro()
	await _animate_attack(mode)
	await get_tree().create_timer(0.16).timeout

	var fade_out: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 0.20)
	await fade_out.finished
	overlay_root.visible = false
	arena_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_clear_combatants()
	playing = false


func _spawn_combatant_visuals(attacker_unit: Node3D, target_unit: Node3D) -> void:
	var attacker_slug: String = str(attacker_unit.get_meta("model_slug", "alba"))
	var target_slug: String = str(target_unit.get_meta("model_slug", "barbatos"))
	attacker_visual = AtacFactory.create_atac(attacker_slug, "arena")
	target_visual = AtacFactory.create_atac(target_slug, "arena")
	attacker_anchor.add_child(attacker_visual)
	target_anchor.add_child(target_visual)
	attacker_visual.scale = Vector3.ONE * (1.06 if bool(attacker_visual.get_meta("real_3d_model", false)) else 1.00)
	target_visual.scale = Vector3.ONE * (1.06 if bool(target_visual.get_meta("real_3d_model", false)) else 1.00)
	_face_combatants()


func _face_combatants() -> void:
	# Static real meshes use exact inward yaw. Multiview rigs stay camera-facing
	# but use mirrored three-quarter artwork, which reads as a face-to-face duel.
	if attacker_visual != null:
		if attacker_visual.has_method("set_arena_facing"):
			attacker_visual.call("set_arena_facing", true)
		elif attacker_visual.has_method("set_arena_view"):
			attacker_visual.call("set_arena_view", "three_quarter", false)
	if target_visual != null:
		if target_visual.has_method("set_arena_facing"):
			target_visual.call("set_arena_facing", false)
		elif target_visual.has_method("set_arena_view"):
			target_visual.call("set_arena_view", "three_quarter", true)


func _clear_combatants() -> void:
	for anchor: Node3D in [attacker_anchor, target_anchor]:
		if anchor == null:
			continue
		for child: Node in anchor.get_children():
			child.queue_free()
	if effects_root != null:
		for effect: Node in effects_root.get_children():
			effect.queue_free()
	attacker_visual = null
	target_visual = null
	if attacker_anchor != null:
		attacker_anchor.position = ATTACKER_START
		attacker_anchor.rotation = Vector3.ZERO
	if target_anchor != null:
		target_anchor.position = TARGET_START
		target_anchor.rotation = Vector3.ZERO
	if arena_camera != null:
		arena_camera.position = CAMERA_REST
		arena_camera.fov = 43.0
		arena_camera.look_at(CAMERA_LOOK, Vector3.UP)


func _camera_intro() -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(arena_camera, "position", CAMERA_REST, 0.42)
	tween.parallel().tween_property(arena_camera, "fov", 43.0, 0.42)
	await tween.finished
	arena_camera.look_at(CAMERA_LOOK, Vector3.UP)


func _animate_attack(mode: String) -> void:
	_face_combatants()
	var melee_modes: Array[String] = ["slash", "strong_slash", "shoulder_bash", "lunge", "long_lunge", "slide", "tornado", "earthquake"]
	if mode in melee_modes:
		await _animate_melee(mode)
	else:
		await _animate_projectile_or_magic(mode)
	await _return_to_start()


func _animate_melee(mode: String) -> void:
	phase_label.text = "СБЛИЖЕНИЕ"
	var approach_x: float = -0.80 if mode not in ["long_lunge", "slide"] else -1.05
	await _approach_to(Vector3(approach_x, 0.02, 0.04), 0.38)
	phase_label.text = "АТАКА"

	var pose_kind: String = "lunge" if mode in ["long_lunge", "slide"] else mode
	for index: int in range(10):
		var p: float = float(index + 1) / 18.0
		if attacker_visual != null and attacker_visual.has_method("set_combat_pose"):
			attacker_visual.call("set_combat_pose", pose_kind, p)
		if index in [2, 5, 8]:
			_spawn_energy_wisp(attacker_anchor.position + Vector3(0.45, 1.05, 0), _mode_color(mode), index)
		await get_tree().create_timer(0.022).timeout

	var strike_start: Vector3 = attacker_anchor.position
	var strike_end: Vector3 = Vector3(0.52 if mode not in ["long_lunge", "slide"] else 0.78, 0.04, 0.02)
	for index: int in range(12):
		var p: float = float(index + 1) / 12.0
		var eased: float = smoothstep(0.0, 1.0, p)
		attacker_anchor.position = strike_start.lerp(strike_end, eased)
		if attacker_visual != null and attacker_visual.has_method("set_combat_pose"):
			attacker_visual.call("set_combat_pose", pose_kind, 0.50 + p * 0.50)
		_spawn_speed_streak(attacker_anchor.position + Vector3(-0.35, 0.75 + float(index % 3) * 0.18, 0), mode, index)
		if index == 6:
			_spawn_slash_combo(target_anchor.position + Vector3(-0.52, 1.20, 0), mode)
		await get_tree().create_timer(0.014).timeout

	# Hit-stop: the short pause makes the strike feel heavier than a continuous tween.
	await get_tree().create_timer(0.070 if mode == "strong_slash" else 0.045).timeout
	_spawn_impact_burst(target_anchor.position + Vector3(-0.18, 1.12, 0), _mode_color(mode), 14 if mode == "strong_slash" else 10)
	await _hit_reaction(1.35 if mode == "strong_slash" else 1.0)


func _animate_projectile_or_magic(mode: String) -> void:
	phase_label.text = "КОНЦЕНТРАЦИЯ"
	await _charge_attacker(mode)
	phase_label.text = "ПРИЁМ"
	match mode:
		"ice_rain":
			await _animate_ice_rain()
		"ultrasound":
			await _animate_ultrasound()
		"desert_storm", "desert_whirl", "sticky_sandstorm":
			await _animate_sand_magic(mode)
		"quicksand":
			await _animate_quicksand()
		"healing_ban":
			await _animate_healing_ban()
		_:
			await _animate_projectile(mode)
	await _hit_reaction(0.92 if mode in ["healing_ban", "quicksand"] else 1.08)


func _approach_to(destination: Vector3, duration: float) -> void:
	var start: Vector3 = attacker_anchor.position
	var steps: int = 20
	for index: int in range(steps):
		var p: float = float(index + 1) / float(steps)
		attacker_anchor.position = start.lerp(destination, smoothstep(0.0, 1.0, p))
		if attacker_visual != null and attacker_visual.has_method("set_walk_pose"):
			attacker_visual.call("set_walk_pose", p * 2.4, 0.82)
		await get_tree().create_timer(duration / float(steps)).timeout
	if attacker_visual != null and attacker_visual.has_method("reset_pose"):
		attacker_visual.call("reset_pose")
	_face_combatants()


func _return_to_start() -> void:
	phase_label.text = "ЗАВЕРШЕНИЕ"
	var start: Vector3 = attacker_anchor.position
	for index: int in range(14):
		var p: float = float(index + 1) / 14.0
		attacker_anchor.position = start.lerp(ATTACKER_START, smoothstep(0.0, 1.0, p))
		if attacker_visual != null and attacker_visual.has_method("set_walk_pose"):
			attacker_visual.call("set_walk_pose", p * 1.6, 0.50)
		await get_tree().create_timer(0.014).timeout
	attacker_anchor.position = ATTACKER_START
	target_anchor.position = TARGET_START
	attacker_anchor.rotation = Vector3.ZERO
	target_anchor.rotation = Vector3.ZERO
	if attacker_visual != null and attacker_visual.has_method("reset_pose"):
		attacker_visual.call("reset_pose")
	if target_visual != null and target_visual.has_method("reset_pose"):
		target_visual.call("reset_pose")
	_face_combatants()


func _charge_attacker(mode: String) -> void:
	var color: Color = _mode_color(mode)
	for index: int in range(14):
		var p: float = float(index + 1) / 14.0
		if attacker_visual != null and attacker_visual.has_method("set_combat_pose"):
			attacker_visual.call("set_combat_pose", mode, p * 0.72)
		if index % 2 == 0:
			_spawn_charge_ring(attacker_anchor.position + Vector3(0, 0.95, 0), color, index)
		_spawn_energy_wisp(attacker_anchor.position + Vector3(0, 1.10, 0), color, index)
		await get_tree().create_timer(0.025).timeout


func _animate_projectile(mode: String) -> void:
	var color: Color = _mode_color(mode)
	var projectile: MeshInstance3D = MeshInstance3D.new()
	var mesh: PrimitiveMesh
	if mode == "spear_throw":
		var spear: BoxMesh = BoxMesh.new()
		spear.size = Vector3(0.95, 0.055, 0.055)
		mesh = spear
	else:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.18 if mode != "bright_bomb" else 0.31
		sphere.height = sphere.radius * 2.0
		mesh = sphere
	projectile.mesh = mesh
	projectile.position = attacker_anchor.position + Vector3(0.46, 1.22, 0)
	projectile.material_override = _material(color, true, 0.25)
	effects_root.add_child(projectile)

	var start: Vector3 = projectile.position
	var destination: Vector3 = target_anchor.position + Vector3(-0.18, 1.18, 0)
	for index: int in range(26):
		var p: float = float(index + 1) / 26.0
		projectile.position = start.lerp(destination, smoothstep(0.0, 1.0, p))
		projectile.rotation_degrees.x += 17.0
		projectile.rotation_degrees.z += 23.0 if mode != "spear_throw" else 0.0
		projectile.scale = Vector3.ONE * (1.0 + sin(p * PI) * (0.42 if mode == "bright_bomb" else 0.16))
		_spawn_projectile_trail(projectile.position, color, index, mode)
		await get_tree().create_timer(0.013).timeout
	projectile.queue_free()
	if mode == "ball_lightning":
		_spawn_lightning_cage(destination, color)
	elif mode == "bright_bomb":
		_spawn_radial_wave(destination, color, 2.0)
	_spawn_impact_burst(destination, color, 14)


func _animate_ice_rain() -> void:
	var color: Color = _mode_color("ice_rain")
	_spawn_radial_wave(target_anchor.position + Vector3(0, 0.05, 0), color, 1.55)
	for wave: int in range(3):
		for index: int in range(7):
			var shard: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(0.07, 0.55, 0.07)
			shard.mesh = box
			var spread_x: float = (float(index) - 3.0) * 0.28 + float(wave - 1) * 0.10
			shard.position = target_anchor.position + Vector3(spread_x, 3.2 + float(index % 2) * 0.34, float((index % 3) - 1) * 0.24)
			shard.rotation_degrees.z = 18.0 if index % 2 == 0 else -18.0
			shard.material_override = _material(color, true, 0.18)
			effects_root.add_child(shard)
			var destination: Vector3 = Vector3(shard.position.x, 0.08, shard.position.z)
			var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(shard, "position", destination, 0.24 + float(index % 3) * 0.025)
			tween.tween_property(shard, "scale", Vector3.ZERO, 0.10)
			tween.tween_callback(Callable(shard, "queue_free"))
		await get_tree().create_timer(0.13).timeout
	_spawn_impact_burst(target_anchor.position + Vector3(0, 0.72, 0), color, 16)


func _animate_ultrasound() -> void:
	var color: Color = _mode_color("ultrasound")
	for index: int in range(12):
		var p: float = float(index + 1) / 12.0
		var position: Vector3 = attacker_anchor.position.lerp(target_anchor.position, p) + Vector3(0, 1.10, 0)
		_spawn_wave_ring(position, color, 0.45 + p * 0.70, index)
		await get_tree().create_timer(0.035).timeout
	_spawn_radial_wave(target_anchor.position + Vector3(0, 1.10, 0), color, 1.65)


func _animate_sand_magic(mode: String) -> void:
	var color: Color = _mode_color(mode)
	var loops: int = 30 if mode == "sticky_sandstorm" else 22
	for index: int in range(loops):
		var angle: float = float(index) * 0.72
		var radius: float = 0.30 + float(index % 7) * 0.11
		var position: Vector3 = target_anchor.position + Vector3(cos(angle) * radius, 0.18 + float(index % 9) * 0.17, sin(angle) * radius)
		_spawn_sand_shard(position, color, angle, index)
		if index % 5 == 0:
			_spawn_wave_ring(target_anchor.position + Vector3(0, 0.08, 0), color, 0.75 + float(index) * 0.025, index)
		await get_tree().create_timer(0.024).timeout
	_spawn_impact_burst(target_anchor.position + Vector3(0, 1.00, 0), color, 13)


func _animate_quicksand() -> void:
	var color: Color = _mode_color("quicksand")
	var pool: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 1.20
	cylinder.bottom_radius = 1.38
	cylinder.height = 0.035
	cylinder.radial_segments = 32
	pool.mesh = cylinder
	pool.position = target_anchor.position + Vector3(0, 0.018, 0)
	pool.material_override = _material(Color(color.r, color.g, color.b, 0.72), true, 0.65)
	pool.scale = Vector3.ZERO
	effects_root.add_child(pool)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pool, "scale", Vector3.ONE, 0.32)
	await tween.finished
	for index: int in range(12):
		_spawn_sand_shard(target_anchor.position + Vector3(0, 0.15, 0), color, float(index), index)
		await get_tree().create_timer(0.025).timeout
	var vanish: Tween = create_tween()
	vanish.tween_property(pool, "scale", Vector3.ZERO, 0.24)
	vanish.tween_callback(Callable(pool, "queue_free"))


func _animate_healing_ban() -> void:
	var color: Color = _mode_color("healing_ban")
	for index: int in range(9):
		_spawn_wave_ring(target_anchor.position + Vector3(0, 0.25 + float(index) * 0.14, 0), color, 0.38 + float(index) * 0.08, index)
		await get_tree().create_timer(0.036).timeout
	_spawn_cross_seal(target_anchor.position + Vector3(0, 1.15, 0), color)
	_spawn_radial_wave(target_anchor.position + Vector3(0, 1.15, 0), color, 1.35)


func _hit_reaction(power: float = 1.0) -> void:
	phase_label.text = "ПОПАДАНИЕ"
	if target_visual != null and target_visual.has_method("flash"):
		target_visual.call("flash", Color(1.0, 0.30, 0.18), 0.20)
	var start: Vector3 = target_anchor.position
	for index: int in range(10):
		var p: float = float(index + 1) / 10.0
		var recoil_curve: float = sin(p * PI)
		target_anchor.position = start + Vector3(0.46 * recoil_curve * power, 0.10 * recoil_curve, 0)
		if target_visual != null and target_visual.has_method("set_combat_pose"):
			target_visual.call("set_combat_pose", "hit", p)
		await get_tree().create_timer(0.018).timeout
	target_anchor.position = start
	if target_visual != null and target_visual.has_method("reset_pose"):
		target_visual.call("reset_pose")
	await _camera_shake(power)


func _camera_shake(power: float = 1.0) -> void:
	for index: int in range(9):
		var strength: float = (9.0 - float(index)) / 9.0 * power
		var sign_value: float = -1.0 if index % 2 == 0 else 1.0
		arena_camera.position = camera_base_position + Vector3(0.085 * strength * sign_value, 0.042 * strength * (1.0 if index % 3 == 0 else -0.5), -0.06 * strength)
		arena_camera.look_at(CAMERA_LOOK, Vector3.UP)
		await get_tree().create_timer(0.016).timeout
	arena_camera.position = camera_base_position
	arena_camera.look_at(CAMERA_LOOK, Vector3.UP)


func _spawn_slash_combo(position: Vector3, mode: String) -> void:
	var color: Color = _mode_color(mode)
	var arc_count: int = 3 if mode == "strong_slash" else 2
	for index: int in range(arc_count):
		var arc: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.58 + float(index) * 0.11
		torus.outer_radius = torus.inner_radius + (0.10 if mode == "strong_slash" else 0.065)
		torus.rings = 40
		torus.ring_segments = 8
		arc.mesh = torus
		arc.position = position + Vector3(0, float(index) * 0.08, float(index) * 0.025)
		arc.rotation_degrees = Vector3(72 - index * 8, index * 16, -32 - index * 17)
		arc.material_override = _material(Color(color.r, color.g, color.b, 0.90 - index * 0.14), true, 0.18)
		effects_root.add_child(arc)
		arc.scale = Vector3.ZERO
		var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(arc, "scale", Vector3.ONE * (1.32 + index * 0.13), 0.10 + index * 0.015)
		tween.tween_interval(0.055)
		tween.tween_property(arc, "scale", Vector3.ZERO, 0.11)
		tween.tween_callback(Callable(arc, "queue_free"))


func _spawn_speed_streak(position: Vector3, mode: String, index: int) -> void:
	if index % 2 != 0:
		return
	var streak: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.82 + float(index % 3) * 0.20, 0.025, 0.018)
	streak.mesh = mesh
	streak.position = position
	var streak_color: Color = _mode_color(mode)
	streak.material_override = _material(Color(streak_color.r, streak_color.g, streak_color.b, 0.55), true, 0.15)
	effects_root.add_child(streak)
	var tween: Tween = create_tween()
	tween.tween_property(streak, "position:x", position.x - 1.15, 0.16)
	tween.parallel().tween_property(streak, "scale", Vector3(0.12, 0.12, 0.12), 0.16)
	tween.tween_callback(Callable(streak, "queue_free"))


func _spawn_projectile_trail(position: Vector3, color: Color, index: int, mode: String) -> void:
	if index % 2 != 0:
		return
	var trail: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.09 if mode != "bright_bomb" else 0.15
	sphere.height = sphere.radius * 2.0
	trail.mesh = sphere
	trail.position = position
	trail.material_override = _material(Color(color.r, color.g, color.b, 0.58), true, 0.12)
	effects_root.add_child(trail)
	var tween: Tween = create_tween()
	tween.tween_property(trail, "scale", Vector3.ZERO, 0.20)
	tween.tween_callback(Callable(trail, "queue_free"))


func _spawn_charge_ring(position: Vector3, color: Color, index: int) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.26 + float(index % 4) * 0.07
	torus.outer_radius = torus.inner_radius + 0.035
	torus.rings = 24
	torus.ring_segments = 7
	ring.mesh = torus
	ring.position = position
	ring.rotation_degrees = Vector3(90, float(index) * 29.0, float(index) * 13.0)
	ring.material_override = _material(Color(color.r, color.g, color.b, 0.65), true, 0.15)
	effects_root.add_child(ring)
	ring.scale = Vector3.ONE * 1.5
	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", Vector3.ZERO, 0.24)
	tween.parallel().tween_property(ring, "rotation_degrees:y", ring.rotation_degrees.y + 120.0, 0.24)
	tween.tween_callback(Callable(ring, "queue_free"))


func _spawn_energy_wisp(center: Vector3, color: Color, index: int) -> void:
	var wisp: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	wisp.mesh = sphere
	var angle: float = float(index) * 1.37
	wisp.position = center + Vector3(cos(angle) * 0.54, -0.25 + float(index % 5) * 0.13, sin(angle) * 0.20)
	wisp.material_override = _material(Color(color.r, color.g, color.b, 0.78), true, 0.10)
	effects_root.add_child(wisp)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(wisp, "position", center, 0.20)
	tween.parallel().tween_property(wisp, "scale", Vector3.ZERO, 0.20)
	tween.tween_callback(Callable(wisp, "queue_free"))


func _spawn_wave_ring(position: Vector3, color: Color, size: float, index: int) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = size
	torus.outer_radius = size + 0.045
	torus.rings = 30
	torus.ring_segments = 7
	ring.mesh = torus
	ring.position = position
	ring.rotation_degrees = Vector3(90, float(index) * 17.0, 0)
	ring.material_override = _material(Color(color.r, color.g, color.b, 0.72), true, 0.12)
	effects_root.add_child(ring)
	ring.scale = Vector3(0.25, 0.25, 0.25)
	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.35, 0.28)
	tween.parallel().tween_property(ring, "position:y", position.y + 0.18, 0.28)
	tween.tween_property(ring, "scale", Vector3.ZERO, 0.10)
	tween.tween_callback(Callable(ring, "queue_free"))


func _spawn_sand_shard(position: Vector3, color: Color, angle: float, index: int) -> void:
	var shard: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.05, 0.20 + float(index % 3) * 0.07, 0.035)
	shard.mesh = box
	shard.position = position
	shard.rotation_degrees = Vector3(float(index) * 11.0, rad_to_deg(angle), float(index) * 23.0)
	shard.material_override = _material(Color(color.r, color.g, color.b, 0.68), true, 0.20)
	effects_root.add_child(shard)
	var direction: Vector3 = Vector3(cos(angle), 0.35, sin(angle)).normalized()
	var tween: Tween = create_tween()
	tween.tween_property(shard, "position", position + direction * 0.58, 0.24)
	tween.parallel().tween_property(shard, "scale", Vector3.ZERO, 0.24)
	tween.tween_callback(Callable(shard, "queue_free"))


func _spawn_lightning_cage(position: Vector3, color: Color) -> void:
	for index: int in range(8):
		var bolt: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.035, 0.75 + float(index % 3) * 0.18, 0.035)
		bolt.mesh = box
		var angle: float = float(index) * TAU / 8.0
		bolt.position = position + Vector3(cos(angle) * 0.55, 0, sin(angle) * 0.42)
		bolt.rotation_degrees = Vector3(float(index) * 19.0, float(index) * 45.0, 18.0 if index % 2 == 0 else -18.0)
		bolt.material_override = _material(Color(color.r, color.g, color.b, 0.86), true, 0.08)
		effects_root.add_child(bolt)
		var tween: Tween = create_tween()
		tween.tween_property(bolt, "scale", Vector3(1.0, 1.35, 1.0), 0.07)
		tween.tween_property(bolt, "scale", Vector3.ZERO, 0.13)
		tween.tween_callback(Callable(bolt, "queue_free"))


func _spawn_radial_wave(position: Vector3, color: Color, maximum_scale: float) -> void:
	var wave: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.10
	wave.mesh = sphere
	wave.position = position
	wave.material_override = _material(Color(color.r, color.g, color.b, 0.24), true, 0.08)
	wave.scale = Vector3.ZERO
	effects_root.add_child(wave)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "scale", Vector3.ONE * maximum_scale, 0.22)
	tween.tween_property(wave, "scale", Vector3.ZERO, 0.16)
	tween.tween_callback(Callable(wave, "queue_free"))


func _spawn_cross_seal(position: Vector3, color: Color) -> void:
	for rotation_value: float in [0.0, 90.0]:
		var bar: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(1.35, 0.08, 0.06)
		bar.mesh = mesh
		bar.position = position
		bar.rotation_degrees.z = rotation_value + 45.0
		bar.material_override = _material(Color(color.r, color.g, color.b, 0.88), true, 0.12)
		effects_root.add_child(bar)
		bar.scale = Vector3.ZERO
		var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(bar, "scale", Vector3.ONE, 0.16)
		tween.tween_interval(0.13)
		tween.tween_property(bar, "scale", Vector3.ZERO, 0.12)
		tween.tween_callback(Callable(bar, "queue_free"))


func _spawn_impact_burst(position: Vector3, color: Color, shard_count: int = 10) -> void:
	_spawn_radial_wave(position, color, 1.35)
	for index: int in range(shard_count):
		var shard: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.055, 0.28 + float(index % 4) * 0.06, 0.04)
		shard.mesh = box
		shard.position = position
		shard.rotation_degrees = Vector3(float(index) * 17.0, float(index) * 137.5, float(index) * 31.0)
		shard.material_override = _material(Color(color.r, color.g, color.b, 0.92), true, 0.10)
		effects_root.add_child(shard)
		var angle: float = float(index) * TAU / float(shard_count)
		var direction: Vector3 = Vector3(cos(angle), 0.24 + float(index % 3) * 0.14, sin(angle)).normalized()
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "position", position + direction * (0.85 + float(index % 4) * 0.13), 0.25)
		tween.parallel().tween_property(shard, "scale", Vector3.ZERO, 0.25)
		tween.tween_callback(Callable(shard, "queue_free"))


func _mode_color(mode: String) -> Color:
	if mode == "ice_rain":
		return Color(0.34, 0.82, 1.0)
	if mode in ["ultrasound", "ball_lightning"]:
		return Color(0.54, 0.40, 1.0)
	if mode in ["desert_storm", "desert_whirl", "sticky_sandstorm", "quicksand"]:
		return Color(0.96, 0.60, 0.16)
	if mode == "healing_ban":
		return Color(0.92, 0.10, 0.28)
	if mode == "bright_bomb":
		return Color(1.0, 0.92, 0.32)
	if mode == "spear_throw":
		return Color(0.86, 0.92, 1.0)
	if mode in ["strong_slash", "shoulder_bash"]:
		return Color(1.0, 0.42, 0.16)
	return Color(0.28, 0.76, 1.0)


func _material(color: Color, emission: bool, roughness: float = 0.55) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b) * 2.15
		material.emission_energy_multiplier = 1.35
	return material
