extends Node3D

const AtacFactory = preload("res://scripts/atac_factory.gd")
const MAP_PATH := "res://data/maps/mission_01.json"
const BALANCE_PATH := "res://data/balance/level_01_units.json"
const TILE_SIZE := 1.0
const CAMERA_MOVE_SPEED := 7.5
const CAMERA_ROTATE_SPEED := 1.55
const PLAYER_PORTRAIT := "res://assets/ui/portraits/bastion.png"
const IMPERIAL_PORTRAIT := "res://assets/ui/portraits/imperial_soldier.png"
const KAMORGE_PORTRAIT := "res://assets/ui/portraits/kamorge.png"
const ENERGY_BALL_LIGHTNING := 30
const FATIGUE_MOVE_PER_CELL := 2
const FATIGUE_SLASH := 5
const FATIGUE_LUNGE := 6
const FATIGUE_LONG_LUNGE := 7
const FATIGUE_DODGE := 4
const FATIGUE_RECOVERY := 18

enum Phase { PLAYER_MOVE, PLAYER_ACTION, ALLY_TURN, ENEMY_TURN, DIALOGUE, VICTORY, DEFEAT }

signal reaction_chosen
signal dialogue_advanced

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var title_label: Label = $HUD/TopBar/Margin/HBox/Title
@onready var phase_label: Label = $HUD/TopBar/Margin/HBox/Phase
@onready var status_label: Label = $HUD/TopBar/Margin/HBox/Status
@onready var portrait: TextureRect = $HUD/UnitPanel/Margin/VBox/Portrait
@onready var unit_name_label: Label = $HUD/UnitPanel/Margin/VBox/UnitName
@onready var unit_role_label: Label = $HUD/UnitPanel/Margin/VBox/UnitRole
@onready var hp_label: Label = $HUD/UnitPanel/Margin/VBox/HP
@onready var fatigue_label: Label = $HUD/UnitPanel/Margin/VBox/Fatigue
@onready var fatigue_bar: ProgressBar = $HUD/UnitPanel/Margin/VBox/FatigueBar
@onready var energy_label: Label = $HUD/UnitPanel/Margin/VBox/Energy
@onready var energy_bar: ProgressBar = $HUD/UnitPanel/Margin/VBox/EnergyBar
@onready var stats_label: Label = $HUD/UnitPanel/Margin/VBox/Stats
@onready var equipment_label: Label = $HUD/UnitPanel/Margin/VBox/Equipment
@onready var unit_info: Label = $HUD/CommandPanel/Margin/VBox/UnitInfo
@onready var turn_info: Label = $HUD/CommandPanel/Margin/VBox/Header/TurnInfo
@onready var attack_button: Button = $HUD/CommandPanel/Margin/VBox/Actions/Attack
@onready var defend_button: Button = $HUD/CommandPanel/Margin/VBox/Actions/Defend
@onready var dodge_button: Button = $HUD/CommandPanel/Margin/VBox/Actions/Dodge
@onready var ability_button: Button = $HUD/CommandPanel/Margin/VBox/Actions/Ability
@onready var end_turn_button: Button = $HUD/CommandPanel/Margin/VBox/Actions/EndTurn
@onready var attack_menu: PanelContainer = $HUD/AttackMenu
@onready var slash_button: Button = $HUD/AttackMenu/Margin/VBox/Slash
@onready var lunge_button: Button = $HUD/AttackMenu/Margin/VBox/Lunge
@onready var long_lunge_button: Button = $HUD/AttackMenu/Margin/VBox/LongLunge
@onready var ball_lightning_button: Button = $HUD/AttackMenu/Margin/VBox/BallLightning
@onready var attack_cancel_button: Button = $HUD/AttackMenu/Margin/VBox/Cancel
@onready var ability_menu: PanelContainer = $HUD/AbilityMenu
@onready var reflect_button: Button = $HUD/AbilityMenu/Margin/VBox/Reflect
@onready var ability_cancel_button: Button = $HUD/AbilityMenu/Margin/VBox/Cancel
@onready var reaction_menu: PanelContainer = $HUD/ReactionMenu
@onready var reaction_title: Label = $HUD/ReactionMenu/Margin/VBox/Title
@onready var reaction_defend_button: Button = $HUD/ReactionMenu/Margin/VBox/Defend
@onready var reaction_dodge_button: Button = $HUD/ReactionMenu/Margin/VBox/Dodge
@onready var reaction_ability_button: Button = $HUD/ReactionMenu/Margin/VBox/Ability
@onready var reaction_take_hit_button: Button = $HUD/ReactionMenu/Margin/VBox/TakeHit
@onready var dialogue_panel: PanelContainer = $HUD/DialoguePanel
@onready var dialogue_portrait: TextureRect = $HUD/DialoguePanel/Margin/HBox/Portrait
@onready var dialogue_speaker: Label = $HUD/DialoguePanel/Margin/HBox/VBox/Speaker
@onready var dialogue_text: Label = $HUD/DialoguePanel/Margin/HBox/VBox/Text
@onready var dialogue_continue: Button = $HUD/DialoguePanel/Margin/HBox/VBox/Continue

var map_data: Dictionary = {}
var balance_data: Dictionary = {}
var grid_width := 14
var grid_height := 12
var blocked_cells: Dictionary = {}
var reachable_cells: Dictionary = {}
var units: Array[Node3D] = []
var player_unit: Node3D
var selected_unit: Node3D
var highlight_root: Node3D
var phase := Phase.PLAYER_MOVE
var round_number := 1
var camera_distance := 11.4
var action_in_progress := false
var rng := RandomNumberGenerator.new()
var kamorge_unit: Node3D
var kamorge_spawned := false
var defeated_enemy_count := 0
var reaction_waiting := false
var reaction_back_attack := false
var pending_reaction_choice := "none"
var coin_label: Label
var shared_prop_materials: Dictionary = {}


func _ready() -> void:
	rng.seed = 2000
	$HUD/TopBar/Margin/HBox/Back.pressed.connect(_return_to_menu)
	attack_button.pressed.connect(_toggle_attack_menu)
	slash_button.pressed.connect(func(): _choose_attack("slash"))
	lunge_button.pressed.connect(func(): _choose_attack("lunge"))
	long_lunge_button.pressed.connect(func(): _choose_attack("long_lunge"))
	ball_lightning_button.pressed.connect(func(): _choose_attack("ball_lightning"))
	attack_cancel_button.pressed.connect(_close_attack_menu)
	ability_button.pressed.connect(_toggle_ability_menu)
	reflect_button.pressed.connect(_choose_reflect_ability)
	ability_cancel_button.pressed.connect(_close_ability_menu)
	end_turn_button.pressed.connect(_end_player_turn)
	reaction_defend_button.pressed.connect(func(): _finish_reaction("defend"))
	reaction_dodge_button.pressed.connect(func(): _finish_reaction("dodge"))
	reaction_ability_button.pressed.connect(_open_reaction_ability)
	reaction_take_hit_button.pressed.connect(func(): _finish_reaction("none"))
	dialogue_continue.pressed.connect(func(): dialogue_advanced.emit())
	attack_menu.visible = false
	ability_menu.visible = false
	reaction_menu.visible = false
	dialogue_panel.visible = false
	_build_coin_display()
	defend_button.visible = false
	dodge_button.visible = false
	status_label.text = "Загрузка карты..."
	_build_environment()
	_load_first_mission()
	_build_map()
	status_label.text = "Загрузка ATAC..."
	_spawn_mission_units()
	_begin_player_turn()


func _build_coin_display() -> void:
	var top_box: HBoxContainer = $HUD/TopBar/Margin/HBox
	coin_label = Label.new()
	coin_label.name = "Coins"
	coin_label.custom_minimum_size = Vector2(150, 0)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_label.add_theme_font_size_override("font_size", 19)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32))
	top_box.add_child(coin_label)
	var back_button: Button = $HUD/TopBar/Margin/HBox/Back
	top_box.move_child(coin_label, back_button.get_index())
	_refresh_coin_display()


func _refresh_coin_display() -> void:
	if coin_label != null:
		coin_label.text = "Монеты: %d" % CampaignState.get_coin_balance()


func _spawn_coin_reward_label(world_position: Vector3, amount: int) -> void:
	var label: Label3D = Label3D.new()
	label.text = "+%d монет" % amount
	label.font_size = 50
	label.outline_size = 9
	label.modulate = Color(1.0, 0.84, 0.24)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = world_position
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.9, 0.85)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.85)
	tween.tween_callback(Callable(label, "queue_free"))


