extends Node

var _capture: AudioEffectCapture
var _bus_idx: int = -1
var _effect_idx: int = -1
var _capturing: bool = false
var _last_level_db: float = -80.0
var _noise_gate_db: float = -50.0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func start_capture() -> void:
	if _capturing:
		return
	if AudioServer.input_device.is_empty():
		var devices = AudioServer.get_input_device_list()
		if devices.size() > 0:
			AudioServer.input_device = devices[0]
		else:
			AudioServer.input_device = "Default"
	_bus_idx = AudioServer.get_bus_index("Master")
	if _bus_idx < 0:
		return
	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(_bus_idx, _capture, 0)
	_effect_idx = 0
	_capturing = true

func stop_capture() -> void:
	if not _capturing:
		return
	if _bus_idx >= 0 and _capture:
		AudioServer.remove_bus_effect(_bus_idx, 0)
	_capture = null
	_effect_idx = -1
	_capturing = false
	_last_level_db = -80.0

func get_mic_level_db() -> float:
	if not _capturing or not _capture:
		return -80.0
	var available = _capture.get_frames_available()
	if available <= 0:
		return _last_level_db
	var frames = mini(available, 2048)
	var buf = _capture.get_buffer(frames)
	var sum_sq: float = 0.0
	var count = buf.size()
	for s in buf:
		sum_sq += s.x * s.x + s.y * s.y
	var rms = sqrt(sum_sq / (count * 2.0))
	if rms < 0.00001:
		_last_level_db = -80.0
	else:
		_last_level_db = linear_to_db(rms)
	if _last_level_db < -80.0:
		_last_level_db = -80.0
	return _last_level_db

func get_mic_volume_linear() -> float:
	var db = get_mic_level_db()
	if db < _noise_gate_db:
		return 0.0
	var normalized = (db - _noise_gate_db) / (0.0 - _noise_gate_db)
	return clampf(normalized, 0.0, 1.0)

func is_quiet(threshold_db: float = -30.0) -> bool:
	return get_mic_level_db() < threshold_db

func is_loud(threshold_db: float = -20.0) -> bool:
	return get_mic_level_db() > threshold_db

func is_capturing() -> bool:
	return _capturing
