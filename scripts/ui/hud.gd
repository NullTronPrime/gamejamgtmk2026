extends CanvasLayer

@onready var timer_label: Label = $Panel/TimerLabel
@onready var puzzle_label: Label = $Panel/PuzzleLabel
@onready var puzzle_type_label: Label = $Panel/PuzzleTypeLabel
@onready var timer_bar: TextureProgressBar = $Panel/TimerBar
@onready var warning_label: Label = $Panel/WarningLabel
@onready var player_marker: ColorRect = $MinimapPanel/PlayerMarker
@onready var minimap_line: ColorRect = $MinimapPanel/MinimapLine
@onready var spawn_marker: ColorRect = $MinimapPanel/SpawnMarker
@onready var benefits_label: Label = $BenefitsPanel/BenefitsLabel

var warning_shown: bool = false

func _ready() -> void:
	GameManager.timer_updated.connect(_on_timer_updated)
	GameManager.puzzle_solved.connect(_on_puzzle_solved)
	GameManager.puzzle_type_changed.connect(_on_puzzle_type_changed)
	GameManager.bonus_awarded.connect(_on_bonus_awarded)
	process_mode = PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var forest = get_node_or_null("/root/Game/ForestLevel")
	if not forest or not forest.player_instance:
		return
	var player = forest.player_instance
	var map_width = minimap_line.size.x
	var spawn_x = 0.0
	var player_x = player.position.x
	var view_range = max(8000.0, abs(player_x) * 2.0)
	var t = (player_x + view_range / 2.0) / view_range
	var marker_x = minimap_line.position.x + t * map_width
	marker_x = clamp(marker_x, minimap_line.position.x, minimap_line.position.x + map_width - player_marker.size.x)
	player_marker.position.x = marker_x
	spawn_marker.position.x = minimap_line.position.x + (view_range / 2.0) / view_range * map_width

func _on_timer_updated(time_left: float) -> void:
	timer_label.text = GameManager.get_time_remaining_string()
	timer_bar.value = GameManager.get_time_fraction() * 100.0

	if time_left <= 60.0 and not warning_shown:
		warning_shown = true
		warning_label.visible = true
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(warning_label, "modulate", Color(1, 0.2, 0.2, 1), 0.5)
		tween.tween_property(warning_label, "modulate", Color(1, 0, 0, 0.3), 0.5)

	if time_left <= 0.0:
		warning_label.visible = false

	if time_left <= 30.0:
		timer_bar.tint_progress = Color(1, 0, 0, 1)
	elif time_left <= 60.0:
		timer_bar.tint_progress = Color(1, 0.6, 0, 1)

func _on_puzzle_solved() -> void:
	puzzle_label.text = GameManager.get_puzzle_progress_string()
	_update_benefits()

func _on_bonus_awarded(bonus_type: String) -> void:
	_update_benefits()

func _update_benefits() -> void:
	var saves = GameManager.question_saves
	var speed_str = "No"
	var forest = get_node_or_null("/root/Game/ForestLevel")
	if forest and forest.player_instance:
		if forest.player_instance.speed_multiplier > 1.0:
			speed_str = "Yes"
	benefits_label.text = "Benefits:\nSaves: %d\nSpeed: %s" % [saves, speed_str]

func _on_puzzle_type_changed(puzzle_type: int) -> void:
	var type_names = {
		RiddleManager.PuzzleType.OBSERVATION: "Observation",
		RiddleManager.PuzzleType.PARADOX: "Paradox",
		RiddleManager.PuzzleType.COLLECTION: "Collection",
		RiddleManager.PuzzleType.MICROPHONE: "Microphone",
		RiddleManager.PuzzleType.ENVIRONMENT: "Environment"
	}
	var type_name = type_names.get(puzzle_type, "Unknown")
	puzzle_type_label.text = "Type: %s" % type_name
	puzzle_type_label.modulate = Color(1, 1, 0.5, 1)
	var tween = create_tween()
	tween.tween_property(puzzle_type_label, "modulate", Color(1, 1, 1, 1), 1.0)

func reset() -> void:
	warning_shown = false
	warning_label.visible = false
	timer_bar.tint_progress = Color(0.2, 0.8, 0.2, 1)
	puzzle_label.text = "Puzzles: 0 / %d" % GameManager.puzzles_needed_to_win
	puzzle_type_label.text = "Type: -"
	benefits_label.text = "Benefits:\nSaves: 0\nSpeed: -"
