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
var _cutscene_box: CanvasLayer
var _snake_sprite: Sprite2D

func _ready() -> void:
	_build_terrain()
	_build_scenery()
	_build_stages()
	_spawn_player()
	_setup_camera()
	_setup_ui()
	reveal.call_deferred()

func _r(x: float, y: float, w: float, h: float, col: Color, z: int = 0) -> ColorRect:
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
	var sky := ColorRect.new()
	sky.color = Color(0.55, 0.7, 0.75)
	sky.size = Vector2(80*TILE, 10*TILE)
	sky.position = Vector2(0, 0); sky.z_index = -5; sky.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(sky)

	var lt := _tex("res://assets/art/rooms/wall_tile_light.png")
	var dt := _tex("res://assets/art/rooms/wall_tile_dark.png")
	for x in range(0, 80 * TILE, TILE):
		if lt:
			var sp := Sprite2D.new()
			sp.texture = lt; sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.position = Vector2(x + TILE/2, 10*TILE + TILE/2)
			sp.z_index = -4; add_child(sp)
		if dt:
			var sp := Sprite2D.new()
			sp.texture = dt; sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.position = Vector2(x + TILE/2, 11*TILE + TILE/2)
			sp.z_index = -4; add_child(sp)
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
				sp.z_index = -4; add_child(sp)
		_solid(Vector2(x + TILE/2, 5*TILE), Vector2(TILE, 10*TILE))

	var grass_strip := ColorRect.new()
	grass_strip.color = Color(0.3, 0.6, 0.2)
	grass_strip.size = Vector2(80*TILE, 8)
	grass_strip.position = Vector2(0, 10*TILE - 4)
	grass_strip.z_index = -3; grass_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(grass_strip)

func _build_scenery() -> void:
	var rng = RandomNumberGenerator.new()
	for i in 12:
		var hx := i * 7 * TILE + rng.randi_range(-TILE, TILE*2)
		var hw := rng.randf_range(100, 240)
		var hh := rng.randf_range(24, 60)
		var hill := _r(hx, 10*TILE - hh, hw, hh, Color(0.25, 0.5, 0.18, 0.25))
		hill.z_index = -4; add_child(hill)
		add_child(_r(hx, 10*TILE - hh, hw, 2, Color(0.3, 0.55, 0.2, 0.2)))

	for i in 20:
		var fx := rng.randi_range(2, 78) * TILE
		var fcol := Color(0.85*rng.randf() + 0.1, 0.2*rng.randf() + 0.2, 0.3*rng.randf() + 0.2)
		add_child(_r(fx, 10*TILE - 10, 2, 8, Color(0.15, 0.45, 0.1)))
		add_child(_r(fx - 3, 10*TILE - 16, 6, 6, fcol))

	for i in 5:
		var dx := i * 16 * TILE + rng.randi_range(0, TILE)
		add_child(_r(dx, 10*TILE - 2, 80, 4, Color(0.4, 0.3, 0.2, 0.15)))

