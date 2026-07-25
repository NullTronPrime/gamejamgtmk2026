extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")
const HumanoidRig := preload("res://scripts/shared/humanoid_rig.gd")

const TILE_SIZE := 64
const ROOM_W := 60
const ROOM_H := 12
const GRAVITY := 1400.0
const JUMP_VEL := -480.0
const MOVE_SPEED := 180.0
const CLIMB_SPEED := 120.0
const PUSH_FORCE := 300.0
const BLOCK_LAYER := 2
const WALL_LAYER := 1

enum TileType { EMPTY, WALL, FLOOR, PLATFORM, LADDER, EXIT }

var _player: CharacterBody2D
var _can_move := false
var _grid: Array[Array]
var _rng: RandomNumberGenerator
var _player_spawn: Vector2i
var _blocks: Array[RigidBody2D] = []
var _on_ladder := false
var _climbing := false
var _exiting := false
var _forest_layers: Array[CanvasLayer] = []
var _stage_hint: Label

var _is_pushing := false
var _jump_launch_time := -1.0
var _land_time := -1.0
var _was_on_floor := true

var _held_item: RigidBody2D
var _held_joint: PinJoint2D
var _shadow: Polygon2D
var _is_punching := false
var _punch_start := -1.0
var _punch_dir := Vector2.RIGHT
var _last_facing := 1.0

var _stage: int = 0
var _snake_retrieved := false
var _boulder_on_plate := false
var _cage_opened := false
var _flowers_picked := false
var _snakes_saved := 0
var _milk_retrieved := false
var _fireplace_lit := false
var _choice_made := false
var _nest_position: Vector2
var _fireplace_pos: Vector2
var _berries_collected := 0
var _flower_count_collected := 0

var _snake_arrow_pickup: Area2D
var _pressure_plate: Area2D
var _plate_visual: ColorRect
var _cage_visual: ColorRect
var _cage_letter: Area2D
var _flower_areas: Array[Area2D] = []
var _berry_areas: Array[Area2D] = []
var _snake_hide_spots: Array[Area2D] = []
var _snake_path_nodes: Array[Vector2] = []
var _nest_area: Area2D
var _milk_pickup: Area2D
var _fireplace_area: Area2D
var _exit_area: Area2D

var _dialogue_box: Node2D
var _interact_prompt: Label
var _progress_labels: Array[Label] = []

func _ready() -> void:
	_hide_forest_sky()
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash("hunting_%d" % randi())
	_build_skybox()
	_build_terrain()
	_build_stages()
	_spawn_player()
	_setup_camera()
	_setup_dialogue()
	_setup_prompts()
	GameInventory.selected_changed.connect(_on_selected_changed)
	reveal.call_deferred()

func _hide_forest_sky() -> void:
	var forest := get_node_or_null("/root/Game/ForestLevel")
	if forest:
		for child in forest.get_children():
			if child is CanvasLayer:
				_forest_layers.append(child)
				child.visible = false

func _restore_forest_sky() -> void:
	for l in _forest_layers:
		if is_instance_valid(l):
			l.visible = true
	_forest_layers.clear()

func _build_skybox() -> void:
	var vp := get_viewport_rect()
	var sky_cl := CanvasLayer.new()
	sky_cl.layer = -10
	add_child(sky_cl)

	var gradient_top := ColorRect.new()
	gradient_top.color = Color(0.5, 0.7, 0.95)
	gradient_top.size = vp.size * 2
	gradient_top.position = -gradient_top.size * 0.25
	gradient_top.mouse_filter = 2
	sky_cl.add_child(gradient_top)

	var cloud_tex := preload("res://assets/sprites/background/tree_light_grey.png")
	if cloud_tex:
		for i in 6:
			var cloud := Sprite2D.new()
			cloud.texture = cloud_tex
			cloud.scale = Vector2(0.3, 0.15)
			cloud.modulate = Color(1, 1, 1, 0.15)
			cloud.position = Vector2(_rng.randf_range(-600, 2400), _rng.randf_range(-300, -100))
			cloud.region_enabled = true
			cloud.region_rect = Rect2(0, 0, 128, 64)
			sky_cl.add_child(cloud)

	var sun := ColorRect.new()
	sun.color = Color(1.0, 0.95, 0.7, 0.3)
	sun.size = Vector2(120, 120)
	sun.position = Vector2(vp.size.x * 0.75 - 60, -80)
	sun.mouse_filter = 2
	sky_cl.add_child(sun)

