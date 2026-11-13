
extends CharacterBody2D

@export var speed: float = 50.0
@export var chase_speed: float = 75.0
@export var detection_range: float = 180.0
@export var lose_target_range: float = 240.0
@export var stop_distance: float = 32.0
@export var patrol_distance: float = 120.0
@export var jump_velocity: float = -400.0
@export var player: Node2D
@export var enemy_data: EnemyData

var patrol_direction: float = 1.0
var patrol_origin_x: float = 0.0
var is_chasing: bool = false


func _ready() -> void:
	patrol_origin_x = global_position.x

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	# Terapkan gravitasi
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D

	if player != null:
		var distance: float = global_position.distance_to(
			player.global_position
		)

		if not is_chasing and distance <= detection_range:
			is_chasing = true

		elif is_chasing and distance >= lose_target_range:
			is_chasing = false

	if is_chasing and player != null:
		var difference_x: float = (
			player.global_position.x - global_position.x
		)

		if absf(difference_x) > stop_distance:
			velocity.x = signf(difference_x) * chase_speed
		else:
			velocity.x = 0.0

	# MODE PATROLI
	else:
		if global_position.x >= patrol_origin_x + patrol_distance:
			patrol_direction = -1.0

		elif global_position.x <= patrol_origin_x - patrol_distance:
			patrol_direction = 1.0

		velocity.x = patrol_direction * speed

	move_and_slide()
	# Lompat saat mengejar Player ke platform lebih tinggi
	if is_chasing and player != null and is_on_floor():
		var height_difference: float = (
			global_position.y - player.global_position.y
		)

		var horizontal_difference: float = absf(
			player.global_position.x - global_position.x
		)

		# Lompat jika Player lebih tinggi dan masih terjangkau
		if (
			height_difference > 25.0
			and height_difference <= 75.0
			and horizontal_difference <= detection_range
		) or is_on_wall():
			velocity.y = jump_velocity
	# Berbalik saat menabrak dinding ketika patroli
	if not is_chasing and is_on_wall():
		patrol_direction *= -1.0


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		GameManager.start_battle(enemy_data)
