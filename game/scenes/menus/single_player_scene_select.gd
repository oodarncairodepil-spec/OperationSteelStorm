extends Control

@onready var _current_button: Button = %CurrentMissionButton
@onready var _scene_1_2_button: Button = %Scene12Button
@onready var _back_button: Button = %BackButton
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	_current_button.pressed.connect(func() -> void: SceneManager.go_to_phase4_mission())
	_scene_1_2_button.pressed.connect(func() -> void: SceneManager.go_to_phase4_scene_1_2())
	_back_button.pressed.connect(func() -> void: SceneManager.go_to_main_menu())
	_hint_label.text = "Choose Mission 1-1: Beachhead or Mission 1-2: High Rescue."
	_current_button.grab_focus()
