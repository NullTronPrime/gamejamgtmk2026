extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")

const GRAVITY := 1400.0; const JUMP_VEL := -480.0; const MOVE_SPEED := 180.0
const SPRINT_SPEED_BONUS := 0.5; const TILE := 64; const FLOOR_Y := 12 * TILE
const ROOM_LEFT := -8 * TILE; const ROOM_RIGHT := 84 * TILE

var _player: CharacterBody2D
var _can_move := false; var _exiting := false; var _stage_hint: Label

var _has_key := false; var _has_book := false; var _has_meat := false; var _has_potion := false
var _lion_done := false; var _potion_used := false
var _bone_bodies: Array[RigidBody2D] = []

var _fountain_frames: Array[Texture2D] = []
var _fountain_sprite: Sprite2D
var _fountain_idx := 0
var _parallax_layers: Array[Dictionary] = []
var _fountain_time := 0.0

const SKELETON_ITEMS := ["skeleton_neck","skeleton_skull","skeleton_arms","skeleton_ribs","skeleton_legs","skeleton_tail"]
const PART_FILES := ["part_neck","part_skull","part_arms","part_ribs","part_legs","part_tail"]
const GROUND_FILES := ["ground_neck","ground_skull","ground_arms","ground_ribs","ground_legs","ground_tail"]

var _pedestal_placed := [false, false, false, false, false, false]
var _bgm: AudioStreamPlayer

func _ready() -> void:
	_build_background(); _build_floor(); _build_walls()
	_build_furniture(); _build_pickups(); _build_interactables()
	_spawn_player(); _setup_camera(); _setup_ui(); reveal.call_deferred()
	_setup_audio()

func _tex(path: String) -> Texture2D: return load(path)

func _r(x, y, w, h, col: Color, z: int = 0) -> ColorRect:
	var r := ColorRect.new(); r.position = Vector2(x, y); r.size = Vector2(w, h)
	r.color = col; r.z_index = z; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; return r

func _build_background() -> void:
	var pl := CanvasLayer.new()
	pl.name = "ParallaxBackdrop"
	pl.layer = -10
	add_child(pl)
	var p_layers = [
		{ "tex": "g2.png", "factor": 0.02 },
		{ "tex": "g1.png", "factor": 0.06 },
		{ "tex": "g3.png", "factor": 0.14 },
	]
	var vs = DisplayServer.window_get_size()
	for l in p_layers:
		var tex = load("res://assets/sprites/background/" + l["tex"])
		if not tex:
			continue
		var tex_w = tex.get_width()
		var tex_h = tex.get_height()
		var scale_y = vs.y / tex_h
		var scale_x = scale_y
		var scaled_w = tex_w * scale_x
		var count = ceil(vs.x / scaled_w) + 2
		var sprites = []
		for i in range(count):
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.scale = Vector2(scale_x, scale_y)
			spr.centered = false
			spr.position = Vector2((i - 1) * scaled_w, 0)
			pl.add_child(spr)
			sprites.append(spr)
		_parallax_layers.append({
			"sprites": sprites, "factor": l["factor"], "tex_w": scaled_w
		})

func _build_floor() -> void:
	var lt := _tex("res://assets/art/rooms/wall_tile_light.png")
	var dt := _tex("res://assets/art/rooms/wall_tile_dark.png")
	for x in range(ROOM_LEFT, ROOM_RIGHT, TILE):
		if lt:
			var s := Sprite2D.new(); s.texture = lt; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.position = Vector2(x+TILE/2, FLOOR_Y+TILE/2); s.z_index = -2; add_child(s)
		if dt:
			var s := Sprite2D.new(); s.texture = dt; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.position = Vector2(x+TILE/2, FLOOR_Y+TILE+TILE/2); s.z_index = -2; add_child(s)
		var s3 := Sprite2D.new(); s3.texture = dt; s3.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s3.position = Vector2(x+TILE/2, FLOOR_Y+TILE*2+TILE/2); s3.z_index = -2; add_child(s3)
		_solid(Vector2(x+TILE/2, FLOOR_Y+TILE/2), Vector2(TILE, TILE))

