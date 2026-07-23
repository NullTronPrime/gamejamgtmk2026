extends Node2D

enum BetaalState { IDLE, TAUNT, SPEAKING, FLYING_AWAY }

var current_state: int = BetaalState.IDLE

var _speak_tween: Tween
var _bubble: Sprite2D
var _rig: Dictionary = {}

@onready var player: CharacterBody2D = owner

func _ready() -> void:
	GameManager.state_changed.connect(_on_game_state_changed)

	scale = Vector2(0.78, 0.78)
	_rig = HumanoidRig.build(self, Color(0.22, 0.4, 0.95), Color(0.35, 0.5, 0.95))
	_pose_piggyback()

	_bubble = Sprite2D.new()
	_bubble.name = "SpeechBubble"
	_bubble.texture = preload("res://addons/at-icons/node3d/speech_bubble_question.svg")
	_bubble.scale = Vector2(0.6, 0.6)
	_bubble.position = Vector2(-22, -26)
	_bubble.modulate = Color(0.9, 0.9, 1.0, 0.9)
	_bubble.visible = false
	add_child(_bubble)

func _pose_piggyback() -> void:
	if _rig.is_empty():
		return
	_rig["l_shoulder"].rotation = deg_to_rad(100)
	_rig["r_shoulder"].rotation = deg_to_rad(100)
	_rig["l_elbow"].rotation = deg_to_rad(75)
	_rig["r_elbow"].rotation = deg_to_rad(75)

	_rig["l_hip"].rotation = deg_to_rad(75)
	_rig["r_hip"].rotation = deg_to_rad(75)
	_rig["l_knee"].rotation = deg_to_rad(95)
	_rig["r_knee"].rotation = deg_to_rad(95)

func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.RESET:
		_play_fly_away()

func _play_fly_away() -> void:
	_stop_speaking()
	current_state = BetaalState.FLYING_AWAY
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", Vector2(position.x, position.y - 200), 1.5)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 1.5)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 1.5)
	await tween.finished
	visible = false

func reappear() -> void:
	visible = true
	modulate = Color.WHITE
	scale = Vector2(0.78, 0.78)
	position = Vector2.ZERO
	current_state = BetaalState.IDLE
	_bubble.visible = false

func trigger_taunt() -> void:
	if current_state == BetaalState.IDLE:
		current_state = BetaalState.TAUNT
		var tween = create_tween()
		tween.tween_property(self, "position", Vector2(position.x, position.y - 10), 0.15)
		tween.tween_property(self, "position", Vector2.ZERO, 0.15)
		await tween.finished
		current_state = BetaalState.IDLE

func start_speaking() -> void:
	if current_state == BetaalState.FLYING_AWAY:
		return
	_stop_speaking()
	current_state = BetaalState.SPEAKING
	_bubble.visible = true
	var bubble_tween = create_tween().set_loops()
	bubble_tween.tween_property(_bubble, "scale", Vector2(0.65, 0.65), 0.4).set_ease(Tween.EASE_IN_OUT)
	bubble_tween.tween_property(_bubble, "scale", Vector2(0.55, 0.55), 0.4).set_ease(Tween.EASE_IN_OUT)
	_speak_tween = create_tween().set_loops()
	_speak_tween.set_parallel(true)
	_speak_tween.tween_property(self, "position:y", position.y - 4, 0.15).set_ease(Tween.EASE_IN_OUT)
	_speak_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15).set_ease(Tween.EASE_IN_OUT)
	_speak_tween.chain()
	_speak_tween.tween_property(self, "position:y", position.y, 0.15).set_ease(Tween.EASE_IN_OUT)
	_speak_tween.tween_property(self, "modulate", Color(0.8, 0.8, 0.9, 0.85), 0.15).set_ease(Tween.EASE_IN_OUT)

func stop_speaking() -> void:
	_stop_speaking()
	_bubble.visible = false
	if current_state == BetaalState.SPEAKING:
		current_state = BetaalState.IDLE

func _stop_speaking() -> void:
	if _speak_tween:
		_speak_tween.kill()
		_speak_tween = null
