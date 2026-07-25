extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")
const HumanoidRig := preload("res://scripts/shared/humanoid_rig.gd")

const TILE_SIZE := 64
const ROOM_W := 20
const ROOM_H := 9
const GRAVITY := 1400.0
const JUMP_VEL := -480.0
const MOVE_SPEED := 180.0
const CLIMB_SPEED := 120.0
const PUSH_FORCE := 200.0
const BLOCK_LAYER := 2
const WALL_LAYER := 1

enum TileType { EMPTY, WALL, FLOOR, PLATFORM, LADDER }

var _player: CharacterBody2D
var _can_move := false
var _grid: Array[Array]
var _rng: RandomNumberGenerator
var _player_spawn: Vector2i
var _blocks: Array[RigidBody2D] = []
var _pickups: Array[DungeonPickup] = []
var _inventory: DungeonInventory
var _sky: CanvasLayer
var _on_ladder := false
var _climbing := false
var _exiting := false
var _forest_layers: Array[CanvasLayer] = []

func _ready() -> void:
	_hide_forest_sky()
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash("dungeon_%d" % randi())
	_build_skybox()
	_generate_room()
	_spawn_player()
	_setup_camera()
	_inventory = $InventoryUI
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
	_sky = CanvasLayer.new()
	_sky.layer = -10
	add_child(_sky)

	var tex := preload("res://assets/dungeon/sky_bg.png")
	var vp := get_viewport_rect()
	var bg := TextureRect.new()
	bg.texture = tex
	bg.size = vp.size * 2
	bg.position = -bg.size * 0.25
	bg.mouse_filter = 2
	_sky.add_child(bg)

func _generate_room() -> void:
	_grid = []
	for x in ROOM_W:
		_grid.append([])
		for y in ROOM_H:
			_grid[x].append(TileType.EMPTY)

	_carve_room()
	_add_tiles()
	_add_ladder()
	_add_blocks()
	_add_pickups()

func _carve_room() -> void:
	for x in ROOM_W:
		_grid[x][ROOM_H - 1] = TileType.FLOOR
		_grid[x][ROOM_H - 2] = TileType.FLOOR

	for x in ROOM_W:
		_grid[x][0] = TileType.WALL

	for y in ROOM_H:
		_grid[0][y] = TileType.WALL
		_grid[ROOM_W - 1][y] = TileType.WALL

	var pillar_count := _rng.randi_range(2, 4)
	for i in pillar_count:
		var px := _rng.randi_range(3, ROOM_W - 4)
		var py := _rng.randi_range(ROOM_H - 6, ROOM_H - 3)
		_grid[px][py] = TileType.WALL
		_grid[px + 1][py] = TileType.WALL

	var plat_count := _rng.randi_range(1, 3)
	for i in plat_count:
		var px := _rng.randi_range(2, ROOM_W - 5)
		var py := _rng.randi_range(ROOM_H - 7, ROOM_H - 4)
		for w in _rng.randi_range(3, 5):
			if px + w < ROOM_W - 1:
				_grid[px + w][py] = TileType.PLATFORM

	_player_spawn = Vector2i(2, ROOM_H - 3)

## Blob autotile — each 32×32 sub-tile checks its own 4 neighbours
## in a virtual grid where each 64×64 cell is 2×2 sub-tiles.
func _vx(x: int, dx: int) -> int:
	return x * 2 + dx

func _vy(y: int, dy: int) -> int:
	return y * 2 + dy

func _vtile(vx: int, vy: int, t: TileType) -> bool:
	var gx := vx / 2
	var gy := vy / 2
	if gx < 0 or gx >= ROOM_W or gy < 0 or gy >= ROOM_H:
		return false
	return _grid[gx][gy] == t

func _vbitmask(vx: int, vy: int, t: TileType) -> int:
	var n := 1 if _vtile(vx, vy - 1, t) else 0
	var s := 1 if _vtile(vx, vy + 1, t) else 0
	var w := 1 if _vtile(vx - 1, vy, t) else 0
	var e := 1 if _vtile(vx + 1, vy, t) else 0
	return n + s * 2 + w * 4 + e * 8

