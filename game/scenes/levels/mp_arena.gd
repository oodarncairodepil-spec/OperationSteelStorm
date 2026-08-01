class_name MpArena
extends Node2D
## Phase 3 co-op combat arena: host-auth shooting, enemies, health, revive.
## Expected parent: scene root via SceneManager.

const NET_PLAYER_SCENE := preload("res://entities/players/net_player.tscn")

@onready var _players_root: Node2D = $Players
@onready var _enemies_root: Node2D = $Enemies
@onready var _spawn_host: Marker2D = $Spawns/HostSpawn
@onready var _spawn_client: Marker2D = $Spawns/ClientSpawn
@onready var _enemy_spawns: Node2D = $EnemySpawns
@onready var _projectile_bucket: Node2D = $ProjectileBucket
@onready var _camera: FollowCamera = $FollowCamera
@onready var _combat: HostCombatSession = $HostCombatSession
@onready var _status: Label = %StatusLabel
@onready var _hud: Label = %HudLabel
@onready var _debug: Label = %DebugLabel
@onready var _result: Label = %ResultLabel
@onready var _disconnect_dialog: AcceptDialog = %DisconnectDialog

var _player_hp: Dictionary = {} # peer_id -> "3/3"


func _ready() -> void:
	_projectile_bucket.add_to_group("projectile_bucket")
	_combat.add_to_group("host_combat_session")
	_result.text = ""

	if not (multiplayer.multiplayer_peer is WebRTCMultiplayerPeer):
		_status.text = "No online session — returning to menu."
		await get_tree().create_timer(1.0).timeout
		SceneManager.go_to_main_menu()
		return

	_disconnect_dialog.confirmed.connect(_return_menu)
	if not NetworkManager.peer_lost.is_connected(_on_peer_lost):
		NetworkManager.peer_lost.connect(_on_peer_lost)
	if not NetworkManager.host_lost.is_connected(_on_host_lost):
		NetworkManager.host_lost.connect(_on_host_lost)

	_combat.player_health_changed.connect(_on_player_health)
	_combat.enemy_count_changed.connect(_on_enemy_count)
	_combat.round_finished.connect(_on_round_finished)

	_spawn_existing_peers()
	if multiplayer.is_server():
		var markers: Array[Marker2D] = []
		for child in _enemy_spawns.get_children():
			if child is Marker2D:
				markers.append(child as Marker2D)
		_combat.bootstrap_enemies(markers)

	_status.text = "Co-op combat — J shoot · E revive downed ally · Esc menu"
	_update_hud()
	_update_debug()


func _exit_tree() -> void:
	if NetworkManager.peer_lost.is_connected(_on_peer_lost):
		NetworkManager.peer_lost.disconnect(_on_peer_lost)
	if NetworkManager.host_lost.is_connected(_on_host_lost):
		NetworkManager.host_lost.disconnect(_on_host_lost)


func _process(_delta: float) -> void:
	_update_debug()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_return_menu()


func _spawn_existing_peers() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	var ids: Array[int] = [multiplayer.get_unique_id()]
	for peer_id in multiplayer.get_peers():
		ids.append(int(peer_id))
	ids.sort()
	for peer_id in ids:
		_spawn_player(peer_id)
	_focus_local_camera()


func _spawn_player(peer_id: int) -> void:
	if _players_root.has_node("Player_%d" % peer_id):
		return
	var player := NET_PLAYER_SCENE.instantiate() as NetPlayer
	var p_name := _name_for_peer(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.configure(p_name, peer_id)
	player.global_position = _spawn_host.global_position if peer_id == 1 else _spawn_client.global_position
	_players_root.add_child(player, true)
	_player_hp[peer_id] = "3/3"
	player.set_equipped_weapon_id(&"standard_rifle")
	if multiplayer.is_server():
		_combat.host_report_player_health(peer_id, 3, 3, false)
		_combat.host_set_player_weapon(peer_id, &"standard_rifle")


func _name_for_peer(peer_id: int) -> String:
	if peer_id == NetworkManager.godot_peer_id:
		return NetworkManager.player_name
	for p in NetworkManager.lobby_players:
		var is_host_player := bool(p.get("isHost", false))
		if peer_id == 1 and is_host_player:
			return str(p.get("name", "Host"))
		if peer_id == 2 and not is_host_player:
			return str(p.get("name", "Client"))
	return "Peer %d" % peer_id


func _focus_local_camera() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	var local_id := multiplayer.get_unique_id()
	var node := _players_root.get_node_or_null("Player_%d" % local_id)
	if node is Node2D:
		_camera.set_target(node as Node2D)
		_camera.global_position = (node as Node2D).global_position


func _on_player_health(peer_id: int, current_hp: int, max_hp: int, downed: bool) -> void:
	_player_hp[peer_id] = ("DOWN" if downed else "%d/%d" % [current_hp, max_hp])
	_update_hud()


func _on_enemy_count(remaining: int) -> void:
	_update_hud()
	_status.text = "Enemies left: %d" % remaining


func _on_round_finished(won: bool) -> void:
	_result.text = "ROOM CLEARED" if won else "ALL OPERATIVES DOWNED"
	_status.text = _result.text


func _update_hud() -> void:
	var parts: PackedStringArray = []
	for peer_id in _player_hp.keys():
		parts.append("P%d %s" % [int(peer_id), str(_player_hp[peer_id])])
	var enemies := _enemies_root.get_child_count()
	parts.append("ENEMIES %d" % enemies)
	if _combat:
		parts.append("REJECTED_DMG %d" % _combat.get_rejected_damage_count())
	_hud.text = " | ".join(parts)


func _on_peer_lost(peer_id: int) -> void:
	var node := _players_root.get_node_or_null("Player_%d" % peer_id)
	if node:
		node.queue_free()
	_status.text = "Peer %d disconnected." % peer_id
	if peer_id != 1:
		_disconnect_dialog.dialog_text = "The other player disconnected. Return to menu?"
		_disconnect_dialog.popup_centered()


func _on_host_lost() -> void:
	_disconnect_dialog.dialog_text = "Host disconnected. Returning to menu."
	_disconnect_dialog.popup_centered()


func _return_menu() -> void:
	NetworkManager.leave_room()
	SceneManager.go_to_main_menu()


func _update_debug() -> void:
	_debug.text = NetworkManager.get_debug_text()