func _build_terrain() -> void:
	for x in ROOM_W:
		_grid.append([])
		for y in ROOM_H:
			_grid[x].append(TileType.EMPTY)

	for x in ROOM_W:
		for y in [ROOM_H - 2, ROOM_H - 1]:
			_grid[x][y] = TileType.FLOOR
		_grid[x][ROOM_H - 3] = TileType.FLOOR

	for y in ROOM_H:
		_grid[0][y] = TileType.WALL
		_grid[ROOM_W - 1][y] = TileType.WALL

	for x in [0, ROOM_W - 1]:
		for y in [ROOM_H - 3, ROOM_H - 2, ROOM_H - 1]:
			_grid[x][y] = TileType.WALL

	var ground_tex := preload("res://assets/art/rooms/tilesets/Small_Rock_Tiles.png")
	var wall_tex := preload("res://assets/art/rooms/tilesets/Big_Tile_Rock.png")
	var grass_tex := preload("res://assets/art/rooms/tilesets/Grass_Tiles.png")

	var hs := TILE_SIZE * 0.5
	for x in ROOM_W:
		for y in ROOM_H:
			var t: TileType = _grid[x][y]
			if t == TileType.EMPTY or t == TileType.LADDER:
				continue
			var body := StaticBody2D.new()
			body.collision_layer = WALL_LAYER
			body.position = Vector2(x * TILE_SIZE + hs, y * TILE_SIZE + hs)
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = Vector2(TILE_SIZE, TILE_SIZE)
			shape.shape = box
			body.add_child(shape)
			add_child(body)

			var sp := Sprite2D.new()
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if t == TileType.WALL:
				sp.texture = wall_tex
			elif y >= ROOM_H - 3:
				if y == ROOM_H - 3:
					sp.texture = grass_tex
					sp.region_enabled = true
					sp.region_rect = Rect2(6 * TILE_SIZE, 2 * TILE_SIZE, TILE_SIZE, TILE_SIZE)
				else:
					sp.texture = ground_tex
					var idx := _rng.randi() % 4
					var ax: int = [2, 3, 6, 7][idx]
					sp.region_enabled = true
					sp.region_rect = Rect2(ax * TILE_SIZE, 2 * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			else:
				sp.texture = wall_tex
			sp.position = Vector2(x * TILE_SIZE + hs, y * TILE_SIZE + hs)
			sp.z_index = -1
			add_child(sp)

	_background_hills()

func _background_hills() -> void:
	for i in range(20):
		var hx := i * 200 + _rng.randi_range(-30, 30)
		var hw := _rng.randf_range(120, 300)
		var hh := _rng.randf_range(40, 120)
		var hy := ROOM_H * TILE_SIZE - 200 + _rng.randf_range(-20, 20)

		var hill := ColorRect.new()
		hill.size = Vector2(hw, hh)
		hill.position = Vector2(hx - hw / 2, hy - hh)
		hill.color = Color(0.2, 0.5, 0.15, 0.3)
		hill.z_index = -2
		hill.mouse_filter = 2
		add_child(hill)

		var outline := ColorRect.new()
		outline.size = Vector2(hw + 4, 3)
		outline.position = Vector2(hx - hw / 2 - 2, hy - 2)
		outline.color = Color(0.15, 0.4, 0.1, 0.25)
		outline.z_index = -2
		outline.mouse_filter = 2
		add_child(outline)

	var dirt_path := ColorRect.new()
	dirt_path.size = Vector2(ROOM_W * TILE_SIZE, 14)
	dirt_path.position = Vector2(0, (ROOM_H - 3) * TILE_SIZE)
	dirt_path.color = Color(0.35, 0.25, 0.15, 0.3)
	dirt_path.z_index = -1
	add_child(dirt_path)

func _build_stages() -> void:
	_build_stage1_snake()
	_build_stage2_boulder()
	_build_stage3_flowers()
	_build_stage4_garden()
	_build_stage5_yajna()
	_build_exit()

func _build_stage1_snake() -> void:
	var sx := 8 * TILE_SIZE + TILE_SIZE / 2
	var sy := (ROOM_H - 3) * TILE_SIZE - 8

	var snake_body := ColorRect.new()
	snake_body.size = Vector2(80, 12)
	snake_body.position = Vector2(sx - 40, sy)
	snake_body.color = Color(0.15, 0.5, 0.2)
	snake_body.z_index = 1
	add_child(snake_body)

	var snake_head := ColorRect.new()
	snake_head.size = Vector2(16, 10)
	snake_head.position = Vector2(sx + 35, sy - 2)
	snake_head.color = Color(0.1, 0.4, 0.15)
	snake_head.z_index = 1
	add_child(snake_head)

	var arrow_shaft := ColorRect.new()
	arrow_shaft.size = Vector2(3, 20)
	arrow_shaft.position = Vector2(sx + 5, sy - 18)
	arrow_shaft.color = Color(0.5, 0.35, 0.15)
	arrow_shaft.rotation = 0.3
	arrow_shaft.z_index = 2
	add_child(arrow_shaft)

	var arrow_head := ColorRect.new()
	arrow_head.size = Vector2(8, 6)
	arrow_head.position = Vector2(sx + 16, sy - 30)
	arrow_head.color = Color(0.6, 0.6, 0.6)
	arrow_head.rotation = 0.3
	arrow_head.z_index = 2
	add_child(arrow_head)

	var blood := ColorRect.new()
	blood.size = Vector2(18, 3)
	blood.position = Vector2(sx + 10, sy + 4)
	blood.color = Color(0.6, 0.05, 0.05, 0.5)
	blood.z_index = 1
	add_child(blood)

	_snake_arrow_pickup = Area2D.new()
	_snake_arrow_pickup.name = "SnakeArrowPickup"
	var pickup_shape := CollisionShape2D.new()
	var pickup_rect := RectangleShape2D.new()
	pickup_rect.size = Vector2(100, 60)
	pickup_shape.shape = pickup_rect
	_snake_arrow_pickup.add_child(pickup_shape)
	_snake_arrow_pickup.position = Vector2(sx, sy - 20)
	_snake_arrow_pickup.body_entered.connect(_on_snake_area_entered)
	_snake_arrow_pickup.collision_mask = 1
	add_child(_snake_arrow_pickup)

	var stage1_label := Label.new()
	stage1_label.text = "[Arrow]"
	stage1_label.add_theme_font_size_override("font_size", 9)
	stage1_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0.5))
	stage1_label.position = Vector2(sx - 20, sy - 42)
	stage1_label.mouse_filter = 2
	add_child(stage1_label)

func _on_snake_area_entered(body: Node) -> void:
	if body == _player and not _snake_retrieved:
		_snake_retrieved = true
		GameInventory.add_item("arrow")
		_snake_arrow_pickup.queue_free()
		_show_stage_text("You retrieve the arrow from the snake's body.\nBetaal: 'An experienced warrior's work...'", 4.0)
		var progress = _progress_labels[0]
		if progress:
			progress.modulate = Color(0.3, 0.8, 0.3, 0.8)

func _build_stage2_boulder() -> void:
	var bx := 16 * TILE_SIZE
	var by := (ROOM_H - 3) * TILE_SIZE - 24

	var mass := 3.0
	var b := RigidBody2D.new()
	b.name = "Boulder"
	b.gravity_scale = 1.0
	b.lock_rotation = true
	b.mass = mass
	b.linear_damp = 0.3
	b.angular_damp = 2.0
	b.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	b.collision_layer = BLOCK_LAYER
	b.collision_mask = WALL_LAYER | BLOCK_LAYER

	var mat := PhysicsMaterial.new()
	mat.friction = 0.8
	mat.bounce = 0.0
	b.physics_material_override = mat

	var body_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(48, 48)
	body_shape.shape = box
	b.add_child(body_shape)

	var sprite := ColorRect.new()
	sprite.size = Vector2(48, 48)
	sprite.position = Vector2(-24, -24)
	sprite.color = Color(0.45, 0.4, 0.3)
	b.add_child(sprite)

	var highlight := ColorRect.new()
	highlight.size = Vector2(36, 36)
	highlight.position = Vector2(-18, -18)
	highlight.color = Color(0.55, 0.48, 0.36)
	b.add_child(highlight)

	var crack1 := ColorRect.new()
	crack1.size = Vector2(10, 2)
	crack1.position = Vector2(-4, -6)
	crack1.color = Color(0.2, 0.18, 0.15, 0.8)
	crack1.rotation = 0.3
	b.add_child(crack1)

	b.position = Vector2(bx + TILE_SIZE / 2, by + TILE_SIZE / 2)
	add_child(b)
	_blocks.append(b)

	var px := 20 * TILE_SIZE + TILE_SIZE / 2
	var py := (ROOM_H - 2) * TILE_SIZE - 2

	_plate_visual = ColorRect.new()
	_plate_visual.size = Vector2(48, 6)
	_plate_visual.position = Vector2(px - 24, py - 6)
	_plate_visual.color = Color(0.4, 0.35, 0.25)
	add_child(_plate_visual)

	var plate_highlight := ColorRect.new()
	plate_highlight.size = Vector2(56, 10)
	plate_highlight.position = Vector2(px - 28, py - 8)
	plate_highlight.color = Color(0.6, 0.5, 0.2, 0.3)
	plate_highlight.mouse_filter = 2
	add_child(plate_highlight)

	var plate_label := Label.new()
	plate_label.text = "[Plate]"
	plate_label.add_theme_font_size_override("font_size", 9)
	plate_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0.5))
	plate_label.position = Vector2(px - 22, py + 8)
	plate_label.mouse_filter = 2
	add_child(plate_label)

	_pressure_plate = Area2D.new()
	_pressure_plate.name = "PressurePlate"
	var plate_shape := CollisionShape2D.new()
	var plate_rect := RectangleShape2D.new()
	plate_rect.size = Vector2(56, 16)
	plate_shape.shape = plate_rect
	_pressure_plate.add_child(plate_shape)
	_pressure_plate.position = Vector2(px, py + 6)
	_pressure_plate.body_entered.connect(_on_plate_body_entered)
	_pressure_plate.body_exited.connect(_on_plate_body_exited)
	_pressure_plate.collision_mask = 2 | 1
	add_child(_pressure_plate)

	_cage_visual = ColorRect.new()
	_cage_visual.size = Vector2(48, 36)
	_cage_visual.position = Vector2(px - 24, py - 100)
	_cage_visual.color = Color(0.3, 0.25, 0.15, 0.0)
	_cage_visual.z_index = 1
	add_child(_cage_visual)

	var cage_bars := ColorRect.new()
	cage_bars.size = Vector2(48, 36)
	cage_bars.position = Vector2(px - 24, py - 100)
	cage_bars.color = Color(0.4, 0.35, 0.25, 0.0)
	cage_bars.z_index = 2
	add_child(cage_bars)

	var cage_label := Label.new()
	cage_label.text = "[Cage]"
	cage_label.name = "CageLabel"
	cage_label.add_theme_font_size_override("font_size", 9)
	cage_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0.5))
	cage_label.position = Vector2(px - 18, py - 110)
	cage_label.mouse_filter = 2
	add_child(cage_label)

	_cage_letter = Area2D.new()
	_cage_letter.name = "CageLetter"
	var letter_shape := CollisionShape2D.new()
	var letter_rect := RectangleShape2D.new()
	letter_rect.size = Vector2(40, 30)
	letter_shape.shape = letter_rect
	_cage_letter.add_child(letter_shape)
	_cage_letter.position = Vector2(px, py - 82)
	_cage_letter.body_entered.connect(_on_letter_area_entered)
	_cage_letter.collision_mask = 1
	_cage_letter.monitoring = false
	add_child(_cage_letter)