## Row-0 tile (grass surface) for a given bitmask.
## vparity = (vx + vy) & 1 for tiling alternation.
func _grass_top(bm: int, vparity: int) -> Vector2i:
	match bm:
		0:  return Vector2i(0, 0)
		1:  return Vector2i(2, 0)
		2:  return Vector2i(5, 0)
		3:  return Vector2i(4, 0)
		4:  return Vector2i(0, 0)
		5:  return Vector2i(0, 0)
		6:  return Vector2i(0, 0)
		7:  return Vector2i(0, 0)
		8:  return Vector2i(1, 0)
		9:  return Vector2i(1, 0)
		10: return Vector2i(1, 0)
		11: return Vector2i(1, 0)
		12: return Vector2i(vparity, 0)
		13: return Vector2i(vparity, 0)
		14: return Vector2i(vparity, 0)
		15: return Vector2i(4, 0)
		_:  return Vector2i(0, 0)

## Row-1 tile (dirt body) for a given bitmask.
## vparity = (vx + vy) & 1 for tiling alternation.
func _dirt_body(bm: int, vparity: int) -> Vector2i:
	match bm:
		0:  return Vector2i(0, 1)
		1:  return Vector2i(0, 1)
		2:  return Vector2i(5, 1)
		3:  return Vector2i(4, 1)
		4:  return Vector2i(2, 1)
		5:  return Vector2i(2, 1)
		6:  return Vector2i(5, 1)
		7:  return Vector2i(5, 1)
		8:  return Vector2i(5, 1)
		9:  return Vector2i(5, 1)
		10: return Vector2i(5, 1)
		11: return Vector2i(6, 1)
		12: return Vector2i(4, 1)
		13: return Vector2i(vparity, 1)
		14: return Vector2i(vparity, 1)
		15: return Vector2i(4, 1)
		_:   return Vector2i(4, 1)

## Background cave tile column for wall/platform bitmask.
func _bg_column(bitmask: int) -> int:
	var n := bitmask & 1
	var s := (bitmask >> 1) & 1
	var w := (bitmask >> 2) & 1
	var e := (bitmask >> 3) & 1
	var c := n + s + w + e
	if c == 0:
		return 0
	if c == 4:
		return 5
	if c == 3:
		return 4
	if (n and s) or (w and e):
		return 2
	return 3

func _add_tiles() -> void:
	var tex := preload("res://assets/dungeon/fore_jungle_grass.png")
	var ts := 32.0
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

			var vx0 := _vx(x, 0)
			var vy0 := _vy(y, 0)

			match t:
				TileType.FLOOR:
					for dy in 2:
						for dx in 2:
							var vx := vx0 + dx
							var vy := vy0 + dy
							var bm := _vbitmask(vx, vy, TileType.FLOOR)
							var vp := (vx + vy) & 1
							var r := _grass_top(bm, vp) if dy == 0 else _dirt_body(bm, vp)
							var sp := Sprite2D.new()
							sp.texture = tex
							sp.region_enabled = true
							sp.region_rect = Rect2(r.x * ts, r.y * ts, ts, ts)
							sp.texture_filter = 0
							sp.position = Vector2(x * TILE_SIZE + dx * ts + ts * 0.5, y * TILE_SIZE + dy * ts + ts * 0.5)
							sp.z_index = -1
							add_child(sp)
				TileType.WALL, TileType.PLATFORM:
					for dy in 2:
						var vy := vy0 + dy
						var bm := _vbitmask(vx0, vy, t)
						var col := _bg_column(bm)
						var sp := Sprite2D.new()
						sp.texture = tex
						sp.region_enabled = true
						sp.region_rect = Rect2(col * ts, (2 + dy) * ts, ts, ts)
						sp.texture_filter = 0
						sp.position = Vector2(x * TILE_SIZE + hs, y * TILE_SIZE + dy * ts + ts * 0.5)
						sp.z_index = -1
						add_child(sp)

func _add_ladder() -> void:
	var lx := _rng.randi_range(5, ROOM_W - 6)
	var top_y := _rng.randi_range(3, ROOM_H - 6)
	var bot_y := ROOM_H - 2

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
			rail.color = Color(0.5, 0.4, 0.25)
			rail.z_index = -1
			add_child(rail)

		for rung_y in range(0, TILE_SIZE, 16):
			var rung := ColorRect.new()
			rung.size = Vector2(TILE_SIZE * 2 - 8, 3)
			rung.position = Vector2(cx0 + 4, cy + rung_y)
			rung.color = Color(0.45, 0.35, 0.2)
			rung.z_index = -1
			add_child(rung)

	var ladder_area := Area2D.new()
	ladder_area.name = "LadderArea"
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

