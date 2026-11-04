extends CanvasLayer

signal chosen(choice: String)

var _buttons: Array[Button] = []
var _done: bool = false

func _ready() -> void:
	layer = 50
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "BUKU UPGRADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Kamu menang! Pilih satu hadiah:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var dmg: int = GameManager.player_base_damage
	var hp: int = GameManager.player_max_hp
	_add_choice(row, "DAMAGE", "+%d Damage\n(%d → %d)" % [
		GameManager.UPGRADE_DAMAGE, dmg, dmg + GameManager.UPGRADE_DAMAGE])
	_add_choice(row, "HP", "+%d HP Maks\n(%d → %d)" % [
		GameManager.UPGRADE_HP, hp, hp + GameManager.UPGRADE_HP])

	_buttons[0].grab_focus()

func _add_choice(parent: Node, id: String, text: String) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(190, 90)
	btn.pressed.connect(_on_choice.bind(id))
	parent.add_child(btn)
	_buttons.append(btn)

func _on_choice(id: String) -> void:
	if _done:
		return
	_done = true
	for b in _buttons:
		b.disabled = true
	chosen.emit(id)
	queue_free()
