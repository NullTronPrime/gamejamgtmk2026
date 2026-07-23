extends CanvasLayer

signal start_game()
signal open_options()

@onready var start_button: Button = $StartButton
@onready var options_button: Button = $OptionsButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	var menu_stream = load("res://assets/audio/bgm/main_menu.wav")
	if menu_stream:
		AudioManager.play_bgm(menu_stream)

func _on_start() -> void:
	AudioManager.stop_bgm()
	start_game.emit()

func _on_options() -> void:
	open_options.emit()

func _on_quit() -> void:
	get_tree().quit()
