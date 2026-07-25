extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")
const TILE_SIZE := 128
const ROOM_W := 16
const ROOM_H := 12
const PLAYER_SPEED := 200.0

var _floor_map: TileMap
var _wall_map: TileMap
var _player: CharacterBody2D
var _can_move := false
var _exiting := false

const _FLOOR_VARIANTS := [
	Vector2i(6, 2), Vector2i(7, 2), Vector2i(9, 0), Vector2i(10, 0)
]

func _ready() -> void:
	_build_floor_tileset()
	_build_wall_tileset()
	_generate_room()
	_spawn_player()
	_setup_camera()
	_setup_ui()
	reveal.call_deferred()

func _build_floor_tileset() -> void:
	var tex := load("res://assets/art/rooms/tilesets/Grass_Tiles.png")
	if not tex:
		return
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x in 12:
		for y in 4:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	_floor_map = TileMap.new()
	_floor_map.name = "FloorTileMap"
	_floor_map.tile_set = ts
	add_child(_floor_map)

func _build_wall_tileset() -> void:
	var tex := load("res://assets/art/rooms/tilesets/Big_Tile_Rock.png")
	if not tex:
		return
	var ts := TileSet.new()
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x in 12:
		for y in 4:
			var c := Vector2i(x, y)
			src.create_tile(c)
			var td := src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-64, -64), Vector2(64, -64), Vector2(64, 64), Vector2(-64, 64)
			]))
	ts.add_source(src, 0)
	_wall_map = TileMap.new()
	_wall_map.name = "WallTileMap"
	_wall_map.tile_set = ts
	add_child(_wall_map)

func _generate_room() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("room_dungeon")
	for x in ROOM_W:
		for y in ROOM_H:
			var cell := Vector2i(x, y)
			var is_wall := x == 0 or x == ROOM_W - 1 or y == 0 or y == ROOM_H - 1
			var is_door := (x == ROOM_W / 2 and y == 0) or (x == ROOM_W / 2 and y == ROOM_H - 1)
			if is_wall and not is_door:
				_wall_map.set_cell(0, cell, 0, _pick_wall_tile(x, y))
			elif not is_wall:
				_floor_map.set_cell(0, cell, 0, _FLOOR_VARIANTS[rng.randi() % _FLOOR_VARIANTS.size()])

	_add_exit_trigger()

func _add_exit_trigger() -> void:
	var exit_area := Area2D.new()
	exit_area.name = "ExitArea"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	shape.shape = rect
	exit_area.add_child(shape)
	exit_area.position = Vector2(ROOM_W / 2 * TILE_SIZE + TILE_SIZE / 2, TILE_SIZE / 2)
	exit_area.body_entered.connect(_on_exit_entered)
	exit_area.collision_mask = 1
	add_child(exit_area)

	var exit_label := Label.new()
	exit_label.text = "EXIT"
	exit_label.add_theme_font_size_override("font_size", 14)
	exit_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.3, 0.7))
	exit_label.position = Vector2(ROOM_W / 2 * TILE_SIZE + 24, 8)
	exit_label.mouse_filter = 2
	add_child(exit_label)

	var exit_arrow := ColorRect.new()
	exit_arrow.size = Vector2(TILE_SIZE / 2, 4)
	exit_arrow.position = Vector2(ROOM_W / 2 * TILE_SIZE + TILE_SIZE / 4, TILE_SIZE + TILE_SIZE / 2)
	exit_arrow.color = Color(0.3, 0.8, 0.2, 0.5)
	add_child(exit_arrow)

func _on_exit_entered(body: Node) -> void:
	if body == _player and not _exiting:
		_exit_room()

func _pick_wall_tile(x: int, y: int) -> Vector2i:
	var n := _is_wall(Vector2i(x, y - 1))
	var s := _is_wall(Vector2i(x, y + 1))
	var w := _is_wall(Vector2i(x - 1, y))
	var e := _is_wall(Vector2i(x + 1, y))
	var bits := (1 if n else 0) | (1 << 1 if s else 0) | (1 << 2 if w else 0) | (1 << 3 if e else 0)
	match bits:
		0b0000: return Vector2i(0, 0)
		0b0001: return Vector2i(10, 1)
		0b0010: return Vector2i(6, 0)
		0b0011: return Vector2i(4, 1)
		0b0100: return Vector2i(0, 2)
		0b0101: return Vector2i(2, 1)
		0b0110: return Vector2i(2, 2)
		0b0111: return Vector2i(5, 1)
		0b1000: return Vector2i(9, 2)
		0b1001: return Vector2i(7, 1)
		0b1010: return Vector2i(3, 1)
		0b1011: return Vector2i(0, 1)
	return Vector2i(0, 0)

func _is_wall(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= ROOM_W or cell.y < 0 or cell.y >= ROOM_H:
		return false
	if cell.y == 0 or cell.y == ROOM_H - 1:
		return not (cell.x == ROOM_W / 2)
	return cell.x == 0 or cell.x == ROOM_W - 1

func _spawn_player() -> void:
	_player = CharacterBody2D.new()
	_player.name = "Player"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 40)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -20)
	_player.add_child(col)
	var sprite := ColorRect.new()
	sprite.size = Vector2(24, 40)
	sprite.color = Color(0.7, 0.5, 0.3)
	sprite.position = Vector2(-12, -40)
	_player.add_child(sprite)
	_player.position = Vector2(TILE_SIZE * 6, TILE_SIZE * (ROOM_H / 2))
	add_child(_player)

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	add_child(cam)
	cam.make_current()

func _setup_ui() -> void:
	var cl := CanvasLayer.new()
	cl.name = "UI"
	var label := Label.new()
	label.text = "WASD to move  |  Reach the EXIT at the top  |  ESC pause"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	label.position = Vector2(8, 8)
	label.add_theme_constant_override("outline_size", 1)
	cl.add_child(label)
	add_child(cl)

func reveal() -> void:
	if GridTrans.is_available() and not GridTrans.is_busy():
		await GridTrans.reveal(0.8)
	_can_move = true

func _process(delta: float) -> void:
	if not _can_move or not _player:
		return
	var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_player.velocity = dir * PLAYER_SPEED
	_player.move_and_slide()
	_center_camera()

func _center_camera() -> void:
	var cam := get_node_or_null("Camera2D") as Camera2D
	if not cam or not _player:
		return
	var ws := DisplayServer.window_get_size()
	var room_px := Vector2(ROOM_W * TILE_SIZE, ROOM_H * TILE_SIZE)
	var cx := _player.position.x - ws.x * 0.5
	var cy := _player.position.y - ws.y * 0.5
	cx = clamp(cx, 0, room_px.x - ws.x)
	cy = clamp(cy, 0, room_px.y - ws.y)
	cam.position = Vector2(max(cx, 0), max(cy, 0))

func _exit_room() -> void:
	if _exiting:
		return
	_exiting = true
	_can_move = false
	if GridTrans.is_available() and not GridTrans.is_busy():
		await GridTrans.cover(0.8)
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("exit_room"):
		game.exit_room()
	else:
		queue_free()
