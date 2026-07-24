extends Node2D

class EnvironmentTracker:
	var trees_near: int = 0
	var trees_far: int = 0
	var bushes: int = 0
	var rocks: int = 0
	var total_trees: int = 0
	var total_bushes: int = 0
	var total_rocks: int = 0
	var tree_names: Array = []
	var bush_names: Array = []
	var rock_names: Array = []
	var first_rock_position: float = -9999.0
	var left_side_trees: int = 0
	var right_side_trees: int = 0
	var deepest_tree_y: float = 0.0
	var shallowest_tree_y: float = 9999.0

	func register_tree(name: String, x: float, y: float, depth_t: float) -> void:
		total_trees += 1
		tree_names.append(name)
		if depth_t < 0.4:
			trees_far += 1
		else:
			trees_near += 1
		if x < 0:
			left_side_trees += 1
		else:
			right_side_trees += 1
		if y > deepest_tree_y:
			deepest_tree_y = y
		if y < shallowest_tree_y:
			shallowest_tree_y = y

	func register_bush(name: String) -> void:
		total_bushes += 1
		bush_names.append(name)

	func register_rock(name: String, x: float) -> void:
		total_rocks += 1
		rock_names.append(name)
		if first_rock_position == -9999.0 or x < first_rock_position:
			first_rock_position = x

	func generate_questions() -> Array:
		var questions: Array = []
		if total_trees > 0:
			questions.append(_count_question("How many trees are in the forest?", total_trees))
			questions.append(_yes_no_question(
				"Are there more trees than bushes?",
				total_trees > total_bushes,
				"There are %d trees and %d bushes." % [total_trees, total_bushes]
			))
		if trees_near > 0 and trees_far > 0:
			questions.append(_yes_no_question(
				"Are there more deciduous (leafy) trees or evergreen trees?",
				trees_near > trees_far,
				"There are %d leafy and %d evergreen trees." % [trees_near, trees_far]
			))
		if total_bushes > 0:
			questions.append(_count_question("How many bushes are scattered along the path?", total_bushes))
		if total_rocks > 0:
			questions.append(_count_question("How many rocks did you pass?", total_rocks))
			questions.append(_yes_no_question(
				"Were there any rocks along the path?",
				true,
				"There were %d rocks." % total_rocks
			))
		else:
			questions.append(_yes_no_question(
				"Were there any rocks along the path?",
				false,
				"There were no rocks at all."
			))
		if total_bushes > 0 and total_rocks > 0:
			questions.append(_yes_no_question(
				"Were there more bushes than rocks?",
				total_bushes > total_rocks,
				"There were %d bushes and %d rocks." % [total_bushes, total_rocks]
			))
		if left_side_trees > 0 and right_side_trees > 0:
			questions.append(_yes_no_question(
				"Were most trees on the left side of the path?",
				left_side_trees > right_side_trees,
				"Left: %d, Right: %d." % [left_side_trees, right_side_trees]
			))
		if total_trees > 2:
			var approx = (total_trees / 5) * 5
			if approx < 5:
				approx = 5
			questions.append(_count_question(
				"Roughly how many trees did you pass? (closest to 5)",
				approx
			))
		return questions

	func _count_question(text: String, correct: int) -> Dictionary:
		var wrong: Array = []
		var offsets = [-3, -2, -1, 1, 2, 3]
		offsets.shuffle()
		for offset in offsets:
			var val = correct + offset
			if val >= 0 and val not in wrong and val != correct:
				wrong.append(val)
				if wrong.size() >= 3:
					break
		while wrong.size() < 3:
			var val = correct + wrong.size() + 5
			if val not in wrong:
				wrong.append(val)
		var options: Array = []
		options.append(str(correct))
		for w in wrong:
			options.append(str(w))
		options.shuffle()
		var correct_idx = options.find(str(correct))
		return {
			"question": text,
			"options": options,
			"correct_index": correct_idx,
			"consequence": "The forest remembers every detail...",
			"puzzle_type": RiddleManager.PuzzleType.ENVIRONMENT
		}

	func _yes_no_question(text: String, answer: bool, _hint: String) -> Dictionary:
		var options: Array = ["Yes", "No"]
		var correct_idx = 0 if answer else 1
		return {
			"question": text,
			"options": options,
			"correct_index": correct_idx,
			"consequence": _hint,
			"puzzle_type": RiddleManager.PuzzleType.ENVIRONMENT
		}

class ObservationSighting:
	var object_name: String
	var object_type: String
	var position: Vector2
	var time_seen: float

class ObservationTracker:
	var _max_sightings: int = 40
	var _sightings: Array = []
	var _forget_time: float = 15.0
	var _scan_radius: float = 350.0
	var _known_objects: Dictionary = {}

	func register_object(name: String, pos: Vector2, type: String) -> void:
		_known_objects[name] = {"pos": pos, "type": type}

	func scan_nearby(player_pos: Vector2, current_time: float) -> void:
		var seen_names: Array = []
		for obj_name in _known_objects:
			var obj = _known_objects[obj_name]
			var dist = player_pos.distance_to(obj.pos)
			if dist < _scan_radius:
				seen_names.append(obj_name)
				var exists = false
				for s in _sightings:
					if s.object_name == obj_name:
						s.time_seen = current_time
						exists = true
						break
				if not exists:
					var sighting = ObservationSighting.new()
					sighting.object_name = obj_name
					sighting.object_type = obj.type
					sighting.position = obj.pos
					sighting.time_seen = current_time
					_sightings.append(sighting)
					if _sightings.size() > _max_sightings:
						_sightings.pop_front()
		_forget_old(current_time)

	func _forget_old(current_time: float) -> void:
		var i = 0
		while i < _sightings.size():
			if current_time - _sightings[i].time_seen > _forget_time:
				_sightings.remove_at(i)
			else:
				i += 1

	func generate_observation_question(current_time: float) -> Dictionary:
		_forget_old(current_time)
		if _sightings.size() < 3:
			return {}

		var tree_count = 0
		var bush_count = 0
		var rock_count = 0
		var left_side = 0
		var right_side = 0
		var seen_names: Array = []
		for s in _sightings:
			seen_names.append(s.object_name)
			match s.object_type:
				"tree": tree_count += 1
				"bush": bush_count += 1
				"rock": rock_count += 1
			if s.position.x < 0:
				left_side += 1
			else:
				right_side += 1

		var questions: Array = []
		if tree_count >= 2:
			questions.append(_make_count_q("How many trees did you just pass?", tree_count, tree_count + randi() % 4 - 1))
		if bush_count >= 2:
			questions.append(_make_count_q("How many bushes were nearby?", bush_count, bush_count + randi() % 3 - 1))
		if rock_count >= 1:
			questions.append(_make_count_q("How many rocks did you see?", rock_count, rock_count + randi() % 3))
		if tree_count > 0 and bush_count > 0:
			questions.append(_make_yesno_q("Were there more trees than bushes?", tree_count > bush_count))
		if tree_count > 0 and left_side > 0 and right_side > 0:
			questions.append(_make_yesno_q("Were most trees on your left?", left_side > right_side))

		if questions.is_empty():
			return {}
		return questions[randi() % questions.size()]

	func _make_count_q(text: String, correct: int, alt: int) -> Dictionary:
		var wrong = alt if alt != correct and alt >= 0 else correct + 2
		var options = [str(correct), str(wrong), str(correct + randi() % 5 + 1)]
		options.shuffle()
		return {
			"question": text,
			"options": options,
			"correct_index": options.find(str(correct)),
			"consequence": "Your eyes do not deceive you.",
			"puzzle_type": RiddleManager.PuzzleType.OBSERVATION
		}

	func _make_yesno_q(text: String, answer: bool) -> Dictionary:
		return {
			"question": text,
			"options": ["Yes", "No"],
			"correct_index": 0 if answer else 1,
			"consequence": "The truth is clear to those who look.",
			"puzzle_type": RiddleManager.PuzzleType.OBSERVATION
		}

class BushDraw extends Node2D:
	var bush_color: Color = Color(0.1, 0.3, 0.08)
	var bush_width: float = 30.0
	var bush_height: float = 20.0
	var offset_y: float = -20.0

	func _draw() -> void:
		var segments = 12
		var points = PackedVector2Array()
		for i in range(segments):
			var angle = TAU * float(i) / float(segments)
			var rx = bush_width * 0.5 * (1.0 + 0.2 * sin(angle * 3.0))
			var ry = bush_height * 0.5 * (1.0 + 0.15 * cos(angle * 2.0))
			points.append(Vector2(cos(angle) * rx, offset_y + sin(angle) * ry))
		draw_colored_polygon(points, bush_color)
		var highlight = bush_color.lightened(0.15)
		var highlight_points = PackedVector2Array()
		for i in range(segments):
			var angle = TAU * float(i) / float(segments)
			var rx = bush_width * 0.3 * (1.0 + 0.2 * sin(angle * 3.0))
			var ry = bush_height * 0.3 * (1.0 + 0.15 * cos(angle * 2.0))
			highlight_points.append(Vector2(cos(angle) * rx - bush_width * 0.05, offset_y + sin(angle) * ry - bush_height * 0.05))
		draw_colored_polygon(highlight_points, highlight)

