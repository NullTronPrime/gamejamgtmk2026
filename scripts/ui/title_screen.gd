extends CanvasLayer

signal start_game()
signal open_options()

@onready var start_button: Button = $StartButton
@onready var options_button: Button = $OptionsButton
@onready var quit_button: Button = $QuitButton
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel
@onready var title_icon: TextureRect = $TitleIcon

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	var menu_stream = load("res://assets/audio/bgm/main_menu.wav")
	if menu_stream:
		AudioManager.play_bgm(menu_stream)
	_fade_in()
	_setup_button_animations()

func _fade_in() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_icon, "position:y", title_icon.position.y, 0.6).from(title_icon.position.y - 30).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _setup_button_animations() -> void:
	for btn in [start_button, options_button, quit_button]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_unhover.bind(btn))
		btn.button_down.connect(_on_button_press.bind(btn))

func _on_button_hover(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _on_button_unhover(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _on_button_press(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)

func _on_start() -> void:
	AudioManager.stop_bgm()
	start_game.emit()

func _on_options() -> void:
	open_options.emit()

func _on_quit() -> void:
	get_tree().quit()
