class_name HostCombatSession
extends Node
## Host-authoritative combat coordinator for Phase 3.
## Clients send fire/revive intent; only the host spawns projectiles, applies damage,
## runs enemy AI authority, and broadcasts results.
## Expected parent: MpArena. Multiplayer authority: peer 1 (host).

signal player_health_changed(peer_id: int, current_hp: int, max_hp: int, downed: bool)
signal player_weapon_changed(peer_id: int, weapon_id: StringName)
signal enemy_count_changed(remaining: int)
signal round_finished(won: bool)

const RIFLE := preload("res://resources/weapons/standard_rifle.tres")
const SCATTER := preload("res://resources/weapons/scatter_cannon.tres")
const RAPID := preload("res://resources/weapons/rapid_pulse_gun.tres")
const ROVER_CANNON := preload("res://resources/weapons/assault_rover_cannon.tres")
const ENEMY_DEF := preload("res://resources/enemies/patrol_trooper_def.tres")
const ENEMY_SCENE := preload("res://entities/enemies/patrol_trooper.tscn")
const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")
const HEAVY_PROJECTILE_SCENE := preload("res://entities/projectiles/heavy_pulse_projectile.tscn")
const REVIVE_RANGE_PX := 48.0
const MIN_FIRE_INTERVAL_SEC := 0.05

@export var auto_finish_on_enemy_clear: bool = true

var _fire_cooldown_by_peer: Dictionary = {} # peer_id -> remaining sec
var _next_projectile_id: int = 1
var _next_enemy_id: int = 1
var _enemies_alive: int = 0
var _finished: bool = false
var _rejected_damage_attempts: int = 0
var _weapon_by_peer: Dictionary = {} # peer_id -> weapon id string


func _ready() -> void:
	set_multiplayer_authority(1)
	add_to_group("host_combat_session")
	set_process(true)


func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not _is_host():
		return
	for peer_id in _fire_cooldown_by_peer.keys():
		_fire_cooldown_by_peer[peer_id] = maxf(0.0, float(_fire_cooldown_by_peer[peer_id]) - delta)


func is_host_peer() -> bool:
	return _is_host()


func get_rejected_damage_count() -> int:
	return _rejected_damage_attempts


func bootstrap_enemies(spawn_markers: Array[Marker2D]) -> void:
	if not _is_host():
		return
	for marker in spawn_markers:
		_host_spawn_enemy(marker.global_position)


func request_fire_from_local(aim: Vector2, origin: Vector2, weapon_id: StringName = &"standard_rifle") -> void:
	if _is_host():
		_host_handle_fire(multiplayer.get_unique_id(), aim, origin, weapon_id)
	else:
		rpc_request_fire.rpc_id(1, aim.x, aim.y, origin.x, origin.y, String(weapon_id))


func request_revive_from_local(target_peer_id: int) -> void:
	if _is_host():
		_host_handle_revive(multiplayer.get_unique_id(), target_peer_id)
	else:
		rpc_request_revive.rpc_id(1, target_peer_id)


## Invalid client shortcut — clients must not call this with fabricated damage.
@rpc("any_peer", "reliable")
func rpc_client_claim_damage(_target_path: String, _amount: int) -> void:
	_rejected_damage_attempts += 1
	var sender := multiplayer.get_remote_sender_id()
	push_warning("Rejected client damage claim from peer %d" % sender)
	rpc_reject.rpc_id(sender, "damage_claim_rejected")


@rpc("any_peer", "reliable")
func rpc_request_fire(aim_x: float, aim_y: float, origin_x: float, origin_y: float, weapon_id: String) -> void:
	if not _is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	_host_handle_fire(sender, Vector2(aim_x, aim_y), Vector2(origin_x, origin_y), StringName(weapon_id))


@rpc("any_peer", "reliable")
func rpc_request_revive(target_peer_id: int) -> void:
	if not _is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	_host_handle_revive(sender, target_peer_id)


