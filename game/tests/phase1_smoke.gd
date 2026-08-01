extends SceneTree
## Headless smoke test for Phase 1: load combat room, run a few frames, quit.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var err := change_scene_to_file("res://scenes/levels/combat_room.tscn")
	if err != OK:
		push_error("Failed to open combat room: %s" % error_string(err))
		quit(1)
		return
	await process_frame
	await process_frame
	await process_frame
	var room := current_scene
	if room == null:
		push_error("Combat room scene missing")
		quit(1)
		return
	var players := get_nodes_in_group("players")
	var enemies := get_nodes_in_group("enemies")
	print("[Phase1Smoke] players=%d enemies=%d scene=%s" % [players.size(), enemies.size(), room.name])
	if players.is_empty() or enemies.is_empty():
		push_error("Expected player and enemies in combat room")
		quit(1)
		return
	print("[Phase1Smoke] OK")
	quit(0)
