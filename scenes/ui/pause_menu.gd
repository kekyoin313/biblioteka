extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const FONT_PATH := ""  # isi path font serif-mu, misalnya "res://assets/fonts/serif.ttf"
const TEXT_COLOR := Color(1, 1, 1)
const ACCENT_COLOR := Color("#a78bfa")

var _root: Control
var _font: Font
var _center: CenterContainer
var _pause_box: VBoxContainer
var _audio_panel: PanelContainer
var _settings_visible := false


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

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_center)

	_build_pause_menu()
	_audio_panel = _build_audio_settings()
	_audio_panel.visible = false
	_center.add_child(_audio_panel)

	# Peringatan kecil di bawah layar.
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


func _build_pause_menu() -> void:
	_pause_box = VBoxContainer.new()
	_pause_box.add_theme_constant_override("separation", 18)
	_center.add_child(_pause_box)

	# Judul dengan garis memudar di kiri dan kanan.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 24)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_box.add_child(title_row)

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
	_pause_box.add_child(spacer)

	_pause_box.add_child(_make_item("Continue", _resume))
	_pause_box.add_child(_make_item("Audio Settings", _open_audio_settings))
	_pause_box.add_child(_make_item("Exit to Main Menu", _to_main_menu))
	_pause_box.add_child(_make_item("Exit from Desktop", _quit))


func _build_audio_settings() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.02, 0.075, 0.97)
	panel_style.border_color = ACCENT_COLOR
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)

	var title := Label.new()
	title.text = "Audio Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	if _font:
		title.add_theme_font_override("font", _font)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Adjust your game volume"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.72, 0.88))
	content.add_child(subtitle)

	_add_audio_slider(
		content,
		"Master Volume",
		AudioManager.get_master_volume(),
		Callable(AudioManager, "set_master_volume")
	)
	_add_audio_slider(
		content,
		"Music Volume",
		AudioManager.get_music_volume(),
		Callable(AudioManager, "set_music_volume")
	)
	_add_audio_slider(
		content,
		"Sound Effects",
		AudioManager.get_sfx_volume(),
		Callable(AudioManager, "set_sfx_volume")
	)

	var separator := HSeparator.new()
	content.add_child(separator)
	content.add_child(_make_item("Back", _close_audio_settings))

	return panel


func _add_audio_slider(
	parent: VBoxContainer,
	label_text: String,
	current_value: float,
	setter: Callable
) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	parent.add_child(group)

	var header := HBoxContainer.new()
	group.add_child(header)

	var title := Label.new()
	title.text = label_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)

	var value_label := Label.new()
	value_label.text = "%d%%" % roundi(current_value * 100.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 54
	value_label.add_theme_color_override("font_color", ACCENT_COLOR)
	value_label.add_theme_font_size_override("font_size", 17)
	header.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = current_value * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 24)
	slider.value_changed.connect(
		_on_audio_slider_changed.bind(value_label, setter)
	)
	group.add_child(slider)


func _on_audio_slider_changed(
	value: float,
	value_label: Label,
	setter: Callable
) -> void:
	value_label.text = "%d%%" % roundi(value)
	setter.call(value / 100.0)
	AudioManager.save_audio_settings()


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
		if _settings_visible:
			_close_audio_settings()
		else:
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
	_show_pause_menu()
	get_tree().paused = true
	_root.visible = true


func _show_pause_menu() -> void:
	_settings_visible = false
	_audio_panel.visible = false
	_pause_box.visible = true


func _open_audio_settings() -> void:
	_settings_visible = true
	_pause_box.visible = false
	_audio_panel.visible = true


func _close_audio_settings() -> void:
	AudioManager.save_audio_settings()
	_show_pause_menu()


func _resume() -> void:
	AudioManager.save_audio_settings()
	_settings_visible = false
	_root.visible = false
	get_tree().paused = false


func _to_main_menu() -> void:
	_resume()
	SceneTransition.change_scene(MAIN_MENU_SCENE)


func _quit() -> void:
	AudioManager.save_audio_settings()
	get_tree().quit()
