class_name HealthComponent
extends Node
## Tracks hit points, invulnerability, and death for any damageable entity.
## Expected parent: entity root. No required child nodes.
## Multiplayer authority (later): host mutates health; clients receive results.

signal health_changed(current_health: int, max_health: int)
signal died
signal invulnerability_finished

@export var max_health: int = 3
@export var invulnerability_duration_sec: float = 0.0

var current_health: int = 3
var is_dead: bool = false
var is_invulnerable: bool = false

var _invuln_timer: float = 0.0


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _process(delta: float) -> void:
	if not is_invulnerable:
		return
	_invuln_timer -= delta
	if _invuln_timer <= 0.0:
		is_invulnerable = false
		invulnerability_finished.emit()


func configure(max_hp: int, invuln_sec: float = 0.0) -> void:
	max_health = maxi(1, max_hp)
	invulnerability_duration_sec = maxf(0.0, invuln_sec)
	current_health = max_health
	is_dead = false
	is_invulnerable = false
	_invuln_timer = 0.0
	health_changed.emit(current_health, max_health)


func apply_damage(amount: int) -> bool:
	if is_dead or is_invulnerable or amount <= 0:
		return false
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		is_dead = true
		died.emit()
		return true
	if invulnerability_duration_sec > 0.0:
		is_invulnerable = true
		_invuln_timer = invulnerability_duration_sec
	return true


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func reset_full() -> void:
	is_dead = false
	is_invulnerable = false
	_invuln_timer = 0.0
	current_health = max_health
	health_changed.emit(current_health, max_health)


func start_invulnerability(duration_sec: float = -1.0) -> void:
	var dur := invulnerability_duration_sec if duration_sec < 0.0 else duration_sec
	if dur <= 0.0:
		return
	is_invulnerable = true
	_invuln_timer = dur


func force_health_state(current: int, dead: bool = false) -> void:
	current_health = clampi(current, 0, max_health)
	is_dead = dead or current_health <= 0
	health_changed.emit(current_health, max_health)
