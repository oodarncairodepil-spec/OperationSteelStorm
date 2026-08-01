extends Control

@onready var _headline_label: Label = %HeadlineLabel
@onready var _subheadline_label: Label = %SubheadlineLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	var result := SceneManager.pending_result
	_headline_label.text = str(result.get("headline", "MISSION FAILED"))
	_subheadline_label.text = str(result.get("subheadline", "Operation report"))
	_score_label.text = "Score %d" % int(result.get("score", 0))
	_detail_label.text = str(result.get("detail", ""))
	_restart_button.text = "Restart Mission" if str(result.get("restart_target", "")) != "combat_room" else "Restart Room"
	_restart_button.pressed.connect(func() -> void: SceneManager.restart_pending_result())
	_menu_button.pressed.connect(func() -> void: SceneManager.go_to_main_menu())
	_restart_button.grab_focus()
