extends Node

var _cells: Dictionary = {}

var player_cell: Vector2i = Vector2i.ZERO
var player_facing: Vector2i = Vector2i.DOWN

var _rng: RandomNumberGenerator


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash("room_grid_seed")
	_generate_at(player_cell)


func get_cell(pos: Vector2i) -> Dictionary:
	if not _cells.has(pos):
		_generate_at(pos)
	return _cells[pos]


func set_cell(pos: Vector2i, data: Dictionary) -> void:
	_cells[pos] = data


func has_cell(pos: Vector2i) -> bool:
	return _cells.has(pos)


func get_player_cell_data() -> Dictionary:
	return get_cell(player_cell)


func reset() -> void:
	_cells.clear()
	player_cell = Vector2i.ZERO
	_ready()


func _generate_at(pos: Vector2i) -> void:
	_rng.seed = hash("room_%d_%d" % [pos.x, pos.y])

	var distance := maxi(abs(pos.x), abs(pos.y))

	var is_wall := false
	if distance > 1:
		is_wall = _rng.randf() < 0.18

	var open_left := _rng.randf() > 0.35
	var open_right := _rng.randf() > 0.35
	var open_up := _rng.randf() > 0.35
	var open_down := _rng.randf() > 0.35

	_cells[pos] = {
		"open_left": open_left,
		"open_right": open_right,
		"open_up": open_up,
		"open_down": open_down,
		"wall": is_wall,
	}
