extends Control

signal puzzle_completed(correct: bool)
signal move_made(from_sq: int, to_sq: int)

const PIECES := {
	"K": 0x2654,
	"Q": 0x2655,
	"R": 0x2656,
	"B": 0x2657,
	"N": 0x2658,
	"P": 0x2659,
	"k": 0x265A,
	"q": 0x265B,
	"r": 0x265C,
	"b": 0x265D,
	"n": 0x265E,
	"p": 0x265F,
}

const BOARD_SIZE := 8
const SQUARE_COUNT := 64
const LIGHT_COLOR := Color(0.94, 0.85, 0.70)
const DARK_COLOR := Color(0.65, 0.44, 0.28)
const SELECTED_COLOR := Color(0.3, 0.7, 0.3, 0.5)
const VALID_TARGET_COLOR := Color(0.15, 0.9, 0.15, 0.45)
const CORRECT_COLOR := Color(0.2, 0.8, 0.2, 0.8)
const WRONG_COLOR := Color(0.8, 0.15, 0.15, 0.8)

var board: Array[String] = []
var selected_sq: int = -1
var correct_from: int = -1
var correct_to: int = -1

var _squares: Array[ColorRect] = []
var _piece_labels: Array[Label] = []
var _highlight: ColorRect
var _valid_target: ColorRect
var _result_overlay: ColorRect
var _input_locked := false
var _panel: Panel

var _dragging: bool = false
var _drag_from_sq: int = -1
var _drag_label: Label
var _drag_start_pos: Vector2

func _ready() -> void:
	_build_board()

func setup_puzzle(board_data: String, from_sq: int, to_sq: int) -> void:
	board = _parse_board(board_data)
	correct_from = from_sq
	correct_to = to_sq
	_render_board()

func _build_board() -> void:
	_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.10, 0.06)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_highlight = ColorRect.new()
	_highlight.color = SELECTED_COLOR
	_highlight.visible = false
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_highlight)

	_valid_target = ColorRect.new()
	_valid_target.color = VALID_TARGET_COLOR
	_valid_target.visible = false
	_valid_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_valid_target)

	_result_overlay = ColorRect.new()
	_result_overlay.visible = false
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_result_overlay)

	_build_squares()

func _build_squares() -> void:
	var sq_size := _square_size()
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			var idx := row * BOARD_SIZE + col
			var pos := _square_pos(col, row)
			var sz := Vector2(sq_size - 2, sq_size - 2)

			var rect := ColorRect.new()
			rect.color = LIGHT_COLOR if (row + col) % 2 == 0 else DARK_COLOR
			rect.size = sz
			rect.position = pos
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_panel.add_child(rect)
			_squares.append(rect)

			var label := Label.new()
			label.size = sz
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", max(16, sq_size / 2))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.position = pos
			_panel.add_child(label)
			_piece_labels.append(label)

func _square_pos(col: int, row: int) -> Vector2:
	var s := _square_size()
	return Vector2(col * s + 4, row * s + 4)

func _square_center(col: int, row: int) -> Vector2:
	var s := _square_size()
	return Vector2(col * s + s / 2.0, row * s + s / 2.0)

func _square_size() -> float:
	return min(size.x, size.y) / float(BOARD_SIZE)

func _parse_board(data: String) -> Array[String]:
	var result: Array[String] = []
	result.resize(SQUARE_COUNT)
	for i in range(min(data.length(), SQUARE_COUNT)):
		result[i] = data[i]
	return result

func _render_board() -> void:
	var sq_size := _square_size()
	for i in SQUARE_COUNT:
		var piece := board[i] if i < board.size() else "."
		var label := _piece_labels[i]
		if piece != "." and PIECES.has(piece):
			var char_str := String.chr(PIECES[piece])
			label.text = char_str
			var is_white := piece == piece.to_upper()
			if is_white:
				label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
				label.add_theme_constant_override("outline_size", 1)
				label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
			else:
				label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
			label.add_theme_font_size_override("font_size", max(16, sq_size / 2))
		else:
			label.text = ""
	_update_layout()