func _solid(pos: Vector2, size: Vector2) -> void:
	var s := StaticBody2D.new(); s.collision_layer = 1; s.position = pos
	var c := CollisionShape2D.new(); c.shape = RectangleShape2D.new(); c.shape.size = size; s.add_child(c); add_child(s)

func _build_walls() -> void:
	for x in [0, 79*TILE]:
		_solid(Vector2(x + TILE/2, FLOOR_Y/2), Vector2(TILE, FLOOR_Y))

func _build_furniture() -> void:
	var px := 31 * TILE
	var pt := _tex("res://assets/art/rooms/pedestal.png")
	if pt:
		var psp := Sprite2D.new(); psp.texture = pt; psp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		psp.position = Vector2(px, FLOOR_Y - 28); psp.z_index = -1; add_child(psp)

	var ped_solid := StaticBody2D.new(); ped_solid.position = Vector2(px, FLOOR_Y - 42)
	var ped_col := CollisionShape2D.new(); ped_col.shape = RectangleShape2D.new(); ped_col.shape.size = Vector2(96, 28)
	ped_solid.add_child(ped_col); add_child(ped_solid)

	var ped_parts := Node2D.new(); ped_parts.name = "PedestalParts"
	ped_parts.position = Vector2(px, FLOOR_Y - 120); add_child(ped_parts)
	for i in 6:
		var ptex := _tex("res://assets/art/skeleton/%s.png" % PART_FILES[i])
		if ptex:
			var ps := Sprite2D.new(); ps.name = "PedestalPart%d" % i
			ps.texture = ptex; ps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ps.position = Vector2.ZERO; ps.visible = false; ps.z_index = 2 + i; ped_parts.add_child(ps)

func _make_bone_pickup(item_id: String, tex_path: String, pos: Vector2, idx: int) -> void:
	var body := RigidBody2D.new()
	body.position = pos; body.z_index = 1
	body.gravity_scale = 0.5; body.lock_rotation = false
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var sp := Sprite2D.new()
	sp.texture = _tex(tex_path); sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sp)
	var poly := CollisionPolygon2D.new()
	var img := sp.texture.get_image()
	if img:
		var bm := BitMap.new()
		bm.create_from_image_alpha(img)
		var polys := bm.opaque_to_polygons(Rect2i(0, 0, img.get_width(), img.get_height()), 0.0)
		if polys.size() > 0:
			poly.polygon = polys[0]
		else:
			poly.polygon = PackedVector2Array([Vector2(-8,-8),Vector2(8,-8),Vector2(8,8),Vector2(-8,8)])
	body.add_child(poly)
	var mat := PhysicsMaterial.new(); mat.friction = 0.7; mat.bounce = 0.05
	body.physics_material_override = mat
	body.set_meta("pickup_id", item_id)
	_bone_bodies.append(body)
	add_child(body)

func _build_pickups() -> void:
	var bone_positions: Array[Vector2] = [
		Vector2(12 * TILE, FLOOR_Y - 3 * TILE),
		Vector2(28 * TILE, FLOOR_Y - 4 * TILE),
		Vector2(42 * TILE, FLOOR_Y - 2 * TILE),
		Vector2(55 * TILE, FLOOR_Y - 3 * TILE),
		Vector2(68 * TILE, FLOOR_Y - 4 * TILE),
		Vector2(20 * TILE, FLOOR_Y - 5 * TILE),
	]
	bone_positions.shuffle()
	for i in 6:
		_make_bone_pickup(SKELETON_ITEMS[i], "res://assets/art/skeleton/%s.png" % GROUND_FILES[i], bone_positions[i], i)