func _process(delta: float) -> void:
	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vec.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vec.y += 1.0
	input_vec = input_vec.normalized()
	var forward := -camera_rig.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera_rig.global_transform.basis.x.normalized()
	camera_rig.position += (right * input_vec.x + forward * input_vec.y) * CAMERA_MOVE_SPEED * delta
	if Input.is_key_pressed(KEY_Q):
		camera_rig.rotate_y(CAMERA_ROTATE_SPEED * delta)
	if Input.is_key_pressed(KEY_E):
		camera_rig.rotate_y(-CAMERA_ROTATE_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if dialogue_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]:
			dialogue_advanced.emit()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_focus_selected_unit()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = max(1.65, camera_distance - 0.75)
			_apply_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = min(24.0, camera_distance + 0.75)
			_apply_zoom()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if attack_menu.visible or ability_menu.visible or reaction_menu.visible:
				return
			_handle_click(event.position)


func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _load_first_mission() -> void:
	var text := FileAccess.get_file_as_string(MAP_PATH)
	var parsed = JSON.parse_string(text)
	map_data = parsed if parsed is Dictionary else {"width": 14, "height": 12}
	grid_width = int(map_data.get("width", 14))
	grid_height = int(map_data.get("height", 12))
	blocked_cells = _cell_set(map_data.get("blocked_cells", []))
	title_label.text = str(map_data.get("name", "Первая миссия"))
	var balance_parsed = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if balance_parsed is Dictionary:
		balance_data = balance_parsed


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.19, 0.36, 0.62)
	sky_material.sky_horizon_color = Color(0.70, 0.83, 0.91)
	sky_material.ground_bottom_color = Color(0.06, 0.08, 0.10)
	sky_material.ground_horizon_color = Color(0.33, 0.43, 0.37)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.68
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.72, 0.72)
	env.fog_density = 0.004
	$WorldEnvironment.environment = env


func _build_map() -> void:
	var road_cells := _cell_set(map_data.get("road_cells", []))
	var raised_cells := _cell_set(map_data.get("raised_cells", []))
	_build_terrain_multimeshes(road_cells, raised_cells)
	for house_data in map_data.get("houses", []):
		_create_house(house_data)
	for hedge_data in map_data.get("hedges", []):
		_create_hedge_line(hedge_data)
	for tree_cell in map_data.get("trees", []):
		_create_tree(_array_to_cell(tree_cell))
	for rock_cell in map_data.get("rocks", []):
		_create_rock(_array_to_cell(rock_cell))


func _build_terrain_multimeshes(road_cells: Dictionary, raised_cells: Dictionary) -> void:
	# Previously every cell owned its own node, mesh and material. Mission 4 therefore
	# created more than 430 terrain objects before units and castle props were added.
	# Four MultiMeshes render the same board in only four terrain draw batches.
	var grass_dark: Array[Transform3D] = []
	var grass_light: Array[Transform3D] = []
	var road_dark: Array[Transform3D] = []
	var road_light: Array[Transform3D] = []
	for z in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, z)
			var raised: bool = raised_cells.has(cell)
			var basis := Basis.IDENTITY.scaled(Vector3(1.0, 1.5 if raised else 1.0, 1.0))
			var origin := Vector3(
				cell.x * TILE_SIZE, 0.02 + (0.12 if raised else 0.0), cell.y * TILE_SIZE
			)
			var transform := Transform3D(basis, origin)
			var light_variant: bool = (cell.x + cell.y) % 2 == 0
			if road_cells.has(cell):
				if light_variant:
					road_light.append(transform)
				else:
					road_dark.append(transform)
			elif light_variant:
				grass_light.append(transform)
			else:
				grass_dark.append(transform)

	_create_box_multimesh("TerrainGrassDark", grass_dark, Vector3(0.98, 0.08, 0.98), Color(0.39, 0.64, 0.30), false)
	_create_box_multimesh("TerrainGrassLight", grass_light, Vector3(0.98, 0.08, 0.98), Color(0.39, 0.64, 0.30).lightened(0.05), false)
	_create_box_multimesh("TerrainRoadDark", road_dark, Vector3(0.98, 0.08, 0.98), Color(0.48, 0.39, 0.27), false)
	_create_box_multimesh("TerrainRoadLight", road_light, Vector3(0.98, 0.08, 0.98), Color(0.48, 0.39, 0.27).lightened(0.05), false)


func _create_box_multimesh(
	node_name: String,
	transforms: Array[Transform3D],
	mesh_size: Vector3,
	color: Color,
	cast_shadows: bool = false,
	roughness: float = 0.84,
	emission: Color = Color(0, 0, 0, 1)
) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	if transforms.is_empty():
		return instance
	var box := BoxMesh.new()
	box.size = mesh_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission.r > 0.0 or emission.g > 0.0 or emission.b > 0.0:
		material.emission_enabled = true
		material.emission = emission
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	instance.multimesh = multimesh
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	add_child(instance)
	return instance


func _create_cell_overlay_multimesh(
	node_name: String,
	cells: Dictionary,
	y_position: float,
	height: float,
	color: Color,
	roughness: float,
	emission: Color
) -> void:
	var transforms: Array[Transform3D] = []
	for cell_value: Variant in cells.keys():
		var cell: Vector2i = cell_value
		transforms.append(Transform3D(Basis.IDENTITY, _cell_to_world(cell) + Vector3(0, y_position, 0)))
	_create_box_multimesh(
		node_name, transforms, Vector3(0.95, height, 0.95), color, false, roughness, emission
	)


