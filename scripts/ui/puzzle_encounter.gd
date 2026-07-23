extends CanvasLayer

signal puzzle_result(correct: bool)

@onready var panel: Panel = $Panel
@onready var question_label: RichTextLabel = $Panel/QuestionLabel
@onready var option_container: VBoxContainer = $Panel/OptionContainer
@onready var mic_instruction: Label = $Panel/MicInstruction
@onready var mic_meter: TextureProgressBar = $Panel/MicMeter

var option_buttons: Array = []
var correct_index: int = -1
var current_riddle_data: Dictionary
var mic_check_timer: Timer
var mic_threshold: float = -30.0
var mic_duration: float = 5.0
var mic_elapsed: float = 0.0
var mic_stay_quiet: bool = true
var mic_success: bool = false

func _ready() -> void:
	for child in option_container.get_children():
		if child is Button:
			option_buttons.append(child)
			child.pressed.connect(_on_option_pressed.bind(option_buttons.size() - 1))
	mic_check_timer = Timer.new()
	mic_check_timer.wait_time = 0.1
	mic_check_timer.one_shot = false
	mic_check_timer.timeout.connect(_check_microphone)
	add_child(mic_check_timer)

func show_riddle(riddle_data: Dictionary) -> void:
	current_riddle_data = riddle_data
	question_label.text = riddle_data.question
	correct_index = riddle_data.correct_index
	var puzzle_type = riddle_data.get("puzzle_type", RiddleManager.PuzzleType.OBSERVATION)
	if puzzle_type == RiddleManager.PuzzleType.MICROPHONE:
		_show_microphone_puzzle(riddle_data)
	else:
		_show_multiple_choice(riddle_data)

func _show_multiple_choice(riddle_data: Dictionary) -> void:
	mic_instruction.visible = false
	mic_meter.visible = false
	option_container.visible = true
	var options = riddle_data.options
	for i in option_buttons.size():
		if i < options.size():
			option_buttons[i].text = options[i]
			option_buttons[i].visible = true
			option_buttons[i].disabled = false
		else:
			option_buttons[i].visible = false
	visible = true

func _show_microphone_puzzle(riddle_data: Dictionary) -> void:
	option_container.visible = false
	mic_instruction.visible = true
	mic_meter.visible = true
	mic_meter.value = 0
	mic_meter.tint_progress = Color(0.3, 1.0, 0.3)
	mic_elapsed = 0.0
	mic_success = false
	var question = riddle_data.question.to_lower()
	mic_stay_quiet = "silent" in question or "quiet" in question or "no sound" in question or "not a sound" in question or "not a whisper" in question or "do not make" in question or "betaal creeps" in question
	if mic_stay_quiet:
		mic_instruction.text = "Stay silent! (%.1fs)" % mic_duration
		mic_threshold = -30.0
	else:
		mic_instruction.text = "Make some noise! (%.1fs)" % mic_duration
		mic_threshold = -10.0
	MicManager.start_capture()
	mic_check_timer.start()
	visible = true

func _check_microphone() -> void:
	mic_elapsed += 0.1
	var mic_level = MicManager.get_mic_level_db()
	var volume_pct = MicManager.get_mic_volume_linear()
	mic_meter.value = volume_pct * 100
	var remaining = mic_duration - mic_elapsed
	mic_meter.tint_progress = Color(1.0 - volume_pct, volume_pct, 0.2)
	if mic_stay_quiet:
		if mic_level > mic_threshold:
			mic_instruction.text = "Too loud! (%.1fs)" % remaining
			mic_success = false
			mic_elapsed = maxf(0, mic_elapsed - 0.5)
		else:
			mic_instruction.text = "Silence... (%.1fs)" % remaining
			mic_success = true
	else:
		if mic_level > mic_threshold:
			mic_instruction.text = "Good noise! (%.1fs)" % remaining
			mic_success = true
		else:
			mic_instruction.text = "Too quiet! (%.1fs)" % remaining
			mic_success = false
			mic_elapsed = maxf(0, mic_elapsed - 0.3)
	if mic_elapsed >= mic_duration:
		mic_check_timer.stop()
		_on_microphone_finished()

func _on_microphone_finished() -> void:
	MicManager.stop_capture()
	mic_check_timer.stop()
	mic_instruction.visible = false
	mic_meter.visible = false
	var correct = mic_success
	for btn in option_buttons:
		btn.disabled = true
	puzzle_result.emit(correct)
	if correct:
		question_label.text = "Correct!"
	else:
		question_label.text = "Wrong! %s" % current_riddle_data.consequence
	await get_tree().create_timer(2.0).timeout
	hide_puzzle()

func show_consequence(text: String) -> void:
	question_label.text = text
	for btn in option_buttons:
		btn.visible = false
	option_container.visible = false
	mic_instruction.visible = false
	mic_meter.visible = false
	visible = true
	await get_tree().create_timer(2.0).timeout
	hide_puzzle()

func hide_puzzle() -> void:
	MicManager.stop_capture()
	mic_check_timer.stop()
	mic_instruction.visible = false
	mic_meter.visible = false
	option_container.visible = true
	visible = false

func _on_option_pressed(index: int) -> void:
	for btn in option_buttons:
		btn.disabled = true
	var correct = index == correct_index
	puzzle_result.emit(correct)
