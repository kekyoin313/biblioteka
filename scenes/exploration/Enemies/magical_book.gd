extends CharacterBody2D

@export var enemy_data: EnemyData
@export var speed: float = 50.0
var direction: int = 1

func _physics_process(delta: float) -> void:
	# Gravitasi
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# Gerak horizontal
	velocity.x = direction * speed

	# Balik arah kalau nabrak tembok
	if is_on_wall():
		direction *= -1

	move_and_slide()

func _on_area_2d_body_entered(body: Node2D) -> void:
	print("[Enemy Magical Book] Body entered: ", body.name, " | is_in_group player: ", body.is_in_group("player"))
	if body.name == "Player":
		# Simpan posisi player
		GameManager.start_battle(enemy_data)

func _go_to_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/battle/Battle.tscn")