func _create_house(data: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "House"
	var cell := _array_to_cell(data.get("cell", [0, 0]))
	var raw_size: Array = data.get("size", [2.0, 1.1, 1.4])
	var size := Vector3(float(raw_size[0]), float(raw_size[1]), float(raw_size[2]))
	root.position = _cell_to_world(cell) + Vector3(0, 0.04, 0)
	root.rotation_degrees.y = float(data.get("rotation", 0))
	add_child(root)
	_box_prop(root, "Walls", Vector3(0, size.y * 0.5, 0), size, Color(0.50, 0.42, 0.31))
	_box_prop(
		root,
		"Door",
		Vector3(0, 0.37, -size.z * 0.505),
		Vector3(0.34, 0.68, 0.05),
		Color(0.20, 0.12, 0.08)
	)
	_box_prop(
		root,
		"RoofL",
		Vector3(-size.x * 0.23, size.y + 0.26, 0),
		Vector3(size.x * 0.62, 0.13, size.z * 1.15),
		Color(0.30, 0.13, 0.10),
		Vector3(0, 0, 25)
	)
	_box_prop(
		root,
		"RoofR",
		Vector3(size.x * 0.23, size.y + 0.26, 0),
		Vector3(size.x * 0.62, 0.13, size.z * 1.15),
		Color(0.30, 0.13, 0.10),
		Vector3(0, 0, -25)
	)
	_box_prop(
		root,
		"WindowL",
		Vector3(-size.x * 0.27, 0.62, -size.z * 0.51),
		Vector3(0.28, 0.30, 0.04),
		Color(0.42, 0.72, 0.86),
		Vector3.ZERO,
		true
	)
	_box_prop(
		root,
		"WindowR",
		Vector3(size.x * 0.27, 0.62, -size.z * 0.51),
		Vector3(0.28, 0.30, 0.04),
		Color(0.42, 0.72, 0.86),
		Vector3.ZERO,
		true
	)


func _create_hedge_line(data: Dictionary) -> void:
	var start := _array_to_cell(data.get("from", [0, 0]))
	var finish := _array_to_cell(data.get("to", [0, 0]))
	var dx := 0 if finish.x == start.x else (1 if finish.x > start.x else -1)
	var dz := 0 if finish.y == start.y else (1 if finish.y > start.y else -1)
	var current := start
	while true:
		var root := Node3D.new()
		root.position = _cell_to_world(current)
		add_child(root)
		_box_prop(
			root, "Hedge", Vector3(0, 0.34, 0), Vector3(0.92, 0.68, 0.42), Color(0.10, 0.35, 0.13)
		)
		_box_prop(
			root,
			"HedgeTop",
			Vector3(0, 0.67, 0),
			Vector3(0.78, 0.15, 0.34),
			Color(0.16, 0.48, 0.18),
			Vector3(0, 11, 0)
		)
		if current == finish:
			break
		current += Vector2i(dx, dz)


func _create_tree(cell: Vector2i) -> void:
	var root := Node3D.new()
	root.position = _cell_to_world(cell)
	add_child(root)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.10
	trunk_mesh.bottom_radius = 0.14
	trunk_mesh.height = 0.88
	trunk_mesh.radial_segments = 7
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.44
	trunk.material_override = _prop_material(Color(0.29, 0.16, 0.08))
	root.add_child(trunk)
	for offset in [Vector3(0, 1.02, 0), Vector3(-0.18, 0.88, 0.05), Vector3(0.18, 0.91, -0.06)]:
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 0.39
		crown_mesh.height = 0.72
		crown_mesh.radial_segments = 8
		crown_mesh.rings = 5
		crown.mesh = crown_mesh
		crown.position = offset
		crown.material_override = _prop_material(Color(0.10, 0.39, 0.14))
		root.add_child(crown)


func _create_rock(cell: Vector2i) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.33
	mesh.height = 0.46
	mesh.radial_segments = 7
	mesh.rings = 4
	rock.mesh = mesh
	rock.position = _cell_to_world(cell) + Vector3(0, 0.20, 0)
	rock.scale = Vector3(1.25, 0.75, 0.9)
	rock.rotation_degrees = Vector3(0, float((cell.x * 31 + cell.y * 17) % 180), 0)
	rock.material_override = _prop_material(Color(0.32, 0.35, 0.36))
	add_child(rock)


func _spawn_mission_units() -> void:
	var start := _array_to_cell(map_data.get("player_start", [3, 9]))
	player_unit = _spawn_unit(
		"Bastion / Alba", "Главный герой", "alba", start, true, false, "ally", "bastion_alba"
	)
	for enemy_data in map_data.get("enemies", []):
		_spawn_unit(
			str(enemy_data.get("name", "Имперский солдат")),
			str(enemy_data.get("role", "Имперский солдат")),
			str(enemy_data.get("atac", "barbatos")),
			_array_to_cell(enemy_data.get("cell", [9, 3])),
			false,
			bool(enemy_data.get("commander", false)),
			"enemy",
			"imperial_commander" if bool(enemy_data.get("commander", false)) else "imperial_soldier"
		)


func _spawn_unit(
	label: String,
	role: String,
	model_slug: String,
	cell: Vector2i,
	player_controlled: bool,
	commander: bool,
	team: String = "enemy",
	profile: String = ""
) -> Node3D:
	var unit := Node3D.new()
	unit.name = label.replace(" / ", "_").replace(" ", "_")
	unit.set_meta("label", label)
	unit.set_meta("role", role)
	unit.set_meta("model_slug", model_slug)
	unit.set_meta("cell", cell)
	unit.set_meta("player", player_controlled)
	unit.set_meta("team", team)
	unit.set_meta("commander", commander)
	unit.set_meta("moved", false)
	unit.set_meta("acted", false)
	unit.set_meta("stats", _create_stats(profile, player_controlled, commander))
	unit.position = _cell_to_world(cell)

	var visual := AtacFactory.create_atac(model_slug, "tactical")
	visual.name = "ATACVisual"
	if bool(visual.get_meta("real_skeleton", false)):
		var skeletal_scale: float = 0.82
		if model_slug in ["barazaph", "eigol", "cador", "toreadore"]:
			skeletal_scale = 0.76
		elif model_slug in ["amphisia", "haurol", "serata"]:
			skeletal_scale = 0.86
		visual.scale = Vector3.ONE * skeletal_scale
	else:
		visual.scale = (
			Vector3.ONE * (0.64 if model_slug in ["barazaph", "eigol"] else (0.61 if player_controlled else 0.58))
		)
	visual.set_meta("base_tactical_scale", visual.scale)
	visual.rotation_degrees.y = 180.0 if team == "ally" else 0.0
	unit.add_child(visual)

	var marker := MeshInstance3D.new()
	marker.name = "SelectionRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.40
	ring.outer_radius = 0.49
	ring.rings = 24
	ring.ring_segments = 8
	marker.mesh = ring
	marker.rotation_degrees.x = 90
	marker.position.y = 0.05
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(0.98, 0.88, 0.20) if team == "ally" else Color(0.95, 0.24, 0.18)
	marker_mat.emission_enabled = true
	marker_mat.emission = marker_mat.albedo_color * 0.85
	marker.material_override = marker_mat
	unit.add_child(marker)

	var bar := _create_hp_bar(unit)
	bar.name = "HPBar"
	bar.position = Vector3(0, 1.92, 0)
	unit.add_child(bar)
	add_child(unit)
	units.append(unit)
	return unit


func _create_stats(profile: String, player_controlled: bool, commander: bool) -> Dictionary:
	var selected_profile := profile
	if selected_profile.is_empty():
		selected_profile = (
			"bastion_alba"
			if player_controlled
			else ("imperial_commander" if commander else "imperial_soldier")
		)
	if balance_data.has(selected_profile):
		var loaded: Dictionary = (balance_data[selected_profile] as Dictionary).duplicate(true)
		loaded["fatigue"] = int(loaded.get("fatigue", 0))
		loaded["max_fatigue"] = int(loaded.get("max_fatigue", 100))
		loaded["energy"] = int(loaded.get("energy", 0))
		loaded["max_energy"] = int(loaded.get("max_energy", 0))
		return loaded
	return {}


func _create_hp_bar(unit: Node3D) -> Label3D:
	var stats: Dictionary = unit.get_meta("stats")
	var label := Label3D.new()
	label.text = "HP %d" % int(stats["hp"])
	label.font_size = 34
	label.outline_size = 7
	label.modulate = (
		Color(0.72, 0.95, 1.0) if str(unit.get_meta("team")) == "ally" else Color(1.0, 0.82, 0.72)
	)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	return label


func _begin_player_turn() -> void:
	if not _is_alive(player_unit):
		_show_defeat()
		return
	phase = Phase.PLAYER_MOVE
	action_in_progress = false
	_close_attack_menu()
	_close_ability_menu()
	player_unit.set_meta("moved", false)
	player_unit.set_meta("acted", false)
	_recover_fatigue(player_unit, FATIGUE_RECOVERY)
	_recover_energy(player_unit, 5)
	_select_unit(player_unit)
	_show_reachable_cells(player_unit, _available_move_range(player_unit))
	phase_label.text = "ХОД ИГРОКА"
	phase_label.modulate = Color(0.42, 0.95, 1.0)
	turn_info.text = "Раунд %d" % round_number
	status_label.text = "Bastion / Alba: выберите зелёную клетку или действие."
	_refresh_ui()


func _handle_click(screen_position: Vector2) -> void:
	if action_in_progress or phase in [Phase.VICTORY, Phase.DEFEAT]:
		return
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if abs(direction.y) < 0.0001:
		return
	var t := -origin.y / direction.y
	if t <= 0.0:
		return
	var point := origin + direction * t
	var cell := Vector2i(roundi(point.x / TILE_SIZE), roundi(point.z / TILE_SIZE))
	if not _cell_in_bounds(cell):
		return
	var clicked_unit := _unit_at(cell)
	if clicked_unit != null:
		_select_unit(clicked_unit)
		status_label.text = "Выбран: %s" % str(clicked_unit.get_meta("label"))
		return
	if phase == Phase.PLAYER_MOVE and reachable_cells.has(cell):
		await _move_player_to(cell)


func _move_player_to(cell: Vector2i) -> void:
	if player_unit == null or bool(player_unit.get_meta("moved")):
		return
	action_in_progress = true
	_close_attack_menu()
	_clear_highlights()
	var start: Vector2i = player_unit.get_meta("cell")
	var path := _find_path(start, cell, player_unit)
	if path.is_empty() and start != cell:
		action_in_progress = false
		_show_reachable_cells(player_unit, _available_move_range(player_unit))
		return
	var fatigue_cost := path.size() * FATIGUE_MOVE_PER_CELL
	if not _can_spend_fatigue(player_unit, fatigue_cost):
		action_in_progress = false
		status_label.text = "Не хватает выносливости для этого маршрута."
		_show_reachable_cells(player_unit, _available_move_range(player_unit))
		return
	await _animate_path(player_unit, path, 0.16)
	_spend_fatigue(player_unit, fatigue_cost)
	player_unit.set_meta("moved", true)
	phase = Phase.PLAYER_ACTION
	action_in_progress = false
	_select_unit(player_unit)
	phase_label.text = "ДЕЙСТВИЕ"
	status_label.text = "Перемещение завершено. Выберите действие."
	_refresh_ui()


func _request_player_attack(mode: String) -> void:
	if action_in_progress or phase not in [Phase.PLAYER_MOVE, Phase.PLAYER_ACTION]:
		return
	var target := _player_attack_target(mode)
	if target == null:
		status_label.text = "Цель недоступна для выбранной атаки."
		return
	var fatigue_cost := _attack_fatigue_cost(mode)
	if not _can_spend_fatigue(player_unit, fatigue_cost):
		status_label.text = "Alba слишком устала для этой атаки."
		return
	action_in_progress = true
	_close_attack_menu()
	_close_ability_menu()
	_clear_highlights()
	_select_unit(target)
	if mode == "long_lunge":
		await _animate_long_lunge(player_unit, target)
	elif mode == "lunge":
		await _animate_lunge(player_unit, target)
	else:
		await _animate_slash(player_unit, target)
	_spend_fatigue(player_unit, fatigue_cost)
	await _resolve_attack(player_unit, target, mode)
	player_unit.set_meta("acted", true)
	action_in_progress = false
	if _all_enemies_defeated():
		_show_victory()
		return
	await _end_player_turn()


func _toggle_attack_menu() -> void:
	if attack_button.disabled:
		return
	_close_ability_menu()
	attack_menu.visible = not attack_menu.visible
	_update_attack_menu_buttons()


func _close_attack_menu() -> void:
	attack_menu.visible = false


func _choose_attack(mode: String) -> void:
	_close_attack_menu()
	await _request_player_attack(mode)


func _update_attack_menu_buttons() -> void:
	if player_unit == null:
		for button in [slash_button, lunge_button, long_lunge_button, ball_lightning_button]:
			button.disabled = true
		return
	var can_act := phase in [Phase.PLAYER_MOVE, Phase.PLAYER_ACTION] and not action_in_progress
	slash_button.disabled = not (
		can_act
		and _player_attack_target("slash") != null
		and _can_spend_fatigue(player_unit, FATIGUE_SLASH)
	)
	lunge_button.disabled = not (
		can_act
		and _player_attack_target("lunge") != null
		and _can_spend_fatigue(player_unit, FATIGUE_LUNGE)
	)
	long_lunge_button.disabled = not (
		can_act
		and _player_attack_target("long_lunge") != null
		and _can_spend_fatigue(player_unit, FATIGUE_LONG_LUNGE)
	)
	ball_lightning_button.visible = false
	ball_lightning_button.disabled = true


func _player_dodge() -> void:
	pass


func _player_reflect() -> void:
	pass


func _player_defend() -> void:
	pass


func _end_player_turn() -> void:
	if action_in_progress and phase != Phase.ENEMY_TURN:
		return
	_close_attack_menu()
	_close_ability_menu()
	_clear_highlights()
	await _run_ally_phase()


func _run_enemy_phase() -> void:
	action_in_progress = true
	phase = Phase.ENEMY_TURN
	phase_label.text = "ХОД ПРОТИВНИКА"
	phase_label.modulate = Color(1.0, 0.45, 0.38)
	var enemy_index := 0
	for enemy in units:
		if str(enemy.get_meta("team")) != "enemy" or not _is_alive(enemy):
			continue
		enemy_index += 1
		_recover_fatigue(enemy, FATIGUE_RECOVERY)
		var target := _nearest_living_ally(enemy)
		if target == null:
			break
		turn_info.text = "Раунд %d • враг %d" % [round_number, enemy_index]
		_select_unit(enemy)
		status_label.text = "%s / Barbatos начинает ход" % str(enemy.get_meta("label"))
		await get_tree().create_timer(0.20).timeout
		var distance := _grid_distance(enemy, target)
		if distance > 2:
			var goals := _free_adjacent_cells(target, enemy)
			var path := _find_path_to_any(enemy.get_meta("cell"), goals, enemy)
			var steps: int = mini(int(_stats(enemy).get("move_range", 5)), path.size())
			if steps > 0:
				var partial: Array = path.slice(0, steps)
				await _animate_path(enemy, partial, 0.17)
				_spend_fatigue(enemy, partial.size() * FATIGUE_MOVE_PER_CELL)
		distance = _grid_distance(enemy, target)
		if distance == 1 and _is_alive(target):
			var mode := "lunge" if bool(enemy.get_meta("commander")) else "slash"
			if mode == "lunge":
				await _animate_lunge(enemy, target)
			else:
				await _animate_slash(enemy, target)
			await _resolve_attack(enemy, target, mode)
		elif distance == 2 and _has_clear_long_lunge_line(enemy, target):
			await _animate_long_lunge(enemy, target)
			await _resolve_attack(enemy, target, "long_lunge")
		else:
			status_label.text = "%s завершает ход" % str(enemy.get_meta("label"))
			await get_tree().create_timer(0.24).timeout
		if not _is_alive(player_unit):
			_show_defeat()
			action_in_progress = false
			return
	if _all_enemies_defeated():
		_show_victory()
		action_in_progress = false
		return
	round_number += 1
	action_in_progress = false
	_begin_player_turn()


func _animate_path(unit: Node3D, path: Array, step_duration: float) -> void:
	var model_root := unit.get_node_or_null("ATACVisual/ModelRoot") as Node3D
	var sprite := unit.get_node_or_null("ATACVisual/ModelRoot/AtacSprite") as Sprite3D
	var step_index := 0
	for next_cell_value in path:
		var next_cell: Vector2i = next_cell_value
		var current: Vector2i = unit.get_meta("cell")
		var delta_cell := next_cell - current
		if delta_cell != Vector2i.ZERO:
			unit.rotation.y = atan2(float(delta_cell.x), float(delta_cell.y))
		var sign := -1.0 if step_index % 2 == 0 else 1.0
		var target_position := _cell_to_world(next_cell)
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if model_root != null:
			tween.parallel().tween_property(model_root, "position:y", 0.10, step_duration * 0.45)
			tween.parallel().tween_property(
				model_root, "rotation_degrees:z", 3.5 * sign, step_duration * 0.45
			)
		if sprite != null:
			tween.parallel().tween_property(
				sprite, "scale", Vector3(1.02, 0.97, 1.0), step_duration * 0.45
			)
		tween.parallel().tween_property(
			unit, "position", target_position + Vector3(0, 0.07, 0), step_duration * 0.45
		)
		tween.tween_property(unit, "position", target_position, step_duration * 0.55)
		if model_root != null:
			tween.parallel().tween_property(model_root, "position:y", 0.0, step_duration * 0.55)
			tween.parallel().tween_property(
				model_root, "rotation_degrees:z", 0.0, step_duration * 0.55
			)
		if sprite != null:
			tween.parallel().tween_property(sprite, "scale", Vector3.ONE, step_duration * 0.55)
		await tween.finished
		unit.set_meta("cell", next_cell)
		step_index += 1
	_refresh_hp_bar(unit)


func _animate_slash(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Порез»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var body := attacker.get_node_or_null("ATACVisual/ModelRoot") as Node3D
	var arm := attacker.get_node_or_null("ATACVisual/ModelRoot/RightArmPivot") as Node3D
	var weapon := (
		attacker.get_node_or_null("ATACVisual/ModelRoot/RightArmPivot/WeaponPivot") as Node3D
	)
	var arm_start := arm.rotation_degrees if arm != null else Vector3.ZERO
	var weapon_start := weapon.rotation_degrees if weapon != null else Vector3.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if body != null:
		tween.parallel().tween_property(body, "rotation_degrees:z", -7.0, 0.18)
	if arm != null:
		tween.tween_property(arm, "rotation_degrees", Vector3(-28, 14, -74), 0.18)
	else:
		tween.tween_interval(0.18)
	if weapon != null:
		tween.parallel().tween_property(weapon, "rotation_degrees", Vector3(8, 0, -42), 0.18)
	tween.tween_callback(
		Callable(self, "_spawn_slash_effect").bind(target.global_position + Vector3(0, 1.0, 0))
	)
	if arm != null:
		tween.tween_property(arm, "rotation_degrees", Vector3(18, -8, 52), 0.14)
	else:
		tween.tween_interval(0.14)
	if arm != null:
		tween.tween_property(arm, "rotation_degrees", arm_start, 0.22)
	if weapon != null:
		tween.parallel().tween_property(weapon, "rotation_degrees", weapon_start, 0.22)
	if body != null:
		tween.parallel().tween_property(body, "rotation_degrees:z", 0.0, 0.22)
	await tween.finished


func _animate_lunge(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Выпад»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var body := attacker.get_node_or_null("ATACVisual/ModelRoot") as Node3D
	var start_position := attacker.position
	var direction := (target.position - attacker.position).normalized()
	var thrust_position := start_position + direction * 0.46
	var arm := attacker.get_node_or_null("ATACVisual/ModelRoot/RightArmPivot") as Node3D
	var weapon := (
		attacker.get_node_or_null("ATACVisual/ModelRoot/RightArmPivot/WeaponPivot") as Node3D
	)
	var arm_start := arm.rotation_degrees if arm != null else Vector3.ZERO
	var weapon_start := weapon.rotation_degrees if weapon != null else Vector3.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if body != null:
		tween.parallel().tween_property(body, "rotation_degrees:x", -9.0, 0.15)
	if arm != null:
		tween.tween_property(arm, "rotation_degrees", Vector3(-58, 0, -12), 0.15)
	else:
		tween.tween_interval(0.15)
	if weapon != null:
		tween.parallel().tween_property(weapon, "rotation_degrees", Vector3(88, 0, 0), 0.15)
	tween.tween_property(attacker, "position", thrust_position, 0.18)
	tween.parallel().tween_callback(
		Callable(self, "_spawn_lunge_effect").bind(
			target.global_position + Vector3(0, 1.0, 0), direction
		)
	)
	tween.tween_interval(0.09)
	tween.tween_property(attacker, "position", start_position, 0.23)
	if arm != null:
		tween.parallel().tween_property(arm, "rotation_degrees", arm_start, 0.23)
	if weapon != null:
		tween.parallel().tween_property(weapon, "rotation_degrees", weapon_start, 0.23)
	if body != null:
		tween.parallel().tween_property(body, "rotation_degrees:x", 0.0, 0.23)
	await tween.finished


func _animate_long_lunge(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Длинный выпад»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var body := attacker.get_node_or_null("ATACVisual/ModelRoot") as Node3D
	var start_position := attacker.position
	var direction := (target.position - attacker.position).normalized()
	var thrust_position := start_position + direction * 0.72
	var arm := attacker.get_node_or_null("ATACVisual/ModelRoot/RightArmPivot") as Node3D
	var weapon := (
		attacker.get_node_or_null("ATACVisual/ModelRoot/RightArmPivot/WeaponPivot") as Node3D
	)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if body != null:
		tween.parallel().tween_property(body, "rotation_degrees:x", -9.0, 0.15)
	if arm != null:
		tween.tween_property(arm, "rotation_degrees", Vector3(-78, 0, -10), 0.15)
	else:
		tween.tween_interval(0.15)
	if weapon != null:
		tween.parallel().tween_property(weapon, "rotation_degrees", Vector3(92, 0, 0), 0.15)
	tween.tween_property(attacker, "position", thrust_position, 0.20)
	tween.parallel().tween_callback(
		Callable(self, "_spawn_lunge_effect").bind(
			target.global_position + Vector3(0, 1.0, 0), direction
		)
	)
	tween.tween_property(attacker, "position", start_position, 0.25)
	if arm != null:
		tween.parallel().tween_property(arm, "rotation_degrees", Vector3.ZERO, 0.25)
	if weapon != null:
		tween.parallel().tween_property(weapon, "rotation_degrees", Vector3(4, 0, -7), 0.25)
	if body != null:
		tween.parallel().tween_property(body, "rotation_degrees:x", 0.0, 0.25)
	await tween.finished


func _face_target(attacker: Node3D, target: Node3D) -> void:
	var direction := target.position - attacker.position
	attacker.rotation.y = atan2(direction.x, direction.z)


func _calculate_damage(attacker: Node3D, target: Node3D, multiplier: float) -> int:
	var attack_stats := _stats(attacker)
	var target_stats := _stats(target)
	var strength := _effective_stat(attack_stats, "strength")
	var defense := _effective_stat(target_stats, "defense")
	var weapon_power := int(attack_stats.get("weapon_power", 0))
	var skill := int(attack_stats.get("attack_skill", 0))
	var base_damage := strength + weapon_power + int(skill * 0.45) - int(defense * 0.72)
	base_damage += rng.randi_range(-2, 3)
	return max(1, int(float(base_damage) * multiplier))


func _effective_stat(stats: Dictionary, key: String) -> int:
	var value := int(stats.get(key, 0))
	var equipment_bonus: Dictionary = stats.get("equipment_bonus", {})
	var amulet_bonus: Dictionary = stats.get("amulet_bonus", {})
	value += int(equipment_bonus.get(key, 0))
	value += int(amulet_bonus.get(key, 0))
	return value


func _resolve_attack(attacker: Node3D, target: Node3D, mode: String) -> void:
	if not _is_alive(target):
		return
	var back_attack := _is_back_attack(attacker, target)
	var reaction := "none"
	if target == player_unit and str(attacker.get_meta("team")) == "enemy":
		reaction = await _request_player_reaction(attacker, back_attack)
	if reaction == "reflect" and not back_attack:
		var reflect_chance := _reflection_chance(target, attacker)
		if rng.randf() <= reflect_chance:
			status_label.text = "Alba отражает атаку!"
			await _animate_reflect(target, attacker)
			await _damage_target(attacker, max(1, int(_calculate_damage(target, attacker, 0.70))))
			return
	if reaction == "dodge":
		var evade_chance := _evasion_chance(target, attacker)
		if rng.randf() <= evade_chance:
			status_label.text = "%s увернулся!" % str(target.get_meta("label"))
			await _animate_dodge(target)
			return
	var multiplier := 1.0
	if mode in ["lunge", "long_lunge"]:
		multiplier = 1.22
	elif mode == "ball_lightning":
		multiplier = 1.52
	var damage := _calculate_damage(attacker, target, multiplier)
	if reaction == "defend" and not back_attack:
		damage = max(1, int(float(damage) * 0.55))
	elif reaction == "defend" and back_attack:
		status_label.text = "Удар со спины: защита невозможна!"
	await _damage_target(target, damage)


func _reflection_chance(defender: Node3D, attacker: Node3D) -> float:
	var defender_strength := _effective_stat(_stats(defender), "strength")
	var attacker_strength := _effective_stat(_stats(attacker), "strength")
	if attacker_strength > defender_strength:
		return max(0.12, 0.29 - float(attacker_strength - defender_strength) * 0.025)
	return min(0.82, 0.60 + float(defender_strength - attacker_strength) * 0.02)


func _evasion_chance(defender: Node3D, attacker: Node3D) -> float:
	var delta := (
		_effective_stat(_stats(defender), "agility") - _effective_stat(_stats(attacker), "agility")
	)
	return clamp(0.35 + float(delta) * 0.025, 0.12, 0.72)


func _is_back_attack(attacker: Node3D, target: Node3D) -> bool:
	var direction_to_attacker := (attacker.position - target.position).normalized()
	var target_forward := -target.global_transform.basis.z.normalized()
	return target_forward.dot(direction_to_attacker) < -0.42


func _damage_target(target: Node3D, damage: int) -> void:
	if not is_instance_valid(target):
		return
	var stats := _stats(target)
	stats["hp"] = max(0, int(stats["hp"]) - damage)
	target.set_meta("stats", stats)
	_refresh_hp_bar(target)
	_spawn_damage_label(target.global_position + Vector3(0, 2.30, 0), damage)
	var visual := target.get_node_or_null("ATACVisual") as Node3D
	if visual != null:
		var original_scale := visual.scale
		var hit_tween := create_tween()
		hit_tween.tween_property(visual, "scale", original_scale * Vector3(1.10, 0.90, 1.10), 0.07)
		hit_tween.tween_property(visual, "scale", original_scale, 0.12)
	if int(stats["hp"]) <= 0:
		var defeat_position: Vector3 = target.global_position
		status_label.text = "%s уничтожен" % str(target.get_meta("label"))
		var death_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		death_tween.tween_property(target, "rotation_degrees:z", 82.0, 0.34)
		death_tween.parallel().tween_property(target, "position:y", target.position.y - 0.22, 0.34)
		death_tween.tween_property(target, "scale", Vector3.ZERO, 0.24)
		await death_tween.finished
		# Hide every visual explicitly.  The old 2.5D renderer used a top-level
		# camera-facing child, so scaling the unit to zero did not always remove it.
		_mark_defeated_invisible(target)
		if str(target.get_meta("team")) == "enemy":
			if not bool(target.get_meta("coin_rewarded", false)):
				target.set_meta("coin_rewarded", true)
				var coin_reward: int = CampaignState.award_atac_elimination(
					str(target.get_meta("model_slug", "")), bool(target.get_meta("commander", false))
				)
				_spawn_coin_reward_label(defeat_position + Vector3(0, 2.75, 0), coin_reward)
				_refresh_coin_display()
				status_label.text = "%s уничтожен • +%d монет" % [str(target.get_meta("label")), coin_reward]
			defeated_enemy_count += 1
			if (
				str(map_data.get("id", "")) == "mission_01_border_village"
				and defeated_enemy_count == 1
				and not kamorge_spawned
			):
				await _spawn_kamorge_event()
		call_deferred("_finalize_defeated_unit", target)
	_refresh_ui()


func _mark_defeated_invisible(unit: Node3D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	unit.set_meta("defeated", true)
	unit.visible = false
	unit.set_process(false)
	unit.set_physics_process(false)
	var visual: Node3D = unit.get_node_or_null("ATACVisual") as Node3D
	if visual != null:
		visual.visible = false
	var hp_bar: Node3D = unit.get_node_or_null("HPBar") as Node3D
	if hp_bar != null:
		hp_bar.visible = false
	var ring: Node3D = unit.get_node_or_null("SelectionRing") as Node3D
	if ring != null:
		ring.visible = false
	unit.set_meta("cell", Vector2i(-9999, -9999))
	if selected_unit == unit:
		selected_unit = null


func _finalize_defeated_unit(unit: Node3D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	units.erase(unit)
	if unit.get_parent() != null:
		unit.queue_free()


func _spawn_damage_label(world_position: Vector3, damage: int) -> void:
	var label := Label3D.new()
	label.text = "-%d" % damage
	label.font_size = 64
	label.outline_size = 10
	label.modulate = Color(1.0, 0.25, 0.16)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = world_position
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.75, 0.65)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.65)
	tween.tween_callback(Callable(label, "queue_free"))


func _spawn_slash_effect(world_position: Vector3) -> void:
	var effect := Node3D.new()
	effect.position = world_position
	add_child(effect)
	for index in range(3):
		var arc := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.46 + index * 0.08
		torus.outer_radius = 0.52 + index * 0.08
		torus.rings = 28
		torus.ring_segments = 6
		arc.mesh = torus
		arc.rotation_degrees = Vector3(68, 18 + index * 9, 20 - index * 11)
		arc.scale = Vector3(1.0, 0.42, 1.0)
		arc.material_override = _effect_material(Color(0.66, 0.92, 1.0, 0.76 - index * 0.14))
		effect.add_child(arc)
	var tween := create_tween()
	effect.scale = Vector3.ONE * 0.30
	tween.tween_property(effect, "scale", Vector3.ONE * 1.30, 0.15)
	tween.parallel().tween_property(effect, "rotation_degrees", Vector3(0, 55, 0), 0.15)
	tween.tween_property(effect, "scale", Vector3.ONE * 0.08, 0.20)
	tween.tween_callback(Callable(effect, "queue_free"))


func _spawn_lunge_effect(world_position: Vector3, direction: Vector3) -> void:
	var effect := Node3D.new()
	effect.position = world_position - direction * 0.30
	effect.look_at(world_position + direction, Vector3.UP)
	add_child(effect)
	for index in range(4):
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.055 + index * 0.018, 0.055 + index * 0.018, 0.80 + index * 0.18)
		streak.mesh = mesh
		streak.position = Vector3((index - 1.5) * 0.08, (index % 2) * 0.08, -index * 0.06)
		streak.material_override = _effect_material(Color(0.75, 0.96, 1.0, 0.80 - index * 0.12))
		effect.add_child(streak)
	var light := OmniLight3D.new()
	light.light_color = Color(0.46, 0.88, 1.0)
	light.light_energy = 4.5
	light.omni_range = 2.2
	effect.add_child(light)
	var tween := create_tween()
	effect.scale = Vector3(0.25, 0.25, 0.25)
	tween.tween_property(effect, "scale", Vector3(1.25, 1.25, 1.25), 0.12)
	tween.tween_property(effect, "scale", Vector3(0.05, 0.05, 0.05), 0.18)
	tween.tween_callback(Callable(effect, "queue_free"))


func _spawn_guard_effect(world_position: Vector3) -> void:
	var effect := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.70
	sphere.height = 1.40
	sphere.radial_segments = 18
	sphere.rings = 10
	effect.mesh = sphere
	effect.position = world_position
	effect.material_override = _effect_material(Color(0.25, 0.70, 1.0, 0.24))
	add_child(effect)
	effect.scale = Vector3.ONE * 0.25
	var tween := create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 1.25, 0.20)
	tween.tween_interval(0.18)
	tween.tween_property(effect, "scale", Vector3.ZERO, 0.22)
	tween.tween_callback(Callable(effect, "queue_free"))


func _effect_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b) * 2.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _toggle_ability_menu() -> void:
	_close_attack_menu()
	ability_menu.visible = not ability_menu.visible
	reflect_button.disabled = not reaction_waiting or reaction_back_attack
	reflect_button.text = "Отразить атаку — реакция" if not reaction_waiting else "Отразить атаку"


func _close_ability_menu() -> void:
	ability_menu.visible = false


func _choose_reflect_ability() -> void:
	if reaction_waiting and not reaction_back_attack:
		_finish_reaction("reflect")
	else:
		status_label.text = "«Отразить атаку» доступно только как реакция на фронтальное нападение."
		_close_ability_menu()


func _open_reaction_ability() -> void:
	ability_menu.visible = true
	reflect_button.disabled = reaction_back_attack
	reflect_button.text = (
		"Отразить атаку" if not reaction_back_attack else "Отражение невозможно со спины"
	)


func _request_player_reaction(attacker: Node3D, back_attack: bool) -> String:
	reaction_waiting = true
	reaction_back_attack = back_attack
	reaction_menu.visible = true
	reaction_title.text = (
		"%s атакует%s" % [str(attacker.get_meta("label")), " со спины" if back_attack else ""]
	)
	reaction_defend_button.disabled = back_attack
	reaction_ability_button.disabled = back_attack
	reaction_dodge_button.disabled = not _can_spend_fatigue(player_unit, FATIGUE_DODGE)
	status_label.text = "Выберите реакцию на атаку."
	await reaction_chosen
	var choice := pending_reaction_choice
	reaction_waiting = false
	reaction_menu.visible = false
	ability_menu.visible = false
	if choice == "dodge":
		_spend_fatigue(player_unit, FATIGUE_DODGE)
	return choice


func _finish_reaction(choice: String) -> void:
	if not reaction_waiting:
		return
	pending_reaction_choice = choice
	reaction_chosen.emit()


func _animate_dodge(unit: Node3D) -> void:
	var start := unit.position
	var side := unit.global_transform.basis.x.normalized() * 0.32
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "position", start + side, 0.11)
	tween.tween_property(unit, "position", start - side * 0.35, 0.10)
	tween.tween_property(unit, "position", start, 0.14)
	await tween.finished


