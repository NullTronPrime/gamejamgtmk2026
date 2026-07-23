extends Node2D

signal platformer_completed

enum Difficulty { EASY, NORMAL, HARD }

var difficulty: int = Difficulty.NORMAL
var _player: CharacterBody2D
var _completed: bool = false
var _camera: Camera2D
var _dead: bool = false

var extra_lives: int = 0
var jump_bonus: float = 0.0

const GRID := 48
const GROUND_Y := 480
const VOID_Y: float = 800.0

const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.15
const RISE_GRAVITY := 2800.0
const FALL_GRAVITY := 3800.0
const MAX_FALL_SPEED := 1200.0
const JUMP_VELOCITY := -950.0
const SPEED := 400.0
const SPRINT_MULT := 1.5
const GROUND_ACCEL := 2000.0
const AIR_ACCEL := 800.0
const FRICTION := 1200.0

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

func set_difficulty(d: int) -> void:
	difficulty = d

func _snap(v: float) -> float:
	return round(v / GRID) * GRID

func _ready() -> void:
	extra_lives = GameManager.active_buffs.get("life", 0)
	jump_bonus = GameManager.active_buffs.get("jump", 0) * 0.3
	_build_level()
	_spawn_player()

func _build_level() -> void:
	var is_hard = difficulty == Difficulty.HARD
	var bg_layer = CanvasLayer.new()
	bg_layer.layer = -1
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.15) if is_hard else Color(0.12, 0.14, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	add_child(bg_layer)

	if is_hard:
		var shade_layer = CanvasLayer.new()
		shade_layer.layer = 0
		var shade = ColorRect.new()
		shade.color = Color(0.4, 0.0, 0.0, 0.3)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade_layer.add_child(shade)
		add_child(shade_layer)

	var ground_segments: Array
	var platform_data: Array
	var spike_cells: Array
	var flag_cell: int

	match difficulty:
		Difficulty.EASY:
			ground_segments = [[0, 28]]
			platform_data = [[5, 7, 3], [13, 6, 3], [21, 7, 3]]
			spike_cells = []
			flag_cell = 26
		Difficulty.NORMAL:
			ground_segments = [[0, 10], [15, 28]]
			platform_data = [[4, 7, 2], [11, 6, 2], [18, 7, 2], [23, 8, 2]]
			spike_cells = [7, 22]
			flag_cell = 26
		Difficulty.HARD:
			ground_segments = [[0, 6], [11, 16], [21, 28]]
			platform_data = [[3, 7, 2], [8, 6, 2], [13, 5, 2], [18, 6, 2], [24, 6, 2]]
			spike_cells = [7, 9, 17, 19, 24]
			flag_cell = 27

	for seg in ground_segments:
		var gx = _snap(float(seg[0] * GRID))
		var gw = _snap(float((seg[1] - seg[0]) * GRID))
		var is_easy = difficulty == Difficulty.EASY
		var ground_col = Color(0.2, 0.5, 0.15) if is_easy else (Color(0.3, 0.2, 0.1) if is_hard else Color(0.25, 0.35, 0.12))
		var ground_vis = ColorRect.new()
		ground_vis.color = ground_col
		ground_vis.offset_left = gx
		ground_vis.offset_top = GROUND_Y
		ground_vis.size = Vector2(gw, GRID)
		add_child(ground_vis)
		var ground_body = StaticBody2D.new()
		var ground_coll = CollisionShape2D.new()
		var ground_shape = RectangleShape2D.new()
		ground_shape.size = Vector2(gw, GRID)
		ground_coll.shape = ground_shape
		ground_body.position = Vector2(gx + gw / 2, GROUND_Y + GRID / 2)
		ground_body.add_child(ground_coll)
		add_child(ground_body)

	for p in platform_data:
		var px = _snap(float(p[0] * GRID))
		var py = _snap(float(p[1] * GRID))
		var pw = _snap(float(p[2] * GRID))
		var ph = 16.0
		var plat_vis = ColorRect.new()
		plat_vis.color = Color(0.4, 0.3, 0.15)
		plat_vis.offset_left = px
		plat_vis.offset_top = py
		plat_vis.size = Vector2(pw, ph)
		add_child(plat_vis)
		var plat_body = StaticBody2D.new()
		var plat_coll = CollisionShape2D.new()
		var plat_shape = RectangleShape2D.new()
		plat_shape.size = Vector2(pw, ph)
		plat_coll.shape = plat_shape
		plat_body.position = Vector2(px + pw / 2, py + ph / 2)
		plat_body.add_child(plat_coll)
		add_child(plat_body)

	for sc in spike_cells:
		var sx = _snap(float(sc * GRID))
		var spike_body = StaticBody2D.new()
		var spike_coll = CollisionShape2D.new()
		var spike_shape = RectangleShape2D.new()
		spike_shape.size = Vector2(20, 22)
		spike_coll.shape = spike_shape
		spike_body.position = Vector2(sx + 10, GROUND_Y - 11)
		spike_body.add_child(spike_coll)
		spike_body.set_meta("is_spike", true)
		add_child(spike_body)
		var spike_poly = Polygon2D.new()
		spike_poly.polygon = PackedVector2Array([
			Vector2(0, 22), Vector2(10, 0), Vector2(20, 22)
		])
		spike_poly.color = Color(0.9, 0.15, 0.15)
		spike_poly.position = Vector2(sx, GROUND_Y - 22)
		add_child(spike_poly)
		var spike_outline = Polygon2D.new()
		spike_outline.polygon = PackedVector2Array([
			Vector2(0, 22), Vector2(10, 0), Vector2(20, 22)
		])
		spike_outline.color = Color(0.1, 0.0, 0.0)
		spike_outline.position = Vector2(sx, GROUND_Y - 22)
		spike_outline.scale = Vector2(1.2, 1.2)
		spike_outline.z_index = -1
		add_child(spike_outline)

	var fx = _snap(float(flag_cell * GRID))
	var flag_pole = ColorRect.new()
	flag_pole.color = Color(0.6, 0.5, 0.3)
	flag_pole.offset_left = fx
	flag_pole.offset_top = GROUND_Y - 100
	flag_pole.size = Vector2(6, 100)
	add_child(flag_pole)
	var flag_tri = ColorRect.new()
	flag_tri.color = Color(0.9, 0.1, 0.1)
	flag_tri.offset_left = fx + 6
	flag_tri.offset_top = GROUND_Y - 100
	flag_tri.size = Vector2(40, 25)
	add_child(flag_tri)
	var flag_body = Area2D.new()
	var flag_coll = CollisionShape2D.new()
	var flag_shape = RectangleShape2D.new()
	flag_shape.size = Vector2(50, 120)
	flag_coll.shape = flag_shape
	flag_body.position = Vector2(fx + 25, GROUND_Y - 50)
	flag_body.add_child(flag_coll)
	flag_body.body_entered.connect(_on_flag_reached.bind(flag_body))
	add_child(flag_body)
	var finish_label = Label.new()
	finish_label.text = "FLAG"
	finish_label.add_theme_font_size_override("font_size", 20)
	finish_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	finish_label.position = Vector2(fx - 10, GROUND_Y - 140)
	add_child(finish_label)

func _spawn_player() -> void:
	_player = CharacterBody2D.new()
	_player.name = "PlatformPlayer"
	_player.up_direction = Vector2(0, -1)
	_player.floor_stop_on_slope = true
	_player.floor_max_angle = deg_to_rad(45)
	_player.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	add_child(_player)
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 40)
	collision.shape = shape
	_player.add_child(collision)
	_player.collision_layer = 1
	_player.collision_mask = 1

	var visual = ColorRect.new()
	visual.color = Color(1.0, 0.95, 0.3)
	visual.size = Vector2(24, 60)
	visual.position = Vector2(-12, -40)
	visual.z_index = -1
	_player.add_child(visual)

	var outline = ColorRect.new()
	outline.color = Color(0.0, 0.0, 0.0, 0.8)
	outline.size = Vector2(28, 64)
	outline.position = Vector2(-14, -42)
	outline.z_index = -2
	_player.add_child(outline)

	var eye = ColorRect.new()
	eye.color = Color(1.0, 1.0, 1.0)
	eye.size = Vector2(4, 4)
	eye.position = Vector2(-2, -10)
	_player.add_child(eye)

	_player.position = Vector2(_snap(48), GROUND_Y - GRID * 2)
	_player.set_meta("is_player", true)
	_player.velocity = Vector2(0, 50)

	_camera = Camera2D.new()
	_camera.enabled = true
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_player.add_child(_camera)

