class_name WeaponPickup
extends Area2D

signal collected(weapon_id: StringName)

@export var weapon_definition: WeaponDefinition
@export var pickup_text: String = "PICKUP"
@export var tint: Color = Color(0.95, 0.8, 0.28, 1.0)

@onready var _visual: ColorRect = $Visual
@onready var _label: Label = $Label

var _consumed: bool = false


func _ready() -> void:
	collision_layer = 64
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_visual.color = tint
	_label.text = pickup_text


func _on_body_entered(body: Node) -> void:
	if _consumed or not (body is Player) or weapon_definition == null:
		return
	var player := body as Player
	var weapon := player.get_weapon_component()
	if weapon == null:
		return
	weapon.set_weapon(weapon_definition)
	_consumed = true
	monitoring = false
	monitorable = false
	collected.emit(weapon_definition.id)
	call_deferred("queue_free")
