extends Control
## Join an existing room by code.

var player_name: String = "Operative"

@onready var _code_edit: LineEdit = %CodeEdit
@onready var _join_button: Button = %JoinButton
@onready var _back_button: Button = %BackButton
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	player_name = SceneManager.pending_join_name
	_join_button.pressed.connect(_on_join)
	_back_button.pressed.connect(func() -> void: SceneManager.go_to_multiplayer_menu())
	NetworkManager.connection_failed.connect(_on_fail)
	NetworkManager.lobby_updated.connect(_on_lobby)
	_code_edit.grab_focus()


func _exit_tree() -> void:
	if NetworkManager.connection_failed.is_connected(_on_fail):
		NetworkManager.connection_failed.disconnect(_on_fail)
	if NetworkManager.lobby_updated.is_connected(_on_lobby):
		NetworkManager.lobby_updated.disconnect(_on_lobby)


func setup(p_name: String) -> void:
	player_name = p_name


func _on_join() -> void:
	_status.text = "Joining…"
	NetworkManager.join_room(_code_edit.text, player_name)


func _on_lobby() -> void:
	if NetworkManager.room_code != "":
		SceneManager.go_to_mp_lobby()


func _on_fail(message: String) -> void:
	_status.text = message