func _build_interactables() -> void:
	var fx: int = 39 * TILE
	var px := 31 * TILE

	for i in 4:
		var sx: int = (19 + i*5) * TILE
		var a := Area2D.new(); a.name = "StatueArea%d" % i
		var s := CollisionShape2D.new(); s.shape = RectangleShape2D.new(); s.shape.size = Vector2(48, 48)
		a.add_child(s); a.position = Vector2(sx, FLOOR_Y-28)
		a.body_entered.connect(_on_near.bind("statue%d" % i)); add_child(a)

	var ka := Area2D.new(); ka.name = "KeyArea"
	var kc := CollisionShape2D.new(); kc.shape = RectangleShape2D.new(); kc.shape.size = Vector2(48, 48)
	ka.add_child(kc); ka.position = Vector2(19*TILE, FLOOR_Y-28)
	ka.body_entered.connect(_on_near.bind("key")); add_child(ka)

	var ba := Area2D.new(); ba.name = "BookArea"
	var bc := CollisionShape2D.new(); bc.shape = RectangleShape2D.new(); bc.shape.size = Vector2(48, 48)
	ba.add_child(bc); ba.position = Vector2(9*TILE, 4*TILE)
	ba.body_entered.connect(_on_near.bind("book")); add_child(ba)
	var scroll_sp := Sprite2D.new()
	scroll_sp.texture = preload("res://assets/art/rooms/scroll.png")
	scroll_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll_sp.scale = Vector2(1.5, 1.5)
	scroll_sp.position = Vector2(9*TILE, 4*TILE - 4)
	scroll_sp.z_index = 1
	add_child(scroll_sp)

	var ma := Area2D.new(); ma.name = "MeatArea"
	var mc := CollisionShape2D.new(); mc.shape = RectangleShape2D.new(); mc.shape.size = Vector2(48, 40)
	ma.add_child(mc); ma.position = Vector2(58*TILE, FLOOR_Y-16)
	ma.body_entered.connect(_on_near.bind("meat")); add_child(ma)

	var fa := Area2D.new(); fa.name = "FountainArea"
	var fc := CollisionShape2D.new(); fc.shape = RectangleShape2D.new(); fc.shape.size = Vector2(80, 60)
	fa.add_child(fc); fa.position = Vector2(fx, FLOOR_Y-24)
	fa.body_entered.connect(_on_near.bind("fountain")); add_child(fa)

	_fountain_frames = []
	for fn in ["f1","f2","f3","f4"]:
		var ft := _tex("res://assets/art/rooms/fountain/%s.png" % fn)
		if ft: _fountain_frames.append(ft)
	if not _fountain_frames.is_empty():
		_fountain_sprite = Sprite2D.new(); _fountain_sprite.name = "FountainSprite"
		_fountain_sprite.texture = _fountain_frames[0]; _fountain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_fountain_sprite.position = Vector2(fx, FLOOR_Y - 32); _fountain_sprite.z_index = 1; add_child(_fountain_sprite)

		var pt := CPUParticles2D.new(); pt.name = "FountainParticles"
		pt.position = Vector2(fx, FLOOR_Y - 44)
		pt.amount = 12; pt.lifetime = 1.2; pt.one_shot = false; pt.explosiveness = 0.0
		pt.direction = Vector2(0, -1); pt.spread = 30.0; pt.gravity = Vector2(0, -80)
		pt.initial_velocity_min = 20; pt.initial_velocity_max = 50
		pt.scale_amount_min = 0.5
		pt.scale_amount_max = 0.5
		pt.color = Color(0.6, 0.8, 1.0, 0.6); pt.emitting = true
		add_child(pt)

		var bt := _tex("res://assets/art/rooms/lifebottle.png")
		if bt:
			var bs := Sprite2D.new(); bs.texture = bt; bs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bs.modulate = Color(1, 1, 1, 0.5); bs.position = Vector2(fx, FLOOR_Y - 48); bs.z_index = 2
			bs.name = "FountainBottle"; add_child(bs)
			var bla := Area2D.new(); bla.name = "BottleArea"
			var blc := CollisionShape2D.new(); blc.shape = RectangleShape2D.new(); blc.shape.size = Vector2(32, 32)
			bla.add_child(blc); bla.position = Vector2(fx, FLOOR_Y - 48)
			bla.body_entered.connect(_on_near.bind("fountain_bottle"))
			add_child(bla)

	var pa := Area2D.new(); pa.name = "PedestalArea"
	var pc := CollisionShape2D.new(); pc.shape = RectangleShape2D.new(); pc.shape.size = Vector2(96, 64)
	pa.add_child(pc); pa.position = Vector2(px, FLOOR_Y-28)
	pa.body_entered.connect(_on_near.bind("pedestal")); add_child(pa)

	var phint := Label.new(); phint.name = "PedestalHint"
	phint.text = "Right Click the Pedestal"
	phint.add_theme_font_size_override("font_size", 12)
	phint.add_theme_color_override("font_color", Color(1, 1, 0, 0.8))
	phint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phint.position = Vector2(px - 80, FLOOR_Y - 180)
	phint.size = Vector2(160, 24)
	phint.z_index = 10
	phint.visible = false
	add_child(phint)