func _gui_input(event: InputEvent) -> void:
	if _input_locked:
		return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var sq := _pos_to_square(get_local_mouse_position())
			if sq >= 0 and board[sq] != ".":
				_dragging = true
				_drag_from_sq = sq
				_drag_start_pos = get_local_mouse_position()
				_drag_label = _piece_labels[sq]
				selected_sq = sq
				_show_selection(sq)
				if sq == correct_from:
					_show_valid_target(correct_to)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _dragging:
				_dragging = false
				_drag_label.z_index = 0
				_highlight.visible = false
				_valid_target.visible = false
				var target_sq := _pos_to_square(get_local_mouse_position())
				if target_sq >= 0 and target_sq != _drag_from_sq:
					move_made.emit(_drag_from_sq, target_sq)
					_snap_piece(_drag_from_sq, target_sq)
					_check_move(_drag_from_sq, target_sq)
				else:
					selected_sq = -1
					_update_layout()

	if event is InputEventMouseMotion and _dragging:
		var s := _square_size()
		_drag_label.position = get_local_mouse_position() - Vector2(s / 2.0, s / 2.0)
		_drag_label.z_index = 10

func _show_selection(sq: int) -> void:
	var s := _square_size()
	var col := sq % BOARD_SIZE
	var row := sq / BOARD_SIZE
	_highlight.position = _square_pos(col, row) - Vector2(2, 2)
	_highlight.size = Vector2(s, s)
	_highlight.visible = true

func _show_valid_target(sq: int) -> void:
	var s := _square_size()
	var col := sq % BOARD_SIZE
	var row := sq / BOARD_SIZE
	_valid_target.position = _square_pos(col, row) - Vector2(1, 1)
	_valid_target.size = Vector2(s - 2, s - 2)
	_valid_target.visible = true

func _snap_piece(from_sq: int, to_sq: int) -> void:
	var col := to_sq % BOARD_SIZE
	var row := to_sq / BOARD_SIZE
	var s := _square_size()
	var center := _square_center(col, row)
	_piece_labels[from_sq].position = center - Vector2(s / 2.0, s / 2.0)

func _pos_to_square(pos: Vector2) -> int:
	var sq_size := _square_size()
	var local := pos - Vector2(4, 4)
	var col := int(local.x / sq_size)
	var row := int(local.y / sq_size)
	if col < 0 or col >= BOARD_SIZE or row < 0 or row >= BOARD_SIZE:
		return -1
	return row * BOARD_SIZE + col

func _update_layout() -> void:
	var sq_size := _square_size()
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			var idx := row * BOARD_SIZE + col
			var pos := _square_pos(col, row)
			var sz := Vector2(sq_size - 2, sq_size - 2)
			_squares[idx].position = pos
			_squares[idx].size = sz
			_piece_labels[idx].position = pos
			_piece_labels[idx].size = sz

func _check_move(from_sq: int, to_sq: int) -> void:
	_input_locked = true
	var correct := (from_sq == correct_from and to_sq == correct_to)
	_result_overlay.visible = true
	if correct:
		_build_move_animation(from_sq, to_sq)
		_result_overlay.color = CORRECT_COLOR
		_result_overlay.modulate.a = 0.4
		await get_tree().create_timer(0.8).timeout
		_result_overlay.modulate.a = 0.0
		puzzle_completed.emit(true)
	else:
		_result_overlay.color = WRONG_COLOR
		_result_overlay.modulate.a = 0.5
		await get_tree().create_timer(1.2).timeout
		_result_overlay.modulate.a = 0.0
		_input_locked = false
		_update_layout()
		puzzle_completed.emit(false)

func _build_move_animation(from_sq: int, to_sq: int) -> void:
	_update_layout()
	var from_label := _piece_labels[from_sq]
	var to_label := _piece_labels[to_sq]
	if from_label.text.is_empty():
		return
	to_label.text = from_label.text
	from_label.text = ""
	board[to_sq] = board[from_sq]
	board[from_sq] = "."
	var col := to_sq % BOARD_SIZE
	var row := to_sq / BOARD_SIZE
	to_label.position = _square_pos(col, row)
	to_label.size = Vector2(_square_size() - 2, _square_size() - 2)
	var tween := create_tween()
	tween.tween_property(to_label, "scale", Vector2(1.15, 1.15), 0.15)
	tween.tween_property(to_label, "scale", Vector2(1, 1), 0.15)
