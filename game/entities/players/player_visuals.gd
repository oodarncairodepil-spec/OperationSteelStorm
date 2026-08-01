class_name PlayerVisuals
extends RefCounted

const WALK_FPS := 8.0
const IDLE := preload("res://assets/sprites/players/player_rook_idle_02.png")
const WALK_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/players/player_rook_walk_01.png"),
	preload("res://assets/sprites/players/player_rook_walk_02.png"),
	preload("res://assets/sprites/players/player_rook_walk_03.png"),
	preload("res://assets/sprites/players/player_rook_walk_04.png"),
]


static func texture_for_walk_cycle(anim_time: float, moving: bool) -> Texture2D:
	if not moving or WALK_FRAMES.is_empty():
		return IDLE
	var frame := int(floor(anim_time * WALK_FPS)) % WALK_FRAMES.size()
	return WALK_FRAMES[frame]
