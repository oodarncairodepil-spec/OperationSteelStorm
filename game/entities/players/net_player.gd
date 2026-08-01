class_name NetPlayer
extends CharacterBody2D
## Phase 3 networked combat operative.
## Local peer: movement + fire/revive intent.
## Host: validates combat; health is applied from host RPCs.
## Expected parent: mp arena Players node.

const MOVE_SPEED := 140.0
const JUMP_VELOCITY := -280.0
const GRAVITY := 900.0
const MAX_HEALTH := 3
const INVULN_SEC := 1.0
const AIM_HELPER := preload("res://scripts/aim_helper.gd")
const PLAYER_VISUALS := preload("res://entities/players/player_visuals.gd")

signal downed_changed(downed: bool)

@onready var _visual: Sprite2D = $Visual
@onready var _label: Label = $Label
@onready var _interp: NetworkInterpolationComponent = $NetworkInterpolationComponent
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _muzzle: Marker2D = $Muzzle
@onready var _muzzle_up: Marker2D = $AimUpMuzzle

var display_name: String = "Operative"
var facing: float = 1.0
var peer_id: int = 0
var is_aiming_up: bool = false
var _aim_vector: Vector2 = Vector2.RIGHT
var equipped_weapon_id: StringName = &"standard_rifle"

var _snapshot_accum: float = 0.0
var _snapshot_interval: float = 0.05
var _downed: bool = false
var _combat: HostCombatSession
var _fire_pressed_prev: bool = false
var _applying_auth_health: bool = false
var _vehicle: Node2D
var _visual_base_scale: Vector2
var _visual_rest_position: Vector2
var _muzzle_base_position: Vector2
var _muzzle_up_base_position: Vector2
var _walk_anim_time: float = 0.0


func _ready() -> void:
	add_to_group("net_players")
	add_to_group("players")
	collision_layer = 2
	collision_mask = 1
	_hurtbox.team = &"player"
	_hurtbox.collision_layer = 2
	_hurtbox.collision_mask = 16
	_health.configure(MAX_HEALTH, INVULN_SEC)
	_health.died.connect(_on_local_died)
	_health.health_changed.connect(_on_health_changed)
	_snapshot_interval = 1.0 / maxf(1.0, NetworkManager.config.snapshot_rate_hz)
	_label.text = display_name
	_combat = get_tree().get_first_node_in_group("host_combat_session") as HostCombatSession
	_visual_base_scale = _visual.scale
	_visual_rest_position = _visual.position
	_muzzle_base_position = _muzzle.position
	_muzzle_up_base_position = _muzzle_up.position
	if is_multiplayer_authority():
		_interp.set_physics_process(false)
	# Only host applies incoming projectile damage to hurtboxes.
	if not multiplayer.is_server():
		_hurtbox.monitoring = true
		_hurtbox.monitorable = true
	_set_visual_facing(facing)
	_update_muzzle_positions()
	_refresh_visual()
	_refresh_label()


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_process_local(delta)
	else:
		_update_visual_animation(delta, velocity)


func _process_local(delta: float) -> void:
	if _downed:
		velocity = Vector2.ZERO
		move_and_slide()
		_try_revive_other()
		return
	if _vehicle != null:
		velocity = Vector2.ZERO
		global_position = _vehicle.global_position
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	is_aiming_up = Input.is_action_pressed("aim_up")
	var axis := Input.get_axis("move_left", "move_right")
	var both := Input.is_action_pressed("move_left") and Input.is_action_pressed("move_right")
	var arc_modifier := Input.is_action_pressed("grenade")
	_aim_vector = AIM_HELPER.get_player_arc_aim(axis, facing, is_aiming_up, both, arc_modifier)
	velocity.x = axis * MOVE_SPEED
	if absf(axis) > 0.01:
		facing = signf(axis)
		_set_visual_facing(facing)
		_update_muzzle_positions()

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	_update_visual_animation(delta, velocity)

	var shoot := Input.is_action_pressed("shoot")
	if shoot:
		_request_fire()
	_fire_pressed_prev = shoot

	_snapshot_accum += delta
	if _snapshot_accum >= _snapshot_interval:
		_snapshot_accum = 0.0
		rpc_snapshot.rpc(global_position, velocity, facing, is_aiming_up, _downed)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_snapshot(pos: Vector2, vel: Vector2, face: float, aiming_up: bool, downed: bool) -> void:
	velocity = vel
	facing = face
	is_aiming_up = aiming_up
	_set_visual_facing(facing if facing != 0.0 else 1.0)
	_update_muzzle_positions()
	_interp.push_snapshot(pos)
	if downed != _downed:
		_downed = downed
		downed_changed.emit(_downed)
		_refresh_label()


func configure(p_name: String, p_peer_id: int) -> void:
	display_name = p_name
	peer_id = p_peer_id
	name = "Player_%d" % p_peer_id
	_refresh_label()


func get_peer_id() -> int:
	return peer_id


func get_health_component() -> HealthComponent:
	return _health


func get_max_health() -> int:
	return _health.max_health


func is_downed() -> bool:
	return _downed or _health.is_dead


func is_in_vehicle() -> bool:
	return _vehicle != null


func get_muzzle_position(aim: Vector2) -> Vector2:
	if aim.y < -0.2:
		return _muzzle_up.global_position
	return _muzzle.global_position


func get_equipped_weapon_id() -> StringName:
	return equipped_weapon_id


