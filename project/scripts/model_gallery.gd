extends Node3D

const AtacFactory = preload("res://scripts/atac_factory.gd")
const MODELS := [
	{"name": "Alba", "slug": "alba", "pilot": "Bastion"},
	{"name": "Barbatos", "slug": "barbatos", "pilot": "Имперский солдат"},
	{"name": "Имперский командирский ATAC", "slug": "imperial_commander", "pilot": "Командир"},
	{"name": "Barazaph", "slug": "barazaph", "pilot": "Kamorge"},
	{"name": "Vedocorban", "slug": "vedocorban", "pilot": "Andrew"},
	{"name": "Неизвестный ATAC", "slug": "cador", "pilot": "Cador"},
	{"name": "Solarus", "slug": "solarus", "pilot": "Faulkner"},
	{"name": "Sarbelas", "slug": "sarbelas", "pilot": "Duyere"},
	{"name": "Einlager", "slug": "einlager", "pilot": "Captain Soldiers"},
	{"name": "Amphisia", "slug": "amphisia", "pilot": "Ione"},
	{"name": "Haurol", "slug": "haurol", "pilot": "Reyna"},
	{"name": "Toreadore", "slug": "toreadore", "pilot": "Zeira"},
	{"name": "Eigol", "slug": "eigol", "pilot": "Kamorge"},
	{"name": "Serata", "slug": "serata", "pilot": "Galvas"},
	{"name": "Glaive", "slug": "glaive", "pilot": "Королевская гвардия"},
]

@onready var pivot: Node3D = $ModelPivot
@onready var camera: Camera3D = $Camera3D
@onready var title: Label = $HUD/Panel/Margin/VBox/Title
@onready var details: Label = $HUD/Panel/Margin/VBox/Details

var current_index := 0
var current_model: Node3D
var camera_distance := 5.2
var dragging := false
var last_mouse := Vector2.ZERO


func _ready() -> void:
	$HUD/Panel/Margin/VBox/Buttons/Previous.pressed.connect(func(): _change_model(-1))
	$HUD/Panel/Margin/VBox/Buttons/Next.pressed.connect(func(): _change_model(1))
	$HUD/Panel/Margin/VBox/Buttons/Back.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
	_build_environment()
	_build_floor()
	_show_model(0)


func _process(delta: float) -> void:
	if not dragging:
		pivot.rotate_y(delta * 0.24)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			last_mouse = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = max(1.45, camera_distance - 0.42)
			_apply_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = min(10.5, camera_distance + 0.42)
			_apply_zoom()
	elif event is InputEventMouseMotion and dragging:
		var delta_mouse := event.position - last_mouse
		pivot.rotate_y(-delta_mouse.x * 0.008)
		pivot.rotate_x(-delta_mouse.y * 0.005)
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-26.0), deg_to_rad(26.0))
		last_mouse = event.position
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT:
			_change_model(-1)
		elif event.keycode == KEY_RIGHT:
			_change_model(1)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.035, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.92)
	env.ambient_light_energy = 0.74
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	$WorldEnvironment.environment = env


func _build_floor() -> void:
	var floor := $Floor as MeshInstance3D
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.7
	mesh.bottom_radius = 1.9
	mesh.height = 0.08
	mesh.radial_segments = 48
	floor.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.10, 0.15)
	material.metallic = 0.28
	material.roughness = 0.52
	floor.material_override = material


func _change_model(direction: int) -> void:
	current_index = posmod(current_index + direction, MODELS.size())
	_show_model(current_index)


func _show_model(index: int) -> void:
	if is_instance_valid(current_model):
		current_model.queue_free()
	pivot.rotation = Vector3(0.0, deg_to_rad(180.0), 0.0)
	var info: Dictionary = MODELS[index]
	var slug := str(info["slug"])
	current_model = AtacFactory.create_atac(slug)
	current_model.scale = Vector3.ONE * 1.28
	pivot.add_child(current_model)
	title.text = "%s — ремастер-модель" % str(info["name"])
	var is_real_3d: bool = bool(current_model.get_meta("real_3d_model", false))
	details.text = (
		"Пилот: %s\n%s"
		% [
			str(info["pilot"]),
			(
				"Оптимизированная статическая GLB-модель с движением всего корпуса и боевыми позами. Скелет, Skin и деформация конечностей пока не добавлены."
				if is_real_3d
				else "Стабильный многовидовой 2.5D-ATAC с фронтальным, боковым, задним и 3/4 ракурсами."
			),
		]
	)


func _apply_zoom() -> void:
	camera.position.z = camera_distance
