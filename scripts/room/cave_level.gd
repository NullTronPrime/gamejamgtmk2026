extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")

const TILE_SIZE := 64
const ROOM_W := 20
const ROOM_H := 14
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

var _pressure_plate: Area2D
var _pressure_activated := false
var _plate_visual: ColorRect
var _plate_highlight: ColorRect

var _exit_door: Area2D
var _exit_door_visual: ColorRect
var _exit_closed_visual: ColorRect
var _exit_hcross: ColorRect
var _exit_vcross: ColorRect
var _door_open := false

func _ready() -> void:
	_hide_forest_sky()
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash("cave_%d" % randi())
	_build_skybox()
	_generate_room()
	_spawn_player()
	_setup_camera()
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
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.03)
	bg.size = vp.size * 2
	bg.position = -bg.size * 0.25
	bg.mouse_filter = 2
	var sky_cl := CanvasLayer.new()
	sky_cl.layer = -10
	sky_cl.add_child(bg)
	add_child(sky_cl)

func _generate_room() -> void:
	_grid = []
	for x in ROOM_W:
		_grid.append([])
		for y in ROOM_H:
			_grid[x].append(TileType.EMPTY)

	_carve_room()
	_add_tiles()
	_add_ladder()
	_add_pressure_plate()
	_add_blocks()
	_add_pickups()
	_add_torches()
	_add_exit_door()

func _carve_room() -> void:
	for x in ROOM_W:
		_grid[x][0] = TileType.WALL
		for y in [ROOM_H - 3, ROOM_H - 2, ROOM_H - 1]:
			_grid[x][y] = TileType.FLOOR

	for y in ROOM_H:
		_grid[0][y] = TileType.WALL
		_grid[ROOM_W - 1][y] = TileType.WALL

	for x in range(9, 12):
		_grid[x][ROOM_H - 3] = TileType.EMPTY

	for x in range(4, 9):
		_grid[x][ROOM_H - 6] = TileType.PLATFORM
	for x in range(14, 19):
		_grid[x][ROOM_H - 6] = TileType.PLATFORM

	_player_spawn = Vector2i(3, ROOM_H - 4)

