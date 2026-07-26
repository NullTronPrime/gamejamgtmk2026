extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")
const HumanoidRig := preload("res://scripts/shared/humanoid_rig.gd")
const GRAVITY := 1400.0; const JUMP_VEL := -480.0; const MOVE_SPEED := 180.0
const CLIMB_SPEED := 120.0; const TILE := 64

var _player: CharacterBody2D
var _can_move := false; var _exiting := false; var _on_ladder := false; var _climbing := false

var _key := false; var _cage := false; var _bones := false; var _book := false
var _meat := false; var _potion := false; var _assembled := false; var _stage_hint: Label

func _ready() -> void:
	_build_floor(); _build_walls(); _build_furniture(); _build_interactables(); _spawn_player()
	_setup_camera(); _setup_ui(); reveal.call_deferred()

func _tex(path: String) -> Texture2D: return load(path)

func _r(x, y, w, h, col: Color, z: int = 0) -> ColorRect:
	var r := ColorRect.new(); r.position = Vector2(x, y); r.size = Vector2(w, h)
	r.color = col; r.z_index = z; r.mouse_filter = 2; return r

func _build_floor() -> void:
	var lt := _tex("res://assets/art/rooms/wall_tile_light.png")
	var dt := _tex("res://assets/art/rooms/wall_tile_dark.png")
	for x in range(0, 80*TILE, TILE):
		if lt: var s := Sprite2D.new(); s.texture = lt; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; s.position = Vector2(x+TILE/2, 10*TILE+TILE/2); s.z_index = -2; add_child(s)
		if dt: var s := Sprite2D.new(); s.texture = dt; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; s.position = Vector2(x+TILE/2, 11*TILE+TILE/2); s.z_index = -2; add_child(s)
		_solid(Vector2(x+TILE/2, 10*TILE+TILE), Vector2(TILE, TILE*2))

func _build_walls() -> void:
	for x in [0, 79*TILE]:
		var dw := _tex("res://assets/art/rooms/wall_tile_dark.png"); var lw := _tex("res://assets/art/rooms/wall_tile_light.png")
		for yi in range(0, 10*TILE, TILE):
			var tex := dw if (yi/TILE)%2==0 else lw
			if tex: var s := Sprite2D.new(); s.texture = tex; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; s.position = Vector2(x+TILE/2, yi+TILE/2); s.z_index = -2; add_child(s)
		_solid(Vector2(x+TILE/2, 5*TILE), Vector2(TILE, 10*TILE))

func _solid(pos: Vector2, size: Vector2) -> void:
	var s := StaticBody2D.new(); s.collision_layer = 1; s.position = pos
	var c := CollisionShape2D.new(); c.shape = RectangleShape2D.new(); c.shape.size = size; s.add_child(c); add_child(s)

func _sprite_or_rect(tex, path: String, pos: Vector2, z: int, fallback_col: Color, fallback_size: Vector2) -> Node:
	if tex:
		var s := Sprite2D.new(); s.texture = tex; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = pos; s.z_index = z; add_child(s); return s
	else:
		var r := ColorRect.new(); r.size = fallback_size; r.color = fallback_col
		r.position = pos - fallback_size/2; r.z_index = z; r.mouse_filter = 2; add_child(r); return r

