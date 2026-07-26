extends Node2D

const GridTrans := preload("res://scripts/ui/grid_transition.gd")
const HumanoidRig := preload("res://scripts/shared/humanoid_rig.gd")
const GRAVITY := 1400.0; const JUMP_VEL := -480.0; const MOVE_SPEED := 180.0
const CLIMB_SPEED := 120.0; const TILE := 64

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
var _fountain_time := 0.0

const SKELETON_ITEMS := ["skeleton_neck","skeleton_skull","skeleton_arms","skeleton_ribs","skeleton_legs","skeleton_tail"]
const PART_FILES := ["part_neck","part_skull","part_arms","part_ribs","part_legs","part_tail"]
const GROUND_FILES := ["ground_neck","ground_skull","ground_arms","ground_ribs","ground_legs","ground_tail"]

var _pedestal_placed := [false, false, false, false, false, false]

func _ready() -> void:
	_build_background(); _build_floor(); _build_walls()
	_build_furniture(); _build_pickups(); _build_interactables()
	_spawn_player(); _setup_camera(); _setup_ui(); reveal.call_deferred()

func _tex(path: String) -> Texture2D: return load(path)

func _r(x, y, w, h, col: Color, z: int = 0) -> ColorRect:
	var r := ColorRect.new(); r.position = Vector2(x, y); r.size = Vector2(w, h)
	r.color = col; r.z_index = z; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; return r

func _build_background() -> void:
	var bg := _tex("res://assets/art/rooms/library_bg.png")
	if bg:
		var s := Sprite2D.new(); s.texture = bg; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(40*TILE, 5*TILE); s.z_index = -5; add_child(s)
	else:
		var br := ColorRect.new(); br.color = Color(0.08, 0.06, 0.04)
		br.size = Vector2(80*TILE, 12*TILE)
		br.position = Vector2(0, -TILE); br.z_index = -5; br.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(br)

func _build_floor() -> void:
	var lt := _tex("res://assets/art/rooms/wall_tile_light.png")
	var dt := _tex("res://assets/art/rooms/wall_tile_dark.png")
	for x in range(0, 80*TILE, TILE):
		if lt:
			var s := Sprite2D.new(); s.texture = lt; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.position = Vector2(x+TILE/2, 10*TILE+TILE/2); s.z_index = -2; add_child(s)
		if dt:
			var s := Sprite2D.new(); s.texture = dt; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.position = Vector2(x+TILE/2, 11*TILE+TILE/2); s.z_index = -2; add_child(s)
		_solid(Vector2(x+TILE/2, 10*TILE+TILE), Vector2(TILE, TILE*2))

func _solid(pos: Vector2, size: Vector2) -> void:
	var s := StaticBody2D.new(); s.collision_layer = 1; s.position = pos
	var c := CollisionShape2D.new(); c.shape = RectangleShape2D.new(); c.shape.size = size; s.add_child(c); add_child(s)

func _build_walls() -> void:
	for x in [0, 79*TILE]:
		var dw := _tex("res://assets/art/rooms/wall_tile_dark.png")
		var lw := _tex("res://assets/art/rooms/wall_tile_light.png")
		for yi in range(0, 10*TILE, TILE):
			var tex := dw if (yi/TILE)%2==0 else lw
			if tex:
				var s := Sprite2D.new(); s.texture = tex; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				s.position = Vector2(x+TILE/2, yi+TILE/2); s.z_index = -2; add_child(s)
		_solid(Vector2(x+TILE/2, 5*TILE), Vector2(TILE, 10*TILE))

