class_name Projectile
extends Area2D
## Basic hitscan-free projectile with lifetime and HitboxComponent.
## Purpose: rifle / enemy bullet placeholder.
## Expected parent: projectile bucket under the level.
## Required children: Visual, CollisionShape2D, HitboxComponent.
## Multiplayer authority (later): host spawns and despawns.

@onready var _hitbox: HitboxComponent = $HitboxComponent
@onready var _visual: ColorRect = $Visual

var _velocity: Vector2 = Vector2.ZERO
var _lifetime: float = 1.0
var _alive: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(
	origin: Vector2,
	direction: Vector2,
	damage: int,
	speed: float,
	lifetime_sec: float,
	team: StringName,
) -> void:
	global_position = origin
	_velocity = direction.normalized() * speed
	_lifetime = lifetime_sec
	_alive = true
	_hitbox.configure(damage, team)
	_apply_team_collision(team)
	_visual.color = Color(0.95, 0.85, 0.2, 1.0) if team == &"player" else Color(0.95, 0.35, 0.25, 1.0)
	monitoring = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	global_position += _velocity * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		despawn()


func despawn() -> void:
	_alive = false
	set_physics_process(false)
	queue_free()


func _apply_team_collision(team: StringName) -> void:
	# Layers: 4=projectile_player(8), 5=projectile_enemy(16)
	# Masks: world(1) + enemy(4) for player shots; world(1) + player(2) for enemy shots.
	if team == &"player":
		collision_layer = 8
		collision_mask = 1 | 4
		_hitbox.collision_layer = 8
		_hitbox.collision_mask = 4
	else:
		collision_layer = 16
		collision_mask = 1 | 2
		_hitbox.collision_layer = 16
		_hitbox.collision_mask = 2


func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		despawn()