class RockDraw extends Node2D:
	var rock_color: Color = Color(0.25, 0.22, 0.18)
	var rock_width: float = 15.0
	var rock_height: float = 8.0
	var offset_y: float = -8.0

	func _draw() -> void:
		var points = PackedVector2Array([
			Vector2(-rock_width * 0.4, offset_y),
			Vector2(-rock_width * 0.5, offset_y + rock_height * 0.3),
			Vector2(-rock_width * 0.3, offset_y + rock_height),
			Vector2(rock_width * 0.2, offset_y + rock_height),
			Vector2(rock_width * 0.5, offset_y + rock_height * 0.4),
			Vector2(rock_width * 0.35, offset_y),
		])
		draw_colored_polygon(points, rock_color)
		var highlight = rock_color.lightened(0.2)
		var h_points = PackedVector2Array([
			Vector2(-rock_width * 0.2, offset_y + rock_height * 0.1),
			Vector2(rock_width * 0.1, offset_y + rock_height * 0.1),
			Vector2(rock_width * 0.15, offset_y + rock_height * 0.5),
			Vector2(-rock_width * 0.15, offset_y + rock_height * 0.5),
		])
		draw_colored_polygon(h_points, highlight)

class CircleDraw extends Node2D:
	var radius: float
	var fill_color: Color
	func _draw():
		draw_circle(Vector2.ZERO, radius, fill_color)

class SunCircle extends Node2D:
	var radius: float
	func _draw():
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.75, 0.15, 1.0))
		draw_circle(Vector2.ZERO, radius * 0.6, Color(1.0, 0.95, 0.5, 1.0))

class StarField extends Node2D:
	var stars: Array[Dictionary] = []

	func _ready():
		var rng = RandomNumberGenerator.new()
		rng.seed = 42
		for i in 60:
			stars.append({
				"x": rng.randf_range(-800, 800),
				"y": rng.randf_range(-500, 100),
				"r": rng.randf_range(0.8, 2.5),
				"a": rng.randf_range(0.15, 0.8),
				"phase": rng.randf_range(0.0, TAU),
				"twinkle_speed": rng.randf_range(0.5, 3.0)
			})

	func _draw():
		var time = Time.get_ticks_msec() / 1000.0
		for s in stars:
			var twinkle = 0.6 + 0.4 * sin(time * s.twinkle_speed + s.phase)
			var alpha = s.a * twinkle
			draw_circle(Vector2(s.x, s.y), s.r, Color(1, 1, 1, alpha))

const LEVEL_WIDTH = 8000
const DEPTH_NEAR = 600
const DEPTH_FAR = 0

const ROAD_ANGLE_FAR := 0
const ROAD_ANGLE_NEAR := 180

func _road_center_x(t: float) -> float:
	return lerp(float(ROAD_ANGLE_FAR), float(ROAD_ANGLE_NEAR), t)

var player_scene: PackedScene
var player_instance: CharacterBody2D
var hud: CanvasLayer
var dialogue_box: Node2D
var puzzle_encounter: CanvasLayer
var reset_cutscene: CanvasLayer

var current_riddle_data: Dictionary
var current_shuffled_options: Array[Dictionary]
var is_waiting_for_response: bool = false
var _generated_chunk_min: int = -25
var _generated_chunk_max: int = 25
var _chunk_idx_counter: int = 500
const CHUNK_SIZE: float = 400.0
const GENERATE_AHEAD: int = 6
var environment: EnvironmentTracker
var observation: ObservationTracker
var _observation_scan_timer: float = 0.0
var _chunk_gen_timer: float = 0.0
var _parallax_layers: Array[Dictionary] = []

var crossroad_markers: Array[Node2D] = []
var completed_crossroads: Array[int] = []
var crossroad_count: int = 6
var crossroad_spacing: float = 2000.0
var crossroad_start_x: float = 1200.0
var current_crossroad_index: int = 0
var _crossroad_enabled: Array[bool] = []
var day_night_cycle_time: float = 0.0
var _moonlight_node: Node
var _ambient_node: Node
var _warm_light: Node
var _cool_light: Node
var _light_drift_time: float = 0.0
var _firefly_particles: GPUParticles2D

# PhantomCamera
var _follow_pcam: PhantomCamera2D
var _puzzle_pcam: PhantomCamera2D

@onready var puzzle_timer: Timer = $PuzzleTriggerTimer
@onready var player_start: Marker2D = $PlayerStart

var _skybox_layer: CanvasLayer
var _sky_material: ShaderMaterial
var _star_node: Node2D
var _sun_node: Node2D
var _moon_node: Node2D
var _moon_disc: Node2D
var _skybox_width: float = 1280.0
var _skybox_height: float = 720.0
const CYCLE_TOTAL: float = 60.0
const SUN_OFFSET: float = 0.42
const SUNSET_END: float = 0.58
const GridTrans := preload("res://scripts/ui/grid_transition.gd")

func _ready() -> void:
	environment = EnvironmentTracker.new()
	observation = ObservationTracker.new()
	_build_terrain()
	_generate_forest()
	_add_leaf_particles()
	_add_leaf_litter()

	player_scene = preload("res://scenes/player.tscn")
	hud = preload("res://scenes/ui/hud.tscn").instantiate()
	dialogue_box = preload("res://scenes/ui/dialogue_box.tscn").instantiate()
	puzzle_encounter = preload("res://scenes/ui/puzzle_encounter.tscn").instantiate()
	reset_cutscene = preload("res://scenes/reset_cutscene.tscn").instantiate()

	add_child(hud)
	add_child(puzzle_encounter)
	add_child(reset_cutscene)
	reset_cutscene.visible = false

	dialogue_box.response_chosen.connect(_on_dialogue_response)
	puzzle_encounter.puzzle_result.connect(_on_puzzle_result)
	reset_cutscene.finished.connect(_on_reset_finished)
	puzzle_timer.timeout.connect(_on_puzzle_timer_timeout)
	GameManager.bonus_awarded.connect(_on_bonus_awarded)
	GameManager.state_changed.connect(_on_game_state_changed)

	_add_new_riddles()
	var ambience_stream = load("res://assets/audio/sfx/ambience.wav")
	if ambience_stream:
		AudioManager.play_ambience(ambience_stream)
	_setup_lighting()
	_load_crossroad_config()
	_build_skybox()
	_setup_crossroads()
	if get_tree().root.has_node("Transition"):
		Transition.add_style("spiral", {"shader": "spiral_wipe.gdshader", "flip": false})
	var st := SpiralTransition.new()
	get_tree().root.add_child(st)
	var gt := GridTrans.new()
	get_tree().root.add_child(gt)
	_setup_phantom_camera()
	GameManager.save_requested.connect(_on_save_requested)
	GameManager.load_completed.connect(_on_load_completed)
	GameManager.start_run()

func _setup_phantom_camera() -> void:
	if not ClassDB.class_exists(&"PhantomCamera2D"):
		return

	var tween_res := PhantomCameraTween.new()
	tween_res.duration = 0.8
	tween_res.transition = PhantomCameraTween.TransitionType.SINE
	tween_res.ease = PhantomCameraTween.EaseType.EASE_OUT

	_follow_pcam = PhantomCamera2D.new()
	_follow_pcam.name = "FollowPCam"
	_follow_pcam.priority = 5
	_follow_pcam.follow_mode = PhantomCamera2D.FollowMode.SIMPLE
	_follow_pcam.follow_damping = true
	_follow_pcam.follow_damping_value = Vector2(0.08, 0.08)
	_follow_pcam.zoom = Vector2.ONE
	_follow_pcam.tween_resource = tween_res
	add_child(_follow_pcam)

	_puzzle_pcam = PhantomCamera2D.new()
	_puzzle_pcam.name = "PuzzlePCam"
	_puzzle_pcam.priority = 0
	_puzzle_pcam.follow_mode = PhantomCamera2D.FollowMode.NONE
	_puzzle_pcam.zoom = Vector2(1.8, 1.8)
	_puzzle_pcam.tween_resource = tween_res
	add_child(_puzzle_pcam)

func _on_save_requested(data: Dictionary) -> void:
	data.completed_crossroads = completed_crossroads.duplicate()
	data.current_crossroad_index = current_crossroad_index
	data.day_night_cycle_time = day_night_cycle_time
	data.crossroad_enabled = _crossroad_enabled.duplicate()