func _on_plate_body_entered(body: Node) -> void:
	if body is RigidBody2D or body == _player:
		_boulder_on_plate = true
		_plate_visual.color = Color(0.6, 0.55, 0.3)
		_drop_cage()

func _on_plate_body_exited(body: Node) -> void:
	if body is RigidBody2D or body == _player:
		var still_pressed := false
		for b in _pressure_plate.get_overlapping_bodies():
			if b is RigidBody2D or b == _player:
				still_pressed = true
				break
		if not still_pressed:
			_boulder_on_plate = false
			_plate_visual.color = Color(0.4, 0.35, 0.25)

func _drop_cage() -> void:
	if _cage_opened:
		return
	_cage_opened = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_cage_visual, "color", Color(0.4, 0.35, 0.25, 0.9), 0.6)
	for c in _cage_visual.get_parent().get_children():
		if c is ColorRect and c != _cage_visual:
			if c.position.y > _cage_visual.position.y - 5 and c.position.y < _cage_visual.position.y + 5:
				tween.tween_property(c, "color", Color(0.4, 0.35, 0.25, 0.7), 0.6)

	var cage_label := get_node_or_null("CageLabel")
	if cage_label:
		cage_label.text = "[Read Letter (E)]"
		cage_label.modulate = Color(0.9, 0.8, 0.2)

	await get_tree().create_timer(0.7).timeout
	_cage_letter.monitoring = true

	var progress = _progress_labels[1]
	if progress:
		progress.modulate = Color(0.3, 0.8, 0.3, 0.8)

func _on_letter_area_entered(body: Node) -> void:
	if body == _player and _cage_opened and not _stage >= 3:
		_show_stage_text(
			"You find a letter inside the cage...\n\n" +
			"'I, Shaktinath, write this with regret.\n" +
			"I slew the serpent Nagesh in the heat of the hunt.\n" +
			"His mate Nageshwari seeks vengeance.\n" +
			"If you read this, complete my vow:\n" +
			"Light the Yajna fire with the hunter's arrow,\n" +
			"a mother's milk, and the flowers of forgiveness.'\n\n" +
			"Betaal: 'The Prince's wish must be fulfilled...'",
			7.0
		)
		_stage = max(_stage, 3)

func _build_stage3_flowers() -> void:
	var fx := 28 * TILE_SIZE
	var fy := (ROOM_H - 3) * TILE_SIZE

	for i in 3:
		var flower := Area2D.new()
		flower.name = "Flower_%d" % i
		var fshape := CollisionShape2D.new()
		var frect := RectangleShape2D.new()
		frect.size = Vector2(30, 30)
		fshape.shape = frect
		flower.add_child(fshape)
		flower.position = Vector2(fx + i * 40, fy - 15)
		flower.body_entered.connect(_on_flower_entered.bind(i))
		flower.collision_mask = 1
		flower.monitoring = true
		add_child(flower)
		_flower_areas.append(flower)

		var stem := ColorRect.new()
		stem.size = Vector2(3, 16)
		stem.position = Vector2(fx + i * 40 - 1.5, fy - 22)
		stem.color = Color(0.15, 0.5, 0.1)
		stem.z_index = 0
		add_child(stem)

		var petal := ColorRect.new()
		petal.size = Vector2(10, 10)
		petal.position = Vector2(fx + i * 40 - 5, fy - 32)
		petal.color = Color(0.9, 0.2 + i * 0.2, 0.3 + i * 0.15)
		petal.z_index = 1
		add_child(petal)

	var field_label := Label.new()
	field_label.text = "[Flowers]"
	field_label.add_theme_font_size_override("font_size", 9)
	field_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0.5))
	field_label.position = Vector2(fx + 30, fy - 44)
	field_label.mouse_filter = 2
	add_child(field_label)

func _on_flower_entered(body: Node, _idx: int) -> void:
	if body == _player and not _flowers_picked:
		if _flower_areas[_idx] and is_instance_valid(_flower_areas[_idx]):
			_flower_areas[_idx].queue_free()
			_flower_areas[_idx] = null
			_collect_flower()

func _collect_flower() -> void:
	var remaining := 0
	for f in _flower_areas:
		if f and is_instance_valid(f):
			remaining += 1
	if remaining == 0:
		_flowers_picked = true
		GameInventory.add_item("flower_bunch")
		_show_stage_text("You gather a bunch of wildflowers.\nBetaal: 'Nature's offering for the ritual...'", 3.5)
		var progress = _progress_labels[2]
		if progress:
			progress.modulate = Color(0.3, 0.8, 0.3, 0.8)
		_stage = max(_stage, 4)