func host_spawn_enemy_projectile(
	origin: Vector2,
	direction: Vector2,
	damage: int,
	speed: float,
	lifetime: float,
	projectile_kind: StringName = &"standard"
) -> void:
	if not _is_host():
		return
	var proj_id := _next_projectile_id
	_next_projectile_id += 1
	rpc_spawn_projectile.rpc(proj_id, origin, direction, damage, speed, lifetime, "enemy", String(projectile_kind))


@rpc("authority", "call_local", "reliable")
func rpc_spawn_projectile(
	proj_id: int,
	origin: Vector2,
	direction: Vector2,
	damage: int,
	speed: float,
	lifetime: float,
	team: String,
	projectile_kind: String = "standard"
) -> void:
	var bucket := get_tree().get_first_node_in_group("projectile_bucket")
	var parent: Node = bucket if bucket != null else get_parent()
	var scene := _projectile_scene_for_kind(StringName(projectile_kind))
	var projectile := scene.instantiate() as Projectile
	projectile.name = "Proj_%d" % proj_id
	parent.add_child(projectile, true)
	projectile.launch(origin, direction, damage, speed, lifetime, StringName(team))
	var hitbox := projectile.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox == null:
		return
	if _is_host():
		projectile.set_meta("host_auth", true)
		hitbox.hit_landed.connect(_on_host_hit.bind(proj_id, StringName(team)))
	else:
		# Visual-only on clients — host is authoritative for hits.
		hitbox.monitoring = false
		hitbox.damage = 0


@rpc("authority", "call_local", "reliable")
func rpc_spawn_enemy(enemy_id: int, pos: Vector2) -> void:
	var enemies_root := get_parent().get_node_or_null("Enemies") as Node2D
	if enemies_root == null:
		return
	if enemies_root.has_node("Enemy_%d" % enemy_id):
		return
	var enemy := ENEMY_SCENE.instantiate() as PatrolTrooper
	enemy.name = "Enemy_%d" % enemy_id
	enemy.definition = ENEMY_DEF
	enemy.network_id = enemy_id
	enemy.networked = true
	enemy.authoritative = _is_host()
	enemies_root.add_child(enemy, true)
	enemy.global_position = pos
	if _is_host():
		enemy.died.connect(_on_host_enemy_died)
		_enemies_alive += 1
		enemy_count_changed.emit(_enemies_alive)


@rpc("authority", "call_local", "unreliable_ordered")
func rpc_enemy_snapshot(enemy_id: int, pos: Vector2, vel: Vector2, state: String, hp: int, facing: float) -> void:
	if _is_host():
		return
	var enemy := _find_enemy(enemy_id)
	if enemy:
		enemy.apply_network_snapshot(pos, vel, StringName(state), hp, facing)


@rpc("authority", "call_local", "reliable")
func rpc_enemy_died(enemy_id: int, score_reward: int) -> void:
	var enemy := _find_enemy(enemy_id)
	if enemy and not enemy.is_network_dead():
		enemy.apply_network_death()
	if _is_host():
		_enemies_alive = maxi(0, _enemies_alive - 1)
		enemy_count_changed.emit(_enemies_alive)
		if auto_finish_on_enemy_clear and _enemies_alive <= 0:
			_finish(true)


@rpc("authority", "call_local", "reliable")
func rpc_player_health(peer_id: int, current_hp: int, max_hp: int, downed: bool) -> void:
	player_health_changed.emit(peer_id, current_hp, max_hp, downed)
	var player := _find_player(peer_id)
	if player:
		player.apply_authoritative_health(current_hp, max_hp, downed)


@rpc("authority", "call_local", "reliable")
func rpc_player_weapon(peer_id: int, weapon_id: String) -> void:
	player_weapon_changed.emit(peer_id, StringName(weapon_id))
	var player := _find_player(peer_id)
	if player and player.has_method("set_equipped_weapon_id"):
		player.call("set_equipped_weapon_id", StringName(weapon_id))


