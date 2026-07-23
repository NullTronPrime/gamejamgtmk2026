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
		if seen_names.size() >= 2:
			var a = seen_names[randi() % seen_names.size()]
			var b = a
			while b == a and seen_names.size() > 1:
				b = seen_names[randi() % seen_names.size()]
			questions.append(_make_yesno_q("Did you see \"" + a + "\" before \"" + b + "\"?", false))

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

const LEVEL_WIDTH = 8000
const DEPTH_NEAR = 600
const DEPTH_FAR = 0

var player_scene: PackedScene
var player_instance: CharacterBody2D
var hud: CanvasLayer
var dialogue_box: CanvasLayer
var puzzle_encounter: CanvasLayer
var reset_cutscene: CanvasLayer

var current_riddle_data
var is_waiting_for_response: bool = false
var _leaf_particles: GPUParticles2D
var _generated_chunk_min: int = -25
var _generated_chunk_max: int = 25
var _chunk_idx_counter: int = 500
const CHUNK_SIZE: float = 400.0
const GENERATE_AHEAD: int = 8
var environment: EnvironmentTracker
var observation: ObservationTracker
var _observation_scan_timer: float = 0.0

@onready var puzzle_timer: Timer = $PuzzleTriggerTimer
@onready var player_start: Marker2D = $PlayerStart

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
	add_child(dialogue_box)
	add_child(puzzle_encounter)
	add_child(reset_cutscene)

	dialogue_box.response_chosen.connect(_on_dialogue_response)
	puzzle_encounter.puzzle_result.connect(_on_puzzle_result)
	reset_cutscene.finished.connect(_on_reset_finished)
	puzzle_timer.timeout.connect(_on_puzzle_timer_timeout)
	GameManager.bonus_awarded.connect(_on_bonus_awarded)
	GameManager.state_changed.connect(_on_game_state_changed)

	_add_sample_riddles()
	_inject_environment_questions()
	var ambience_stream = load("res://assets/audio/sfx/ambience.wav")
	if ambience_stream:
		AudioManager.play_ambience(ambience_stream)
	GameManager.start_run()

var _game_time: float = 0.0

func _process(delta: float) -> void:
	_game_time += delta
	_observation_scan_timer += delta
	if _observation_scan_timer >= 0.5 and player_instance:
		_observation_scan_timer = 0.0
		observation.scan_nearby(player_instance.position, _game_time)
	if player_instance and GameManager.state == GameManager.GameState.PLAYING:
		var dist = abs(player_instance.position.x)
		if dist > GameManager.max_distance:
			GameManager.max_distance = dist
	if _leaf_particles and player_instance:
		_leaf_particles.position.x = player_instance.position.x
		_leaf_particles.position.y = player_instance.position.y - 300
	if player_instance:
		_generate_props_ahead()

func _build_terrain() -> void:
	var TERRAIN_HALF = 50000
	var sky = ColorRect.new()
	sky.name = "Sky"
	sky.offset_left = -TERRAIN_HALF
	sky.offset_top = -800
	sky.size = Vector2(TERRAIN_HALF * 2, 2000)
	sky.color = Color(0.02, 0.02, 0.08)
	add_child(sky)
	move_child(sky, 0)

	var moon = ColorRect.new()
	moon.name = "Moon"
	moon.offset_left = 1800
	moon.offset_top = 80
	moon.size = Vector2(60, 60)
	moon.color = Color(0.85, 0.85, 0.9, 0.95)
	add_child(moon)
	move_child(moon, 1)
	var moon_glow = ColorRect.new()
	moon_glow.name = "MoonGlow"
	moon_glow.offset_left = 1760
	moon_glow.offset_top = 40
	moon_glow.size = Vector2(140, 140)
	moon_glow.color = Color(0.3, 0.3, 0.5, 0.15)
	add_child(moon_glow)
	move_child(moon_glow, 1)

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
		var stripe = ColorRect.new()
		stripe.offset_left = -path_w / 2
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

