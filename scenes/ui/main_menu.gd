extends Control

const HOVER_COLOR := Color(0.85, 0.75, 1.0)
const FADE_TIME := 0.18

@onready var adventure_btn: Button = $NewGameBtn
@onready var load_btn: Button = $LoadGameBtn
@onready var credits_btn: Button = $CreditsGameBtn
@onready var exit_btn: Button = $ExitBtn

var _hover_fx: Dictionary = {}


func _ready() -> void:
	load_btn.disabled = not FileAccess.file_exists("user://biblioteka_save.json")
	AudioManager.play_bgm("res://assets/audio/bgm/background_audio.mp3")

	for btn in [adventure_btn, load_btn, credits_btn, exit_btn]:
		_setup_hover(btn)


func _setup_hover(btn: Button) -> void:
	var glow := ColorRect.new()
	glow.color = Color(HOVER_COLOR, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(glow)

	var line := ColorRect.new()
	line.color = HOVER_COLOR
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2(0.0, btn.size.y - 12.0)
	line.size = Vector2(0.0, 3.0)
	line.modulate.a = 0.0
	btn.add_child(line)

	_hover_fx[btn] = {"line": line, "glow": glow, "tween": null}

	btn.mouse_entered.connect(_hover_in.bind(btn))
	btn.mouse_exited.connect(_hover_out.bind(btn))
	btn.focus_entered.connect(_hover_in.bind(btn))
	btn.focus_exited.connect(_hover_out.bind(btn))


func _hover_in(btn: Button) -> void:
	var fx: Dictionary = _hover_fx[btn]
	if fx["tween"] != null:
		(fx["tween"] as Tween).kill()

	var strength: float = 0.3 if btn.disabled else 1.0  # disabled: efek 30%
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fx["line"], "size:x", btn.size.x, FADE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx["line"], "modulate:a", strength, FADE_TIME)
	tween.tween_property(fx["glow"], "color:a", 0.12 * strength, FADE_TIME)
	fx["tween"] = tween


func _hover_out(btn: Button) -> void:
	var fx: Dictionary = _hover_fx[btn]
	if fx["tween"] != null:
		(fx["tween"] as Tween).kill()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(fx["line"], "size:x", 0.0, FADE_TIME)
	tween.tween_property(fx["line"], "modulate:a", 0.0, FADE_TIME)
	tween.tween_property(fx["glow"], "color:a", 0.0, FADE_TIME)
	fx["tween"] = tween


func _on_adventure_pressed() -> void:
	GameManager.reset_game()
	GameManager.current_area = "area_1_lobby"
	SceneTransition.change_scene("res://scenes/exploration/Level_Area1.tscn")


func _on_load_game_pressed() -> void:
	print("[Main Menu] Fitur Load belum diimplementasikan sepenuhnya.")


func _on_credits_pressed() -> void:
	print("[Main Menu] Credits belum dibuat.")


func _on_exit_pressed() -> void:
	get_tree().quit()
