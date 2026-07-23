extends Node

var title_screen: CanvasLayer
var intro_cutscene: CanvasLayer
var forest_level: Node2D
var options_menu: CanvasLayer

func _ready() -> void:
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

func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.WIN:
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
