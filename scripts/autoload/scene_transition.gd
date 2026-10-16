extends Node
## SceneTransition: pindah scene dengan fade

var _fade_layer: CanvasLayer
var _color_rect: ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	# Bikin overlay fade otomatis
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100  # selalu di atas
	add_child(_fade_layer)

	_color_rect = ColorRect.new()
	_color_rect.color = Color(0, 0, 0, 0)
	_color_rect.anchor_right = 1.0
	_color_rect.anchor_bottom = 1.0
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_color_rect)

func change_scene(scene_path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await fade_out()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_in()
	_is_transitioning = false

func fade_out(duration: float = 0.35) -> void:
	var tween = create_tween()
	tween.tween_property(_color_rect, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.35) -> void:
	var tween = create_tween()
	tween.tween_property(_color_rect, "color:a", 0.0, duration)
	await tween.finished
