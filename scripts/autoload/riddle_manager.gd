extends Node

enum PuzzleType { OBSERVATION, PARADOX, COLLECTION, MICROPHONE, ENVIRONMENT }

var riddle_pool: Array = []
var riddle_history: Array = []

func add_riddle(question: String, options: Array, correct_index: int, consequence: String = "", puzzle_type: int = PuzzleType.OBSERVATION) -> void:
	riddle_pool.append({
		"question": question,
		"options": options,
		"correct_index": correct_index,
		"consequence": consequence,
		"puzzle_type": puzzle_type
	})

func add_environment_question(question: String, correct_answer: String, wrong_answers: Array, consequence: String = "") -> void:
	var options = wrong_answers.duplicate()
	var insert_at = randi() % (wrong_answers.size() + 1)
	options.insert(insert_at, correct_answer)
	riddle_pool.append({
		"question": question,
		"options": options,
		"correct_index": insert_at,
		"consequence": consequence,
		"puzzle_type": PuzzleType.ENVIRONMENT
	})

func get_random_riddle() -> Dictionary:
	if riddle_pool.is_empty():
		return {}
	var available: Array = []
	for i in riddle_pool.size():
		if not i in riddle_history:
			available.append(i)
	if available.is_empty():
		riddle_history.clear()
		available = range(riddle_pool.size())
	var chosen = available[randi() % available.size()]
	riddle_history.append(chosen)
	return riddle_pool[chosen]

func get_riddle_by_type(puzzle_type: int) -> Dictionary:
	var available: Array = []
	for i in riddle_pool.size():
		if riddle_pool[i].puzzle_type == puzzle_type and not i in riddle_history:
			available.append(i)
	if available.is_empty():
		for i in riddle_pool.size():
			if riddle_pool[i].puzzle_type == puzzle_type:
				available.append(i)
		riddle_history.clear()
	if available.is_empty():
		return {}
	var chosen = available[randi() % available.size()]
	riddle_history.append(chosen)
	return riddle_pool[chosen]

func clear_pool() -> void:
	riddle_pool.clear()
	riddle_history.clear()
