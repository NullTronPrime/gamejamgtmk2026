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
@onready var betaal: Node2D = $Visual/BetaalPosition/Betaal
@onready var collision: CollisionShape2D = $CollisionShape2D

# ---- rig / walk-cycle state ----
var _rig: Dictionary = {}
var _walk_phase: float = 0.0
var _walk_blend: float = 0.0
const WALK_SWING_DEG: float = 32.0
const WALK_CYCLE_SPEED: float = 9.0

func _ready() -> void:
	GameManager.state_changed.connect(_on_game_state_changed)
	GameInventory.selected_changed.connect(_on_selected_changed)
	$Visual/BetaalPosition.position = Vector2(0, 0)
	_shadow = _create_player_shadow()
	add_child(_shadow)
	if not GameInventory.selected_item.is_empty():
		_update_held_item()

	# Neutral "placeholder" stick-figure body for Vikram (Betaal, the one being
	# carried, is the blue figure - see betaal.gd).
	_rig = HumanoidRig.build(visual, Color(0.78, 0.78, 0.8), Color(0.85, 0.7, 0.55))
	for p in _rig["polygons"]:
		_make_lit(p)

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
		_animate_rig(delta, false, on_ground)
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
	_animate_rig(delta, is_moving, on_ground, is_running)

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

func _animate_rig(delta: float, is_moving: bool, on_ground: bool, is_running: bool = false) -> void:
	if _rig.is_empty():
		return

	if _is_crouching:
		var crouch_factor = 1.0 - collision.shape.size.y / _normal_collision_height
		var tuck = deg_to_rad(45.0 * crouch_factor)
		_rig["l_hip"].rotation = lerp(_rig["l_hip"].rotation, tuck, delta * 12.0)
		_rig["r_hip"].rotation = lerp(_rig["r_hip"].rotation, tuck, delta * 12.0)
		_rig["l_knee"].rotation = lerp(_rig["l_knee"].rotation, deg_to_rad(60.0 * crouch_factor), delta * 12.0)
		_rig["r_knee"].rotation = lerp(_rig["r_knee"].rotation, deg_to_rad(60.0 * crouch_factor), delta * 12.0)
		_rig["torso"].rotation = lerp(_rig["torso"].rotation, deg_to_rad(10.0 * crouch_factor), delta * 12.0)
		_rig["head"].rotation = lerp(_rig["head"].rotation, deg_to_rad(-5.0 * crouch_factor), delta * 12.0)
		if is_moving:
			_walk_phase += delta * WALK_CYCLE_SPEED * 0.5
			var c_swing = sin(_walk_phase) * deg_to_rad(15.0 * crouch_factor)
			_rig["l_shoulder"].rotation = -c_swing
			_rig["r_shoulder"].rotation = c_swing
		return

	if _is_punching:
		var now: float = Time.get_ticks_msec() / 1000.0
		var elapsed: float = now - _punch_start
		if elapsed < 0.15:
			var p: float = min(elapsed / 0.1, 1.0)
			var f: float = signf(visual.scale.x)
			var forward := Vector2(f, 0)
			var rel_angle := forward.angle_to(_punch_dir) if _punch_dir.length_squared() > 0 else 0.0
			_rig["torso"].rotation = -0.15 * f * p + clamp(rel_angle * 0.2, -0.3, 0.3) * p
			var s_key: String = "l_shoulder" if f > 0 else "r_shoulder"
			var e_key: String = "l_elbow" if f > 0 else "r_elbow"
			_rig[s_key].rotation = 0.8 * p * f
			_rig[e_key].rotation = -0.3 * p
		return

	var target_blend = 1.0 if (is_moving and on_ground) else 0.0
	_walk_blend = move_toward(_walk_blend, target_blend, delta * 6.0)

	if is_moving and on_ground:
		_walk_phase += delta * WALK_CYCLE_SPEED * (1.4 if is_running else 1.0)

	var swing = sin(_walk_phase) * deg_to_rad(WALK_SWING_DEG) * _walk_blend
	var lift_l = max(0.0, -sin(_walk_phase)) * deg_to_rad(40.0) * _walk_blend
	var lift_r = max(0.0, sin(_walk_phase)) * deg_to_rad(40.0) * _walk_blend

	_rig["l_hip"].rotation = swing
	_rig["r_hip"].rotation = -swing
	_rig["l_knee"].rotation = lift_l
	_rig["r_knee"].rotation = lift_r

	_rig["l_shoulder"].rotation = -swing * 0.6
	_rig["r_shoulder"].rotation = swing * 0.6
	_rig["l_elbow"].rotation = abs(swing) * 0.25
	_rig["r_elbow"].rotation = abs(swing) * 0.25

	if not on_ground:
		var tuck = deg_to_rad(18.0)
		_rig["l_hip"].rotation = lerp(_rig["l_hip"].rotation, tuck, delta * 10.0)
		_rig["r_hip"].rotation = lerp(_rig["r_hip"].rotation, tuck, delta * 10.0)
		_rig["l_knee"].rotation = lerp(_rig["l_knee"].rotation, deg_to_rad(35.0), delta * 10.0)
		_rig["r_knee"].rotation = lerp(_rig["r_knee"].rotation, deg_to_rad(35.0), delta * 10.0)
		var shoulder_swing := deg_to_rad(40.0) if vertical_vel < 0 else deg_to_rad(15.0)
		_rig["l_shoulder"].rotation = lerp(_rig["l_shoulder"].rotation, -shoulder_swing, delta * 8.0)
		_rig["r_shoulder"].rotation = lerp(_rig["r_shoulder"].rotation, shoulder_swing, delta * 8.0)

	if on_ground and _land_time > 0.0 and Time.get_ticks_msec() / 1000.0 - _land_time < 0.15:
		var land_factor: float = (Time.get_ticks_msec() / 1000.0 - _land_time) / 0.15
		var squat: float = lerp(0.4, 0.0, land_factor)
		_rig["l_knee"].rotation = lerp(_rig["l_knee"].rotation, squat, delta * 15.0)
		_rig["r_knee"].rotation = lerp(_rig["r_knee"].rotation, squat, delta * 15.0)
		_rig["torso"].rotation = lerp(_rig["torso"].rotation, -squat * 0.3, delta * 15.0)

	if _walk_blend < 0.05:
		var bob = sin(Time.get_ticks_msec() / 1000.0 * 1.6) * 0.5
		_rig["torso"].position.y = bob
		_rig["head"].position.y = bob
	else:
		_rig["torso"].position.y = 0.0
		_rig["head"].position.y = 0.0

func _set_collision_height(h: float) -> void:
	if _crouch_tween and _crouch_tween.is_valid():
		_crouch_tween.kill()
	_crouch_tween = create_tween()
	_crouch_tween.tween_method(func(v: float): collision.shape.size.y = v; collision.position.y = -v * 0.5, collision.shape.size.y, h, 0.1)
	var vis_target = -h * 0.5
	_crouch_tween.parallel().tween_property(visual, "position:y", vis_target - height_offset, 0.1)
	if not _is_crouching:
		_crouch_tween.tween_callback(func(): visual.position.y = -height_offset)
