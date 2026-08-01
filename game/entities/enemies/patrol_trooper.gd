class_name PatrolTrooper
extends CharacterBody2D
## Patrol trooper with optional host-authoritative networking (Phase 3).
## Offline: full AI locally. Online: AI + death only on host; clients interpolate.

signal died(enemy: PatrolTrooper, score_reward: int)

const TEAM := &"enemy"
const STATE_PATROL := &"patrol"
const STATE_ATTACK := &"attack"
const STATE_DEAD := &"dead"
const AIM_HELPER := preload("res://scripts/aim_helper.gd")
const ART_PATROL := preload("res://assets/sprites/enemies/enemy_shieldtrooper_idle_02.png")
const ART_SHIELD := preload("res://assets/sprites/enemies/enemy_shieldtrooper_idle_02.png")
const ART_DRONE := preload("res://assets/sprites/enemies/enemy_drone_hover_01.png")
const ART_HEAVY := preload("res://assets/sprites/enemies/enemy_heavygunner_idle_01.png")

@export var definition: EnemyDefinition
@export var patrol_offset_a: Vector2 = Vector2(-80, 0)
@export var patrol_offset_b: Vector2 = Vector2(80, 0)
@export var networked: bool = false
@export var authoritative: bool = true

var network_id: int = 0

@onready var _visual: Sprite2D = $Visual
@onready var _label: Label = $Label
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _state: StateMachine = $StateMachine
@onready var _muzzle: Marker2D = $Muzzle
@onready var _interp: NetworkInterpolationComponent = get_node_or_null("NetworkInterpolationComponent")

var _origin: Vector2
var _target_index: int = 0
var _attack_cooldown: float = 0.0
var _snapshot_accum: float = 0.0
var _facing: float = -1.0
var _network_dead: bool = false
var _combat: HostCombatSession
var _hover_time: float = 0.0
var _hover_anchor_y: float = 0.0
var _visual_base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_hurtbox.team = TEAM
	_hurtbox.collision_layer = 4
	_hurtbox.collision_mask = 8
	_origin = global_position
	_hover_anchor_y = global_position.y
	_combat = get_tree().get_first_node_in_group("host_combat_session") as HostCombatSession
	if definition == null:
		push_error("PatrolTrooper missing EnemyDefinition")
		return
	_health.configure(definition.max_health, 0.0)
	_health.died.connect(_on_died)
	_health.health_changed.connect(_on_health_changed)
	_label.text = definition.display_name.to_upper()
	_apply_art_from_definition()
	_state.start(STATE_PATROL)
	if networked and not authoritative:
		# Clients do not resolve hits locally.
		_hurtbox.set_deferred("monitorable", true)
		if _interp:
			_interp.set_physics_process(true)
	elif _interp:
		_interp.set_physics_process(false)


func _physics_process(delta: float) -> void:
	if definition == null or _state.is_in(STATE_DEAD) or _network_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if networked and not authoritative:
		# Movement comes from snapshots / interpolation.
		return

	if definition.hover_amplitude > 0.0:
		_hover_time += delta * maxf(definition.hover_speed, 0.1)
		var target_y := _hover_anchor_y + definition.hover_height_offset + sin(_hover_time) * definition.hover_amplitude
		velocity.y = (target_y - global_position.y) * 8.0
	elif not is_on_floor():
		velocity.y += 900.0 * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	match _state.current_state:
		STATE_PATROL:
			_tick_patrol(delta)
			if _can_see_player():
				_state.transition_to(STATE_ATTACK)
		STATE_ATTACK:
			_tick_attack(delta)
			if not _can_see_player():
				_state.transition_to(STATE_PATROL)

	move_and_slide()

	if networked and authoritative and _combat:
		_snapshot_accum += delta
		if _snapshot_accum >= 0.05:
			_snapshot_accum = 0.0
			_combat.host_broadcast_enemy_snapshot(self)


func get_health_component() -> HealthComponent:
	return _health


func get_state_name() -> StringName:
	return _state.current_state


func get_facing() -> float:
	return _facing


func is_network_dead() -> bool:
	return _network_dead or _state.is_in(STATE_DEAD)


func apply_network_snapshot(pos: Vector2, vel: Vector2, state: StringName, hp: int, facing: float) -> void:
	if authoritative or _network_dead:
		return
	velocity = vel
	_facing = facing
	_set_visual_facing(facing if facing != 0.0 else 1.0)
	_muzzle.position.x = absf(_muzzle.position.x) * signf(facing if facing != 0.0 else -1.0)
	if _interp:
		_interp.push_snapshot(pos)
	else:
		global_position = pos
	_health.force_health_state(hp, hp <= 0)
	if state != _state.current_state and state != STATE_DEAD:
		_state.transition_to(state)


func apply_network_death() -> void:
	if _network_dead:
		return
	_network_dead = true
	_state.transition_to(STATE_DEAD)
	_visual.modulate = Color(0.24, 0.2, 0.2, 1.0)
	_label.text = "X"
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	await get_tree().create_timer(0.6).timeout
	queue_free()


func _tick_patrol(_delta: float) -> void:
	var targets: Array[Vector2] = [_origin + patrol_offset_a, _origin + patrol_offset_b]
	var target := targets[_target_index]
	var dir := signf(target.x - global_position.x)
	if absf(target.x - global_position.x) < 4.0:
		_target_index = 1 - _target_index
		velocity.x = 0.0
	else:
		velocity.x = dir * definition.move_speed
		_set_facing(dir)


