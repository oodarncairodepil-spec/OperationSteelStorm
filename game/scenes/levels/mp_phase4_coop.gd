class_name MpPhase4Coop
extends Node2D

const NET_PLAYER_SCENE := preload("res://entities/players/net_player.tscn")
const ENEMY_SCENE := preload("res://entities/enemies/patrol_trooper.tscn")
const CAPTIVE_SCENE := preload("res://entities/world/rescue_captive.tscn")
const ROVER_SCENE := preload("res://entities/vehicles/assault_rover.tscn")
const BOSS_SCENE := preload("res://entities/enemies/siege_walker.tscn")

const PATROL := preload("res://resources/enemies/patrol_trooper_def.tres")
const SHIELD := preload("res://resources/enemies/shield_trooper_def.tres")
const DRONE := preload("res://resources/enemies/drone_unit_def.tres")
const HEAVY := preload("res://resources/enemies/heavy_gunner_def.tres")
const ROVER_CANNON := preload("res://resources/weapons/assault_rover_cannon.tres")

@onready var _players_root: Node2D = $Players
@onready var _enemies_root: Node2D = $Enemies
@onready var _objectives_root: Node2D = $Objectives
@onready var _vehicles_root: Node2D = $Vehicles
@onready var _boss_root: Node2D = $Bosses
@onready var _projectile_bucket: Node2D = $ProjectileBucket
@onready var _spawn_host: Marker2D = $Spawns/HostSpawn
@onready var _spawn_client: Marker2D = $Spawns/ClientSpawn
@onready var _camera: FollowCamera = $FollowCamera
@onready var _combat: HostCombatSession = $HostCombatSession
@onready var _hud: GameHUD = $GameHUD
@onready var _disconnect_dialog: AcceptDialog = %DisconnectDialog
@onready var _scatter_marker: Marker2D = $MissionMarkers/ScatterPickup
@onready var _rapid_marker: Marker2D = $MissionMarkers/RapidPickup
@onready var _captive_marker: Marker2D = $MissionMarkers/Captive
@onready var _captive_safe_marker: Marker2D = $MissionMarkers/CaptiveSafe
@onready var _rover_marker: Marker2D = $MissionMarkers/Rover
@onready var _boss_marker: Marker2D = $MissionMarkers/Boss

var _captive: RescueCaptive
var _rover: AssaultRover
var _boss: SiegeWalker

var _score: int = 0
var _next_enemy_id: int = 100
var _finished: bool = false
var _weapon_before_rover_by_peer: Dictionary = {}
var _picked_scatter: bool = false
var _picked_rapid: bool = false
var _rescued_count: int = 0
var _spawned_catwalk_wave: bool = false
var _spawned_rescue_wave: bool = false
var _spawned_rover_wave: bool = false
var _boss_spawned: bool = false
var _boss_defeated: bool = false
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
		_host_spawn_enemy(Vector2(420, 320), PATROL, Vector2(-60, 0), Vector2(60, 0))
		_host_spawn_enemy(Vector2(760, 320), PATROL, Vector2(-50, 0), Vector2(50, 0))
	_hud.show_banner("CO-OP PHASE 4 - BEACHHEAD", 2.0)
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
	_handle_local_vehicle_input()
	_handle_local_interact()
	if multiplayer.is_server():
		_progress_host_events()
		_snapshot_accum += delta
		if _snapshot_accum >= 0.05:
			_snapshot_accum = 0.0
			_broadcast_entity_snapshots()
	_update_objective()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_return_menu()


func _spawn_existing_peers() -> void:
	if _is_headless_smoke_mode():
		_spawn_player(1)
		return
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

	_rover = ROVER_SCENE.instantiate() as AssaultRover
	_rover.mounted_weapon = ROVER_CANNON
	_rover.networked = true
	_rover.authoritative = _is_host_authority()
	_rover.global_position = _rover_marker.global_position
	_vehicles_root.add_child(_rover)
	_rover.disembarked.connect(_on_rover_disembarked)


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
		return
	if _rover == null:
		return
	if local_player.is_in_vehicle():
		if multiplayer.is_server():
			_host_exit_rover(local_player.get_peer_id())
		else:
			rpc_request_rover_exit.rpc_id(1)
		return
	if local_player.global_position.distance_to(_rover.global_position) <= 72.0:
		if multiplayer.is_server():
			_host_board_rover(local_player.get_peer_id())
		else:
			rpc_request_rover_board.rpc_id(1)