func _physics_process(delta: float) -> void:
	if _completed or not _player or _dead:
		return

	if _player.position.y > VOID_Y:
		_die()
		return

	var on_floor = _player.is_on_floor()

	if on_floor:
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)

	if Input.is_action_just_released("jump") and _player.velocity.y < 0:
		_player.velocity.y *= 0.5

	if _player.velocity.y < 0:
		_player.velocity.y += RISE_GRAVITY * delta
	else:
		_player.velocity.y += FALL_GRAVITY * delta

	_player.velocity.y = min(_player.velocity.y, MAX_FALL_SPEED)

	var h_dir = Input.get_axis("move_left", "move_right")
	var sprint_pressed = Input.is_key_pressed(KEY_SHIFT)
	var effective_speed = SPEED * (SPRINT_MULT if sprint_pressed else 1.0)
	var accel = GROUND_ACCEL if on_floor else AIR_ACCEL

	if h_dir != 0:
		_player.velocity.x = move_toward(_player.velocity.x, h_dir * effective_speed, accel * delta)
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, FRICTION * delta)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		var jump_vel = JUMP_VELOCITY - (jump_bonus * 500.0)
		_player.velocity.y = jump_vel
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	_player.move_and_slide()

	for i in _player.get_slide_collision_count():
		var col = _player.get_slide_collision(i)
		var hit = col.get_collider()
		if hit and hit.has_meta("is_spike"):
			_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	if _player:
		_player.velocity = Vector2.ZERO
		_player.set_physics_process(false)
	GameManager.run_timer -= 20.0
	if GameManager.run_timer < 0:
		GameManager.run_timer = 0
	if get_tree().root.has_node("Transition"):
		await Transition.cover("fade", 0.4)
	_respawn()
	if get_tree().root.has_node("Transition"):
		await Transition.reveal("fade", 0.4)

func _respawn() -> void:
	_dead = false
	if _player:
		_player.position = Vector2(_snap(48), GROUND_Y - GRID * 2)
		_player.velocity = Vector2(0, 50)
		_player.set_physics_process(true)

func _on_flag_reached(body: Node, _flag_area: Area2D) -> void:
	if _completed:
		return
	if not body.has_meta("is_player"):
		return
	_completed = true
	if _player:
		_player.velocity = Vector2.ZERO
		_player.set_physics_process(false)
	await get_tree().create_timer(0.5).timeout
	platformer_completed.emit()