func _build_stages() -> void:
	var surface := 10 * TILE
	var sx := 8*TILE
	_snake_sprite = Sprite2D.new()
	_snake_sprite.texture = preload("res://assets/art/rooms/snakedeadwitharrow.png")
	_snake_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_snake_sprite.position = Vector2(sx + 40, surface - 12)
	_snake_sprite.z_index = 1
	add_child(_snake_sprite)
	add_child(_hint(Vector2(sx+20, surface - 52), "[Arrow]", Color(1, 1, 0.6, 0.7)))
	var aa := _area(Vector2(sx+40, surface - 20), Vector2(100, 60), "ArrowArea")
	aa.body_entered.connect(_on_near.bind("arrow")); add_child(aa)

	var bx := 20*TILE
	var boulder := RigidBody2D.new()
	boulder.name = "Boulder"
	boulder.gravity_scale = 1.0; boulder.lock_rotation = true; boulder.mass = 3.0
	boulder.linear_damp = 0.3; boulder.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	boulder.collision_layer = 1; boulder.collision_mask = 1
	var bshape := CollisionShape2D.new()
	bshape.shape = RectangleShape2D.new(); bshape.shape.size = Vector2(46, 46)
	boulder.add_child(bshape)
	var bvis := ColorRect.new()
	bvis.size = Vector2(48, 48); bvis.position = Vector2(-24, -24)
	bvis.color = Color(0.45, 0.4, 0.3); boulder.add_child(bvis)
	var bh := ColorRect.new()
	bh.size = Vector2(36, 36); bh.position = Vector2(-18, -18)
	bh.color = Color(0.55, 0.48, 0.36); boulder.add_child(bh)
	boulder.position = Vector2(bx, surface - 24); add_child(boulder)
	add_child(_hint(Vector2(bx-12, surface - 70), "[Push Boulder]", Color(0.8, 0.8, 0.7, 0.7)))

	var px := 26*TILE
	add_child(_r(px - 26, surface - 6, 52, 6, Color(0.4, 0.35, 0.25)))
	add_child(_r(px - 30, surface - 8, 60, 10, Color(0.6, 0.5, 0.2, 0.3)))
	var pa := _area(Vector2(px, surface), Vector2(60, 16), "PlateArea")
	pa.body_entered.connect(_on_plate_entered)
	pa.body_exited.connect(_on_plate_exited)
	pa.collision_mask = 1; add_child(pa)

	var cv := ColorRect.new()
	cv.name = "CageVisual"
	cv.color = Color(0.3, 0.25, 0.15, 0.0)
	cv.size = Vector2(48, 36)
	cv.position = Vector2(px - 24, surface - 106)
	cv.z_index = 1; add_child(cv)

	var cbv := ColorRect.new()
	cbv.name = "CageBars"
	cbv.color = Color(0.4, 0.35, 0.25, 0.0)
	cbv.size = Vector2(48, 36)
	cbv.position = Vector2(px - 24, surface - 106)
	cbv.z_index = 2; add_child(cbv)

	add_child(_hint(Vector2(px-24, surface - 130), "[Cage]", Color(0.8, 0.7, 0.3, 0.5)))
	var la := _area(Vector2(px, surface - 90), Vector2(40, 30), "LetterArea")
	la.body_entered.connect(_on_near.bind("letter")); la.monitoring = false; add_child(la)

	var flower_tex := preload("res://assets/art/items/flowersspread.png")
	for i in 3:
		var fpos := Vector2(34*TILE + i * 40, surface - 12)
		var fsp := Sprite2D.new()
		fsp.texture = flower_tex; fsp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fsp.scale = Vector2(1.2, 1.2)
		fsp.position = fpos; fsp.z_index = 1; add_child(fsp)
	var fa := _area(Vector2(34*TILE, surface - 12), Vector2(TILE*4, 30), "FlowerArea")
	fa.body_entered.connect(_on_near.bind("flower")); add_child(fa)
	add_child(_hint(Vector2(34*TILE - 30, surface - 40), "[Pick Flowers]", Color(0.9, 0.7, 0.2, 0.7)))

	_nest_pos = Vector2(48*TILE, surface - 18)
	var nest_out := ColorRect.new()
	nest_out.size = Vector2(40, 14)
	nest_out.position = _nest_pos - Vector2(20, 7)
	nest_out.color = Color(0.35, 0.25, 0.12)
	nest_out.z_index = 1; add_child(nest_out)
	var nest_in := ColorRect.new()
	nest_in.size = Vector2(28, 10)
	nest_in.position = _nest_pos - Vector2(14, 5)
	nest_in.color = Color(0.25, 0.18, 0.08)
	nest_in.z_index = 1; add_child(nest_in)

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

	var hid_positions: Array[Vector2] = [
		Vector2(42*TILE, 8*TILE + 8),
		Vector2(54*TILE, 8*TILE + 8),
		Vector2(48*TILE, 7*TILE + 4),
	]
	for i in 3:
		var hp: Vector2 = hid_positions[i]
		var plat_w := 56; var plat_h := 8
		add_child(_r(hp.x - plat_w/2, hp.y, plat_w, plat_h, Color(0.3, 0.28, 0.22)))
		add_child(_r(hp.x - plat_w/2 + 2, hp.y - 4, plat_w - 4, plat_h - 2, Color(0.35, 0.32, 0.25)))
		_solid(Vector2(hp.x, hp.y + plat_h/2), Vector2(plat_w, plat_h))
		var vine_r := _r(hp.x + plat_w/2 - 2, hp.y - 30, 4, 34, Color(0.12, 0.4, 0.1))
		vine_r.z_index = 0; add_child(vine_r)
		for vi in range(3):
			var lf := _r(hp.x + plat_w/2 - 2 + vi * 3, hp.y - 26 + vi * 12, 8, 5, Color(0.15, 0.5, 0.1))
			lf.z_index = 0; add_child(lf)

		var ha := _area(Vector2(hp.x, hp.y - 12), Vector2(30, 24), "SnakeHide_%d"%i)
		ha.monitoring = false; ha.body_entered.connect(_on_snake_hide.bind(i)); add_child(ha); _snake_hides.append(ha)

	for i in 3:
		var bpos := Vector2(44*TILE + i * 3 * TILE, surface - 12)
		var bush := _r(bpos.x - 14, bpos.y - 18, 28, 20, Color(0.15, 0.4, 0.1))
		bush.z_index = 0; add_child(bush)
		var berry := _r(bpos.x - 3, bpos.y - 10, 6, 6, Color(0.85, 0.1, 0.1))
		berry.z_index = 1; add_child(berry)
		var ba := _area(bpos, Vector2(28, 24), "Berry_%d"%i)
		ba.monitoring = true; ba.body_entered.connect(_on_berry.bind(i)); add_child(ba); _berry_areas.append(ba)

	var yx := 66*TILE; var yy := surface - 8
	var yajna_base := _r(yx - 60, yy, 120, 16, Color(0.5, 0.35, 0.15))
	yajna_base.z_index = 0; add_child(yajna_base)
	var yajna_altar := _r(yx - 30, yy - 16, 60, 24, Color(0.4, 0.28, 0.1))
	yajna_altar.z_index = 1; add_child(yajna_altar)
	var yajna_top := _r(yx - 12, yy - 24, 24, 8, Color(0.15, 0.1, 0.05))
	yajna_top.z_index = 1; add_child(yajna_top)
	var wood1 := _r(yx - 9, yy - 22, 18, 3, Color(0.35, 0.2, 0.08))
	wood1.z_index = 1; add_child(wood1)
	var wood2 := _r(yx - 9, yy - 20, 18, 3, Color(0.3, 0.18, 0.06))
	wood2.z_index = 1; add_child(wood2)
	add_child(_hint(Vector2(yx-24, yy - 60), "[Light Yajna Fire]", Color(0.9, 0.5, 0.2, 0.7)))
	var ya := _area(Vector2(yx, yy - 16), Vector2(80, 60), "YajnaArea")
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
	if body.name == "Boulder" or body == _player:
		if not _cage_dropped:
			_cage_dropped = true
			var cv := get_node_or_null("CageVisual") as ColorRect
			var cbv := get_node_or_null("CageBars") as ColorRect
			if cv:
				var tw := create_tween()
				tw.tween_property(cv, "color", Color(0.4, 0.35, 0.25, 0.9), 0.6)
			if cbv:
				var tw := create_tween()
				tw.tween_property(cbv, "color", Color(0.5, 0.45, 0.3, 0.8), 0.6)
			get_node_or_null("LetterArea").monitoring = true
			_show_prompt("The cage drops! Check inside.")

