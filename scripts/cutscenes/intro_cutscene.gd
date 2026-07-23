extends CanvasLayer

signal finished()

@onready var skip_button: Button = $SkipButton
@onready var continue_button: Button = $ContinueButton

func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	continue_button.pressed.connect(_on_continue)
	continue_button.visible = false
	await get_tree().create_timer(3.0).timeout
	continue_button.visible = true

func _on_skip() -> void:
	finished.emit()

func _on_continue() -> void:
	finished.emit()
