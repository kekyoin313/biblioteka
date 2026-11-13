extends Node
## AudioManager: play BGM & SFX global

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _current_bgm_path: String = ""

const BGM_VOLUME_DB := -8.0
const SFX_VOLUME_DB := -4.0

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = BGM_VOLUME_DB
	add_child(_bgm_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	_sfx_player.volume_db = SFX_VOLUME_DB
	add_child(_sfx_player)

func play_bgm(path: String) -> void:
	if path == _current_bgm_path and _bgm_player.playing:
		return
	var stream = load(path)
	if stream == null:
		push_warning("BGM tidak ditemukan: " + path)
		return
	_current_bgm_path = path
	_bgm_player.stream = stream
	_bgm_player.play()

func stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm_path = ""

func play_sfx(path: String) -> void:
	var stream = load(path)
	if stream == null:
		push_warning("SFX tidak ditemukan: " + path)
		return
	_sfx_player.stream = stream
	_sfx_player.play()
