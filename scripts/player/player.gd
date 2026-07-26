extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var acceleration: float = 1200.0
@export var friction: float = 800.0
@export var gravity: float = 1200.0

var is_carrying_betaal: bool = true
var is_stopped: bool = false
var speed_multiplier: float = 1.0
var _speed_boost_tween: Tween

var height_offset: float = 0.0
var vertical_vel: float = 0.0

var _is_crouching: bool = false
var _crouch_tween: Tween
var _normal_collision_height: float = 56.0
var _crouch_collision_height: float = 28.0

var _footstep_timer: float = 0.0
var _footstep_streams: Array = []
var _run_streams: Array = []

var sprint_energy: float = 1.0
const SPRINT_DEPLETE_RATE: float = 1.0 / 3.0
const SPRINT_RECHARGE_RATE: float = 1.0 / 2.0
const SPRINT_SPEED_BONUS: float = 0.5

signal sprint_energy_changed(value: float)

var _land_time := -1.0
var _was_on_ground := true

var _held_item: RigidBody2D
var _held_joint: PinJoint2D
var _shadow: Polygon2D
var _is_punching := false
var _punch_start := -1.0
var _punch_dir := Vector2.RIGHT

@onready var visual: Node2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	GameManager.state_changed.connect(_on_game_state_changed)
	GameInventory.selected_changed.connect(_on_selected_changed)
	_shadow = _create_player_shadow()
	add_child(_shadow)
	if not GameInventory.selected_item.is_empty():
		_update_held_item()

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
		visual.add_child(spr)

	for i in 4:
		var s = load("res://assets/audio/sfx/footstep/forestfs%d.wav" % (i + 1))
		if s:
			_footstep_streams.append(s)
		var r = load("res://assets/audio/sfx/run/runfs%d.wav" % (i + 1))
		if r:
			_run_streams.append(r)

func _on_game_state_changed(new_state: int) -> void:
	is_stopped = new_state != GameManager.GameState.PLAYING

func _physics_process(delta: float) -> void:
	var on_ground = height_offset <= 0.0 and vertical_vel <= 0.0
	if not on_ground:
		vertical_vel += gravity * delta
		height_offset += vertical_vel * delta
	if height_offset < 0.0:
		height_offset = 0.0
		vertical_vel = 0.0

	visual.position.y = -height_offset

	if is_stopped:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.y = move_toward(velocity.y, 0.0, friction * delta)
		move_and_slide()
		return

	var h_dir := Input.get_axis("move_left", "move_right")

	var crouch_held := Input.is_action_pressed("crouch")
	if crouch_held and on_ground and not _is_crouching:
		_is_crouching = true
		_set_collision_height(_crouch_collision_height)
	elif not crouch_held and _is_crouching:
		_is_crouching = false
		_set_collision_height(_normal_collision_height)

	var sprint_pressed = Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint")
	var wants_to_sprint = sprint_pressed and h_dir != 0 and sprint_energy > 0

	if wants_to_sprint:
		sprint_energy = max(sprint_energy - SPRINT_DEPLETE_RATE * delta, 0.0)
	else:
		sprint_energy = min(sprint_energy + SPRINT_RECHARGE_RATE * delta, 1.0)
	sprint_energy_changed.emit(sprint_energy)

	var effective_speed = speed * speed_multiplier
	if wants_to_sprint:
		effective_speed *= 1.0 + SPRINT_SPEED_BONUS
	if h_dir != 0:
		velocity.x = move_toward(velocity.x, h_dir * effective_speed, acceleration * delta)
		visual.scale.x = sign(h_dir) * abs(visual.scale.x)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	velocity.y = move_toward(velocity.y, 0.0, friction * delta)

	if Input.is_action_just_pressed("jump") and on_ground and not _is_crouching:
		vertical_vel = jump_velocity

	if not _was_on_ground and on_ground:
		_land_time = Time.get_ticks_msec() / 1000.0
	_was_on_ground = on_ground

	move_and_slide()

	var is_moving = h_dir != 0
	var is_running = (wants_to_sprint or speed_multiplier > 1.0) and not _is_crouching
	_update_held_item_position()
	if _is_punching and Time.get_ticks_msec() / 1000.0 - _punch_start > 0.15:
		_is_punching = false

	if is_moving:
		var interval = 0.3 if is_running else 0.5
		_footstep_timer += delta
		if _footstep_timer >= interval:
			_footstep_timer = 0.0
			var streams = _run_streams if is_running else _footstep_streams
			if not streams.is_empty():
				AudioManager.play_footstep(streams[randi() % streams.size()])
	else:
		_footstep_timer = 0.0

