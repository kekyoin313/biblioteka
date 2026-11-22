extends Node2D

const STAGE_LEFT: int = 0
const STAGE_RIGHT: int = 3200
const STAGE_TOP: int = 0
const STAGE_BOTTOM: int = 800
const DIALOG_SCENE = preload("res://scenes/ui/dialogue.tscn") # Sesuaikan path-nya!

func _ready() -> void:
	# Keep the camera inside Stage 1 so empty space beyond the level edges is not visible.
	AudioManager.play_bgm("res://assets/audio/bgm/bgm_battle.mp3")
	
	var camera := get_node_or_null("Player/Camera2D") as Camera2D
	if camera != null:
		camera.limit_left = STAGE_LEFT
		camera.limit_right = STAGE_RIGHT
		camera.limit_top = STAGE_TOP
		camera.limit_bottom = STAGE_BOTTOM
		camera.position_smoothing_enabled = false
		
	if not GameManager.opened_chests.has("intro_dialog_seen"): # Kita pakai array chest sebagai penanda
		GameManager.opened_chests.append("intro_dialog_seen") # Tandai sudah lihat
		_munculkan_dialog_intro()
	else:
		# Kalau balik dari battle, langsung restore posisi player
		if GameManager.saved_player_position != Vector2.ZERO:
			var player = get_node_or_null("Player")
			if player:
				player.global_position = GameManager.saved_player_position
				GameManager.saved_player_position = Vector2.ZERO

func _munculkan_dialog_intro() -> void:
	print("[LEVEL] Mencoba memunculkan dialog...")
	var dialog = DIALOG_SCENE.instantiate()
	add_child(dialog) # Tambahkan dialog ke level
	print("[LEVEL] Dialog ditambahkan.")
	# Data Dialog: Sesuaikan nama file gambarnya dengan asetmu
	var intro_data = [
		{
			"name": "Narator",
			"text": "Di sebuah sudut kota yang terlupakan, berdiri sebuah perpustakaan tua...",
			"bg": "res://assets/Gemini_Generated_Image_soahw5soahw5soah.png.jpg",
			"portrait": ""
		},
		{
			"name": "Budi Pekerti",
			"text": "Nenek bilang, perpustakaan itu hanya terlihat oleh orang yang benar-benar mencari",
			"portrait": "res://assets/sprites/Player/Player_mata terbuka.png",
			"posisi_x": 300
		},
		{
			"name": "Budi Pekerti",
			"text": "Sunyi sekali... seperti semua buku di sini sedang menahan napas",
		},
		{
			"name": "Narator",
			"text": "Sesosok misterius mendekati Budi, sosok itu adalah sebuah buku yang hidup",
			"portrait": "res://assets/sprites/Enemy/g_book.png",
			"posisi_x": 800
		},
		{
			"name": "Budi Pekerti",
			"text": "Aku tidak mau melukaimu... tapi kau tidak memberiku pilihan",
			"portrait": "res://assets/sprites/Enemy/Attack.png",
			"posisi_x": 300
		}
	]
	
	dialog.mulai_dialog(intro_data)
