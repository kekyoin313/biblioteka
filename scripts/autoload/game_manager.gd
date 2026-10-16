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
func start_battle(enemy_data: Resource) -> void:
	current_enemy_data = enemy_data
	# Simpan posisi player & scene area saat ini
	var player = get_tree().get_first_node_in_group("player")
	if player:
		saved_player_position = player.global_position
	saved_area_scene = get_tree().current_scene.scene_file_path
	battle_started.emit(enemy_data)
	print("[GameManager] start_battle dipanggil | enemy_data = ", enemy_data)
	call_deferred("_go_to_battle")

func end_battle(result: String) -> void:
	battle_ended.emit(result)
	if result == "win":
		# kembalikan ke area sebelumnya
		SceneTransition.change_scene(saved_area_scene)
	else:
		# kalah → game over
		SceneTransition.change_scene("res://scenes/ui/GameOver.tscn")
	current_enemy_data = null

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
