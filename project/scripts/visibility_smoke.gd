extends Node3D

const AtacFactory = preload("res://scripts/atac_factory.gd")

const SLUGS: Array[String] = [
	"alba", "barbatos", "barazaph", "vedocorban", "cador", "solarus",
	"sarbelas", "einlager", "eigol", "amphisia", "haurol", "toreadore",
	"serata", "glaive",
]


func _ready() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.current = true
	add_child(camera)
	var camera_positions: Array[Vector3] = [
		Vector3(0, 2.5, 6.0),
		Vector3(6.0, 2.5, 0),
		Vector3(0, 2.5, -6.0),
		Vector3(-6.0, 2.5, 0),
	]
	for slug: String in SLUGS:
		var rig: Node3D = AtacFactory.create_atac(slug, "tactical")
		rig.name = "Smoke_%s" % slug
		add_child(rig)
		await get_tree().process_frame

		if not bool(rig.get_meta("real_skeleton", false)):
			_fail("TACTICAL_VISIBILITY_NOT_SKELETAL_%s" % slug)
			return
		var skeleton: Skeleton3D = rig.get_node_or_null("ModelRoot/Skeleton3D") as Skeleton3D
		if skeleton == null or skeleton.get_bone_count() < 20:
			_fail("TACTICAL_VISIBILITY_RIG_FAILED_%s" % slug)
			return
		var meshes: Array[Node] = rig.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() < 18:
			_fail("TACTICAL_VISIBILITY_INCOMPLETE_MODEL_%s" % slug)
			return
		var tested_angles: int = 0
		for camera_position: Vector3 in camera_positions:
			camera.position = camera_position
			camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
			rig.look_at(Vector3(camera_position.x, rig.global_position.y, camera_position.z), Vector3.UP, true)
			await get_tree().process_frame
			if not rig.visible or not rig.is_visible_in_tree():
				_fail("TACTICAL_VISIBILITY_EDGE_ON_FAILED_%s" % slug)
				return
			tested_angles += 1
		if tested_angles != 4:
			_fail("TACTICAL_VIEW_SWAP_FAILED_%s" % slug)
			return
		for pose_name: String in ["slash", "lunge", "strong_slash", "ball_lightning", "hit"]:
			rig.call("set_combat_pose", pose_name, 0.55)
			await get_tree().process_frame
		rig.call("reset_pose")
		rig.queue_free()
		await get_tree().process_frame

	print("TACTICAL_VISIBILITY_SMOKE_OK")
	print("SKELETAL_ATAC_SMOKE_OK")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