func _build_stage4_garden() -> void:
	var gx := 36 * TILE_SIZE
	var gy := (ROOM_H - 3) * TILE_SIZE

	var garden_wall_left := ColorRect.new()
	garden_wall_left.color = Color(0.3, 0.22, 0.12)
	garden_wall_left.size = Vector2(8, (ROOM_H - 3) * TILE_SIZE)
	garden_wall_left.position = Vector2(gx - 8, 0)
	garden_wall_left.z_index = -1
	add_child(garden_wall_left)

	var garden_wall_right := ColorRect.new()
	garden_wall_right.color = Color(0.3, 0.22, 0.12)
	garden_wall_right.size = Vector2(8, (ROOM_H - 3) * TILE_SIZE)
	garden_wall_right.position = Vector2(gx + 10 * TILE_SIZE, 0)
	garden_wall_right.z_index = -1
	add_child(garden_wall_right)

	var arch := ColorRect.new()
	arch.color = Color(0.4, 0.3, 0.18)
	arch.size = Vector2(48, 8)
	arch.position = Vector2(gx + 5 * TILE_SIZE - 24, (ROOM_H - 4) * TILE_SIZE)
	arch.z_index = 0
	add_child(arch)

	var tree_pos := Vector2(gx + 6 * TILE_SIZE, gy - 200)
	var trunk := ColorRect.new()
	trunk.color = Color(0.25, 0.15, 0.05)
	trunk.size = Vector2(20, 160)
	trunk.position = tree_pos - Vector2(10, 160)
	trunk.z_index = 0
	add_child(trunk)

	var canopy := ColorRect.new()
	canopy.color = Color(0.08, 0.3, 0.06)
	canopy.size = Vector2(180, 120)
	canopy.position = tree_pos - Vector2(90, 200)
	canopy.z_index = 0
	add_child(canopy)

	var canopy2 := ColorRect.new()
	canopy2.color = Color(0.1, 0.35, 0.08, 0.7)
	canopy2.size = Vector2(120, 80)
	canopy2.position = tree_pos - Vector2(60, 180)
	canopy2.z_index = 1
	add_child(canopy2)

	_nest_position = Vector2(gx + 6 * TILE_SIZE, gy - 22)
	var nest := ColorRect.new()
	nest.name = "Nest"
	nest.color = Color(0.35, 0.25, 0.12)
	nest.size = Vector2(36, 12)
	nest.position = _nest_position - Vector2(18, 0)
	nest.z_index = 0
	add_child(nest)

	var nest_inside := ColorRect.new()
	nest_inside.color = Color(0.25, 0.18, 0.08)
	nest_inside.size = Vector2(24, 8)
	nest_inside.position = _nest_position - Vector2(12, 2)
	nest_inside.z_index = 1
	add_child(nest_inside)

	var nest_label := Label.new()
	nest_label.text = "[Nest]"
	nest_label.name = "NestLabel"
	nest_label.add_theme_font_size_override("font_size", 9)
	nest_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0.5))
	nest_label.position = _nest_position - Vector2(18, 24)
	nest_label.mouse_filter = 2
	add_child(nest_label)

	var nest_progress := Label.new()
	nest_progress.text = "Snakes: 0/3"
	nest_progress.name = "NestProgress"
	nest_progress.add_theme_font_size_override("font_size", 8)
	nest_progress.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3, 0.6))
	nest_progress.position = _nest_position - Vector2(22, -8)
	nest_progress.mouse_filter = 2
	add_child(nest_progress)

	_nest_area = Area2D.new()
	_nest_area.name = "NestArea"
	var nest_shape := CollisionShape2D.new()
	var nest_rect := RectangleShape2D.new()
	nest_rect.size = Vector2(50, 30)
	nest_shape.shape = nest_rect
	_nest_area.add_child(nest_shape)
	_nest_area.position = _nest_position
	_nest_area.monitoring = false
	add_child(_nest_area)

	_milk_pickup = Area2D.new()
	_milk_pickup.name = "MilkPickup"
	var milk_shape := CollisionShape2D.new()
	var milk_rect := RectangleShape2D.new()
	milk_rect.size = Vector2(40, 30)
	milk_shape.shape = milk_rect
	_milk_pickup.add_child(milk_shape)
	_milk_pickup.position = _nest_position + Vector2(0, 20)
	_milk_pickup.body_entered.connect(_on_milk_entered)
	_milk_pickup.collision_mask = 1
	_milk_pickup.monitoring = false
	add_child(_milk_pickup)

	var milk_vis := ColorRect.new()
	milk_vis.name = "MilkVisual"
	milk_vis.color = Color(0.9, 0.85, 0.7, 0.0)
	milk_vis.size = Vector2(24, 12)
	milk_vis.position = _nest_position - Vector2(12, 14)
	milk_vis.z_index = 1
	add_child(milk_vis)

	var garden_label := Label.new()
	garden_label.text = "[Snake Garden]"
	garden_label.add_theme_font_size_override("font_size", 9)
	garden_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0.5))
	garden_label.position = Vector2(gx + 20, gy - 220)
	garden_label.mouse_filter = 2
	add_child(garden_label)

	var hide_positions := [
		Vector2(gx + 2 * TILE_SIZE, gy - 16),
		Vector2(gx + 4 * TILE_SIZE, gy - 20),
		Vector2(gx + 8 * TILE_SIZE, gy - 18),
	]

	for i in 3:
		var hp: Vector2 = hide_positions[i]
		var hide_area := Area2D.new()
		hide_area.name = "SnakeHide_%d" % i
		var hshape := CollisionShape2D.new()
		var hrect := RectangleShape2D.new()
		hrect.size = Vector2(30, 24)
		hshape.shape = hrect
		hide_area.add_child(hshape)
		hide_area.position = hp
		hide_area.body_entered.connect(_on_snake_hide_entered.bind(i))
		hide_area.collision_mask = 1
		hide_area.monitoring = false
		add_child(hide_area)
		_snake_hide_spots.append(hide_area)

		var bush_block := ColorRect.new()
		bush_block.color = Color(0.12, 0.32, 0.08)
		bush_block.size = Vector2(28, 20)
		bush_block.position = hp - Vector2(14, 16)
		bush_block.z_index = 0
		add_child(bush_block)

		var hide_label := Label.new()
		hide_label.text = "[?]"
		hide_label.name = "HideLabel_%d" % i
		hide_label.add_theme_font_size_override("font_size", 9)
		hide_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.2, 0.0))
		hide_label.position = hp - Vector2(8, -12)
		hide_label.mouse_filter = 2
		add_child(hide_label)

	for i in 3:
		var bx := gx + (1 + i * 3) * TILE_SIZE
		var by := gy - 10
		var berry := Area2D.new()
		berry.name = "BerryBush_%d" % i
		var bshape := CollisionShape2D.new()
		var brect := RectangleShape2D.new()
		brect.size = Vector2(28, 24)
		bshape.shape = brect
		berry.add_child(bshape)
		berry.position = Vector2(bx, by)
		berry.body_entered.connect(_on_berry_bush_entered.bind(i))
		berry.collision_mask = 1
		berry.monitoring = true
		add_child(berry)
		_berry_areas.append(berry)

		var bush_vis := ColorRect.new()
		bush_vis.color = Color(0.15, 0.4, 0.1)
		bush_vis.size = Vector2(24, 18)
		bush_vis.position = Vector2(bx - 12, by - 16)
		bush_vis.z_index = 0
		add_child(bush_vis)

		var berry_dot := ColorRect.new()
		berry_dot.color = Color(0.85, 0.1, 0.1)
		berry_dot.size = Vector2(4, 4)
		berry_dot.position = Vector2(bx - 2, by - 8)
		berry_dot.z_index = 1
		add_child(berry_dot)

	_snake_path_nodes.append(hide_positions[0])
	_snake_path_nodes.append(hide_positions[1])
	_snake_path_nodes.append(hide_positions[2])

func _on_berry_bush_entered(body: Node, _idx: int) -> void:
	if body == _player and _stage >= 3 and _berries_collected < 3:
		if _berry_areas[_idx] and is_instance_valid(_berry_areas[_idx]):
			_berry_areas[_idx].queue_free()
			_berry_areas[_idx] = null
			_berries_collected += 1
			GameInventory.add_item("berry")
			_show_stage_text("You pick some berries from the bush.", 2.5)

			if _berries_collected >= 3:
				_show_stage_text(
					"The berries might help lure the baby snakes out...\n" +
					"Search the garden for their hiding spots!",
					4.0
				)
				for hide in _snake_hide_spots:
					hide.monitoring = true
				var i := 0
				for c in get_children():
					if c is Label and c.name.begins_with("HideLabel"):
						c.modulate = Color(0.3, 0.7, 0.2, 0.8)
						i += 1

