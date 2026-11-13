extends Control

# Sesuaikan nama node ini dengan nama node tombol di scene Main Menu kamu
@onready var adventure_btn = $VBoxContainer/NewGameBtn
@onready var load_btn = $VBoxContainer/LoadGameBtn
@onready var exit_btn = $VBoxContainer/ExitBtn

func _ready() -> void:
	# Cek apakah ada file save. Kalau tidak ada, sembunyikan tombol Load
	load_btn.disabled = not FileAccess.file_exists("user://biblioteka_save.json")

func _on_adventure_pressed() -> void:
	# 1. Reset semua progress game (HP, kartu, area)
	GameManager.reset_game()
	
	# 2. Setup awal untuk game baru
	GameManager.current_area = "area_1_lobby"
	# Jika kamu pakai DeckManager (seperti di obrolan sebelumnya)
	if Engine.has_singleton("DeckManager") or DeckManager:
		DeckManager.load_default_deck()
		
	# 3. Pindah ke Level 1 dengan transisi smooth
	SceneTransition.change_scene("res://scenes/exploration/Level_Area1.tscn")

func _on_load_game_pressed() -> void:
	# Jika GameManager kamu sudah punya fungsi load_game(), panggil di sini
	# if GameManager.load_game():
	# 	var scene_path = "res://scenes/exploration/" + GameManager.current_area + ".tscn"
	# 	SceneTransition.change_scene(scene_path)
	
	# --- ATAU ---
	# Kalau kamu belum buat sistem save, kita bisa pakai simulasi sementara:
	print("[Main Menu] Fitur Load belum diimplementasikan sepenuhnya.")
	# Contoh implementasi nanti:
	# GameManager.load_game()
	# var scene_path = GameManager.get_current_scene_path() 
	# SceneTransition.change_scene(scene_path)

func _on_exit_pressed() -> void:
	get_tree().quit()
