extends CanvasLayer

var is_paused: bool = false
var _paused_state: int = -1

@onready var panel: Panel = $Panel
@onready var resume_btn: Button = $Panel/VBoxContainer/Resume
@onready var quit_btn: Button = $Panel/VBoxContainer/Quit

func _ready() -> void:
	resume_btn.pressed.connect(_on_resume)
	quit_btn.pressed.connect(_on_quit)
	process_mode = PROCESS_MODE_ALWAYS
	hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	is_paused = true
	_paused_state = GameManager.state
	show()
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	hide()

func _on_resume() -> void:
	resume_game()

func _on_quit() -> void:
	resume_game()
	GameManager.trigger_reset()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
