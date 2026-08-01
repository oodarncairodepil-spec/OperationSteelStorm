class_name FollowCamera
extends Camera2D
## Smooth horizontal follower with level limits for Phase 1 single-player.
## Expected parent: level root. Assign target_path to the player.
## Multiplayer authority: local visual only.

@export var target_path: NodePath
@export var follow_smoothing: float = 8.0
@export var look_ahead_px: float = 24.0
@export var vertical_softness: float = 4.0

var _target: Node2D


func _ready() -> void:
	make_current()
	position_smoothing_enabled = false
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D


func set_target(node: Node2D) -> void:
	_target = node


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var facing := 1.0
	if "facing" in _target:
		facing = float(_target.get("facing"))
	var desired := _target.global_position + Vector2(look_ahead_px * facing, -20.0)
	var weight := 1.0 - exp(-follow_smoothing * delta)
	global_position.x = lerpf(global_position.x, desired.x, weight)
	global_position.y = lerpf(global_position.y, desired.y, weight * (vertical_softness / follow_smoothing))
	_clamp_to_limits()


func _clamp_to_limits() -> void:
	if limit_left < limit_right:
		global_position.x = clampf(global_position.x, limit_left + 160.0, limit_right - 160.0)
	if limit_top < limit_bottom:
		global_position.y = clampf(global_position.y, limit_top + 90.0, limit_bottom - 90.0)
