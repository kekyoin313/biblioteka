extends Control

signal card_clicked(card_data: Resource)

@export var card_data: Resource

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/Name
@onready var cost_label: Label = $Panel/Cost
@onready var desc_label: Label = $Panel/Description


func _ready() -> void:
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.gui_input.connect(_on_gui_input)

	if card_data != null:
		setup(card_data)


func setup(data: Resource) -> void:
	if data == null:
		push_warning("[Card] Data kartu kosong.")
		return

	card_data = data
	name_label.text = str(data.get_meta("card_name", "Unknown"))
	cost_label.text = str(data.get_meta("cost", 0))
	desc_label.text = str(data.get_meta("description", ""))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if card_data == null:
				push_warning("[Card] Tidak ada data kartu.")
				return

			print("[Card] Klik terdeteksi: ", card_data.get_meta("card_name", "Unknown"))
			card_clicked.emit(card_data)
