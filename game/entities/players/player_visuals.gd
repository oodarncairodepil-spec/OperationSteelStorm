class_name PlayerVisuals
extends RefCounted

const WALK_RATE := 10.0
const WALK_BOB_Y := 1.5
const WALK_SWAY_DEGREES := 2.5
const AIM_UP_BIAS_Y := -2.0
const AIM_UP_ROT_DEGREES := -6.0
const AIM_DIAG_ROT_DEGREES := 5.0
const CROUCH_OFFSET_Y := 10.0
const IDLE := preload("res://assets/sprites/players/player_rook_idle_02.png")


static func apply_walk_pose(
	sprite: Sprite2D,
	anim_time: float,
	moving: bool,
	base_position: Vector2,
	aim_dir: Vector2,
	crouching: bool,
	aiming: bool,
) -> void:
	sprite.texture = IDLE
	var pose_pos := base_position
	if crouching:
		pose_pos = base_position + Vector2(0.0, CROUCH_OFFSET_Y)

	var rot := 0.0
	var bob := 0.0
	if moving and not crouching:
		var phase := anim_time * WALK_RATE
		bob = sin(phase * PI) * WALK_BOB_Y
		rot = sin(phase * TAU) * WALK_SWAY_DEGREES

	if aiming:
		var dir := aim_dir.normalized() if aim_dir.length() > 0.01 else Vector2(0.0, -1.0)
		if dir.y < -0.75 and absf(dir.x) < 0.35:
			pose_pos += Vector2(0.0, AIM_UP_BIAS_Y)
			rot += AIM_UP_ROT_DEGREES
		elif dir.y < -0.35:
			pose_pos += Vector2(0.0, AIM_UP_BIAS_Y * 0.6)
			rot += AIM_DIAG_ROT_DEGREES * (1.0 if dir.x > 0.0 else -1.0)

	sprite.position = pose_pos + Vector2(0.0, bob)
	sprite.rotation_degrees = rot
