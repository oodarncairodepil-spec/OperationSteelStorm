class_name Phase4Scene12
extends Node2D

const PLAYER_SCENE := preload("res://entities/players/player.tscn")
const ENEMY_SCENE := preload("res://entities/enemies/patrol_trooper.tscn")
const PICKUP_SCENE := preload("res://entities/world/weapon_pickup.tscn")
const CAPTIVE_SCENE := preload("res://entities/world/rescue_captive.tscn")

const PLAYER_CONFIG := preload("res://resources/players/default_player_config.tres")
const RIFLE := preload("res://resources/weapons/standard_rifle.tres")
const SCATTER := preload("res://resources/weapons/scatter_cannon.tres")
const PATROL := preload("res://resources/enemies/patrol_trooper_def.tres")
const SHIELD := preload("res://resources/enemies/shield_trooper_def.tres")
const DRONE := preload("res://resources/enemies/drone_unit_def.tres")

@onready var _spawn: Marker2D = $PlayerSpawn
@onready var _camera: FollowCamera = $FollowCamera
@onready var _hud: GameHUD = $GameHUD
@onready var _projectile_bucket: Node2D = $ProjectileBucket
@onready var _enemy_root: Node2D = $Enemies
@onready var _pickup_root: Node2D = $Pickups
@onready var _objective_root: Node2D = $Objectives
@onready var _scatter_marker: Marker2D = $MissionMarkers/ScatterPickup
@onready var _captive_marker: Marker2D = $MissionMarkers/Captive
@onready var _captive_safe_marker: Marker2D = $MissionMarkers/CaptiveSafe

var _player: Player
var _captive: RescueCaptive
var _scatter_pickup: WeaponPickup

var _finished: bool = false
var _picked_scatter: bool = false
var _rescued_count: int = 0
var _captive_evacuated: bool = false
var _enemies_alive: int = 0
var _result_won: bool = false
var _death_resume_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_projectile_bucket.add_to_group("projectile_bucket")
	_hud.restart_pressed.connect(_restart)
	_hud.menu_pressed.connect(_to_menu)
	_spawn_player()
	_spawn_scatter_pickup()
	_spawn_rescue_target()
	_spawn_enemy(Vector2(560, 288), PATROL, Vector2(-40, 0), Vector2(40, 0))
	_spawn_enemy(Vector2(1040, 166), DRONE, Vector2.ZERO, Vector2.ZERO)
	_spawn_enemy(Vector2(1770, 320), SHIELD, Vector2(-30, 0), Vector2(30, 0))
	_hud.show_banner("MISSION 1-2: HIGH RESCUE", 2.0)
	_update_objective()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 2400
	_camera.limit_bottom = 360


func _process(_delta: float) -> void:
	if _finished or _player == null:
		return
	_handle_local_interact()
	if _player.get_health_component().is_dead:
		_finish(false)
		return
	_update_objective()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_to_menu()


func _handle_local_interact() -> void:
	if not Input.is_action_just_pressed("interact") or _player == null:
		return
	if _captive and not _captive.is_rescued() and _player.global_position.distance_to(_captive.global_position) <= 40.0:
		_captive.force_rescue(_captive_safe_marker.global_position)


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


func _spawn_scatter_pickup() -> void:
	_scatter_pickup = PICKUP_SCENE.instantiate() as WeaponPickup
	_scatter_pickup.weapon_definition = SCATTER
	_scatter_pickup.pickup_text = "SCATTER"
	_scatter_pickup.global_position = _scatter_marker.global_position
	_pickup_root.add_child(_scatter_pickup)
	_scatter_pickup.collected.connect(func(_weapon_id: StringName) -> void:
		_unlock_scatter("SCATTER CANNON ONLINE")
	)


func _spawn_rescue_target() -> void:
	_captive = CAPTIVE_SCENE.instantiate() as RescueCaptive
	_captive.global_position = _captive_marker.global_position
	_captive.safe_position = _captive_safe_marker.global_position
	_objective_root.add_child(_captive)
	_captive.rescued.connect(func() -> void:
		_rescued_count = 1
		_unlock_scatter("SCATTER CANNON ONLINE")
		_hud.show_banner("PRISONER RELEASED", 1.2)
	)
	_captive.evacuated.connect(func() -> void:
		_captive_evacuated = true
		_hud.show_banner("PRISONER SAFE", 1.0)
		if _enemies_alive <= 0:
			_finish(true)
	)


func _unlock_scatter(banner_text: String) -> void:
	if _picked_scatter:
		return
	_picked_scatter = true
	if _scatter_pickup and is_instance_valid(_scatter_pickup):
		_scatter_pickup.call_deferred("queue_free")
	if _player:
		_player.get_weapon_component().set_weapon(SCATTER)
	_hud.show_banner(banner_text, 1.2)


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
	if _captive_evacuated and _enemies_alive <= 0:
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
	var detail := "Rescued %s | Evacuated %s | Scatter %s | Guards %d" % [
		"Y" if _rescued_count > 0 else "N",
		"Y" if _captive_evacuated else "N",
		"Y" if _picked_scatter else "N",
		_enemies_alive,
	]
	call_deferred("_show_finish_result", won, score, detail)


func _show_finish_result(won: bool, score: int, detail: String) -> void:
	get_tree().paused = true
	_hud.set_result_actions("Play Again" if won else "Try Again", "Main Menu")
	_hud.show_result(won, score, detail)
	_hud.set_objective("Prisoner safe" if won else "You were downed")


func _update_objective() -> void:
	if _finished:
		return
	var objective := "Climb to the scatter cache"
	if not _picked_scatter:
		objective = "Jump up to the high scatter platform"
	elif not _rescued_count:
		objective = "Drop down and release the prisoner"
	elif not _captive_evacuated:
		objective = "Cover the prisoner while they run back"
	elif _enemies_alive > 0:
		objective = "Clear remaining guards (%d)" % _enemies_alive
	else:
		objective = "Hold the route"
	_hud.set_objective(objective)


func _restart() -> void:
	if not _finished:
		SceneManager.go_to_phase4_scene_1_2()
		return
	get_tree().paused = false
	_hud.hide_result()
	if _result_won:
		SceneManager.go_to_phase4_scene_1_2()
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