func _generate_forest() -> void:
	var props = Node2D.new()
	props.name = "ForestProps"
	props.y_sort_enabled = true
	add_child(props)
	_generated_chunk_min = -1
	_generated_chunk_max = 1
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

	if rng.randf() < 0.08:
		var gx = cx + rng.randf_range(-100, 100)
		var gy = DEPTH_FAR + rng.randf_range(0.3, 0.7) * (DEPTH_NEAR - DEPTH_FAR)
		var gt = (gy - DEPTH_FAR) / max(1.0, DEPTH_NEAR - DEPTH_FAR)
		_chunk_idx_counter += 1
		_build_tree(props, "GiantTree_%d" % _chunk_idx_counter, gx, gy, Color(0.12, 0.35, 0.08), rng.randf_range(40, 60), rng.randf_range(280, 350), 0, rng.randf_range(-3.0, 3.0))
		environment.register_tree("GiantTree_%d" % _chunk_idx_counter, gx, gy, gt)
		observation.register_object("GiantTree_%d" % _chunk_idx_counter, Vector2(gx, gy), "tree")

	var tree_count = rng.randi_range(2, 4)
	for i in tree_count:
		var t = rng.randf_range(0.0, 1.0)
		var ty = DEPTH_FAR + t * (DEPTH_NEAR - DEPTH_FAR)
		var path_w = lerp(200.0, 800.0, t)
		var side = 1.0 if rng.randi() % 2 == 0 else -1.0
		var dist = path_w / 2 + rng.randf_range(20, 140)
		var tx = cx + side * dist
		var th = rng.randf_range(80, 250)
		var tw = rng.randf_range(15, 50)
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

	var bush_count = rng.randi_range(1, 2)
	for i in bush_count:
		var t = rng.randf_range(0.0, 1.0)
		var by = DEPTH_FAR + t * (DEPTH_NEAR - DEPTH_FAR)
		var bw = rng.randf_range(20, 35)
		var bh = rng.randf_range(15, 25)
		var bx = cx + rng.randf_range(-200, 200)
		_chunk_idx_counter += 1
		var bush_name = "Bush_%d" % _chunk_idx_counter
		_build_rect_prop(props, bush_name, bx, by, Color(0.1, 0.3, 0.08), bw, bh)
		environment.register_bush(bush_name)
		observation.register_object(bush_name, Vector2(bx, by), "bush")

	var rock_count = rng.randi_range(0, 1)
	for i in rock_count:
		var t = rng.randf_range(0.1, 0.9)
		var ry = DEPTH_FAR + t * (DEPTH_NEAR - DEPTH_FAR)
		var rs = rng.randf_range(10, 20)
		var rx = cx + rng.randf_range(-300, 300)
		_chunk_idx_counter += 1
		var rock_name = "Rock_%d" % _chunk_idx_counter
		_build_rect_prop(props, rock_name, rx, ry, Color(0.25, 0.22, 0.18), rs, rs * 0.5)
		environment.register_rock(rock_name, rx)
		observation.register_object(rock_name, Vector2(rx, ry), "rock")

