extends Node2D

signal response_chosen(response: bool)
signal text_shown()
signal text_hidden()

const TYPING_INTERVAL: float = 0.03
const FALL_OFFSET: float = 8.0

var _full_text: String = ""
var _text_visible: bool = false
var _char_index: int = 0
var _typing_done: bool = false
var _char_timer: float = 0.0
var _last_visible_chars: int = 0

@onready var panel: Panel = $Panel
@onready var text_label: RichTextLabel = $Panel/TextLabel
@onready var yes_button: Button = $Panel/ButtonContainer/YesButton
@onready var no_button: Button = $Panel/ButtonContainer/NoButton

func _ready() -> void:
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_on_no)

func show_text(text: String) -> void:
	_full_text = text
	text_label.text = text
	text_label.visible_characters = 0
	_last_visible_chars = 0
	visible = true
	_typing_done = false
	_char_index = 0
	_char_timer = 0.0
	yes_button.disabled = true
	no_button.disabled = true
	_text_visible = true
	text_shown.emit()

func hide_box() -> void:
	visible = false
	_text_visible = false
	_typing_done = true
	text_hidden.emit()

func _process(delta: float) -> void:
	if not _text_visible or _typing_done:
		return
	if _char_index >= _full_text.length():
		_finish_typing()
		return
	_char_timer += delta
	while _char_timer >= TYPING_INTERVAL and _char_index < _full_text.length():
		_char_timer -= TYPING_INTERVAL
		_char_index += 1
		text_label.visible_characters = _char_index
		text_label.position.y = -FALL_OFFSET
		var bounce := create_tween()
		bounce.tween_property(text_label, "position:y", 0.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	if _char_index >= _full_text.length():
		_finish_typing()

func _finish_typing() -> void:
	_typing_done = true
	text_label.visible_characters = -1
	text_label.position.y = 0.0
	yes_button.disabled = false
	no_button.disabled = false

func _skip_typing() -> void:
	if not _typing_done:
		_typing_done = true
		text_label.visible_characters = -1
		text_label.position.y = 0.0
		yes_button.disabled = false
		no_button.disabled = false

func _on_yes() -> void:
	_skip_typing()
	yes_button.disabled = true
	no_button.disabled = true
	response_chosen.emit(true)

func _on_no() -> void:
	_skip_typing()
	yes_button.disabled = true
	no_button.disabled = true
	response_chosen.emit(false)
