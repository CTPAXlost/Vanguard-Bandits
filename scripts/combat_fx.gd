class_name CombatFx
extends RefCounted

# Shared colourful 2.5D combat flourishes for the tactical battlefield.
# Effects stay camera-readable Sprite3D / unshaded mesh bursts — no arena 3D battle.

static func slash_ribbon(parent: Node, world_position: Vector3, color: Color, power: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	root.name = "CombatFx_SlashRibbon"
	root.position = world_position
	_attach(parent, root, 1.4)
	for index: int in range(5):
		var blade := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.04 + index * 0.012, 0.04 + index * 0.008, 0.55 + index * 0.14 * power)
		blade.mesh = mesh
		blade.rotation_degrees = Vector3(-18.0 + index * 9.0, 28.0 - index * 14.0, -42.0 + index * 22.0)
		blade.position = Vector3((index - 2) * 0.05, (index % 3) * 0.04 - 0.04, -index * 0.03)
		blade.material_override = _mat(Color(color.r, color.g, color.b, 0.92 - index * 0.12), true)
		root.add_child(blade)
	_burst_light(root, color, 4.8 * power, 2.4 * power)
	var tween: Tween = parent.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	root.scale = Vector3.ONE * 0.18
	tween.tween_property(root, "scale", Vector3.ONE * (1.15 + power * 0.35), 0.11)
	tween.parallel().tween_property(root, "rotation_degrees:y", 48.0, 0.11)
	tween.tween_property(root, "scale", Vector3.ONE * 0.05, 0.16)
	tween.tween_callback(Callable(root, "queue_free"))


static func thrust_streak(parent: Node, world_position: Vector3, direction: Vector3, color: Color, length: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	root.name = "CombatFx_Thrust"
	root.position = world_position - direction.normalized() * (0.35 * length)
	_attach(parent, root, 1.2)
	if direction.length_squared() > 0.0001:
		root.look_at(world_position + direction.normalized(), Vector3.UP)
	for index: int in range(7):
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.03 + index * 0.008, 0.03 + index * 0.008, 0.55 * length + index * 0.12)
		streak.mesh = mesh
		streak.position = Vector3((index - 3) * 0.04, sin(index * 1.4) * 0.05, -index * 0.05)
		streak.material_override = _mat(Color(color.r, color.g, color.b, 0.94 - index * 0.1), true)
		root.add_child(streak)
	var tip := MeshInstance3D.new()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.14 * length
	tip_mesh.height = 0.28 * length
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0, -0.55 * length)
	tip.material_override = _mat(Color(1.0, 0.95, 0.55, 0.95), true)
	root.add_child(tip)
	_burst_light(root, color, 5.2, 2.6)
	var tween: Tween = parent.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	root.scale = Vector3.ONE * 0.15
	tween.tween_property(root, "scale", Vector3.ONE * (1.05 + length * 0.2), 0.1)
	tween.tween_property(root, "scale", Vector3.ONE * 0.04, 0.16)
	tween.tween_callback(Callable(root, "queue_free"))


static func impact_burst(parent: Node, world_position: Vector3, color: Color, scale_factor: float = 1.0, sparks: int = 14) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	root.name = "CombatFx_Impact"
	root.position = world_position
	_attach(parent, root, 1.3)
	for index: int in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.18 + index * 0.1
		torus.outer_radius = 0.23 + index * 0.1
		torus.rings = 24
		torus.ring_segments = 8
		ring.mesh = torus
		ring.rotation_degrees = Vector3(90.0, index * 40.0, index * 12.0)
		ring.material_override = _mat(Color(color.r, color.g, color.b, 0.86 - index * 0.14), true)
		root.add_child(ring)
	for index: int in range(sparks):
		var spark := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.02, 0.02, 0.16 + float(index % 5) * 0.04)
		spark.mesh = mesh
		spark.rotation_degrees = Vector3(randf_range(-50.0, 50.0), randf_range(0.0, 360.0), randf_range(-70.0, 70.0))
		spark.material_override = _mat(Color(minf(1.0, color.r + 0.2), minf(1.0, color.g + 0.15), minf(1.0, color.b + 0.1), 0.95), true)
		root.add_child(spark)
		var outward := Vector3(randf_range(-1.0, 1.0), randf_range(0.1, 1.0), randf_range(-1.0, 1.0)).normalized()
		var spark_tween: Tween = parent.create_tween().set_parallel(true)
		spark_tween.tween_property(spark, "position", outward * randf_range(0.4, 1.15) * scale_factor, 0.22)
		spark_tween.tween_property(spark, "scale", Vector3.ZERO, 0.24)
	_burst_light(root, color, 7.5 * scale_factor, 3.0 * scale_factor)
	var tween: Tween = parent.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	root.scale = Vector3.ONE * 0.2
	tween.tween_property(root, "scale", Vector3.ONE * scale_factor, 0.14)
	tween.tween_property(root, "scale", Vector3.ZERO, 0.18)
	tween.tween_callback(Callable(root, "queue_free"))