func _handle_local_vehicle_input() -> void:
	if _is_host_authority():
		return
	var local_player := _find_player(_local_peer_id())
	if local_player == null or not local_player.is_in_vehicle():
		return
	rpc_rover_input.rpc_id(
		1,
		Input.get_axis("move_left", "move_right"),
		Input.is_action_pressed("aim_up"),
		Input.is_action_pressed("shoot"),
		Input.is_action_pressed("grenade")
	)


func _progress_host_events() -> void:
	var front_x := _mission_front_x()
	if not _picked_scatter and front_x >= _scatter_marker.global_position.x - 24.0:
		_picked_scatter = true
		_apply_weapon_to_all(&"scatter_cannon", "SCATTER CANNON ONLINE")
	if not _spawned_catwalk_wave and front_x >= 920.0:
		_spawned_catwalk_wave = true
		rpc_show_banner.rpc("SMELTER CATWALK", 1.2)
		_host_spawn_enemy(Vector2(1080, 200), DRONE, Vector2.ZERO, Vector2.ZERO)
		_host_spawn_enemy(Vector2(1220, 320), SHIELD, Vector2(-40, 0), Vector2(40, 0))
	if not _spawned_rescue_wave and front_x >= 1560.0:
		_spawned_rescue_wave = true
		rpc_show_banner.rpc("LOCKUP BREACH", 1.2)
		_host_spawn_enemy(Vector2(1680, 320), PATROL, Vector2(-50, 0), Vector2(50, 0))
		_host_spawn_enemy(Vector2(1810, 320), DRONE, Vector2.ZERO, Vector2.ZERO)
	if not _spawned_rover_wave and _rescued_count > 0 and front_x >= 2140.0:
		_spawned_rover_wave = true
		rpc_show_banner.rpc("HEAVY PLAZA", 1.2)
		_host_spawn_enemy(Vector2(2280, 320), HEAVY, Vector2(-60, 0), Vector2(60, 0))
		_host_spawn_enemy(Vector2(2420, 320), SHIELD, Vector2(-40, 0), Vector2(40, 0))
	if not _picked_rapid and front_x >= _rapid_marker.global_position.x - 24.0:
		_picked_rapid = true
		_apply_weapon_to_all(&"rapid_pulse_gun", "RAPID PULSE GUN ONLINE")
	if not _boss_spawned and _rover and _rover.has_occupant() and front_x >= 2700.0:
		_host_spawn_boss()


func _mission_front_x() -> float:
	var best := 0.0
	for node in get_tree().get_nodes_in_group("net_players"):
		if node is NetPlayer and not (node as NetPlayer).is_downed():
			best = maxf(best, (node as NetPlayer).global_position.x)
	if _rover and _rover.has_occupant():
		best = maxf(best, _rover.global_position.x)
	return best


func _apply_weapon_to_all(weapon_id: StringName, banner_text: String) -> void:
	if not multiplayer.is_server():
		return
	for node in get_tree().get_nodes_in_group("net_players"):
		if node is NetPlayer:
			var peer_id := (node as NetPlayer).get_peer_id()
			if _rover and _rover.get_occupant_peer_id() == peer_id:
				_weapon_before_rover_by_peer[peer_id] = weapon_id
				continue
			_combat.host_set_player_weapon(peer_id, weapon_id)
	rpc_show_banner.rpc(banner_text, 1.2)


func _host_spawn_enemy(pos: Vector2, definition: EnemyDefinition, patrol_a: Vector2, patrol_b: Vector2) -> void:
	var enemy_id := _next_enemy_id
	_next_enemy_id += 1
	rpc_spawn_enemy_instance.rpc(enemy_id, String(definition.id), pos, patrol_a, patrol_b)