func _animate_reflect(defender: Node3D, attacker: Node3D) -> void:
	_face_target(defender, attacker)
	var weapon := (
		defender.get_node_or_null("ATACVisual/ModelRoot/RightArmPivot/WeaponPivot") as Node3D
	)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if weapon != null:
		tween.tween_property(weapon, "rotation_degrees", Vector3(0, 0, 72), 0.13)
		tween.tween_property(weapon, "rotation_degrees", Vector3(0, 0, -38), 0.12)
		tween.tween_property(weapon, "rotation_degrees", Vector3.ZERO, 0.18)
	else:
		tween.tween_interval(0.40)
	_spawn_guard_effect(defender.global_position + Vector3(0, 1.1, 0))
	await tween.finished


func _run_ally_phase() -> void:
	if kamorge_unit == null or not _is_alive(kamorge_unit) or _all_enemies_defeated():
		await _run_enemy_phase()
		return
	phase = Phase.ALLY_TURN
	phase_label.text = "ХОД KAMORGE"
	phase_label.modulate = Color(0.55, 1.0, 0.64)
	action_in_progress = true
	_recover_fatigue(kamorge_unit, FATIGUE_RECOVERY)
	_recover_energy(kamorge_unit, 10)
	_select_unit(kamorge_unit)
	status_label.text = "Kamorge самостоятельно атакует имперских солдат."
	var target := _nearest_enemy(kamorge_unit)
	if target != null:
		var distance := _grid_distance(kamorge_unit, target)
		if distance > 1:
			var goals := _free_adjacent_cells(target, kamorge_unit)
			var path := _find_path_to_any(kamorge_unit.get_meta("cell"), goals, kamorge_unit)
			var steps: int = mini(int(_stats(kamorge_unit).get("move_range", 5)), path.size())
			if steps > 0:
				await _animate_path(kamorge_unit, path.slice(0, steps), 0.15)
		distance = _grid_distance(kamorge_unit, target)
		if distance == 1 and _is_alive(target):
			if _can_spend_energy(kamorge_unit, ENERGY_BALL_LIGHTNING):
				await _animate_ball_lightning(kamorge_unit, target)
				_spend_energy(kamorge_unit, ENERGY_BALL_LIGHTNING)
				await _resolve_attack(kamorge_unit, target, "ball_lightning")
			else:
				await _animate_lunge(kamorge_unit, target)
				await _resolve_attack(kamorge_unit, target, "lunge")
	action_in_progress = false
	if _all_enemies_defeated():
		_show_victory()
		return
	await _run_enemy_phase()


