extends Node

enum GameState { TITLE, INTRO, PLAYING, PUZZLE, RESET, WIN }

var state: int = GameState.TITLE
var run_timer: float = 0.0
var max_run_time: float = 999999.0
var puzzle_count: int = 0
var puzzles_solved_this_run: int = 0
var puzzles_needed_to_win: int = 5
var current_run: int = 0

var last_puzzle_type: int = -1
var puzzle_type_weights: Dictionary = {
	RiddleManager.PuzzleType.OBSERVATION: 25,
	RiddleManager.PuzzleType.PARADOX: 25,
	RiddleManager.PuzzleType.COLLECTION: 12,
	RiddleManager.PuzzleType.MICROPHONE: 13,
	RiddleManager.PuzzleType.ENVIRONMENT: 25
}

var question_saves: int = 0
var mic_puzzles_disabled: bool = false
var max_distance: float = 0.0

signal state_changed(new_state: int)
signal timer_updated(time_left: float)
signal puzzle_solved()
signal run_ended()
signal game_won()
signal puzzle_type_changed(puzzle_type: int)
signal bonus_awarded(bonus_type: String)

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func start_run() -> void:
	run_timer = max_run_time
	puzzles_solved_this_run = 0
	max_distance = 0.0
	current_run += 1
	change_state(GameState.PLAYING)

func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		run_timer -= delta
		timer_updated.emit(run_timer)

func change_state(new_state: int) -> void:
	state = new_state
	state_changed.emit(new_state)

func trigger_puzzle() -> void:
	change_state(GameState.PUZZLE)

func get_next_puzzle_type() -> int:
	var weights = puzzle_type_weights.duplicate()
	if mic_puzzles_disabled:
		weights.erase(RiddleManager.PuzzleType.MICROPHONE)
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	if total_weight == 0:
		return RiddleManager.PuzzleType.OBSERVATION
	var rand = randi() % total_weight
	var cumulative = 0
	for puzzle_type in weights:
		cumulative += weights[puzzle_type]
		if rand < cumulative:
			return puzzle_type
	return RiddleManager.PuzzleType.OBSERVATION

func on_puzzle_completed(correct: bool, puzzle_type: int = -1) -> void:
	if correct:
		puzzles_solved_this_run += 1
		puzzle_count += 1
		puzzle_solved.emit()
		if puzzles_solved_this_run >= puzzles_needed_to_win:
			change_state(GameState.WIN)
			game_won.emit()
			return
		if randi() % 2 == 0:
			bonus_awarded.emit("speed")
		else:
			question_saves += 1
			bonus_awarded.emit("save")
	if puzzle_type >= 0:
		last_puzzle_type = puzzle_type
		puzzle_type_changed.emit(puzzle_type)
	change_state(GameState.PLAYING)

func consume_question_save() -> bool:
	if question_saves > 0:
		question_saves -= 1
		return true
	return false

func trigger_reset() -> void:
	change_state(GameState.RESET)
	run_ended.emit()

func on_reset_complete() -> void:
	start_run()

func get_time_remaining_string() -> String:
	if run_timer <= 0:
		return "--:--"
	var total_seconds = int(run_timer)
	var minutes = int(total_seconds / 60.0)
	var seconds = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func get_time_fraction() -> float:
	return clamp(run_timer / max_run_time, 0.0, 1.0)

func get_puzzle_progress_string() -> String:
	return "Puzzles: %d / %d" % [puzzles_solved_this_run, puzzles_needed_to_win]
