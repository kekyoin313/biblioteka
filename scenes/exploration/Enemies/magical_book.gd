
extends CharacterBody2D

@export var enemy_data: EnemyData
@export var speed: float = 50.0

# Pengaturan Steering Behavior Flee
@export var player: Node2D
@export var detection_radius: float = 160.0
@export var escape_radius: float = 240.0
@export var flee_speed: float = 110.0
@export var steering_force: float = 400.0

var direction: int = 1
var is_fleeing: bool = false
func _ready() -> void:
	
	# Cari player otomatis berdasarkan group
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D

func _physics_process(delta: float) -> void:
	# Gravitasi tetap berjalan
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# Periksa jarak terhadap player
	if is_instance_valid(player):
		var distance: float = global_position.distance_to(
			player.global_position
		)

		# Mulai kabur jika player mendekat
		if not is_fleeing and distance <= detection_radius:
			is_fleeing = true
			print("[MagicalBook] Mulai kabur!")

		# Kembali patroli setelah mencapai jarak aman
		elif is_fleeing and distance >= escape_radius:
			is_fleeing = false
			print("[MagicalBook] Kembali patroli.")

	# Steering Behavior: Flee
	if is_fleeing and is_instance_valid(player):
		# Arah menjauhi player pada sumbu horizontal
		var away_x: float = global_position.x - player.global_position.x
		var flee_direction: float = sign(away_x)

		# Jika posisi horizontal sama, pilih arah menjauhi secara alternatif
		if is_zero_approx(flee_direction):
			flee_direction = -float(direction)

		# Desired velocity
		var desired_velocity_x: float = flee_direction * flee_speed

		# Steering force = desired velocity - current velocity
		var steering: float = desired_velocity_x - velocity.x

		# Batasi gaya steering agar perubahan kecepatan bertahap
		steering = clampf(
			steering,
			-steering_force * delta,
			steering_force * delta
		)

		velocity.x += steering
		direction = int(flee_direction)

	else:
		# Pergerakan patroli normal
		velocity.x = direction * speed

	move_and_slide()

	# Balik arah saat menabrak tembok ketika patroli
	if not is_fleeing and is_on_wall():
		direction *= -1


func _on_area_2d_body_entered(body: Node2D) -> void:
	print(
		"[Enemy Magical Book] Body entered: ",
		body.name,
		" | is_in_group player: ",
		body.is_in_group("player")
	)

	if body.name == "Player" or body.is_in_group("player"):
		GameManager.start_battle(enemy_data)


func _go_to_battle() -> void:
	get_tree().change_scene_to_file(
		"res://scenes/battle/Battle.tscn"
	)
