extends Node2D

const TAU := PI * 2

var _time_offset: float = 0.0
var _pulse_phase: float = 0.0
var _running: bool = true

const CLOCK_RADIUS: float = 120.0

var rune_shapes: Dictionary = {}

func _ready() -> void:
	_build_runes()

func _build_runes() -> void:
	var glyphs = [
		[Vector2(2,2), Vector2(10,10), Vector2(18,2)],
		[Vector2(2,2), Vector2(18,2), Vector2(18,10), Vector2(2,10), Vector2(2,18), Vector2(18,18)],
		[Vector2(2,2), Vector2(18,2), Vector2(10,10), Vector2(18,10), Vector2(2,18)],
		[Vector2(2,2), Vector2(2,18), Vector2(2,10), Vector2(18,10), Vector2(18,2), Vector2(18,18)],
		[Vector2(18,2), Vector2(2,2), Vector2(2,10), Vector2(18,10), Vector2(18,18), Vector2(2,18)],
		[Vector2(18,2), Vector2(2,10), Vector2(18,10), Vector2(18,18), Vector2(2,18), Vector2(2,10)],
		[Vector2(2,2), Vector2(18,2), Vector2(10,18)],
		[Vector2(10,2), Vector2(2,6), Vector2(2,14), Vector2(10,18), Vector2(18,14), Vector2(18,6)],
		[Vector2(18,10), Vector2(10,2), Vector2(2,6), Vector2(2,14), Vector2(18,18)],
		[Vector2(2,2), Vector2(2,18), Vector2(2,10), Vector2(14,2), Vector2(2,10), Vector2(14,18)],
		[Vector2(4,2), Vector2(4,18), Vector2(14,2), Vector2(14,18)],
		[Vector2(2,2), Vector2(18,10), Vector2(2,18), Vector2(18,2), Vector2(18,18)],
	]
	for i in 12:
		rune_shapes[i + 1] = glyphs[i % glyphs.size()]

func _draw() -> void:
	var cx = 0
	var cy = 0
	var r = CLOCK_RADIUS - 4

	draw_circle(Vector2(cx, cy), r, Color.WHITE)
	draw_arc(Vector2(cx, cy), r, 0, TAU, 64, Color.BLACK, 2)

	var d = Time.get_datetime_dict_from_unix_time(int(_time_offset))
	var h = d["hour"] % 12
	var m = d["minute"]
	var s = d["second"]

	for i in range(60):
		var ang = (i / 60.0) * TAU - PI / 2
		var is_hour = i % 5 == 0
		var r1 = r - 3
		var r2 = r - 8 if is_hour else r - 6
		var x1 = cx + cos(ang) * r1
		var y1 = cy + sin(ang) * r1
		var x2 = cx + cos(ang) * r2
		var y2 = cy + sin(ang) * r2
		var col = Color.BLACK if is_hour else Color(0.55, 0.55, 0.55)
		var lw = 1.5 if is_hour else 0.8
		draw_line(Vector2(x1, y1), Vector2(x2, y2), col, lw)

	for hour in range(12):
		var ang = (hour / 12.0) * TAU - PI / 2
		var gr = r - 18
		var gx = cx + cos(ang) * gr
		var gy = cy + sin(ang) * gr
		_draw_rune(hour + 1, gx, gy, 0.5)

	var sec_angle = s / 60.0 * TAU - PI / 2
	var min_angle = (m + s / 60.0) / 60.0 * TAU - PI / 2
	var hour_angle = (h + m / 60.0) / 12.0 * TAU - PI / 2

	_draw_hand(hour_angle, r * 0.48, 4.0, Color.BLACK, true)
	_draw_hand(min_angle, r * 0.72, 2.5, Color.BLACK, true)
	_draw_hand(sec_angle, r * 0.80, 1.5, Color(0.54, 0.17, 0.89), true)

	draw_circle(Vector2(cx, cy), 3.0, Color.BLACK)

func _draw_rune(n: int, x: float, y: float, scale: float) -> void:
	var pts = rune_shapes.get(n, rune_shapes[1])
	if pts.size() < 2:
		return
	var prev = Vector2(x + (pts[0].x - 10) * scale, y + (pts[0].y - 10) * scale)
	for i in range(1, pts.size()):
		var cur = Vector2(x + (pts[i].x - 10) * scale, y + (pts[i].y - 10) * scale)
		draw_line(prev, cur, Color.BLACK, 1.2)
		prev = cur

func _draw_hand(angle: float, length: float, width: float, color: Color, arrow: bool) -> void:
	var cx = 0
	var cy = 0
	var tip = Vector2(cx + cos(angle) * length, cy + sin(angle) * length)

	if arrow:
		var head_len = max(length * 0.16, 4.0)
		var head_w = max(length * 0.11, 3.5)
		var shaft_len = max(length - head_len, 0)
		var shaft_tip = Vector2(cx + cos(angle) * shaft_len, cy + sin(angle) * shaft_len)

		draw_line(Vector2(cx, cy), shaft_tip, color, width)

		var perp = angle + PI / 2
		var lx = shaft_tip + Vector2(cos(perp), sin(perp)) * head_w * 0.5
		var rx = shaft_tip - Vector2(cos(perp), sin(perp)) * head_w * 0.5
		var pts = PackedVector2Array([tip, lx, rx])
		draw_colored_polygon(pts, color)
	else:
		draw_line(Vector2(cx, cy), tip, color, width)

func _process(delta: float) -> void:
	if _running:
		_time_offset += delta * 120.0

	_pulse_phase += delta * 0.6
	var breath = 1.0 + sin(_pulse_phase) * 0.06
	scale = Vector2.ONE * breath
	queue_redraw()

func reset_time() -> void:
	_time_offset = 0.0

func toggle_running() -> void:
	_running = not _running