func _host_spawn_boss() -> void:
	_boss_spawned = true
	rpc_show_banner.rpc("SIEGE WALKER INBOUND", 1.6)
	rpc_spawn_boss.rpc(_boss_marker.global_position)


func _host_rescue_player(peer_id: int) -> void:
	if _captive == null or _captive.is_rescued():
		return
	var player := _find_player(peer_id)
	if player == null or player.global_position.distance_to(_captive.global_position) > 40.0:
		return
	_rescued_count = 1
	_captive.force_rescue(_captive_safe_marker.global_position)
	rpc_show_banner.rpc("CIVILIAN SECURED", 1.2)


func _host_board_rover(peer_id: int) -> void:
	if _rover == null or _rover.has_occupant():
		return
	var player := _find_player(peer_id)
	if player == null or player.global_position.distance_to(_rover.global_position) > 72.0:
		return
	_weapon_before_rover_by_peer[peer_id] = player.get_equipped_weapon_id()
	_rover.board_rider(player)
	_combat.host_set_player_weapon(peer_id, &"assault_rover_cannon")
	rpc_show_banner.rpc("ASSAULT ROVER ONLINE", 1.2)


func _host_exit_rover(peer_id: int) -> void:
	if _rover == null or _rover.get_occupant_peer_id() != peer_id:
		return
	_rover.force_disembark()


func _broadcast_entity_snapshots() -> void:
	if _captive:
		rpc_captive_snapshot.rpc(_captive.global_position, _captive.is_rescued(), _captive.is_evacuated())
	if _rover:
		rpc_rover_snapshot.rpc(_rover.global_position, _rover.get_facing(), _rover.get_occupant_peer_id(), _rover.get_health_component().current_health)
	if _boss:
		rpc_boss_snapshot.rpc(_boss.global_position, _boss.get_health_component().current_health, _boss.get_phase(), _boss.get_move_direction(), _boss.is_fight_active())


func _on_player_weapon_changed(peer_id: int, weapon_id: StringName) -> void:
	if peer_id != _local_peer_id():
		return
	match weapon_id:
		&"scatter_cannon":
			_hud.set_weapon_override("SCATTER CANNON", "AMMO SHARED")
		&"rapid_pulse_gun":
			_hud.set_weapon_override("RAPID PULSE GUN", "AMMO SHARED")
		&"assault_rover_cannon":
			_hud.set_weapon_override("ROVER CANNON", "AMMO ∞")
		_:
			_hud.set_weapon_override("STANDARD RIFLE", "AMMO ∞")


func _on_enemy_died(_enemy: PatrolTrooper, score_reward: int) -> void:
	if not multiplayer.is_server():
		return
	_score += score_reward
	rpc_score_update.rpc(_score)


