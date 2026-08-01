extends Control
## Multiplayer hub: create or join a room.

@onready var _name_edit: LineEdit = %NameEdit
@onready var _create_button: Button = %CreateButton
@onready var _join_button: Button = %JoinButton
@onready var _back_button: Button = %BackButton
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_name_edit.text = "Operative"
	_create_button.pressed.connect(_on_create)
	_join_button.pressed.connect(_on_join)
	_back_button.pressed.connect(func() -> void: SceneManager.go_to_main_menu())
	NetworkManager.connection_failed.connect(_on_fail)
	_create_button.grab_focus()


func _exit_tree() -> void:
	if NetworkManager.connection_failed.is_connected(_on_fail):
		NetworkManager.connection_failed.disconnect(_on_fail)
	if NetworkManager.lobby_updated.is_connected(_on_lobby_created):
		NetworkManager.lobby_updated.disconnect(_on_lobby_created)


func _on_create() -> void:
	_status.text = "Connecting to signaling…"
	if not NetworkManager.lobby_updated.is_connected(_on_lobby_created):
		NetworkManager.lobby_updated.connect(_on_lobby_created)
	NetworkManager.create_room(_name_edit.text)


func _on_lobby_created() -> void:
	if NetworkManager.room_code == "":
		return
	if NetworkManager.lobby_updated.is_connected(_on_lobby_created):
		NetworkManager.lobby_updated.disconnect(_on_lobby_created)
	SceneManager.go_to_mp_lobby()


func _on_join() -> void:
	SceneManager.go_to_join_room(_name_edit.text)


func _on_fail(message: String) -> void:
	_status.text = message