@rpc("authority", "call_local", "reliable")
func rpc_player_revived(peer_id: int, current_hp: int) -> void:
	var player := _find_player(peer_id)
	if player:
		player.apply_authoritative_health(current_hp, player.get_max_health(), false)


@rpc("authority", "call_local", "reliable")
func rpc_round_result(won: bool) -> void:
	_finished = true
	round_finished.emit(won)


@rpc("authority", "reliable")
func rpc_reject(reason: String) -> void:
	if reason == "cannot_fire":
		return
	push_warning("Host rejected request: %s" % reason)


func host_broadcast_enemy_snapshot(enemy: PatrolTrooper) -> void:
	if not _is_host() or enemy == null:
		return
	rpc_enemy_snapshot.rpc(
		enemy.network_id,
		enemy.global_position,
		enemy.velocity,
		String(enemy.get_state_name()),
		enemy.get_health_component().current_health,
		enemy.get_facing(),
	)


func host_report_player_health(peer_id: int, current_hp: int, max_hp: int, downed: bool) -> void:
	if not _is_host():
		return
	rpc_player_health.rpc(peer_id, current_hp, max_hp, downed)
	_check_all_downed()


func _host_handle_fire(peer_id: int, aim: Vector2, origin: Vector2, requested_weapon_id: StringName = &"standard_rifle") -> void:
	if _finished:
		return
	var player := _find_player(peer_id)
	if player == null or player.is_downed():
		return
	var cd := float(_fire_cooldown_by_peer.get(peer_id, 0.0))
	if cd > 0.0:
		return
	var weapon := _definition_for_weapon_id(_weapon_by_peer.get(peer_id, requested_weapon_id))
	var interval := weapon.fire_interval_sec if weapon else (RIFLE.fire_interval_sec if RIFLE else MIN_FIRE_INTERVAL_SEC)
	_fire_cooldown_by_peer[peer_id] = maxf(interval, MIN_FIRE_INTERVAL_SEC)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	# Clamp origin near player to reduce spoofed muzzle positions.
	if origin.distance_to(player.global_position) > 48.0:
		origin = player.get_muzzle_position(aim)
	var damage := weapon.damage if weapon else (RIFLE.damage if RIFLE else 1)
	var speed := weapon.projectile_speed if weapon else (RIFLE.projectile_speed if RIFLE else 420.0)
	var lifetime := weapon.projectile_lifetime_sec if weapon else (RIFLE.projectile_lifetime_sec if RIFLE else 1.2)
	var pellets := maxi(1, weapon.pellet_count if weapon else 1)
	var projectile_kind := _projectile_kind_for_weapon(weapon)
	for i in pellets:
		var dir := aim
		if weapon and weapon.spread_degrees > 0.0 and pellets > 1:
			var t := 0.0 if pellets == 1 else float(i) / float(pellets - 1)
			var angle := deg_to_rad(lerpf(-weapon.spread_degrees, weapon.spread_degrees, t))
			dir = aim.rotated(angle)
		var proj_id := _next_projectile_id
		_next_projectile_id += 1
		rpc_spawn_projectile.rpc(proj_id, origin, dir, damage, speed, lifetime, "player", String(projectile_kind))


func _host_handle_revive(reviver_id: int, target_id: int) -> void:
	if _finished:
		return
	var reviver := _find_player(reviver_id)
	var target := _find_player(target_id)
	if reviver == null or target == null:
		return
	if reviver.is_downed() or not target.is_downed():
		return
	if reviver.global_position.distance_to(target.global_position) > REVIVE_RANGE_PX:
		rpc_reject.rpc_id(reviver_id, "revive_too_far")
		return
	target.host_revive(1)
	rpc_player_revived.rpc(target_id, target.get_health_component().current_health)


