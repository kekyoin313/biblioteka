
extends Node

const BGM_VOLUME_DB := -8.0
const SFX_VOLUME_DB := -4.0
const MAX_SFX_PLAYERS := 8

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_bgm_path: String = ""

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = BGM_VOLUME_DB
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = SFX_VOLUME_DB
		add_child(player)
		_sfx_players.append(player)


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
