class_name WeaponDefinition
extends Resource
## Data-driven weapon stats. Gameplay reads this instead of hard-coded values.

@export var id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export var damage: int = 1
@export var fire_interval_sec: float = 0.25
@export var projectile_speed: float = 420.0
@export var projectile_lifetime_sec: float = 1.2
@export var unlimited_ammo: bool = true
@export var max_ammo: int = 0
@export var pellet_count: int = 1
@export var spread_degrees: float = 0.0
@export var projectile_scene: PackedScene
