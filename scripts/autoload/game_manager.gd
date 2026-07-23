extends Node

enum GameState { TITLE, INTRO, PLAYING, PUZZLE, SECOND_PUZZLE, PLATFORMER, RESET, WIN }

var state: int = GameState.TITLE
var run_timer: float = 0.0
var max_run_time: float = 600.0
var puzzle_count: int = 0
var puzzles_solved_this_run: int = 0
var puzzles_needed_to_win: int = 5
var current_run: int = 0

var current_riddle_result: int = -1
var pending_level_difficulty: int = RiddleManager.LevelDifficulty.NORMAL
var got_second_riddle: bool = false
var second_riddle_correct: bool = false
var active_buffs: Dictionary = {}

var max_distance: float = 0.0
var question_saves: int = 0
var mic_puzzles_disabled: bool = false

signal state_changed(new_state: int)
signal timer_updated(time_left: float)
signal puzzle_solved()
signal run_ended()
signal game_won()
signal bonus_awarded(bonus_type: String)
signal puzzle_type_changed(puzzle_type: int)

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func start_run() -> void:
	run_timer = max_run_time
	puzzles_solved_this_run = 0
	max_distance = 0.0
	question_saves = 0
	active_buffs.clear()
	current_run += 1
	change_state(GameState.PLAYING)

func _process(delta: float) -> void:
	if state == GameState.PLAYING or state == GameState.PLATFORMER:
		run_timer -= delta
		timer_updated.emit(run_timer)

func change_state(new_state: int) -> void:
	state = new_state
	state_changed.emit(new_state)

func trigger_puzzle() -> void:
	change_state(GameState.PUZZLE)

func on_riddle_answered(category: int) -> void:
	current_riddle_result = category
	match category:
		RiddleManager.Category.RIGHT:
			pending_level_difficulty = RiddleManager.LevelDifficulty.EASY
			puzzles_solved_this_run += 1
			puzzle_count += 1
			puzzle_solved.emit()
			var buff = "jump" if randi() % 2 == 0 else "life"
			active_buffs[buff] = active_buffs.get(buff, 0) + 1
			bonus_awarded.emit(buff)
			if puzzles_solved_this_run >= puzzles_needed_to_win:
				change_state(GameState.WIN)
				game_won.emit()
				return
			change_state(GameState.PLATFORMER)
		RiddleManager.Category.WRONG:
			got_second_riddle = true
			change_state(GameState.SECOND_PUZZLE)
		RiddleManager.Category.FALSE:
			pending_level_difficulty = RiddleManager.LevelDifficulty.NORMAL
			puzzles_solved_this_run += 1
			puzzle_count += 1
			puzzle_solved.emit()
			if puzzles_solved_this_run >= puzzles_needed_to_win:
				change_state(GameState.WIN)
				game_won.emit()
				return
			change_state(GameState.PLATFORMER)

func on_second_riddle_completed(correct: bool) -> void:
	second_riddle_correct = correct
	if correct:
		pending_level_difficulty = RiddleManager.LevelDifficulty.NORMAL
	else:
		pending_level_difficulty = RiddleManager.LevelDifficulty.HARD
	puzzles_solved_this_run += 1
	puzzle_count += 1
	puzzle_solved.emit()
	if puzzles_solved_this_run >= puzzles_needed_to_win:
		change_state(GameState.WIN)
		game_won.emit()
		return
	change_state(GameState.PLATFORMER)

func on_platformer_completed() -> void:
	pending_level_difficulty = RiddleManager.LevelDifficulty.NORMAL
	got_second_riddle = false
	second_riddle_correct = false
	current_riddle_result = -1
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