func _generate_props_ahead() -> void:
	if not player_instance:
		return
	var player_chunk = int(floor(player_instance.position.x / CHUNK_SIZE))
	while player_chunk + GENERATE_AHEAD > _generated_chunk_max:
		_generated_chunk_max += 1
		_generate_chunk(_generated_chunk_max)
	while player_chunk - GENERATE_AHEAD < _generated_chunk_min:
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
	var is_dark = (color.r + color.g + color.b) / 3.0 < 0.2

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
				tree.max_steps = 9
				tree.current_step = 9
				tree.branch_length = clamp(h / 12.0, 5.0, 20.0)
				tree.angle = 26.0
				tree.leaf_growth_threshold = 5.0
				tree.leaf_color = Color(color.r * 0.6, color.g * 0.7, color.b * 0.6)
				tree.leaf_scale = clamp(w / 20.0, 0.5, 2.0)
			else:
				var r: Dictionary[String, String] = {}
				r["X"] = "fA"
				r["A"] = "[--l++++l][-Y]fB"
				r["Y"] = "fB"
				r["B"] = "[--l++++l][+X]fA"
				tree.rules = r
				tree.max_steps = 10
				tree.current_step = 10
				tree.branch_length = clamp(h / 15.0, 6.0, 18.0)
				tree.angle = 30.0
				tree.leaf_growth_threshold = 9.0
				tree.leaf_color = color
				tree.leaf_scale = clamp(w / 25.0, 0.8, 2.5)
		1:
			var r: Dictionary[String, String] = {}
			r["X"] = "f[+l][-l]"
			tree.rules = r
			tree.max_steps = 4
			tree.current_step = 4
			tree.angle = 20.0
			tree.branch_length = clamp(h / 5.0, 10.0, 35.0)
			tree.leaf_growth_threshold = 10.0
			tree.leaf_color = color
			tree.leaf_scale = clamp(w / 12.0, 1.2, 3.5)
		2:
			if is_far:
				var r: Dictionary[String, String] = {}
				r["X"] = "l[+l][-l]f[A]"
				r["A"] = "fB"
				r["B"] = "[+l][-l]"
				tree.rules = r
				tree.max_steps = 6
				tree.current_step = 6
				tree.branch_length = clamp(h / 10.0, 6.0, 22.0)
				tree.angle = 35.0
				tree.leaf_growth_threshold = 4.0
				tree.leaf_color = Color(color.r * 0.6, color.g * 0.7, color.b * 0.6)
				tree.leaf_scale = clamp(w / 20.0, 0.5, 2.0)
			else:
				var r: Dictionary[String, String] = {}
				r["X"] = "fA"
				r["A"] = "[--l][++l]fB"
				r["B"] = "[--l][++l]"
				tree.rules = r
				tree.max_steps = 5
				tree.current_step = 5
				tree.branch_length = clamp(h / 12.0, 8.0, 25.0)
				tree.angle = 35.0
				tree.leaf_growth_threshold = 7.0
				tree.leaf_color = color
				tree.leaf_scale = clamp(w / 22.0, 0.8, 2.5)
		3:
			if is_far:
				var r: Dictionary[String, String] = {}
				r["X"] = "f[+F][-F]A"
				r["A"] = "f[+F][-F]B"
				r["B"] = "f[+l][-l]C"
				r["C"] = "f[+l][-l]"
				tree.rules = r
				tree.max_steps = 7
				tree.current_step = 7
				tree.branch_length = clamp(h / 14.0, 4.0, 14.0)
				tree.angle = 28.0
				tree.leaf_growth_threshold = 6.0
				tree.leaf_color = Color(color.r * 0.7, color.g * 0.8, color.b * 0.7)
				tree.leaf_scale = clamp(w / 18.0, 0.8, 2.5)
			else:
				var r: Dictionary[String, String] = {}
				r["X"] = "fA"
				r["A"] = "[--l++++l][++l][--l]fB"
				r["B"] = "[--l++++l][++l][--l]fC"
				r["C"] = "[--l++++l][++l][--l]"
				tree.rules = r
				tree.max_steps = 6
				tree.current_step = 6
				tree.branch_length = clamp(h / 18.0, 5.0, 14.0)
				tree.angle = 25.0
				tree.leaf_growth_threshold = 10.0
				tree.leaf_color = color
				tree.leaf_scale = clamp(w / 20.0, 1.0, 3.0)
		4:
			if is_far:
				var r: Dictionary[String, String] = {}
				r["X"] = "[+k][-k]f[+k]f[-k]f[A]"
				r["A"] = "[+k]f[-k]f[B]"
				r["B"] = "[+l]f[-l]"
				tree.rules = r
				tree.max_steps = 8
				tree.current_step = 8
				tree.branch_length = clamp(h / 11.0, 5.0, 18.0)
				tree.angle = 40.0
				tree.leaf_growth_threshold = 4.0
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
				tree.max_steps = 7
				tree.current_step = 7
				tree.branch_length = clamp(h / 13.0, 6.0, 20.0)
				tree.angle = 38.0
				tree.leaf_growth_threshold = 8.0
				tree.leaf_color = color
				tree.leaf_scale = clamp(w / 24.0, 0.6, 2.0)

	var branch_shade = Color(0.2 + color.r * 0.15, 0.12 + color.g * 0.1, 0.06 + color.b * 0.05)
	tree.branch_width = clamp(w * 0.08, 1.0, 4.0)
	tree.branch_color = branch_shade
	tree.wind_strength = randf_range(0.2, 0.6)
	tree.leaf_angle = randf_range(15.0, 40.0)

	node.add_child(tree)
	parent.add_child(node)

func _build_rect_prop(parent: Node2D, prop_name: String, x: float, y: float, color: Color, w: float, h: float) -> void:
	var node = Node2D.new()
	node.name = prop_name
	node.position = Vector2(x, y)

	if prop_name.begins_with("Bush"):
		var bush_draw = BushDraw.new()
		bush_draw.bush_color = color
		bush_draw.bush_width = w
		bush_draw.bush_height = h
		bush_draw.offset_y = -h
		node.add_child(bush_draw)
	elif prop_name.begins_with("Rock"):
		var rock_draw = RockDraw.new()
		rock_draw.rock_color = color
		rock_draw.rock_width = w
		rock_draw.rock_height = h
		rock_draw.offset_y = -h
		node.add_child(rock_draw)

	parent.add_child(node)