func _exit_tree() -> void:
	_cleanup_held_item()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_do_punch()

func activate_speed_boost(duration: float = 10.0) -> void:
	speed_multiplier = min(speed_multiplier + 0.1, 2.5)
	if _speed_boost_tween:
		_speed_boost_tween.kill()
	var decay_steps = (speed_multiplier - 1.0) / 0.1
	var decay_duration = decay_steps * 2.0
	_speed_boost_tween = create_tween()
	_speed_boost_tween.tween_interval(duration)
	_speed_boost_tween.tween_property(self, "speed_multiplier", 1.0, decay_duration)
	_speed_boost_tween.tween_callback(func(): _speed_boost_tween = null)

func _on_selected_changed(_item_id: String) -> void:
	_update_held_item()

func _create_player_shadow() -> Polygon2D:
	var shadow := Polygon2D.new()
	shadow.name = "PlayerShadow"
	var pts := PackedVector2Array()
	var seg := 24
	for i in seg:
		var a := TAU * i / seg
		pts.append(Vector2(cos(a) * 22.0, sin(a) * 9.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.position = Vector2(0, 56)
	shadow.z_index = -1
	_make_lit(shadow)
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
	if GameInventory.selected_item.is_empty():
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
	_held_item.collision_mask = collision_mask
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
	_held_item.add_collision_exception_with(self)

	var parent := get_parent()
	if not parent:
		_held_item.queue_free()
		_held_item = null
		return
	var hands_pos := global_position + Vector2(signf(visual.scale.x) * 16, -8)
	_held_item.global_position = hands_pos
	parent.add_child(_held_item)

	_held_joint = PinJoint2D.new()
	_held_joint.name = "HeldItemJoint"
	_held_joint.global_position = hands_pos
	parent.add_child(_held_joint)
	_held_joint.node_a = _held_item.get_path()
	_held_joint.node_b = get_path()

func _update_held_item_position() -> void:
	if not _held_item or not _held_joint:
		return
	_held_joint.global_position = global_position + Vector2(signf(visual.scale.x) * 16, -8)

func _do_punch() -> void:
	if is_stopped:
		return
	_is_punching = true
	_punch_start = Time.get_ticks_msec() / 1000.0
	_punch_dir = (get_global_mouse_position() - global_position).normalized()
	velocity += -_punch_dir * 150.0

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	query.shape = shape
	query.transform = Transform2D(0, global_position + _punch_dir * 35.0)
	query.collision_mask = collision_mask
	query.exclude = [self]

	for r in space_state.intersect_shape(query):
		var body: Variant = r.collider
		if body is RigidBody2D:
			body.apply_central_force(_punch_dir * 500.0)
			body.apply_torque(_punch_dir.x * 300.0)

func _make_lit(item: CanvasItem) -> void:
	var shader = load("res://addons/lit/shaders/lit_receiver_fast.gdshader")
	if not shader:
		return
	var mat = ShaderMaterial.new()
	mat.shader = shader
	item.material = mat

func _set_collision_height(h: float) -> void:
	if _crouch_tween and _crouch_tween.is_valid():
		_crouch_tween.kill()
	_crouch_tween = create_tween()
	_crouch_tween.tween_method(func(v: float): collision.shape.size.y = v; collision.position.y = -v * 0.5, collision.shape.size.y, h, 0.1)
	var vis_target = -h * 0.5
	_crouch_tween.parallel().tween_property(visual, "position:y", vis_target - height_offset, 0.1)
	if not _is_crouching:
		_crouch_tween.tween_callback(func(): visual.position.y = -height_offset)
