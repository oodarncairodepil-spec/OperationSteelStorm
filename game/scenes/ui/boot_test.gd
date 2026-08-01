extends Control
## Boot / smoke-test scene for Phase 0.
## Purpose: verify project boots, show platform info, unlock input via Start click.
## Expected parent: root viewport (main scene).
## Required children: TitleLabel, InfoLabel, StatusLabel, StartButton, Background.
## Multiplayer authority: none (local UI only).

@onready var _title_label: Label = %TitleLabel
@onready var _info_label: Label = %InfoLabel
@onready var _status_label: Label = %StatusLabel
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_title_label.text = "Operation Steelstorm"
	_info_label.text = _build_info_text()
	_status_label.text = "Waiting for Start…"
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus()


func _build_info_text() -> String:
	var platform := "Native"
	if OS.has_feature("web"):
		platform = "Web (HTML5 / WebAssembly)"
	elif OS.has_feature("mobile"):
		platform = "Mobile"

	var lines: PackedStringArray = [
		"Temporary working title — replaceable later",
		"App version: %s" % str(ProjectSettings.get_setting("application/config/version", "dev")),
		"Godot version: %s" % Engine.get_version_info().string,
		"Platform: %s" % platform,
		"Renderer: Compatibility (GL Compatibility)",
		"Internal resolution: %dx%d" % [
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"),
		],
		"Phase: 4 — Vertical slice mission",
	]
	return "\n".join(lines)


func _on_start_pressed() -> void:
	# Browser audio unlock and input enable happen via this user gesture.
	_status_label.text = "Starting…"
	_start_button.disabled = true
	print("[BootTest] Start pressed — entering main menu")
	SceneManager.go_to_main_menu()
