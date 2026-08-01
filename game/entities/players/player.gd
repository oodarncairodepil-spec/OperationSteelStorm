class_name Player
extends CharacterBody2D
## Offline placeholder operative: run, jump, crouch, aim, shoot.
## Purpose: Phase 1 controllable avatar.
## Expected parent: level root.
## Required children: Visual, CollisionShape2D, HurtboxComponent, HealthComponent,
##   WeaponComponent, Muzzle, AimUpMuzzle, Label.
## Exported: config
## Signals: died, health_changed (proxied)
## Multiplayer authority: local offline for Phase 1; later host validates intent.

signal died
signal health_changed(current_health: int, max_health: int)
signal score_pickup_requested

const TEAM := &"player"
const AIM_HELPER := preload("res://scripts/aim_helper.gd")

@export var config: PlayerConfig

@onready var _visual: Sprite2D = $Visual
@onready var _label: Label = $Label
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _hurtbox_shape: CollisionShape2D = $HurtboxComponent/CollisionShape2D
@onready var _health: HealthComponent = $HealthComponent
@onready var _weapon: WeaponComponent = $WeaponComponent
@onready var _muzzle: Marker2D = $Muzzle
@onready var _muzzle_up: Marker2D = $AimUpMuzzle

var facing: float = 1.0
var is_crouching: bool = false
var is_aiming_up: bool = false
var score: int = 0
var _vehicle: Node2D

var _standing_shape: RectangleShape2D
var _crouch_shape: RectangleShape2D
var _standing_hurt: RectangleShape2D
var _crouch_hurt: RectangleShape2D
var _visual_base_scale: Vector2
var _muzzle_base_position: Vector2
var _muzzle_up_base_position: Vector2


func _ready() -> void:
	add_to_group("players")
	collision_layer = 2
	collision_mask = 1
	_hurtbox.team = TEAM
	_hurtbox.collision_layer = 2
	_hurtbox.collision_mask = 16
	_health.died.connect(_on_died)
	_health.health_changed.connect(_on_health_changed)
	_health.invulnerability_finished.connect(_refresh_visual)
	if config == null:
		push_error("Player missing PlayerConfig")
		return
	_health.configure(config.max_health, config.invulnerability_sec)
	_setup_shapes()
	_weapon.muzzle_path = _weapon.get_path_to(_muzzle)
	if config.default_weapon != null:
		_weapon.set_weapon(config.default_weapon)
	_label.text = "ROOK"
	_visual_base_scale = _visual.scale
	_muzzle_base_position = _muzzle.position
	_muzzle_up_base_position = _muzzle_up.position
	_set_visual_facing(facing)
	_update_muzzle_positions()
	_refresh_visual()


func _physics_process(delta: float) -> void:
	if _vehicle != null:
		velocity = Vector2.ZERO
		global_position = _vehicle.global_position
		return
	if _health.is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += config.gravity * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	is_crouching = Input.is_action_pressed("move_down") and is_on_floor()
	is_aiming_up = Input.is_action_pressed("aim_up") and not is_crouching
	_apply_pose()

	var axis := Input.get_axis("move_left", "move_right")
	var speed := config.move_speed
	if is_crouching:
		speed *= config.crouch_speed_factor
	velocity.x = axis * speed
	if absf(axis) > 0.01:
		facing = signf(axis)
		_set_visual_facing(facing)
		_update_muzzle_positions()

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = config.jump_velocity

	move_and_slide()

	if Input.is_action_pressed("shoot"):
		_try_shoot()


func get_health_component() -> HealthComponent:
	return _health


func get_weapon_component() -> WeaponComponent:
	return _weapon


func add_score(amount: int) -> void:
	score += amount


func is_in_vehicle() -> bool:
	return _vehicle != null


func enter_vehicle(vehicle: Node2D) -> void:
	_vehicle = vehicle
	velocity = Vector2.ZERO
	hide()
	collision_layer = 0
	_collision.disabled = true
	_hurtbox.monitoring = false
	_hurtbox.monitorable = false


func exit_vehicle(spawn_position: Vector2) -> void:
	_vehicle = null
	global_position = spawn_position
	show()
	collision_layer = 2
	_collision.disabled = false
	_hurtbox.monitoring = true
	_hurtbox.monitorable = true
	_refresh_visual()


func _try_shoot() -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var both := Input.is_action_pressed("move_left") and Input.is_action_pressed("move_right")
	var arc_modifier := Input.is_action_pressed("grenade")
	var aim := AIM_HELPER.get_player_arc_aim(axis, facing, is_aiming_up, both, arc_modifier)
	var muzzle := _muzzle
	if aim.y < -0.2:
		muzzle = _muzzle_up
	if aim.x != 0.0:
		facing = signf(aim.x)
		_set_visual_facing(facing)
	_update_muzzle_positions()
	_weapon.set_muzzle(muzzle)
	_weapon.try_fire(aim, TEAM)


func _setup_shapes() -> void:
	_standing_shape = RectangleShape2D.new()
	_standing_shape.size = config.standing_hurtbox_size
	_crouch_shape = RectangleShape2D.new()
	_crouch_shape.size = config.crouching_hurtbox_size
	_standing_hurt = RectangleShape2D.new()
	_standing_hurt.size = config.standing_hurtbox_size
	_crouch_hurt = RectangleShape2D.new()
	_crouch_hurt.size = config.crouching_hurtbox_size
	_collision.shape = _standing_shape
	_hurtbox_shape.shape = _standing_hurt


func _apply_pose() -> void:
	if is_crouching:
		_collision.shape = _crouch_shape
		_hurtbox_shape.shape = _crouch_hurt
		_collision.position.y = 5.0
		_hurtbox_shape.position.y = 5.0
		_visual.position = Vector2(0, 0)
	else:
		_collision.shape = _standing_shape
		_hurtbox_shape.shape = _standing_hurt
		_collision.position.y = 0.0
		_hurtbox_shape.position.y = 0.0
		_visual.position = Vector2(0, -2)


func _on_health_changed(current_health: int, max_health: int) -> void:
	health_changed.emit(current_health, max_health)
	_refresh_visual()


func _on_died() -> void:
	died.emit()
	_visual.modulate = Color(0.3, 0.3, 0.35, 1.0)
	_label.text = "DOWN"


func _refresh_visual() -> void:
	if _health.is_dead:
		return
	if _health.is_invulnerable:
		_visual.modulate = Color(0.72, 0.92, 1.0, 0.82)
	else:
		_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _set_visual_facing(dir: float) -> void:
	var side := signf(dir if dir != 0.0 else 1.0)
	_visual.scale = Vector2(absf(_visual_base_scale.x) * side, _visual_base_scale.y)


func _update_muzzle_positions() -> void:
	var side := signf(facing if facing != 0.0 else 1.0)
	_muzzle.position = Vector2(absf(_muzzle_base_position.x) * side, _muzzle_base_position.y)
	_muzzle_up.position = Vector2(absf(_muzzle_up_base_position.x) * side, _muzzle_up_base_position.y)
