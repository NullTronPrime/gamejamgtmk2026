extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")
const HumanoidRig := preload("res://scripts/shared/humanoid_rig.gd")
const GRAVITY := 1400.0; const JUMP_VEL := -480.0; const MOVE_SPEED := 180.0
const SPRINT_SPEED_BONUS := 0.5; const TILE := 64; const FLOOR_Y := 12 * TILE
const ROOM_LEFT := -8 * TILE; const ROOM_RIGHT := 84 * TILE

var _player: CharacterBody2D
var _can_move := false; var _exiting := false; var _stage_hint: Label

var _has_key := false; var _has_book := false; var _has_meat := false; var _has_potion := false
var _lion_done := false; var _cage_unlocked := false
var _bone_bodies: Array[RigidBody2D] = []
var _rig: Dictionary = {}
var _walk_time := 0.0

var _fountain_frames: Array[Texture2D] = []
var _fountain_sprite: Sprite2D
var _fountain_idx := 0
var _parallax_layers: Array[Dictionary] = []
var _fountain_time := 0.0

const SKELETON_ITEMS := ["skeleton_neck","skeleton_skull","skeleton_arms","skeleton_ribs","skeleton_legs","skeleton_tail"]
const PART_FILES := ["part_neck","part_skull","part_arms","part_ribs","part_legs","part_tail"]
const GROUND_FILES := ["ground_neck","ground_skull","ground_arms","ground_ribs","ground_legs","ground_tail"]

var _pedestal_placed := [false, false, false, false, false, false]
var _potion_used := false
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
	var cage_x: int = 50 * TILE
	add_child(_r(cage_x-30, FLOOR_Y-48, 60, 48, Color(0.28,0.24,0.18,0.95), 0))
	add_child(_r(cage_x-24, FLOOR_Y-42, 48, 36, Color(0.1,0.08,0.04,0.95), 0))
	add_child(_r(cage_x-2, FLOOR_Y-56, 4, 12, Color(0.35,0.3,0.2,0.9), 0))
	for bx in [cage_x-26, cage_x-16, cage_x-6, cage_x+4, cage_x+14, cage_x+24]:
		add_child(_r(bx, FLOOR_Y-46, 3, 40, Color(0.3,0.26,0.18,0.85), 0))
	add_child(_r(cage_x + 36, FLOOR_Y - 64, 12, 64, Color(0.4, 0.3, 0.2, 0.9), -1))
	for lx in [cage_x + 38, cage_x + 42]:
		add_child(_r(lx, FLOOR_Y - 52, 4, 8, Color(0.45, 0.35, 0.22, 0.9), -1))
		add_child(_r(lx, FLOOR_Y - 36, 4, 8, Color(0.45, 0.35, 0.22, 0.9), -1))
		add_child(_r(lx, FLOOR_Y - 20, 4, 8, Color(0.45, 0.35, 0.22, 0.9), -1))

	var px := 31 * TILE
	var pt := _tex("res://assets/art/rooms/pedestal.png")
	if pt:
		var psp := Sprite2D.new(); psp.texture = pt; psp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		psp.position = Vector2(px, FLOOR_Y - 28); psp.z_index = -1; add_child(psp)

	var ped_solid := StaticBody2D.new(); ped_solid.position = Vector2(px, FLOOR_Y - 42)
	var ped_col := CollisionShape2D.new(); ped_col.shape = RectangleShape2D.new(); ped_col.shape.size = Vector2(96, 28)
	ped_solid.add_child(ped_col); add_child(ped_solid)

	var ped_parts := Node2D.new(); ped_parts.name = "PedestalParts"
	ped_parts.position = Vector2(px, FLOOR_Y - 56); add_child(ped_parts)
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
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in 5:
		var rx = rng.randf_range(3.0, 75.0) * TILE
		var ry = rng.randf_range(FLOOR_Y - 5.0 * TILE, FLOOR_Y - 1.5 * TILE)
		_make_bone_pickup(SKELETON_ITEMS[i], "res://assets/art/skeleton/%s.png" % GROUND_FILES[i], Vector2(rx, ry), i)

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

	var ca := Area2D.new(); ca.name = "CageArea"
	var cc := CollisionShape2D.new(); cc.shape = RectangleShape2D.new(); cc.shape.size = Vector2(72, 56)
	ca.add_child(cc); ca.position = Vector2(50*TILE, FLOOR_Y-24)
	ca.body_entered.connect(_on_near.bind("cage")); add_child(ca)

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

