extends Node3D

const MultiViewAtacScript = preload("res://scripts/multiview_atac.gd")


func _ready() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.current = true
	camera.position = Vector3(0, 2.5, 6.0)
	add_child(camera)

	var rig := MultiViewAtacScript.new()
	rig.configure("eigol")
	add_child(rig)
	await get_tree().process_frame

	var camera_positions: Array[Vector3] = [
		Vector3(0, 2.5, 6.0),
		Vector3(6.0, 2.5, 0),
		Vector3(0, 2.5, -6.0),
		Vector3(-6.0, 2.5, 0),
	]
	var seen_views: Dictionary = {}
	for camera_position: Vector3 in camera_positions:
		camera.position = camera_position
		camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
		# Force the direction calculation so the smoke test is independent of the
		# headless runner frame time and really covers all four tactical viewpoints.
		rig.call("_sync_camera_facing", camera)
		rig.call("_process_view_direction", camera, true)
		await get_tree().process_frame
		var sprite: Sprite3D = rig.get_node_or_null("CameraFacingRoot/ModelRoot/AtacSprite") as Sprite3D
		if sprite == null or sprite.texture == null or not sprite.visible:
			push_error("TACTICAL_VISIBILITY_SMOKE_FAILED")
			get_tree().quit(1)
			return
		var camera_root: Node3D = rig.get_node_or_null("CameraFacingRoot") as Node3D
		if camera_root == null or not camera_root.top_level:
			push_error("TACTICAL_VISIBILITY_ROOT_FAILED")
			get_tree().quit(1)
			return
		var flat_to_camera: Vector3 = camera.global_position - camera_root.global_position
		flat_to_camera.y = 0.0
		if flat_to_camera.length_squared() > 0.0001:
			flat_to_camera = flat_to_camera.normalized()
			var front_dot: float = camera_root.global_transform.basis.z.normalized().dot(flat_to_camera)
			if front_dot < 0.985:
				push_error("TACTICAL_VISIBILITY_EDGE_ON_FAILED")
				get_tree().quit(1)
				return
		seen_views[str(rig.current_view)] = true

	if seen_views.size() < 3:
		push_error("TACTICAL_VIEW_SWAP_FAILED")
		get_tree().quit(1)
		return
	print("TACTICAL_VISIBILITY_SMOKE_OK")
	get_tree().quit()
