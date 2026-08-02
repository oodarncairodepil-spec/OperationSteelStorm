extends Node

const RESOLUTION_COMPACT := "compact"
const RESOLUTION_STANDARD := "standard"
const RESOLUTION_HD := "hd"

const RESOLUTION_OPTIONS := {
	RESOLUTION_COMPACT: Vector2i(512, 288),
	RESOLUTION_STANDARD: Vector2i(640, 360),
	RESOLUTION_HD: Vector2i(1280, 720),
}

const RESOLUTION_LABELS := {
	RESOLUTION_COMPACT: "Below 640x360 (512x288)",
	RESOLUTION_STANDARD: "640x360",
	RESOLUTION_HD: "1280x720",
}

const SETTINGS_PATH := "user://app_settings.cfg"

var resolution_key: String = RESOLUTION_STANDARD


func _ready() -> void:
	load_settings()
	apply_resolution(resolution_key)


func get_resolution_options() -> Dictionary:
	return RESOLUTION_LABELS.duplicate()


func get_resolution_size(key: String = resolution_key) -> Vector2i:
	return RESOLUTION_OPTIONS.get(key, RESOLUTION_OPTIONS[RESOLUTION_STANDARD])


func get_resolution_label(key: String = resolution_key) -> String:
	return RESOLUTION_LABELS.get(key, RESOLUTION_LABELS[RESOLUTION_STANDARD])


func set_resolution(key: String) -> void:
	if not RESOLUTION_OPTIONS.has(key):
		key = RESOLUTION_STANDARD
	resolution_key = key
	apply_resolution(key)
	save_settings()


func apply_resolution(key: String) -> void:
	var size := get_resolution_size(key)
	ProjectSettings.set_setting("display/window/size/window_width_override", size.x)
	ProjectSettings.set_setting("display/window/size/window_height_override", size.y)
	if OS.has_feature("web"):
		get_window().content_scale_size = Vector2i(640, 360)
	else:
		DisplayServer.window_set_size(size)
		get_window().size = size
		get_window().content_scale_size = Vector2i(640, 360)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	resolution_key = str(config.get_value("display", "resolution_key", RESOLUTION_STANDARD))
	if not RESOLUTION_OPTIONS.has(resolution_key):
		resolution_key = RESOLUTION_STANDARD


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "resolution_key", resolution_key)
	config.save(SETTINGS_PATH)