func _add_tiles() -> void:
	var tex := preload("res://assets/art/rooms/tilesets/Small_Rock_Tiles.png")
	var wall_tex := preload("res://assets/art/rooms/tilesets/Big_Tile_Rock.png")
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
				var atlas_x := x % 12
				var atlas_y := y % 4
				sp.region_enabled = true
				sp.region_rect = Rect2(atlas_x * TILE_SIZE, atlas_y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			else:
				sp.texture = tex
				var r := _rng.randi()
				var idx: int = r % 4
				var atlas_x: int = [2, 3, 6, 7][idx]
				var atlas_y := 2
				sp.region_enabled = true
				sp.region_rect = Rect2(atlas_x * TILE_SIZE, atlas_y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			sp.position = Vector2(x * TILE_SIZE + hs, y * TILE_SIZE + hs)
			sp.z_index = -1
			add_child(sp)

func _add_ladder() -> void:
	var lx := 2
	var top_y := 3
	var bot_y := ROOM_H - 5

	for y in range(top_y, bot_y + 1):
		_grid[lx][y] = TileType.LADDER
		_grid[lx + 1][y] = TileType.LADDER

	for y in range(top_y, bot_y + 1):
		var cx0 := lx * TILE_SIZE
		var cx1 := (lx + 1) * TILE_SIZE
		var cy := y * TILE_SIZE

		for dx in 2:
			var rail_x := cx0 if dx == 0 else cx1 + TILE_SIZE - 4
			var rail := ColorRect.new()
			rail.size = Vector2(4, TILE_SIZE)
			rail.position = Vector2(rail_x, cy)
			rail.color = Color(0.35, 0.3, 0.25)
			rail.z_index = -1
			add_child(rail)

		for rung_y in range(0, TILE_SIZE, 16):
			var rung := ColorRect.new()
			rung.size = Vector2(TILE_SIZE * 2 - 8, 3)
			rung.position = Vector2(cx0 + 4, cy + rung_y)
			rung.color = Color(0.3, 0.25, 0.2)
			rung.z_index = -1
			add_child(rung)

	var ladder_area := Area2D.new()
	var ladder_shape := CollisionShape2D.new()
	var ladder_rect := RectangleShape2D.new()
	ladder_rect.size = Vector2(TILE_SIZE * 2, (bot_y - top_y + 1) * TILE_SIZE)
	ladder_shape.shape = ladder_rect
	ladder_area.add_child(ladder_shape)
	ladder_area.position = Vector2((lx + 1) * TILE_SIZE, (top_y + bot_y) * TILE_SIZE / 2 + TILE_SIZE / 2)
	ladder_area.body_entered.connect(_on_ladder_enter)
	ladder_area.body_exited.connect(_on_ladder_exit)
	ladder_area.collision_mask = 1
	add_child(ladder_area)

func _on_ladder_enter(body: Node) -> void:
	if body == _player:
		_on_ladder = true

func _on_ladder_exit(body: Node) -> void:
	if body == _player:
		_on_ladder = false
		_climbing = false

func _add_pressure_plate() -> void:
	var px := 10
	var py := ROOM_H - 2

	_plate_visual = ColorRect.new()
	_plate_visual.size = Vector2(48, 6)
	_plate_visual.position = Vector2(px * TILE_SIZE + 8, py * TILE_SIZE - 6)
	_plate_visual.color = Color(0.4, 0.35, 0.25)
	add_child(_plate_visual)

	_plate_highlight = ColorRect.new()
	_plate_highlight.size = Vector2(56, 10)
	_plate_highlight.position = Vector2(px * TILE_SIZE + 4, py * TILE_SIZE - 8)
	_plate_highlight.color = Color(0.6, 0.5, 0.2, 0.3)
	_plate_highlight.mouse_filter = 2
	add_child(_plate_highlight)

	_pressure_plate = Area2D.new()
	_pressure_plate.name = "PressurePlate"
	var plate_shape := CollisionShape2D.new()
	var plate_rect := RectangleShape2D.new()
	plate_rect.size = Vector2(56, 16)
	plate_shape.shape = plate_rect
	_pressure_plate.add_child(plate_shape)
	_pressure_plate.position = Vector2(px * TILE_SIZE + 32, py * TILE_SIZE - 2)
	_pressure_plate.body_entered.connect(_on_plate_body_entered)
	_pressure_plate.body_exited.connect(_on_plate_body_exited)
	_pressure_plate.collision_mask = 2 | 1
	add_child(_pressure_plate)

	var plate_label := Label.new()
	plate_label.text = "[P]"
	plate_label.add_theme_font_size_override("font_size", 10)
	plate_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0.6))
	plate_label.position = Vector2(px * TILE_SIZE + 22, py * TILE_SIZE + TILE_SIZE - 20)
	plate_label.mouse_filter = 2
	add_child(plate_label)

func _on_plate_body_entered(body: Node) -> void:
	if body is RigidBody2D or body == _player:
		_pressure_activated = true
		_plate_visual.color = Color(0.6, 0.55, 0.3)
		_plate_highlight.color = Color(0.8, 0.7, 0.2, 0.5)
		_check_puzzle_solved()

func _on_plate_body_exited(body: Node) -> void:
	if body is RigidBody2D or body == _player:
		var still_pressed := false
		for b in _pressure_plate.get_overlapping_bodies():
			if b is RigidBody2D or b == _player:
				still_pressed = true
				break
		if not still_pressed:
			_pressure_activated = false
			_plate_visual.color = Color(0.4, 0.35, 0.25)
			_plate_highlight.color = Color(0.6, 0.5, 0.2, 0.3)

func _check_puzzle_solved() -> void:
	if _door_open:
		return
	if _pressure_activated:
		_door_open = true
		_open_exit()

