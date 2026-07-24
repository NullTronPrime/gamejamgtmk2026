extends CanvasLayer
class_name GridTransition

const TAU := PI * 2

static var _instance: GridTransition = null

var _spiral_overlay: ColorRect
var _spiral_mat: ShaderMaterial
var _current_clock: Node2D
var _busy := false
var _ready_done := false

func _ready() -> void:
	_instance = self
	layer = 129

	var shader_path = "res://addons/saltmire_transitions/shaders/grid_wipe.gdshader"
	var shader_res = load(shader_path) as Shader
	if not shader_res:
		push_error("GridTransition: failed to load ", shader_path)
		return
	_spiral_mat = ShaderMaterial.new()
	_spiral_mat.shader = shader_res
	_spiral_mat.set_shader_parameter("fill_color", Color.BLACK)
	_spiral_mat.set_shader_parameter("origin", Vector2(0.5, 0.5))
	_spiral_mat.set_shader_parameter("arms", 3.0)
	_spiral_mat.set_shader_parameter("twist", 6.0)
	_spiral_mat.set_shader_parameter("edge_softness", 0.04)
	_spiral_mat.set_shader_parameter("grid_size", Vector2(64, 36))
	_spiral_overlay = ColorRect.new()
	_spiral_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spiral_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spiral_overlay.modulate.a = 0.0
	_spiral_overlay.material = _spiral_mat
	add_child(_spiral_overlay)

	_ready_done = true

func _exit_tree() -> void:
	_instance = null

static func is_available() -> bool:
	return _instance != null and _instance._ready_done

static func play(total_duration: float = 2.8) -> void:
	if not is_available() or _instance._busy:
		return
	_instance._busy = true

	var vs := DisplayServer.window_get_size()
	var clock := preload("res://scripts/ui/enchant_clock.gd").new()
	clock.position = vs * 0.5
	clock.scale = Vector2.ZERO
	clock.rotation = 0.0
	_instance.add_child(clock)

	_instance._current_clock = clock

	var cover_t := total_duration * 0.45
	var hold_t := total_duration * 0.10
	var reveal_t := total_duration * 0.45

	_instance._spiral_overlay.modulate.a = 1.0
	_instance._spiral_mat.set_shader_parameter("progress", 0.0)

	var tw = _instance.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v):
		_instance._spiral_mat.set_shader_parameter("progress", v)
		_instance._current_clock.rotation = v * TAU * 3.0
		_instance._current_clock.scale = Vector2.ONE * v
	, 0.0, 1.0, cover_t)
	await _instance.get_tree().create_timer(cover_t).timeout

	await _instance.get_tree().create_timer(hold_t).timeout

	var tw4 = _instance.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw4.tween_method(func(v):
		_instance._spiral_mat.set_shader_parameter("progress", v)
		_instance._current_clock.rotation = v * TAU * 3.0
		_instance._current_clock.scale = Vector2.ONE * v
	, 1.0, 0.0, reveal_t)

	await _instance.get_tree().create_timer(reveal_t).timeout

	_instance._spiral_overlay.modulate.a = 0.0
	_instance._current_clock.queue_free()
	_instance._current_clock = null
	_instance._busy = false

static func cover(duration: float = 1.2) -> void:
	if not is_available() or _instance._busy:
		return
	_instance._busy = true

	var vs := DisplayServer.window_get_size()
	var clock := preload("res://scripts/ui/enchant_clock.gd").new()
	clock.position = vs * 0.5
	clock.scale = Vector2.ZERO
	clock.rotation = 0.0
	_instance.add_child(clock)

	_instance._current_clock = clock

	_instance._spiral_overlay.modulate.a = 1.0
	_instance._spiral_mat.set_shader_parameter("progress", 0.0)

	var tw = _instance.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v):
		_instance._spiral_mat.set_shader_parameter("progress", v)
		_instance._current_clock.rotation = v * TAU * 3.0
		_instance._current_clock.scale = Vector2.ONE * v
	, 0.0, 1.0, duration)

	await _instance.get_tree().create_timer(duration).timeout
	_instance._busy = false

static func reveal(duration: float = 1.2) -> void:
	if not is_available() or _instance._busy:
		return
	_instance._busy = true
	var clock = _instance._current_clock
	if not clock or not is_instance_valid(clock):
		var vs := DisplayServer.window_get_size()
		clock = preload("res://scripts/ui/enchant_clock.gd").new()
		clock.position = vs * 0.5
		clock.scale = Vector2.ONE
		clock.rotation = TAU * 3.0
		_instance.add_child(clock)
	clock.scale = Vector2.ONE
	clock.rotation = TAU * 3.0

	_instance._spiral_overlay.modulate.a = 1.0
	_instance._spiral_mat.set_shader_parameter("progress", 1.0)

	var tw = _instance.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v):
		_instance._spiral_mat.set_shader_parameter("progress", v)
		_instance._current_clock.rotation = v * TAU * 3.0
		_instance._current_clock.scale = Vector2.ONE * v
	, 1.0, 0.0, duration)
	await tw.finished

	_instance._spiral_overlay.modulate.a = 0.0
	_instance._current_clock.queue_free()
	_instance._current_clock = null
	_instance._busy = false

static func is_busy() -> bool:
	return _instance and _instance._busy
