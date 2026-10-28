extends Node2D

const STAGE_LEFT: int = 0
const STAGE_RIGHT: int = 3200
const STAGE_TOP: int = 0
const STAGE_BOTTOM: int = 800

func _ready() -> void:
	# Keep the camera inside Stage 1 so empty space beyond the level edges is not visible.
	var camera := get_node_or_null("Player/Camera2D") as Camera2D
	if camera != null:
		camera.limit_left = STAGE_LEFT
		camera.limit_right = STAGE_RIGHT
		camera.limit_top = STAGE_TOP
		camera.limit_bottom = STAGE_BOTTOM
		camera.position_smoothing_enabled = false
