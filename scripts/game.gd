extends Node

const GridTrans := preload("res://scripts/ui/grid_transition.gd")

var title_screen: CanvasLayer
var intro_cutscene: CanvasLayer
var forest_level: Node2D
var options_menu: CanvasLayer
var room_level: Node2D
var dungeon_level: Node2D
var cave_level: Node2D
var library_room: Node2D
var hunting_grounds: Node2D

func _ready() -> void:
	var cs := SystemFont.new()
	cs.font_names = ["Comic Sans MS", "Comic Sans"]
	ThemeDB.fallback_font = cs
	_show_title()

func _show_title() -> void:
	title_screen = preload("res://scenes/title_screen.tscn").instantiate()
	add_child(title_screen)
	title_screen.start_game.connect(_on_start_game)
	title_screen.open_options.connect(_on_open_options)

func _on_open_options() -> void:
	if not options_menu:
		options_menu = preload("res://scenes/ui/options_menu.tscn").instantiate()
		options_menu.visible = false
		add_child(options_menu)
		options_menu.closed.connect(_on_options_closed)
	title_screen.visible = false
	options_menu.visible = true

func _on_options_closed() -> void:
	title_screen.visible = true

func _on_start_game() -> void:
	title_screen.queue_free()
	_show_intro()

func _show_intro() -> void:
	intro_cutscene = preload("res://scenes/intro_cutscene.tscn").instantiate()
	add_child(intro_cutscene)
	intro_cutscene.finished.connect(_on_intro_finished)

func _on_intro_finished() -> void:
	if intro_cutscene:
		intro_cutscene.visible = false
		intro_cutscene.queue_free()
		intro_cutscene = null
	_start_gameplay()

func _start_gameplay() -> void:
	forest_level = preload("res://scenes/world/forest_level.tscn").instantiate()
	add_child(forest_level)
	GameManager.state_changed.connect(_on_game_state_changed)
	var pause_menu = preload("res://scenes/ui/pause_menu.tscn").instantiate()
	add_child(pause_menu)
	_setup_inventory()

func _setup_inventory() -> void:
	var inv_layer := CanvasLayer.new()
	inv_layer.name = "InventoryLayer"
	inv_layer.layer = 10
	var inv := preload("res://scripts/room/dungeon_inventory.gd").new()
	inv.name = "InventoryUI"
	inv.anchor_left = 0.0
	inv.anchor_top = 0.0
	inv.anchor_right = 1.0
	inv.anchor_bottom = 1.0
	inv_layer.add_child(inv)
	add_child(inv_layer)

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.WIN:
			_show_ending()

func trigger_ending() -> void:
	_show_ending()

func _show_ending() -> void:
	if forest_level:
		forest_level.queue_free()
		forest_level = null
	var ending = CanvasLayer.new()
	add_child(ending)
	var bg = ColorRect.new()
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 1)
	ending.add_child(bg)
	var label = Label.new()
	var distance_m = int(GameManager.max_distance / 10.0)
	var puzzles = GameManager.puzzles_solved_this_run
	label.text = "You escaped the forest.\nBetaal is free.\n\nDistance: %dm\nPuzzles: %d" % [distance_m, puzzles]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.1
	label.anchor_top = 0.3
	label.anchor_right = 0.9
	label.anchor_bottom = 0.7
	label.add_theme_font_size_override("font_size", 28)
	ending.add_child(label)


func enter_room() -> void:
	if room_level:
		return
	if not GridTrans.is_available() or GridTrans.is_busy():
		return
	await GridTrans.cover(0.8)
	if forest_level:
		forest_level.visible = false
		forest_level.process_mode = PROCESS_MODE_DISABLED
		forest_level.set_backgrounds_visible(false)
	room_level = preload("res://scenes/world/room_level.tscn").instantiate()
	add_child(room_level)


func exit_room() -> void:
	if not room_level:
		return
	room_level.queue_free()
	room_level = null
	if forest_level:
		forest_level.visible = true
		forest_level.process_mode = PROCESS_MODE_INHERIT
		forest_level.set_backgrounds_visible(true)
	if GridTrans.is_available() and not GridTrans.is_busy():
		GridTrans.reveal(0.8)

func enter_dungeon() -> bool:
	if dungeon_level:
		return true
	if not GridTrans.is_available() or GridTrans.is_busy():
		return false
	if forest_level:
		forest_level.visible = false
		forest_level.process_mode = PROCESS_MODE_DISABLED
		forest_level.set_backgrounds_visible(false)
	dungeon_level = preload("res://scenes/world/dungeon_level.tscn").instantiate()
	add_child(dungeon_level)
	return true

