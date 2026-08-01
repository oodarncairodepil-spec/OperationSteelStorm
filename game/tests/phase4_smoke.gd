extends SceneTree
## Headless smoke for the offline Phase 4 vertical slice.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var err := change_scene_to_file("res://scenes/levels/phase4_vertical_slice.tscn")
	if err != OK:
		push_error("Phase 4 scene failed to load: %s" % error_string(err))
		quit(1)
		return
	for i in 4:
		await process_frame
	var scene := current_scene
	if scene == null:
		push_error("Phase 4 scene missing")
		quit(1)
		return
	var players := get_nodes_in_group("players")
	var enemies := get_nodes_in_group("enemies")
	var bosses := get_nodes_in_group("bosses")
	var rover := scene.get_node_or_null("Vehicles/AssaultRover")
	var captive := scene.get_node_or_null("Objectives/RescueCaptive")
	print("[Phase4Smoke] players=%d enemies=%d bosses=%d" % [players.size(), enemies.size(), bosses.size()])
	if players.is_empty():
		push_error("Expected at least one player in phase 4 scene")
		quit(1)
		return
	if rover == null or captive == null:
		push_error("Expected rover and rescue target in phase 4 scene")
		quit(1)
		return
	print("[Phase4Smoke] OK")
	quit(0)