func _on_snake_hide_entered(body: Node, idx: int) -> void:
	if body == _player and _berries_collected >= 3 and _snakes_saved < 3:
		if GameInventory.has_item("berry"):
			GameInventory.remove_item("berry")
			_snakes_saved += 1
			_snake_hide_spots[idx].monitoring = false

			var snake_path: Vector2 = _snake_path_nodes[idx] if idx < _snake_path_nodes.size() else Vector2.ZERO
			_animate_snake_to_nest(snake_path, idx)

			var label := get_node_or_null("NestProgress") as Label
			if label:
				label.text = "Snakes: %d/3" % _snakes_saved

			_show_stage_text("A baby snake emerges and slithers toward the nest!", 3.0)

			if _snakes_saved >= 3:
				_show_stage_text(
					"All three babies are safe in the nest.\n" +
					"A bowl of milk appears nearby.",
					4.0
				)
				var milk_vis := get_node_or_null("MilkVisual") as ColorRect
				if milk_vis:
					var mtween := create_tween()
					mtween.tween_property(milk_vis, "color", Color(0.9, 0.85, 0.7, 1.0), 0.8)
				_milk_pickup.monitoring = true
				_stage = max(_stage, 5)
				var progress = _progress_labels[3]
				if progress:
					progress.modulate = Color(0.3, 0.8, 0.3, 0.8)

func _animate_snake_to_nest(from: Vector2, idx: int) -> void:
	var snake := ColorRect.new()
	snake.color = Color(0.15, 0.5, 0.2)
	snake.size = Vector2(14, 5)
	snake.position = from - Vector2(7, 2)
	snake.z_index = 2
	add_child(snake)

	var tween := create_tween()
	var target: Vector2 = _nest_position + Vector2(-6 + idx * 6, 2)
	var mid := Vector2(from.x + (target.x - from.x) * 0.5, from.y - 30)
	tween.tween_property(snake, "position", mid - Vector2(7, 2), 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(snake, "position", target - Vector2(7, 2), 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		snake.queue_free()
		var nest := get_node_or_null("Nest")
		if nest:
			var size_add := ColorRect.new()
			size_add.color = Color(0.15, 0.5, 0.2)
			size_add.size = Vector2(4, 4)
			size_add.position = target - Vector2(2, 2)
			size_add.z_index = 1
			add_child(size_add)
	)

func _on_milk_entered(body: Node) -> void:
	if body == _player and not _milk_retrieved:
		_milk_retrieved = true
		GameInventory.add_item("milk_bowl")
		_milk_pickup.queue_free()
		var milk_vis := get_node_or_null("MilkVisual")
		if milk_vis:
			milk_vis.queue_free()
		_show_stage_text(
			"You retrieve the bowl of milk.\n" +
			"A vision appears: Nageshwari watches over her babies,\n" +
			"her eyes full of gratitude and sorrow.",
			5.0
		)
		_stage = max(_stage, 5)

func _build_stage5_yajna() -> void:
	var yx := 50 * TILE_SIZE + TILE_SIZE / 2
	var yy := (ROOM_H - 3) * TILE_SIZE

	var platform := ColorRect.new()
	platform.color = Color(0.5, 0.35, 0.15)
	platform.size = Vector2(120, 16)
	platform.position = Vector2(yx - 60, yy - 8)
	platform.z_index = 0
	add_child(platform)

	var altar := ColorRect.new()
	altar.color = Color(0.4, 0.28, 0.1)
	altar.size = Vector2(60, 24)
	altar.position = Vector2(yx - 30, yy - 24)
	altar.z_index = 0
	add_child(altar)

	var fire_pit := ColorRect.new()
	fire_pit.name = "FirePit"
	fire_pit.color = Color(0.15, 0.1, 0.05)
	fire_pit.size = Vector2(24, 8)
	fire_pit.position = Vector2(yx - 12, yy - 32)
	fire_pit.z_index = 1
	add_child(fire_pit)

	var fire_log1 := ColorRect.new()
	fire_log1.color = Color(0.35, 0.2, 0.08)
	fire_log1.size = Vector2(18, 3)
	fire_log1.position = Vector2(yx - 9, yy - 30)
	fire_log1.rotation = 0.4
	fire_log1.z_index = 1
	add_child(fire_log1)

	var fire_log2 := ColorRect.new()
	fire_log2.color = Color(0.3, 0.18, 0.06)
	fire_log2.size = Vector2(18, 3)
	fire_log2.position = Vector2(yx - 9, yy - 28)
	fire_log2.rotation = -0.3
	fire_log2.z_index = 1
	add_child(fire_log2)

	var yajna_label := Label.new()
	yajna_label.text = "[Yajna Fire]"
	yajna_label.add_theme_font_size_override("font_size", 9)
	yajna_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0.6))
	yajna_label.position = Vector2(yx - 30, yy - 70)
	yajna_label.mouse_filter = 2
	add_child(yajna_label)

	var slot_labels := [
		"Need: Arrow",
		"Need: Flowers",
		"Need: Milk Bowl"
	]
	for i in 3:
		var sl := Label.new()
		sl.text = slot_labels[i]
		sl.name = "SlotLabel_%d" % i
		sl.add_theme_font_size_override("font_size", 8)
		sl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.2, 0.7))
		sl.position = Vector2(yx - 80 + i * 55, yy - 48)
		sl.mouse_filter = 2
		add_child(sl)

	_fireplace_area = Area2D.new()
	_fireplace_area.name = "FireplaceArea"
	var fshape := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(80, 60)
	fshape.shape = frect
	_fireplace_area.add_child(fshape)
	_fireplace_area.position = Vector2(yx, yy - 30)
	_fireplace_area.body_entered.connect(_on_fireplace_entered)
	_fireplace_area.collision_mask = 1
	add_child(_fireplace_area)

	var fire_glow := ColorRect.new()
	fire_glow.name = "FireGlow"
	fire_glow.color = Color(1.0, 0.4, 0.05, 0.0)
	fire_glow.size = Vector2(60, 60)
	fire_glow.position = Vector2(yx - 30, yy - 70)
	fire_glow.mouse_filter = 2
	fire_glow.z_index = 0
	add_child(fire_glow)

	_fireplace_pos = Vector2(yx, yy)

func _on_fireplace_entered(body: Node) -> void:
	if body == _player and not _fireplace_lit and _stage >= 5:
		var has_arrow := GameInventory.has_item("arrow")
		var has_flowers := GameInventory.has_item("flower_bunch")
		var has_milk := GameInventory.has_item("milk_bowl")

		if has_arrow:
			var sl0 := get_node_or_null("SlotLabel_0") as Label
			if sl0:
				sl0.text = "Arrow: \u2713"
				sl0.modulate = Color(0.3, 0.8, 0.3, 0.8)
		if has_flowers:
			var sl1 := get_node_or_null("SlotLabel_1") as Label
			if sl1:
				sl1.text = "Flowers: \u2713"
				sl1.modulate = Color(0.3, 0.8, 0.3, 0.8)
		if has_milk:
			var sl2 := get_node_or_null("SlotLabel_2") as Label
			if sl2:
				sl2.text = "Milk: \u2713"
				sl2.modulate = Color(0.3, 0.8, 0.3, 0.8)

		if has_arrow and has_flowers and has_milk and not _fireplace_lit:
			_fireplace_lit = true
			GameInventory.remove_item("arrow")
			GameInventory.remove_item("flower_bunch")
			GameInventory.remove_item("milk_bowl")
			_light_fire()

func _light_fire() -> void:
	var fire_colors := [Color(1.0, 0.5, 0.05), Color(1.0, 0.3, 0.02), Color(0.8, 0.1, 0.01)]
	for i in 3:
		var flame := ColorRect.new()
		flame.color = fire_colors[i]
		flame.size = Vector2(8, 12 + i * 6)
		flame.position = _fireplace_pos + Vector2(-12 + i * 12, -52 - i * 4)
		flame.z_index = 2
		add_child(flame)

		var ftween := create_tween().set_loops()
		ftween.tween_property(flame, "color:a", 1.0, 0.1 + i * 0.05)
		ftween.tween_property(flame, "color:a", 0.7, 0.15 + i * 0.05)
		ftween.tween_property(flame, "color:a", 0.9, 0.12 + i * 0.05)

	var glow := get_node_or_null("FireGlow") as ColorRect
	if glow:
		var gtween := create_tween()
		gtween.tween_property(glow, "color", Color(1.0, 0.4, 0.05, 0.4), 0.8)
		var pulse := create_tween().set_loops()
		pulse.tween_property(glow, "color:a", 0.4, 0.5)
		pulse.tween_property(glow, "color:a", 0.25, 0.5)

	_show_dialogue_choice()

