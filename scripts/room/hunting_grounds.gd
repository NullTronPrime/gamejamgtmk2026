extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")
const HumanoidRig := preload("res://scripts/shared/humanoid_rig.gd")
const GRAVITY := 1400.0
const JUMP_VEL := -480.0
const MOVE_SPEED := 180.0
const TILE := 64

var _player: CharacterBody2D
var _can_move := false
var _exiting := false
var _stage_hint: Label
var _near_interact: Dictionary = {}

var _arrow_obtained := false; var _cage_dropped := false; var _letter_read := false
var _flowers_collected := false; var _berries := 0; var _milk_obtained := false
var _yajna_lit := false; var _choice_made := false; var _snakes_saved := 0
var _snake_hides: Array[Area2D] = []; var _berry_areas: Array[Area2D] = []
var _nest_pos: Vector2

func _ready() -> void:
	_build_terrain()
	_build_scenery()
	_build_stages()
	_spawn_player()
	_setup_camera()
	_setup_ui()
	reveal.call_deferred()

func _r(x, y, w, h, col: Color, z: int = 0) -> ColorRect:
	var r := ColorRect.new()
	r.position = Vector2(x, y); r.size = Vector2(w, h); r.color = col
	r.z_index = z; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; return r

func _solid(pos: Vector2, size: Vector2) -> void:
	var s := StaticBody2D.new(); s.collision_layer = 1; s.position = pos
	var c := CollisionShape2D.new()
	c.shape = RectangleShape2D.new(); c.shape.size = size
	s.add_child(c); add_child(s)

func _area(pos: Vector2, size: Vector2, name: String) -> Area2D:
	var a := Area2D.new(); a.name = name; a.position = pos; a.collision_mask = 1
	var s := CollisionShape2D.new()
	s.shape = RectangleShape2D.new(); s.shape.size = size
	a.add_child(s); return a

func _tex(path: String) -> Texture2D:
	return load(path)

func _hint(pos: Vector2, text: String, col: Color) -> Label:
	var l := Label.new(); l.position = pos; l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", col); l.mouse_filter = Control.MOUSE_FILTER_IGNORE; return l

func _build_terrain() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.35, 0.55, 0.5)
	bg.size = Vector2(80*TILE, 10*TILE)
	bg.position = Vector2(0, 0); bg.z_index = -3; bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)

	var lt := _tex("res://assets/art/rooms/wall_tile_light.png")
	var dt := _tex("res://assets/art/rooms/wall_tile_dark.png")
	for x in range(0, 80 * TILE, TILE):
		if lt:
			var sp := Sprite2D.new()
			sp.texture = lt; sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.position = Vector2(x + TILE/2, 10*TILE + TILE/2)
			sp.z_index = -2; add_child(sp)
		if dt:
			var sp := Sprite2D.new()
			sp.texture = dt; sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.position = Vector2(x + TILE/2, 11*TILE + TILE/2)
			sp.z_index = -2; add_child(sp)
		_solid(Vector2(x + TILE/2, 10*TILE + TILE), Vector2(TILE, TILE*2))

	var dw := _tex("res://assets/art/rooms/wall_tile_dark.png")
	var lw := _tex("res://assets/art/rooms/wall_tile_light.png")
	for x in [0, 79*TILE]:
		for yi in range(0, 10*TILE, TILE):
			var tex := dw if (yi/TILE)%2==0 else lw
			if tex:
				var sp := Sprite2D.new()
				sp.texture = tex; sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sp.position = Vector2(x + TILE/2, yi + TILE/2)
				sp.z_index = -2; add_child(sp)
			else:
				add_child(_r(x, yi, TILE, TILE, Color(0.2,0.15,0.1), -2))
		_solid(Vector2(x + TILE/2, 5*TILE), Vector2(TILE, 10*TILE))

func _build_scenery() -> void:
	var rng = RandomNumberGenerator.new()
	for i in 10:
		var hx := i * 8 * TILE + rng.randi_range(0, TILE*2)
		var hw := rng.randf_range(80, 200)
		var hh := rng.randf_range(30, 80)
		var hill := _r(hx, 10*TILE - hh + 4, hw, hh, Color(0.2, 0.45, 0.15, 0.2))
		hill.z_index = -3; add_child(hill)
		add_child(_r(hx, 10*TILE - hh + 2, hw, 2, Color(0.25, 0.55, 0.18, 0.15)))

	for i in 25:
		var fx := rng.randi_range(2, 78) * TILE
		var fcol := Color(0.9*rng.randf(), 0.3*rng.randf(), 0.4*rng.randf())
		add_child(_r(fx, 10*TILE - 12, 2, 10, Color(0.15, 0.45, 0.1)))
		add_child(_r(fx - 2, 10*TILE - 18, 6, 6, fcol))

	var rock_col := Color(0.35, 0.3, 0.25)
	for i in 6:
		var rx := rng.randi_range(2, 78) * TILE
		var rw := rng.randf_range(12, 28)
		var rh := rng.randf_range(8, 16)
		add_child(_r(rx, 10*TILE - rh, rw, rh, rock_col))
		_solid(Vector2(rx + rw/2, 10*TILE - rh/2), Vector2(rw, rh))