func _on_load_completed(data: Dictionary) -> void:
	completed_crossroads = data.get("completed_crossroads", []).duplicate()
	current_crossroad_index = data.get("current_crossroad_index", 0)
	day_night_cycle_time = data.get("day_night_cycle_time", 0.0)
	if data.has("crossroad_enabled"):
		_crossroad_enabled = data.get("crossroad_enabled", []).duplicate()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		if GridTrans.is_available() and not GridTrans.is_busy():
			_test_spiral()
	if event is InputEventKey and event.keycode == KEY_T and event.pressed and not event.echo:
		if GridTrans.is_available() and not GridTrans.is_busy():
			var game := get_node_or_null("/root/Game")
			if game and game.has_method("enter_room"):
				game.enter_room()

func _test_spiral() -> void:
	await GridTrans.play(3.2)

var _game_time: float = 0.0

func _process(delta: float) -> void:
	_game_time += delta
	if GameManager.state == GameManager.GameState.PLAYING:
		_update_day_night(delta)
	_observation_scan_timer += delta
	if _observation_scan_timer >= 0.5 and player_instance:
		_observation_scan_timer = 0.0
		observation.scan_nearby(player_instance.position, _game_time)
	if player_instance and GameManager.state == GameManager.GameState.PLAYING:
		var dist = abs(player_instance.position.x)
		if dist > GameManager.max_distance:
			GameManager.max_distance = dist
	if player_instance:
		_chunk_gen_timer -= delta
		if _chunk_gen_timer <= 0.0:
			_generate_props_ahead()
			_chunk_gen_timer = 0.15
	var cam = player_instance.get_node_or_null("Camera2D") if player_instance else null
	if cam:
		var vh = _skybox_height * 0.5
		var max_y = vh - 80.0
		cam.offset.y = -max(0.0, player_instance.position.y - max_y)
	if player_instance and not _parallax_layers.is_empty():
		var px = player_instance.position.x
		for l in _parallax_layers:
			var spr = l["sprite"] as Sprite2D
			spr.position.x = -px * l["factor"] + l["tile_x"]
	_animate_lights(delta)

func _build_terrain() -> void:
	var TERRAIN_HALF = 50000

	var dirt = ColorRect.new()
	dirt.name = "Dirt"
	dirt.offset_left = -TERRAIN_HALF
	dirt.offset_top = DEPTH_FAR
	dirt.size = Vector2(TERRAIN_HALF * 2, DEPTH_NEAR - DEPTH_FAR)
	dirt.color = Color(0.12, 0.08, 0.04)
	add_child(dirt)

	var rng = RandomNumberGenerator.new()
	rng.seed = hash("perspective_stripes")
	for i in range(40):
		var t = float(i) / 40.0
		var y = DEPTH_FAR + t * (DEPTH_NEAR - DEPTH_FAR)
		var path_w = lerp(200.0, 800.0, t)
		var cx = _road_center_x(t)
		var stripe = ColorRect.new()
		stripe.offset_left = cx - path_w / 2
		stripe.offset_top = y - 1
		stripe.size = Vector2(path_w, 2)
		var c = 0.18 if i % 2 == 0 else 0.14
		stripe.color = Color(c, c * 0.7, c * 0.4)
		add_child(stripe)

	var grass_bottom = ColorRect.new()
	grass_bottom.name = "GrassBottom"
	grass_bottom.offset_left = -TERRAIN_HALF
	grass_bottom.offset_top = DEPTH_NEAR
	grass_bottom.size = Vector2(TERRAIN_HALF * 2, 60)
	grass_bottom.color = Color(0.08, 0.18, 0.06)
	add_child(grass_bottom)

func _build_skybox() -> void:
	var ws = DisplayServer.window_get_size()
	_skybox_width = max(ws.x, 1280)
	_skybox_height = max(ws.y, 720)

	var clear_layer := CanvasLayer.new()
	clear_layer.layer = -12
	add_child(clear_layer)
	var clear_rect := ColorRect.new()
	clear_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear_rect.color = Color(0.35, 0.55, 0.8)
	clear_layer.add_child(clear_rect)

	_skybox_layer = CanvasLayer.new()
	_skybox_layer.layer = -8
	_skybox_layer.offset = Vector2(0, 1)
	add_child(_skybox_layer)

	var sky_rect := ColorRect.new()
	sky_rect.name = "SkyRect"
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = preload("res://shaders/sky.gdshader")
	sky_rect.material = _sky_material
	_skybox_layer.add_child(sky_rect)

	_star_node = StarField.new()
	_star_node.name = "Stars"
	_star_node.modulate = Color(1, 1, 1, 0.0)
	_skybox_layer.add_child(_star_node)

	_sun_node = Node2D.new()
	_sun_node.name = "SunNode"
	_sun_node.modulate = Color(1, 1, 1, 0)

	var sun_glow := CircleDraw.new()
	sun_glow.name = "SunGlow"
	sun_glow.radius = 180
	sun_glow.fill_color = Color(1.0, 0.4, 0.0, 0.2)
	_sun_node.add_child(sun_glow)

	var sun_halo := CircleDraw.new()
	sun_halo.name = "SunHalo"
	sun_halo.radius = 100
	sun_halo.fill_color = Color(1.0, 0.6, 0.05, 0.4)
	_sun_node.add_child(sun_halo)

	var sun_disc := SunCircle.new()
	sun_disc.name = "SunDisc"
	sun_disc.radius = 65
	_sun_node.add_child(sun_disc)

	_skybox_layer.add_child(_sun_node)

	_moon_node = Node2D.new()
	_moon_node.name = "MoonNode"
	_moon_node.modulate = Color(1, 1, 1, 0)

	var moon_glow := CircleDraw.new()
	moon_glow.name = "MoonGlow"
	moon_glow.radius = 160
	moon_glow.fill_color = Color(0.5, 0.6, 0.9, 0.12)
	_moon_node.add_child(moon_glow)

	var moon_halo := CircleDraw.new()
	moon_halo.name = "MoonHalo"
	moon_halo.radius = 90
	moon_halo.fill_color = Color(0.7, 0.8, 1.0, 0.25)
	_moon_node.add_child(moon_halo)

	_moon_disc = CircleDraw.new()
	_moon_disc.name = "MoonDisc"
	_moon_disc.radius = 55
	_moon_disc.fill_color = Color(0.92, 0.92, 0.96, 0.95)
	_moon_node.add_child(_moon_disc)

	_skybox_layer.add_child(_moon_node)

	for c in [_star_node, _sun_node, _moon_node]:
		c.queue_redraw()
	_add_parallax_backdrop()

func _add_parallax_backdrop() -> void:
	var pl := CanvasLayer.new()
	pl.name = "ParallaxBackdrop"
	pl.layer = -10
	add_child(pl)

	var layers = [
		{ "tex": "tree_light_grey.png", "factor": 0.02, "scale": 0.15 },
		{ "tex": "medium_grey_tree.png", "factor": 0.06, "scale": 0.20, "variant": "medium_grey_tree_two.png" },
		{ "tex": "Dark_Tree.png", "factor": 0.14, "scale": 0.25, "variant": "Dark_Tree_two.png" },
	]
	_parallax_layers.clear()
	var vs = DisplayServer.window_get_size()
	var count = 20
	for l in layers:
		var tex = load("res://assets/sprites/background/" + l["tex"])
		if not tex:
			continue
		var variant_tex = null
		if l.has("variant"):
			variant_tex = load("res://assets/sprites/background/" + l["variant"])
		var sw = tex.get_size().x * l["scale"]
		var sh = tex.get_size().y * l["scale"]
		var base_y = vs.y * 0.4 - sh
		for i in range(count):
			var tex_to_use = tex
			if variant_tex and randi() % 2 == 0:
				tex_to_use = variant_tex
			var spr := Sprite2D.new()
			spr.texture = tex_to_use
			spr.centered = false
			spr.scale = Vector2.ONE * l["scale"]
			spr.position = Vector2((i - 10) * sw, base_y)
			pl.add_child(spr)
			_parallax_layers.append({ "sprite": spr, "factor": l["factor"], "tex_w": sw, "tile_x": (i - 10) * sw })

func _generate_forest() -> void:
	var props = Node2D.new()
	props.name = "ForestProps"
	props.y_sort_enabled = true
	add_child(props)
	_generated_chunk_min = -3
	_generated_chunk_max = 3
	_chunk_idx_counter = 500
	for ci in range(_generated_chunk_min, _generated_chunk_max + 1):
		_generate_chunk(ci)

