extends SceneTree
## Phase 2 headless checks: config load + menu scenes parse via change_scene.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var config := NetworkConfigData.load_from_disk()
	if config.signaling_url.is_empty():
		push_error("signaling_url empty")
		quit(1)
		return
	if config.snapshot_rate_hz <= 0.0:
		push_error("invalid snapshot rate")
		quit(1)
		return
	print("[Phase2Smoke] signaling_url=%s ice=%d" % [config.signaling_url, config.build_ice_servers_dict().size()])

	var err := change_scene_to_file("res://scenes/menus/multiplayer_menu.tscn")
	if err != OK:
		push_error("mp menu load failed")
		quit(1)
		return
	await process_frame
	await process_frame
	print("[Phase2Smoke] multiplayer_menu OK")

	err = change_scene_to_file("res://scenes/menus/main_menu.tscn")
	if err != OK:
		push_error("main menu load failed")
		quit(1)
		return
	await process_frame
	print("[Phase2Smoke] main_menu OK")

	err = change_scene_to_file("res://scenes/menus/mp_lobby.tscn")
	if err != OK:
		push_error("lobby load failed")
		quit(1)
		return
	await process_frame
	print("[Phase2Smoke] mp_lobby OK")

	var scene_manager := get_root().get_node("/root/SceneManager")
	scene_manager.pending_result = {
		"won": true,
		"score": 1234,
		"detail": "Smoke result",
		"headline": "MISSION COMPLETE",
		"subheadline": "Smoke Report",
		"restart_target": "phase4_single",
	}
	err = change_scene_to_file("res://scenes/menus/mission_result.tscn")
	if err != OK:
		push_error("mission result load failed")
		quit(1)
		return
	await process_frame
	print("[Phase2Smoke] mission_result OK")

	err = change_scene_to_file("res://scenes/levels/mp_arena.tscn")
	if err != OK:
		push_error("arena load failed")
		quit(1)
		return
	await process_frame
	print("[Phase2Smoke] mp_arena OK (no peer expected)")
	print("[Phase2Smoke] OK")
	quit(0)
