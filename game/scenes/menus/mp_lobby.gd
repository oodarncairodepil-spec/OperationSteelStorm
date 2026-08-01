extends Control
## Multiplayer lobby: room code, ready state, WebRTC status, host start.

@onready var _room_label: Label = %RoomLabel
@onready var _players_label: Label = %PlayersLabel
@onready var _ready_button: Button = %ReadyButton
@onready var _start_button: Button = %StartButton
@onready var _leave_button: Button = %LeaveButton
@onready var _status_label: Label = %StatusLabel
@onready var _debug_label: Label = %DebugLabel
@onready var _error_label: Label = %ErrorLabel

var _local_ready: bool = false


func _ready() -> void:
	_ready_button.pressed.connect(_on_ready_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	NetworkManager.lobby_updated.connect(_refresh)
	NetworkManager.webrtc_state_changed.connect(func(_s: String) -> void: _refresh())
	NetworkManager.match_ready_changed.connect(func(_r: bool) -> void: _refresh())
	NetworkManager.connection_failed.connect(_on_fail)
	NetworkManager.debug_line.connect(func(_l: String) -> void: _debug_label.text = NetworkManager.get_debug_text())
	_refresh()


func _exit_tree() -> void:
	if NetworkManager.lobby_updated.is_connected(_refresh):
		NetworkManager.lobby_updated.disconnect(_refresh)
	if NetworkManager.connection_failed.is_connected(_on_fail):
		NetworkManager.connection_failed.disconnect(_on_fail)


func _process(_delta: float) -> void:
	_debug_label.text = NetworkManager.get_debug_text()
	_start_button.disabled = not NetworkManager.can_start_match()


func _refresh() -> void:
	_room_label.text = "Room %s" % NetworkManager.room_code
	var lines: PackedStringArray = []
	for p in NetworkManager.lobby_players:
		var mark := "HOST" if bool(p.get("isHost", false)) else "GUEST"
		var ready := "READY" if bool(p.get("ready", false)) else "…"
		lines.append("[%s] %s — %s" % [mark, str(p.get("name", "?")), ready])
	_players_label.text = "\n".join(lines) if not lines.is_empty() else "Waiting for players…"
	_status_label.text = "Signaling: %s | WebRTC: %s" % [NetworkManager.signaling_state, NetworkManager.webrtc_state]
	_start_button.visible = NetworkManager.is_host
	_start_button.disabled = not NetworkManager.can_start_match()
	_ready_button.text = "Unready" if _local_ready else "Ready"
	_error_label.text = NetworkManager.last_error


func _on_ready_pressed() -> void:
	_local_ready = not _local_ready
	NetworkManager.set_ready(_local_ready)
	_refresh()


func _on_start_pressed() -> void:
	NetworkManager.start_match()


func _on_leave_pressed() -> void:
	NetworkManager.leave_room()
	SceneManager.go_to_multiplayer_menu()


func _on_fail(message: String) -> void:
	_error_label.text = message