func _show_dialogue_choice() -> void:
	_can_move = false
	_show_stage_text(
		"The Yajna fire blazes. Shaktinath and Nageshwari appear at the entrance.\n\n" +
		"Betaal: 'The moment of truth, King. Choose:\n" +
		"Fulfill the Vow — let Shaktinath give himself up.\n" +
		"Protect the Prince — Nageshwari walks into the flame.'",
		6.0
	)

	await get_tree().create_timer(6.5).timeout

	_dialogue_box = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
	_dialogue_box.position = Vector2(200, 300)
	add_child(_dialogue_box)
	_dialogue_box.yes_button.text = "Fulfill the Vow"
	_dialogue_box.no_button.text = "Protect the Prince"
	_dialogue_box.response_chosen.connect(_on_choice_made)
	_dialogue_box.show_text("Shaktinath stands ready to give himself up.\nNageshwari glides toward the flame.\n\nWho do you let complete the sacrifice?")

func _on_choice_made(fulfill_vow: bool) -> void:
	if _choice_made:
		return
	_choice_made = true
	_can_move = true

	if _dialogue_box and _dialogue_box.get_parent():
		_dialogue_box.queue_free()
		_dialogue_box = null

	var consequence: String
	if fulfill_vow:
		consequence = "Shaktinath steps forward to fulfill his vow,\nbut Nageshwari slithers past him into the fire first.\n'No more death,' she hisses. 'Let the prince live.'\n\nBetaal: 'A mother's love overrides revenge...\nEven a serpent knows mercy, King.'"
	else:
		consequence = "Nageshwari glides into the sacred flame.\nHer serpent form dissolves in the light.\nShaktinath weeps.\n\nBetaal: 'Her maternal instinct was stronger than her vow.\nShe chose forgiveness over vengeance.'"

	var time_cost := 60.0
	if GameManager.run_timer > time_cost:
		GameManager.run_timer -= time_cost
		consequence += "\n\nYou sacrifice %d seconds of your time.\nThe path forward opens." % int(time_cost)
	else:
		GameManager.run_timer = 10.0
		consequence += "\n\nYou sacrifice almost all your remaining time.\nHurry — the forest awaits!"

	_show_stage_text(consequence, 6.0)

	await get_tree().create_timer(3.0).timeout
	_show_exit_door()

func _show_exit_door() -> void:
	var ex := ROOM_W - 3
	var ey := ROOM_H - 3

	_exit_area = Area2D.new()
	_exit_area.name = "ExitArea"
	var exit_shape := CollisionShape2D.new()
	var exit_rect := RectangleShape2D.new()
	exit_rect.size = Vector2(TILE_SIZE, TILE_SIZE * 2)
	exit_shape.shape = exit_rect
	_exit_area.add_child(exit_shape)
	_exit_area.position = Vector2(ex * TILE_SIZE + TILE_SIZE / 2, ey * TILE_SIZE + TILE_SIZE)
	_exit_area.body_entered.connect(_on_exit_entered)
	_exit_area.collision_mask = 1
	add_child(_exit_area)

	var exit_door_visual := ColorRect.new()
	exit_door_visual.color = Color(0.3, 0.6, 0.2, 0.0)
	exit_door_visual.size = Vector2(TILE_SIZE, TILE_SIZE * 2)
	exit_door_visual.position = Vector2(ex * TILE_SIZE, ey * TILE_SIZE)
	exit_door_visual.z_index = 1
	add_child(exit_door_visual)

	var tween := create_tween()
	tween.tween_property(exit_door_visual, "color", Color(0.3, 0.7, 0.2, 0.6), 0.8)

	var exit_glow := ColorRect.new()
	exit_glow.color = Color(0.3, 0.8, 0.2, 0.0)
	exit_glow.size = Vector2(TILE_SIZE * 2, TILE_SIZE * 2.5)
	exit_glow.position = Vector2(ex * TILE_SIZE - TILE_SIZE / 2, ey * TILE_SIZE - TILE_SIZE / 4)
	exit_glow.mouse_filter = 2
	exit_glow.z_index = 0
	add_child(exit_glow)
	tween.tween_property(exit_glow, "color", Color(0.3, 0.8, 0.2, 0.15), 0.8)

	var exit_label := Label.new()
	exit_label.text = "EXIT"
	exit_label.add_theme_font_size_override("font_size", 10)
	exit_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.3, 0.7))
	exit_label.position = Vector2(ex * TILE_SIZE + 14, ey * TILE_SIZE + TILE_SIZE - 6)
	exit_label.mouse_filter = 2
	add_child(exit_label)

	var progress = _progress_labels[4]
	if progress:
		progress.modulate = Color(0.3, 0.8, 0.3, 0.8)

func _build_exit() -> void:
	pass

func _spawn_player() -> void:
	_player = CharacterBody2D.new()
	_player.name = "Player"
	_player.collision_layer = 1
	_player.collision_mask = WALL_LAYER | BLOCK_LAYER

	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 88)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, 12)
	_player.add_child(col)

	HumanoidRig.build(_player, Color(0.55, 0.4, 0.25), Color(0.8, 0.65, 0.5))
	for c in _player.get_children():
		if c is Polygon2D:
			c.z_index = 1

	_player_spawn = Vector2i(2, ROOM_H - 4)
	_player.position = Vector2(_player_spawn.x * TILE_SIZE, _player_spawn.y * TILE_SIZE)
	add_child(_player)
	_shadow = _create_player_shadow()
	_player.add_child(_shadow)
	if not GameInventory.selected_item.is_empty():
		_update_held_item()

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = _player.position
	cam.zoom = Vector2(1.8, 1.8)
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(cam)
	cam.make_current()

func _setup_dialogue() -> void:
	_dialogue_box = null

func _setup_prompts() -> void:
	_interact_prompt = Label.new()
	_interact_prompt.text = ""
	_interact_prompt.add_theme_font_size_override("font_size", 12)
	_interact_prompt.add_theme_color_override("font_color", Color(1, 1, 0.8, 0.9))
	_interact_prompt.add_theme_constant_override("outline_size", 1)
	_interact_prompt.position = Vector2(10, 20)
	_interact_prompt.mouse_filter = 2
	add_child(_interact_prompt)

	_stage_hint = Label.new()
	_stage_hint.text = "Explore the hunting grounds..."
	_stage_hint.add_theme_font_size_override("font_size", 11)
	_stage_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7, 0.6))
	_stage_hint.add_theme_constant_override("outline_size", 1)
	_stage_hint.anchor_left = 0.5
	_stage_hint.anchor_top = 0.0
	_stage_hint.anchor_right = 0.5
	_stage_hint.anchor_bottom = 0.0
	_stage_hint.position = Vector2(-120, 60)
	_stage_hint.mouse_filter = 2
	add_child(_stage_hint)

	var stage_names := ["Find the Snake", "Move the Boulder", "Pick the Flowers", "Save the Snakes", "Light the Fire"]
	for i in 5:
		var sl := Label.new()
		sl.text = "\u25CB " + stage_names[i]
		sl.add_theme_font_size_override("font_size", 8)
		sl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5, 0.5))
		sl.position = Vector2(10, 260 + i * 16)
		sl.mouse_filter = 2
		add_child(sl)
		_progress_labels.append(sl)

