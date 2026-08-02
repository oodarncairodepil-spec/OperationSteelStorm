extends Node
## Global networking: signaling WebSocket + WebRTC mesh + lobby state.
## Responsibility: matchmaking and peer connectivity only — not combat simulation.
## Phase 2: two-player host-authoritative session setup (host = room creator).

signal signaling_state_changed(state: String)
signal lobby_updated
signal webrtc_state_changed(state: String)
signal match_ready_changed(is_ready: bool)
signal connection_failed(message: String)
signal peer_lost(peer_id: int)
signal host_lost
signal debug_line(line: String)

const GODOT_HOST_ID := 1
const GODOT_CLIENT_ID := 2

var config: NetworkConfigData

var signaling_state: String = "disconnected"
var webrtc_state: String = "idle"
var last_error: String = ""

var signaling_peer_id: String = ""
var room_code: String = ""
var player_name: String = ""
var is_host: bool = false
var godot_peer_id: int = 0
var lobby_players: Array[Dictionary] = []
var remote_signaling_id: String = ""
var webrtc_connected: bool = false
var selected_room_scene_id: String = "phase4_beachhead"

var _socket: WebSocketPeer
var _rtc: WebRTCMultiplayerPeer
var _peer_connection: WebRTCPeerConnection
var _ice_buffer: Array[Dictionary] = []
var _offer_started: bool = false
var _connect_deadline_msec: int = 0
var _webrtc_deadline_msec: int = 0


func _ready() -> void:
	config = NetworkConfigData.load_from_disk()
	set_process(true)


func _process(_delta: float) -> void:
	_poll_socket()
	_check_timeouts()


func reset_session() -> void:
	_log("session_reset")
	_pending_action = ""
	_teardown_webrtc()
	_close_socket()
	signaling_peer_id = ""
	room_code = ""
	is_host = false
	godot_peer_id = 0
	lobby_players.clear()
	remote_signaling_id = ""
	webrtc_connected = false
	selected_room_scene_id = "phase4_beachhead"
	last_error = ""
	_set_signaling_state("disconnected")
	_set_webrtc_state("idle")
	lobby_updated.emit()
	match_ready_changed.emit(false)


func connect_signaling() -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return
	config = NetworkConfigData.load_from_disk()
	if config.signaling_config_error != "":
		_fail(config.signaling_config_error)
		return
	if config.signaling_url == "":
		_fail("Signaling server not configured.")
		return
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(config.signaling_url)
	if err != OK:
		_fail("Failed to open signaling socket (%s)." % error_string(err))
		return
	_connect_deadline_msec = Time.get_ticks_msec() + config.signaling_timeout_ms
	_set_signaling_state("connecting")
	_log("signaling_connecting url=%s" % config.signaling_url)


func create_room(p_name: String) -> void:
	reset_session()
	player_name = _clamp_name(p_name)
	is_host = true
	godot_peer_id = GODOT_HOST_ID
	connect_signaling()
	_pending_action = "create"


func join_room(p_code: String, p_name: String) -> void:
	reset_session()
	player_name = _clamp_name(p_name)
	room_code = p_code.strip_edges().to_upper()
	is_host = false
	godot_peer_id = GODOT_CLIENT_ID
	connect_signaling()
	_pending_action = "join"


func set_ready(ready: bool) -> void:
	_send_signal({"type": "set_ready", "ready": ready})


func leave_room() -> void:
	_send_signal({"type": "leave_room"})
	reset_session()


func can_start_match() -> bool:
	return is_host and webrtc_connected and lobby_players.size() >= 2 and _all_ready()


func set_room_scene(scene_id: String) -> void:
	var normalized := _normalize_scene_id(scene_id)
	selected_room_scene_id = normalized
	if room_code == "" or not is_host:
		lobby_updated.emit()
		return
	_send_signal({"type": "set_room_scene", "sceneId": normalized})


func start_match() -> void:
	if not can_start_match():
		_fail("Cannot start match yet (need WebRTC + all ready).")
		return
	rpc_start_match.rpc()


@rpc("authority", "call_local", "reliable")
func rpc_start_match() -> void:
	_log("match_start")
	match selected_room_scene_id:
		"phase4_scene_1_2":
			SceneManager.go_to_mp_phase4_scene_1_2()
		_:
			SceneManager.go_to_mp_phase4_mission()


