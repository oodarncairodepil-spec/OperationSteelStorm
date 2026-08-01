class_name PlayerConfig
extends Resource
## Tunable player movement and durability for the MVP.

@export var max_health: int = 3
@export var move_speed: float = 140.0
@export var crouch_speed_factor: float = 0.55
@export var jump_velocity: float = -280.0
@export var gravity: float = 900.0
@export var invulnerability_sec: float = 1.0
@export var standing_hurtbox_size: Vector2 = Vector2(14, 28)
@export var crouching_hurtbox_size: Vector2 = Vector2(14, 18)
@export var default_weapon: WeaponDefinition
