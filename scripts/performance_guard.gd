extends Node

const TARGET_FPS: int = 60
const SAFE_FPS: int = 45
const SAMPLE_INTERVAL: float = 5.0
const LOG_FLUSH_INTERVAL: float = 30.0
const FX_CLEANUP_INTERVAL: float = 12.0
const MAX_TRANSIENT_FX: int = 96
const LOG_PATH: String = "user://performance_2_0_1.log"

var _elapsed: float = 0.0
var _flush_elapsed: float = 0.0
var _cleanup_elapsed: float = 0.0
var _overlay: Label
var _overlay_visible: bool = false
var _log_file: FileAccess
var _safe_mode: bool = false
var _low_fps_samples: int = 0
var _startup_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_startup_msec = Time.get_ticks_msec()
	Engine.max_fps = TARGET_FPS
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 6900
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_create_overlay()
	get_tree().node_added.connect(_on_node_added)
	await get_tree().process_frame
	await get_tree().process_frame
	_write_header()
	_write_snapshot("startup")
	_flush_log()


func _process(delta: float) -> void:
	_elapsed += delta
	_flush_elapsed += delta
	_cleanup_elapsed += delta
	if _cleanup_elapsed >= FX_CLEANUP_INTERVAL:
		_cleanup_elapsed = 0.0
		_trim_transient_fx()
	if _flush_elapsed >= LOG_FLUSH_INTERVAL:
		_flush_elapsed = 0.0
		_flush_log()
	if _elapsed < SAMPLE_INTERVAL:
		return
	_elapsed = 0.0
	var fps: int = int(round(Performance.get_monitor(Performance.TIME_FPS)))
	if _overlay_visible and _overlay != null:
		_overlay.text = _overlay_text()
	# Do not flush a line to disk every two seconds. The old monitor kept forcing
	# synchronous writes throughout long battles and amplified stutter on Windows.
	_write_line("sample | " + _snapshot_text().replace("\n", " | "), false)
	_check_automatic_safe_mode(fps)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F10:
		_overlay_visible = not _overlay_visible
		if _overlay != null:
			_overlay.visible = _overlay_visible
			if _overlay_visible:
				_overlay.text = _overlay_text()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F9:
		_set_safe_mode(not _safe_mode, false)
		get_viewport().set_input_as_handled()


func _overlay_text() -> String:
	return _snapshot_text() + "\nF9 — безопасный режим: %s\nF10 — скрыть монитор" % (
		"ВКЛ" if _safe_mode else "ВЫКЛ"
	)


func _check_automatic_safe_mode(fps: int) -> void:
	if _safe_mode or Time.get_ticks_msec() - _startup_msec < 45000:
		return
	if fps > 0 and fps < 32:
		_low_fps_samples += 1
	else:
		_low_fps_samples = maxi(0, _low_fps_samples - 1)
	if _low_fps_samples >= 3:
		_set_safe_mode(true, true)


func _set_safe_mode(enabled: bool, automatic: bool = false) -> void:
	_safe_mode = enabled
	Engine.max_fps = SAFE_FPS if enabled else TARGET_FPS
	_set_shadows_recursive(get_tree().current_scene, not enabled)
	_write_line("safe_mode | %s | source %s | FPS cap %d | shadows %s" % [
		"enabled" if enabled else "disabled",
		"automatic" if automatic else "manual",
		Engine.max_fps,
		"off" if enabled else "on",
	], true)
	if _overlay != null:
		_overlay.visible = true
		_overlay_visible = true
		_overlay.text = _overlay_text()


func _set_shadows_recursive(node: Node, enabled: bool) -> void:
	if node == null:
		return
	if node is Light3D:
		(node as Light3D).shadow_enabled = enabled and node.name == "DirectionalLight3D"
	for child: Node in node.get_children():
		_set_shadows_recursive(child, enabled)


func _on_node_added(node: Node) -> void:
	if not _safe_mode:
		return
	if node is Light3D:
		(node as Light3D).shadow_enabled = false


func _trim_transient_fx() -> void:
	var nodes: Array[Node] = []
	for candidate: Node in get_tree().get_nodes_in_group("vbr_transient_fx"):
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			nodes.append(candidate)
	nodes.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get_meta("vbr_fx_created", 0)) < int(b.get_meta("vbr_fx_created", 0))
	)
	var now: int = Time.get_ticks_msec()
	for node: Node in nodes:
		var lifetime_msec: int = int(node.get_meta("vbr_fx_lifetime_msec", 5000))
		var created: int = int(node.get_meta("vbr_fx_created", now))
		if now - created > lifetime_msec:
			node.queue_free()
	while nodes.size() > MAX_TRANSIENT_FX:
		var oldest: Node = nodes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_snapshot("close_request")
		_flush_log()
		get_tree().quit()


func _create_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "PerformanceOverlay"
	layer.layer = 100
	add_child(layer)
	_overlay = Label.new()
	_overlay.name = "Stats"
	_overlay.visible = false
	_overlay.position = Vector2(12, 96)
	_overlay.add_theme_font_size_override("font_size", 16)
	_overlay.add_theme_color_override("font_color", Color(0.78, 1.0, 0.84))
	_overlay.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_overlay.add_theme_constant_override("shadow_offset_x", 2)
	_overlay.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_overlay)


func _write_header() -> void:
	_write_line("Vanguard Bandits Remaster 2.0.3 performance log", false)
	_write_line("GPU: %s | Vendor: %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()], false)
	_write_line("Renderer: %s | Driver: %s | FPS cap: %d | VSync: enabled" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(), TARGET_FPS], false)
	var memory: Dictionary = OS.get_memory_info()
	_write_line("RAM: physical %.1f GB | free at startup %.1f GB" % [_to_gb(int(memory.get("physical", 0))), _to_gb(int(memory.get("available", memory.get("free", 0))))], false)


func _write_snapshot(tag: String) -> void:
	_write_line(tag + " | " + _snapshot_text().replace("\n", " | "), false)


func _snapshot_text() -> String:
	var fps: int = int(round(Performance.get_monitor(Performance.TIME_FPS)))
	var static_mb: float = _to_mb(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	var process_ms: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var render_setup_ms: float = RenderingServer.get_frame_setup_time_cpu()
	var texture_mb: float = _to_mb(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))
	var buffer_mb: float = _to_mb(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED))
	var draw_calls: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var memory: Dictionary = OS.get_memory_info()
	var free_bytes: int = int(memory.get("available", memory.get("free", 0)))
	var free_gb: float = _to_gb(free_bytes)
	var active_cap: int = int(Engine.max_fps)
	var godot_ram_text: String = "н/д в release" if static_mb <= 0.0 else "%.0f MB" % static_mb
	return "FPS %d/%d | кадр CPU %.2f ms | render setup %.2f ms\nRAM Godot %s | свободно в системе %.1f GB\nVRAM текстуры %.0f MB | буферы %.0f MB\nDraw calls %d | объектов %d\nGPU: %s" % [fps, active_cap, process_ms, render_setup_ms, godot_ram_text, free_gb, texture_mb, buffer_mb, draw_calls, objects, RenderingServer.get_video_adapter_name()]


func _write_line(text: String, flush_now: bool = false) -> void:
	if _log_file == null:
		return
	_log_file.store_line("%s | %s" % [Time.get_datetime_string_from_system(), text])
	if flush_now:
		_flush_log()


func _flush_log() -> void:
	if _log_file != null:
		_log_file.flush()


func _to_mb(bytes: int) -> float:
	return float(bytes) / 1048576.0


func _to_gb(bytes: int) -> float:
	return float(bytes) / 1073741824.0
