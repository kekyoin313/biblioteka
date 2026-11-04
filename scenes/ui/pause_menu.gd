extends CanvasLayer


const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

@onready var root: Control = $Root
@onready var stats_label: Label = $Root/Center/Panel/Margin/VBox/StatsLabel
@onready var resume_btn: Button = $Root/Center/Panel/Margin/VBox/ResumeBtn
@onready var menu_btn: Button = $Root/Center/Panel/Margin/VBox/MenuBtn
@onready var quit_btn: Button = $Root/Center/Panel/Margin/VBox/QuitBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	resume_btn.pressed.connect(resume)
	menu_btn.pressed.connect(_on_menu_pressed)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if root.visible:
		resume()
		get_viewport().set_input_as_handled()
	elif _can_pause():
		pause()
		get_viewport().set_input_as_handled()

func _can_pause() -> bool:
	var scene := get_tree().current_scene
	if scene == null or not scene.scene_file_path.contains("/exploration/"):
		return false
	return not GameManager.battle_in_progress

func pause() -> void:
	_refresh_stats()
	root.visible = true
	get_tree().paused = true
	resume_btn.grab_focus()

func resume() -> void:
	AudioManager.play_sfx(
    "res://assets/audio/sfx/open_menu.wav"
)
	root.visible = false
	get_tree().paused = false

func _refresh_stats() -> void:
	var dmg: Variant = GameManager.get("player_base_damage")
	stats_label.text = "HP  %d / %d\nDamage dasar  %s" % [
		GameManager.player_hp, GameManager.player_max_hp,
		str(dmg) if dmg != null else "-"]

func _on_menu_pressed() -> void:
	resume()
	await SceneTransition.change_scene(MAIN_MENU_SCENE)
