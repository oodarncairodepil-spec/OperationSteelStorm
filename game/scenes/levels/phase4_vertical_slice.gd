class_name Phase4VerticalSlice
extends Node2D

const PLAYER_SCENE := preload("res://entities/players/player.tscn")
const ENEMY_SCENE := preload("res://entities/enemies/patrol_trooper.tscn")
const PICKUP_SCENE := preload("res://entities/world/weapon_pickup.tscn")
const CAPTIVE_SCENE := preload("res://entities/world/rescue_captive.tscn")
const ROVER_SCENE := preload("res://entities/vehicles/assault_rover.tscn")
const BOSS_SCENE := preload("res://entities/enemies/siege_walker.tscn")

const PLAYER_CONFIG := preload("res://resources/players/default_player_config.tres")
const RIFLE := preload("res://resources/weapons/standard_rifle.tres")
const SCATTER := preload("res://resources/weapons/scatter_cannon.tres")
const RAPID := preload("res://resources/weapons/rapid_pulse_gun.tres")
const ROVER_CANNON := preload("res://resources/weapons/assault_rover_cannon.tres")
const PATROL := preload("res://resources/enemies/patrol_trooper_def.tres")
const SHIELD := preload("res://resources/enemies/shield_trooper_def.tres")
const DRONE := preload("res://resources/enemies/drone_unit_def.tres")
const HEAVY := preload("res://resources/enemies/heavy_gunner_def.tres")

@onready var _spawn: Marker2D = $PlayerSpawn
@onready var _camera: FollowCamera = $FollowCamera
@onready var _hud: GameHUD = $GameHUD
@onready var _projectile_bucket: Node2D = $ProjectileBucket
@onready var _enemy_root: Node2D = $Enemies
@onready var _pickup_root: Node2D = $Pickups
@onready var _objective_root: Node2D = $Objectives
@onready var _vehicle_root: Node2D = $Vehicles
@onready var _boss_root: Node2D = $Bosses
@onready var _scatter_marker: Marker2D = $MissionMarkers/ScatterPickup
@onready var _rapid_marker: Marker2D = $MissionMarkers/RapidPickup
@onready var _captive_marker: Marker2D = $MissionMarkers/Captive
@onready var _captive_safe_marker: Marker2D = $MissionMarkers/CaptiveSafe
@onready var _rover_marker: Marker2D = $MissionMarkers/Rover
@onready var _boss_marker: Marker2D = $MissionMarkers/Boss

var _player: Player
var _boss
var _rover
var _captive

var _finished: bool = false
var _rescued_count: int = 0
var _picked_scatter: bool = false
var _picked_rapid: bool = false
var _spawned_catwalk_wave: bool = false
var _spawned_rescue_wave: bool = false
var _spawned_rover_wave: bool = false
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _enemies_alive: int = 0
var _result_won: bool = false
var _death_resume_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_projectile_bucket.add_to_group("projectile_bucket")
	_hud.restart_pressed.connect(_restart)
	_hud.menu_pressed.connect(_to_menu)
	_spawn_player()
	_spawn_pickups()
	_spawn_rescue_target()
	_spawn_rover()
	_spawn_enemy(Vector2(420, 320), PATROL, Vector2(-60, 0), Vector2(60, 0))
	_spawn_enemy(Vector2(760, 320), PATROL, Vector2(-50, 0), Vector2(50, 0))
	_hud.show_banner("MISSION 01 - BEACHHEAD", 2.0)
	_update_objective()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 3328
	_camera.limit_bottom = 360


func _process(_delta: float) -> void:
	if _finished or _player == null:
		return
	_handle_local_interact()
	if _player.get_health_component().is_dead:
		_finish(false)
		return
	_progress_scripted_events()
	_update_objective()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_to_menu()


