class_name AssaultRover
extends CharacterBody2D

signal boarded(peer_id: int)
signal disembarked(peer_id: int)
signal destroyed

@export var mounted_weapon: WeaponDefinition
@export var drive_speed: float = 190.0
@export var max_health: int = 8
@export var networked: bool = false
@export var authoritative: bool = true

const AIM_HELPER := preload("res://scripts/aim_helper.gd")

@onready var _visual: Sprite2D = $Visual
@onready var _label: Label = $Label
@onready var _weapon: WeaponComponent = $WeaponComponent
@onready var _muzzle: Marker2D = $Muzzle
@onready var _exit_marker: Marker2D = $ExitMarker
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _board_area: Area2D = $BoardArea

var _occupant: Node2D
var _nearby_player: Node2D
var _facing: float = 1.0
var _visual_base_scale: Vector2
var _muzzle_base_position: Vector2
var _exit_base_position: Vector2
var _occupant_peer_id: int = 0
var _remote_axis: float = 0.0
var _remote_aim_up: bool = false
var _remote_fire: bool = false
var _remote_arc_modifier: bool = false


func _ready() -> void:
	collision_layer = 256
	collision_mask = 1
	_hurtbox.team = &"player"
	_hurtbox.collision_layer = 2
	_hurtbox.collision_mask = 16
	_weapon.muzzle_path = _weapon.get_path_to(_muzzle)
	if mounted_weapon:
		_weapon.set_weapon(mounted_weapon)
	_health.configure(max_health, 0.2)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	_board_area.body_entered.connect(_on_board_area_entered)
	_board_area.body_exited.connect(_on_board_area_exited)
	_visual_base_scale = _visual.scale
	_muzzle_base_position = _muzzle.position
	_exit_base_position = _exit_marker.position
	_set_visual_facing(_facing)
	_update_mount_positions()
	_refresh_label()


func _physics_process(_delta: float) -> void:
	if networked and not authoritative:
		return
	if _occupant == null and _nearby_player and Input.is_action_just_pressed("interact"):
		_board(_nearby_player)
		return
	if _occupant == null:
		velocity = Vector2.ZERO
		return
	var axis := Input.get_axis("move_left", "move_right")
	var aiming_up := Input.is_action_pressed("aim_up")
	var firing := Input.is_action_pressed("shoot")
	var arc_modifier := Input.is_action_pressed("grenade")
	if networked and _occupant is NetPlayer and not (_occupant as NetPlayer).is_multiplayer_authority():
		axis = _remote_axis
		aiming_up = _remote_aim_up
		firing = _remote_fire
		arc_modifier = _remote_arc_modifier
	velocity.x = axis * drive_speed
	if absf(axis) > 0.01:
		_facing = signf(axis)
		_set_visual_facing(_facing)
		_update_mount_positions()
	move_and_slide()
	if Input.is_action_just_pressed("interact"):
		_disembark()
		return
	if firing:
		var aim_axis := Input.get_axis("move_left", "move_right")
		var both := Input.is_action_pressed("move_left") and Input.is_action_pressed("move_right")
		if networked and _occupant is NetPlayer and not (_occupant as NetPlayer).is_multiplayer_authority():
			aim_axis = axis
			both = false
		var aim := AIM_HELPER.get_player_arc_aim(aim_axis, _facing, aiming_up, both, arc_modifier)
		var muzzle := _muzzle
		_weapon.set_muzzle(muzzle)
		_weapon.try_fire(aim, &"player")


func has_occupant() -> bool:
	return _occupant != null


func get_facing() -> float:
	return _facing


func get_health_component() -> HealthComponent:
	return _health


func _unhandled_input(event: InputEvent) -> void:
	if _occupant == null and _nearby_player and event.is_action_pressed("interact"):
		_board(_nearby_player)


