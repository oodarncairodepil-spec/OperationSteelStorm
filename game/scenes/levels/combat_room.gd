class_name CombatRoom
extends Node2D
## Phase 1 offline combat room: platforms, player, patrol troopers, clear objective.
## Expected parent: scene tree root (via SceneManager).
## Required children: World, Player, Enemies, ProjectileBucket, Camera, HUD.
## Multiplayer authority: local offline simulation.

const PLAYER_SCENE := preload("res://entities/players/player.tscn")
const ENEMY_SCENE := preload("res://entities/enemies/patrol_trooper.tscn")
const PLAYER_CONFIG := preload("res://resources/players/default_player_config.tres")
const ENEMY_DEF := preload("res://resources/enemies/patrol_trooper_def.tres")

@onready var _spawn: Marker2D = $PlayerSpawn
@onready var _enemy_spawns: Node2D = $EnemySpawns
@onready var _projectile_bucket: Node2D = $ProjectileBucket
@onready var _camera: FollowCamera = $FollowCamera
@onready var _hud: GameHUD = $GameHUD

var _player: Player
var _enemies_alive: int = 0
var _finished: bool = false


func _ready() -> void:
	_projectile_bucket.add_to_group("projectile_bucket")
	_hud.restart_pressed.connect(_restart)
	_hud.menu_pressed.connect(_to_menu)
	_spawn_player()
	_spawn_enemies()
	_hud.set_objective("Eliminate all Patrol Troopers (%d left)" % _enemies_alive)
	_hud.show_banner("COMBAT ROOM", 1.5)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 1280
	_camera.limit_bottom = 360


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_to_menu()


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.config = PLAYER_CONFIG
	_player.global_position = _spawn.global_position
	add_child(_player)
	_player.died.connect(_on_player_died)
	_player.health_changed.connect(func(cur: int, mx: int) -> void:
		_hud.set_health(cur, mx)
	)
	_hud.bind_player(_player)
	_camera.set_target(_player)
	_camera.global_position = _player.global_position


func _spawn_enemies() -> void:
	for marker in _enemy_spawns.get_children():
		if not (marker is Marker2D):
			continue
		var enemy := ENEMY_SCENE.instantiate() as PatrolTrooper
		enemy.definition = ENEMY_DEF
		enemy.global_position = (marker as Marker2D).global_position
		add_child(enemy)
		enemy.died.connect(_on_enemy_died)
		_enemies_alive += 1


func _on_enemy_died(enemy: PatrolTrooper, score_reward: int) -> void:
	if _finished or _player == null:
		return
	_player.add_score(score_reward)
	_hud.set_score(_player.score)
	_enemies_alive = maxi(0, _enemies_alive - 1)
	_hud.set_objective("Eliminate all Patrol Troopers (%d left)" % _enemies_alive)
	if _enemies_alive <= 0:
		_finish(true)


func _on_player_died() -> void:
	if _finished:
		return
	_finish(false)


func _finish(won: bool) -> void:
	_finished = true
	var score := _player.score if _player else 0
	call_deferred("_show_finish_result", won, score)


func _show_finish_result(won: bool, score: int) -> void:
	_hud.show_result(won, score)
	_hud.set_objective("Room cleared" if won else "You were downed")


func _restart() -> void:
	SceneManager.go_to_combat_room()


func _to_menu() -> void:
	SceneManager.go_to_main_menu()