func _tick_attack(_delta: float) -> void:
	var player := _find_any_player()
	if player == null:
		velocity.x = 0.0
		return
	var target := player.global_position + Vector2(0.0, definition.aim_height_offset)
	var dir := signf(target.x - global_position.x)
	if dir != 0.0:
		_set_facing(dir)
	var distance := global_position.distance_to(target)
	if definition.standoff_distance > 0.0:
		if distance > definition.standoff_distance + 12.0:
			velocity.x = dir * definition.move_speed
		elif distance < definition.standoff_distance - 12.0:
			velocity.x = -dir * definition.move_speed
		else:
			velocity.x = 0.0
	else:
		velocity.x = 0.0
	if distance <= definition.attack_range and _attack_cooldown <= 0.0:
		_fire_at_player(player)
		_attack_cooldown = definition.attack_interval_sec


func _fire_at_player(player: Node2D) -> void:
	if definition.projectile_scene == null or player == null:
		return
	var target := player.global_position + Vector2(0.0, definition.aim_height_offset)
	var aim := AIM_HELPER.quantize_supported_aim(target - _muzzle.global_position, _facing)
	match String(definition.id):
		"drone_unit":
			_emit_enemy_projectile(_muzzle.global_position, AIM_HELPER.quantize_supported_aim(aim.rotated(deg_to_rad(-12.0)), _facing))
			_emit_enemy_projectile(_muzzle.global_position, AIM_HELPER.quantize_supported_aim(aim.rotated(deg_to_rad(12.0)), _facing))
		"heavy_gunner":
			_emit_enemy_projectile(_muzzle.global_position, aim)
			_emit_enemy_projectile(_muzzle.global_position, AIM_HELPER.quantize_supported_aim(aim.rotated(deg_to_rad(-10.0)), _facing))
			_emit_enemy_projectile(_muzzle.global_position, AIM_HELPER.quantize_supported_aim(aim.rotated(deg_to_rad(10.0)), _facing))
		"shield_trooper":
			_emit_enemy_projectile(_muzzle.global_position, aim)
		_:
			_emit_enemy_projectile(_muzzle.global_position, aim)


func _can_see_player() -> bool:
	var player := _find_any_player()
	if player == null:
		return false
	if player.has_method("is_downed") and player.call("is_downed"):
		return false
	if player.has_method("get_health_component"):
		var health: HealthComponent = player.call("get_health_component")
		if health and health.is_dead:
			return false
	return global_position.distance_to(player.global_position) <= definition.detection_range


func _find_any_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("net_players"):
		if not (node is NetPlayer):
			continue
		var net_player := node as NetPlayer
		if net_player.is_downed() or net_player.is_in_vehicle():
			continue
		return net_player
	for node in get_tree().get_nodes_in_group("players"):
		if not (node is Player):
			continue
		var player := node as Player
		if player.is_in_vehicle() or player.get_health_component().is_dead:
			continue
		return player
	return null


func _set_facing(dir: float) -> void:
	if dir == 0.0:
		return
	_facing = signf(dir)
	_set_visual_facing(_facing)
	_muzzle.position.x = absf(_muzzle.position.x) * _facing


func _on_health_changed(current_health: int, _max_health: int) -> void:
	_label.text = "HP %d" % current_health
	_visual.modulate = Color(1.0, 0.85, 0.85, 1.0)


func _on_died() -> void:
	if _network_dead:
		return
	_state.transition_to(STATE_DEAD)
	died.emit(self, definition.score_reward if definition else 0)
	_visual.modulate = Color(0.24, 0.2, 0.2, 1.0)
	_label.text = "X"
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	if networked and not authoritative:
		return
	if not networked:
		await get_tree().create_timer(0.6).timeout
		queue_free()


func _apply_art_from_definition() -> void:
	if definition == null:
		return
	match String(definition.id):
		"drone_unit":
			_visual.texture = ART_DRONE
			_visual.scale = Vector2(0.26, 0.26)
			_visual.position = Vector2(0, -34)
		"heavy_gunner":
			_visual.texture = ART_HEAVY
			_visual.scale = Vector2(0.28, 0.28)
			_visual.position = Vector2(0, -20)
		"shield_trooper":
			_visual.texture = ART_SHIELD
			_visual.scale = Vector2(0.28, 0.28)
			_visual.position = Vector2(0, -20)
		_:
			_visual.texture = ART_PATROL
			_visual.scale = Vector2(0.25, 0.25)
			_visual.position = Vector2(0, -18)
	_visual_base_scale = _visual.scale
	_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_set_visual_facing(_facing)


func _set_visual_facing(dir: float) -> void:
	var side := signf(dir if dir != 0.0 else -1.0)
	_visual.scale = Vector2(absf(_visual_base_scale.x) * side, _visual_base_scale.y)


func _emit_enemy_projectile(origin: Vector2, aim: Vector2) -> void:
	if networked and authoritative and _combat:
		_combat.host_spawn_enemy_projectile(
			origin,
			aim,
			definition.attack_damage,
			definition.projectile_speed,
			definition.projectile_lifetime_sec,
		)
		return
	var projectile := definition.projectile_scene.instantiate() as Node2D
	var bucket := get_tree().get_first_node_in_group("projectile_bucket")
	var parent := bucket if bucket != null else get_parent()
	parent.add_child(projectile)
	if projectile.has_method("launch"):
		projectile.call(
			"launch",
			origin,
			aim,
			definition.attack_damage,
			definition.projectile_speed,
			definition.projectile_lifetime_sec,
			TEAM,
		)
