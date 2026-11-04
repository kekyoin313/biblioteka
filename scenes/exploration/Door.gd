extends Area2D
## Pintu antar-stage. Berdiri di depan pintu lalu tekan E (atau panah atas) untuk masuk.

@export_file("*.tscn") var target_scene: String = "res://scenes/exploration/Level_Area2.tscn"
@export var prompt_text: String = "[E] Masuk"
@export var interact_key: Key = KEY_E

@onready var _prompt: Label = $Prompt

var _player_inside: bool = false
var _key_was_down: bool = false
var _used: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.text = prompt_text if not target_scene.is_empty() else "(pintu belum terhubung)"
	_prompt.visible = false


func _physics_process(_delta: float) -> void:
	var key_down: bool = Input.is_physical_key_pressed(interact_key) or Input.is_physical_key_pressed(KEY_UP)
	var just_pressed: bool = key_down and not _key_was_down
	_key_was_down = key_down
	if not _player_inside or _used or not just_pressed:
		return
	if target_scene.is_empty():
		push_warning("Door '%s' belum punya target_scene." % name)
		return
	_used = true
	await SceneTransition.change_scene(target_scene)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_prompt.visible = false