func _host_spawn_enemy(pos: Vector2) -> void:
	var enemy_id := _next_enemy_id
	_next_enemy_id += 1
	rpc_spawn_enemy.rpc(enemy_id, pos)


func _on_host_hit(hurtbox: HurtboxComponent, _proj_id: int, team: StringName) -> void:
	if not _is_host() or hurtbox == null:
		return
	# Damage already applied inside HurtboxComponent.receive_hit via Hitbox.
	# Broadcast resulting health for players / ensure enemy death is unique.
	var owner := hurtbox.get_parent()
	if owner is NetPlayer:
		var np := owner as NetPlayer
		host_report_player_health(np.get_peer_id(), np.get_health_component().current_health, np.get_health_component().max_health, np.is_downed())
	elif owner is PatrolTrooper:
		var enemy := owner as PatrolTrooper
		if enemy.get_health_component().is_dead:
			# death signal handles broadcast once
			pass
		else:
			host_broadcast_enemy_snapshot(enemy)
	# Enemy projectiles hitting players already went through hurtbox.
	if team == &"enemy" and owner is NetPlayer:
		pass


func _on_host_enemy_died(enemy: PatrolTrooper, score_reward: int) -> void:
	if not _is_host() or enemy == null:
		return
	if enemy.get_meta("death_broadcast", false):
		return
	enemy.set_meta("death_broadcast", true)
	rpc_enemy_died.rpc(enemy.network_id, score_reward)


func _check_all_downed() -> void:
	if _finished:
		return
	var any_up := false
	for node in get_tree().get_nodes_in_group("net_players"):
		if node is NetPlayer and not (node as NetPlayer).is_downed():
			any_up = true
			break
	if not any_up:
		_finish(false)


func _finish(won: bool) -> void:
	if _finished:
		return
	_finished = true
	rpc_round_result.rpc(won)


func _find_player(peer_id: int) -> NetPlayer:
	for n in get_tree().get_nodes_in_group("net_players"):
		if n is NetPlayer and (n as NetPlayer).get_peer_id() == peer_id:
			return n as NetPlayer
	return null


func _find_enemy(enemy_id: int) -> PatrolTrooper:
	var enemies_root := get_parent().get_node_or_null("Enemies")
	if enemies_root == null:
		return null
	return enemies_root.get_node_or_null("Enemy_%d" % enemy_id) as PatrolTrooper


func _is_host() -> bool:
	return multiplayer.multiplayer_peer is WebRTCMultiplayerPeer and multiplayer.is_server()


func host_set_player_weapon(peer_id: int, weapon_id: StringName) -> void:
	if not _is_host():
		return
	_weapon_by_peer[peer_id] = weapon_id
	rpc_player_weapon.rpc(peer_id, String(weapon_id))


func host_register_network_enemy(enemy: PatrolTrooper) -> void:
	if not _is_host() or enemy == null:
		return
	if not enemy.died.is_connected(_on_host_enemy_died):
		enemy.died.connect(_on_host_enemy_died)
	_enemies_alive += 1
	enemy_count_changed.emit(_enemies_alive)


func _definition_for_weapon_id(weapon_id: Variant) -> WeaponDefinition:
	var id := StringName(weapon_id)
	match id:
		&"scatter_cannon":
			return SCATTER
		&"rapid_pulse_gun":
			return RAPID
		&"assault_rover_cannon":
			return ROVER_CANNON
		_:
			return RIFLE


func _projectile_kind_for_weapon(weapon: WeaponDefinition) -> StringName:
	if weapon == null:
		return &"standard"
	if weapon.id == &"assault_rover_cannon":
		return &"heavy_pulse"
	return &"standard"


func _projectile_scene_for_kind(projectile_kind: StringName) -> PackedScene:
	match projectile_kind:
		&"heavy_pulse":
			return HEAVY_PROJECTILE_SCENE
		_:
			return PROJECTILE_SCENE
