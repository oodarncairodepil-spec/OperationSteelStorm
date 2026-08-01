class_name NetworkConfigData
extends RefCounted
## Loads multiplayer/network_config.json (+ optional local override).

var signaling_url: String = "ws://127.0.0.1:8787"
var signaling_timeout_ms: int = 15000
var ice_servers: Array = []
var webrtc_timeout_ms: int = 20000
var snapshot_rate_hz: float = 20.0
var max_players: int = 2
var player_name_max_length: int = 16


static func load_from_disk() -> NetworkConfigData:
	var data := NetworkConfigData.new()
	var path := "res://multiplayer/network_config.json"
	var local_path := "res://multiplayer/network_config.local.json"
	var root: Variant = _read_json(path)
	if root is Dictionary:
		data._apply_dict(root as Dictionary)
	if ResourceLoader.exists(local_path) or FileAccess.file_exists(local_path):
		var local_root: Variant = _read_json(local_path)
		if local_root is Dictionary:
			data._apply_dict(local_root as Dictionary)
	data._apply_runtime_overrides()
	return data


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("NetworkConfigData: cannot open %s" % path)
		return null
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	return parsed


func _apply_dict(root: Dictionary) -> void:
	if root.has("signaling") and root["signaling"] is Dictionary:
		var s: Dictionary = root["signaling"]
		signaling_url = str(s.get("url", signaling_url))
		signaling_timeout_ms = int(s.get("connection_timeout_ms", signaling_timeout_ms))
	if root.has("webrtc") and root["webrtc"] is Dictionary:
		var w: Dictionary = root["webrtc"]
		if w.has("ice_servers") and w["ice_servers"] is Array:
			ice_servers = (w["ice_servers"] as Array).duplicate(true)
		webrtc_timeout_ms = int(w.get("connection_timeout_ms", webrtc_timeout_ms))
	if root.has("snapshots") and root["snapshots"] is Dictionary:
		snapshot_rate_hz = float((root["snapshots"] as Dictionary).get("send_rate_hz", snapshot_rate_hz))
	if root.has("lobby") and root["lobby"] is Dictionary:
		var l: Dictionary = root["lobby"]
		max_players = int(l.get("max_players", max_players))
		player_name_max_length = int(l.get("player_name_max_length", player_name_max_length))


func _apply_runtime_overrides() -> void:
	if OS.has_feature("web"):
		signaling_url = _resolve_web_signaling_url(signaling_url)


static func _resolve_web_signaling_url(configured_url: String) -> String:
	if _is_explicit_remote_signaling_url(configured_url):
		return configured_url
	var page_host := _js_value_as_string("window.location.hostname")
	if page_host == "":
		return configured_url
	var page_protocol := _js_value_as_string("window.location.protocol")
	var scheme := "wss" if page_protocol == "https:" else "ws"
	var port := _port_from_url(configured_url, 8787)
	return "%s://%s:%d" % [scheme, page_host, port]


static func _is_explicit_remote_signaling_url(url: String) -> bool:
	if url == "":
		return false
	var host := _host_from_url(url).to_lower()
	if host == "" or host == "localhost" or host == "127.0.0.1" or host == "0.0.0.0" or host == "::1":
		return false
	return true


static func _host_from_url(url: String) -> String:
	var without_scheme := url
	var scheme_index := url.find("://")
	if scheme_index >= 0:
		without_scheme = url.substr(scheme_index + 3)
	var host_port := without_scheme.split("/", false, 1)[0]
	if host_port.begins_with("[") and host_port.contains("]"):
		return host_port.get_slice("]", 0).trim_prefix("[")
	if host_port.contains(":"):
		return host_port.rsplit(":", true, 1)[0]
	return host_port


static func _port_from_url(url: String, fallback: int) -> int:
	var without_scheme := url
	var scheme_index := url.find("://")
	if scheme_index >= 0:
		without_scheme = url.substr(scheme_index + 3)
	var host_port := without_scheme.split("/", false, 1)[0]
	if host_port.contains(":"):
		var raw_port := host_port.rsplit(":", true, 1)[1]
		if raw_port.is_valid_int():
			return int(raw_port)
	return fallback


static func _js_value_as_string(expression: String) -> String:
	var value: Variant = JavaScriptBridge.eval(expression, true)
	return str(value) if value != null else ""


func build_ice_servers_dict() -> Array:
	# Godot WebRTCPeerConnection expects [{ "urls": PackedStringArray or String, ... }]
	var out: Array = []
	for entry in ice_servers:
		if not (entry is Dictionary):
			continue
		var src: Dictionary = entry
		var urls_variant: Variant = src.get("urls", [])
		var urls: PackedStringArray = PackedStringArray()
		if urls_variant is PackedStringArray:
			urls = urls_variant
		elif urls_variant is Array:
			for u in urls_variant:
				urls.append(str(u))
		elif urls_variant is String:
			urls.append(urls_variant)
		var server: Dictionary = {"urls": urls}
		if src.has("username"):
			server["username"] = str(src["username"])
		if src.has("credential"):
			server["credential"] = str(src["credential"])
		out.append(server)
	if out.is_empty():
		out.append({"urls": PackedStringArray(["stun:stun.l.google.com:19302"])})
	return out
