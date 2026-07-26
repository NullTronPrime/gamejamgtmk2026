extends CanvasLayer

signal finished()
signal click_advanced()

const IMAGES := [
	preload("res://assets/art/cutscenes/cutscene_1.png"),
	preload("res://assets/art/cutscenes/cutscene_2.png"),
	preload("res://assets/art/cutscenes/cutscene_3.png"),
]

@onready var skip_button: Button = $SkipButton
@onready var continue_button: Button = $ContinueButton

var _slides: Array[TextureRect] = []
var _current := 0
var _vs: Vector2
var _click_ready := false

func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	continue_button.pressed.connect(_on_continue)
	continue_button.visible = false
	skip_button.z_index = 10
	continue_button.z_index = 10

	_vs = DisplayServer.window_get_size()
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = _vs; bg.z_index = 0; bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	for i in 3:
		var tr := TextureRect.new()
		tr.texture = IMAGES[i]
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = _vs
		tr.position = Vector2(_vs.x, 0)
		tr.z_index = 1
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		_slides.append(tr)

	_slides[0].position = Vector2.ZERO
	_slides[0].z_index = 3

	_animate_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _click_ready:
		_click_ready = false
		click_advanced.emit()

func _animate_sequence() -> void:
	await get_tree().create_timer(0.5).timeout
	for i in 3:
		var tr := _slides[i]
		tr.z_index = 3

		if i == 2:
			_click_ready = true
			continue_button.visible = true
			_current = i
			return

		_click_ready = true
		await click_advanced

		var next := i + 1
		var nt := _slides[next]
		nt.position = Vector2(_vs.x, 0)
		nt.z_index = 4
		tr.z_index = 2

		var ts := create_tween().set_parallel(true)
		ts.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		ts.tween_property(tr, "position:x", -_vs.x, 1.8)
		ts.tween_property(nt, "position:x", 0, 1.8)
		await ts.finished
		_current = next
		_wobble_in(nt)

func _wobble_in(tr: TextureRect) -> void:
	var orig_x := tr.position.x
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tr, "position:x", orig_x + 10, 0.3)
	tw.tween_property(tr, "position:x", orig_x - 8, 0.25)
	tw.tween_property(tr, "position:x", orig_x + 6, 0.21)
	tw.tween_property(tr, "position:x", orig_x - 5, 0.19)
	tw.tween_property(tr, "position:x", orig_x + 4, 0.17)
	tw.tween_property(tr, "position:x", orig_x, 0.15)

func _on_skip() -> void:
	finished.emit()

func _on_continue() -> void:
	finished.emit()