func _nearest_enemy(from_unit: Node3D) -> Node3D:
	var best: Node3D
	var best_distance := 999
	for unit in units:
		if str(unit.get_meta("team")) != "enemy" or not _is_alive(unit):
			continue
		var distance := _grid_distance(from_unit, unit)
		if distance < best_distance:
			best_distance = distance
			best = unit
	return best


func _nearest_living_ally(from_unit: Node3D) -> Node3D:
	var best: Node3D
	var best_distance := 999
	for unit in units:
		if str(unit.get_meta("team")) != "ally" or not _is_alive(unit):
			continue
		var distance := _grid_distance(from_unit, unit)
		if distance < best_distance:
			best_distance = distance
			best = unit
	return best


func _spawn_kamorge_event() -> void:
	kamorge_spawned = true
	phase = Phase.DIALOGUE
	action_in_progress = true
	_clear_highlights()
	await _show_dialogue(
		"Kamorge",
		"Ах вот ты где?!? Я пошёл найти дров, а ты удрал, удрал спасать деревню!",
		KAMORGE_PORTRAIT
	)
	await _show_dialogue("Bastion", "Отец, я справлюсь, не переживай за меня!", PLAYER_PORTRAIT)
	await _show_dialogue("Kamorge", "Ну уж нет, я иду.", KAMORGE_PORTRAIT)
	var spawn_cell := _array_to_cell(map_data.get("kamorge_spawn", [2, 9]))
	while _unit_at(spawn_cell) != null or blocked_cells.has(spawn_cell):
		spawn_cell += Vector2i.LEFT
	kamorge_unit = _spawn_unit(
		"Kamorge / Barazaph",
		"Отец Bastion • союзный ИИ",
		"barazaph",
		spawn_cell,
		false,
		false,
		"ally",
		"kamorge_barazaph"
	)
	_spawn_arrival_effect(kamorge_unit.global_position + Vector3(0, 1.1, 0))
	_select_unit(kamorge_unit)
	status_label.text = "Kamorge присоединился к бою и действует самостоятельно."
	await get_tree().create_timer(0.7).timeout
	action_in_progress = false


