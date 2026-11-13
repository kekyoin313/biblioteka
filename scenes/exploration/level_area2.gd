extends Node2D

const MAP_LEFT: int = 0
const MAP_RIGHT: int = 3200
const MAP_TOP: int = 160
const MAP_BOTTOM: int = 912


func _ready() -> void:
	var player := get_node_or_null("Player")
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = MAP_LEFT
	camera.limit_right = MAP_RIGHT
	camera.limit_top = MAP_TOP
	camera.limit_bottom = MAP_BOTTOM
