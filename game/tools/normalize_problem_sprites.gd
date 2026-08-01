extends SceneTree

const ROOT := "res://assets/sprites/"

const JOBS := [
	{
		"path": "players/player_rook_idle_02.png",
		"size": Vector2i(128, 128),
		"bottom_margin": 4,
		"side_margin": 10,
		"top_margin": 4,
	},
	{
		"path": "players/player_rook_walk_01.png",
		"size": Vector2i(128, 128),
		"bottom_margin": 4,
		"side_margin": 10,
		"top_margin": 4,
	},
	{
		"path": "players/player_rook_walk_02.png",
		"size": Vector2i(128, 128),
		"bottom_margin": 4,
		"side_margin": 10,
		"top_margin": 4,
	},
	{
		"path": "players/player_rook_walk_03.png",
		"size": Vector2i(128, 128),
		"bottom_margin": 4,
		"side_margin": 10,
		"top_margin": 4,
	},
	{
		"path": "players/player_rook_walk_04.png",
		"size": Vector2i(128, 128),
		"bottom_margin": 4,
		"side_margin": 10,
		"top_margin": 4,
	},
	{
		"path": "enemies/enemy_shieldtrooper_idle_02.png",
		"size": Vector2i(160, 160),
		"bottom_margin": 6,
		"side_margin": 10,
		"top_margin": 8,
	},
]


func _initialize() -> void:
	var errors: PackedStringArray = []
	for job in JOBS:
		var err := _normalize(job)
		if err != "":
			errors.append(err)
	if errors.is_empty():
		print("[NormalizeProblemSprites] OK")
		quit(0)
		return
	for err in errors:
		push_error(err)
	quit(1)


func _normalize(job: Dictionary) -> String:
	var path := ROOT + String(job["path"])
	if not FileAccess.file_exists(path):
		return "Missing %s" % path
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return "Failed to load %s" % path

	var bounds := _non_transparent_bounds(image)
	var source := image.get_region(bounds)
	var target_size: Vector2i = job["size"]
	var side_margin := int(job.get("side_margin", 0))
	var top_margin := int(job.get("top_margin", 0))
	var bottom_margin := int(job.get("bottom_margin", 0))
	var max_w := maxi(1, target_size.x - side_margin * 2)
	var max_h := maxi(1, target_size.y - top_margin - bottom_margin)

	if source.get_width() > max_w or source.get_height() > max_h:
		var scale_ratio := minf(float(max_w) / float(source.get_width()), float(max_h) / float(source.get_height()))
		var resized_w := maxi(1, int(floor(source.get_width() * scale_ratio)))
		var resized_h := maxi(1, int(floor(source.get_height() * scale_ratio)))
		source.resize(resized_w, resized_h, Image.INTERPOLATE_NEAREST)

	var canvas := Image.create_empty(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var dest_x := maxi(0, int((target_size.x - source.get_width()) / 2))
	var dest_y := maxi(top_margin, target_size.y - source.get_height() - bottom_margin)
	canvas.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(dest_x, dest_y))
	var err := canvas.save_png(path)
	if err != OK:
		return "Failed to save %s: %s" % [path, error_string(err)]
	return ""


func _non_transparent_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i(Vector2i.ZERO, image.get_size())
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