func reveal() -> void:
	if GridTrans.is_available() and not GridTrans.is_busy():
		await GridTrans.reveal(0.8)
	_can_move = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_I and event.pressed and not event.echo:
			var inv = get_node_or_null("/root/Game/InventoryLayer/InventoryUI")
			if inv and inv.has_method("toggle"):
				inv.toggle()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_do_punch()

func _show_stage_text(text: String, duration: float) -> void:
	if _dialogue_box and _dialogue_box.get_parent():
		_dialogue_box.queue_free()
	_dialogue_box = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
	_dialogue_box.position = Vector2(200, 300)
	add_child(_dialogue_box)
	_dialogue_box.yes_button.visible = false
	_dialogue_box.no_button.visible = false
	_dialogue_box.show_text(text)
	await get_tree().create_timer(duration).timeout
	if _dialogue_box and _dialogue_box.get_parent():
		_dialogue_box.queue_free()
		_dialogue_box = null

func _physics_process(delta: float) -> void:
	if not _can_move or not _player:
		return

	var dir := Input.get_axis(&"move_left", &"move_right")
	if dir != 0:
		_last_facing = signf(dir)
	var on_floor := _player.is_on_floor()
	var vert := Input.get_axis(&"move_up", &"move_down")

	var space_held := Input.is_action_pressed(&"jump")
	_climbing = _on_ladder and (space_held or abs(vert) > 0.1)

	if _climbing:
		var climb_dir := 0.0
		if space_held:
			climb_dir = -1.0
		elif abs(vert) > 0.1:
			climb_dir = vert
		_player.velocity.x = dir * MOVE_SPEED * 0.5
		_player.velocity.y = climb_dir * CLIMB_SPEED
		_player.move_and_slide()
		_push_rigid_bodies()
		_update_rig_animation(dir, on_floor, true)
	else:
		var jump := Input.is_action_just_pressed(&"jump") and on_floor

		if jump:
			_jump_launch_time = Time.get_ticks_msec() / 1000.0

		if _was_on_floor and not on_floor:
			_jump_launch_time = Time.get_ticks_msec() / 1000.0
		elif not _was_on_floor and on_floor:
			_land_time = Time.get_ticks_msec() / 1000.0
			_jump_launch_time = -1.0
		_was_on_floor = on_floor

		_player.velocity.x = dir * MOVE_SPEED
		_player.velocity.y += GRAVITY * delta

		if _on_ladder and abs(vert) > 0.1 and _player.velocity.y > 0:
			_player.velocity.y = 0

		if jump:
			_player.velocity.y = JUMP_VEL

		_player.move_and_slide()
		_push_rigid_bodies()
		_update_rig_animation(dir, on_floor, false)

	_stage_hint_management()

	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.position = _player.position

	_update_held_item_position()
	if _is_punching and Time.get_ticks_msec() / 1000.0 - _punch_start > 0.15:
		_is_punching = false

func _stage_hint_management() -> void:
	var hints := {
		0: "Find the snake with the arrow...",
		1: "Push the boulder onto the pressure plate!",
		2: "Pick the flowers in the field ahead.",
		3: "Gather berries to lure the baby snakes!",
		4: "Use the arrow, flowers, and milk at the Yajna fire.",
		5: "The fire is lit! Make your choice.",
		6: "The exit is open — return to the forest!"
	}
	if _exiting:
		_stage_hint.text = ""
		return
	if _fireplace_lit:
		_stage_hint.text = hints[5]
		if _choice_made:
			_stage_hint.text = hints[6]
		return
	var player_x := _player.position.x
	if player_x < 6 * TILE_SIZE:
		_stage_hint.text = hints[0]
	elif player_x < 15 * TILE_SIZE:
		_stage_hint.text = hints[0] if not _snake_retrieved else "Good — now push the boulder!"
	elif player_x < 24 * TILE_SIZE:
		_stage_hint.text = hints[1] if not _cage_opened else "Check the cage!"
	elif player_x < 32 * TILE_SIZE:
		_stage_hint.text = hints[2]
	elif player_x < 46 * TILE_SIZE:
		_stage_hint.text = hints[3]
	else:
		_stage_hint.text = hints[4]

func _push_rigid_bodies() -> void:
	_is_pushing = false
	for i in _player.get_slide_collision_count():
		var col := _player.get_slide_collision(i)
		var body := col.get_collider()
		if body is RigidBody2D:
			_is_pushing = true
			var push_dir := col.get_normal() * -1.0
			var speed_ratio := clampf(_player.velocity.length() / MOVE_SPEED, 0.2, 1.0)
			var force_mult: float = 2.0 + body.mass * 0.5
			body.apply_central_force(push_dir * PUSH_FORCE * speed_ratio * force_mult)
			body.apply_torque(push_dir.x * 800.0 * speed_ratio)

