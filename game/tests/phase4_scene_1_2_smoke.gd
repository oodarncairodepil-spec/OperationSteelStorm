extends SceneTree
## Headless smoke for the new offline Phase 4 Scene 1-2 mission.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var err := change_scene_to_file("res://scenes/levels/phase4_scene_1_2.tscn")
	if err != OK:
		push_error("Phase 4 Scene 1-2 failed to load: %s" % error_string(err))
		quit(1)
		return
	for _i in 4:
		await process_frame
	var scene := current_scene
	if scene == null:
		push_error("Phase 4 Scene 1-2 missing")
		quit(1)
		return
	var players := get_nodes_in_group("players")
	var enemies := get_nodes_in_group("enemies")
	var captive := scene.get_node_or_null("Objectives/RescueCaptive")
	var scatter := scene.get_node_or_null("Pickups/WeaponPickup")
	var high_platform := scene.get_node_or_null("World/HighPlatform")
	var drop_platform := scene.get_node_or_null("World/DropPlatform")
	print("[Phase4Scene12Smoke] players=%d enemies=%d" % [players.size(), enemies.size()])
	if players.is_empty():
		push_error("Expected at least one player in Phase 4 Scene 1-2")
		quit(1)
		return
	if captive == null or scatter == null:
		push_error("Expected captive and scatter pickup in Phase 4 Scene 1-2")
		quit(1)
		return
	if high_platform == null or drop_platform == null:
		push_error("Expected high-ground traversal platforms in Phase 4 Scene 1-2")
		quit(1)
		return
	print("[Phase4Scene12Smoke] OK")
	quit(0)