func _inject_environment_questions() -> void:
	var questions = environment.generate_questions()
	for q in questions:
		RiddleManager.add_environment_question(q.question, q.options[q.correct_index], q.options.filter(func(o): return o != q.options[q.correct_index]), q.consequence)

func _add_sample_riddles() -> void:
	# PARADOX riddles — directly from team Discord discussions
	RiddleManager.add_riddle(
		"The barber shaves every man who does not shave himself. In this village, who shaves the barber?",
		["The barber himself", "Another man", "No one", "The question has no answer"],
		3, "If the barber shaves himself, he shaves a man who shaves himself. If another shaves him, not every man who doesn't shave himself is shaved. Either way, the rule breaks.",
		RiddleManager.PuzzleType.PARADOX
	)
	RiddleManager.add_riddle(
		"Do you, Mighty King, believe the Sage to be an honest man?",
		["Yes", "No"],
		1, "If yes, you trust a demon's word. If no, you call yourself a liar — for I am a Sage too. Your answer crumbles either way.",
		RiddleManager.PuzzleType.PARADOX
	)
	RiddleManager.add_riddle(
		"O Mighty King, in which hand does my dear Golden Coin lie?",
		["Left", "Right", "Neither", "Both"],
		2, "There is no coin. I made you guess at nothing. Your certainty means nothing before the void.",
		RiddleManager.PuzzleType.PARADOX
	)
	RiddleManager.add_riddle(
		"A ruler swore before his people that every thief would be punished. One day, a starving widow stole a loaf of bread for her child. If he keeps his oath, an innocent child suffers. If he breaks it, his word loses meaning. Tell me... should a king honor his oath, or his conscience?",
		["His oath", "His conscience", "Both", "Neither"],
		1, "Either way, someone loses. That is the weight of the crown. There is no clean answer, King.",
		RiddleManager.PuzzleType.PARADOX
	)

	# COLLECTION riddles — concept discussed: "Betaal urges you to gather twigs/items"
	RiddleManager.add_riddle(
		"Betaal urges you to gather twigs from the forest floor. How many does he demand?",
		["Three", "Five", "Seven", "Nine"],
		1, "Five twigs. A handful of dry bones from the earth's skeleton.",
		RiddleManager.PuzzleType.COLLECTION
	)
	RiddleManager.add_riddle(
		"Collect three fallen leaves for Betaal. Which color does he favour?",
		["Green", "Red", "Brown", "Yellow"],
		2, "Brown. The colour of dead things. He collects rot and memory.",
		RiddleManager.PuzzleType.COLLECTION
	)

	# MICROPHONE riddles — concept discussed: "stay silent" / "scream"
	RiddleManager.add_riddle(
		"Stay silent for 5 seconds. Betaal creeps closer.",
		["Silence", "Noise"],
		0, "Stillness is the deepest respect for the dead.",
		RiddleManager.PuzzleType.MICROPHONE
	)
	RiddleManager.add_riddle(
		"Scream! Let the forest hear your voice.",
		["Silence", "Noise"],
		1, "Fear given voice is courage. The darkness listens.",
		RiddleManager.PuzzleType.MICROPHONE
	)
	RiddleManager.add_riddle(
		"Betaal creeps closer... Do not make a sound.",
		["Silence", "Noise"],
		0, "Your breath betrays you. The dead have no need for air.",
		RiddleManager.PuzzleType.MICROPHONE
	)

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.PLAYING:
			_spawn_player()
			puzzle_timer.start()
			hud.get_node("Panel/WarningLabel").visible = false
			reset_cutscene.visible = false
		GameManager.GameState.PUZZLE:
			puzzle_timer.stop()
		GameManager.GameState.RESET:
			_trigger_reset()

func _spawn_player() -> void:
	if player_instance:
		return
	player_instance = player_scene.instantiate()
	player_instance.position = player_start.position
	add_child(player_instance)

func _on_puzzle_timer_timeout() -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if is_waiting_for_response:
		return
	_trigger_betaal_dialogue()

