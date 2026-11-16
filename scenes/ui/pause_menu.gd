extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const FONT_PATH := ""  # isi path font serif-mu, misalnya "res://assets/fonts/serif.ttf"
const TEXT_COLOR := Color(1, 1, 1)
const ACCENT_COLOR := Color("#a78bfa")

var _root: Control
var _font: Font


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FONT_PATH != "" and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	_build_ui()
	_root.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	# Judul dengan garis memudar di kiri dan kanan
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 24)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(title_row)

	title_row.add_child(_make_line(false))
	var title := Label.new()
	title.text = "Game Paused"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	if _font:
		title.add_theme_font_override("font", _font)
	title_row.add_child(title)
	title_row.add_child(_make_line(true))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	box.add_child(_make_item("Continue", _resume))
	box.add_child(_make_item("Exit to Main Menu", _to_main_menu))
	box.add_child(_make_item("Exit from Desktop", _quit))

	# Peringatan kecil di bawah layar
	var warning := Label.new()
	warning.text = "All unsaved data will be gone!"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.anchor_left = 0.0
	warning.anchor_right = 1.0
	warning.anchor_top = 1.0
	warning.anchor_bottom = 1.0
	warning.offset_top = -56.0
	warning.offset_bottom = -24.0
	warning.add_theme_font_size_override("font_size", 14)
	warning.add_theme_color_override("font_color", ACCENT_COLOR)
	if _font:
		warning.add_theme_font_override("font", _font)
	_root.add_child(warning)


func _make_line(flip: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9)])
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	tex.width = 256

	var line := TextureRect.new()
	line.texture = tex
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.flip_h = flip
	line.custom_minimum_size = Vector2(220, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _make_item(label: String, callback: Callable) -> LinkButton:
	var btn := LinkButton.new()
	btn.text = label
	btn.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", ACCENT_COLOR)
	btn.add_theme_color_override("font_focus_color", ACCENT_COLOR)
	btn.add_theme_color_override("font_pressed_color", ACCENT_COLOR)
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.pressed.connect(callback)
	return btn


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _root.visible:
		_resume()
		get_viewport().set_input_as_handled()
	elif _can_pause():
		_pause()
		get_viewport().set_input_as_handled()


func _can_pause() -> bool:
	if GameManager.battle_in_progress:
		return false
	return get_tree().get_first_node_in_group("player") != null


func _pause() -> void:
	get_tree().paused = true
	_root.visible = true


func _resume() -> void:
	_root.visible = false
	get_tree().paused = false


func _to_main_menu() -> void:
	_resume()
	SceneTransition.change_scene(MAIN_MENU_SCENE)


func _quit() -> void:
	get_tree().quit()
