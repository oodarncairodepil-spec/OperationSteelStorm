class_name GameHUD
extends CanvasLayer
## Basic Phase 1 HUD: health, weapon, ammo, score, objective.
## Expected parent: level root.
## Required children: labels via unique names.
## Multiplayer authority: local UI.

signal restart_pressed
signal menu_pressed

@onready var _health_label: Label = %HealthLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _ammo_label: Label = %AmmoLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _banner: Label = %BannerLabel
@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton
@onready var _touch_controls: Control = %TouchControls
@onready var _left_button: TouchScreenButton = %LeftButton
@onready var _right_button: TouchScreenButton = %RightButton
@onready var _up_button: TouchScreenButton = %UpButton
@onready var _down_button: TouchScreenButton = %DownButton
@onready var _jump_button: TouchScreenButton = %JumpButton
@onready var _squat_button: TouchScreenButton = %SquatButton
@onready var _shoot_button: TouchScreenButton = %ShootButton

var _weapon_override_active: bool = false
var _bound_player: Node
var _bound_weapon: WeaponComponent


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_result_panel.visible = false
	_banner.text = ""
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	_configure_touch_controls()


func bind_player(player: Node) -> void:
	if player == null:
		return
	_bound_player = player
	_bound_weapon = null
	if player.has_signal("health_changed"):
		player.health_changed.connect(set_health)
	if player.has_method("get_health_component"):
		var health: HealthComponent = player.get_health_component()
		if health:
			set_health(health.current_health, health.max_health)
	if player.has_method("get_weapon_component"):
		var weapon: WeaponComponent = player.get_weapon_component()
		if weapon:
			_bound_weapon = weapon
			weapon.weapon_changed.connect(_on_weapon_changed)
			weapon.ammo_changed.connect(set_ammo)
			if weapon.weapon != null:
				_on_weapon_changed(weapon.weapon)
				set_ammo(weapon.current_ammo, weapon.weapon.unlimited_ammo)
	elif player.has_method("get_equipped_weapon_id"):
		_refresh_from_weapon_id(player.get_equipped_weapon_id())
	if "score" in player:
		set_score(player.score)


func set_health(current_health: int, max_health: int) -> void:
	_health_label.text = "HP %d/%d" % [current_health, max_health]


func set_score(score: int) -> void:
	_score_label.text = "SCORE %d" % score


func set_objective(text: String) -> void:
	_objective_label.text = text


func set_ammo(current_ammo: int, unlimited: bool) -> void:
	if _weapon_override_active:
		return
	_ammo_label.text = "AMMO ∞" if unlimited else "AMMO %d" % current_ammo


func show_banner(text: String, duration_sec: float = 2.0) -> void:
	_banner.text = text
	if duration_sec > 0.0:
		await get_tree().create_timer(duration_sec).timeout
		if _banner.text == text:
			_banner.text = ""


func show_result(won: bool, score: int, detail_text: String = "") -> void:
	_result_panel.visible = true
	_result_label.text = ("ROOM CLEARED\nScore %d" if won else "MISSION FAILED\nScore %d") % score
	if detail_text != "":
		_result_label.text += "\n%s" % detail_text
	_restart_button.grab_focus()


func hide_result() -> void:
	_result_panel.visible = false


func set_result_actions(restart_text: String, menu_text: String = "Main Menu") -> void:
	_restart_button.text = restart_text
	_menu_button.text = menu_text


func _configure_touch_controls() -> void:
	var mobile := OS.has_feature("web") and JavaScriptBridge.eval("/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent)")
	_touch_controls.visible = mobile
	if not mobile:
		return
	for button in [_left_button, _right_button, _up_button, _down_button, _jump_button, _squat_button, _shoot_button]:
		button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY


func _on_weapon_changed(weapon: WeaponDefinition) -> void:
	if _weapon_override_active:
		return
	_weapon_label.text = "WPN %s" % (weapon.display_name if weapon else "-")


func set_weapon_override(weapon_text: String, ammo_text: String = "") -> void:
	_weapon_override_active = true
	_weapon_label.text = "WPN %s" % weapon_text
	if ammo_text != "":
		_ammo_label.text = ammo_text


func clear_weapon_override() -> void:
	_weapon_override_active = false
	if _bound_weapon and _bound_weapon.weapon:
		_on_weapon_changed(_bound_weapon.weapon)
		set_ammo(_bound_weapon.current_ammo, _bound_weapon.weapon.unlimited_ammo)
	elif _bound_player and _bound_player.has_method("get_equipped_weapon_id"):
		_refresh_from_weapon_id(_bound_player.get_equipped_weapon_id())


func _refresh_from_weapon_id(weapon_id: StringName) -> void:
	match weapon_id:
		&"scatter_cannon":
			_weapon_label.text = "WPN SCATTER CANNON"
			_ammo_label.text = "AMMO SHARED"
		&"rapid_pulse_gun":
			_weapon_label.text = "WPN RAPID PULSE GUN"
			_ammo_label.text = "AMMO SHARED"
		&"assault_rover_cannon":
			_weapon_label.text = "WPN ROVER CANNON"
			_ammo_label.text = "AMMO ∞"
		_:
			_weapon_label.text = "WPN STANDARD RIFLE"
			_ammo_label.text = "AMMO ∞"
