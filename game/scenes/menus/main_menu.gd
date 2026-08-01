extends Control
## Main menu for Phase 1 offline entry.
## Expected parent: root. Required: title + buttons.
## Multiplayer authority: none.

@onready var _single_button: Button = %SinglePlayerButton
@onready var _multi_button: Button = %MultiplayerButton
@onready var _quit_button: Button = %QuitButton
@onready var _hint_label: Label = %HintLabel
@onready var _subtitle_label: Label = %Subtitle
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_single_button.pressed.connect(_on_single)
	_multi_button.pressed.connect(_on_multi)
	_quit_button.pressed.connect(_on_quit)
	_multi_button.disabled = false
	_subtitle_label.text = "Phase 4 — Vertical Slice + Co-op Mission"
	_version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "dev"))
	_hint_label.text = "Single Player starts the Phase 4 mission. Multiplayer starts the co-op Phase 4 mission through the lobby."
	if OS.has_feature("web"):
		_quit_button.visible = false
	_single_button.grab_focus()


func _on_single() -> void:
	SceneManager.go_to_phase4_mission()


func _on_multi() -> void:
	SceneManager.go_to_multiplayer_menu()


func _on_quit() -> void:
	get_tree().quit()