func _show_dialogue(speaker_name: String, text: String, portrait_path: String) -> void:
	dialogue_panel.visible = true
	dialogue_speaker.text = speaker_name
	dialogue_text.text = text
	dialogue_portrait.texture = load(portrait_path)
	await dialogue_advanced
	dialogue_panel.visible = false


func _animate_ball_lightning(attacker: Node3D, target: Node3D) -> void:
	status_label.text = "%s использует «Шаровая молния»" % str(attacker.get_meta("label"))
	_face_target(attacker, target)
	var origin := attacker.global_position + Vector3(0, 1.15, 0)
	var finish := target.global_position + Vector3(0, 1.10, 0)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	orb.mesh = sphere
	orb.position = origin
	orb.material_override = _effect_material(Color(0.46, 0.75, 1.0, 0.95))
	add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = Color(0.38, 0.72, 1.0)
	light.light_energy = 7.0
	light.omni_range = 2.6
	orb.add_child(light)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(orb, "scale", Vector3.ONE * 1.65, 0.18)
	tween.tween_property(orb, "position", finish, 0.24)
	tween.tween_callback(Callable(self, "_spawn_lightning_impact").bind(finish))
	tween.tween_property(orb, "scale", Vector3.ZERO, 0.10)
	tween.tween_callback(Callable(orb, "queue_free"))
	await tween.finished