func _generate_chunk(ci: int) -> void:
	var props = get_node_or_null("ForestProps")
	if not props:
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("diagonal_forest_%d" % ci)
	var cx = ci * CHUNK_SIZE

	var giant_chance = rng.randf()
	if giant_chance < 0.10:
		var gt = rng.randf_range(0.25, 0.75)
		var gx = cx + _road_center_x(gt) + rng.randf_range(-120, 120)
		var gy = DEPTH_FAR + gt * (DEPTH_NEAR - DEPTH_FAR)
		_chunk_idx_counter += 1
		var giant_w = rng.randf_range(100, 150)
		var giant_h = rng.randf_range(550, 800)
		var giant_variant = rng.randi() % 3
		_build_tree(props, "GiantTree_%d" % _chunk_idx_counter, gx, gy, Color(0.12, 0.35, 0.08), giant_w, giant_h, giant_variant, rng.randf_range(-3.0, 3.0))
		environment.register_tree("GiantTree_%d" % _chunk_idx_counter, gx, gy, gt)
		observation.register_object("GiantTree_%d" % _chunk_idx_counter, Vector2(gx, gy), "tree")

	var tree_count = rng.randi_range(1, 2)
	for i in tree_count:
		var t = rng.randf_range(0.0, 1.0)
		var ty = DEPTH_FAR + t * (DEPTH_NEAR - DEPTH_FAR)
		var path_w = lerp(200.0, 800.0, t)
		var side = 1.0 if rng.randi() % 2 == 0 else -1.0
		var dist = path_w / 2 + rng.randf_range(30, 180)
		var tx = cx + _road_center_x(t) + side * dist
		var th = rng.randf_range(150, 450)
		var tw = rng.randf_range(35, 90)
		var variant = rng.randi() % 5
		var green_palette = [Color(0.06, 0.25, 0.05), Color(0.08, 0.3, 0.06), Color(0.1, 0.2, 0.04), Color(0.05, 0.35, 0.07), Color(0.12, 0.28, 0.03)]
		var autumn_palette = [Color(0.6, 0.25, 0.05), Color(0.7, 0.35, 0.08), Color(0.5, 0.15, 0.02), Color(0.65, 0.4, 0.1), Color(0.55, 0.2, 0.04), Color(0.8, 0.45, 0.05)]
		var special_palette = [Color(0.4, 0.15, 0.3), Color(0.3, 0.4, 0.1), Color(0.5, 0.5, 0.05)]
		var color_pick = rng.randf()
		var leaf_color: Color
		if color_pick < 0.45:
			leaf_color = green_palette[rng.randi() % green_palette.size()]
		elif color_pick < 0.8:
			leaf_color = autumn_palette[rng.randi() % autumn_palette.size()]
		else:
			leaf_color = special_palette[rng.randi() % special_palette.size()]
		var tilt = rng.randf_range(-8.0, 8.0)
		_chunk_idx_counter += 1
		var tree_name = "Tree_%d" % _chunk_idx_counter
		_build_tree(props, tree_name, tx, ty, leaf_color, tw, th, variant, tilt)
		environment.register_tree(tree_name, tx, ty, t)
		observation.register_object(tree_name, Vector2(tx, ty), "tree")

	var bush_count = rng.randi_range(0, 1)
	for i in bush_count:
		var t = rng.randf_range(0.0, 1.0)
		var by = DEPTH_FAR + t * (DEPTH_NEAR - DEPTH_FAR)
		var bw = rng.randf_range(25, 45)
		var bh = rng.randf_range(18, 35)
		var bx = cx + _road_center_x(t) + rng.randf_range(-300, 300)
		_chunk_idx_counter += 1
		var bush_name = "Bush_%d" % _chunk_idx_counter
		_build_rect_prop(props, bush_name, bx, by, Color(0.1, 0.3, 0.08), bw, bh)
		environment.register_bush(bush_name)
		observation.register_object(bush_name, Vector2(bx, by), "bush")

	var rock_count = rng.randi_range(0, 1)
	for i in rock_count:
		var t = rng.randf_range(0.1, 0.9)
		var ry = DEPTH_FAR + t * (DEPTH_NEAR - DEPTH_FAR)
		var rs = rng.randf_range(12, 30)
		var rx = cx + _road_center_x(t) + rng.randf_range(-350, 350)
		_chunk_idx_counter += 1
		var rock_name = "Rock_%d" % _chunk_idx_counter
		_build_rect_prop(props, rock_name, rx, ry, Color(0.25, 0.22, 0.18), rs, rs * 0.5)
		environment.register_rock(rock_name, rx)
		observation.register_object(rock_name, Vector2(rx, ry), "rock")
	
	var shrub_count = rng.randi_range(0, 1)
	for i in shrub_count:
		var t = rng.randf_range(0.0, 1.0)
		var sy = DEPTH_FAR + t * (DEPTH_NEAR - DEPTH_FAR)
		var sw = rng.randf_range(12, 22)
		var sh = rng.randf_range(10, 18)
		var sx = cx + _road_center_x(t) + rng.randf_range(-250, 250)
		_chunk_idx_counter += 1
		var shrub_name = "Shrub_%d" % _chunk_idx_counter
		_build_rect_prop(props, shrub_name, sx, sy, Color(0.08, 0.22, 0.06), sw, sh)
		environment.register_bush(shrub_name)
		observation.register_object(shrub_name, Vector2(sx, sy), "bush")

func _generate_props_ahead() -> void:
	if not player_instance:
		return
	var player_chunk = int(floor(player_instance.position.x / CHUNK_SIZE))
	if player_chunk + GENERATE_AHEAD > _generated_chunk_max:
		_generated_chunk_max += 1
		_generate_chunk(_generated_chunk_max)
	elif player_chunk - GENERATE_AHEAD < _generated_chunk_min:
		_generated_chunk_min -= 1
		_generate_chunk(_generated_chunk_min)

func _build_tree(parent: Node2D, tree_name: String, x: float, y: float, color: Color, w: float, h: float, variant: int = 0, tilt: float = 0.0) -> void:
	var node = Node2D.new()
	node.name = tree_name
	node.position = Vector2(x, y)
	node.rotation = deg_to_rad(tilt)

	var tree = Plant2D.new()
	var depth_t = clamp((y - DEPTH_FAR) / max(1.0, DEPTH_NEAR - DEPTH_FAR), 0.0, 1.0)
	var is_far = depth_t < 0.4

	# near: 4 steps for good leaf coverage, far: 3 steps (small, minimal detail)
	var steps = 3 if is_far else 4
	var leaf_start = 2 if is_far else 3

	match variant:
		0:
			if is_far:
				var r: Dictionary[String, String] = {}
				r["X"] = "[-l+++l]f[+l---l]f[A]"
				r["A"] = "[+++B][-j]f[---C]"
				r["B"] = "[--l]f[+D]B"
				r["C"] = "[++l]f[-D]C"
				r["D"] = "E"
				r["E"] = "[--l]fD"
				tree.rules = r
				tree.angle = 26.0
				tree.branch_length = clamp(h / 12.0, 5.0, 20.0)
				tree.leaf_color = Color(color.r * 0.6, color.g * 0.7, color.b * 0.6)
				tree.leaf_scale = clamp(w / 20.0, 0.5, 2.0)
			else:
				var r: Dictionary[String, String] = {}
				r["X"] = "fA"
				r["A"] = "[--l++++l][-Y]fB"
				r["Y"] = "fB"
				r["B"] = "[--l++++l][+X]fA"
				tree.rules = r
				tree.angle = 30.0
				tree.branch_length = clamp(h / 15.0, 6.0, 40.0)
				tree.leaf_color = color
				tree.leaf_scale = clamp(w / 25.0, 0.8, 5.0)
		1:
			var r: Dictionary[String, String] = {}
			r["X"] = "f[+l][-l]"
			tree.rules = r
			tree.angle = 20.0
			tree.branch_length = clamp(h / 5.0, 10.0, 60.0)
			tree.leaf_color = color
			tree.leaf_scale = clamp(w / 12.0, 1.2, 6.0)
		2:
			if is_far:
				var r: Dictionary[String, String] = {}
				r["X"] = "l[+l][-l]f[A]"
				r["A"] = "fB"
				r["B"] = "[+l][-l]"
				tree.rules = r
				tree.angle = 35.0
				tree.branch_length = clamp(h / 10.0, 6.0, 22.0)
				tree.leaf_color = Color(color.r * 0.6, color.g * 0.7, color.b * 0.6)
				tree.leaf_scale = clamp(w / 20.0, 0.5, 2.0)
			else:
				var r: Dictionary[String, String] = {}
				r["X"] = "fA"
				r["A"] = "[--l][++l]fB"
				r["B"] = "[--l][++l]"
				tree.rules = r
				tree.angle = 35.0
				tree.branch_length = clamp(h / 12.0, 8.0, 50.0)
				tree.leaf_color = color
				tree.leaf_scale = clamp(w / 22.0, 0.8, 5.0)
		3:
			if is_far:
				var r: Dictionary[String, String] = {}
				r["X"] = "f[+F][-F]A"
				r["A"] = "f[+F][-F]B"
				r["B"] = "f[+l][-l]C"
				r["C"] = "f[+l][-l]"
				tree.rules = r
				tree.angle = 28.0
				tree.branch_length = clamp(h / 14.0, 4.0, 14.0)
				tree.leaf_color = Color(color.r * 0.7, color.g * 0.8, color.b * 0.7)
				tree.leaf_scale = clamp(w / 18.0, 0.8, 2.5)
			else:
				var r: Dictionary[String, String] = {}
				r["X"] = "fA"
				r["A"] = "[--l++++l][++l][--l]fB"
				r["B"] = "[--l++++l][++l][--l]fC"
				r["C"] = "[--l++++l][++l][--l]"
				tree.rules = r
				tree.angle = 25.0
				tree.branch_length = clamp(h / 18.0, 5.0, 30.0)
				tree.leaf_color = color
				tree.leaf_scale = clamp(w / 20.0, 1.0, 5.0)
		4:
			if is_far:
				var r: Dictionary[String, String] = {}
				r["X"] = "[+k][-k]f[+k]f[-k]f[A]"
				r["A"] = "[+k]f[-k]f[B]"
				r["B"] = "[+l]f[-l]"
				tree.rules = r
				tree.angle = 40.0
				tree.branch_length = clamp(h / 11.0, 5.0, 18.0)
				tree.leaf_color = Color(color.r * 0.5, color.g * 0.6, color.b * 0.5)
				tree.leaf_scale = clamp(w / 22.0, 0.4, 1.8)
			else:
				var r: Dictionary[String, String] = {}
				r["X"] = "fA"
				r["A"] = "[+Y]f[-Z]fB"
				r["Y"] = "[--l]f[++l]"
				r["Z"] = "[++l]f[--l]"
				r["B"] = "[+Y]f[-Z]fC"
				r["C"] = "[--l][++l]"
				tree.rules = r
				tree.angle = 38.0
				tree.branch_length = clamp(h / 13.0, 6.0, 40.0)
				tree.leaf_color = color
				tree.leaf_scale = clamp(w / 24.0, 0.6, 4.0)

	tree.max_steps = steps
	tree.current_step = steps
	tree.leaf_growth_threshold = leaf_start

	var branch_shade = Color(0.2 + color.r * 0.15, 0.12 + color.g * 0.1, 0.06 + color.b * 0.05)
	tree.branch_width = clamp(w * 0.08, 1.0, 6.0)
	tree.branch_color = branch_shade
	tree.wind_strength = randf_range(0.0, 0.05)

	node.add_child(tree)

	var body = StaticBody2D.new()
	body.name = "Collision"
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(w * 0.3, h * 0.15)
	shape.shape = rect
	shape.position = Vector2(0, -h * 0.05)
	body.add_child(shape)
	node.add_child(body)

	_make_lit(tree)
	parent.add_child(node)

