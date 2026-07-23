extends CanvasLayer

signal puzzle_result(correct: bool)

@onready var panel: Panel = $Panel
@onready var question_label: RichTextLabel = $Panel/QuestionLabel
@onready var option_container: VBoxContainer = $Panel/OptionContainer
@onready var mic_instruction: Label = $Panel/MicInstruction
@onready var mic_meter: TextureProgressBar = $Panel/MicMeter
@onready var board_container: Panel = $Panel/BoardContainer
@onready var board_question: RichTextLabel = $Panel/BoardContainer/BoardQuestion

var option_buttons: Array = []
var current_shuffled_options: Array[Dictionary] = []
var current_riddle_data: Dictionary
var is_second_riddle: bool = false
var _chessboard_widget: Control

func _ready() -> void:
	for child in option_container.get_children():
		if child is Button:
			option_buttons.append(child)
			child.pressed.connect(_on_option_pressed.bind(option_buttons.size() - 1))

func show_riddle(riddle_data: Dictionary, second: bool = false) -> void:
	current_riddle_data = riddle_data
	is_second_riddle = second
	question_label.text = riddle_data.question
	var puzzle_type = riddle_data.get("puzzle_type", -1)
	if is_second_riddle and puzzle_type == RiddleManager.PuzzleType.CHESSBOARD:
		_show_chessboard_puzzle(riddle_data)
	else:
		current_shuffled_options = RiddleManager.get_shuffled_options(riddle_data)
		_show_multiple_choice()

func _show_multiple_choice() -> void:
	option_container.visible = true
	for i in option_buttons.size():
		if i < current_shuffled_options.size():
			option_buttons[i].text = current_shuffled_options[i].text
			option_buttons[i].visible = true
			option_buttons[i].disabled = false
		else:
			option_buttons[i].visible = false
	visible = true

func _on_option_pressed(index: int) -> void:
	for btn in option_buttons:
		btn.disabled = true
	var chosen = current_shuffled_options[index]
	var category = chosen.category
	if is_second_riddle:
		var correct = category == RiddleManager.Category.RIGHT
		GameManager.on_second_riddle_completed(correct)
		hide_puzzle()
		return
	match category:
		RiddleManager.Category.RIGHT:
			_reset_camera_zoom()
			GameManager.on_riddle_answered(RiddleManager.Category.RIGHT)
			hide_puzzle()
		RiddleManager.Category.WRONG:
			_reset_camera_zoom()
			var second = RiddleManager.get_second_riddle()
			if second.is_empty():
				GameManager.on_riddle_answered(RiddleManager.Category.FALSE)
				hide_puzzle()
			else:
				show_riddle(second, true)
		RiddleManager.Category.FALSE:
			_reset_camera_zoom()
			GameManager.on_riddle_answered(RiddleManager.Category.FALSE)
			hide_puzzle()

func _reset_camera_zoom() -> void:
	var forest = get_node_or_null("/root/Game/ForestLevel")
	if forest:
		forest._reset_camera_zoom()

func _show_chessboard_puzzle(riddle_data: Dictionary) -> void:
	option_container.visible = false
	question_label.visible = false
	board_container.visible = true
	board_question.text = riddle_data.question

	if _chessboard_widget:
		_chessboard_widget.queue_free()
	_chessboard_widget = preload("res://scenes/chessboard/chessboard_widget.tscn").instantiate()
	_chessboard_widget.position = Vector2(10, 50)
	_chessboard_widget.size = Vector2(400, 400)
	board_container.add_child(_chessboard_widget)
	_chessboard_widget.puzzle_completed.connect(_on_chessboard_result)
	_chessboard_widget.setup_puzzle(
		riddle_data.get("board_data", ""),
		riddle_data.get("correct_from", -1),
		riddle_data.get("correct_to", -1)
	)

	if get_tree().root.has_node("Transition"):
		await Transition.cover("fade", 0.3)

	visible = true
	await get_tree().process_frame

	if get_tree().root.has_node("Transition"):
		await Transition.reveal("fade", 0.3)

func _on_chessboard_result(correct: bool) -> void:
	await get_tree().create_timer(0.5).timeout

	if get_tree().root.has_node("Transition"):
		await Transition.cover("fade", 0.3)

	board_container.visible = false
	if _chessboard_widget:
		_chessboard_widget.queue_free()
		_chessboard_widget = null

	question_label.visible = true

	if get_tree().root.has_node("Transition"):
		await Transition.reveal("fade", 0.3)

	if correct:
		GameManager.on_second_riddle_completed(true)
	else:
		GameManager.on_second_riddle_completed(false)
	hide_puzzle()

func hide_puzzle() -> void:
	board_container.visible = false
	question_label.visible = true
	option_container.visible = true
	visible = false
