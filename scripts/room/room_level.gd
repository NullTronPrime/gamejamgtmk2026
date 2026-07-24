extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")

var _renderer: Node2D
var _can_move: bool = false
var _move_cooldown: float = 0.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.06, 0.1)
	add_child(bg)

	_renderer = preload("res://scripts/room/room_renderer.gd").new()
	_renderer.name = "RoomRenderer"
	add_child(_renderer)

	var label := Label.new()
	label.name = "HelpLabel"
	label.text = "WASD / Arrow keys to move — T to return"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	label.position = Vector2(10, 10)
	add_child(label)

	if is_inside_tree():
		_reveal()


func _reveal() -> void:
	if GridTrans.is_available() and not GridTrans.is_busy():
		await GridTrans.reveal(0.8)
	_can_move = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_T and event.pressed and not event.echo:
		_exit_room_level()
		return

	if not _can_move:
		return

	var dir := Vector2i.ZERO
	if event.is_action_pressed(&"move_right") or (event is InputEventKey and event.keycode == KEY_D and event.pressed and not event.echo):
		dir = Vector2i.RIGHT
	elif event.is_action_pressed(&"move_left") or (event is InputEventKey and event.keycode == KEY_A and event.pressed and not event.echo):
		dir = Vector2i.LEFT
	elif event.is_action_pressed(&"move_down") or (event is InputEventKey and event.keycode == KEY_S and event.pressed and not event.echo):
		dir = Vector2i.DOWN
	elif event.is_action_pressed(&"move_up") or (event is InputEventKey and event.keycode == KEY_W and event.pressed and not event.echo):
		dir = Vector2i.UP

	if dir != Vector2i.ZERO:
		_try_move(dir)


func _try_move(dir: Vector2i) -> void:
	if not _can_move:
		return

	var grid := RoomGrid
	var new_pos := grid.player_cell + dir
	var cell_data := grid.get_cell(new_pos)

	if cell_data.get("wall", false):
		return

	grid.player_cell = new_pos
	grid.player_facing = dir

	_can_move = false
	_move_cooldown = 0.25

	_renderer.rebuild_all()


func _process(delta: float) -> void:
	if _move_cooldown > 0.0:
		_move_cooldown -= delta
		if _move_cooldown <= 0.0:
			_can_move = true


func _exit_room_level() -> void:
	_can_move = false
	if GridTrans.is_available() and not GridTrans.is_busy():
		await GridTrans.cover(0.8)
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("exit_room"):
		game.exit_room()
	else:
		queue_free()