func _add_blocks() -> void:
	var px := 7
	var py := ROOM_H - 6
	if _grid[px][py] != TileType.PLATFORM:
		return

	var mass := 2.0
	var b := RigidBody2D.new()
	b.name = "PushBlock_0"
	b.gravity_scale = 1.0
	b.lock_rotation = false
	b.mass = mass
	b.linear_damp = 0.1
	b.angular_damp = 0.3
	b.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	b.collision_layer = BLOCK_LAYER
	b.collision_mask = WALL_LAYER | BLOCK_LAYER

	var mat := PhysicsMaterial.new()
	mat.friction = 0.1
	mat.bounce = 0.05
	b.physics_material_override = mat

	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22
	body_shape.shape = circle
	body_shape.position = Vector2(0, 0)
	b.add_child(body_shape)

	var rock := Polygon2D.new()
	rock.polygon = _circle_poly(22, 32)
	rock.color = Color(0.35, 0.3, 0.25)
	b.add_child(rock)

	var highlight := Polygon2D.new()
	highlight.polygon = _circle_poly(12, 20)
	highlight.color = Color(0.5, 0.44, 0.35, 0.5)
	highlight.position = Vector2(-4, -6)
	b.add_child(highlight)

	var shadow := Polygon2D.new()
	shadow.polygon = _circle_poly(14, 20)
	shadow.color = Color(0.2, 0.18, 0.15, 0.4)
	shadow.position = Vector2(2, 6)
	b.add_child(shadow)

	var crack1 := ColorRect.new()
	crack1.size = Vector2(10, 2)
	crack1.position = Vector2(-4, -6)
	crack1.color = Color(0.2, 0.18, 0.15, 0.8)
	crack1.rotation = 0.3
	b.add_child(crack1)
	var crack2 := ColorRect.new()
	crack2.size = Vector2(2, 8)
	crack2.position = Vector2(6, -4)
	crack2.color = Color(0.2, 0.18, 0.15, 0.7)
	crack2.rotation = -0.2
	b.add_child(crack2)
	var crack3 := ColorRect.new()
	crack3.size = Vector2(6, 1)
	crack3.position = Vector2(-2, 4)
	crack3.color = Color(0.22, 0.2, 0.16, 0.6)
	crack3.rotation = 0.1
	b.add_child(crack3)

	var label := Label.new()
	label.text = "boulder"
	label.position = Vector2(-14, 16)
	label.add_theme_font_size_override("font_size", 7)
	label.modulate = Color(1, 1, 1, 0.3)
	b.add_child(label)

	b.position = Vector2(px * TILE_SIZE + TILE_SIZE / 2, py * TILE_SIZE - 24)
	add_child(b)
	_blocks.append(b)

func _add_pickups() -> void:
	var item_types := ["bottle_empty", "liquid_blue"]
	var table_x := 5
	var table_y := ROOM_H - 7

	for id in item_types:
		var p := DungeonPickup.new()
		p.item_id = id
		var offset := Vector2(item_types.find(id) * 36 - 18, -28)
		p.position = Vector2(table_x * TILE_SIZE + TILE_SIZE / 2, table_y * TILE_SIZE + TILE_SIZE / 2) + offset
		p.pickup_radius = 80.0
		add_child(p)

func _add_torches() -> void:
	var torch_positions := [
		Vector2(1, 4),
		Vector2(1, 9),
		Vector2(ROOM_W - 2, 4),
		Vector2(ROOM_W - 2, 9),
	]
	for tp in torch_positions:
		_build_torch(tp.x, tp.y)