func _on_plate_exited(_body: Node) -> void:
	pass

func _on_snake_hide(body: Node, idx: int) -> void:
	if body == _player and _berries >= 3 and _snakes_saved < 3:
		_snake_hides[idx].monitoring = false; _snakes_saved += 1
		var msgs := [
			"Baby snake emerges! (%d/3)" % _snakes_saved,
			"Another one! Betaal: 'Playing nursemaid now?' (%d/3)" % _snakes_saved,
			"Betaal: 'Hmph. Even snakes have better parenting skills.' (%d/3)" % _snakes_saved,
		]
		_show_prompt(msgs[_snakes_saved - 1])
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
			_show_prompt("All baby snakes saved! A bowl of milk appears.")
			await get_tree().create_timer(1.5).timeout
			_play_nageshwari_cutscene()

func _play_nageshwari_cutscene() -> void:
	_can_move = false
	_cutscene_box = CanvasLayer.new(); _cutscene_box.layer = 20; add_child(_cutscene_box)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.anchor_left = 0; bg.anchor_top = 0; bg.anchor_right = 1; bg.anchor_bottom = 1
	_cutscene_box.add_child(bg)
	var label := Label.new()
	label.text = "Nageshwari watches from the shadows...\nHer children are safe."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 0.9))
	label.position = Vector2(200, 500); label.size = Vector2(400, 100)
	_cutscene_box.add_child(label)
	await get_tree().create_timer(3.0).timeout
	_cutscene_box.queue_free(); _cutscene_box = null
	_can_move = true

func _on_berry(body: Node, idx: int) -> void:
	if body == _player and _berries < 3:
		_berries += 1
		if _berry_areas[idx]: _berry_areas[idx].queue_free(); _berry_areas[idx] = null
		var msgs := ["Found a berry! (%d/3)", "Another berry! (%d/3)", "Three berries! Now lure the babies."]
		_show_prompt(msgs[_berries - 1] % _berries)
		if _berries >= 3:
			_stage_hint.text = "Berries gathered! Climb to the snake hideouts."
			for h in _snake_hides: h.monitoring = true

