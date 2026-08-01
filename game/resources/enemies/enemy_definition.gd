class_name EnemyDefinition
extends Resource
## Configurable enemy stats for the reusable enemy framework.

@export var id: StringName = &"enemy"
@export var display_name: String = "Enemy"
@export var max_health: int = 3
@export var move_speed: float = 60.0
@export var detection_range: float = 180.0
@export var attack_range: float = 160.0
@export var attack_damage: int = 1
@export var attack_interval_sec: float = 0.9
@export var score_reward: int = 100
@export var projectile_speed: float = 260.0
@export var projectile_lifetime_sec: float = 1.4
@export var tint: Color = Color(0.75, 0.25, 0.28, 1.0)
@export var hover_amplitude: float = 0.0
@export var hover_speed: float = 2.0
@export var hover_height_offset: float = 0.0
@export var standoff_distance: float = 0.0
@export var aim_height_offset: float = -8.0
@export var projectile_scene: PackedScene
