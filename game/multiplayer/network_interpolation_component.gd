class_name NetworkInterpolationComponent
extends Node
## Interpolates a Node2D toward networked snapshots.
## Expected parent: remote-controlled entity root.

@export var target_path: NodePath
@export var catchup_speed: float = 14.0
@export var snap_distance: float = 80.0

var _target: Node2D
var _goal_pos: Vector2 = Vector2.ZERO
var _has_goal: bool = false


func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		_target = get_parent() as Node2D


func push_snapshot(pos: Vector2) -> void:
	_goal_pos = pos
	_has_goal = true
	if _target != null and _target.global_position.distance_to(pos) > snap_distance:
		_target.global_position = pos


func _physics_process(delta: float) -> void:
	if not _has_goal or _target == null:
		return
	var weight := 1.0 - exp(-catchup_speed * delta)
	_target.global_position = _target.global_position.lerp(_goal_pos, weight)