func _build_furniture() -> void:
	var bks := _tex("res://assets/art/rooms/bookshelf.png")
	if bks: for yi in 4:
		var s := Sprite2D.new(); s.texture = bks; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(32*TILE, (3+yi*2)*TILE + bks.get_height()/2); s.z_index = -1; add_child(s)
	else: for yi in 4: add_child(_r(32*TILE-16, (3+yi*2)*TILE, 32, 64, Color(0.3,0.2,0.08), -1))

	var lad := Area2D.new(); lad.name = "LadderArea"
	var lc := CollisionShape2D.new(); lc.shape = RectangleShape2D.new(); lc.shape.size = Vector2(28, 8*TILE)
	lad.add_child(lc); lad.position = Vector2(36*TILE+10, 8*TILE)
	lad.body_entered.connect(_on_ladder_entered); lad.body_exited.connect(_on_ladder_exited); add_child(lad)

	var ns := _tex("res://assets/art/rooms/nightstand_large.png")
	var ns_fb := Vector2(28, 56)
	for i in 4:
		var nx := (4 + i*5) * TILE
		_sprite_or_rect(ns, "", Vector2(nx, 10*TILE - 28), -1, Color(0.15,0.12,0.06,0.8), ns_fb)
		if i > 0: add_child(_r(nx-4, 10*TILE-36, 8, 8, Color(0.9,0.8,0.4), 0))

	var fx := 26 * TILE
	var fountain_frames := []
	for fn in ["f1","f2","f3","f4"]:
		var ft := _tex("res://assets/art/rooms/fountain/%s.png" % fn)
		if ft: fountain_frames.append(ft)
	var fountain_base := ColorRect.new()
	fountain_base.size = Vector2(48, 32); fountain_base.color = Color(0.3,0.25,0.2,0.6)
	fountain_base.position = Vector2(fx-24, 10*TILE-32); fountain_base.z_index = 0; add_child(fountain_base)
	if not fountain_frames.is_empty():
		var sph := Sprite2D.new(); sph.name = "FountainSprite"
		sph.texture = fountain_frames[0]; sph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sph.position = Vector2(fx, 10*TILE - 32); sph.z_index = 1; add_child(sph)
		var fr := 0; var tw := create_tween().set_loops()
		tw.tween_interval(0.6); tw.tween_callback(func(): fr = (fr+1)%fountain_frames.size(); sph.texture = fountain_frames[fr])
	else:
		var fb := ColorRect.new(); fb.size = Vector2(32, 24); fb.color = Color(0.6,0.5,0.4)
		fb.position = Vector2(fx-16, 10*TILE-36); fb.z_index = 1; fb.mouse_filter = 2; add_child(fb)

	var cx := 42 * TILE
	add_child(_r(cx-32, 10*TILE-48, 64, 48, Color(0.35,0.3,0.2), 0))
	add_child(_r(cx-24, 10*TILE-42, 48, 36, Color(0.12,0.1,0.06), 0))

	var t1 := _tex("res://assets/art/rooms/table_variant1.png"); var t2 := _tex("res://assets/art/rooms/table_variant2.png")
	var ch := _tex("res://assets/art/rooms/chair.png")
	for i in 2:
		var tx2 := (52 + i*3) * TILE
		_sprite_or_rect(t1, "", Vector2(tx2, 10*TILE-16), -1, Color(0.35,0.25,0.1,0.8), Vector2(40, 16))
		_sprite_or_rect(ch, "", Vector2(tx2-20, 10*TILE-12), -1, Color(0.25,0.15,0.05,0.8), Vector2(16, 20))
		_sprite_or_rect(ch, "", Vector2(tx2+20, 10*TILE-12), -1, Color(0.25,0.15,0.05,0.8), Vector2(16, 20))
	add_child(_r(53*TILE-8, 10*TILE-24, 16, 12, Color(0.7,0.15,0.1), 1))

func _area(pos: Vector2, size: Vector2, name: String) -> Area2D:
	var a := Area2D.new(); a.name = name; a.position = pos; a.collision_mask = 1
	var s := CollisionShape2D.new(); s.shape = RectangleShape2D.new(); s.shape.size = size; a.add_child(s); return a

func _build_interactables() -> void:
	var ka := _area(Vector2(4*TILE, 10*TILE-16), Vector2(48,40), "KeyArea")
	ka.body_entered.connect(_on_near.bind("key")); add_child(ka)
	add_child(_r(4*TILE-16, 10*TILE-60, 32, 12, Color(0.9,0.7,0.2,0.6), 5))

	var ca := _area(Vector2(42*TILE, 10*TILE-20), Vector2(72,60), "CageArea")
	ca.body_entered.connect(_on_near.bind("cage")); add_child(ca)
	add_child(_r(42*TILE-24, 10*TILE-56, 48, 12, Color(0.9,0.6,0.3,0.5), 5))

	var ba := _area(Vector2(36*TILE+14, 4*TILE+TILE/2), Vector2(48,48), "BookArea")
	ba.body_entered.connect(_on_near.bind("book")); add_child(ba)
	add_child(_r(36*TILE-8, 4*TILE+10, 44, 12, Color(0.8,0.5,0.2,0.5), 5))

	var ma := _area(Vector2(53*TILE, 10*TILE-16), Vector2(48,40), "MeatArea")
	ma.body_entered.connect(_on_near.bind("meat")); add_child(ma)
	add_child(_r(53*TILE-16, 10*TILE-52, 32, 12, Color(0.9,0.3,0.2,0.5), 5))

	var fa := _area(Vector2(26*TILE, 10*TILE-24), Vector2(80,60), "FountainArea")
	fa.body_entered.connect(_on_near.bind("fountain")); add_child(fa)

	var pa := _area(Vector2(26*TILE, 9*TILE), Vector2(48,48), "PotionArea")
	pa.monitoring = false; pa.body_entered.connect(_on_near.bind("potion")); add_child(pa)

	var pv := ColorRect.new(); pv.name = "PotionVisual"
	pv.color = Color(0.2,0.6,0.8,0.0); pv.size = Vector2(20,28)
	pv.position = Vector2(26*TILE-10, 9*TILE-8); pv.z_index = 1; add_child(pv)

func _spawn_player() -> void:
	_player = CharacterBody2D.new(); _player.name = "Player"; _player.collision_layer = 1; _player.collision_mask = 1
	var shape := RectangleShape2D.new(); shape.size = Vector2(28, 88)
	var col := CollisionShape2D.new(); col.shape = shape; col.position = Vector2(0, 12); _player.add_child(col)
	HumanoidRig.build(_player, Color(0.55,0.4,0.25), Color(0.8,0.65,0.5))
	for c in _player.get_children(): if c is Polygon2D: c.z_index = 1
	_player.position = Vector2(2*TILE, 9*TILE); add_child(_player)

func _setup_camera() -> void:
	var cam := Camera2D.new(); cam.name = "Camera2D"
	cam.zoom = Vector2(1.8, 1.8); add_child(cam); cam.make_current()

