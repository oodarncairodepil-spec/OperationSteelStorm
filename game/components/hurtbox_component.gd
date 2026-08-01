class_name HurtboxComponent
extends Area2D
## Receives overlapping hitboxes and forwards damage to a HealthComponent.
## Expected parent: entity root. Assign health_path or sibling HealthComponent.
## Multiplayer authority (later): host resolves damage; clients visualize only.

signal damaged(amount: int, source: Node)

@export var health_path: NodePath
@export var team: StringName = &"neutral"

var _health: HealthComponent


func _ready() -> void:
	monitoring = true
	monitorable = true
	if health_path != NodePath():
		_health = get_node_or_null(health_path) as HealthComponent
	if _health == null:
		_health = get_parent().get_node_or_null("HealthComponent") as HealthComponent


func receive_hit(amount: int, source: Node) -> bool:
	if _health == null:
		return false
	var applied := _health.apply_damage(amount)
	if applied:
		damaged.emit(amount, source)
	return applied


func get_health() -> HealthComponent:
	return _health
