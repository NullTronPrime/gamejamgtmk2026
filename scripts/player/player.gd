extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var acceleration: float = 1200.0
@export var friction: float = 800.0
@export var gravity: float = 1200.0

const MIN_DEPTH: float = 0.0
const MAX_DEPTH: float = 600.0

var is_carrying_betaal: bool = true
var is_stopped: bool = false
var speed_multiplier: float = 1.0
var _speed_boost_tween: Tween

var height_offset: float = 0.0
var vertical_vel: float = 0.0

var _footstep_timer: float = 0.0
var _footstep_streams: Array = []
var _run_streams: Array = []

var sprint_energy: float = 1.0
const SPRINT_DEPLETE_RATE: float = 1.0 / 3.0
const SPRINT_RECHARGE_RATE: float = 1.0 / 2.0
const SPRINT_SPEED_BONUS: float = 0.5

signal sprint_energy_changed(value: float)

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
	var v_dir := Input.get_axis("move_up", "move_down")

	var sprint_pressed = Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint")
	var wants_to_sprint = sprint_pressed and (h_dir != 0 or v_dir != 0) and sprint_energy > 0

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

	if v_dir != 0:
		var target_y = position.y + v_dir * effective_speed * delta
		target_y = clamp(target_y, MIN_DEPTH, MAX_DEPTH)
		velocity.y = (target_y - position.y) / delta
	else:
		velocity.y = move_toward(velocity.y, 0.0, friction * delta)

	if Input.is_action_just_pressed("jump") and on_ground:
		vertical_vel = jump_velocity

	move_and_slide()

	var is_moving = h_dir != 0 or v_dir != 0
	var is_running = wants_to_sprint or speed_multiplier > 1.0
	_animate_rig(delta, is_moving, on_ground, is_running)

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

	if _walk_blend < 0.05:
		var bob = sin(Time.get_ticks_msec() / 1000.0 * 1.6) * 0.5
		_rig["torso"].position.y = bob
		_rig["head"].position.y = bob
	else:
		_rig["torso"].position.y = 0.0
		_rig["head"].position.y = 0.0
