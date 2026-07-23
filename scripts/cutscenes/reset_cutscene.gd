extends CanvasLayer

signal finished()

@onready var fade_rect: ColorRect = $FadeRect
@onready var text_label: Label = $TextLabel
@onready var sub_text_label: Label = $SubTextLabel

func play() -> void:
	var distance_m = int(GameManager.max_distance / 10.0)
	var puzzles = GameManager.puzzles_solved_this_run
	sub_text_label.text = "Distance: %dm | Puzzles: %d\nBetaal returns to his tree..." % [distance_m, puzzles]
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 1.5)
	tween.tween_property(text_label, "modulate", Color(1, 1, 1, 1), 1.0)
	tween.tween_property(sub_text_label, "modulate", Color(1, 1, 1, 1), 1.5)
	await tween.finished
	await get_tree().create_timer(1.5).timeout
	finished.emit()
