class_name DungeonPickup
extends RigidBody2D

signal picked_up(item_id: String)

@export var item_id: String = "bottle_empty"
@export var pickup_radius: float = 80.0

var _player_ref: Node2D
var _exclamation: ColorRect
var _in_range := false
var _moused_over := false

func _ready() -> void:
	gravity_scale = 1.0
	lock_rotation = true
	linear_damp = 0.5
	angular_damp = 2.0
	mass = randf_range(3.0, 8.0)

	collision_layer = 4
	collision_mask = 1 | 2

	var mat := PhysicsMaterial.new()
	mat.friction = 0.95
	mat.bounce = 0.0
	physics_material_override = mat

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(32, 32)
	shape.shape = box
	add_child(shape)

	_build_sprite()
	_build_exclamation()

func _build_exclamation() -> void:
	_exclamation = ColorRect.new()
	_exclamation.size = Vector2(18, 22)
	_exclamation.position = Vector2(-9, -46)
	_exclamation.color = Color(0.9, 0.1, 0.1, 0.9)
	_exclamation.visible = false
	_exclamation.mouse_filter = 2
	add_child(_exclamation)

	var bar := ColorRect.new()
	bar.size = Vector2(8, 14)
	bar.position = Vector2(-4, -42)
	bar.color = Color(1, 1, 1, 1)
	bar.mouse_filter = 2
	_exclamation.add_child(bar)

	var dot := ColorRect.new()
	dot.size = Vector2(4, 4)
	dot.position = Vector2(-2, -22)
	dot.color = Color(1, 1, 1, 1)
	dot.mouse_filter = 2
	_exclamation.add_child(dot)

func _build_sprite() -> void:
	var colors: Dictionary = {
		"bottle_empty": { "body": Color(0.15, 0.6, 0.15), "detail": Color(0.25, 0.7, 0.25) },
		"liquid_blue": { "body": Color(0.15, 0.25, 0.85), "detail": Color(0.1, 0.15, 0.6) },
		"potion_filled": { "body": Color(0.3, 0.5, 0.6), "detail": Color(0.4, 0.6, 0.7) }
	}
	var pal: Dictionary = colors.get(item_id, colors["bottle_empty"])

	var bg := ColorRect.new()
	bg.size = Vector2(24, 32)
	bg.position = Vector2(-12, -16)
	bg.color = pal["body"]
	bg.mouse_filter = 2
	add_child(bg)

	var detail := ColorRect.new()
	detail.size = Vector2(14, 20)
	detail.position = Vector2(-7, -10)
	detail.color = pal["detail"]
	detail.mouse_filter = 2
	add_child(detail)

	var wgt := ColorRect.new()
	wgt.size = Vector2(20, 3)
	wgt.position = Vector2(-10, 17)
	wgt.color = Color(0.4, 0.3, 0.2, 0.6)
	wgt.mouse_filter = 2
	add_child(wgt)

	var wgt_fill := ColorRect.new()
	var fill_w: float = 4.0 + (mass / 2.0) * 14.0
	wgt_fill.size = Vector2(fill_w, 3)
	wgt_fill.position = Vector2(-10, 17)
	wgt_fill.color = Color(0.8, 0.7, 0.3, 0.8)
	wgt_fill.mouse_filter = 2
	add_child(wgt_fill)

func _process(_delta: float) -> void:
	if not _player_ref:
		_player_ref = get_node_or_null("/root/Game/DungeonLevel/Player")
		return

	var dist: float = global_position.distance_to(_player_ref.global_position)
	_in_range = dist < pickup_radius

	var mouse_global: Vector2 = get_global_mouse_position()
	var item_rect := Rect2(global_position.x - 16, global_position.y - 24, 32, 40)
	_moused_over = _in_range and item_rect.has_point(mouse_global)

	_exclamation.visible = _in_range
	_exclamation.color = Color(0.9, 0.1, 0.1, 0.9) if not _moused_over else Color(0.9, 0.85, 0.1, 0.95)

func _input(event: InputEvent) -> void:
	if _in_range and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var inv: Node = get_node_or_null("/root/Game/DungeonLevel/InventoryUI")
		var inv_control: DungeonInventory = inv as DungeonInventory if inv else null
		if inv_control and not inv_control.visible:
			if inv_control.add_item(item_id):
				picked_up.emit(item_id)
				queue_free()
