class_name MpPhase4Scene12
extends Node2D

const NET_PLAYER_SCENE := preload("res://entities/players/net_player.tscn")
const ENEMY_SCENE := preload("res://entities/enemies/patrol_trooper.tscn")
const CAPTIVE_SCENE := preload("res://entities/world/rescue_captive.tscn")

const PATROL := preload("res://resources/enemies/patrol_trooper_def.tres")
const SHIELD := preload("res://resources/enemies/shield_trooper_def.tres")
const DRONE := preload("res://resources/enemies/drone_unit_def.tres")

@onready var _players_root: Node2D = $Players
@onready var _enemies_root: Node2D = $Enemies
@onready var _objectives_root: Node2D = $Objectives
@onready var _projectile_bucket: Node2D = $ProjectileBucket
@onready var _spawn_host: Marker2D = $Spawns/HostSpawn
@onready var _spawn_client: Marker2D = $Spawns/ClientSpawn
@onready var _camera: FollowCamera = $FollowCamera
@onready var _combat: HostCombatSession = $HostCombatSession
@onready var _hud: GameHUD = $GameHUD
@onready var _disconnect_dialog: AcceptDialog = %DisconnectDialog
@onready var _scatter_marker: Marker2D = $MissionMarkers/ScatterPickup
@onready var _captive_marker: Marker2D = $MissionMarkers/Captive
@onready var _captive_safe_marker: Marker2D = $MissionMarkers/CaptiveSafe
@onready var _scatter_cache: Node2D = $World/ScatterCache

var _captive: RescueCaptive
var _score: int = 0
var _next_enemy_id: int = 100
var _finished: bool = false
var _picked_scatter: bool = false
var _rescued_count: int = 0
var _captive_evacuated: bool = false
var _snapshot_accum: float = 0.0


func _ready() -> void:
	_projectile_bucket.add_to_group("projectile_bucket")
	_combat.add_to_group("host_combat_session")
	_combat.auto_finish_on_enemy_clear = false
	_hud.restart_pressed.connect(_restart_scene)
	_hud.menu_pressed.connect(_return_menu)

	var has_online_peer := multiplayer.multiplayer_peer is WebRTCMultiplayerPeer
	var allow_headless_smoke := false
	if not has_online_peer and not allow_headless_smoke:
		_hud.show_banner("No online session - returning to menu.", 1.0)
		await get_tree().create_timer(1.0).timeout
		SceneManager.go_to_main_menu()
		return

	_disconnect_dialog.confirmed.connect(_return_menu)
	if not NetworkManager.peer_lost.is_connected(_on_peer_lost):
		NetworkManager.peer_lost.connect(_on_peer_lost)
	if not NetworkManager.host_lost.is_connected(_on_host_lost):
		NetworkManager.host_lost.connect(_on_host_lost)

	_combat.round_finished.connect(_on_round_finished)
	_combat.player_weapon_changed.connect(_on_player_weapon_changed)

	_spawn_existing_peers()
	_spawn_shared_entities()
	if _is_host_authority():
		_host_spawn_enemy(Vector2(560, 288), PATROL, Vector2(-40, 0), Vector2(40, 0))
		_host_spawn_enemy(Vector2(1040, 166), DRONE, Vector2.ZERO, Vector2.ZERO)
		_host_spawn_enemy(Vector2(1770, 320), SHIELD, Vector2(-30, 0), Vector2(30, 0))
	_hud.show_banner("CO-OP MISSION 1-2: HIGH RESCUE", 2.0)
	_update_scatter_visual()
	_update_objective()
	_focus_local_camera()


func _exit_tree() -> void:
	if NetworkManager.peer_lost.is_connected(_on_peer_lost):
		NetworkManager.peer_lost.disconnect(_on_peer_lost)
	if NetworkManager.host_lost.is_connected(_on_host_lost):
		NetworkManager.host_lost.disconnect(_on_host_lost)


func _process(delta: float) -> void:
	if _finished:
		return
	_handle_local_interact()
	if multiplayer.is_server():
		_check_scatter_reach()
		_snapshot_accum += delta
		if _snapshot_accum >= 0.05:
			_snapshot_accum = 0.0
			_broadcast_entity_snapshots()
	_update_objective()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_return_menu()


func _spawn_existing_peers() -> void:
	var local_id := _local_peer_id()
	if local_id <= 0:
		return
	var ids: Array[int] = [local_id]
	for peer_id in multiplayer.get_peers():
		ids.append(int(peer_id))
	ids.sort()
	for peer_id in ids:
		_spawn_player(peer_id)