func _spawn_player() -> void:
	_player = CharacterBody2D.new(); _player.name = "Player"
	_player.collision_layer = 1; _player.collision_mask = 1
	var shape := RectangleShape2D.new(); shape.size = Vector2(28, 88)
	var col := CollisionShape2D.new(); col.shape = shape; col.position = Vector2(0, 12); _player.add_child(col)
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
		_player.add_child(spr)
	_player.position = Vector2(2*TILE, FLOOR_Y - 3*TILE); add_child(_player)

func _setup_camera() -> void:
	var cam := Camera2D.new(); cam.name = "Camera2D"
	cam.zoom = Vector2(1.8, 1.8); add_child(cam); cam.make_current()

func _setup_ui() -> void:
	_stage_hint = Label.new(); _stage_hint.add_theme_font_size_override("font_size", 11)
	_stage_hint.add_theme_color_override("font_color", Color(0.8,0.8,0.7,0.6))
	_stage_hint.anchor_left = 0.5; _stage_hint.anchor_top = 0.0
	_stage_hint.anchor_right = 0.5; _stage_hint.anchor_bottom = 0.0
	_stage_hint.position = Vector2(-120, 60); _stage_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_stage_hint)

func _setup_audio() -> void:
	var s := AudioStreamPlayer.new(); s.name = "BGM"
	s.stream = load("res://assets/audio/bgm/library_room.mp3")
	s.autoplay = true; s.volume_db = -12.0; add_child(s); _bgm = s

var _near_interact: Dictionary = {}

func _on_near(body: Node, id: String) -> void:
	if body == _player: _near_interact[id] = true