func _build_stages() -> void:
	var sx := 8*TILE
	add_child(_r(sx, 10*TILE - 12, 80, 10, Color(0.15, 0.5, 0.2)))
	add_child(_r(sx+75, 10*TILE - 14, 14, 8, Color(0.1, 0.4, 0.15)))
	add_child(_r(sx+45, 10*TILE - 30, 3, 20, Color(0.5, 0.35, 0.15)))
	add_child(_r(sx+56, 10*TILE - 42, 8, 6, Color(0.6, 0.6, 0.6)))
	add_child(_hint(Vector2(sx+20, 10*TILE - 52), "[Arrow]", Color(1, 1, 0.6, 0.7)))
	var aa := _area(Vector2(sx+40, 10*TILE - 20), Vector2(100, 60), "ArrowArea")
	aa.body_entered.connect(_on_near.bind("arrow")); add_child(aa)

	var bx := 20*TILE
	add_child(_r(bx, 10*TILE - 24, 48, 48, Color(0.45, 0.4, 0.3)))
	add_child(_r(bx+6, 10*TILE - 18, 36, 36, Color(0.55, 0.48, 0.36)))
	_solid(Vector2(bx+24, 10*TILE), Vector2(48, 48))
	add_child(_hint(Vector2(bx-12, 10*TILE - 60), "[Push Boulder]", Color(0.8, 0.8, 0.7, 0.7)))

	var px := 26*TILE
	add_child(_r(px-24, 10*TILE - 6, 48, 6, Color(0.4, 0.35, 0.25)))
	add_child(_r(px-28, 10*TILE - 8, 56, 10, Color(0.6, 0.5, 0.2, 0.3)))
	var pa := _area(Vector2(px, 10*TILE), Vector2(56, 16), "PlateArea")
	pa.body_entered.connect(_on_plate_entered)
	pa.body_exited.connect(_on_plate_exited)
	pa.collision_mask = 1; add_child(pa)

	var cv := ColorRect.new()
	cv.name = "CageVisual"
	cv.color = Color(0.3, 0.25, 0.15, 0.0)
	cv.size = Vector2(48, 36)
	cv.position = Vector2(px-24, 10*TILE - 106)
	cv.z_index = 1; add_child(cv)

	add_child(_hint(Vector2(px-24, 10*TILE - 130), "[Cage]", Color(0.8, 0.7, 0.3, 0.5)))

	var la := _area(Vector2(px, 10*TILE - 90), Vector2(40, 30), "LetterArea")
	la.body_entered.connect(_on_near.bind("letter")); la.monitoring = false; add_child(la)
	add_child(_hint(Vector2(px-28, 10*TILE - 130), "[Letter Inside]", Color(0.9, 0.9, 0.6, 0.0)))

	var fa := _area(Vector2(34*TILE, 10*TILE - 12), Vector2(TILE*4, 30), "FlowerArea")
	fa.body_entered.connect(_on_near.bind("flower")); add_child(fa)
	add_child(_hint(Vector2(34*TILE - 30, 10*TILE - 40), "[Pick Flowers]", Color(0.9, 0.7, 0.2, 0.7)))

	_nest_pos = Vector2(48*TILE, 10*TILE - 18)
	add_child(_r(_nest_pos.x - 18, _nest_pos.y - 6, 36, 12, Color(0.35, 0.25, 0.12)))
	add_child(_r(_nest_pos.x - 12, _nest_pos.y - 4, 24, 8, Color(0.25, 0.18, 0.08)))
	var na := _area(_nest_pos, Vector2(50, 30), "NestArea")
	na.monitoring = false; na.body_entered.connect(_on_near.bind("nest")); add_child(na)
	add_child(_hint(Vector2(_nest_pos.x - 18, _nest_pos.y - 28), "[Nest]", Color(0.8, 0.7, 0.3, 0.5)))

	var np := Label.new()
	np.name = "NestProgress"
	np.text = "Snakes: 0/3"
	np.add_theme_font_size_override("font_size", 8)
	np.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3, 0.6))
	np.position = _nest_pos - Vector2(22, -8); np.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(np)

	var mv := ColorRect.new()
	mv.name = "MilkVisual"
	mv.color = Color(0.9, 0.85, 0.7, 0.0)
	mv.size = Vector2(24, 12)
	mv.position = _nest_pos - Vector2(12, 12); mv.z_index = 1; add_child(mv)

	var ma := _area(_nest_pos + Vector2(0, 12), Vector2(40, 30), "MilkArea")
	ma.monitoring = false; ma.body_entered.connect(_on_near.bind("milk")); add_child(ma)

	var hid := [Vector2(42*TILE, 9*TILE+16), Vector2(54*TILE, 9*TILE+16), Vector2(48*TILE, 8*TILE+12)]
	for i in 3:
		var ha := _area(hid[i], Vector2(30, 24), "SnakeHide_%d"%i)
		ha.monitoring = false; ha.body_entered.connect(_on_snake_hide.bind(i)); add_child(ha); _snake_hides.append(ha)
		add_child(_r(hid[i].x-14, hid[i].y-16, 28, 20, Color(0.12, 0.32, 0.08)))

	for i in 3:
		var bpos := Vector2(44*TILE + i*3*TILE, 10*TILE - 12)
		var ba := _area(bpos, Vector2(28, 24), "Berry_%d"%i)
		ba.monitoring = true; ba.body_entered.connect(_on_berry.bind(i)); add_child(ba); _berry_areas.append(ba)
		add_child(_r(bpos.x-12, bpos.y-16, 24, 18, Color(0.15, 0.4, 0.1)))
		add_child(_r(bpos.x-2, bpos.y-8, 4, 4, Color(0.85, 0.1, 0.1)))

	var yx := 66*TILE; var yy := 10*TILE - 8
	add_child(_r(yx-60, yy, 120, 16, Color(0.5, 0.35, 0.15)))
	add_child(_r(yx-30, yy-16, 60, 24, Color(0.4, 0.28, 0.1)))
	add_child(_r(yx-12, yy-24, 24, 8, Color(0.15, 0.1, 0.05)))
	add_child(_r(yx-9, yy-22, 18, 3, Color(0.35, 0.2, 0.08)))
	add_child(_r(yx-9, yy-20, 18, 3, Color(0.3, 0.18, 0.06)))
	add_child(_hint(Vector2(yx-24, yy-60), "[Light Yajna Fire]", Color(0.9, 0.5, 0.2, 0.7)))
	var ya := _area(Vector2(yx, yy-16), Vector2(80, 60), "YajnaArea")
	ya.body_entered.connect(_on_near.bind("yajna")); add_child(ya)