func _spawn_lightning_impact(position: Vector3) -> void:
	var root := Node3D.new()
	root.position = position
	add_child(root)
	for index in range(4):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.20 + index * 0.09
		torus.outer_radius = 0.24 + index * 0.09
		torus.rings = 24
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation_degrees = Vector3(35 + index * 17, index * 37, 18)
		ring.material_override = _effect_material(Color(0.58, 0.84, 1.0, 0.85 - index * 0.12))
		root.add_child(ring)
	var tween := create_tween()
	root.scale = Vector3.ONE * 0.2
	tween.tween_property(root, "scale", Vector3.ONE * 1.45, 0.15)
	tween.tween_property(root, "scale", Vector3.ZERO, 0.18)
	tween.tween_callback(Callable(root, "queue_free"))


func _spawn_arrival_effect(position: Vector3) -> void:
	_spawn_lightning_impact(position)


func _can_spend_energy(unit: Node3D, cost: int) -> bool:
	return int(_stats(unit).get("energy", 0)) >= cost


func _spend_energy(unit: Node3D, cost: int) -> void:
	var stats := _stats(unit)
	stats["energy"] = max(0, int(stats.get("energy", 0)) - cost)
	unit.set_meta("stats", stats)
	_refresh_ui()


func _recover_energy(unit: Node3D, amount: int) -> void:
	var stats := _stats(unit)
	var maximum := int(stats.get("max_energy", 0))
	if maximum <= 0:
		return
	stats["energy"] = min(maximum, int(stats.get("energy", 0)) + amount)
	unit.set_meta("stats", stats)


func _show_reachable_cells(unit: Node3D, move_range: int) -> void:
	_clear_highlights()
	reachable_cells = _reachable_from(unit.get_meta("cell"), move_range, unit)
	highlight_root = Node3D.new()
	highlight_root.name = "MovementHighlights"
	add_child(highlight_root)
	for cell_value in reachable_cells.keys():
		var cell: Vector2i = cell_value
		if cell == unit.get_meta("cell"):
			continue
		var marker := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.88, 0.035, 0.88)
		marker.mesh = mesh
		marker.position = _cell_to_world(cell) + Vector3(0, 0.11, 0)
		marker.material_override = _highlight_material(Color(0.20, 0.92, 0.48, 0.48))
		highlight_root.add_child(marker)


func _clear_highlights() -> void:
	reachable_cells.clear()
	if highlight_root != null and is_instance_valid(highlight_root):
		highlight_root.queue_free()
	highlight_root = null


func _reachable_from(start: Vector2i, max_steps: int, moving_unit: Node3D) -> Dictionary:
	var result := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var distance := int(result[current])
		if distance >= max_steps:
			continue
		for neighbor in _neighbors(current):
			if not _can_enter(neighbor, moving_unit, start):
				continue
			if result.has(neighbor):
				continue
			result[neighbor] = distance + 1
			queue.append(neighbor)
	return result


func _find_path(start: Vector2i, goal: Vector2i, moving_unit: Node3D) -> Array:
	if start == goal:
		return []
	var queue: Array[Vector2i] = [start]
	var parents := {start: start}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for neighbor in _neighbors(current):
			if parents.has(neighbor):
				continue
			if neighbor != goal and not _can_enter(neighbor, moving_unit, start):
				continue
			if neighbor == goal and (_unit_at(neighbor) != null or blocked_cells.has(neighbor)):
				continue
			parents[neighbor] = current
			if neighbor == goal:
				return _reconstruct_path(parents, start, goal)
			queue.append(neighbor)
	return []


func _find_path_to_any(start: Vector2i, goals: Array, moving_unit: Node3D) -> Array:
	if goals.has(start):
		return []
	var goal_set := {}
	for goal in goals:
		goal_set[goal] = true
	var queue: Array[Vector2i] = [start]
	var parents := {start: start}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for neighbor in _neighbors(current):
			if parents.has(neighbor) or not _can_enter(neighbor, moving_unit, start):
				continue
			parents[neighbor] = current
			if goal_set.has(neighbor):
				return _reconstruct_path(parents, start, neighbor)
			queue.append(neighbor)
	return []


func _reconstruct_path(parents: Dictionary, start: Vector2i, goal: Vector2i) -> Array:
	var reversed_path: Array[Vector2i] = []
	var cursor := goal
	while cursor != start:
		reversed_path.append(cursor)
		cursor = parents[cursor]
	reversed_path.reverse()
	return reversed_path


func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]


func _can_enter(cell: Vector2i, moving_unit: Node3D, start: Vector2i) -> bool:
	if not _cell_in_bounds(cell) or blocked_cells.has(cell):
		return false
	var occupant := _unit_at(cell)
	return occupant == null or occupant == moving_unit or cell == start


func _free_adjacent_cells(target: Node3D, moving_unit: Node3D) -> Array:
	var result: Array = []
	var target_cell: Vector2i = target.get_meta("cell")
	for cell in _neighbors(target_cell):
		if _can_enter(cell, moving_unit, moving_unit.get_meta("cell")):
			result.append(cell)
	return result


func _player_attack_target(mode: String = "slash") -> Node3D:
	var required_distance := 2 if mode == "long_lunge" else 1
	if (
		selected_unit != null
		and str(selected_unit.get_meta("team")) == "enemy"
		and _is_alive(selected_unit)
	):
		if _grid_distance(player_unit, selected_unit) == required_distance:
			if mode != "long_lunge" or _has_clear_long_lunge_line(player_unit, selected_unit):
				return selected_unit
	for unit in units:
		if str(unit.get_meta("team")) != "enemy" or not _is_alive(unit):
			continue
		if _grid_distance(player_unit, unit) == required_distance:
			if mode != "long_lunge" or _has_clear_long_lunge_line(player_unit, unit):
				return unit
	return null


func _grid_distance(a: Node3D, b: Node3D) -> int:
	if a == null or b == null:
		return 999
	var cell_a: Vector2i = a.get_meta("cell")
	var cell_b: Vector2i = b.get_meta("cell")
	return abs(cell_a.x - cell_b.x) + abs(cell_a.y - cell_b.y)


func _has_clear_long_lunge_line(attacker: Node3D, target: Node3D) -> bool:
	var a: Vector2i = attacker.get_meta("cell")
	var b: Vector2i = target.get_meta("cell")
	if _grid_distance(attacker, target) != 2:
		return false
	if a.x != b.x and a.y != b.y:
		return false
	var middle := Vector2i(int((a.x + b.x) / 2), int((a.y + b.y) / 2))
	return not blocked_cells.has(middle) and _unit_at(middle) == null