func _build_furniture() -> void:
	var bks := _tex("res://assets/art/rooms/bookshelf.png")
	var bk_x: Array[int] = [6, 9, 12, 15, 58, 62]
	for xi in range(bk_x.size()):
		var bx: int = bk_x[xi] * TILE
		if bks:
			var s := Sprite2D.new(); s.texture = bks; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if xi % 2 == 1: s.scale.x = -1
			s.position = Vector2(bx, 4*TILE + bks.get_height()/2); s.z_index = -1; add_child(s)
		else:
			add_child(_r(bx-16, 4*TILE, 32, 5*TILE, Color(0.2,0.12,0.06,0.8), -1))

	var ns := _tex("res://assets/art/rooms/nightstand_large.png")
	for i in 4:
		var nx: int = (19 + i*5) * TILE
		if ns:
			var s := Sprite2D.new(); s.texture = ns; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.position = Vector2(nx, 10*TILE - 28); s.z_index = -1; add_child(s)
		else:
			add_child(_r(nx-14, 10*TILE-56, 28, 56, Color(0.15,0.12,0.06,0.8), -1))

	var t1 := _tex("res://assets/art/rooms/table_variant1.png")
	var ch := _tex("res://assets/art/rooms/chair.png")
	var tx: int = 58 * TILE
	if t1:
		var s := Sprite2D.new(); s.texture = t1; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(tx, 10*TILE-12); s.z_index = -1; add_child(s)
	else:
		add_child(_r(tx-16, 10*TILE-20, 32, 16, Color(0.35,0.25,0.1,0.8), -1))
	if ch:
		var s := Sprite2D.new(); s.texture = ch; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(tx-24, 10*TILE-10); s.z_index = -1; add_child(s)
		var s2 := Sprite2D.new(); s2.texture = ch; s2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s2.position = Vector2(tx+24, 10*TILE-10); s2.z_index = -1; add_child(s2)

	var cage_x: int = 50 * TILE
	add_child(_r(cage_x-32, 10*TILE-48, 64, 48, Color(0.35,0.3,0.2), 0))
	add_child(_r(cage_x-24, 10*TILE-42, 48, 36, Color(0.12,0.1,0.06), 0))

	var px := 31 * TILE
	var pt := _tex("res://assets/art/rooms/pedestal.png")
	if pt:
		var psp := Sprite2D.new(); psp.texture = pt; psp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		psp.position = Vector2(px, 10*TILE - 28); psp.z_index = -1; add_child(psp)

	var ped_solid := StaticBody2D.new(); ped_solid.position = Vector2(px, 10*TILE - 42)
	var ped_col := CollisionShape2D.new(); ped_col.shape = RectangleShape2D.new(); ped_col.shape.size = Vector2(96, 28)
	ped_solid.add_child(ped_col); add_child(ped_solid)

	var ped_parts := Node2D.new(); ped_parts.name = "PedestalParts"
	ped_parts.position = Vector2(px, 10*TILE - 56); add_child(ped_parts)
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
	_make_bone_pickup(SKELETON_ITEMS[0], "res://assets/art/skeleton/%s.png" % GROUND_FILES[0], Vector2(7*TILE, 9*TILE), 0)
	_make_bone_pickup(SKELETON_ITEMS[1], "res://assets/art/skeleton/%s.png" % GROUND_FILES[1], Vector2(4*TILE, 9.5*TILE), 1)
	_make_bone_pickup(SKELETON_ITEMS[2], "res://assets/art/skeleton/%s.png" % GROUND_FILES[2], Vector2(21*TILE, 9*TILE), 2)
	_make_bone_pickup(SKELETON_ITEMS[3], "res://assets/art/skeleton/%s.png" % GROUND_FILES[3], Vector2(35*TILE, 9.5*TILE), 3)
	_make_bone_pickup(SKELETON_ITEMS[4], "res://assets/art/skeleton/%s.png" % GROUND_FILES[4], Vector2(55*TILE, 9*TILE), 4)