func _show_prompt(text: String) -> void:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1,1,0.8)); l.position = Vector2(20, 20); l.z_index = 10; add_child(l)
	var tw = create_tween(); tw.tween_property(l, "modulate:a", 0.0, 3.0).set_delay(2.0)
	tw.finished.connect(l.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			var inv := get_node_or_null("/root/Game/InventoryLayer/InventoryUI")
			if inv and inv.has_method("toggle"): inv.toggle()
		elif event.keycode == KEY_E and _can_move: _handle_interact()
		elif event.keycode == KEY_ESCAPE: add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _can_move:
			var mpos := get_global_mouse_position()
			var bottle := get_node_or_null("FountainBottle") as Sprite2D
			if bottle and not _has_potion and _near_interact.get("fountain_bottle", false) and bottle.global_position.distance_to(mpos) < 28:
				_trigger_potion()
				return
			for b in _bone_bodies:
				if not is_instance_valid(b): continue
				if b.global_position.distance_to(mpos) > 40: continue
				if b.global_position.distance_to(_player.global_position) > 120: continue
				var pid = b.get_meta("pickup_id", "") as String
				if pid != "" and GameInventory.add_item(pid):
					b.queue_free()
					_bone_bodies.erase(b)
				break
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _can_move and _near_interact.get("pedestal", false):
			if not _lion_done:
				_place_on_pedestal()
			elif _lion_done and (_has_potion or GameInventory.has_item("life_potion")) and not _potion_used:
				_use_potion_on_skeleton()
			elif _lion_done and not _has_potion and not _potion_used:
				_show_prompt("You need the Potion of Life from the fountain.")

func _handle_interact() -> void:
	if not _has_key and _near_interact.get("key", false):
		_has_key = true; _show_prompt("Found a rusty key! Maybe it opens something valuable.")
		_stage_hint.text = "Got the key! Search for more items."
		return
	if not _has_book and _near_interact.get("book", false):
		_has_book = true; _show_prompt("Found an ancient Book on the shelf!")
		_stage_hint.text = "Got the Book! Take the Meat from the table."
		return
	if not _has_meat and _near_interact.get("meat", false):
		_has_meat = true; _show_prompt("Took the fresh Meat!")
		_stage_hint.text = "Got the Meat! Bring all to the pedestal."
		return
	if _near_interact.get("pedestal", false):
		_show_prompt("Right-click to place skeleton parts from inventory.")
		return
	var near_statue := false
	for i in 4:
		if _near_interact.get("statue%d" % i, false): near_statue = true
	if near_statue and not _has_key:
		_show_prompt("A statue of a Learned Man. He seems to hold something...")

func _place_on_pedestal() -> void:
	var idx := -1
	for i in 6:
		if not _pedestal_placed[i] and GameInventory.has_item(SKELETON_ITEMS[i]):
			idx = i; break
	if idx < 0:
		_show_prompt("No more skeleton parts in inventory to place.")
		return
	GameInventory.remove_item(SKELETON_ITEMS[idx])
	_pedestal_placed[idx] = true
	var pp := get_node_or_null("PedestalParts") as Node2D
	if pp:
		var ps := pp.get_node_or_null("PedestalPart%d" % idx) as Sprite2D
		if ps:
			ps.visible = true; ps.scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_property(ps, "scale", Vector2(1, 1), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	var left := 0
	for i in 6:
		if not _pedestal_placed[i]: left += 1
	if left == 0:
		_show_prompt("All parts placed! The skeleton stirs...")
		_stage_hint.text = "The skeleton is complete!"
		await get_tree().create_timer(1.5).timeout
		_finish_assembly()
	else:
		_show_prompt("Placed %s! (%d left)" % [_get_part_name(idx), left])

func _exit_to_gravestone() -> void:
	if _exiting: return; _exiting = true
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.cover()
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("exit_library_room"): g.exit_library_room()

func _get_part_name(i: int) -> String:
	var names := ["Neck","Skull","Arms","Ribs","Legs","Tail"]
	return names[i] if i < names.size() else "Part"

func _play_voice(path: String) -> void:
	var s := AudioStreamPlayer.new()
	s.stream = load(path)
	if s.stream:
		add_child(s)
		s.finished.connect(s.queue_free)
		s.play()

func _show_vn_dialogue(title: String, text: String, duration: float) -> void:
	var vs := DisplayServer.window_get_size()
	var vn_layer := CanvasLayer.new()
	vn_layer.layer = 20
	vn_layer.name = "VNDialogue"
	add_child(vn_layer)
	var vn_box := ColorRect.new()
	vn_box.color = Color(0.05, 0.05, 0.1, 0.92)
	vn_box.position = Vector2(10, vs.y - 260)
	vn_box.size = Vector2(vs.x - 20, 250)
	vn_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vn_layer.add_child(vn_box)
	var vn_name := Label.new()
	vn_name.text = title
	vn_name.add_theme_font_size_override("font_size", 22)
	vn_name.add_theme_color_override("font_color", Color(0.6, 0.7, 1, 1))
	vn_name.position = Vector2(30, vs.y - 248)
	vn_name.size = Vector2(vs.x - 60, 30)
	vn_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vn_layer.add_child(vn_name)
	var vn_text := Label.new()
	vn_text.text = text
	vn_text.add_theme_font_size_override("font_size", 18)
	vn_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 1))
	vn_text.position = Vector2(30, vs.y - 210)
	vn_text.size = Vector2(vs.x - 60, 180)
	vn_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vn_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vn_layer.add_child(vn_text)
	await get_tree().create_timer(duration).timeout
	vn_layer.queue_free()

func _finish_assembly() -> void:
	_lion_done = true
	_can_move = false
	_stage_hint.text = ""
	_play_voice("res://assets/audio/sfx/completedthebeast.mp3")
	await _show_vn_dialogue("???",
		"I see... You have completed the Beast. Now Only One thing remains...", 4.0)
	_stage_hint.text = "The lion skeleton assembles before you. It seems to be waiting for something... The fountain shimmers. Get the Potion of Life."
	_can_move = true
	_set_fountain_bottle_visible(true)