func _build_torch(tx: int, ty: int) -> void:
	var torch := Node2D.new()
	torch.position = Vector2(tx * TILE_SIZE + TILE_SIZE / 2, ty * TILE_SIZE + TILE_SIZE / 2)

	var pole := ColorRect.new()
	pole.size = Vector2(4, 32)
	pole.position = Vector2(-2, -16)
	pole.color = Color(0.3, 0.22, 0.12)
	torch.add_child(pole)

	var head := ColorRect.new()
	head.size = Vector2(10, 10)
	head.position = Vector2(-5, -24)
	head.color = Color(0.2, 0.15, 0.08)
	torch.add_child(head)

	var flame := ColorRect.new()
	flame.size = Vector2(6, 10)
	flame.position = Vector2(-3, -32)
	flame.color = Color(1.0, 0.5, 0.1, 0.9)
	torch.add_child(flame)

	var glow := ColorRect.new()
	glow.size = Vector2(24, 24)
	glow.position = Vector2(-12, -34)
	glow.color = Color(1.0, 0.4, 0.05, 0.08)
	glow.mouse_filter = 2
	torch.add_child(glow)

	var flicker := create_tween().set_loops()
	flicker.tween_method(func(v: float): flame.color = Color(1.0, 0.5 + v * 0.1, 0.1 + v * 0.15, 0.85 + v * 0.15), 0.0, 1.0, 0.15)
	flicker.tween_method(func(v: float): flame.color = Color(1.0, 0.5 + v * 0.1, 0.1 + v * 0.15, 0.85 + v * 0.15), 1.0, 0.0, 0.15)
	flicker.tween_interval(0.05 + (tx % 3) * 0.02)

	if ClassDB.class_exists(&"LitPointLight2D"):
		var light := LitPointLight2D.new()
		light.energy = 0.6
		light.range = 150
		light.color = Color(1.0, 0.5, 0.15)
		light.position = Vector2(0, -26)
		torch.add_child(light)
		var light_flicker := create_tween().set_loops()
		light_flicker.tween_method(func(v: float): light.energy = 0.5 + v * 0.25, 0.0, 1.0, 0.12)
		light_flicker.tween_method(func(v: float): light.energy = 0.5 + v * 0.25, 1.0, 0.0, 0.12)
		light_flicker.tween_interval(0.04 + (ty % 3) * 0.015)

	torch.z_index = 2
	add_child(torch)

func _add_exit_door() -> void:
	var ex := ROOM_W - 3
	var ey := ROOM_H - 3

	_exit_door = Area2D.new()
	_exit_door.name = "ExitDoor"
	_exit_door.monitoring = false

	var door_shape := CollisionShape2D.new()
	var door_rect := RectangleShape2D.new()
	door_rect.size = Vector2(TILE_SIZE, TILE_SIZE * 2)
	door_shape.shape = door_rect
	_exit_door.add_child(door_shape)
	_exit_door.position = Vector2(ex * TILE_SIZE + TILE_SIZE / 2, ey * TILE_SIZE + TILE_SIZE)
	_exit_door.body_entered.connect(_on_exit_entered)
	_exit_door.collision_mask = 1
	add_child(_exit_door)

	_exit_closed_visual = ColorRect.new()
	_exit_closed_visual.size = Vector2(TILE_SIZE, TILE_SIZE * 2)
	_exit_closed_visual.position = Vector2(ex * TILE_SIZE, ey * TILE_SIZE)
	_exit_closed_visual.color = Color(0.3, 0.25, 0.2, 0.9)
	_exit_closed_visual.z_index = 1
	add_child(_exit_closed_visual)

	_exit_hcross = ColorRect.new()
	_exit_hcross.size = Vector2(TILE_SIZE, 4)
	_exit_hcross.position = Vector2(_exit_closed_visual.position.x, _exit_closed_visual.position.y + TILE_SIZE - 2)
	_exit_hcross.color = Color(0.5, 0.4, 0.3)
	add_child(_exit_hcross)
	_exit_vcross = ColorRect.new()
	_exit_vcross.size = Vector2(4, TILE_SIZE * 2)
	_exit_vcross.position = Vector2(_exit_closed_visual.position.x + TILE_SIZE / 2 - 2, _exit_closed_visual.position.y)
	_exit_vcross.color = Color(0.5, 0.4, 0.3)
	add_child(_exit_vcross)

	_exit_door_visual = ColorRect.new()
	_exit_door_visual.size = Vector2(TILE_SIZE, TILE_SIZE * 2)
	_exit_door_visual.position = Vector2(ex * TILE_SIZE, ey * TILE_SIZE)
	_exit_door_visual.color = Color(0.2, 0.15, 0.08, 0.0)
	_exit_door_visual.z_index = 1
	add_child(_exit_door_visual)

	var exit_label := Label.new()
	exit_label.text = "EXIT"
	exit_label.add_theme_font_size_override("font_size", 10)
	exit_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.3, 0.4))
	exit_label.position = Vector2(ex * TILE_SIZE + 14, ey * TILE_SIZE + TILE_SIZE - 6)
	exit_label.mouse_filter = 2
	add_child(exit_label)

