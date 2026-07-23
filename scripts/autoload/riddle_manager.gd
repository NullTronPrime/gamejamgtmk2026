extends Node

enum Category { RIGHT, WRONG, FALSE }
enum LevelDifficulty { EASY, NORMAL, HARD }
enum PuzzleType { OBSERVATION, PARADOX, COLLECTION, MICROPHONE, ENVIRONMENT, CHESSBOARD }

var riddle_pool: Array[Dictionary] = []
var riddle_history: Array[int] = []

var second_riddle_pool: Array[Dictionary] = []
var second_riddle_history: Array[int] = []

func add_riddle(question: String, right: String, wrong: String, false1: String, false2: String, puzzle_type: int, cons_right: String, cons_wrong: String) -> void:
	riddle_pool.append({
		"question": question,
		"right_answer": right,
		"wrong_answer": wrong,
		"false_answers": [false1, false2],
		"puzzle_type": puzzle_type,
		"consequence_right": cons_right,
		"consequence_wrong": cons_wrong
	})

func add_second_riddle(question: String, puzzle_type: int, data: Dictionary) -> void:
	var entry = {
		"question": question,
		"puzzle_type": puzzle_type,
		"consequence_right": data.get("consequence_right", ""),
		"consequence_wrong": data.get("consequence_wrong", "")
	}
	if puzzle_type == PuzzleType.CHESSBOARD:
		entry["board_data"] = data.get("board_data", "")
		entry["correct_from"] = data.get("correct_from", -1)
		entry["correct_to"] = data.get("correct_to", -1)
	second_riddle_pool.append(entry)

func get_random_riddle() -> Dictionary:
	if riddle_pool.is_empty():
		return {}
	var available: Array[int] = []
	for i in riddle_pool.size():
		if not i in riddle_history:
			available.append(i)
	if available.is_empty():
		riddle_history.clear()
		for i in riddle_pool.size():
			available.append(i)
	var chosen = available[randi() % available.size()]
	riddle_history.append(chosen)
	return riddle_pool[chosen].duplicate()

func get_shuffled_options(riddle: Dictionary) -> Array[Dictionary]:
	var opts: Array[Dictionary] = []
	var right = {"text": riddle.right_answer, "category": Category.RIGHT}
	var wrong = {"text": riddle.wrong_answer, "category": Category.WRONG}
	opts.append(right)
	opts.append(wrong)
	for f in riddle.false_answers:
		opts.append({"text": f, "category": Category.FALSE})
	opts.shuffle()
	return opts

func get_second_riddle() -> Dictionary:
	if second_riddle_pool.is_empty():
		return {}
	var available: Array[int] = []
	for i in second_riddle_pool.size():
		if not i in second_riddle_history:
			available.append(i)
	if available.is_empty():
		second_riddle_history.clear()
		for i in second_riddle_pool.size():
			available.append(i)
	var chosen = available[randi() % available.size()]
	second_riddle_history.append(chosen)
	return second_riddle_pool[chosen].duplicate()

func clear_pool() -> void:
	riddle_pool.clear()
	riddle_history.clear()
	second_riddle_pool.clear()
	second_riddle_history.clear()
