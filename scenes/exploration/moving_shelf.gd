extends AnimatableBody2D

@export var travel: Vector2 = Vector2(0, -100)
@export var duration: float = 3.0 
@export var phase: float = 0.0  

var _origin: Vector2
var _time: float = 0.0


func _ready() -> void:
	_origin = position
	_time = phase


func _physics_process(delta: float) -> void:
	_time += delta
	var t: float = (sin(_time * TAU / maxf(duration, 0.1)) + 1.0) * 0.5
	position = _origin + travel * t
