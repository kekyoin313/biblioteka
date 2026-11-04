
extends CharacterBody2D

@export var enemy_data: EnemyData
@export var player: Node2D

# Mode patroli
@export var patrol_speed: float = 45.0
@export var patrol_distance: float = 110.0

# Mode kabur
@export var detection_radius: float = 160.0
@export var escape_radius: float = 240.0
@export var flee_speed: float = 110.0
@export var steering_force: float = 400.0

var direction: int = 1
var patrol_origin_x: float = 0.0
var is_fleeing: bool = false
var encounter_started: bool = false
var persistent_enemy_id: String = ""


func _ready() -> void:
	persistent_enemy_id = _make_persistent_id()

	if GameManager.is_enemy_defeated(persistent_enemy_id):
		collision_layer = 0
		collision_mask = 0

		var area := get_node_or_null("Area2D") as Area2D
		if area != null:
			area.monitoring = false
			area.monitorable = false

		set_physics_process(false)
		call_deferred("queue_free")
		return

	patrol_origin_x = global_position.x

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D


func _make_persistent_id() -> String:
	var scene_path := ""
	var scene := get_tree().current_scene

	if scene != null:
		scene_path = scene.scene_file_path

	return "%s::%s" % [scene_path, str(get_path())]


func _physics_process(delta: float) -> void:
	# Gravitasi
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	# Deteksi pemain
	if is_instance_valid(player):
		var distance := global_position.distance_to(
			player.global_position
		)

		if not is_fleeing and distance <= detection_radius:
			is_fleeing = true
			print("[MagicalBook] Kabur dari pemain!")

		elif is_fleeing and distance >= escape_radius:
			is_fleeing = false
			print("[MagicalBook] Kembali berpatroli.")

	# MODE KABUR
	if is_fleeing and is_instance_valid(player):
		var away_x := global_position.x - player.global_position.x
		var flee_direction := signf(away_x)

		if is_zero_approx(flee_direction):
			flee_direction = -float(direction)

		var desired_velocity := flee_direction * flee_speed
		var steering := desired_velocity - velocity.x

		steering = clampf(
			steering,
			-steering_force * delta,
			steering_force * delta
		)

		velocity.x += steering
		direction = int(flee_direction)

	# MODE PATROLI
	else:
		if global_position.x >= patrol_origin_x + patrol_distance:
			direction = -1
		elif global_position.x <= patrol_origin_x - patrol_distance:
			direction = 1

		velocity.x = direction * patrol_speed

	move_and_slide()

	# Berbalik saat menabrak dinding ketika patroli
	if not is_fleeing and is_on_wall():
		direction *= -1


func _on_area_2d_body_entered(body: Node2D) -> void:
	if encounter_started:
		return

	if GameManager.is_enemy_defeated(persistent_enemy_id):
		return

	if body.is_in_group("player") or body.name == "Player":
		encounter_started = true

		var area := get_node_or_null("Area2D") as Area2D
		if area != null:
			area.set_deferred("monitoring", false)

		GameManager.start_battle(
			enemy_data,
			persistent_enemy_id
		)