func _handle_local_interact() -> void:
	if not Input.is_action_just_pressed("interact") or _player == null:
		return
	if _captive and not _captive.is_rescued() and _player.global_position.distance_to(_captive.global_position) <= 40.0:
		_captive.force_rescue(_captive_safe_marker.global_position)
		return
	if _rover == null:
		return
	if _player.is_in_vehicle():
		_rover.force_disembark()
		return
	if _player.global_position.distance_to(_rover.global_position) <= 86.0:
		_rover.board_rider(_player)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.config = PLAYER_CONFIG
	_player.global_position = _spawn.global_position
	add_child(_player)
	_player.died.connect(_on_player_died)
	_hud.bind_player(_player)
	_camera.set_target(_player)
	_camera.global_position = _player.global_position
	if RIFLE:
		_player.get_weapon_component().set_weapon(RIFLE)


func _spawn_pickups() -> void:
	var scatter := PICKUP_SCENE.instantiate()
	scatter.weapon_definition = SCATTER
	scatter.pickup_text = "SCATTER"
	scatter.global_position = _scatter_marker.global_position
	_pickup_root.add_child(scatter)
	scatter.collected.connect(func(_weapon_id: StringName) -> void:
		_picked_scatter = true
		_hud.show_banner("SCATTER CANNON ONLINE", 1.2)
	)

	var rapid := PICKUP_SCENE.instantiate()
	rapid.weapon_definition = RAPID
	rapid.pickup_text = "PULSE"
	rapid.tint = Color(0.48, 0.9, 1.0, 1.0)
	rapid.global_position = _rapid_marker.global_position
	_pickup_root.add_child(rapid)
	rapid.collected.connect(func(_weapon_id: StringName) -> void:
		_picked_rapid = true
		_hud.show_banner("RAPID PULSE GUN ONLINE", 1.2)
	)


func _spawn_rescue_target() -> void:
	_captive = CAPTIVE_SCENE.instantiate()
	_captive.global_position = _captive_marker.global_position
	_captive.safe_position = _captive_safe_marker.global_position
	_objective_root.add_child(_captive)
	_captive.rescued.connect(func() -> void:
		_rescued_count = 1
		_hud.show_banner("CIVILIAN SECURED", 1.2)
	)
	_captive.evacuated.connect(func() -> void:
		_hud.show_banner("CIVILIAN EVACUATED", 1.0)
	)


func _spawn_rover() -> void:
	_rover = ROVER_SCENE.instantiate()
	_rover.mounted_weapon = ROVER_CANNON
	_rover.global_position = _rover_marker.global_position
	_vehicle_root.add_child(_rover)
	_rover.boarded.connect(func(_peer_id: int) -> void:
		_hud.show_banner("ASSAULT ROVER ONLINE", 1.2)
		_hud.set_weapon_override("ROVER CANNON", "AMMO ∞")
	)
	_rover.disembarked.connect(func(_peer_id: int) -> void:
		_hud.clear_weapon_override()
	)


func _progress_scripted_events() -> void:
	var progress_x := _player.global_position.x
	if not _spawned_catwalk_wave and progress_x >= 920.0:
		_spawned_catwalk_wave = true
		_hud.show_banner("SMELTER CATWALK", 1.2)
		_spawn_enemy(Vector2(1080, 200), DRONE, Vector2.ZERO, Vector2.ZERO)
		_spawn_enemy(Vector2(1220, 320), SHIELD, Vector2(-40, 0), Vector2(40, 0))
	if not _spawned_rescue_wave and progress_x >= 1560.0:
		_spawned_rescue_wave = true
		_hud.show_banner("LOCKUP BREACH", 1.2)
		_spawn_enemy(Vector2(1680, 320), PATROL, Vector2(-50, 0), Vector2(50, 0))
		_spawn_enemy(Vector2(1810, 320), DRONE, Vector2.ZERO, Vector2.ZERO)
	if not _spawned_rover_wave and _rescued_count > 0 and progress_x >= 2140.0:
		_spawned_rover_wave = true
		_hud.show_banner("HEAVY PLAZA", 1.2)
		_spawn_enemy(Vector2(2280, 320), HEAVY, Vector2(-60, 0), Vector2(60, 0))
		_spawn_enemy(Vector2(2420, 320), SHIELD, Vector2(-40, 0), Vector2(40, 0))
	if not _boss_spawned and _rover and _rover.has_occupant() and progress_x >= 2700.0:
		_spawn_boss()