func _open_exit() -> void:
	_exit_door.set_deferred("monitoring", true)
	_exit_door.set_deferred("monitorable", true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_exit_closed_visual, "color:a", 0.0, 0.8)
	tween.tween_property(_exit_hcross, "color:a", 0.0, 0.8)
	tween.tween_property(_exit_vcross, "color:a", 0.0, 0.8)

	_exit_door_visual.color = Color(0.3, 0.6, 0.2, 0.0)
	tween.tween_property(_exit_door_visual, "color", Color(0.3, 0.7, 0.2, 0.6), 0.8)
	tween.tween_property(_exit_door_visual, "color:a", 0.6, 0.8)

	var glow := ColorRect.new()
	glow.size = Vector2(TILE_SIZE * 2, TILE_SIZE * 2.5)
	glow.position = _exit_door_visual.position - Vector2(TILE_SIZE / 2, TILE_SIZE / 4)
	glow.color = Color(0.3, 0.8, 0.2, 0.0)
	glow.mouse_filter = 2
	glow.z_index = 0
	add_child(glow)
	tween.tween_property(glow, "color", Color(0.3, 0.8, 0.2, 0.15), 0.8)

func _on_exit_entered(body: Node) -> void:
	if body == _player and _door_open and not _exiting:
		_exit_cave()

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

	var tex := load("res://assets/sprites/player/charactertilesheet.png")
	if tex:
		var sf := SpriteFrames.new()
		sf.add_animation("walk")
		sf.set_animation_speed("walk", 8.0)
		sf.set_animation_loop("walk", true)
		for i in 4:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(0, i * 80, 40, 80)
			sf.add_frame("walk", at)
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = sf
		spr.play("walk")
		spr.centered = true
		spr.z_index = 1
		_player.add_child(spr)

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

func reveal() -> void:
	if GridTrans.is_available() and not GridTrans.is_busy():
		await GridTrans.reveal(0.8)
	_can_move = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_T and event.pressed and not event.echo and not _exiting and _door_open:
			_exit_cave()
		if event.keycode == KEY_I and event.pressed and not event.echo:
			var inv = get_node_or_null("/root/Game/InventoryLayer/InventoryUI")
			if inv and inv.has_method("toggle"):
				inv.toggle()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_do_punch()

func _physics_process(delta: float) -> void:
	if not _can_move or not _player:
		return

	var dir := Input.get_axis(&"move_left", &"move_right")
	if dir != 0:
		_last_facing = signf(dir)
		_player.scale.x = sign(dir) * abs(_player.scale.x)
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

	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.position = _player.position

	_update_held_item_position()
	if _is_punching and Time.get_ticks_msec() / 1000.0 - _punch_start > 0.15:
		_is_punching = false

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

static func _circle_poly(radius: float, points: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	arr.resize(points)
	for i in points:
		var a := TAU * float(i) / float(points)
		arr[i] = Vector2(cos(a) * radius, sin(a) * radius)
	return arr

func _exit_cave() -> void:
	if _exiting:
		return
	_exiting = true
	_can_move = false
	_cleanup_held_item()
	_restore_forest_sky()
	if GridTrans.is_available() and not GridTrans.is_busy():
		await GridTrans.cover(0.8)
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("exit_cave"):
		game.exit_cave()
	else:
		queue_free()
