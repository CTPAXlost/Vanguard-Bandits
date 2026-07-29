extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for index: int in range(130):
		var fx: Node3D = Node3D.new()
		fx.name = "TransientFxSmoke_%d" % index
		fx.add_to_group("vbr_transient_fx")
		fx.set_meta("vbr_fx_created", index)
		fx.set_meta("vbr_fx_lifetime_msec", 9999999)
		add_child(fx)
	PerformanceGuard.call("_trim_transient_fx")
	for _frame: int in range(4):
		await get_tree().process_frame
	var active: int = 0
	for candidate: Node in get_tree().get_nodes_in_group("vbr_transient_fx"):
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			active += 1
	if active > 96:
		push_error("PERFORMANCE_SMOKE_FAILED: transient effects were not trimmed: %d" % active)
		get_tree().quit(1)
		return
	if Engine.max_fps > 60:
		push_error("PERFORMANCE_SMOKE_FAILED: FPS cap is missing: %d" % Engine.max_fps)
		get_tree().quit(1)
		return
	print("PERFORMANCE_SMOKE_OK active_fx=%d fps_cap=%d" % [active, Engine.max_fps])
	get_tree().quit(0)
