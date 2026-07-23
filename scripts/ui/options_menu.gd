extends CanvasLayer

signal closed()

@onready var bgm_slider: HSlider = $Panel/VBoxContainer/BGMContainer/BGMSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXContainer/SFXSlider
@onready var bgm_value_label: Label = $Panel/VBoxContainer/BGMContainer/BGMValue
@onready var sfx_value_label: Label = $Panel/VBoxContainer/SFXContainer/SFXValue
@onready var fps_option: OptionButton = $Panel/VBoxContainer/FPSSection/FPSSetting
@onready var vsync_check: CheckBox = $Panel/VBoxContainer/VSyncSection/VSyncCheck
@onready var res_option: OptionButton = $Panel/VBoxContainer/ResSection/ResSetting
@onready var back_button: Button = $Panel/VBoxContainer/BackButton
@onready var mic_check: CheckBox = $Panel/VBoxContainer/MicSection/MicCheck

const RESOLUTIONS: Array = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

func _ready() -> void:
	_style_sliders()
	_load_settings()
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fps_option.item_selected.connect(_on_fps_changed)
	vsync_check.toggled.connect(_on_vsync_toggled)
	res_option.item_selected.connect(_on_resolution_changed)
	back_button.pressed.connect(_on_back)
	mic_check.toggled.connect(_on_mic_toggled)

func _style_sliders() -> void:
	for slider in [bgm_slider, sfx_slider]:
		var grabber = StyleBoxFlat.new()
		grabber.bg_color = Color(0.9, 0.9, 1.0, 1)
		grabber.corner_radius_top_left = 4
		grabber.corner_radius_top_right = 4
		grabber.corner_radius_bottom_left = 4
		grabber.corner_radius_bottom_right = 4
		grabber.content_margin_left = 8
		grabber.content_margin_right = 8
		grabber.content_margin_top = 8
		grabber.content_margin_bottom = 8
		slider.add_theme_stylebox_override("grabber", grabber)
		slider.add_theme_stylebox_override("grabber_highlight", grabber)

		var track = StyleBoxFlat.new()
		track.bg_color = Color(0.15, 0.15, 0.2, 1)
		track.corner_radius_top_left = 3
		track.corner_radius_top_right = 3
		track.corner_radius_bottom_left = 3
		track.corner_radius_bottom_right = 3
		track.content_margin_left = 2
		track.content_margin_right = 2
		track.content_margin_top = 4
		track.content_margin_bottom = 4
		slider.add_theme_stylebox_override("slider", track)

		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.3, 0.5, 0.3, 1) if slider == bgm_slider else Color(0.5, 0.3, 0.3, 1)
		fill.corner_radius_top_left = 3
		fill.corner_radius_top_right = 3
		fill.corner_radius_bottom_left = 3
		fill.corner_radius_bottom_right = 3
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_constant_override("grabber_size", 16)

func _load_settings() -> void:
	bgm_slider.value = AudioManager.bgm_volume
	sfx_slider.value = AudioManager.sfx_volume
	_update_labels()
	match Engine.max_fps:
		0: fps_option.select(0)
		60: fps_option.select(1)
		120: fps_option.select(2)
		144: fps_option.select(3)
		_: fps_option.select(1)
	vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	_find_current_resolution()
	mic_check.button_pressed = not GameManager.mic_puzzles_disabled

func _find_current_resolution() -> void:
	var current = DisplayServer.window_get_size()
	var closest = 0
	var min_dist = 999999
	for i in RESOLUTIONS.size():
		var r = RESOLUTIONS[i]
		var dist = abs(r.x - current.x) + abs(r.y - current.y)
		if dist < min_dist:
			min_dist = dist
			closest = i
	res_option.select(closest)

func _update_labels() -> void:
	bgm_value_label.text = "%d%%" % int((bgm_slider.value + 40.0) / 40.0 * 100.0)
	sfx_value_label.text = "%d%%" % int((sfx_slider.value + 40.0) / 40.0 * 100.0)

func _on_bgm_changed(value: float) -> void:
	AudioManager.set_bgm_volume(value)
	bgm_value_label.text = "%d%%" % int((value + 40.0) / 40.0 * 100.0)

func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	sfx_value_label.text = "%d%%" % int((value + 40.0) / 40.0 * 100.0)

func _on_fps_changed(index: int) -> void:
	match index:
		0: Engine.max_fps = 0
		1: Engine.max_fps = 60
		2: Engine.max_fps = 120
		3: Engine.max_fps = 144

func _on_vsync_toggled(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
	fps_option.disabled = enabled

func _on_resolution_changed(index: int) -> void:
	if index >= 0 and index < RESOLUTIONS.size():
		var res = RESOLUTIONS[index]
		DisplayServer.window_set_size(res)

func _on_mic_toggled(enabled: bool) -> void:
	GameManager.mic_puzzles_disabled = not enabled

func _on_back() -> void:
	visible = false
	closed.emit()