func _spawn_player(peer_id: int) -> void:
	if _players_root.has_node("Player_%d" % peer_id):
		return
	var player := NET_PLAYER_SCENE.instantiate() as NetPlayer
	player.set_multiplayer_authority(peer_id)
	player.configure(_name_for_peer(peer_id), peer_id)
	player.global_position = _spawn_host.global_position if peer_id == 1 else _spawn_client.global_position
	_players_root.add_child(player, true)
	player.set_equipped_weapon_id(&"standard_rifle")
	if peer_id == _local_peer_id():
		_hud.bind_player(player)
		_hud.set_weapon_override("STANDARD RIFLE", "AMMO ∞")
		_camera.set_target(player)
		_camera.global_position = player.global_position
	if _is_host_authority():
		_combat.host_report_player_health(peer_id, 3, 3, false)
		_combat.host_set_player_weapon(peer_id, &"standard_rifle")


func _spawn_shared_entities() -> void:
	_captive = CAPTIVE_SCENE.instantiate() as RescueCaptive
	_captive.global_position = _captive_marker.global_position
	_captive.safe_position = _captive_safe_marker.global_position
	_objectives_root.add_child(_captive)
	if multiplayer.is_server():
		_captive.evacuated.connect(_on_captive_evacuated)


func _focus_local_camera() -> void:
	var local_player := _find_player(_local_peer_id())
	if local_player:
		_camera.set_target(local_player)
		_camera.global_position = local_player.global_position


func _handle_local_interact() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	var local_player := _find_player(_local_peer_id())
	if local_player == null:
		return
	if _captive and not _captive.is_rescued() and local_player.global_position.distance_to(_captive.global_position) <= 40.0:
		if multiplayer.is_server():
			_host_rescue_player(local_player.get_peer_id())
		else:
			rpc_request_rescue.rpc_id(1)


func _check_scatter_reach() -> void:
	if _picked_scatter:
		return
	for node in get_tree().get_nodes_in_group("net_players"):
		if node is NetPlayer and not (node as NetPlayer).is_downed():
			if (node as NetPlayer).global_position.distance_to(_scatter_marker.global_position) <= 38.0:
				_unlock_scatter_for_all()
				return


func _unlock_scatter_for_all() -> void:
	if not multiplayer.is_server() or _picked_scatter:
		return
	_picked_scatter = true
	for node in get_tree().get_nodes_in_group("net_players"):
		if node is NetPlayer:
			_combat.host_set_player_weapon((node as NetPlayer).get_peer_id(), &"scatter_cannon")
	rpc_set_scatter_state.rpc(true)
	rpc_show_banner.rpc("SCATTER CANNON ONLINE", 1.2)


func _host_spawn_enemy(pos: Vector2, definition: EnemyDefinition, patrol_a: Vector2, patrol_b: Vector2) -> void:
	var enemy_id := _next_enemy_id
	_next_enemy_id += 1
	rpc_spawn_enemy_instance.rpc(enemy_id, String(definition.id), pos, patrol_a, patrol_b)


func _host_rescue_player(peer_id: int) -> void:
	if _captive == null or _captive.is_rescued():
		return
	var player := _find_player(peer_id)
	if player == null or player.global_position.distance_to(_captive.global_position) > 40.0:
		return
	_rescued_count = 1
	_captive.force_rescue(_captive_safe_marker.global_position)
	_unlock_scatter_for_all()
	rpc_show_banner.rpc("PRISONER RELEASED", 1.2)


func _broadcast_entity_snapshots() -> void:
	if _captive:
		rpc_captive_snapshot.rpc(_captive.global_position, _captive.is_rescued(), _captive.is_evacuated())


func _on_player_weapon_changed(peer_id: int, weapon_id: StringName) -> void:
	if peer_id != _local_peer_id():
		return
	match weapon_id:
		&"scatter_cannon":
			_hud.set_weapon_override("SCATTER CANNON", "AMMO SHARED")
		_:
			_hud.set_weapon_override("STANDARD RIFLE", "AMMO ∞")


func _on_enemy_died(_enemy: PatrolTrooper, score_reward: int) -> void:
	if not multiplayer.is_server():
		return
	_score += score_reward
	rpc_score_update.rpc(_score)
	if _captive_evacuated and _living_enemy_count() <= 0:
		_finish_host(true)


func _on_captive_evacuated() -> void:
	if not multiplayer.is_server():
		return
	_captive_evacuated = true
	rpc_show_banner.rpc("PRISONER SAFE", 1.0)
	if _living_enemy_count() <= 0:
		_finish_host(true)


func _on_round_finished(won: bool) -> void:
	if won:
		return
	if multiplayer.is_server():
		_finish_host(false)