func get_debug_text() -> String:
	var lines: PackedStringArray = [
		"signaling: %s" % signaling_state,
		"signaling_url: %s" % (config.signaling_url if config != null and config.signaling_url != "" else "-"),
		"webrtc: %s" % webrtc_state,
		"room: %s" % (room_code if room_code != "" else "-"),
		"name: %s" % (player_name if player_name != "" else "-"),
		"host: %s" % str(is_host),
		"signal_id: %s" % (signaling_peer_id if signaling_peer_id != "" else "-"),
		"godot_id: %s" % str(godot_peer_id),
		"remote_signal: %s" % (remote_signaling_id if remote_signaling_id != "" else "-"),
		"peers_lobby: %d" % lobby_players.size(),
		"error: %s" % (last_error if last_error != "" else "-"),
	]
	if config != null and config.signaling_config_error != "":
		lines.append("config_error: %s" % config.signaling_config_error)
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer is WebRTCMultiplayerPeer:
		lines.append("mp_unique: %d" % multiplayer.get_unique_id())
		lines.append("mp_peers: %s" % str(multiplayer.get_peers()))
	return "\n".join(lines)


var _pending_action: String = ""


func _poll_socket() -> void:
	if _socket == null:
		return
	_socket.poll()
	var state := _socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if signaling_state == "connecting":
				_set_signaling_state("open")
			while _socket.get_available_packet_count() > 0:
				var packet := _socket.get_packet()
				_on_signal_packet(packet.get_string_from_utf8())
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			if signaling_state != "disconnected":
				var code := _socket.get_close_code()
				_log("signaling_closed code=%s" % str(code))
				_socket = null
				_set_signaling_state("disconnected")
				if webrtc_connected:
					# Gameplay can continue on WebRTC; lobby signaling lost.
					last_error = "Signaling socket closed."
				else:
					_fail("Signaling disconnected.")


