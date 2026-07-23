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

const VOID_Y: float = 600.0

func set_difficulty(d: int) -> void:
	difficulty = d

func _ready() -> void:
	extra_lives = GameManager.active_buffs.get("life", 0)
	jump_bonus = GameManager.active_buffs.get("jump", 0) * 0.3
	_build_level()
	_spawn_player()

func _build_level() -> void:
	var is_hard = difficulty == Difficulty.HARD
	var is_easy = difficulty == Difficulty.EASY

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.15) if is_hard else Color(0.12, 0.14, 0.2)
	bg.offset_left = -200
	bg.offset_top = -200
	bg.size = Vector2(1800, 800)
	add_child(bg)

	if is_hard:
		var shade = ColorRect.new()
		shade.color = Color(0.4, 0.0, 0.0, 0.3)
		shade.offset_left = -200
		shade.offset_top = -200
		shade.size = Vector2(1800, 800)
		add_child(shade)

	var ground_height = 40
	var ground_y = 498
	var gap_start = -1
	var gap_end = -1
	var spike_count = 0
	var platform_gaps = false
	match difficulty:
		Difficulty.EASY:
			spike_count = 0
			platform_gaps = false
		Difficulty.NORMAL:
			spike_count = 2
			platform_gaps = true
		Difficulty.HARD:
			spike_count = 5
			platform_gaps = true

	if platform_gaps and is_hard and randi() % 2 == 0:
		gap_start = 550
		gap_end = 850

	var ground_sections = []
	if gap_start > 0:
		ground_sections.append([0, gap_start])
		ground_sections.append([gap_end, 1400])
	else:
		ground_sections.append([0, 1400])

	for section in ground_sections:
		var gx = section[0]
		var gw = section[1] - gx
		var ground = ColorRect.new()
		ground.color = Color(0.2, 0.5, 0.15) if is_easy else (Color(0.3, 0.2, 0.1) if is_hard else Color(0.25, 0.35, 0.12))
		ground.offset_left = gx
		ground.offset_top = ground_y
		ground.size = Vector2(gw, ground_height)
		add_child(ground)
		var ground_body = StaticBody2D.new()
		var ground_collision = CollisionShape2D.new()
		var ground_shape = RectangleShape2D.new()
		ground_shape.size = Vector2(gw, ground_height)
		ground_collision.shape = ground_shape
		ground_body.position = Vector2(gx + gw / 2, ground_y + ground_height / 2)
		ground_body.add_child(ground_collision)
		add_child(ground_body)

	if gap_start > 0:
		var gap_rect = ColorRect.new()
		gap_rect.color = Color(0.05, 0.0, 0.05)
		gap_rect.offset_left = gap_start
		gap_rect.offset_top = ground_y
		gap_rect.size = Vector2(gap_end - gap_start, ground_height)
		add_child(gap_rect)

	var platform_y = ground_y - 80
	var platform_x = 200
	var platform_width = 100
	for i in range(3):
		var px = platform_x + i * 350
		var pw = platform_width
		if is_easy:
			pw = 150
		var plat = ColorRect.new()
		plat.color = Color(0.4, 0.3, 0.15)
		plat.offset_left = px
		plat.offset_top = platform_y
		plat.size = Vector2(pw, 16)
		add_child(plat)
		var plat_body = StaticBody2D.new()
		var plat_coll = CollisionShape2D.new()
		var plat_shape = RectangleShape2D.new()
		plat_shape.size = Vector2(pw, 16)
		plat_coll.shape = plat_shape
		plat_body.position = Vector2(px + pw / 2, platform_y + 8)
		plat_body.add_child(plat_coll)
		add_child(plat_body)
		platform_x += pw + 80

	for i in range(spike_count):
		var sx = 250 + i * 200
		if is_hard and i >= 3:
			sx = 400 + (i - 3) * 150
		var spike_body = StaticBody2D.new()
		var spike_coll = CollisionShape2D.new()
		var spike_shape = RectangleShape2D.new()
		spike_shape.size = Vector2(16, 12)
		spike_coll.shape = spike_shape
		spike_body.position = Vector2(sx + 10, ground_y - 10)
		spike_body.add_child(spike_coll)
		spike_body.set_meta("is_spike", true)
		add_child(spike_body)

		var spike_poly = Polygon2D.new()
		spike_poly.polygon = PackedVector2Array([
			Vector2(0, 22), Vector2(10, 0), Vector2(20, 22)
		])
		spike_poly.color = Color(0.9, 0.15, 0.15)
		spike_poly.position = Vector2(sx, ground_y - 22)
		add_child(spike_poly)

		var spike_outline = Polygon2D.new()
		spike_outline.polygon = PackedVector2Array([
			Vector2(0, 22), Vector2(10, 0), Vector2(20, 22)
		])
		spike_outline.color = Color(0.1, 0.0, 0.0)
		spike_outline.position = Vector2(sx, ground_y - 22)
		spike_outline.scale = Vector2(1.2, 1.2)
		spike_outline.z_index = -1
		add_child(spike_outline)

	var flag_x = 1250
	var flag_pole = ColorRect.new()
	flag_pole.color = Color(0.6, 0.5, 0.3)
	flag_pole.offset_left = flag_x
	flag_pole.offset_top = ground_y - 100
	flag_pole.size = Vector2(6, 100)
	add_child(flag_pole)
	var flag_tri = ColorRect.new()
	flag_tri.color = Color(0.9, 0.1, 0.1)
	flag_tri.offset_left = flag_x + 6
	flag_tri.offset_top = ground_y - 100
	flag_tri.size = Vector2(40, 25)
	add_child(flag_tri)
	var flag_body = Area2D.new()
	var flag_coll = CollisionShape2D.new()
	var flag_shape = RectangleShape2D.new()
	flag_shape.size = Vector2(50, 120)
	flag_coll.shape = flag_shape
	flag_body.position = Vector2(flag_x + 25, ground_y - 50)
	flag_body.add_child(flag_coll)
	flag_body.body_entered.connect(_on_flag_reached.bind(flag_body))
	add_child(flag_body)

	var finish_label = Label.new()
	finish_label.text = "FLAG"
	finish_label.add_theme_font_size_override("font_size", 20)
	finish_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	finish_label.position = Vector2(flag_x - 10, ground_y - 140)
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

	_player.position = Vector2(50, 400)
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

	var gravity = 2000.0
	var jump_velocity = -750.0 - (jump_bonus * 500.0)
	var speed = 350.0
	var sprint_mult = 1.5

	_player.velocity.y += gravity * delta

	var h_dir = Input.get_axis("move_left", "move_right")
	var sprint_pressed = Input.is_key_pressed(KEY_SHIFT)
	var effective_speed = speed * (sprint_mult if sprint_pressed else 1.0)
	_player.velocity.x = h_dir * effective_speed

	if Input.is_action_just_pressed("jump") and _player.is_on_floor():
		_player.velocity.y = jump_velocity

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
		_player.position = Vector2(50, 400)
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