func _trigger_betaal_dialogue() -> void:
	is_waiting_for_response = true
	var puzzle_type = GameManager.get_next_puzzle_type()
	if puzzle_type == RiddleManager.PuzzleType.OBSERVATION:
		var obs_q = observation.generate_observation_question(_game_time)
		if not obs_q.is_empty():
			current_riddle_data = obs_q
		else:
			current_riddle_data = RiddleManager.get_riddle_by_type(puzzle_type)
	else:
		current_riddle_data = RiddleManager.get_riddle_by_type(puzzle_type)
	if not current_riddle_data:
		is_waiting_for_response = false
		return

	GameManager.trigger_puzzle()
	var questions = [
		"Answer my riddle, Vikram!",
		"Solve my riddle if you dare!",
		"I have a riddle for you, mortal.",
		"Answer wisely, or face the darkness!"
	]
	dialogue_box.show_text(questions[randi() % questions.size()])
	if player_instance:
		var betaal = player_instance.get_node_or_null("Visual/BetaalPosition/Betaal")
		if betaal and betaal.has_method("start_speaking"):
			betaal.start_speaking()
		var cam = player_instance.get_node_or_null("Camera2D")
		if cam:
			var tween = create_tween()
			tween.tween_property(cam, "zoom", Vector2(1.3, 1.3), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _stop_betaal_speaking() -> void:
	if player_instance:
		var betaal = player_instance.get_node_or_null("Visual/BetaalPosition/Betaal")
		if betaal and betaal.has_method("stop_speaking"):
			betaal.stop_speaking()

func _on_dialogue_response(response: bool) -> void:
	dialogue_box.hide_box()
	_stop_betaal_speaking()
	_reset_camera_zoom()
	if response:
		puzzle_encounter.show_riddle(current_riddle_data)
	else:
		puzzle_encounter.show_consequence(current_riddle_data.consequence)
		_apply_penalty()

func _apply_penalty() -> void:
	if GameManager.consume_question_save():
		_show_bonus_popup("Save Used!", Color(0.3, 0.8, 1.0))
		return
	GameManager.run_timer -= 15.0
	if GameManager.run_timer < 0:
		GameManager.run_timer = 0

func _reset_camera_zoom() -> void:
	if player_instance:
		var cam = player_instance.get_node_or_null("Camera2D")
		if cam:
			var tween = create_tween()
			tween.tween_property(cam, "zoom", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

func _on_bonus_awarded(bonus_type: String) -> void:
	match bonus_type:
		"speed":
			if player_instance and player_instance.has_method("activate_speed_boost"):
				player_instance.activate_speed_boost(10.0)
			_show_bonus_popup("+20%% Speed!", Color(0.3, 1.0, 0.3))
		"save":
			_show_bonus_popup("+1 Question Save!", Color(0.3, 0.8, 1.0))

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
	if not correct:
		_reset_player_position()
	var puzzle_type = current_riddle_data.get("puzzle_type", RiddleManager.PuzzleType.OBSERVATION)
	GameManager.on_puzzle_completed(correct, puzzle_type)

func _reset_player_position() -> void:
	if player_instance:
		player_instance.position = player_start.position

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
	particles.position = Vector2(0, -100)
	particles.z_index = 1
	particles.amount = 40
	particles.lifetime = 8.0
	particles.explosiveness = 0.2
	particles.randomness = 0.6
	particles.one_shot = false
	particles.preprocess = 4.0
	particles.visibility_rect = Rect2(-50000, -500, 100000, 1500)
	particles.trail_enabled = true
	particles.trail_lifetime = 1.5
	particles.trail_sections = 6

	var material = ParticleProcessMaterial.new()
	material.particle_flag_align_y = true
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 150.0
	material.gravity = Vector3(0.0, 3.0, 0.0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.orbit_velocity_min = 2.0
	material.orbit_velocity_max = 8.0
	material.scale_min = 0.05
	material.scale_max = 0.2
	material.color = Color(0.15, 0.65, 0.1, 0.7)
	var color_ramp = Gradient.new()
	color_ramp.colors = PackedColorArray([Color(0.2, 0.8, 0.15, 0.8), Color(0.1, 0.5, 0.1, 0.5), Color(0.3, 0.7, 0.15, 0.2)])
	material.color_ramp = color_ramp
	material.hue_variation_min = -0.1
	material.hue_variation_max = 0.1
	particles.process_material = material
	particles.texture = leaf_texture
	add_child(particles)
	_leaf_particles = particles

func _add_leaf_litter() -> void:
	var leaf_texture = load("res://addons/PlantGenerator/Assets/leaf.png")
	if not leaf_texture:
		return
	var forest = get_node_or_null("ForestProps")
	if not forest:
		return
	for i in 80:
		var x = randi_range(-3800, 3800)
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
