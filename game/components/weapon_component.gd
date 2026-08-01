class_name WeaponComponent
extends Node
## Owns current weapon definition, ammo, and fire cooldown.
## Expected parent: player/vehicle. Requires a muzzle Marker2D path for spawn origin.
## Multiplayer authority (later): clients request fire; host validates and spawns.

signal fired(projectile: Node2D)
signal ammo_changed(current_ammo: int, unlimited: bool)
signal weapon_changed(weapon: WeaponDefinition)

@export var muzzle_path: NodePath
@export var projectile_parent_path: NodePath

var weapon: WeaponDefinition
var current_ammo: int = 0

var _cooldown: float = 0.0
var _muzzle: Node2D
var _projectile_parent: Node


func _ready() -> void:
	if muzzle_path != NodePath():
		_muzzle = get_node_or_null(muzzle_path) as Node2D
	if projectile_parent_path != NodePath():
		_projectile_parent = get_node_or_null(projectile_parent_path)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)


func set_muzzle(muzzle: Node2D) -> void:
	_muzzle = muzzle


func set_weapon(definition: WeaponDefinition) -> void:
	weapon = definition
	if weapon == null:
		current_ammo = 0
		weapon_changed.emit(null)
		ammo_changed.emit(0, false)
		return
	current_ammo = 0 if weapon.unlimited_ammo else weapon.max_ammo
	weapon_changed.emit(weapon)
	ammo_changed.emit(current_ammo, weapon.unlimited_ammo)


func can_fire() -> bool:
	if weapon == null or weapon.projectile_scene == null:
		return false
	if _cooldown > 0.0:
		return false
	if weapon.unlimited_ammo:
		return true
	return current_ammo > 0


func try_fire(aim_dir: Vector2, team: StringName) -> bool:
	if not can_fire():
		return false
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT
	aim_dir = aim_dir.normalized()

	var origin := _resolve_muzzle_global()
	var parent := _resolve_projectile_parent()
	var pellets := maxi(1, weapon.pellet_count)
	for i in pellets:
		var dir := aim_dir
		if weapon.spread_degrees > 0.0 and pellets > 1:
			var t := 0.0 if pellets == 1 else float(i) / float(pellets - 1)
			var angle := deg_to_rad(lerpf(-weapon.spread_degrees, weapon.spread_degrees, t))
			dir = aim_dir.rotated(angle)
		var projectile := weapon.projectile_scene.instantiate() as Node2D
		parent.add_child(projectile)
		if projectile.has_method("launch"):
			projectile.call("launch", origin, dir, weapon.damage, weapon.projectile_speed, weapon.projectile_lifetime_sec, team)
		fired.emit(projectile)

	if not weapon.unlimited_ammo:
		current_ammo = maxi(0, current_ammo - 1)
		ammo_changed.emit(current_ammo, false)
	_cooldown = weapon.fire_interval_sec
	return true


func _resolve_muzzle_global() -> Vector2:
	if _muzzle != null:
		return _muzzle.global_position
	var owner_2d := get_parent() as Node2D
	return owner_2d.global_position if owner_2d != null else Vector2.ZERO


func _resolve_projectile_parent() -> Node:
	if _projectile_parent != null:
		return _projectile_parent
	var tree := get_tree()
	if tree != null:
		var bucket := tree.get_first_node_in_group("projectile_bucket")
		if bucket != null:
			return bucket
	return get_tree().current_scene
