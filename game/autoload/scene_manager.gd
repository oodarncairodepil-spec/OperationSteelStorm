extends Node
## Global scene transitions. Keep this autoload focused on navigation only.

const BOOT_SCENE := "res://scenes/ui/boot_test.tscn"
const MAIN_MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const SINGLE_PLAYER_SCENE_SELECT_SCENE := "res://scenes/menus/single_player_scene_select.tscn"
const COMBAT_ROOM_SCENE := "res://scenes/levels/combat_room.tscn"
const PHASE4_SCENE := "res://scenes/levels/phase4_vertical_slice.tscn"
const PHASE4_SCENE_1_2 := "res://scenes/levels/phase4_scene_1_2.tscn"
const MULTIPLAYER_MENU_SCENE := "res://scenes/menus/multiplayer_menu.tscn"
const JOIN_ROOM_SCENE := "res://scenes/menus/join_room.tscn"
const MP_LOBBY_SCENE := "res://scenes/menus/mp_lobby.tscn"
const MP_ARENA_SCENE := "res://scenes/levels/mp_arena.tscn"
const MP_PHASE4_SCENE := "res://scenes/levels/mp_phase4_coop.tscn"
const MP_PHASE4_SCENE_1_2 := "res://scenes/levels/mp_phase4_scene_1_2.tscn"
const MISSION_RESULT_SCENE := "res://scenes/menus/mission_result.tscn"

var pending_join_name: String = "Operative"
var pending_single_scene_id: String = "phase4_beachhead"
var pending_multiplayer_scene_id: String = "phase4_beachhead"
var pending_result: Dictionary = {
	"won": false,
	"score": 0,
	"detail": "",
	"headline": "MISSION FAILED",
	"subheadline": "Operation report",
	"restart_target": "phase4_single",
}


func go_to_main_menu() -> void:
	_change(MAIN_MENU_SCENE)


func go_to_single_player_scene_select() -> void:
	_change(SINGLE_PLAYER_SCENE_SELECT_SCENE)


func go_to_combat_room() -> void:
	_change(COMBAT_ROOM_SCENE)


func go_to_phase4_mission() -> void:
	pending_single_scene_id = "phase4_beachhead"
	_change(PHASE4_SCENE)


func go_to_phase4_scene_1_2() -> void:
	pending_single_scene_id = "phase4_scene_1_2"
	_change(PHASE4_SCENE_1_2)


func go_to_multiplayer_menu() -> void:
	_change(MULTIPLAYER_MENU_SCENE)


func go_to_join_room(player_name: String) -> void:
	pending_join_name = player_name
	_change(JOIN_ROOM_SCENE)


func go_to_mp_lobby() -> void:
	_change(MP_LOBBY_SCENE)


func go_to_mp_arena() -> void:
	_change(MP_ARENA_SCENE)


func go_to_mp_phase4_mission() -> void:
	pending_multiplayer_scene_id = "phase4_beachhead"
	_change(MP_PHASE4_SCENE)


func go_to_mp_phase4_scene_1_2() -> void:
	pending_multiplayer_scene_id = "phase4_scene_1_2"
	_change(MP_PHASE4_SCENE_1_2)


func go_to_mission_result(
	won: bool,
	score: int,
	detail: String,
	restart_target: String,
	subheadline: String = "Operation report"
) -> void:
	pending_result = {
		"won": won,
		"score": score,
		"detail": detail,
		"headline": "MISSION COMPLETE" if won else "MISSION FAILED",
		"subheadline": subheadline,
		"restart_target": restart_target,
	}
	_change(MISSION_RESULT_SCENE)


func restart_pending_result() -> void:
	match String(pending_result.get("restart_target", "phase4_single")):
		"combat_room":
			go_to_combat_room()
		"phase4_scene_1_2":
			go_to_phase4_scene_1_2()
		"phase4_coop":
			go_to_mp_phase4_mission()
		"phase4_coop_scene_1_2":
			go_to_mp_phase4_scene_1_2()
		_:
			go_to_phase4_mission()


func go_to_boot() -> void:
	_change(BOOT_SCENE)


func _change(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager failed to load %s (error %s)" % [path, error_string(err)])
