extends SceneTree

const ROOT := "res://assets/sprites/"

const JOBS := [
	{
		"path": "players/player_rook_idle_01.png",
		"size": Vector2i(96, 96),
		"mode": "bottom_center",
		"bottom_margin": 4,
	},
	{
		"path": "players/player_rook_idle_02.png",
		"size": Vector2i(96, 96),
		"mode": "bottom_center",
		"bottom_margin": 4,
	},
	{
		"path": "world/npc_civilian_idle_01.png",
		"size": Vector2i(96, 96),
		"mode": "bottom_center",
		"bottom_margin": 4,
	},
	{
		"path": "enemies/enemy_shieldtrooper_idle_01.png",
		"size": Vector2i(160, 160),
		"mode": "bottom_center",
		"bottom_margin": 6,
	},
	{
		"path": "enemies/enemy_shieldtrooper_idle_02.png",
		"size": Vector2i(160, 160),
		"mode": "bottom_center",
		"bottom_margin": 6,
	},
	{
		"path": "enemies/enemy_drone_hover_01.png",
		"size": Vector2i(160, 160),
		"mode": "center",
		"offset": Vector2i(0, -8),
	},
	{
		"path": "enemies/enemy_heavygunner_idle_01.png",
		"size": Vector2i(160, 160),
		"mode": "bottom_center",
		"bottom_margin": 6,
	},
	{
		"path": "vehicles/veh_assault_rover_idle_01.png",
		"size": Vector2i(192, 96),
		"mode": "bottom_center",
		"bottom_margin": 6,
	},
	{
		"path": "bosses/boss_siegewalker_body_idle_01.png",
		"size": Vector2i(192, 192),
		"mode": "bottom_center",
		"bottom_margin": 8,
	},
	{
		"path": "ui/ui_results_panel.png",
		"size": Vector2i(192, 128),
		"mode": "center",
		"offset": Vector2i.ZERO,
	},
]


func _initialize() -> void:
	var errors: Array[String] = []
	for job in JOBS:
		var result := _pad_asset(job)
		if result != "":
			errors.append(result)
	if errors.is_empty():
		print("[PadPhase4Anchors] OK")
		quit(0)
		return
	for err in errors:
		push_error(err)
	quit(1)


func _pad_asset(job: Dictionary) -> String:
	var path := ROOT + String(job["path"])
	if not FileAccess.file_exists(path):
		return ""
	var source := Image.load_from_file(path)
	if source == null or source.is_empty():
		return "Failed to load %s" % path
	var target_size: Vector2i = job["size"]
	if source.get_width() == target_size.x and source.get_height() == target_size.y:
		return ""
	var canvas := Image.create_empty(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var dest := Vector2i.ZERO
	var mode := String(job.get("mode", "center"))
	if mode == "bottom_center":
		var bottom_margin := int(job.get("bottom_margin", 0))
		dest.x = maxi(0, int((target_size.x - source.get_width()) / 2))
		dest.y = maxi(0, target_size.y - source.get_height() - bottom_margin)
	else:
		dest.x = maxi(0, int((target_size.x - source.get_width()) / 2))
		dest.y = maxi(0, int((target_size.y - source.get_height()) / 2))
	var offset: Vector2i = job.get("offset", Vector2i.ZERO)
	dest += offset
	var src_rect := Rect2i(Vector2i.ZERO, Vector2i(mini(source.get_width(), target_size.x), mini(source.get_height(), target_size.y)))
	canvas.blit_rect(source, src_rect, dest)
	var err := canvas.save_png(path)
	if err != OK:
		return "Failed to save %s: %s" % [path, error_string(err)]
	return ""