func _set_fountain_bottle_visible(vis: bool) -> void:
	var bottle := get_node_or_null("FountainBottle") as Sprite2D
	if bottle:
		bottle.modulate = Color(1, 1, 1, 0.9) if vis else Color(1, 1, 1, 0.5)

func _trigger_potion() -> void:
	if _has_potion: return
	_has_potion = true
	GameInventory.add_item("life_potion")
	var bottle := get_node_or_null("FountainBottle") as Sprite2D
	if bottle:
		_set_fountain_bottle_visible(false)
	_stage_hint.text = "The Potion of Life shimmers in your hands. The pedestal awaits..."
	var popup := ColorRect.new()
	popup.color = Color(0.0, 0.3, 0.0, 0.6)
	popup.position = Vector2(300, 300)
	popup.size = Vector2(280, 60)
	popup.z_index = 60; add_child(popup)
	var popup_label := Label.new()
	popup_label.text = "Got Potion of Life!"
	popup_label.add_theme_font_size_override("font_size", 18)
	popup_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.position = Vector2(300, 310)
	popup_label.size = Vector2(280, 40)
	popup_label.z_index = 61; add_child(popup_label)
	await get_tree().create_timer(1.5).timeout
	popup.queue_free(); popup_label.queue_free()

func _show_countdown_timer() -> void:
	var cl := CanvasLayer.new(); cl.layer = 30; cl.name = "CountdownLayer"; add_child(cl)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = DisplayServer.window_get_size()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(bg)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 0)
	label.size = DisplayServer.window_get_size()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(label)
	var tick_start: float = 0.12; var tick_end: float = 0.04
	for i in range(40, 0, -1):
		label.text = str(i)
		label.scale = Vector2(1.3, 1.3)
		var tw := create_tween()
		tw.tween_property(label, "scale", Vector2(1, 1), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var t: float = float(40 - i) / 39.0
		var wait: float = lerp(tick_start, tick_end, t)
		await get_tree().create_timer(wait).timeout
	cl.queue_free()

func _show_ending_cutscene() -> void:
	var cl := CanvasLayer.new(); cl.layer = 30; cl.name = "EndingCutscene"; add_child(cl)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = DisplayServer.window_get_size()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(bg)
	var tr := TextureRect.new()
	tr.texture = preload("res://assets/art/cutscenes/cutscene_4.png")
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size = DisplayServer.window_get_size()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)
	var txt_bg := ColorRect.new()
	txt_bg.color = Color(0, 0, 0, 0.6)
	txt_bg.size = Vector2(DisplayServer.window_get_size().x, 100)
	txt_bg.position = Vector2(0, DisplayServer.window_get_size().y - 100)
	txt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(txt_bg)
	var lb := Label.new()
	lb.text = "As Vikram breaks the deal, Betaal flies right back to the tree he came from"
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.add_theme_font_size_override("font_size", 20)
	lb.add_theme_color_override("font_color", Color(1, 1, 0.9))
	lb.size = Vector2(DisplayServer.window_get_size().x - 40, 90)
	lb.position = Vector2(20, DisplayServer.window_get_size().y - 95)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(lb)
	await get_tree().create_timer(4.0).timeout
	cl.queue_free()

func _show_credits() -> void:
	var cl := CanvasLayer.new(); cl.layer = 35; cl.name = "CreditsLayer"; add_child(cl)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.size = DisplayServer.window_get_size()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(bg)
	var label := Label.new()
	label.text = "This Game was our team's unique spin on the Indian Classical folktale of \"Vikram & Betaal\". This version was made in 4 days."
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(60, 200)
	label.size = Vector2(DisplayServer.window_get_size().x - 120, 300)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(label)
	await get_tree().create_timer(5.0).timeout
	cl.queue_free()

