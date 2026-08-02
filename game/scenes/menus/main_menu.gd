extends Control
## Main menu for Phase 1 offline entry.
## Expected parent: root. Required: title + buttons.
## Multiplayer authority: none.

@onready var _single_button: Button = %SinglePlayerButton
@onready var _multi_button: Button = %MultiplayerButton
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _install_button: Button = %InstallButton
@onready var _quit_button: Button = %QuitButton
@onready var _hint_label: Label = %HintLabel
@onready var _subtitle_label: Label = %Subtitle
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_single_button.pressed.connect(_on_single)
	_multi_button.pressed.connect(_on_multi)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_install_button.pressed.connect(_on_install)
	_quit_button.pressed.connect(_on_quit)
	_multi_button.disabled = false
	_populate_resolution_options()
	_subtitle_label.text = "Phase 4 — Mission Select + Co-op Mission Select"
	_version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "dev"))
	_hint_label.text = "Single Player opens mission select. Multiplayer opens the co-op room flow, and the host picks the mission in the lobby. Mobile installs run fullscreen and show touch controls."
	if OS.has_feature("web"):
		_quit_button.visible = false
	_install_button.visible = true
	_install_button.disabled = true
	_single_button.grab_focus()
	_call_install_bridge("showInstallButton", [_install_button.get_path()])


func _populate_resolution_options() -> void:
	_resolution_option.clear()
	var options := AppSettings.get_resolution_options()
	for key in [AppSettings.RESOLUTION_COMPACT, AppSettings.RESOLUTION_STANDARD, AppSettings.RESOLUTION_HD]:
		_resolution_option.add_item("Resolution: %s" % options.get(key, key))
		_resolution_option.set_item_metadata(_resolution_option.item_count - 1, key)
		if key == AppSettings.resolution_key:
			_resolution_option.select(_resolution_option.item_count - 1)


func _on_resolution_selected(index: int) -> void:
	var key := str(_resolution_option.get_item_metadata(index))
	AppSettings.set_resolution(key)


func _on_install() -> void:
	_call_install_bridge("promptInstall", [])


func _on_single() -> void:
	SceneManager.go_to_single_player_scene_select()


func _on_multi() -> void:
	SceneManager.go_to_multiplayer_menu()


func _on_quit() -> void:
	get_tree().quit()


func _call_install_bridge(method: String, args: Array) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.operationSteelstormMobile && window.operationSteelstormMobile.%s(%s);" % [method, JSON.stringify(args)])