static func magic_orb(parent: Node, origin: Vector3, finish: Vector3, color: Color, radius: float = 0.22) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var orb := MeshInstance3D.new()
	orb.name = "CombatFx_MagicOrb"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	orb.mesh = sphere
	orb.position = origin
	orb.material_override = _mat(Color(color.r, color.g, color.b, 0.96), true)
	_attach(parent, orb, 2.5)
	_burst_light(orb, color, 10.0, 4.0)
	for index: int in range(6):
		var spark := MeshInstance3D.new()
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.035
		spark_mesh.height = 0.07
		spark.mesh = spark_mesh
		var angle: float = TAU * float(index) / 6.0
		spark.position = Vector3(cos(angle) * 0.28, sin(angle * 2.0) * 0.12, sin(angle) * 0.28)
		spark.material_override = _mat(Color(1.0, 1.0, 1.0, 0.85), true)
		orb.add_child(spark)
	orb.scale = Vector3.ZERO
	var charge: Tween = parent.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(orb, "scale", Vector3.ONE * 1.35, 0.28)
	await charge.finished
	if not is_instance_valid(orb):
		return
	var flight: Tween = parent.create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	flight.tween_property(orb, "position", finish, 0.34)
	flight.parallel().tween_property(orb, "scale", Vector3.ONE * 1.7, 0.34)
	await flight.finished
	if is_instance_valid(orb):
		impact_burst(parent, finish, color, 1.25, 16)
		orb.queue_free()


static func hit_flash(visual: Node3D, color: Color = Color(1.0, 0.45, 0.35), duration: float = 0.12) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if visual.has_method("flash"):
		visual.call("flash", color, duration)
		return
	var sprites: Array[Node] = visual.find_children("*", "Sprite3D", true, false)
	for node: Node in sprites:
		var sprite: Sprite3D = node as Sprite3D
		if sprite == null:
			continue
		var original: Color = sprite.modulate
		var tween: Tween = visual.create_tween()
		tween.tween_property(sprite, "modulate", Color(color.r, color.g, color.b, 1.0), duration * 0.35)
		tween.tween_property(sprite, "modulate", original, duration * 0.65)


static func find_atac_sprite(unit: Node3D) -> Sprite3D:
	if unit == null:
		return null
	var paths: Array[String] = [
		"ATACVisual/CameraFacingRoot/ModelRoot/AtacSprite",
		"ATACVisual/ModelRoot/AtacSprite",
	]
	for path: String in paths:
		var sprite: Sprite3D = unit.get_node_or_null(path) as Sprite3D
		if sprite != null and sprite.texture != null:
			return sprite
	var visual: Node3D = unit.get_node_or_null("ATACVisual") as Node3D
	if visual == null:
		return null
	var sprites: Array[Node] = visual.find_children("AtacSprite", "Sprite3D", true, false)
	if not sprites.is_empty():
		return sprites[0] as Sprite3D
	return null


static func _attach(parent: Node, node: Node, lifetime: float) -> void:
	if parent.has_method("_register_transient_fx"):
		parent.call("_register_transient_fx", node, lifetime)
	else:
		parent.add_child(node)


static func _burst_light(parent: Node3D, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	parent.add_child(light)


static func _mat(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 1.8
	return material