func _board(player: Node2D) -> void:
	if player == null or _occupant != null or not _can_ride(player):
		return
	_occupant = player
	_occupant_peer_id = _peer_for_rider(player)
	player.call("enter_vehicle", self)
	boarded.emit(_occupant_peer_id)
	_refresh_label()


func board_rider(player: Node2D) -> void:
	_board(player)


func _disembark() -> void:
	if _occupant == null:
		return
	var player := _occupant
	var exiting_peer_id := _occupant_peer_id
	_occupant = null
	_occupant_peer_id = 0
	if _can_ride(player):
		player.call("exit_vehicle", _exit_marker.global_position)
	disembarked.emit(exiting_peer_id)
	_refresh_label()


func force_disembark() -> void:
	_disembark()


func _on_board_area_entered(body: Node) -> void:
	if _can_ride(body):
		_nearby_player = body as Node2D
		_refresh_label()


func _on_board_area_exited(body: Node) -> void:
	if body == _nearby_player:
		_nearby_player = null
		_refresh_label()


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	var ratio := float(current_health) / float(maximum_health if maximum_health > 0 else 1)
	_visual.modulate = Color(1.0, 0.7 + ratio * 0.3, 0.7 + ratio * 0.3, 1.0)
	_refresh_label()


func _on_died() -> void:
	if _occupant:
		_disembark()
	_visual.modulate = Color(0.3, 0.28, 0.28, 1.0)
	_label.text = "ROVER DOWN"
	destroyed.emit()


func _refresh_label() -> void:
	if _health.is_dead:
		return
	if _occupant:
		_label.text = "ROVER ONLINE"
	elif _nearby_player:
		_label.text = "PRESS E"
	else:
		_label.text = "ASSAULT ROVER"


func _set_visual_facing(dir: float) -> void:
	var side := signf(dir if dir != 0.0 else 1.0)
	_visual.scale = Vector2(absf(_visual_base_scale.x) * side, _visual_base_scale.y)


func _update_mount_positions() -> void:
	var side := signf(_facing if _facing != 0.0 else 1.0)
	_muzzle.position = Vector2(absf(_muzzle_base_position.x) * side, _muzzle_base_position.y)
	_exit_marker.position = Vector2(absf(_exit_base_position.x) * side, _exit_base_position.y)


func _can_ride(node: Node) -> bool:
	return node is Node2D and node.has_method("enter_vehicle") and node.has_method("exit_vehicle")


func set_remote_input(axis: float, aiming_up: bool, firing: bool, arc_modifier: bool) -> void:
	_remote_axis = axis
	_remote_aim_up = aiming_up
	_remote_fire = firing
	_remote_arc_modifier = arc_modifier


func apply_network_snapshot(pos: Vector2, facing: float, occupant_peer_id: int, hp: int) -> void:
	if authoritative:
		return
	global_position = pos
	_facing = facing
	_set_visual_facing(_facing)
	_update_mount_positions()
	_health.force_health_state(hp, hp <= 0)
	if occupant_peer_id != _occupant_peer_id:
		_occupant_peer_id = occupant_peer_id
		if occupant_peer_id <= 0:
			if _occupant and _can_ride(_occupant):
				_occupant.call("exit_vehicle", _exit_marker.global_position)
			_occupant = null
		else:
			var rider := _find_rider(occupant_peer_id)
			if rider and _can_ride(rider):
				_occupant = rider
				rider.call("enter_vehicle", self)
	_refresh_label()


func get_occupant_peer_id() -> int:
	return _occupant_peer_id


func _peer_for_rider(node: Node) -> int:
	if node.has_method("get_peer_id"):
		return int(node.call("get_peer_id"))
	return 1


func _find_rider(peer_id: int) -> Node2D:
	for node in get_tree().get_nodes_in_group("net_players"):
		if node is NetPlayer and (node as NetPlayer).get_peer_id() == peer_id:
			return node as Node2D
	for node in get_tree().get_nodes_in_group("players"):
		if node is Node2D:
			return node as Node2D
	return null
