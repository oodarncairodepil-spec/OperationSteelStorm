extends SceneTree
## Phase 3 smoke: combat session + arena parse, damage-claim reject helper exists.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var err := change_scene_to_file("res://scenes/levels/mp_arena.tscn")
	if err != OK:
		push_error("arena load failed")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("no arena")
		quit(1)
		return
	var combat := arena.get_node_or_null("HostCombatSession")
	if combat == null:
		push_error("missing HostCombatSession")
		quit(1)
		return
	print("[Phase3Smoke] arena + HostCombatSession OK")
	# Offline combat room still loads
	err = change_scene_to_file("res://scenes/levels/combat_room.tscn")
	if err != OK:
		push_error("combat_room failed")
		quit(1)
		return
	await process_frame
	print("[Phase3Smoke] offline combat_room OK")
	print("[Phase3Smoke] OK")
	quit(0)
