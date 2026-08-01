class_name SiegeWalker
extends CharacterBody2D

signal defeated
signal phase_changed(phase: int)

const TEAM := &"enemy"
const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")
const AIM_HELPER := preload("res://scripts/aim_helper.gd")

@export var max_health: int = 20
@export var phase_two_health: int = 10
@export var projectile_speed: float = 260.0
@export var networked: bool = false
@export var authoritative: bool = true

@onready var _visual: Sprite2D = $Visual
@onready var _core: ColorRect = $Core
@onready var _label: Label = $Label
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _muzzle_left: Marker2D = $MuzzleLeft
@onready var _muzzle_right: Marker2D = $MuzzleRight
@onready var _combat: HostCombatSession = get_tree().get_first_node_in_group("host_combat_session") as HostCombatSession

var _phase: int = 1
var _attack_cooldown: float = 1.4
var _fight_active: bool = false
var _move_direction: float = -1.0
var _visual_base_scale: Vector2
var _pattern_index: int = 0


func _ready() -> void:
	add_to_group("bosses")
	collision_layer = 4
	collision_mask = 1
	_hurtbox.team = TEAM
	_hurtbox.collision_layer = 4
	_hurtbox.collision_mask = 8
	_health.configure(max_health, 0.0)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	_label.text = "SIEGE WALKER"
	_visual_base_scale = _visual.scale
	_set_visual_facing(_move_direction)
	_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_core.color = Color(0.95, 0.3, 0.22, 1.0)


func start_fight() -> void:
	_fight_active = true
	phase_changed.emit(_phase)


func get_phase() -> int:
	return _phase


func is_fight_active() -> bool:
	return _fight_active


func get_move_direction() -> float:
	return _move_direction


func _physics_process(delta: float) -> void:
	if networked and not authoritative:
		return
	if not _fight_active or _health.is_dead:
		velocity = Vector2.ZERO
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	velocity.x = _move_direction * (28.0 if _phase == 1 else 40.0)
	move_and_slide()
	if is_on_wall():
		_move_direction *= -1.0
		_set_visual_facing(_move_direction)
		_core.scale.x = _move_direction
	var player := _find_target_player()
	if player == null:
		return
	if _attack_cooldown <= 0.0:
		_fire_pattern(player)
		_attack_cooldown = 1.35 if _phase == 1 else 0.8


func _fire_pattern(player: Node2D) -> void:
	var target := player.global_position + Vector2(0.0, -10.0)
	var center_aim := AIM_HELPER.quantize_supported_aim(target - global_position, _move_direction)
	if _phase == 1:
		if _pattern_index % 2 == 0:
			_spawn_projectile(_muzzle_right.global_position, center_aim)
			_spawn_projectile(_muzzle_left.global_position, center_aim)
		else:
			_spawn_projectile(_muzzle_right.global_position, AIM_HELPER.quantize_supported_aim(center_aim.rotated(deg_to_rad(-12.0)), _move_direction))
			_spawn_projectile(_muzzle_left.global_position, AIM_HELPER.quantize_supported_aim(center_aim.rotated(deg_to_rad(12.0)), _move_direction))
		_pattern_index += 1
		return
	if _pattern_index % 2 == 0:
		var fan: Array[Vector2] = [
			center_aim,
			AIM_HELPER.quantize_supported_aim(center_aim.rotated(deg_to_rad(-18.0)), _move_direction),
			AIM_HELPER.quantize_supported_aim(center_aim.rotated(deg_to_rad(18.0)), _move_direction),
		]
		for aim in fan:
			_spawn_projectile(_muzzle_left.global_position, aim)
			_spawn_projectile(_muzzle_right.global_position, aim)
	else:
		var sweep: Array[Vector2] = [
			AIM_HELPER.quantize_supported_aim(center_aim.rotated(deg_to_rad(-28.0)), _move_direction),
			center_aim,
			AIM_HELPER.quantize_supported_aim(center_aim.rotated(deg_to_rad(28.0)), _move_direction),
		]
		for i in sweep.size():
			var muzzle := _muzzle_left if i % 2 == 0 else _muzzle_right
			_spawn_projectile(muzzle.global_position, sweep[i])
	_pattern_index += 1


func _spawn_projectile(origin: Vector2, aim: Vector2) -> void:
	if networked and authoritative and _combat:
		_combat.host_spawn_enemy_projectile(origin, aim, 1 if _phase == 1 else 2, projectile_speed, 1.6)
		return
	var bucket := get_tree().get_first_node_in_group("projectile_bucket")
	var parent := bucket if bucket != null else get_parent()
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	parent.add_child(projectile)
	projectile.launch(origin, aim, 1 if _phase == 1 else 2, projectile_speed, 1.6, TEAM)


func _find_target_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("net_players"):
		if node is NetPlayer and not (node as NetPlayer).is_in_vehicle() and not (node as NetPlayer).is_downed():
			return node as Node2D
	for node in get_tree().get_nodes_in_group("players"):
		if node is Player and not (node as Player).is_in_vehicle() and not (node as Player).get_health_component().is_dead:
			return node as Node2D
	return get_tree().get_first_node_in_group("players") as Node2D


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	_label.text = "BOSS %d/%d" % [current_health, maximum_health]
	_visual.modulate = Color(1.0, 0.92, 0.92, 1.0)
	if _phase == 1 and current_health <= phase_two_health:
		_phase = 2
		_core.color = Color(1.0, 0.72, 0.2, 1.0)
		phase_changed.emit(_phase)


func _on_died() -> void:
	_label.text = "WALKER DOWN"
	_visual.modulate = Color(0.34, 0.32, 0.34, 1.0)
	_core.color = Color(0.35, 0.2, 0.18, 1.0)
	defeated.emit()


func _set_visual_facing(dir: float) -> void:
	var side := signf(dir if dir != 0.0 else -1.0)
	_visual.scale = Vector2(absf(_visual_base_scale.x) * side, _visual_base_scale.y)


func apply_network_snapshot(pos: Vector2, hp: int, phase: int, move_direction: float, fight_active: bool) -> void:
	if authoritative:
		return
	global_position = pos
	_health.force_health_state(hp, hp <= 0)
	_phase = phase
	_move_direction = move_direction
	_fight_active = fight_active
	_set_visual_facing(move_direction)
	_core.scale.x = move_direction
	if hp <= 0:
		_label.text = "WALKER DOWN"
	elif fight_active:
		_label.text = "BOSS %d/%d" % [hp, _health.max_health]


func apply_network_death() -> void:
	if _health.is_dead:
		return
	_health.force_health_state(0, true)
	_label.text = "WALKER DOWN"
	_visual.modulate = Color(0.34, 0.32, 0.34, 1.0)
	_core.color = Color(0.35, 0.2, 0.18, 1.0)
