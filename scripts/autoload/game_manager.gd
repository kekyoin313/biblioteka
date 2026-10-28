extends Node
## GameManager: menyimpan state global game (HP, progress, area)

signal hp_changed(new_hp: int, max_hp: int)
signal battle_started(enemy_data: Resource)
signal battle_ended(result: String)

# === Player State ===
var player_max_hp: int = 100
var player_hp: int = 100

# === Progress ===
var current_area: String = "area_1"
var defeated_bosses: Array[String] = []
var opened_chests: Array[String] = []
var unlocked_doors: Array[String] = []
var defeated_enemies: Array[String] = []
var current_enemy_id: String = ""
var battle_in_progress: bool = false

# === Posisi player sebelum battle (untuk restore) ===
var saved_player_position: Vector2 = Vector2.ZERO
var saved_area_scene: String = ""

# === Battle state (sementara) ===
var current_enemy_data: Resource = null

func reset_game() -> void:
	player_hp = player_max_hp
	current_area = "area_1_lobby"
	defeated_bosses.clear()
	opened_chests.clear()
	unlocked_doors.clear()

func set_hp(value: int) -> void:
	player_hp = clamp(value, 0, player_max_hp)
	hp_changed.emit(player_hp, player_max_hp)
	if player_hp <= 0:
		on_player_dead()

func heal(amount: int) -> void:
	set_hp(player_hp + amount)

func damage(amount: int) -> void:
	set_hp(player_hp - amount)

func on_player_dead() -> void:
	print("[GameManager] Player mati. Trigger game over.")
	# nanti: pindah ke Game Over scene

# === Battle Flow ===
func start_battle(
	enemy_data: Resource,
	enemy_id: String = ""
) -> void:
	if battle_in_progress:
		return

	battle_in_progress = true
	current_enemy_data = enemy_data
	current_enemy_id = enemy_id

	var player := get_tree().get_first_node_in_group("player") as Node2D

	if player != null:
		saved_player_position = player.global_position

	var scene := get_tree().current_scene

	if scene != null:
		saved_area_scene = scene.scene_file_path

	battle_started.emit(enemy_data)
	call_deferred("_go_to_battle")
	
func end_battle(result: String) -> void:
	battle_ended.emit(result)

	if result == "win":
		if (
			not current_enemy_id.is_empty()
			and current_enemy_id not in defeated_enemies
		):
			defeated_enemies.append(current_enemy_id)

		var return_scene := saved_area_scene
		var return_position := saved_player_position

		current_enemy_data = null
		current_enemy_id = ""
		battle_in_progress = false

		if not return_scene.is_empty():
			await SceneTransition.change_scene(return_scene)

			var player := get_tree().get_first_node_in_group("player") as Node2D

			if player != null:
				player.global_position = return_position

				if player is CharacterBody2D:
					player.velocity = Vector2.ZERO

	else:
		current_enemy_data = null
		current_enemy_id = ""
		battle_in_progress = false

		if ResourceLoader.exists("res://scenes/ui/GameOver.tscn"):
			await SceneTransition.change_scene(
                "res://scenes/ui/GameOver.tscn"
			)
		elif not saved_area_scene.is_empty():
			player_hp = player_max_hp
			hp_changed.emit(player_hp, player_max_hp)

			await SceneTransition.change_scene(saved_area_scene)

			var player := get_tree().get_first_node_in_group("player") as Node2D

			if player != null:
				player.global_position = saved_player_position

				if player is CharacterBody2D:
					player.velocity = Vector2.ZERO

func mark_chest_opened(chest_id: String) -> void:
	if chest_id not in opened_chests:
		opened_chests.append(chest_id)

func is_chest_opened(chest_id: String) -> bool:
	return chest_id in opened_chests

func mark_boss_defeated(boss_id: String) -> void:
	if boss_id not in defeated_bosses:
		defeated_bosses.append(boss_id)

func is_boss_defeated(boss_id: String) -> bool:
	return boss_id in defeated_bosses

func _go_to_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/battle/Battle.tscn")
	
func is_enemy_defeated(enemy_id: String) -> bool:
	return not enemy_id.is_empty() and enemy_id in defeated_enemies