func _spawn_player() -> void:
	_player = CharacterBody2D.new(); _player.name = "Player"
	_player.collision_layer = 1; _player.collision_mask = 1
	var shape := RectangleShape2D.new(); shape.size = Vector2(28, 88)
	var col := CollisionShape2D.new(); col.shape = shape; col.position = Vector2(0, 12)
	_player.add_child(col)

	HumanoidRig.build(_player, Color(0.55, 0.4, 0.25), Color(0.8, 0.65, 0.5))
	for c in _player.get_children():
		if c is Polygon2D: c.z_index = 1

	_player.position = Vector2(3*TILE, 9*TILE); add_child(_player)

func _setup_camera() -> void:
	var cam := Camera2D.new(); cam.name = "Camera2D"
	cam.zoom = Vector2(1.8, 1.8); cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(cam); cam.make_current()

func _setup_ui() -> void:
	_stage_hint = Label.new()
	_stage_hint.add_theme_font_size_override("font_size", 11)
	_stage_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7, 0.6))
	_stage_hint.anchor_left = 0.5; _stage_hint.anchor_top = 0.0
	_stage_hint.anchor_right = 0.5; _stage_hint.anchor_bottom = 0.0
	_stage_hint.position = Vector2(-120, 60); _stage_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage_hint)

func _on_near(body: Node, id: String) -> void:
	if body == _player: _near_interact[id] = true

func _on_plate_entered(body: Node) -> void:
	if not _cage_dropped:
		_cage_dropped = true
		var cv := get_node_or_null("CageVisual") as ColorRect
		if cv:
			var tw := create_tween()
			tw.tween_property(cv, "color", Color(0.4, 0.35, 0.25, 0.9), 0.6)
		get_node_or_null("LetterArea").monitoring = true

func _on_plate_exited(_body: Node) -> void:
	pass

