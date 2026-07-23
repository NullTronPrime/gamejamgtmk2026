extends CanvasLayer

signal response_chosen(response: bool)
signal shown()
signal hidden()

const TYPING_SPEED_MS: float = 0.03

var _full_text: String = ""
var _text_visible: bool = false
var _typing_timer: float = 0.0
var _char_index: int = 0
var _typing_done: bool = false

@onready var panel: Panel = $Panel
@onready var text_label: RichTextLabel = $Panel/TextLabel
@onready var yes_button: Button = $Panel/ButtonContainer/YesButton
@onready var no_button: Button = $Panel/ButtonContainer/NoButton

func _ready() -> void:
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_on_no)

func show_text(text: String) -> void:
	_full_text = text
	text_label.text = ""
	visible = true
	_typing_done = false
	_char_index = 0
	_typing_timer = 0.0
	yes_button.disabled = true
	no_button.disabled = true
	_text_visible = true
	shown.emit()

func hide_box() -> void:
	visible = false
	_text_visible = false
	_typing_done = true
	hidden.emit()

func _process(delta: float) -> void:
	if not _text_visible or _typing_done:
		return
	if _char_index >= _full_text.length():
		_finish_typing()
		return
	_typing_timer += delta
	while _typing_timer >= TYPING_SPEED_MS and _char_index < _full_text.length():
		_typing_timer -= TYPING_SPEED_MS
		_char_index += 1
		text_label.text = _full_text.substr(0, _char_index)
	if _char_index >= _full_text.length():
		_finish_typing()

func _finish_typing() -> void:
	_typing_done = true
	text_label.text = _full_text
	yes_button.disabled = false
	no_button.disabled = false

func _skip_typing() -> void:
	if not _typing_done:
		_typing_done = true
		text_label.text = _full_text
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