func _finish_host(won: bool) -> void:
	if _finished:
		return
	_finished = true
	var detail := "Rescued %d/1 | Evacuated %s | Scatter %s | Guards %d" % [
		_rescued_count,
		"Y" if _captive_evacuated else "N",
		"Y" if _picked_scatter else "N",
		_living_enemy_count(),
	]
	rpc_mission_result.rpc(won, _score, detail)


func _update_objective() -> void:
	if _finished:
		return
	var objective := "Jump to the high scatter platform"
	if not _picked_scatter:
		objective = "Jump to the high scatter platform"
	elif not _rescued_count:
		objective = "Drop down and free the prisoner"
	elif not _captive_evacuated:
		objective = "Cover the prisoner while they run back"
	elif _living_enemy_count() > 0:
		objective = "Clear remaining guards (%d)" % _living_enemy_count()
	else:
		objective = "Hold the route"
	_hud.set_objective(objective)


func _update_scatter_visual() -> void:
	if _scatter_cache:
		_scatter_cache.visible = not _picked_scatter


func _living_enemy_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is PatrolTrooper and not (node as PatrolTrooper).get_health_component().is_dead:
			count += 1
	return count


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


func _find_player(peer_id: int) -> NetPlayer:
	for node in get_tree().get_nodes_in_group("net_players"):
		if node is NetPlayer and (node as NetPlayer).get_peer_id() == peer_id:
			return node as NetPlayer
	return null


func _enemy_definition_for_id(def_id: String) -> EnemyDefinition:
	match StringName(def_id):
		&"shield_trooper":
			return SHIELD
		&"drone_unit":
			return DRONE
		_:
			return PATROL


func _local_peer_id() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 0
	return multiplayer.get_unique_id()


func _is_host_authority() -> bool:
	return multiplayer.is_server()


@rpc("any_peer", "reliable")
func rpc_request_rescue() -> void:
	if multiplayer.is_server():
		_host_rescue_player(multiplayer.get_remote_sender_id())


@rpc("authority", "call_local", "reliable")
func rpc_spawn_enemy_instance(enemy_id: int, def_id: String, pos: Vector2, patrol_a: Vector2, patrol_b: Vector2) -> void:
	if _enemies_root.has_node("Enemy_%d" % enemy_id):
		return
	var enemy := ENEMY_SCENE.instantiate() as PatrolTrooper
	enemy.name = "Enemy_%d" % enemy_id
	enemy.definition = _enemy_definition_for_id(def_id)
	enemy.network_id = enemy_id
	enemy.networked = true
	enemy.authoritative = multiplayer.is_server()
	enemy.patrol_offset_a = patrol_a
	enemy.patrol_offset_b = patrol_b
	enemy.global_position = pos
	_enemies_root.add_child(enemy, true)
	if multiplayer.is_server():
		enemy.died.connect(_on_enemy_died)
		_combat.host_register_network_enemy(enemy)


@rpc("authority", "call_local", "unreliable_ordered")
func rpc_captive_snapshot(pos: Vector2, rescued_state: bool, evacuated_state: bool) -> void:
	if _captive:
		_captive.apply_network_snapshot(pos, rescued_state, evacuated_state)
		if rescued_state:
			_rescued_count = 1
		_captive_evacuated = evacuated_state


@rpc("authority", "call_local", "reliable")
func rpc_show_banner(text: String, duration_sec: float) -> void:
	_hud.show_banner(text, duration_sec)


@rpc("authority", "call_local", "reliable")
func rpc_score_update(score: int) -> void:
	_score = score
	_hud.set_score(score)


@rpc("authority", "call_local", "reliable")
func rpc_set_scatter_state(unlocked: bool) -> void:
	_picked_scatter = unlocked
	_update_scatter_visual()


@rpc("authority", "call_local", "reliable")
func rpc_mission_result(won: bool, score: int, detail: String) -> void:
	_finished = true
	call_deferred("_show_mission_result", won, score, detail)


func _show_mission_result(won: bool, score: int, detail: String) -> void:
	SceneManager.go_to_mission_result(won, score, detail, "phase4_coop_scene_1_2", "Phase 4 Co-op Scene 1-2")


func _on_peer_lost(_peer_id: int) -> void:
	_disconnect_dialog.dialog_text = "The other player disconnected. Return to menu?"
	_disconnect_dialog.popup_centered()


func _on_host_lost() -> void:
	_disconnect_dialog.dialog_text = "Host disconnected. Returning to menu."
	_disconnect_dialog.popup_centered()


func _return_menu() -> void:
	NetworkManager.leave_room()
	SceneManager.go_to_main_menu()


func _restart_scene() -> void:
	get_tree().reload_current_scene()