func _on_signal_packet(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_log("invalid_signal_json")
		return
	var msg: Dictionary = parsed
	var type := str(msg.get("type", ""))
	match type:
		"welcome":
			signaling_peer_id = str(msg.get("peerId", ""))
			_log("welcome peerId=%s" % signaling_peer_id)
			_flush_pending_action()
		"room_created":
			room_code = str(msg.get("roomCode", ""))
			is_host = true
			godot_peer_id = GODOT_HOST_ID
			selected_room_scene_id = _normalize_scene_id(str(msg.get("sceneId", "phase4_beachhead")))
			lobby_players = [{
				"peerId": signaling_peer_id,
				"name": player_name,
				"ready": false,
				"isHost": true,
			}]
			_log("room_created code=%s" % room_code)
			lobby_updated.emit()
		"room_joined":
			room_code = str(msg.get("roomCode", ""))
			is_host = bool(msg.get("isHost", false))
			godot_peer_id = GODOT_HOST_ID if is_host else GODOT_CLIENT_ID
			selected_room_scene_id = _normalize_scene_id(str(msg.get("sceneId", "phase4_beachhead")))
			lobby_players.clear()
			var players: Variant = msg.get("players", [])
			if players is Array:
				for p in players:
					if p is Dictionary:
						lobby_players.append((p as Dictionary).duplicate())
			_update_remote_signaling_id()
			_log("room_joined code=%s players=%d" % [room_code, lobby_players.size()])
			lobby_updated.emit()
			_maybe_start_webrtc()
		"player_joined":
			var player: Variant = msg.get("player", {})
			if player is Dictionary:
				_upsert_lobby_player(player as Dictionary)
			_update_remote_signaling_id()
			lobby_updated.emit()
			_log("player_joined")
			_maybe_start_webrtc()
		"player_left":
			var left_id := str(msg.get("peerId", ""))
			_remove_lobby_player(left_id)
			if left_id == remote_signaling_id:
				remote_signaling_id = ""
				_teardown_webrtc()
			lobby_updated.emit()
			_log("player_left id=%s" % left_id)
		"player_ready":
			var pid := str(msg.get("peerId", ""))
			var ready := bool(msg.get("ready", false))
			for i in lobby_players.size():
				if str(lobby_players[i].get("peerId", "")) == pid:
					lobby_players[i]["ready"] = ready
			lobby_updated.emit()
			match_ready_changed.emit(can_start_match())
		"room_scene_changed":
			selected_room_scene_id = _normalize_scene_id(str(msg.get("sceneId", "phase4_beachhead")))
			lobby_updated.emit()
		"host_changed":
			var new_host := str(msg.get("peerId", ""))
			is_host = new_host == signaling_peer_id
			for i in lobby_players.size():
				lobby_players[i]["isHost"] = str(lobby_players[i].get("peerId", "")) == new_host
			lobby_updated.emit()
			_log("host_changed id=%s" % new_host)
		"webrtc_offer":
			_on_remote_offer(str(msg.get("fromPeerId", "")), str(msg.get("sdp", "")))
		"webrtc_answer":
			_on_remote_answer(str(msg.get("fromPeerId", "")), str(msg.get("sdp", "")))
		"webrtc_ice":
			_on_remote_ice(msg)
		"error":
			var code := str(msg.get("code", "error"))
			var message := str(msg.get("message", "Signaling error"))
			_fail("%s: %s" % [code, message])
		"pong":
			pass
		_:
			_log("unknown_signal type=%s" % type)


func _flush_pending_action() -> void:
	if _pending_action == "create":
		_send_signal({"type": "create_room", "playerName": player_name})
	elif _pending_action == "join":
		_send_signal({"type": "join_room", "roomCode": room_code, "playerName": player_name})
	_pending_action = ""


func get_selected_room_scene_label() -> String:
	match selected_room_scene_id:
		"phase4_scene_1_2":
			return "Mission 1-2: High Rescue"
		_:
			return "Mission 1-1: Beachhead"


func _maybe_start_webrtc() -> void:
	if webrtc_connected or _offer_started:
		return
	if lobby_players.size() < 2:
		return
	_update_remote_signaling_id()
	if remote_signaling_id == "":
		return
	_setup_webrtc_mesh()


func _normalize_scene_id(scene_id: String) -> String:
	if scene_id == "phase4_scene_1_2":
		return scene_id
	return "phase4_beachhead"


func _setup_webrtc_mesh() -> void:
	_teardown_webrtc(false)
	_rtc = WebRTCMultiplayerPeer.new()
	var err := _rtc.create_mesh(godot_peer_id)
	if err != OK:
		_fail("WebRTC mesh failed: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = _rtc
	if not multiplayer.peer_connected.is_connected(_on_mp_peer_connected):
		multiplayer.peer_connected.connect(_on_mp_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_mp_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_mp_peer_disconnected)

	var remote_godot := GODOT_CLIENT_ID if is_host else GODOT_HOST_ID
	_peer_connection = WebRTCPeerConnection.new()
	var ice := {"iceServers": config.build_ice_servers_dict()}
	err = _peer_connection.initialize(ice)
	if err != OK:
		_fail("WebRTC initialize failed: %s" % error_string(err))
		return
	_peer_connection.session_description_created.connect(_on_session_description_created)
	_peer_connection.ice_candidate_created.connect(_on_ice_candidate_created)
	err = _rtc.add_peer(_peer_connection, remote_godot)
	if err != OK:
		_fail("WebRTC add_peer failed: %s" % error_string(err))
		return

	_webrtc_deadline_msec = Time.get_ticks_msec() + config.webrtc_timeout_ms
	_set_webrtc_state("connecting")
	_log("webrtc_mesh local=%d remote=%d offerer=%s" % [godot_peer_id, remote_godot, str(is_host)])

	if is_host:
		_offer_started = true
		err = _peer_connection.create_offer()
		if err != OK:
			_fail("create_offer failed: %s" % error_string(err))


func _on_session_description_created(type: String, sdp: String) -> void:
	if _peer_connection == null:
		return
	_peer_connection.set_local_description(type, sdp)
	if type == "offer":
		_send_signal({
			"type": "webrtc_offer",
			"targetPeerId": remote_signaling_id,
			"sdp": sdp,
		})
		_log("sent_offer")
	elif type == "answer":
		_send_signal({
			"type": "webrtc_answer",
			"targetPeerId": remote_signaling_id,
			"sdp": sdp,
		})
		_log("sent_answer")


func _on_ice_candidate_created(media: String, index: int, candidate_name: String) -> void:
	_send_signal({
		"type": "webrtc_ice",
		"targetPeerId": remote_signaling_id,
		"candidate": candidate_name,
		"sdpMid": media,
		"sdpMLineIndex": index,
	})


func _on_remote_offer(from_id: String, sdp: String) -> void:
	if from_id != "" and remote_signaling_id == "":
		remote_signaling_id = from_id
	if _peer_connection == null:
		_setup_webrtc_mesh()
	if _peer_connection == null:
		return
	var err := _peer_connection.set_remote_description("offer", sdp)
	if err != OK:
		_fail("set_remote_description(offer) failed: %s" % error_string(err))
		return
	_flush_ice_buffer()
	_log("got_offer")


func _on_remote_answer(from_id: String, sdp: String) -> void:
	if _peer_connection == null:
		return
	var err := _peer_connection.set_remote_description("answer", sdp)
	if err != OK:
		_fail("set_remote_description(answer) failed: %s" % error_string(err))
		return
	_flush_ice_buffer()
	_log("got_answer from=%s" % from_id)


func _on_remote_ice(msg: Dictionary) -> void:
	var candidate := str(msg.get("candidate", ""))
	var mid: Variant = msg.get("sdpMid", "")
	var index: Variant = msg.get("sdpMLineIndex", 0)
	var ice := {
		"candidate": candidate,
		"sdpMid": str(mid) if mid != null else "",
		"sdpMLineIndex": int(index) if index != null else 0,
	}
	if _peer_connection == null:
		_ice_buffer.append(ice)
		return
	_add_ice(ice)


func _flush_ice_buffer() -> void:
	for ice in _ice_buffer:
		_add_ice(ice)
	_ice_buffer.clear()


func _add_ice(ice: Dictionary) -> void:
	if _peer_connection == null:
		return
	_peer_connection.add_ice_candidate(
		str(ice.get("sdpMid", "")),
		int(ice.get("sdpMLineIndex", 0)),
		str(ice.get("candidate", "")),
	)


func _on_mp_peer_connected(id: int) -> void:
	webrtc_connected = true
	_set_webrtc_state("connected")
	_log("peer_connected id=%d" % id)
	match_ready_changed.emit(can_start_match())


func _on_mp_peer_disconnected(id: int) -> void:
	_log("peer_disconnected id=%d" % id)
	webrtc_connected = false
	_set_webrtc_state("disconnected")
	peer_lost.emit(id)
	if id == GODOT_HOST_ID:
		host_lost.emit()


func _check_timeouts() -> void:
	var now := Time.get_ticks_msec()
	if signaling_state == "connecting" and _connect_deadline_msec > 0 and now > _connect_deadline_msec:
		_fail("Signaling connection timed out.")
		_close_socket()
	if webrtc_state == "connecting" and _webrtc_deadline_msec > 0 and now > _webrtc_deadline_msec and not webrtc_connected:
		_fail("WebRTC connection timed out.")
		_teardown_webrtc()


func _send_signal(payload: Dictionary) -> void:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		# Queue after welcome via pending, or fail.
		if signaling_state == "connecting" or signaling_state == "open":
			_log("signal_deferred type=%s" % str(payload.get("type", "")))
		return
	var text := JSON.stringify(payload)
	_socket.send_text(text)


func _upsert_lobby_player(player: Dictionary) -> void:
	var pid := str(player.get("peerId", ""))
	for i in lobby_players.size():
		if str(lobby_players[i].get("peerId", "")) == pid:
			lobby_players[i] = player.duplicate()
			return
	lobby_players.append(player.duplicate())


func _remove_lobby_player(peer_id: String) -> void:
	for i in range(lobby_players.size() - 1, -1, -1):
		if str(lobby_players[i].get("peerId", "")) == peer_id:
			lobby_players.remove_at(i)


func _update_remote_signaling_id() -> void:
	remote_signaling_id = ""
	for p in lobby_players:
		var pid := str(p.get("peerId", ""))
		if pid != "" and pid != signaling_peer_id:
			remote_signaling_id = pid
			return


func _all_ready() -> bool:
	if lobby_players.size() < 2:
		return false
	for p in lobby_players:
		if not bool(p.get("ready", false)):
			return false
	return true


func _clamp_name(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.is_empty():
		cleaned = "Operative"
	return cleaned.substr(0, config.player_name_max_length)


func _teardown_webrtc(clear_mp: bool = true) -> void:
	_offer_started = false
	_ice_buffer.clear()
	_webrtc_deadline_msec = 0
	webrtc_connected = false
	if _peer_connection != null:
		_peer_connection.session_description_created.disconnect(_on_session_description_created)
		_peer_connection.ice_candidate_created.disconnect(_on_ice_candidate_created)
		_peer_connection.close()
		_peer_connection = null
	if clear_mp:
		if multiplayer.peer_connected.is_connected(_on_mp_peer_connected):
			multiplayer.peer_connected.disconnect(_on_mp_peer_connected)
		if multiplayer.peer_disconnected.is_connected(_on_mp_peer_disconnected):
			multiplayer.peer_disconnected.disconnect(_on_mp_peer_disconnected)
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.close()
			multiplayer.multiplayer_peer = null
		_rtc = null
		_set_webrtc_state("idle")


func _close_socket() -> void:
	if _socket != null:
		_socket.close()
		_socket = null
	_connect_deadline_msec = 0


func _set_signaling_state(state: String) -> void:
	signaling_state = state
	signaling_state_changed.emit(state)


func _set_webrtc_state(state: String) -> void:
	webrtc_state = state
	webrtc_state_changed.emit(state)


func _fail(message: String) -> void:
	last_error = message
	_log("error %s" % message)
	connection_failed.emit(message)


func _log(line: String) -> void:
	print("[NetworkManager] %s" % line)
	debug_line.emit(line)