func _build_interactables() -> void:
	var fx: int = 39 * TILE
	var px := 31 * TILE

	for i in 4:
		var sx: int = (19 + i*5) * TILE
		var a := Area2D.new(); a.name = "StatueArea%d" % i
		var s := CollisionShape2D.new(); s.shape = RectangleShape2D.new(); s.shape.size = Vector2(48, 48)
		a.add_child(s); a.position = Vector2(sx, 10*TILE-28)
		a.body_entered.connect(_on_near.bind("statue%d" % i)); add_child(a)

	var ka := Area2D.new(); ka.name = "KeyArea"
	var kc := CollisionShape2D.new(); kc.shape = RectangleShape2D.new(); kc.shape.size = Vector2(48, 48)
	ka.add_child(kc); ka.position = Vector2(19*TILE, 10*TILE-28)
	ka.body_entered.connect(_on_near.bind("key")); add_child(ka)

	var ca := Area2D.new(); ca.name = "CageArea"
	var cc := CollisionShape2D.new(); cc.shape = RectangleShape2D.new(); cc.shape.size = Vector2(72, 56)
	ca.add_child(cc); ca.position = Vector2(50*TILE, 10*TILE-24)
	ca.body_entered.connect(_on_near.bind("cage")); add_child(ca)

	var ba := Area2D.new(); ba.name = "BookArea"
	var bc := CollisionShape2D.new(); bc.shape = RectangleShape2D.new(); bc.shape.size = Vector2(48, 48)
	ba.add_child(bc); ba.position = Vector2(9*TILE, 4*TILE)
	ba.body_entered.connect(_on_near.bind("book")); add_child(ba)

	var ma := Area2D.new(); ma.name = "MeatArea"
	var mc := CollisionShape2D.new(); mc.shape = RectangleShape2D.new(); mc.shape.size = Vector2(48, 40)
	ma.add_child(mc); ma.position = Vector2(58*TILE, 10*TILE-16)
	ma.body_entered.connect(_on_near.bind("meat")); add_child(ma)

	var fa := Area2D.new(); fa.name = "FountainArea"
	var fc := CollisionShape2D.new(); fc.shape = RectangleShape2D.new(); fc.shape.size = Vector2(80, 60)
	fa.add_child(fc); fa.position = Vector2(fx, 10*TILE-24)
	fa.body_entered.connect(_on_near.bind("fountain")); add_child(fa)

	_fountain_frames = []
	for fn in ["f1","f2","f3","f4"]:
		var ft := _tex("res://assets/art/rooms/fountain/%s.png" % fn)
		if ft: _fountain_frames.append(ft)
	if not _fountain_frames.is_empty():
		_fountain_sprite = Sprite2D.new(); _fountain_sprite.name = "FountainSprite"
		_fountain_sprite.texture = _fountain_frames[0]; _fountain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_fountain_sprite.position = Vector2(fx, 10*TILE - 32); _fountain_sprite.z_index = 1; add_child(_fountain_sprite)

		var pt := CPUParticles2D.new(); pt.name = "FountainParticles"
		pt.position = Vector2(fx, 10*TILE - 44)
		pt.amount = 12; pt.lifetime = 1.2; pt.one_shot = false; pt.explosiveness = 0.0
		pt.direction = Vector2(0, -1); pt.spread = 30.0; pt.gravity = Vector2(0, -80)
		pt.initial_velocity_min = 20; pt.initial_velocity_max = 50
		pt.scale_amount = 0.5
		pt.color = Color(0.6, 0.8, 1.0, 0.6); pt.emitting = true
		pt.visibility_rect = Rect2(-64, -64, 128, 128)
		add_child(pt)

	var pa := Area2D.new(); pa.name = "PedestalArea"
	var pc := CollisionShape2D.new(); pc.shape = RectangleShape2D.new(); pc.shape.size = Vector2(96, 64)
	pa.add_child(pc); pa.position = Vector2(px, 10*TILE-28)
	pa.body_entered.connect(_on_near.bind("pedestal")); add_child(pa)

func _spawn_player() -> void:
	_player = CharacterBody2D.new(); _player.name = "Player"
	_player.collision_layer = 1; _player.collision_mask = 1
	var shape := RectangleShape2D.new(); shape.size = Vector2(28, 88)
	var col := CollisionShape2D.new(); col.shape = shape; col.position = Vector2(0, 12); _player.add_child(col)
	_rig = HumanoidRig.build(_player, Color(0.55,0.4,0.25), Color(0.8,0.65,0.5))
	for c in _player.get_children(): if c is Polygon2D: c.z_index = 1
	_player.position = Vector2(2*TILE, 9*TILE); add_child(_player)

