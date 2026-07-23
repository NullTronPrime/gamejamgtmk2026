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

func _ready() -> void:
	GameManager.state_changed.connect(_on_game_state_changed)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-8, -24), Vector2(8, -24), Vector2(12, 0), Vector2(8, 24), Vector2(-8, 24), Vector2(-12, 0)])
	body.color = Color(0.2, 0.5, 0.9)
	visual.add_child(body)
	var head = Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-6, -32), Vector2(6, -32), Vector2(8, -24), Vector2(-8, -24)])
	head.color = Color(0.85, 0.7, 0.55)
	visual.add_child(head)
	_make_lit(body)
	_make_lit(head)
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

	if h_dir != 0 or v_dir != 0:
		var is_running = wants_to_sprint or speed_multiplier > 1.0
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
