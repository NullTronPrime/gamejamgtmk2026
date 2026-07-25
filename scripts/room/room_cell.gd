extends Node2D
class_name RoomCell

const TEXTURES := {
	"r1": preload("res://assets/art/rooms/r1.png"),
	"r2": preload("res://assets/art/rooms/r2.png"),
	"r3": preload("res://assets/art/rooms/r3.png"),
	"r4": preload("res://assets/art/rooms/r4.png"),
	"r5": preload("res://assets/art/rooms/r5.png"),
}

var ceiling: Sprite2D
var floor_panel: Sprite2D
var left_wall: Sprite2D
var right_wall: Sprite2D
var back_wall: Sprite2D
var puzzle_socket: Node2D

var _texture_override: Dictionary = {}

func set_texture_override(overrides: Dictionary) -> void:
	for key in overrides:
		_texture_override[key] = overrides[key]


func build() -> void:
	var t := _texture_override

	_add_bg_frame()

	back_wall = Sprite2D.new()
	back_wall.name = "Back"
	back_wall.texture = t.get("r1", TEXTURES.r1)
	add_child(back_wall)

	puzzle_socket = Node2D.new()
	puzzle_socket.name = "PuzzleSocket"
	back_wall.add_child(puzzle_socket)

	left_wall = Sprite2D.new()
	left_wall.name = "LeftWall"
	left_wall.texture = t.get("r2", TEXTURES.r2)
	add_child(left_wall)

	ceiling = Sprite2D.new()
	ceiling.name = "Ceiling"
	ceiling.texture = t.get("r3", TEXTURES.r3)
	add_child(ceiling)

	floor_panel = Sprite2D.new()
	floor_panel.name = "Floor"
	floor_panel.texture = t.get("r4", TEXTURES.r4)
	add_child(floor_panel)

	right_wall = Sprite2D.new()
	right_wall.name = "RightWall"
	right_wall.texture = t.get("r5", TEXTURES.r5)
	add_child(right_wall)


func _add_bg_frame() -> void:
	var c := Color(0.05, 0.04, 0.06)
	var hw := 565.0 * 0.5
	var hh := 441.0 * 0.5

	var left := ColorRect.new()
	left.color = c
	left.size = Vector2(152.0, 441.0)
	left.position = Vector2(-hw, -hh)
	add_child(left)

	var right := ColorRect.new()
	right.color = c
	right.size = Vector2(131.0, 441.0)
	right.position = Vector2(435.0 - hw, -hh)
	add_child(right)

	var top := ColorRect.new()
	top.color = c
	top.size = Vector2(283.0, 227.0)
	top.position = Vector2(152.0 - hw, -hh)
	add_child(top)

	var bottom := ColorRect.new()
	bottom.color = c
	bottom.size = Vector2(283.0, 121.0)
	bottom.position = Vector2(152.0 - hw, 320.0 - hh)
	add_child(bottom)


func configure(open_left: bool, open_right: bool, is_dead_end: bool, inward_scene_path: String = "") -> void:
	left_wall.visible = not open_left
	right_wall.visible = not open_right
	back_wall.visible = is_dead_end

	for child in puzzle_socket.get_children():
		child.queue_free()

	if is_dead_end and inward_scene_path != "":
		var packed: PackedScene = load(inward_scene_path)
		if packed:
			puzzle_socket.add_child(packed.instantiate())
