class_name RescueCaptive
extends Area2D

signal rescued
signal evacuated

@onready var _visual: Sprite2D = $Visual
@onready var _label: Label = $Label

@export var run_speed: float = 90.0

var _nearby_player: Node2D
var _rescued: bool = false
var safe_position: Vector2 = Vector2.ZERO
var _evacuated: bool = false


func _ready() -> void:
	collision_layer = 128
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visual()


func _process(_delta: float) -> void:
	if _rescued:
		_tick_escape(_delta)
		return
	if _nearby_player == null:
		return
	if Input.is_action_just_pressed("interact"):
		_rescued = true
		if safe_position == Vector2.ZERO:
			safe_position = global_position + Vector2(150.0, -18.0)
		_update_visual()
		rescued.emit()


func is_rescued() -> bool:
	return _rescued


func is_evacuated() -> bool:
	return _evacuated


func force_rescue(target_safe_position: Vector2) -> void:
	if _rescued:
		return
	_rescued = true
	safe_position = target_safe_position
	_update_visual()
	rescued.emit()


func apply_network_snapshot(pos: Vector2, rescued_state: bool, evacuated_state: bool) -> void:
	global_position = pos
	_rescued = rescued_state
	_evacuated = evacuated_state
	_update_visual()


func _on_body_entered(body: Node) -> void:
	if _rescued or not (body is Node2D and body.has_method("get_health_component")):
		return
	_nearby_player = body as Node2D
	_update_visual()


func _on_body_exited(body: Node) -> void:
	if body == _nearby_player:
		_nearby_player = null
		_update_visual()


func _update_visual() -> void:
	if _evacuated:
		_visual.modulate = Color(0.45, 0.85, 0.5, 0.25)
		_label.text = ""
	elif _rescued:
		_visual.modulate = Color(0.55, 1.0, 0.62, 1.0)
		_label.text = "RUNNING"
	elif _nearby_player:
		_visual.modulate = Color(1.0, 0.92, 0.72, 1.0)
		_label.text = "PRESS E"
	else:
		_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_label.text = "CAPTIVE"


func _tick_escape(delta: float) -> void:
	if _evacuated:
		return
	var target := safe_position if safe_position != Vector2.ZERO else global_position + Vector2(150.0, -18.0)
	global_position = global_position.move_toward(target, run_speed * delta)
	if global_position.distance_to(target) <= 2.0:
		_evacuated = true
		monitoring = false
		monitorable = false
		_update_visual()
		evacuated.emit()