func _on_snake_hide(body: Node, idx: int) -> void:
	if body == _player and _berries >= 3 and _snakes_saved < 3:
		_snake_hides[idx].monitoring = false; _snakes_saved += 1
		_show_prompt("Baby snake slithers to the nest! (%d/3)" % _snakes_saved)
		var np := get_node_or_null("NestProgress") as Label
		if np: np.text = "Snakes: %d/3" % _snakes_saved
		if _snakes_saved >= 3:
			_milk_obtained = true
			get_node_or_null("NestArea").monitoring = true
			get_node_or_null("MilkArea").monitoring = true
			var mv := get_node_or_null("MilkVisual") as ColorRect
			if mv:
				var tw := create_tween()
				tw.tween_property(mv, "color", Color(0.9, 0.85, 0.7, 1.0), 0.8)
			_show_prompt("All snakes saved! Bowl of milk appears.")

func _on_berry(body: Node, idx: int) -> void:
	if body == _player and _berries < 3:
		_berries += 1
		if _berry_areas[idx]: _berry_areas[idx].queue_free(); _berry_areas[idx] = null
		_show_prompt("Found berries! (%d/3)" % _berries)
		if _berries >= 3:
			_stage_hint.text = "Berries gathered! Search bushes for baby snakes."
			for h in _snake_hides: h.monitoring = true

func _show_prompt(text: String) -> void:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1, 1, 0.8))
	l.position = Vector2(20, 20); l.z_index = 10; add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 3.0).set_delay(2.5)
	await tw.finished; l.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and _can_move: _handle_interact()
		elif event.keycode == KEY_ESCAPE:
			add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())

func _handle_interact() -> void:
	if _near_interact.get("arrow", false) and not _arrow_obtained:
		_arrow_obtained = true; _show_prompt("Retrieved Arrow from snake body!")
		_stage_hint.text = "Got the arrow! Push the boulder onto the plate."
	elif _near_interact.get("letter", false) and not _letter_read and _cage_dropped:
		_letter_read = true; _flowers_collected = true
		_show_prompt("Letter: Shaktinath's regret... Pick flowers from the field.")
		_stage_hint.text = "Pick flowers from the field ahead."
	elif _near_interact.get("flower", false) and _letter_read:
		_show_prompt("Picked wildflowers! Now enter the snake garden.")
		_stage_hint.text = "Enter the garden. Gather berries to lure baby snakes!"
	elif _near_interact.get("nest", false) and _milk_obtained:
		_show_prompt("You retrieve the bowl of milk!")
		_stage_hint.text = "Got the milk! Head to the Yajna fire."
		get_node_or_null("MilkArea").monitoring = false
	elif _near_interact.get("milk", false) and _milk_obtained:
		_show_prompt("Go to the Yajna fire.")
	elif _near_interact.get("yajna", false) and _arrow_obtained and _flowers_collected and _milk_obtained and not _yajna_lit:
		_yajna_lit = true; _light_fire()
	else: _show_prompt("Need arrow, flowers, and milk to light the Yajna.")

func _light_fire() -> void:
	_can_move = false
	var yx := 66*TILE; var yy := 10*TILE - 8
	var fc := [Color(1,0.5,0.05), Color(1,0.3,0.02), Color(0.8,0.1,0.01)]
	for i in 3:
		var flame := ColorRect.new()
		flame.color = fc[i]; flame.size = Vector2(8, 12+i*6)
		flame.position = Vector2(yx-12+i*12, yy-40-i*4); flame.z_index = 2; add_child(flame)
	_show_prompt("The Yajna fire blazes! Shaktinath and Nageshwari appear.")
	var box := preload("res://scenes/ui/dialogue_box.tscn").instantiate()
	box.position = Vector2(200, 200); add_child(box)
	box.yes_button.text = "Fulfill the Vow"; box.no_button.text = "Protect the Prince"
	box.response_chosen.connect(_on_choice)
	box.show_text("Shaktinath stands ready.\nNageshwari glides toward the flame.\n\nWho completes the sacrifice?")

func _on_choice(fulfill: bool) -> void:
	if _choice_made: return
	_choice_made = true; _can_move = false
	if fulfill: _show_prompt("Nageshwari enters the flame first. 'Let the prince live.'")
	else: _show_prompt("Nageshwari sacrifices herself. Maternal love over revenge.")
	await get_tree().create_timer(3.0).timeout; _exit_room()

func _exit_room() -> void:
	if _exiting: return
	_exiting = true
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.cover(0.8)
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("exit_hunting_grounds"): g.exit_hunting_grounds()
	else: queue_free()

func reveal() -> void:
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.reveal(0.8)
	_can_move = true

func _physics_process(delta: float) -> void:
	if not _can_move or not _player: return
	var dir := Input.get_axis("move_left", "move_right")
	_player.velocity.x = dir * MOVE_SPEED
	_player.velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and _player.is_on_floor(): _player.velocity.y = JUMP_VEL
	_player.move_and_slide()
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam: cam.position = _player.position
