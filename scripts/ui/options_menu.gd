extends CanvasLayer

signal closed()

@onready var bgm_slider: HSlider = $Panel/VBoxContainer/BGMContainer/BGMControlRow/BGMSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXContainer/SFXControlRow/SFXSlider
@onready var bgm_value_label: Label = $Panel/VBoxContainer/BGMContainer/BGMControlRow/BGMValue
@onready var sfx_value_label: Label = $Panel/VBoxContainer/SFXContainer/SFXControlRow/SFXValue
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
	_style_dropdowns()
	_load_settings()
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fps_option.item_selected.connect(_on_fps_changed)
	vsync_check.toggled.connect(_on_vsync_toggled)
	res_option.item_selected.connect(_on_resolution_changed)
	back_button.pressed.connect(_on_back)
	mic_check.toggled.connect(_on_mic_toggled)
	_setup_button_animations()

func _setup_button_animations() -> void:
	for btn in [back_button]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_unhover.bind(btn))
		btn.button_down.connect(_on_button_press.bind(btn))

func _on_button_hover(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _on_button_unhover(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _on_button_press(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)

func _style_dropdowns() -> void:
	var res_items = ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
	var fps_items = ["Unlimited", "60 FPS", "120 FPS", "144 FPS"]

	var opts = [res_option, fps_option]
	var items_list = [res_items, fps_items]
	for i in opts.size():
		var opt = opts[i]
		var items = items_list[i]
		opt.clear()
		for item in items:
			opt.add_item(item)
		var popup = opt.get_popup()
		popup.add_theme_font_size_override("font_size", 16)
		popup.reset_size()

func _style_sliders() -> void:
	for slider in [bgm_slider, sfx_slider]:
		var grabber = StyleBoxFlat.new()
		grabber.bg_color = Color(0.9, 0.9, 1.0, 1)
		grabber.corner_radius_top_left = 14
		grabber.corner_radius_top_right = 14
		grabber.corner_radius_bottom_left = 14
		grabber.corner_radius_bottom_right = 14
		grabber.content_margin_left = 6
		grabber.content_margin_right = 6
		grabber.content_margin_top = 6
		grabber.content_margin_bottom = 6
		slider.add_theme_stylebox_override("grabber", grabber)
		slider.add_theme_stylebox_override("grabber_highlight", grabber)

		var track = StyleBoxFlat.new()
		track.bg_color = Color(0.25, 0.25, 0.3, 1)
		track.corner_radius_top_left = 6
		track.corner_radius_top_right = 6
		track.corner_radius_bottom_left = 6
		track.corner_radius_bottom_right = 6
		track.content_margin_left = 0
		track.content_margin_right = 0
		track.content_margin_top = 12
		track.content_margin_bottom = 12
		slider.add_theme_stylebox_override("slider", track)

		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.4, 0.7, 0.4, 1) if slider == bgm_slider else Color(0.7, 0.4, 0.4, 1)
		fill.corner_radius_top_left = 6
		fill.corner_radius_top_right = 6
		fill.corner_radius_bottom_left = 6
		fill.corner_radius_bottom_right = 6
		fill.content_margin_left = 0
		fill.content_margin_right = 0
		fill.content_margin_top = 14
		fill.content_margin_bottom = 14
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_constant_override("grabber_size", 40)
		slider.add_theme_constant_override("center_grabber", 0)

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