func _available_move_range(unit: Node3D) -> int:
	var stats := _stats(unit)
	var remaining := int(stats.get("max_fatigue", 100)) - int(stats.get("fatigue", 0))
	return min(int(stats.get("move_range", 0)), max(0, int(remaining / FATIGUE_MOVE_PER_CELL)))


func _attack_fatigue_cost(mode: String) -> int:
	if mode == "long_lunge":
		return FATIGUE_LONG_LUNGE
	if mode == "lunge":
		return FATIGUE_LUNGE
	if mode == "ball_lightning":
		return 0
	return FATIGUE_SLASH


func _can_spend_fatigue(unit: Node3D, cost: int) -> bool:
	var stats := _stats(unit)
	return int(stats.get("fatigue", 0)) + cost <= int(stats.get("max_fatigue", 100))


func _spend_fatigue(unit: Node3D, cost: int) -> void:
	var stats := _stats(unit)
	stats["fatigue"] = min(int(stats.get("max_fatigue", 100)), int(stats.get("fatigue", 0)) + cost)
	unit.set_meta("stats", stats)
	_refresh_ui()


func _recover_fatigue(unit: Node3D, amount: int) -> void:
	var stats := _stats(unit)
	stats["fatigue"] = max(0, int(stats.get("fatigue", 0)) - amount)
	unit.set_meta("stats", stats)


func _is_adjacent(a: Node3D, b: Node3D) -> bool:
	if a == null or b == null:
		return false
	var cell_a: Vector2i = a.get_meta("cell")
	var cell_b: Vector2i = b.get_meta("cell")
	return abs(cell_a.x - cell_b.x) + abs(cell_a.y - cell_b.y) == 1


func _select_unit(unit: Node3D) -> void:
	selected_unit = unit
	for candidate in units:
		var marker := candidate.get_node_or_null("SelectionRing") as MeshInstance3D
		if marker != null:
			marker.visible = candidate == selected_unit and _is_alive(candidate)
	_refresh_ui()


func _refresh_ui() -> void:
	_refresh_coin_display()
	if selected_unit == null:
		unit_name_label.text = "Юнит не выбран"
		unit_role_label.text = ""
		hp_label.text = ""
		fatigue_label.text = ""
		fatigue_bar.value = 0
		energy_label.text = ""
		energy_bar.value = 0
		stats_label.text = ""
		equipment_label.text = ""
		portrait.texture = null
		unit_info.text = "Юнит не выбран"
		_set_action_buttons(true)
		return
	var stats := _stats(selected_unit)
	var team := str(selected_unit.get_meta("team"))
	var model_slug := str(selected_unit.get_meta("model_slug"))
	if model_slug == "barazaph":
		portrait.texture = load(KAMORGE_PORTRAIT)
	elif team == "ally":
		portrait.texture = load(PLAYER_PORTRAIT)
	else:
		portrait.texture = load(IMPERIAL_PORTRAIT)
	unit_name_label.text = str(selected_unit.get_meta("label"))
	unit_role_label.text = (
		"%s • ATAC %s" % [str(selected_unit.get_meta("role")), str(stats.get("atac_name", "ATAC"))]
	)
	hp_label.text = "HP %d / %d" % [int(stats["hp"]), int(stats["max_hp"])]
	fatigue_label.text = (
		"Усталость %d / %d" % [int(stats.get("fatigue", 0)), int(stats.get("max_fatigue", 100))]
	)
	fatigue_bar.max_value = float(stats.get("max_fatigue", 100))
	fatigue_bar.value = float(stats.get("fatigue", 0))
	var max_energy := int(stats.get("max_energy", 0))
	energy_label.visible = max_energy > 0
	energy_bar.visible = max_energy > 0
	energy_label.text = "Энергия %d / %d" % [int(stats.get("energy", 0)), max_energy]
	energy_bar.max_value = maxi(1, max_energy)
	energy_bar.value = int(stats.get("energy", 0))
	stats_label.text = (
		(
			"Уровень: %d\nСила: %d (+ оружие %d)\nЛовкость: %d\n"
			+ "Защита: %d\nМагия: отключена\nУмение: %s\nХод: %d клеток"
		)
		% [
			int(stats["level"]),
			_effective_stat(stats, "strength"),
			int(stats["weapon_power"]),
			_effective_stat(stats, "agility"),
			_effective_stat(stats, "defense"),
			str(stats.get("ability", "Нет")),
			int(stats["move_range"]),
		]
	)
	equipment_label.text = (
		"Оружие: %s\nСнаряжение: %s\nАмулет: %s"
		% [str(stats["weapon"]), str(stats["equipment"]), str(stats["amulet"])]
	)
	var cell: Vector2i = selected_unit.get_meta("cell")
	unit_info.text = "%s • клетка %d,%d" % [str(selected_unit.get_meta("label")), cell.x, cell.y]
	var player_can_act := (
		phase in [Phase.PLAYER_MOVE, Phase.PLAYER_ACTION]
		and not action_in_progress
		and _is_alive(player_unit)
	)
	var has_target := (
		_player_attack_target("slash") != null or _player_attack_target("long_lunge") != null
	)
	attack_button.disabled = not (player_can_act and has_target)
	ability_button.disabled = not player_can_act
	end_turn_button.disabled = not player_can_act
	defend_button.disabled = true
	dodge_button.disabled = true
	_update_attack_menu_buttons()


func _set_action_buttons(disabled: bool) -> void:
	attack_button.disabled = disabled
	ability_button.disabled = disabled
	end_turn_button.disabled = disabled
	defend_button.disabled = true
	dodge_button.disabled = true
	if disabled:
		_close_attack_menu()
		_close_ability_menu()


func _focus_selected_unit() -> void:
	if selected_unit == null:
		return
	var target := selected_unit.position
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera_rig, "position", Vector3(target.x, 0, target.z), 0.28)


func _show_victory() -> void:
	phase = Phase.VICTORY
	_clear_highlights()
	phase_label.text = "ПОБЕДА"
	phase_label.modulate = Color(0.42, 1.0, 0.55)
	status_label.text = "Все имперские ATAC уничтожены. Первая миссия завершена."
	_set_action_buttons(true)


func _show_defeat() -> void:
	phase = Phase.DEFEAT
	_clear_highlights()
	phase_label.text = "ПОРАЖЕНИЕ"
	phase_label.modulate = Color(1.0, 0.28, 0.22)
	status_label.text = "Alba выведена из строя."
	_set_action_buttons(true)


func _all_enemies_defeated() -> bool:
	for unit in units:
		if str(unit.get_meta("team")) == "enemy" and _is_alive(unit):
			return false
	return true


func _is_alive(unit: Node3D) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	return int((_stats(unit))["hp"]) > 0


func _stats(unit: Node3D) -> Dictionary:
	return unit.get_meta("stats") as Dictionary


func _refresh_hp_bar(unit: Node3D) -> void:
	var label := unit.get_node_or_null("HPBar") as Label3D
	if label == null:
		return
	var stats := _stats(unit)
	label.text = "HP %d" % int(stats["hp"])
	if int(stats["hp"]) <= int(stats["max_hp"]) / 3:
		label.modulate = Color(1.0, 0.32, 0.24)


func _unit_at(cell: Vector2i) -> Node3D:
	for unit in units:
		if _is_alive(unit) and unit.get_meta("cell") == cell:
			return unit
	return null


func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height


func _cell_to_world(cell: Vector2i) -> Vector3:
	var raised_cells := _cell_set(map_data.get("raised_cells", []))
	var elevation := 0.15 if raised_cells.has(cell) else 0.0
	return Vector3(cell.x * TILE_SIZE, 0.07 + elevation, cell.y * TILE_SIZE)


func _cell_set(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		result[_array_to_cell(value)] = true
	return result


func _array_to_cell(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _box_prop(
	parent: Node3D,
	prop_name: String,
	position: Vector3,
	size: Vector3,
	color: Color,
	rotation: Vector3 = Vector3.ZERO,
	emission: bool = false
) -> void:
	var node := MeshInstance3D.new()
	node.name = prop_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.rotation_degrees = rotation
	var material := _prop_material(color, emission)
	node.material_override = material
	parent.add_child(node)


func _prop_material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var key := "%.4f|%.4f|%.4f|%.4f|%s" % [
		color.r, color.g, color.b, color.a, str(emission)
	]
	if shared_prop_materials.has(key):
		return shared_prop_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	if emission:
		material.emission_enabled = true
		material.emission = color * 1.4
	shared_prop_materials[key] = material
	return material


func _highlight_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b) * 0.65
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _apply_zoom() -> void:
	camera.position = Vector3(0, camera_distance * 0.72, camera_distance)
	camera.rotation_degrees.x = -31.0 - clamp((camera_distance - 1.65) * 0.42, 0.0, 10.0)
