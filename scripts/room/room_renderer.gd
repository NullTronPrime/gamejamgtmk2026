extends Node2D

const CELL_W := 565.0
const CELL_H := 441.0
const DEPTH_STEP := 60.0
const DEPTH_SCALE_FACTOR := 0.55
const CORRIDOR_LENGTH := 5
const SIDE_OFFSET := 160.0

var _depth_cells: Array[RoomCell] = []
var _side_cells_left: Node2D
var _side_cells_right: Node2D

var _player_dot: ColorRect
var _player_marker: Node2D


func _ready() -> void:
	_setup_player_marker()
	rebuild_all()


func _setup_player_marker() -> void:
	_player_marker = Node2D.new()
	_player_marker.name = "PlayerMarker"
	add_child(_player_marker)

	_player_dot = ColorRect.new()
	_player_dot.name = "PlayerDot"
	_player_dot.size = Vector2(12, 12)
	_player_dot.color = Color(1, 0.8, 0.2)
	_player_dot.position = Vector2(-6, -6)
	_player_marker.add_child(_player_dot)


static func _forward_screen(facing: Vector2i) -> Vector2:
	if facing == Vector2i.DOWN:
		return Vector2(0, -1)
	if facing == Vector2i.UP:
		return Vector2(0, 1)
	if facing == Vector2i.RIGHT:
		return Vector2(-1, 0)
	return Vector2(1, 0)

static func _left_grid(facing: Vector2i) -> Vector2i:
	if facing == Vector2i.DOWN:
		return Vector2i.LEFT
	if facing == Vector2i.UP:
		return Vector2i.RIGHT
	if facing == Vector2i.RIGHT:
		return Vector2i.UP
	return Vector2i.DOWN

static func _right_grid(facing: Vector2i) -> Vector2i:
	if facing == Vector2i.DOWN:
		return Vector2i.RIGHT
	if facing == Vector2i.UP:
		return Vector2i.LEFT
	if facing == Vector2i.RIGHT:
		return Vector2i.DOWN
	return Vector2i.UP

static func _left_screen(facing: Vector2i) -> Vector2:
	if facing == Vector2i.DOWN:
		return Vector2(-1, 0)
	if facing == Vector2i.UP:
		return Vector2(1, 0)
	if facing == Vector2i.RIGHT:
		return Vector2(0, -1)
	return Vector2(0, 1)

static func _right_screen(facing: Vector2i) -> Vector2:
	if facing == Vector2i.DOWN:
		return Vector2(1, 0)
	if facing == Vector2i.UP:
		return Vector2(-1, 0)
	if facing == Vector2i.RIGHT:
		return Vector2(0, 1)
	return Vector2(0, -1)


func rebuild_all() -> void:
	_rebuild_depth_corridor()
	_rebuild_side_tiles()
	_update_player_marker()


func _rebuild_depth_corridor() -> void:
	for c in _depth_cells:
		if is_instance_valid(c):
			c.queue_free()
	_depth_cells.clear()

	var grid := RoomGrid
	var facing := grid.player_facing
	var fwd := _forward_screen(facing)

	for i in CORRIDOR_LENGTH:
		var cell_pos := grid.player_cell + facing * (i + 1)
		var cell_data := grid.get_cell(cell_pos)

		if cell_data.get("wall", false):
			break

		var scale_t := pow(DEPTH_SCALE_FACTOR, i + 1)
		var pos := fwd * ((i + 1) * DEPTH_STEP + DEPTH_STEP * 0.5)

		var cell := RoomCell.new()
		cell.build()
		cell.configure(
			cell_data.get("open_left", false),
			cell_data.get("open_right", false),
			i == CORRIDOR_LENGTH - 1,
			""
		)
		cell.scale = Vector2(scale_t, scale_t)
		cell.position = pos

		add_child(cell)
		_depth_cells.append(cell)


func _rebuild_side_tiles() -> void:
	for n in [_side_cells_left, _side_cells_right]:
		if is_instance_valid(n):
			n.queue_free()

	var grid := RoomGrid
	var pc := grid.player_cell
	var facing := grid.player_facing

	var left_grid_off: Vector2i = _left_grid(facing)
	var right_grid_off: Vector2i = _right_grid(facing)
	var left_screen_dir: Vector2 = _left_screen(facing)
	var right_screen_dir: Vector2 = _right_screen(facing)

	_build_side_tile("left", pc + left_grid_off, left_screen_dir)
	_build_side_tile("right", pc + right_grid_off, right_screen_dir)


func _build_side_tile(side_name: String, grid_pos: Vector2i, screen_dir: Vector2) -> void:
	var grid := RoomGrid
	var cell_data := grid.get_cell(grid_pos)
	if cell_data.get("wall", false):
		return

	var cell := RoomCell.new()
	cell.build()
	cell.configure(
		cell_data.get("open_left", false),
		cell_data.get("open_right", false),
		false,
		""
	)
	cell.position = screen_dir * SIDE_OFFSET
	cell.z_index = -1
	add_child(cell)
	set("_side_cells_" + side_name, cell)


func _update_player_marker() -> void:
	if not _player_marker:
		return
	_player_marker.position = Vector2.ZERO
