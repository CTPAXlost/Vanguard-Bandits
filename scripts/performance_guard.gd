extends Node

const TARGET_FPS: int = 60
const SAMPLE_INTERVAL: float = 2.0
const LOG_PATH: String = "user://performance_v13.log"

var _elapsed: float = 0.0
var _overlay: Label
var _overlay_visible: bool = false
var _log_file: FileAccess
var _safe_mode: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = TARGET_FPS
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 6900
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_create_overlay()
	await get_tree().process_frame
	await get_tree().process_frame
	_write_header()
	_write_snapshot("startup")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < SAMPLE_INTERVAL:
		return
	_elapsed = 0.0
	var text: String = _snapshot_text()
	if _overlay_visible and _overlay != null:
		_overlay.text = _overlay_text()
	_write_line("sample | " + text.replace("\n", " | "))


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
		_set_safe_mode(not _safe_mode)
		get_viewport().set_input_as_handled()


func _overlay_text() -> String:
	return _snapshot_text() + "\nF9 — безопасный режим: %s\nF10 — скрыть монитор" % (
		"ВКЛ" if _safe_mode else "ВЫКЛ"
	)


func _set_safe_mode(enabled: bool) -> void:
	_safe_mode = enabled
	Engine.max_fps = 30 if enabled else TARGET_FPS
	_set_shadows_recursive(get_tree().current_scene, not enabled)
	_write_line("safe_mode | %s | FPS cap %d | shadows %s" % [
		"enabled" if enabled else "disabled",
		Engine.max_fps,
		"off" if enabled else "on",
	])
	if _overlay != null:
		_overlay.visible = true
		_overlay_visible = true
		_overlay.text = _overlay_text()


func _set_shadows_recursive(node: Node, enabled: bool) -> void:
	if node == null:
		return
	if node is Light3D:
		(node as Light3D).shadow_enabled = enabled
	for child: Node in node.get_children():
		_set_shadows_recursive(child, enabled)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_snapshot("close_request")
		if _log_file != null:
			_log_file.flush()
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
	_write_line("Vanguard Bandits Remaster 1.3 performance log")
	_write_line("GPU: %s | Vendor: %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	_write_line("Renderer: %s | Driver: %s | FPS cap: %d | VSync: enabled" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(), TARGET_FPS])
	var memory: Dictionary = OS.get_memory_info()
	_write_line("RAM: physical %.1f GB | free at startup %.1f GB" % [_to_gb(int(memory.get("physical", 0))), _to_gb(int(memory.get("available", memory.get("free", 0))))])


func _write_snapshot(tag: String) -> void:
	_write_line(tag + " | " + _snapshot_text().replace("\n", " | "))


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


func _write_line(text: String) -> void:
	if _log_file == null:
		return
	_log_file.store_line("%s | %s" % [Time.get_datetime_string_from_system(), text])
	_log_file.flush()


func _to_mb(bytes: int) -> float:
	return float(bytes) / 1048576.0


func _to_gb(bytes: int) -> float:
	return float(bytes) / 1073741824.0
