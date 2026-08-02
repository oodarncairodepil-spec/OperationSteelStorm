class_name PlayerVisuals
extends RefCounted

const WALK_RATE := 10.0
const WALK_BOB_Y := 1.5
const WALK_SWAY_DEGREES := 2.5
const AIM_UP_BIAS_Y := -4.0
const AIM_UP_ROT_DEGREES := -11.0
const AIM_DIAG_ROT_DEGREES := 8.0
const CROUCH_OFFSET_Y := 8.0
const CROUCH_SCALE_Y := 0.9
const CROUCH_SCALE_X := 1.02
const AIM_UP_SCALE_X := 0.98
const AIM_UP_SCALE_Y := 1.02
const IDLE := preload("res://assets/sprites/players/player_rook_idle_02.png")


static func apply_walk_pose(
	sprite: Sprite2D,
	anim_time: float,
	moving: bool,
	base_position: Vector2,
	base_scale: Vector2,
	aim_dir: Vector2,
	crouching: bool,
	aiming: bool,
) -> void:
	sprite.texture = IDLE
	sprite.scale = base_scale
	var pose_pos := base_position
	if crouching:
		pose_pos = base_position + Vector2(0.0, CROUCH_OFFSET_Y)
		sprite.scale = Vector2(signf(base_scale.x) * absf(base_scale.x) * CROUCH_SCALE_X, absf(base_scale.y) * CROUCH_SCALE_Y)

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
			sprite.scale = Vector2(signf(sprite.scale.x) * absf(base_scale.x) * AIM_UP_SCALE_X, absf(sprite.scale.y) * AIM_UP_SCALE_Y)
		elif dir.y < -0.35:
			pose_pos += Vector2(0.0, AIM_UP_BIAS_Y * 0.6)
			rot += AIM_DIAG_ROT_DEGREES * (1.0 if dir.x > 0.0 else -1.0)

	sprite.position = pose_pos + Vector2(0.0, bob)
	sprite.rotation_degrees = rot