func _update_rig_animation(dir: float, on_floor: bool, climbing: bool) -> void:
	var t := Time.get_ticks_msec() / 1000.0 * 2.0

	if climbing:
		var phase := t * 3.5
		var r_up := sin(phase)
		var l_up := sin(phase + PI)

		var r_shoulder := _get_rig_part("RShoulder")
		var l_shoulder := _get_rig_part("LShoulder")
		if r_shoulder: r_shoulder.rotation = -0.85 + (r_up + 1.0) * 0.5 * 0.65
		if l_shoulder: l_shoulder.rotation = 0.85 - (l_up + 1.0) * 0.5 * 0.65

		var r_elbow := _get_rig_part("RElbow")
		var l_elbow := _get_rig_part("LElbow")
		if r_elbow:
			r_elbow.position = Vector2(0, 16)
			r_elbow.rotation = 0.2 + (r_up + 1.0) * 0.5 * 0.5
		if l_elbow:
			l_elbow.position = Vector2(0, 16)
			l_elbow.rotation = 0.2 + (l_up + 1.0) * 0.5 * 0.5

		var r_hip := _get_rig_part("RHip")
		var l_hip := _get_rig_part("LHip")
		var r_knee := _get_rig_part("RKnee")
		var l_knee := _get_rig_part("LKnee")
		if r_hip: r_hip.rotation = 0
		if l_hip: l_hip.rotation = 0
		if r_knee: r_knee.rotation = lerp(0.0, 0.5, (1.0 + l_up) * 0.5)
		if l_knee: l_knee.rotation = lerp(0.0, 0.5, (1.0 + r_up) * 0.5)

		var torso := _get_rig_part("Torso")
		if torso: torso.rotation = -0.1 + sin(phase) * 0.04
		return

	if not on_floor:
		for c in _player.get_children():
			if c is Polygon2D:
				c.rotation = 0
			if c is Node2D and c.name in ["RShoulder", "LShoulder", "RHip", "LHip"]:
				c.rotation = 0
		var torso := _get_rig_part("Torso")
		if torso: torso.rotation = 0.15 if _player.velocity.y < 0 else -0.1
		var l_shoulder := _get_rig_part("LShoulder")
		var r_shoulder := _get_rig_part("RShoulder")
		if _player.velocity.y < 0:
			if l_shoulder: l_shoulder.rotation = -0.6
			if r_shoulder: r_shoulder.rotation = 0.6
		else:
			if l_shoulder: l_shoulder.rotation = -0.2
			if r_shoulder: r_shoulder.rotation = 0.2
		return

	var now := Time.get_ticks_msec() / 1000.0

	if _land_time > 0.0 and now - _land_time < 0.15:
		var land_factor: float = (now - _land_time) / 0.15
		var squat: float = lerp(0.4, 0.0, land_factor)
		var l_knee := _get_rig_part("LKnee")
		var r_knee := _get_rig_part("RKnee")
		if l_knee: l_knee.rotation = squat
		if r_knee: r_knee.rotation = squat
		var torso := _get_rig_part("Torso")
		if torso: torso.rotation = -squat * 0.3
		var r_hip := _get_rig_part("RHip")
		var l_hip := _get_rig_part("LHip")
		if l_hip: l_hip.rotation = -squat * 0.1
		if r_hip: r_hip.rotation = squat * 0.1
		return

	if _is_punching:
		var punch_now: float = Time.get_ticks_msec() / 1000.0
		var elapsed: float = punch_now - _punch_start
		if elapsed < 0.15:
			var p: float = min(elapsed / 0.1, 1.0)
			var f: float = _last_facing
			var torso: Node2D = _get_rig_part("Torso")
			if torso:
				var forward := Vector2(f, 0)
				var rel_angle := forward.angle_to(_punch_dir) if _punch_dir.length_squared() > 0 else 0.0
				torso.rotation = -0.15 * f * p + clamp(rel_angle * 0.2, -0.3, 0.3) * p
			var closer_s: Node2D
			var closer_e: Node2D
			if f > 0:
				closer_s = _get_rig_part("LShoulder")
				closer_e = _get_rig_part("LElbow")
			else:
				closer_s = _get_rig_part("RShoulder")
				closer_e = _get_rig_part("RElbow")
			if closer_s: closer_s.rotation = 0.8 * p * f
			if closer_e: closer_e.rotation = -0.3 * p
		return

	if _is_pushing:
		var facing := signf(dir)
		var torso := _get_rig_part("Torso")
		if torso: torso.rotation = -0.2 * facing
		var l_shoulder := _get_rig_part("LShoulder")
		var r_shoulder := _get_rig_part("RShoulder")
		if l_shoulder: l_shoulder.rotation = 0.7 * facing
		if r_shoulder: r_shoulder.rotation = -0.7 * facing
		var l_elbow := _get_rig_part("LElbow")
		var r_elbow := _get_rig_part("RElbow")
		if l_elbow: l_elbow.rotation = -0.1
		if r_elbow: r_elbow.rotation = 0.1
		var l_knee := _get_rig_part("LKnee")
		var r_knee := _get_rig_part("RKnee")
		if l_knee: l_knee.rotation = 0.25
		if r_knee: r_knee.rotation = 0.25
		var l_hip := _get_rig_part("LHip")
		var r_hip := _get_rig_part("RHip")
		if l_hip: l_hip.rotation = 0.1 * facing
		if r_hip: r_hip.rotation = -0.1 * facing
		return

	if abs(dir) < 0.1:
		var bob := sin(t * 1.5) * 0.02
		var torso := _get_rig_part("Torso")
		if torso: torso.rotation = bob
		return

	var phase := t * 4.0 * signf(dir)
	var swing := sin(phase) * 0.5

	var r_shoulder := _get_rig_part("RShoulder")
	var l_shoulder := _get_rig_part("LShoulder")
	var r_hip := _get_rig_part("RHip")
	var l_hip := _get_rig_part("LHip")

	if r_shoulder: r_shoulder.rotation = swing * 0.6
	if l_shoulder: l_shoulder.rotation = -swing * 0.6
	if r_hip: r_hip.rotation = -swing * 0.4
	if l_hip: l_hip.rotation = swing * 0.4

	var torso := _get_rig_part("Torso")
	if torso: torso.rotation = -swing * 0.1

func _on_selected_changed(_item_id: String) -> void:
	_update_held_item()

func _create_player_shadow() -> Polygon2D:
	var shadow := Polygon2D.new()
	shadow.name = "PlayerShadow"
	var pts := PackedVector2Array()
	var seg := 20
	for i in seg:
		var a := TAU * i / seg
		pts.append(Vector2(cos(a) * 18.0, sin(a) * 7.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.position = Vector2(0, 55)
	shadow.z_index = -1
	return shadow

func _cleanup_held_item() -> void:
	if _held_joint:
		_held_joint.queue_free()
		_held_joint = null
	if _held_item:
		_held_item.queue_free()
		_held_item = null

func _update_held_item() -> void:
	_cleanup_held_item()
	if GameInventory.selected_item.is_empty() or not is_instance_valid(_player):
		return
	var data: Dictionary = GameInventory.item_data()
	if not data.has(GameInventory.selected_item):
		return
	var icon: Color = data[GameInventory.selected_item]["icon"]

	_held_item = RigidBody2D.new()
	_held_item.name = "HeldItem"
	_held_item.mass = 0.5
	_held_item.gravity_scale = 0.5
	_held_item.collision_layer = 8
	_held_item.collision_mask = WALL_LAYER | BLOCK_LAYER
	var held_shape := CollisionShape2D.new()
	var held_rect := RectangleShape2D.new()
	held_rect.size = Vector2(10, 14)
	held_shape.shape = held_rect
	_held_item.add_child(held_shape)
	var held_vis := ColorRect.new()
	held_vis.size = Vector2(10, 14)
	held_vis.color = icon
	held_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_item.add_child(held_vis)
	_held_item.add_collision_exception_with(_player)

	var hands_pos := _player.global_position + Vector2(_last_facing * 16, -8)
	_held_item.global_position = hands_pos
	add_child(_held_item)

	_held_joint = PinJoint2D.new()
	_held_joint.name = "HeldItemJoint"
	_held_joint.global_position = hands_pos
	add_child(_held_joint)
	_held_joint.node_a = _held_item.get_path()
	_held_joint.node_b = _player.get_path()

func _update_held_item_position() -> void:
	if not _held_item or not _held_joint or not is_instance_valid(_player):
		return
	_held_joint.global_position = _player.global_position + Vector2(_last_facing * 16, -8)

func _do_punch() -> void:
	if not _can_move or not is_instance_valid(_player):
		return
	_is_punching = true
	_punch_start = Time.get_ticks_msec() / 1000.0
	_punch_dir = (_player.get_global_mouse_position() - _player.global_position).normalized()

	_player.velocity += -_punch_dir * 150.0

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	query.shape = shape
	query.transform = Transform2D(0, _player.global_position + _punch_dir * 35.0)
	query.collision_mask = BLOCK_LAYER
	query.exclude = [_player]

	for r in space_state.intersect_shape(query):
		var body: Variant = r.collider
		if body is RigidBody2D:
			body.apply_central_force(_punch_dir * 500.0)
			body.apply_torque(_punch_dir.x * 300.0)

func _get_rig_part(part_name: String) -> Node2D:
	return _find_node_recursive(_player, part_name)

func _find_node_recursive(parent: Node, name: String) -> Node2D:
	for c in parent.get_children():
		if c is Node2D and c.name == name:
			return c
		if c.get_child_count() > 0:
			var found := _find_node_recursive(c, name)
			if found:
				return found
	return null

func _on_exit_entered(body: Node) -> void:
	if body == _player and _choice_made and not _exiting:
		_exit_dungeon()

func _exit_dungeon() -> void:
	if _exiting:
		return
	_exiting = true
	_can_move = false
	_cleanup_held_item()
	_restore_forest_sky()
	if GridTrans.is_available() and not GridTrans.is_busy():
		await GridTrans.cover(0.8)
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("exit_dungeon"):
		game.exit_dungeon()
	else:
		queue_free()