func _setup_ui() -> void:
	_stage_hint = Label.new(); _stage_hint.add_theme_font_size_override("font_size", 11)
	_stage_hint.add_theme_color_override("font_color", Color(0.8,0.8,0.7,0.6))
	_stage_hint.anchor_left = 0.5; _stage_hint.anchor_top = 0.0; _stage_hint.anchor_right = 0.5; _stage_hint.anchor_bottom = 0.0
	_stage_hint.position = Vector2(-120, 60); _stage_hint.mouse_filter = 2; add_child(_stage_hint)

var _near_interact: Dictionary = {}

func _on_near(body: Node, id: String) -> void:
	if body == _player: _near_interact[id] = true

func _on_ladder_entered(body: Node) -> void:
	if body == _player: _on_ladder = true

func _on_ladder_exited(body: Node) -> void:
	if body == _player: _on_ladder = false; _climbing = false

func _show_prompt(text: String) -> void:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1,1,0.8)); l.position = Vector2(20, 20); l.z_index = 10; add_child(l)
	var tw = create_tween(); tw.tween_property(l, "modulate:a", 0.0, 3.0).set_delay(2.0); await tw.finished; l.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and _can_move: _handle_interact()
		elif event.keycode == KEY_ESCAPE: add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())

func _handle_interact() -> void:
	if _near_interact.get("key",false) and not _key:
		_key = true; _show_prompt("Found a rusty key in the statue!")
	elif _near_interact.get("cage",false) and _key and not _cage:
		_cage = true; _bones = true; _show_prompt("Unlocked the cage! Retrieved the Bones.")
		_stage_hint.text = "Got bones! Climb the ladder to find the book."
	elif _near_interact.get("book",false) and not _book and _on_ladder:
		_book = true; _show_prompt("Found an ancient Book on the shelf!")
		_stage_hint.text = "Got the book! Take meat from the table."
	elif _near_interact.get("meat",false) and not _meat:
		_meat = true; _show_prompt("Took the fresh Meat!")
		_stage_hint.text = "Got meat! Offer bones + book + meat at the fountain."
	elif _near_interact.get("potion",false) and not _potion:
		var pv := get_node_or_null("PotionVisual")
		_potion = true
		if pv: pv.queue_free()
		_show_prompt("Betaal hands you the Potion of Life!")
		_stage_hint.text = "Got potion! Assemble the Lion at the fountain."
	elif _near_interact.get("fountain",false):
		if _bones and _book and _meat and not _potion:
			var pv := get_node_or_null("PotionVisual")
			if pv:
				var tw := create_tween()
				tw.tween_property(pv, "color", Color(0.2,0.6,0.8,1.0), 0.6)
			var pa := get_node_or_null("PotionArea")
			if pa: pa.monitoring = true
			_show_prompt("The fountain glows! Betaal appears with a potion.")
		elif _bones and _book and _meat and _potion and not _assembled:
			_assemble_lion()
		else:
			_show_prompt("Need bones, book, and meat for the fountain.")

func _assemble_lion() -> void:
	_assembled = true; _can_move = false; _stage_hint.text = "The Lion awakens!"
	for i in 4:
		var n := ColorRect.new()
		n.size = Vector2(24, 24)
		n.color = [Color(0.9,0.9,0.8), Color(0.8,0.3,0.2), Color(0.6,0.4,0.15), Color(0.2,0.6,0.8)][i]
		n.position = Vector2(26*TILE+i*28-40, 9*TILE-16)
		n.z_index = 5; add_child(n)
		var tw = create_tween()
		tw.tween_property(n, "position", Vector2(26*TILE+i*28-40, 8*TILE-16), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		await get_tree().create_timer(0.3).timeout
	_show_prompt("The Lion takes shape! You offer your time. The exit opens.")
	await get_tree().create_timer(2.0).timeout; _exit_room()

func _exit_room() -> void:
	if _exiting: return; _exiting = true; _can_move = false
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.cover(0.8)
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("exit_library_room"):
		g.exit_library_room()
	else:
		queue_free()

func reveal() -> void:
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.reveal(0.8)
	_can_move = true

func _physics_process(delta: float) -> void:
	if not _can_move or not _player: return
	var dir := Input.get_axis("move_left", "move_right"); var vert := Input.get_axis("move_up", "move_down")
	var space := Input.is_action_pressed("jump")
	_climbing = _on_ladder and (space or abs(vert) > 0.1)
	if _climbing:
		_player.velocity.x = dir * MOVE_SPEED * 0.5; _player.velocity.y = -CLIMB_SPEED if space else vert * CLIMB_SPEED
	else:
		if Input.is_action_just_pressed("jump") and _player.is_on_floor(): _player.velocity.y = JUMP_VEL
		_player.velocity.x = dir * MOVE_SPEED; _player.velocity.y += GRAVITY * delta
		if _on_ladder and abs(vert) > 0.1 and _player.velocity.y > 0: _player.velocity.y = 0
	_player.move_and_slide()
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam: cam.position = _player.position