func _add_blocks() -> void:
	var count := _rng.randi_range(1, 3)
	var placed := 0
	var attempts := 0
	while placed < count and attempts < 30:
		attempts += 1
		var px := _rng.randi_range(2, ROOM_W - 3)
		var py := ROOM_H - 3
		if _grid[px][py] != TileType.FLOOR and _grid[px][py + 1] != TileType.FLOOR:
			continue
		if abs(px - _player_spawn.x) < 3:
			continue

		var mass := _rng.randf_range(1.0, 5.0)

		var b := RigidBody2D.new()
		b.name = "PushBlock_%d" % placed
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

		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(48, 48)
		shape.shape = box
		b.add_child(shape)

		var sprite := ColorRect.new()
		sprite.size = Vector2(48, 48)
		sprite.position = Vector2(-24, -24)
		var shade := 0.55 - mass * 0.04
		sprite.color = Color(shade, shade * 0.85, shade * 0.7)
		b.add_child(sprite)

		var inset := ColorRect.new()
		inset.size = Vector2(36, 36)
		inset.position = Vector2(-18, -18)
		inset.color = Color(shade * 0.8, shade * 0.68, shade * 0.56)
		b.add_child(inset)

		var mass_label := Label.new()
		mass_label.text = "%.1f kg" % mass
		mass_label.position = Vector2(-16, -6)
		mass_label.add_theme_font_size_override("font_size", 10)
		mass_label.modulate = Color(1, 1, 1, 0.6)
		b.add_child(mass_label)

		b.position = Vector2(px * TILE_SIZE + TILE_SIZE / 2, py * TILE_SIZE + TILE_SIZE / 2 - 16)
		add_child(b)
		_blocks.append(b)
		placed += 1

func _add_pickups() -> void:
	var item_types := ["bottle_empty", "liquid_blue"]
	var px := _rng.randi_range(8, ROOM_W - 4)
	var py := ROOM_H - 3
	for id in item_types:
		var p := DungeonPickup.new()
		p.item_id = id
		var offset := Vector2(item_types.find(id) * 40 - 20, -20)
		p.position = Vector2(px * TILE_SIZE + TILE_SIZE / 2, py * TILE_SIZE + TILE_SIZE / 2) + offset
		p.pickup_radius = 80.0
		add_child(p)
		_pickups.append(p)

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

	_player.position = Vector2(_player_spawn.x * TILE_SIZE, _player_spawn.y * TILE_SIZE)
	add_child(_player)

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_T and event.pressed and not event.echo and not _exiting:
			_exit_dungeon()
		if event.keycode == KEY_I and event.pressed and not event.echo:
			if _inventory:
				_inventory.toggle()

func _physics_process(delta: float) -> void:
	if not _can_move or not _player:
		return

	var dir := Input.get_axis(&"move_left", &"move_right")
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

		_player.velocity.x = dir * MOVE_SPEED
		_player.velocity.y += GRAVITY * delta

		if _on_ladder and abs(vert) > 0.1 and _player.velocity.y > 0:
			_player.velocity.y = 0

		if jump:
			_player.velocity.y = JUMP_VEL

		_player.move_and_slide()
		_push_rigid_bodies()
		_update_rig_animation(dir, on_floor, false)

	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.position = _player.position

func _push_rigid_bodies() -> void:
	for i in _player.get_slide_collision_count():
		var col := _player.get_slide_collision(i)
		var body := col.get_collider()
		if body is RigidBody2D:
			var push_dir := col.get_normal() * -1.0
			var speed_ratio := _player.velocity.length() / MOVE_SPEED
			body.apply_central_force(push_dir * PUSH_FORCE * speed_ratio)

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

func _exit_dungeon() -> void:
	if _exiting:
		return
	_exiting = true
	_can_move = false
	_restore_forest_sky()
	if GridTrans.is_available() and not GridTrans.is_busy():
		await GridTrans.cover(0.8)
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("exit_dungeon"):
		game.exit_dungeon()
	else:
		queue_free()