func _spawn_boss() -> void:
	_boss_spawned = true
	_hud.show_banner("SIEGE WALKER INBOUND", 1.6)
	_boss = BOSS_SCENE.instantiate()
	_boss.global_position = _boss_marker.global_position
	_boss_root.add_child(_boss)
	_boss.defeated.connect(_on_boss_defeated)
	_boss.phase_changed.connect(func(phase: int) -> void:
		_hud.show_banner("BOSS PHASE %d" % phase, 1.0)
	)
	_boss.start_fight()


func _spawn_enemy(pos: Vector2, definition: EnemyDefinition, patrol_a: Vector2, patrol_b: Vector2) -> void:
	var enemy := ENEMY_SCENE.instantiate() as PatrolTrooper
	enemy.definition = definition
	enemy.global_position = pos
	enemy.patrol_offset_a = patrol_a
	enemy.patrol_offset_b = patrol_b
	_enemy_root.add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	_enemies_alive += 1


func _on_enemy_died(_enemy: PatrolTrooper, score_reward: int) -> void:
	if _finished or _player == null:
		return
	_player.add_score(score_reward)
	_hud.set_score(_player.score)
	_enemies_alive = maxi(0, _enemies_alive - 1)


func _on_boss_defeated() -> void:
	_boss_defeated = true
	_player.add_score(1000)
	_hud.set_score(_player.score)
	_finish(true)


func _on_player_died() -> void:
	if not _finished:
		_finish(false)


func _finish(won: bool) -> void:
	if _finished:
		return
	_finished = true
	_result_won = won
	if not won and _player != null:
		_death_resume_position = _player.global_position
	var score := _player.score if _player else 0
	var detail := "Rescued %d/1 | Scatter %s | Pulse %s | Boss %s" % [
		_rescued_count,
		"Y" if _picked_scatter else "N",
		"Y" if _picked_rapid else "N",
		"DOWN" if _boss_defeated else "ACTIVE",
	]
	call_deferred("_show_finish_result", won, score, detail)


func _show_finish_result(won: bool, score: int, detail: String) -> void:
	get_tree().paused = true
	_hud.set_result_actions("Play Again" if won else "Try Again", "Main Menu")
	_hud.show_result(won, score, detail)
	_hud.set_objective("Mission complete" if won else "You were downed")


func _update_objective() -> void:
	if _finished:
		return
	var objective := "Secure the beachhead"
	if not _picked_scatter:
		objective = "Reach the scatter cannon crate"
	elif not _rescued_count:
		objective = "Rescue the captive worker"
	elif _rover and not _rover.has_occupant():
		objective = "Board the Assault Rover"
	elif not _picked_rapid:
		objective = "Advance to the pulse gun cache"
	elif not _boss_spawned:
		objective = "Push into the drydock"
	elif not _boss_defeated:
		objective = "Destroy the Siege Walker"
	elif _enemies_alive > 0:
		objective = "Mop up remaining hostiles (%d)" % _enemies_alive
	_hud.set_objective(objective)


func _restart() -> void:
	if not _finished:
		SceneManager.go_to_phase4_mission()
		return
	get_tree().paused = false
	_hud.hide_result()
	if _result_won:
		SceneManager.go_to_phase4_mission()
		return
	_finished = false
	if _player != null:
		var revive_position := _death_resume_position if _death_resume_position != Vector2.ZERO else _spawn.global_position
		_player.revive_full(revive_position)
		_camera.set_target(_player)
		_camera.global_position = _player.global_position
	_hud.show_banner("TRY AGAIN", 1.0)
	_update_objective()


func _to_menu() -> void:
	get_tree().paused = false
	SceneManager.go_to_main_menu()