func _use_potion_on_skeleton() -> void:
	_potion_used = true
	_can_move = false
	_stage_hint.text = ""

	var potion_spr := Sprite2D.new()
	var potion_tex := load("res://assets/art/rooms/lifebottle.png")
	if potion_tex:
		potion_spr.texture = potion_tex
		potion_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	potion_spr.position = Vector2(31 * TILE, FLOOR_Y - 200)
	potion_spr.scale = Vector2(2, 2)
	potion_spr.z_index = 20
	add_child(potion_spr)

	var tw_appear := create_tween()
	tw_appear.tween_property(potion_spr, "modulate", Color(1, 1, 1, 1), 0.5).from(Color(1, 1, 1, 0))
	await tw_appear.finished
	await get_tree().create_timer(0.5).timeout

	var tw_fade := create_tween()
	tw_fade.tween_property(potion_spr, "modulate", Color(1, 1, 1, 0), 1.0)
	tw_fade.parallel().tween_property(potion_spr, "position:y", potion_spr.position.y - 60, 1.0)
	await tw_fade.finished
	potion_spr.queue_free()

	await _show_countdown_timer()
	await _show_vn_dialogue("Betaal", "Everything has a price, Mighty Rajan.", 3.0)
	_play_voice("res://assets/audio/sfx/knowledgeisacuriousgift.mp3")
	await _show_vn_dialogue("Betaal", "Knowledge... is a curious gift, Might Rajan. It teaches us how something may be done... but not whether it should.", 4.0)
	await get_tree().create_timer(0.5).timeout
	_play_voice("res://assets/audio/sfx/Vikram Refuse.mp3")
	await _show_vn_dialogue("Vikram", "No Betaal, I am not going to fall for your tricks. I know that using this potion will awaken the beast", 4.0)
	await get_tree().create_timer(0.5).timeout
	await _show_vn_dialogue("Betaal", "Indeed Mighty Rajan, Wisdom has finally blessed you. But in doing so, YOU have spoken up, breaking our deal", 3.5)
	await get_tree().create_timer(0.3).timeout
	_play_voice("res://assets/audio/sfx/wellthenoffigo.mp3")
	await _show_vn_dialogue("Betaal", "Well then, Off I Go!", 2.5)

	if _bgm: _bgm.stop()
	await _show_ending_cutscene()
	await _show_credits()
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("return_to_title"): g.return_to_title()
	else: queue_free()

func _exit_room() -> void:
	if _exiting: return; _exiting = true; _can_move = false
	if _bgm: _bgm.stop()
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.cover()
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("exit_library_room"): g.exit_library_room()
	else: queue_free()

func reveal() -> void:
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.reveal()
	_can_move = true

func _process(delta: float) -> void:
	if not _parallax_layers.is_empty():
		var cam := get_node_or_null("Camera2D") as Camera2D
		if cam:
			var cx = cam.global_position.x
			for l in _parallax_layers:
				var offset = wrapf(-cx * l["factor"], 0, l["tex_w"])
				var sprites = l["sprites"]
				for i in range(sprites.size()):
					sprites[i].position.x = offset + (i - 1) * l["tex_w"]

	var phint := get_node_or_null("PedestalHint") as Label
	if phint:
		var has_any := false
		for item in SKELETON_ITEMS:
			if GameInventory.has_item(item): has_any = true; break
		phint.visible = has_any and _can_move and not _lion_done

	if not _fountain_frames.is_empty() and _fountain_sprite:
		_fountain_time += delta
		if _fountain_time >= 0.25:
			_fountain_time -= 0.25
			_fountain_idx = (_fountain_idx + 1) % _fountain_frames.size()
			_fountain_sprite.texture = _fountain_frames[_fountain_idx]

func _physics_process(delta: float) -> void:
	if not _can_move or not _player: return
	var dir := Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("jump") and _player.is_on_floor(): _player.velocity.y = JUMP_VEL
	var sprint_pressed = Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint")
	var speed = MOVE_SPEED * (1.0 + SPRINT_SPEED_BONUS) if sprint_pressed and dir != 0 else MOVE_SPEED
	_player.velocity.x = dir * speed; _player.velocity.y += GRAVITY * delta
	if abs(dir) > 0.1:
		_player.scale.x = sign(dir) * abs(_player.scale.x)
	_player.move_and_slide()
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam: cam.position = _player.position
