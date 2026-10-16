extends Control

signal card_clicked(card_data: Resource)

@export var card_data: Resource

@onready var name_label: Label = $Panel/Name
@onready var cost_label: Label = $Panel/Cost
@onready var desc_label: Label = $Panel/Description

func _ready() -> void:
	if card_data:
		setup(card_data)
	gui_input.connect(_on_gui_input)

func setup(data: Resource) -> void:
	card_data = data
	if name_label: name_label.text = data.card_name
	if cost_label: cost_label.text = str(data.cost)
	if desc_label: desc_label.text = data.description

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(card_data)
			print("[Card] Klik: ", card_data.card_name)
