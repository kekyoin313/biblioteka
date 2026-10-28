extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -400.0

func _ready() -> void:
	add_to_group("player")
func _physics_process(delta: float) -> void:
	# Gravitasi
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# Lompat
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Gerak horizontal
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