func _build_rect_prop(parent: Node2D, prop_name: String, x: float, y: float, color: Color, w: float, h: float) -> void:
	var node = Node2D.new()
	node.name = prop_name
	node.position = Vector2(x, y)

	if prop_name.begins_with("Bush") or prop_name.begins_with("Shrub"):
		var bush_draw = BushDraw.new()
		bush_draw.bush_color = color
		bush_draw.bush_width = w
		bush_draw.bush_height = h
		bush_draw.offset_y = -h
		node.add_child(bush_draw)
		_make_lit(bush_draw)
	elif prop_name.begins_with("Rock"):
		var rock_draw = RockDraw.new()
		rock_draw.rock_color = color
		rock_draw.rock_width = w
		rock_draw.rock_height = h
		rock_draw.offset_y = -h
		node.add_child(rock_draw)
		_make_lit(rock_draw)

	var body = StaticBody2D.new()
	body.name = "Collision"
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(w * 0.6, h * 0.4)
	shape.shape = rect
	shape.position = Vector2(0, -h * 0.3)
	body.add_child(shape)
	node.add_child(body)

	parent.add_child(node)

func _inject_environment_questions() -> void:
	var questions = environment.generate_questions()
	for q in questions:
		RiddleManager.add_environment_question(q.question, q.options[q.correct_index], q.options.filter(func(o): return o != q.options[q.correct_index]), q.consequence)

func _add_new_riddles() -> void:
	RiddleManager.add_riddle(
		"sample text",
		"sample text", "sample text", "sample text", "sample text",
		RiddleManager.PuzzleType.PARADOX,
		"sample text",
		"sample text"
	)
	RiddleManager.add_riddle(
		"sample text",
		"sample text", "sample text", "sample text", "sample text",
		RiddleManager.PuzzleType.PARADOX,
		"sample text",
		"sample text"
	)
	RiddleManager.add_riddle(
		"sample text",
		"sample text", "sample text", "sample text", "sample text",
		RiddleManager.PuzzleType.PARADOX,
		"sample text",
		"sample text"
	)
	RiddleManager.add_riddle(
		"sample text",
		"sample text", "sample text", "sample text", "sample text",
		RiddleManager.PuzzleType.PARADOX,
		"sample text",
		"sample text"
	)
	RiddleManager.add_riddle(
		"sample text",
		"sample text", "sample text", "sample text", "sample text",
		RiddleManager.PuzzleType.OBSERVATION,
		"sample text",
		"sample text"
	)
	RiddleManager.add_riddle(
		"sample text",
		"sample text", "sample text", "sample text", "sample text",
		RiddleManager.PuzzleType.OBSERVATION,
		"sample text",
		"sample text"
	)
	RiddleManager.add_riddle(
		"sample text",
		"sample text", "sample text", "sample text", "sample text",
		RiddleManager.PuzzleType.OBSERVATION,
		"sample text",
		"sample text"
	)
	RiddleManager.add_riddle(
		"sample text",
		"sample text", "sample text", "sample text", "sample text",
		RiddleManager.PuzzleType.OBSERVATION,
		"sample text",
		"sample text"
	)

	# Miro board riddles
	RiddleManager.add_riddle(
		"Who should the bride now consider as her husband — the man who has Suryamal's head, or Suryamal's body?",
		"The man with Suryamal's head", "The man with Suryamal's body", "Neither", "Both are the same man",
		RiddleManager.PuzzleType.PARADOX,
		"A man is known by his head, not his limbs. You see the truth clearly.",
		"You severed the head from the man. A king must keep his wits together."
	)
	RiddleManager.add_riddle(
		"Between King Rupsen and Virvar, whose sacrifice is greater?",
		"King Rupsen's", "Virvar's", "Both are equal", "Neither made a sacrifice",
		RiddleManager.PuzzleType.PARADOX,
		"A king who gives all for his people is the greatest of all. You know the measure of sacrifice.",
		"You weigh gifts by their glitter, not their cost. A king must sacrifice more than coin."
	)
	RiddleManager.add_riddle(
		"Why does the thief cry and laugh simultaneously after hearing the declaration of the Rich Man?",
		"He laughs at mercy and weeps at his crimes", "He laughs at the reward and weeps at the punishment", "He laughs from madness and weeps from fear", "He does neither — it is a trick",
		RiddleManager.PuzzleType.PARADOX,
		"The thief weeps for what he stole and laughs for what he escaped. You understand the two faces of justice.",
		"You see only one side of the coin. Justice has two faces, King."
	)
	RiddleManager.add_riddle(
		"What must the king legislate?",
		"That which protects the weak", "That which strengthens the throne", "That which pleases the gods", "Nothing — law is a cage",
		RiddleManager.PuzzleType.PARADOX,
		"A king's law is the shield of the helpless. You would make a wise legislator.",
		"Laws for the throne alone are chains on the people. A king rules for all, not for himself."
	)
	RiddleManager.add_riddle(
		"Will Nageshwari kill Prince Shaktinath?",
		"Yes, fate cannot be escaped", "No, love conquers all", "She will try and fail", "The snake will spare him",
		RiddleManager.PuzzleType.PARADOX,
		"You see the fangs of fate but recognize the antidote of choice. A king bends destiny.",
		"Fate is a snake that strikes the careless king. You stepped into its path."
	)

	RiddleManager.add_second_riddle(
		"It is White to move. Find checkmate in one!\n\nThe rook travels the g-file. The bishop on e5 watches the only door out of e7.",
		RiddleManager.PuzzleType.CHESSBOARD,
		{
			"board_data": ".....k.r.....pp.............B........................................KR.",
			"correct_from": 62, "correct_to": 6,
			"consequence_right": "A king who sees the killing square deserves his crown.",
			"consequence_wrong": "A king who cannot see the killing square should not carry a head."
		}
	)
	RiddleManager.add_second_riddle(
		"It is White to move. Find checkmate in one!\n\nThe queen crosses the board. The rook on h7 holds the back door shut.",
		RiddleManager.PuzzleType.CHESSBOARD,
		{
			"board_data": ".......k.......R........................................Q......K",
			"correct_from": 56, "correct_to": 0,
			"consequence_right": "You held the killing square. Well played.",
			"consequence_wrong": "You let the king breathe. In the dark, one gasp is all we need."
		}
	)
	RiddleManager.add_second_riddle(
		"It is White to move. Find checkmate in one!\n\nThe queen steps forward one square. The rook on g7 seals the escape.",
		RiddleManager.PuzzleType.CHESSBOARD,
		{
			"board_data": ".......k.....QR........................................K.......",
			"correct_from": 13, "correct_to": 6,
			"consequence_right": "The trap springs true. The king falls.",
			"consequence_wrong": "You held the killing square in your hand and opened your fingers."
		}
	)

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.PLAYING:
			_spawn_player()
			is_waiting_for_response = false
			hud.get_node("Panel/WarningLabel").visible = false
			reset_cutscene.visible = false
		GameManager.GameState.PUZZLE:
			puzzle_timer.stop()
		GameManager.GameState.SECOND_PUZZLE:
			puzzle_timer.stop()
		GameManager.GameState.RESET:
			_trigger_reset()

