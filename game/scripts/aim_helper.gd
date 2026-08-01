class_name AimHelper
extends RefCounted

const ARC_SHALLOW_X := 0.9238795
const ARC_SHALLOW_Y := -0.3826834
const ARC_DIAGONAL_X := 0.7071068
const ARC_DIAGONAL_Y := -0.7071068
const ARC_STEEP_X := 0.3826834
const ARC_STEEP_Y := -0.9238795


static func get_player_arc_aim(
	horizontal_input: float,
	facing: float,
	aiming_up: bool,
	both_horizontal_pressed: bool = false,
	arc_modifier: bool = false
) -> Vector2:
	var side := signf(facing if facing != 0.0 else 1.0)
	var input_side := signf(horizontal_input)
	if not aiming_up:
		if input_side != 0.0:
			return Vector2(input_side, 0.0)
		return Vector2(side, 0.0)
	if both_horizontal_pressed:
		return Vector2(0.0, -1.0)
	if not arc_modifier:
		if input_side == 0.0:
			return Vector2(0.0, -1.0)
		return Vector2(input_side, -1.0).normalized()
	if input_side == 0.0:
		return Vector2(ARC_STEEP_X * side, ARC_STEEP_Y)
	if input_side == side:
		return Vector2(ARC_SHALLOW_X * side, ARC_SHALLOW_Y)
	return Vector2(ARC_DIAGONAL_X * input_side, ARC_DIAGONAL_Y)


static func quantize_supported_aim(direction: Vector2, fallback_side: float = 1.0) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2(signf(fallback_side if fallback_side != 0.0 else 1.0), 0.0)
	var side := signf(direction.x)
	if side == 0.0:
		side = signf(fallback_side if fallback_side != 0.0 else 1.0)
	var normalized := direction.normalized()
	if absf(normalized.x) <= 0.12 and normalized.y <= -0.88:
		return Vector2(0.0, -1.0)
	if normalized.y >= -0.15:
		return Vector2(side, 0.0)
	var up_angle := rad_to_deg(atan2(-normalized.y, absf(normalized.x)))
	if up_angle < 33.75:
		return Vector2(ARC_SHALLOW_X * side, ARC_SHALLOW_Y)
	if up_angle < 56.25:
		return Vector2(ARC_DIAGONAL_X * side, ARC_DIAGONAL_Y)
	return Vector2(ARC_STEEP_X * side, ARC_STEEP_Y)