func _spawn_player() -> void:
	_player = CharacterBody2D.new(); _player.name = "Player"
	_player.collision_layer = 1; _player.collision_mask = 1
	var shape := RectangleShape2D.new(); shape.size = Vector2(28, 88)
	var col := CollisionShape2D.new(); col.shape = shape; col.position = Vector2(0, 12); _player.add_child(col)
	_rig = HumanoidRig.build(_player, Color(0.55,0.4,0.25), Color(0.8,0.65,0.5))
	for c in _player.get_children(): if c is Polygon2D: c.z_index = 1
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
	var tw = create_tween(); tw.tween_property(l, "modulate:a", 0.0, 3.0).set_delay(2.0); await tw.finished; l.queue_free()

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
			if bottle and not _has_potion and _near_interact.get("fountain", false) and bottle.global_position.distance_to(mpos) < 28:
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
			if _lion_done and _has_potion and not _potion_used:
				_use_potion_on_skeleton()
			elif _lion_done and not _has_potion and not _potion_used:
				_show_prompt("You need the Potion of Life from the fountain.")
			elif not _lion_done:
				_place_on_pedestal()

func _handle_interact() -> void:
	if not _has_key and _near_interact.get("key", false):
		_has_key = true; _show_prompt("Found a rusty key in the statue!")
		_stage_hint.text = "Got the key! The cage rattles..."
		return
	if _near_interact.get("cage", false):
		if _has_key and not _cage_unlocked:
			_cage_unlocked = true
			_make_bone_pickup("skeleton_tail", "res://assets/art/skeleton/ground_tail.png", Vector2(50*TILE, FLOOR_Y - 2*TILE), 5)
			_show_prompt("Unlocked the cage! The tail bone falls out.")
			_stage_hint.text = "Cage open! Collect all 6 skeleton parts."
		elif not _has_key:
			_show_prompt("The cage is locked. Find a key.")
		return
	if not _has_book and _near_interact.get("book", false):
		_has_book = true; _show_prompt("Found an ancient Book on the shelf!")
		_stage_hint.text = "Got the Book! Take the Meat from the table."
		return
	if not _has_meat and _near_interact.get("meat", false):
		_has_meat = true; _show_prompt("Took the fresh Meat!")
		_stage_hint.text = "Got the Meat! Bring all to the pedestal."
		return
	if _near_interact.get("fountain", false) and not _has_potion:
		_show_prompt("Click the glowing bottle in the fountain.")
		return
	if _near_interact.get("pedestal", false):
		_show_prompt("Right-click to place skeleton parts from inventory.")
		return
	var near_statue := false
	for i in 4:
		if _near_interact.get("statue%d" % i, false): near_statue = true
	if near_statue and not _has_key:
		_show_prompt("A statue of a Learned Man. He seems to hold something...")

func _trigger_potion() -> void:
	if _has_potion: return
	_has_potion = true; _can_move = false
	_show_prompt("The fountain glows... a bottle emerges!")
	_stage_hint.text = "Got the Potion of Life!"
	var bottle := get_node_or_null("FountainBottle") as Sprite2D
	if bottle: bottle.queue_free()
	var haze := ColorRect.new(); haze.color = Color(0.5, 0.1, 0.6, 0)
	haze.size = get_viewport().get_visible_rect().size; haze.z_index = 100
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(haze)
	var tw := create_tween()
	tw.tween_property(haze, "color", Color(0.5, 0.1, 0.6, 0.85), 1.0)
	await tw.finished
	GameInventory.add_item("life_potion")
	await get_tree().create_timer(0.8).timeout
	var tw2 := create_tween()
	tw2.tween_property(haze, "color", Color(0.5, 0.1, 0.6, 0), 1.5)
	await tw2.finished; haze.queue_free()
	_can_move = true

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