func _spawn_player() -> void:
	if player_instance:
		return
	player_instance = player_scene.instantiate()
	player_instance.position = player_start.position
	add_child(player_instance)
	if _follow_pcam:
		_follow_pcam.follow_target = player_instance

func _on_puzzle_timer_timeout() -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if is_waiting_for_response:
		return
	_trigger_betaal_riddle()

func _on_crossroad_trigger_entered(body: Node2D, crossroad_idx: int) -> void:
	if body != player_instance:
		return
	if crossroad_idx != current_crossroad_index:
		return
	if is_waiting_for_response:
		return
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if completed_crossroads.has(crossroad_idx):
		return
	if not _is_crossroad_enabled(crossroad_idx):
		return
	var marker_node = crossroad_markers[crossroad_idx] if crossroad_idx < crossroad_markers.size() else null
	if not marker_node:
		return
	var trigger_node = marker_node.get_node_or_null("CenterDot")
	if trigger_node:
		trigger_node.set_deferred("monitoring", false)
	_trigger_betaal_riddle()

func _trigger_betaal_riddle() -> void:
	is_waiting_for_response = true
	current_riddle_data = RiddleManager.get_random_riddle()
	if current_riddle_data.is_empty():
		is_waiting_for_response = false
		return

	if current_crossroad_index < crossroad_markers.size():
		var mk = crossroad_markers[current_crossroad_index]
		if mk:
			mk.modulate = Color(1, 1, 1, 0)
			mk.visible = true
			var reveal = create_tween()
			reveal.tween_property(mk, "modulate", Color(1, 1, 1, 1), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	GameManager.trigger_puzzle()
	GameManager.puzzle_type_changed.emit(current_riddle_data.get("puzzle_type", 0))
	if player_instance:
		var betaal = player_instance.get_node_or_null("Visual/BetaalPosition/Betaal")
		if betaal and betaal.has_method("start_speaking"):
			betaal.start_speaking()
		if _puzzle_pcam:
			var crossroad_pos = _get_crossroad_position(current_crossroad_index)
			_puzzle_pcam.position = crossroad_pos
			_puzzle_pcam.priority = 10
		if _follow_pcam:
			_follow_pcam.follow_target = player_instance

	await get_tree().create_timer(5.0).timeout
	puzzle_encounter.show_riddle(current_riddle_data, false)

func _stop_betaal_speaking() -> void:
	if player_instance:
		var betaal = player_instance.get_node_or_null("Visual/BetaalPosition/Betaal")
		if betaal and betaal.has_method("stop_speaking"):
			betaal.stop_speaking()

func _on_dialogue_response(response: bool) -> void:
	dialogue_box.hide_box()
	if dialogue_box.get_parent():
		dialogue_box.get_parent().remove_child(dialogue_box)
	_stop_betaal_speaking()
	_reset_camera_zoom()

func _reset_camera_zoom() -> void:
	if _puzzle_pcam:
		_puzzle_pcam.priority = 0

func _on_bonus_awarded(bonus_type: String) -> void:
	match bonus_type:
		"jump":
			if player_instance and player_instance.has_method("activate_jump_boost"):
				player_instance.activate_jump_boost()
			_show_bonus_popup("+30%% Jump Height!", Color(0.3, 1.0, 0.3))
		"life":
			_show_bonus_popup("+1 Extra Life!", Color(0.3, 0.8, 1.0))
		"speed":
			if player_instance and player_instance.has_method("activate_speed_boost"):
				player_instance.activate_speed_boost(10.0)
			_show_bonus_popup("+20%% Speed!", Color(0.3, 1.0, 0.3))

func _show_bonus_popup(text: String, color: Color) -> void:
	if not player_instance:
		return
	var label = Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 1)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.position = player_instance.position + Vector2(0, -60)
	add_child(label)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_delay(0.5)
	await tween.finished
	label.queue_free()

func _on_puzzle_result(correct: bool) -> void:
	puzzle_encounter.hide_puzzle()
	_stop_betaal_speaking()
	_reset_camera_zoom()
	is_waiting_for_response = false
	current_riddle_data = {}
	current_shuffled_options = []

func _trigger_reset() -> void:
	_stop_betaal_speaking()
	observation = ObservationTracker.new()
	_game_time = 0.0
	puzzle_timer.stop()
	is_waiting_for_response = false
	if player_instance:
		player_instance.queue_free()
		player_instance = null
	reset_cutscene.visible = true
	reset_cutscene.play()
	hud.reset()

func _re_register_forest_props() -> void:
	var forest = get_node_or_null("ForestProps")
	if not forest:
		return
	for child in forest.get_children():
		var name_lower = child.name.to_lower()
		var type = "tree"
		if name_lower.begins_with("bush"):
			type = "bush"
		elif name_lower.begins_with("rock"):
			type = "rock"
		observation.register_object(child.name, child.position, type)

func _on_reset_finished() -> void:
	reset_cutscene.visible = false
	_re_register_forest_props()
	GameManager.on_reset_complete()

func _add_leaf_particles() -> void:
	var leaf_texture = load("res://addons/PlantGenerator/Assets/leaf.png")
	if not leaf_texture:
		return
	var particles = GPUParticles2D.new()
	particles.name = "LeafParticles"
	particles.position = Vector2(0, -200)
	particles.z_index = 1
	particles.amount = 8
	particles.lifetime = 8.0
	particles.explosiveness = 0.0
	particles.randomness = 0.4
	particles.one_shot = false
	particles.preprocess = 4.0
	particles.visibility_rect = Rect2(-600, -300, 1200, 1200)
	particles.trail_enabled = false

	var material = ParticleProcessMaterial.new()
	material.particle_flag_align_y = true
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 180.0
	material.gravity = Vector3(0.0, 1.5, 0.0)
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 8.0
	material.angular_velocity_min = -120.0
	material.angular_velocity_max = 120.0
	material.scale_min = 0.08
	material.scale_max = 0.18
	material.color = Color(0.15, 0.65, 0.1, 0.5)
	var color_ramp = Gradient.new()
	color_ramp.colors = PackedColorArray([Color(0.2, 0.8, 0.15, 0.6), Color(0.1, 0.5, 0.1, 0.3), Color(0.3, 0.7, 0.15, 0.1)])
	material.color_ramp = color_ramp
	material.hue_variation_min = -0.1
	material.hue_variation_max = 0.1
	particles.process_material = material
	particles.texture = leaf_texture
	add_child(particles)

func _add_leaf_litter() -> void:
	var leaf_texture = load("res://addons/PlantGenerator/Assets/leaf.png")
	if not leaf_texture:
		return
	var forest = get_node_or_null("ForestProps")
	if not forest:
		return
	for i in 30:
		var x = randi_range(-1600, 1600)
		var y = randi_range(50, 550)
		var leaf = Sprite2D.new()
		leaf.texture = leaf_texture
		var sw = randf_range(0.2, 1.0)
		var sh = randf_range(0.2, 1.0)
		leaf.scale = Vector2(sw, sh)
		leaf.rotation = randf_range(0, TAU)
		leaf.flip_h = randi() % 2 == 0
		leaf.flip_v = randi() % 2 == 0
		leaf.modulate = Color(
			randf_range(0.3, 0.8),
			randf_range(0.1, 0.5),
			randf_range(0.02, 0.25),
			randf_range(0.6, 1.0)
		)
		leaf.position = Vector2(x, y)
		leaf.z_index = 0 if randi() % 2 == 0 else -1
		forest.add_child(leaf)
		_make_lit(leaf)

func _get_crossroad_position(idx: int) -> Vector2:
	return Vector2(crossroad_start_x + idx * crossroad_spacing, lerp(200.0, 80.0, float(idx) / float(crossroad_count - 1)))

func _load_crossroad_config() -> void:
	var path = "res://config/crossroads.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var parsed = JSON.parse_string(json_string)
		if parsed is Dictionary and parsed.has("crossroads"):
			var arr = parsed["crossroads"] as Array
			_crossroad_enabled.resize(crossroad_count)
			for entry in arr:
				if entry is Dictionary and entry.has("index"):
					var idx = int(entry["index"])
					if idx >= 0 and idx < crossroad_count:
						_crossroad_enabled[idx] = bool(entry.get("enabled", false))
	file.close()