func _on_rover_disembarked(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id <= 0:
		return
	var restore_id := StringName(_weapon_before_rover_by_peer.get(peer_id, &"standard_rifle"))
	_weapon_before_rover_by_peer.erase(peer_id)
	_combat.host_set_player_weapon(peer_id, restore_id)


func _on_boss_defeated() -> void:
	if not multiplayer.is_server():
		return
	_boss_defeated = true
	_score += 1000
	rpc_score_update.rpc(_score)
	_finish_host(true)


func _on_round_finished(won: bool) -> void:
	if won and not _boss_defeated:
		return
	if not won and multiplayer.is_server():
		_finish_host(false)


func _finish_host(won: bool) -> void:
	if _finished:
		return
	_finished = true
	var detail := "Rescued %d/1 | Scatter %s | Pulse %s | Boss %s" % [
		_rescued_count,
		"Y" if _picked_scatter else "N",
		"Y" if _picked_rapid else "N",
		"DOWN" if _boss_defeated else "ACTIVE",
	]
	rpc_mission_result.rpc(won, _score, detail)


func _update_objective() -> void:
	if _finished:
		return
	var objective := "Secure the beachhead"
	if not _picked_scatter:
		objective = "Push to the scatter cannon cache"
	elif not _rescued_count:
		objective = "Rescue the captive worker"
	elif _rover and not _rover.has_occupant():
		objective = "Board the Assault Rover"
	elif not _picked_rapid:
		objective = "Advance to the pulse gun cache"
	elif not _boss_spawned:
		objective = "Push into the drydock"
	elif not _boss_defeated:
		objective = "Destroy the Siege Walker"
	_hud.set_objective(objective)


func _name_for_peer(peer_id: int) -> String:
	if _is_headless_smoke_mode() and peer_id == 1:
		return "SmokeHost"
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
		&"heavy_gunner":
			return HEAVY
		_:
			return PATROL


func _is_headless_smoke_mode() -> bool:
	return false


func _local_peer_id() -> int:
	if _is_headless_smoke_mode():
		return 1
	if not multiplayer.has_multiplayer_peer():
		return 0
	return multiplayer.get_unique_id()


func _is_host_authority() -> bool:
	return multiplayer.is_server() or _is_headless_smoke_mode()


@rpc("any_peer", "reliable")
func rpc_request_rescue() -> void:
	if multiplayer.is_server():
		_host_rescue_player(multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func rpc_request_rover_board() -> void:
	if multiplayer.is_server():
		_host_board_rover(multiplayer.get_remote_sender_id())


@rpc("any_peer", "unreliable_ordered")
func rpc_rover_input(axis: float, aiming_up: bool, firing: bool, arc_modifier: bool) -> void:
	if multiplayer.is_server() and _rover and _rover.get_occupant_peer_id() == multiplayer.get_remote_sender_id():
		_rover.set_remote_input(axis, aiming_up, firing, arc_modifier)


@rpc("any_peer", "reliable")
func rpc_request_rover_exit() -> void:
	if multiplayer.is_server() and _rover and _rover.get_occupant_peer_id() == multiplayer.get_remote_sender_id():
		_host_exit_rover(multiplayer.get_remote_sender_id())


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


@rpc("authority", "call_local", "reliable")
func rpc_spawn_boss(pos: Vector2) -> void:
	if _boss != null:
		return
	_boss = BOSS_SCENE.instantiate() as SiegeWalker
	_boss.networked = true
	_boss.authoritative = multiplayer.is_server()
	_boss.global_position = pos
	_boss_root.add_child(_boss, true)
	if multiplayer.is_server():
		_boss.defeated.connect(_on_boss_defeated)
		_boss.phase_changed.connect(func(phase: int) -> void:
			rpc_show_banner.rpc("BOSS PHASE %d" % phase, 1.0)
		)
		_boss.start_fight()
	_boss_spawned = true


@rpc("authority", "call_local", "unreliable_ordered")
func rpc_captive_snapshot(pos: Vector2, rescued_state: bool, evacuated_state: bool) -> void:
	if _captive:
		_captive.apply_network_snapshot(pos, rescued_state, evacuated_state)
		if rescued_state:
			_rescued_count = 1


@rpc("authority", "call_local", "unreliable_ordered")
func rpc_rover_snapshot(pos: Vector2, facing: float, occupant_peer_id: int, hp: int) -> void:
	if _rover:
		_rover.apply_network_snapshot(pos, facing, occupant_peer_id, hp)


@rpc("authority", "call_local", "unreliable_ordered")
func rpc_boss_snapshot(pos: Vector2, hp: int, phase: int, move_direction: float, fight_active: bool) -> void:
	if _boss:
		_boss.apply_network_snapshot(pos, hp, phase, move_direction, fight_active)


@rpc("authority", "call_local", "reliable")
func rpc_show_banner(text: String, duration_sec: float) -> void:
	_hud.show_banner(text, duration_sec)


@rpc("authority", "call_local", "reliable")
func rpc_score_update(score: int) -> void:
	_score = score
	_hud.set_score(score)


@rpc("authority", "call_local", "reliable")
func rpc_mission_result(won: bool, score: int, detail: String) -> void:
	_finished = true
	SceneManager.go_to_mission_result(won, score, detail, "phase4_coop", "Phase 4 Co-op Mission")


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