func _use_potion_on_skeleton() -> void:
	if _potion_used or not _has_potion: return
	_potion_used = true; _can_move = false
	GameInventory.remove_item("life_potion")
	_stage_hint.text = "The Potion of Life shimmers over the skeleton!"
	var sk := get_node_or_null("SkeletonLion")
	if sk:
		var tw := create_tween(); tw.set_parallel(true)
		tw.tween_property(sk, "modulate", Color(1, 1, 1, 0.6), 0.5)
		tw.tween_property(sk, "modulate", Color(1, 1, 1, 1), 0.5).set_delay(0.5)
		for i in 4:
			var shimmer := ColorRect.new()
			shimmer.size = Vector2(120 + i * 20, 20 + i * 8)
			shimmer.position = Vector2(31*TILE - shimmer.size.x/2, FLOOR_Y - 56 - i * 16)
			shimmer.color = Color(1, 1, 0.8, 0.4 - i * 0.08)
			shimmer.z_index = 10; shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(shimmer)
			var st := create_tween()
			st.tween_property(shimmer, "modulate", Color(1, 1, 0.8, 0), 0.8).set_delay(i * 0.15)
			st.tween_callback(shimmer.queue_free)
		await tw.finished
		sk.modulate = Color(1, 1, 1, 1)
	var vs := DisplayServer.window_get_size()
	var vn_box := ColorRect.new()
	vn_box.color = Color(0.05, 0.05, 0.1, 0.85)
	vn_box.position = Vector2(40, vs.y - 140)
	vn_box.size = Vector2(vs.x - 80, 120)
	vn_box.z_index = 50; add_child(vn_box)
	var vn_name := Label.new()
	vn_name.text = "Sample Character"
	vn_name.add_theme_font_size_override("font_size", 12)
	vn_name.add_theme_color_override("font_color", Color(0.6, 0.7, 1, 1))
	vn_name.position = Vector2(50, vs.y - 132)
	vn_name.z_index = 51; add_child(vn_name)
	var vn_text := Label.new()
	vn_text.text = "Sample dialogue text goes here."
	vn_text.add_theme_font_size_override("font_size", 14)
	vn_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 1))
	vn_text.position = Vector2(50, vs.y - 112)
	vn_text.size = Vector2(vs.x - 100, 80)
	vn_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vn_text.z_index = 51; add_child(vn_text)
	await get_tree().create_timer(3.0).timeout
	vn_box.queue_free(); vn_name.queue_free(); vn_text.queue_free()
	_stage_hint.text = "The way opens. You emerge from the grave..."
	if _bgm: _bgm.stop()
	var tw2 := create_tween(); tw2.tween_property(_player, "modulate", Color(1,1,1,0), 2.0)
	await tw2.finished
	_exit_to_gravestone()

func _exit_to_gravestone() -> void:
	if _exiting: return; _exiting = true
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.cover()
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("exit_library_room"): g.exit_library_room()

func _get_part_name(i: int) -> String:
	var names := ["Neck","Skull","Arms","Ribs","Legs","Tail"]
	return names[i] if i < names.size() else "Part"

func _finish_assembly() -> void:
	_lion_done = true
	_stage_hint.text = "The Skeleton Lion awakens!"
	var sk := preload("res://assets/skeleton_assembly.tscn").instantiate()
	sk.name = "SkeletonLion"
	sk.position = Vector2(31*TILE, FLOOR_Y - 220)
	add_child(sk)
	await get_tree().create_timer(1.0).timeout
	if sk.has_method("_on_stand_button_pressed") or sk.get_node_or_null("AnimationPlayer"):
		var ap := sk.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap and ap.has_animation("stand"):
			ap.play("stand")
	_show_prompt("The Skeleton takes shape! Use the Potion of Life on it.")
	_stage_hint.text = "Right-click the pedestal with the Life Potion."

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
	if abs(dir) > 0.1 and _player.is_on_floor():
		_walk_time += delta * 8.0
		var s := sin(_walk_time); var c := cos(_walk_time)
		if _rig.has("l_shoulder"): _rig.l_shoulder.rotation = s * 0.3
		if _rig.has("r_shoulder"): _rig.r_shoulder.rotation = -s * 0.3
		if _rig.has("l_elbow"): _rig.l_elbow.rotation = abs(s) * 0.15
		if _rig.has("r_elbow"): _rig.r_elbow.rotation = abs(s) * 0.15
		if _rig.has("l_hip"): _rig.l_hip.rotation = c * 0.25
		if _rig.has("r_hip"): _rig.r_hip.rotation = -c * 0.25
		if _rig.has("l_knee"): _rig.l_knee.rotation = max(0, -c) * 0.15
		if _rig.has("r_knee"): _rig.r_knee.rotation = max(0, c) * 0.15
	elif _rig.size() > 0:
		_walk_time = 0.0
		for key in ["l_shoulder","r_shoulder","l_elbow","r_elbow","l_hip","r_hip","l_knee","r_knee"]:
			if _rig.has(key): _rig[key].rotation = 0.0
	_player.move_and_slide()
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam: cam.position = _player.position