func exit_dungeon() -> void:
	if not dungeon_level:
		return
	dungeon_level.queue_free()
	dungeon_level = null
	if forest_level:
		forest_level.visible = true
		forest_level.process_mode = PROCESS_MODE_INHERIT
		forest_level.set_backgrounds_visible(true)
		if forest_level.has_method("_grave_completed"):
			forest_level._grave_completed(1)
	if GridTrans.is_available() and not GridTrans.is_busy():
		GridTrans.reveal(0.8)

func enter_cave() -> void:
	if cave_level:
		return
	if not GridTrans.is_available() or GridTrans.is_busy():
		return
	await GridTrans.cover(0.8)
	if forest_level:
		forest_level.visible = false
		forest_level.process_mode = PROCESS_MODE_DISABLED
		forest_level.set_backgrounds_visible(false)
	cave_level = preload("res://scenes/world/cave_level.tscn").instantiate()
	add_child(cave_level)

func exit_cave() -> void:
	if not cave_level:
		return
	cave_level.queue_free()
	cave_level = null
	if forest_level:
		forest_level.visible = true
		forest_level.process_mode = PROCESS_MODE_INHERIT
		forest_level.set_backgrounds_visible(true)
	if GridTrans.is_available() and not GridTrans.is_busy():
		GridTrans.reveal(0.8)

func enter_library_room() -> bool:
	if library_room:
		return true
	if not GridTrans.is_available() or GridTrans.is_busy():
		return false
	if forest_level:
		forest_level.visible = false
		forest_level.process_mode = PROCESS_MODE_DISABLED
		forest_level.set_backgrounds_visible(false)
		var hud = forest_level.get_node_or_null("HUD")
		if hud and hud.has_method("set_room_mode"):
			hud.set_room_mode(true)
	var lib = load("res://scenes/world/library_room.tscn")
	if not lib:
		push_error("library_room.tscn failed to load")
		return false
	library_room = lib.instantiate()
	add_child(library_room)
	return true

func exit_library_room() -> void:
	if not library_room:
		return
	library_room.queue_free()
	library_room = null
	if forest_level:
		forest_level.visible = true
		forest_level.process_mode = PROCESS_MODE_INHERIT
		forest_level.set_backgrounds_visible(true)
		var hud = forest_level.get_node_or_null("HUD")
		if hud and hud.has_method("set_room_mode"):
			hud.set_room_mode(false)
		if forest_level.has_method("_grave_completed"):
			forest_level._grave_completed(0)
	if GridTrans.is_available() and not GridTrans.is_busy():
		GridTrans.reveal(0.8)

func enter_hunting_grounds() -> bool:
	if hunting_grounds:
		return true
	if not GridTrans.is_available() or GridTrans.is_busy():
		return false
	var hg = null
	if forest_level:
		forest_level.visible = false
		forest_level.process_mode = PROCESS_MODE_DISABLED
		forest_level.set_backgrounds_visible(false)
		hg = load("res://scenes/world/hunting_grounds.tscn")
	if not hg:
		push_error("hunting_grounds.tscn failed to load")
		return false
	hunting_grounds = hg.instantiate()
	add_child(hunting_grounds)
	return true

func exit_hunting_grounds() -> void:
	if not hunting_grounds:
		return
	hunting_grounds.queue_free()
	hunting_grounds = null
	if forest_level:
		forest_level.visible = true
		forest_level.process_mode = PROCESS_MODE_INHERIT
		forest_level.set_backgrounds_visible(true)
	if GridTrans.is_available() and not GridTrans.is_busy():
		GridTrans.reveal(0.8)

func return_to_title() -> void:
	if library_room: library_room.queue_free(); library_room = null
	if hunting_grounds: hunting_grounds.queue_free(); hunting_grounds = null
	if dungeon_level: dungeon_level.queue_free(); dungeon_level = null
	if room_level: room_level.queue_free(); room_level = null
	if cave_level: cave_level.queue_free(); cave_level = null
	if forest_level: forest_level.queue_free(); forest_level = null
	var inv_layer := get_node_or_null("InventoryLayer")
	if inv_layer: inv_layer.queue_free()
	var pause_menu := get_node_or_null("PauseMenu")
	if pause_menu: pause_menu.queue_free()
	if GameManager.state_changed.is_connected(_on_game_state_changed):
		GameManager.state_changed.disconnect(_on_game_state_changed)
	_show_title()
