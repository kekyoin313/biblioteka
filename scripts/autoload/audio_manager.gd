extends Node

const BGM_VOLUME_DB := -8.0
const SFX_VOLUME_DB := -4.0
const MAX_SFX_PLAYERS := 8
const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_bgm_path: String = ""

var _master_volume := DEFAULT_MASTER_VOLUME
var _music_volume := DEFAULT_MUSIC_VOLUME
var _sfx_volume := DEFAULT_SFX_VOLUME


func _ready() -> void:
	_load_audio_settings()

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = _get_bus_or_master("Music")
	_bgm_player.volume_db = BGM_VOLUME_DB
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = _get_bus_or_master("SFX")
		player.volume_db = SFX_VOLUME_DB
		add_child(player)
		_sfx_players.append(player)


func _get_bus_or_master(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name

	push_warning("Audio bus tidak ditemukan: " + bus_name + ". Menggunakan Master.")
	return "Master"


func _load_audio_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)

	if error == OK:
		_master_volume = clampf(
			float(config.get_value("audio", "master", DEFAULT_MASTER_VOLUME)),
			0.0,
			1.0
		)
		_music_volume = clampf(
			float(config.get_value("audio", "music", DEFAULT_MUSIC_VOLUME)),
			0.0,
			1.0
		)
		_sfx_volume = clampf(
			float(config.get_value("audio", "sfx", DEFAULT_SFX_VOLUME)),
			0.0,
			1.0
		)

	_apply_audio_settings()


func _apply_audio_settings() -> void:
	_set_bus_volume("Master", _master_volume)
	_set_bus_volume("Music", _music_volume)
	_set_bus_volume("SFX", _sfx_volume)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)

	if bus_index < 0:
		push_warning("Audio bus tidak ditemukan: " + bus_name)
		return

	AudioServer.set_bus_volume_linear(bus_index, clampf(volume, 0.0, 1.0))


func get_master_volume() -> float:
	return _master_volume


func get_music_volume() -> float:
	return _music_volume


func get_sfx_volume() -> float:
	return _sfx_volume


func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Master", _master_volume)


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Music", _music_volume)


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("SFX", _sfx_volume)


func save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", _master_volume)
	config.set_value("audio", "music", _music_volume)
	config.set_value("audio", "sfx", _sfx_volume)

	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Gagal menyimpan pengaturan audio. Error: " + str(error))


func play_bgm(path: String) -> void:
	if path == _current_bgm_path and _bgm_player.playing:
		return

	var stream := load(path) as AudioStream

	if stream == null:
		push_warning("BGM tidak ditemukan: " + path)
		return

	_current_bgm_path = path
	_bgm_player.stream = stream
	_bgm_player.play()


func stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm_path = ""


func _on_bgm_finished() -> void:
	if _bgm_player.stream != null:
		_bgm_player.play()


func play_sfx(path: String) -> void:
	var stream := load(path) as AudioStream

	if stream == null:
		push_warning("SFX tidak ditemukan: " + path)
		return

	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return

	# Semua channel sedang digunakan.
	# Hindari memotong suara yang masih berjalan.
	push_warning("Semua channel SFX sedang digunakan.")