func set_equipped_weapon_id(weapon_id: StringName) -> void:
	equipped_weapon_id = weapon_id


func enter_vehicle(vehicle: Node2D) -> void:
	_vehicle = vehicle
	velocity = Vector2.ZERO
	hide()
	collision_layer = 0
	get_node("CollisionShape2D").set_deferred("disabled", true)
	_hurtbox.monitoring = false
	_hurtbox.monitorable = false


func exit_vehicle(spawn_position: Vector2) -> void:
	_vehicle = null
	global_position = spawn_position
	show()
	collision_layer = 2
	get_node("CollisionShape2D").set_deferred("disabled", false)
	_hurtbox.monitoring = true
	_hurtbox.monitorable = true
	_refresh_visual()


func apply_authoritative_health(current_hp: int, max_hp: int, downed: bool) -> void:
	_applying_auth_health = true
	_health.max_health = max_hp
	_health.current_health = current_hp
	_health.is_dead = downed or current_hp <= 0
	_downed = downed or current_hp <= 0
	_health.health_changed.emit(current_hp, max_hp)
	downed_changed.emit(_downed)
	_refresh_label()
	_refresh_visual()
	_applying_auth_health = false


func host_revive(hp: int = 1) -> void:
	# Host-only mutation before broadcast.
	_applying_auth_health = true
	_health.force_health_state(clampi(hp, 1, _health.max_health), false)
	_health.start_invulnerability(INVULN_SEC)
	_downed = false
	_refresh_label()
	_refresh_visual()
	_applying_auth_health = false


func _request_fire() -> void:
	if _combat == null:
		_combat = get_tree().get_first_node_in_group("host_combat_session") as HostCombatSession
	if _combat == null:
		return
	var aim := _aim_vector
	if aim.x != 0.0:
		facing = signf(aim.x)
		_set_visual_facing(facing)
	_update_muzzle_positions()
	_combat.request_fire_from_local(aim, get_muzzle_position(aim), equipped_weapon_id)


func _try_revive_other() -> void:
	# Local downed player cannot revive; standing player uses interact near downed ally.
	pass


func _physics_revive_check() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or _downed:
		return
	if event.is_action_pressed("interact"):
		_request_revive_nearest()


func _request_revive_nearest() -> void:
	if _combat == null:
		_combat = get_tree().get_first_node_in_group("host_combat_session") as HostCombatSession
	if _combat == null:
		return
	var best: NetPlayer = null
	var best_dist := 48.0
	for node in get_tree().get_nodes_in_group("net_players"):
		if node == self or not (node is NetPlayer):
			continue
		var other := node as NetPlayer
		if not other.is_downed():
			continue
		var d := global_position.distance_to(other.global_position)
		if d <= best_dist:
			best_dist = d
			best = other
	if best:
		_combat.request_revive_from_local(best.get_peer_id())


func _on_local_died() -> void:
	# Provisional local feedback; host will confirm via rpc_player_health.
	_downed = true
	downed_changed.emit(true)
	_refresh_label()
	if _should_report_health_to_host() and _combat:
		_combat.host_report_player_health(peer_id, 0, _health.max_health, true)


func _on_health_changed(current_health: int, max_health: int) -> void:
	_refresh_label()
	_refresh_visual()
	if _applying_auth_health:
		return
	if _should_report_health_to_host() and _combat and is_inside_tree():
		_combat.host_report_player_health(peer_id, current_health, max_health, current_health <= 0)


func _should_report_health_to_host() -> bool:
	return multiplayer.multiplayer_peer is WebRTCMultiplayerPeer and multiplayer.is_server()


func _refresh_label() -> void:
	if _label == null:
		return
	var state := "DOWN" if _downed else "HP %d" % _health.current_health
	_label.text = "%s [%d] %s" % [display_name, peer_id, state]


func _refresh_visual() -> void:
	_update_visual_animation(0.0, velocity)
	if _downed:
		_visual.modulate = Color(0.35, 0.35, 0.4, 1.0)
		return
	if _health.is_invulnerable:
		_visual.modulate = Color(0.72, 0.92, 1.0, 0.82)
	elif is_multiplayer_authority():
		_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_visual.modulate = Color(1.0, 0.92, 0.8, 1.0)


func _set_visual_facing(dir: float) -> void:
	var side := signf(dir if dir != 0.0 else 1.0)
	_visual.scale = Vector2(absf(_visual_base_scale.x) * side, _visual_base_scale.y)


func _update_muzzle_positions() -> void:
	var side := signf(facing if facing != 0.0 else 1.0)
	_muzzle.position = Vector2(absf(_muzzle_base_position.x) * side, _muzzle_base_position.y)
	_muzzle_up.position = Vector2(absf(_muzzle_up_base_position.x) * side, _muzzle_up_base_position.y)


func _update_visual_animation(delta: float, current_velocity: Vector2) -> void:
	var walking := _vehicle == null and not _downed and absf(current_velocity.x) > 8.0 and absf(current_velocity.y) < 120.0
	if walking:
		_walk_anim_time += delta
	else:
		_walk_anim_time = 0.0
	var aim_dir := _aim_vector if is_multiplayer_authority() else Vector2(facing, -1.0 if is_aiming_up else 0.0)
	PLAYER_VISUALS.apply_walk_pose(_visual, _walk_anim_time, walking, _visual_rest_position, aim_dir, false, is_aiming_up)
