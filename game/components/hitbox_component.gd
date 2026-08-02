class_name HitboxComponent
extends Area2D
## Deals damage to HurtboxComponents on overlap. Used by projectiles and melee.
## Expected parent: projectile/attacker. Set damage and team before enabling.
## Multiplayer authority (later): only host should spawn authoritative hitboxes.

signal hit_landed(hurtbox: HurtboxComponent)

@export var damage: int = 1
@export var team: StringName = &"neutral"
@export var destroy_on_hit: bool = true
@export var hit_world: bool = true

var _spent: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func configure(p_damage: int, p_team: StringName) -> void:
	damage = p_damage
	team = p_team
	_spent = false


func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	if hurtbox.team == team:
		return
	if hurtbox.receive_hit(damage, self):
		hit_landed.emit(hurtbox)
		if destroy_on_hit:
			_spent = true
			_request_owner_despawn()


func _on_body_entered(body: Node2D) -> void:
	if _spent or not hit_world:
		return
	# Static world geometry ends projectile travel.
	if body is StaticBody2D or body is TileMapLayer or body is TileMap:
		_spent = true
		_request_owner_despawn()


func _request_owner_despawn() -> void:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("despawn"):
		owner_node.call_deferred("despawn")
	elif owner_node != null:
		owner_node.call_deferred("queue_free")
