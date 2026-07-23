extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var footstep_players: Array = []

var bgm_volume: float = -10.0
var sfx_volume: float = 0.0
var _footstep_idx: int = 0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.volume_db = bgm_volume
	add_child(music_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SfxPlayer"
	sfx_player.volume_db = sfx_volume
	add_child(sfx_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "AmbiencePlayer"
	ambience_player.volume_db = sfx_volume - 6
	add_child(ambience_player)
	for i in 4:
		var fp = AudioStreamPlayer2D.new()
		fp.name = "FootstepPlayer_%d" % i
		fp.volume_db = sfx_volume - 3
		fp.max_polyphony = 2
		add_child(fp)
		footstep_players.append(fp)

func play_bgm(stream: AudioStream) -> void:
	music_player.stream = stream
	music_player.play()

func stop_bgm() -> void:
	music_player.stop()

func play_ambience(stream: AudioStream) -> void:
	ambience_player.stream = stream
	ambience_player.play()

func stop_ambience() -> void:
	ambience_player.stop()

func play_sfx(stream: AudioStream) -> void:
	sfx_player.stream = stream
	sfx_player.play()

func play_footstep(stream: AudioStream) -> void:
	var player = footstep_players[_footstep_idx % footstep_players.size()]
	_footstep_idx += 1
	player.stream = stream
	player.play()

func set_bgm_volume(db: float) -> void:
	bgm_volume = db
	music_player.volume_db = bgm_volume

func set_sfx_volume(db: float) -> void:
	sfx_volume = db
	sfx_player.volume_db = sfx_volume
	for fp in footstep_players:
		fp.volume_db = sfx_volume - 3