func _setup_camera() -> void:
	var cam := Camera2D.new(); cam.name = "Camera2D"
	cam.zoom = Vector2(1.8, 1.8); add_child(cam); cam.make_current()

func _setup_ui() -> void:
	_stage_hint = Label.new(); _stage_hint.add_theme_font_size_override("font_size", 11)
	_stage_hint.add_theme_color_override("font_color", Color(0.8,0.8,0.7,0.6))
	_stage_hint.anchor_left = 0.5; _stage_hint.anchor_top = 0.0
	_stage_hint.anchor_right = 0.5; _stage_hint.anchor_bottom = 0.0
	_stage_hint.position = Vector2(-120, 60); _stage_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_stage_hint)

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
		if _can_move and _near_interact.get("pedestal", false) and not _lion_done:
			_place_on_pedestal()

func _handle_interact() -> void:
	if not _has_key and _near_interact.get("key", false):
		_has_key = true; _show_prompt("Found a rusty key in the statue!")
		_stage_hint.text = "Got the key! The cage rattles..."
		return
	if _near_interact.get("cage", false):
		if _has_key and not _cage_unlocked:
			_cage_unlocked = true
			_make_bone_pickup("skeleton_tail", "res://assets/art/skeleton/ground_tail.png", Vector2(50*TILE, 9*TILE), 5)
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
		_has_potion = true; _can_move = false
		_show_prompt("The fountain glows... a bottle emerges!")
		_stage_hint.text = "Got the Potion of Life!"
		var fade := ColorRect.new(); fade.color = Color(0, 0, 0, 0)
		fade.size = get_viewport().get_visible_rect().size; fade.z_index = 100
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(fade)
		var tw := create_tween(); tw.tween_property(fade, "color", Color(0, 0, 0, 1), 1.0)
		await tw.finished
		GameInventory.add_item("life_potion")
		await get_tree().create_timer(0.5).timeout
		var tw2 := create_tween(); tw2.tween_property(fade, "color", Color(0, 0, 0, 0), 1.0)
		await tw2.finished; fade.queue_free()
		_can_move = true
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

func _get_part_name(i: int) -> String:
	var names := ["Neck","Skull","Arms","Ribs","Legs","Tail"]
	return names[i] if i < names.size() else "Part"

func _finish_assembly() -> void:
	_lion_done = true; _can_move = false
	_stage_hint.text = "The Skeleton Lion awakens!"
	var sk := preload("res://assets/skeleton_assembly.tscn").instantiate()
	sk.position = Vector2(31*TILE, 10*TILE - 220)
	add_child(sk)
	await get_tree().create_timer(1.0).timeout
	if sk.has_method("_on_stand_button_pressed") or sk.get_node_or_null("AnimationPlayer"):
		var ap := sk.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap and ap.has_animation("stand"):
			ap.play("stand")
	_show_prompt("The Skeleton takes shape! You must offer your time...")
	await get_tree().create_timer(2.0).timeout
	var tw := create_tween()
	tw.tween_property(_player, "modulate", Color(1,1,1,0), 2.0)
	_stage_hint.text = "Your time is given. The way opens."
	await tw.finished
	_exit_room()

func _exit_room() -> void:
	if _exiting: return; _exiting = true; _can_move = false
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.cover(0.8)
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("exit_library_room"): g.exit_library_room()
	else: queue_free()

func reveal() -> void:
	if GridTrans.is_available() and not GridTrans.is_busy(): await GridTrans.reveal(0.8)
	_can_move = true

func _process(delta: float) -> void:
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
	_player.velocity.x = dir * MOVE_SPEED; _player.velocity.y += GRAVITY * delta
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