func _is_crossroad_enabled(idx: int) -> bool:
	if idx < 0 or idx >= _crossroad_enabled.size():
		return true
	return _crossroad_enabled[idx]

func _setup_crossroads() -> void:
	for i in range(crossroad_count):
		if _is_crossroad_enabled(i):
			_generate_crossroad(i)
			return

func _generate_crossroad(idx: int) -> void:
	if idx >= crossroad_count:
		return
	if idx < crossroad_markers.size():
		return

	if not _is_crossroad_enabled(idx):
		crossroad_markers.append(null)
		return

	var p = _get_crossroad_position(idx)
	var cy = p.y
	var cx = p.x

	var marker = Node2D.new()
	marker.name = "Crossroad_%d" % idx
	marker.position = Vector2(0, 0)
	marker.visible = false
	add_child(marker)

	var stripe_count = 40
	var road_max_y = 600.0
	var dark_col = Color(0.02, 0.015, 0.01, 0.8)
	var dark_fork = Color(0.015, 0.025, 0.01, 0.85)

	for i in range(stripe_count):
		var t = float(i) / float(stripe_count - 1)
		var y = t * road_max_y
		var path_w = lerp(200.0, 800.0, t)
		var rcx = cx + _road_center_x(t)

		if y >= cy:
			var stripe = ColorRect.new()
			stripe.size = Vector2(path_w, 2)
			stripe.color = dark_col
			stripe.position = Vector2(rcx - path_w / 2, y - 1)
			marker.add_child(stripe)
		else:
			var depth_t = 1.0 - y / max(cy, 1.0)
			var spread = lerp(40.0, 220.0, depth_t)
			var arm_w = lerp(180.0, 50.0, depth_t)

			var left = ColorRect.new()
			left.size = Vector2(arm_w, 2)
			left.color = dark_fork
			left.position = Vector2(rcx - arm_w - spread, y - 1)
			marker.add_child(left)

			var right = ColorRect.new()
			right.size = Vector2(arm_w, 2)
			right.color = dark_fork
			right.position = Vector2(rcx + spread, y - 1)
			marker.add_child(right)

	var t_cy = cy / road_max_y
	var trigger = Area2D.new()
	trigger.name = "CenterDot"
	trigger.position = Vector2(cx + _road_center_x(t_cy), cy)

	var dot_visual = ColorRect.new()
	dot_visual.name = "DotVisual"
	dot_visual.size = Vector2(16, 16)
	dot_visual.color = Color(0.6, 0.2, 0.15, 0.95)
	dot_visual.position = Vector2(-8, -8)
	trigger.add_child(dot_visual)

	var band_collision = CollisionShape2D.new()
	var band_shape = RectangleShape2D.new()
	band_shape.size = Vector2(800, 600)
	band_collision.shape = band_shape
	band_collision.position = Vector2(0, 300 - cy)
	trigger.add_child(band_collision)

	trigger.collision_mask = 1
	trigger.body_entered.connect(_on_crossroad_trigger_entered.bind(idx))

	var band_debug = ColorRect.new()
	band_debug.size = Vector2(800, 600)
	band_debug.color = Color(1, 0, 0, 0.05)
	band_debug.position = Vector2(-400, -cy)
	trigger.add_child(band_debug)

	marker.add_child(trigger)

	var label = Label.new()
	label.name = "ForkLabel"
	label.text = "%d" % (idx + 1)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.8, 1))
	label.position = Vector2(cx - 10, cy + 10)
	label.z_index = 2
	marker.add_child(label)

	var glow = ColorRect.new()
	glow.name = "Glow"
	glow.size = Vector2(800, 600)
	glow.color = Color(0.3, 0.05, 0.05, 0.06)
	glow.position = Vector2(cx - 400, 0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(glow)
	marker.move_child(glow, 0)

	crossroad_markers.append(marker)

func _light_crossroad(outcome_difficulty: int) -> void:
	var idx = current_crossroad_index - 1
	if idx < 0 or idx >= crossroad_markers.size():
		return
	var marker = crossroad_markers[idx]
	if not marker:
		return
	var center_dot = marker.get_node_or_null("CenterDot")
	if not center_dot:
		return
	var dot_visual = center_dot.get_node_or_null("DotVisual")
	if not dot_visual:
		return

	var lit_color: Color
	var glow_color: Color
	var cp = _get_crossroad_position(idx)
	match outcome_difficulty:
		RiddleManager.LevelDifficulty.EASY:
			lit_color = Color(0.1, 0.95, 0.15, 1.0)
			glow_color = Color(0.05, 0.9, 0.1, 0.5)
		RiddleManager.LevelDifficulty.HARD:
			lit_color = Color(0.95, 0.1, 0.1, 1.0)
			glow_color = Color(0.9, 0.05, 0.05, 0.5)
		RiddleManager.LevelDifficulty.NORMAL:
			lit_color = Color(0.95, 0.7, 0.05, 1.0)
			glow_color = Color(0.9, 0.6, 0.05, 0.5)

	dot_visual.color = lit_color
	for child in marker.get_children():
		if child.name == "Glow" or child.name == "ForkLabel":
			continue
		if child is ColorRect:
			child.color = lit_color

	var existing_glow = marker.get_node_or_null("Glow")
	if existing_glow:
		existing_glow.queue_free()
	var new_glow = ColorRect.new()
	new_glow.name = "Glow"
	new_glow.size = Vector2(500, 700)
	new_glow.color = glow_color
	new_glow.position = Vector2(cp.x - 250, cp.y - 300)
	new_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(new_glow)
	marker.move_child(new_glow, 0)

func _mark_crossroad_completed() -> void:
	if current_crossroad_index >= crossroad_count:
		return
	if current_crossroad_index < crossroad_markers.size():
		var marker = crossroad_markers[current_crossroad_index]
		if marker:
			var center_dot = marker.get_node_or_null("CenterDot")
			var dot_visual = center_dot.get_node_or_null("DotVisual") if center_dot else null
			if dot_visual:
				dot_visual.color = Color(0.15, 0.85, 0.15, 0.95)
			for child in marker.get_children():
				if child.name == "Glow" or child.name == "ForkLabel":
					continue
				if child is ColorRect:
					child.color = Color(0.2, 0.7, 0.15, 0.6)
	completed_crossroads.append(current_crossroad_index)
	current_crossroad_index += 1
	while current_crossroad_index < crossroad_count and not _is_crossroad_enabled(current_crossroad_index):
		completed_crossroads.append(current_crossroad_index)
		current_crossroad_index += 1
	_generate_crossroad(current_crossroad_index)
	GameManager.save_game()

func _update_day_night(delta: float) -> void:
	if not _moonlight_node:
		return
	day_night_cycle_time += delta
	var cycle_progress = fmod(day_night_cycle_time, CYCLE_TOTAL) / CYCLE_TOTAL

	var night_factor: float
	var sunset_glow: float
	if cycle_progress < SUN_OFFSET:
		night_factor = 0.0
		sunset_glow = 0.0
	elif cycle_progress < SUNSET_END:
		var dusk_t = (cycle_progress - SUN_OFFSET) / (SUNSET_END - SUN_OFFSET)
		night_factor = dusk_t
		sunset_glow = sin(dusk_t * PI)
	else:
		night_factor = 1.0
		sunset_glow = 0.0

	if _sky_material:
		_sky_material.set_shader_parameter("night_factor", night_factor)
		_sky_material.set_shader_parameter("sunset_glow", sunset_glow)

	var star_alpha = clamp((night_factor - 0.3) / 0.3, 0.0, 1.0) if night_factor > 0.3 else 0.0
	if _star_node:
		_star_node.modulate = Color(1, 1, 1, star_alpha)
		_star_node.queue_redraw()

	var cam_y = player_instance.position.y if player_instance else _skybox_height * 0.3
	var cam = player_instance.get_node_or_null("Camera2D") if player_instance else null
	if cam:
		cam_y = player_instance.position.y + cam.offset.y
	var view_half = _skybox_height * 0.5
	var terrain_top_screen = 0.0 - cam_y + view_half
	var sky_top = clamp(terrain_top_screen * 0.12, 8.0, _skybox_height * 0.4)
	var sky_horizon = clamp(terrain_top_screen - 20.0, sky_top + 30.0, _skybox_height * 0.5)

	var hw = _skybox_width * 0.5
	var mid_x = hw

	var sun_alpha: float
	var sun_x: float
	var sun_y: float
	if cycle_progress < SUNSET_END + 0.06:
		var sun_t = cycle_progress / (SUNSET_END + 0.06)
		sun_t = clamp(sun_t, 0.0, 1.0)
		sun_alpha = 1.0
		if sun_t > 0.9:
			sun_alpha = 1.0 - (sun_t - 0.9) / 0.1
		var sun_arc_angle = sun_t * PI - PI * 0.5
		sun_x = mid_x + sin(sun_arc_angle) * hw * 0.55
		sun_y = sky_horizon - (cos(sun_arc_angle) * 0.5 + 0.5) * (sky_horizon - sky_top) * 0.9
	else:
		sun_alpha = 0.0
		sun_x = _skybox_width + 200
		sun_y = sky_horizon
	if _sun_node:
		_sun_node.position = Vector2(sun_x, sun_y)
		_sun_node.modulate = Color(1, 1, 1, sun_alpha)

	var moon_alpha: float
	var moon_x: float
	var moon_y: float
	if cycle_progress > SUN_OFFSET - 0.05:
		var moon_start = SUN_OFFSET - 0.05
		var moon_duration = 1.0 - moon_start
		var moon_t = clamp((cycle_progress - moon_start) / moon_duration, 0.0, 1.0)
		moon_alpha = 0.0
		if moon_t < 0.15:
			moon_alpha = moon_t / 0.15
		elif moon_t > 0.85:
			moon_alpha = 1.0 - (moon_t - 0.85) / 0.15
		else:
			moon_alpha = 1.0
		var moon_arc = moon_t * PI - PI * 0.5
		moon_x = mid_x + sin(moon_arc) * hw * 0.55
		moon_y = sky_top + 20.0 + (1.0 - cos(moon_arc)) * 0.5 * (sky_horizon - sky_top) * 0.7
	else:
		moon_alpha = 0.0
		moon_x = -200
		moon_y = sky_top
	if _moon_node:
		_moon_node.position = Vector2(moon_x, moon_y)
		_moon_node.modulate = Color(1, 1, 1, moon_alpha)

	var light_angle: float
	var light_color: Color
	if cycle_progress < SUN_OFFSET:
		var day_t = cycle_progress / SUN_OFFSET
		light_angle = lerp(-60.0, -10.0, day_t)
		light_color = Color(1.0, 0.95, 0.85)
		if _moonlight_node:
			_moonlight_node.energy = lerp(2.0, 3.5, day_t)
	elif cycle_progress < SUNSET_END:
		var dusk_t = (cycle_progress - SUN_OFFSET) / (SUNSET_END - SUN_OFFSET)
		light_angle = lerp(-10.0, 50.0, dusk_t)
		light_color = Color(1.0, lerp(0.95, 0.4, dusk_t), lerp(0.85, 0.15, dusk_t))
		if _moonlight_node:
			_moonlight_node.energy = lerp(3.5, 0.8, dusk_t)
	else:
		var night_t = (cycle_progress - SUNSET_END) / (1.0 - SUNSET_END)
		light_angle = lerp(50.0, -60.0, night_t)
		light_color = Color(0.55, 0.65, 0.95)
		if _moonlight_node:
			_moonlight_node.energy = lerp(0.8, 2.5, night_t)
	if _moonlight_node:
		_moonlight_node.rotation = deg_to_rad(light_angle)
		_moonlight_node.color = light_color

	var amb_energy: float
	if cycle_progress < SUN_OFFSET:
		amb_energy = lerp(0.25, 0.08, cycle_progress / SUN_OFFSET)
	elif cycle_progress < SUNSET_END:
		amb_energy = lerp(0.08, 0.015, (cycle_progress - SUN_OFFSET) / (SUNSET_END - SUN_OFFSET))
	else:
		amb_energy = lerp(0.015, 0.06, (cycle_progress - SUNSET_END) / (1.0 - SUNSET_END))
	if _ambient_node and _ambient_node.has_method("set_ambient_energy"):
		_ambient_node.ambient_energy = amb_energy

func _animate_lights(delta: float) -> void:
	if not _warm_light or not _cool_light:
		return
	_light_drift_time += delta

	var cycle_progress = fmod(day_night_cycle_time, CYCLE_TOTAL) / CYCLE_TOTAL
	var night_factor: float
	if cycle_progress < SUN_OFFSET:
		night_factor = 0.0
	elif cycle_progress < SUNSET_END:
		night_factor = (cycle_progress - SUN_OFFSET) / (SUNSET_END - SUN_OFFSET)
	else:
		night_factor = 1.0

	var t = _light_drift_time
	var drift_x = sin(t * 0.15) * 80.0 + cos(t * 0.23) * 50.0
	var drift_y = cos(t * 0.19) * 60.0 + sin(t * 0.27) * 40.0
	_warm_light.position = Vector2(-200 + drift_x, 200 + drift_y)

	var cool_drift_x = sin(t * 0.21 + 1.7) * 70.0 + cos(t * 0.17) * 60.0
	var cool_drift_y = cos(t * 0.13 + 0.8) * 50.0 + sin(t * 0.29) * 45.0
	_cool_light.position = Vector2(200 + cool_drift_x, 50 + cool_drift_y)

	var warm_energy = 0.25 + 0.1 * sin(t * 1.3) + 0.05 * sin(t * 3.7)
	var cool_energy = 0.18 + 0.08 * sin(t * 0.9 + 2.1) + 0.04 * sin(t * 4.1)
	var warm_color = Color(
		1.0 - night_factor * 0.2,
		0.7 - night_factor * 0.15,
		0.3 + night_factor * 0.3
	)
	var cool_color = Color(
		0.3 + night_factor * 0.2,
		0.5 + night_factor * 0.15,
		1.0 - night_factor * 0.1
	)
	_warm_light.energy = warm_energy * (1.0 - night_factor * 0.4)
	_warm_light.color = warm_color
	_cool_light.energy = cool_energy * (0.5 + night_factor * 0.8)
	_cool_light.color = cool_color

	if _firefly_particles and player_instance:
		_firefly_particles.position = player_instance.position

func _make_lit(item: CanvasItem) -> void:
	var shader = load("res://addons/lit/shaders/lit_receiver_fast.gdshader")
	if not shader:
		return
	var mat = ShaderMaterial.new()
	mat.shader = shader
	item.material = mat

func _setup_lighting() -> void:
	if not ClassDB.class_exists(&"LitCanvasModulate"):
		return

	_ambient_node = LitCanvasModulate.new()
	_ambient_node.color = Color(0.04, 0.04, 0.12)
	_ambient_node.ambient_energy = 0.15
	add_child(_ambient_node)

	_moonlight_node = LitDirectionalLight2D.new()
	_moonlight_node.color = Color(0.55, 0.65, 0.95)
	_moonlight_node.energy = 3.5
	_moonlight_node.shadow_enabled = false
	_moonlight_node.rotation = deg_to_rad(-35)
	add_child(_moonlight_node)

	var pp = LitPostProcess.new()
	pp.bloom_enabled = true
	pp.bloom_threshold = 0.4
	pp.bloom_intensity = 0.15
	pp.bloom_radius = 0.5
	pp.grade_enabled = true
	pp.exposure = 0.8
	pp.contrast = 1.3
	pp.saturation = 0.6
	pp.vignette_enabled = true
	pp.vignette_strength = 0.4
	pp.layer = 5
	add_child(pp)

	if ClassDB.class_exists(&"LitPointLight2D"):
		_warm_light = LitPointLight2D.new()
		_warm_light.name = "AmbientWarmLight"
		_warm_light.energy = 0.3
		_warm_light.range = 600
		_warm_light.color = Color(1.0, 0.7, 0.3)
		_warm_light.position = Vector2(-200, 200)
		_warm_light.shadow_enabled = false
		add_child(_warm_light)

		_cool_light = LitPointLight2D.new()
		_cool_light.name = "AmbientCoolLight"
		_cool_light.energy = 0.2
		_cool_light.range = 500
		_cool_light.color = Color(0.3, 0.5, 1.0)
		_cool_light.position = Vector2(200, 50)
		_cool_light.shadow_enabled = false
		add_child(_cool_light)

	_setup_fireflies()

func _setup_fireflies() -> void:
	_firefly_particles = GPUParticles2D.new()
	_firefly_particles.name = "FireflyParticles"
	_firefly_particles.amount = 15
	_firefly_particles.lifetime = 6.0
	_firefly_particles.explosiveness = 0.0
	_firefly_particles.randomness = 0.6
	_firefly_particles.one_shot = false
	_firefly_particles.preprocess = 3.0
	_firefly_particles.visibility_rect = Rect2(-800, -400, 1600, 1200)
	_firefly_particles.z_index = 2

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3(0.0, -0.5, 0.0)
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 12.0
	mat.linear_accel_min = -2.0
	mat.linear_accel_max = 2.0
	mat.angular_velocity_min = -30.0
	mat.angular_velocity_max = 30.0
	mat.scale_min = 0.08
	mat.scale_max = 0.25
	mat.color = Color(1.0, 0.95, 0.6, 0.8)
	mat.hue_variation_min = -0.05
	mat.hue_variation_max = 0.05
	_firefly_particles.process_material = mat
	add_child(_firefly_particles)
