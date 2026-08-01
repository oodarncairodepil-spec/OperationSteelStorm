extends Control
## Join an existing room by code.

var player_name: String = "Operative"

@onready var _name_edit: LineEdit = %NameEdit
@onready var _code_edit: LineEdit = %CodeEdit
@onready var _join_button: Button = %JoinButton
@onready var _back_button: Button = %BackButton
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	player_name = SceneManager.pending_join_name
	_name_edit.text = player_name
	_configure_text_input(_name_edit)
	_configure_text_input(_code_edit)
	_join_button.pressed.connect(_on_join)
	_back_button.pressed.connect(func() -> void: SceneManager.go_to_multiplayer_menu())
	_name_edit.text_submitted.connect(func(_text: String) -> void: _code_edit.grab_focus())
	_code_edit.text_submitted.connect(func(_text: String) -> void: _on_join())
	NetworkManager.connection_failed.connect(_on_fail)
	NetworkManager.lobby_updated.connect(_on_lobby)
	_name_edit.grab_focus()


func _exit_tree() -> void:
	if NetworkManager.connection_failed.is_connected(_on_fail):
		NetworkManager.connection_failed.disconnect(_on_fail)
	if NetworkManager.lobby_updated.is_connected(_on_lobby):
		NetworkManager.lobby_updated.disconnect(_on_lobby)


func setup(p_name: String) -> void:
	player_name = p_name
	if is_instance_valid(_name_edit):
		_name_edit.text = p_name


func _on_join() -> void:
	player_name = _sanitize_player_name(_name_edit.text)
	_name_edit.text = player_name
	SceneManager.pending_join_name = player_name
	_code_edit.text = _code_edit.text.strip_edges().to_upper()
	if _code_edit.text == "":
		_status.text = "Enter a room code."
		_code_edit.grab_focus()
		return
	_status.text = "Joining…"
	NetworkManager.join_room(_code_edit.text, player_name)


func _on_lobby() -> void:
	if NetworkManager.room_code != "":
		SceneManager.go_to_mp_lobby()


func _on_fail(message: String) -> void:
	_status.text = message
	if message.begins_with("duplicate_name:"):
		_name_edit.grab_focus()
		_name_edit.select_all()
	elif _code_edit.text == "":
		_code_edit.grab_focus()


func _configure_text_input(edit: LineEdit) -> void:
	edit.virtual_keyboard_enabled = true
	edit.virtual_keyboard_show_on_focus = true


func _sanitize_player_name(value: String) -> String:
	var cleaned := value.strip_edges()
	return cleaned if cleaned != "" else "Operative"