func _show_prompt(text: String) -> void:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1, 1, 0.8))
	l.position = Vector2(20, 20); l.z_index = 10; add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 3.0).set_delay(2.5)
	tw.finished.connect(l.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and _can_move: _handle_interact()
		elif event.keycode == KEY_ESCAPE:
			add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())

func _handle_interact() -> void:
	if _near_interact.get("arrow", false) and not _arrow_obtained:
		_arrow_obtained = true
		if _snake_sprite:
			_snake_sprite.texture = preload("res://assets/art/rooms/snakedeadwithoutarrow.png")
		_show_prompt("You retrieve the arrow from the snake's body.\nBetaal: 'An experienced warrior's work...'")
		_stage_hint.text = "Got the arrow! Push the boulder onto the plate."
	elif _near_interact.get("letter", false) and not _letter_read and _cage_dropped:
		_letter_read = true
		_show_prompt("You unfold the letter...\n\n'Forgive me, Nagesh. My duty bound me to kill you.\nYour prince needed the vow fulfilled.\nMay your children find peace.'\n- Shaktinath")
		_stage_hint.text = "Pick flowers from the field ahead."
	elif _near_interact.get("flower", false) and _letter_read:
		_flowers_collected = true
		_show_prompt("You gather a bunch of wildflowers.\nBetaal: 'Nature's offering for the ritual...'")
		_stage_hint.text = "Enter the garden ahead. Gather berries to lure baby snakes!"
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
	box.show_text("Shaktinath and Nageshwari stand before you.\nNageshwari glides toward the flame.\n\nWho completes the sacrifice?")

func _on_choice(fulfill: bool) -> void:
	if _choice_made: return
	_choice_made = true; _can_move = false
	if fulfill:
		_show_prompt("Shaktinath steps forward, but Nageshwari enters the flame first.\n'Let the prince live. My children are safe now.'\nBetaal: 'A mother's love... stronger than revenge.'")
	else:
		_show_prompt("Nageshwari glides into the sacred fire.\n'My vengeance dies with me.'\nBetaal: 'Maternal instinct overcomes all. The cycle ends.'")
	await get_tree().create_timer(4.0).timeout
	_show_prompt("Your remaining time is consumed by the flame...")
	await get_tree().create_timer(2.5).timeout
	_exit_room()

func _exit_room() -> void:
	if _exiting: return
	_exiting = true
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.cover(0.8)
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("exit_hunting_grounds"): g.exit_hunting_grounds()
	else: queue_free()

func _show_vn_dialogue(title: String, text: String, duration: float) -> void:
	var vs := DisplayServer.window_get_size()
	var vn_layer := CanvasLayer.new()
	vn_layer.layer = 25; vn_layer.name = "VNDialogue"; add_child(vn_layer)
	var vn_box := ColorRect.new()
	vn_box.color = Color(0.05, 0.05, 0.1, 0.9)
	vn_box.position = Vector2(20, vs.y - 220)
	vn_box.size = Vector2(vs.x - 40, 200)
	vn_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vn_layer.add_child(vn_box)
	var vn_name := Label.new()
	vn_name.text = title
	vn_name.add_theme_font_size_override("font_size", 20)
	vn_name.add_theme_color_override("font_color", Color(0.6, 0.7, 1, 1))
	vn_name.position = Vector2(40, vs.y - 210)
	vn_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vn_layer.add_child(vn_name)
	var vn_text := Label.new()
	vn_text.text = text
	vn_text.add_theme_font_size_override("font_size", 16)
	vn_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 1))
	vn_text.position = Vector2(40, vs.y - 180)
	vn_text.size = Vector2(vs.x - 80, 150)
	vn_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vn_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vn_layer.add_child(vn_text)
	await get_tree().create_timer(duration).timeout
	vn_layer.queue_free()

func reveal() -> void:
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.reveal(0.8)
	_can_move = true
	await _show_vn_dialogue("Betaal", "Well, I believe we could play some games to pass the time...", 3.0)
	_show_vn_dialogue("Betaal", "O Mighty Rajan, here are one of my stories!", 3.0)

func _physics_process(delta: float) -> void:
	if not _can_move or not _player: return
	var dir := Input.get_axis("move_left", "move_right")
	_player.velocity.x = dir * MOVE_SPEED
	_player.velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and _player.is_on_floor(): _player.velocity.y = JUMP_VEL
	_player.move_and_slide()
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam: cam.position = _player.position
