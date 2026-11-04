extends CanvasLayer

signal dialog_selesai

@onready var background_node = $Background
@onready var portrait_container: Control = $PortraitContainer
@onready var name_label = $DialoguePanel/CharName
@onready var text_label = $DialoguePanel/DialogueText
@onready var next_button = $DialoguePanel/NextButton

var story_data: Array = []
var current_dialogue_index: int = 0

# Variabel animasi ketik
var is_typing: bool = false
var type_tween: Tween

func _ready() -> void:
	# Hubungkan tombol Next ke fungsi
	next_button.pressed.connect(_on_next_button_pressed)
	get_tree().paused = true
	# Sembunyikan panel di awal (opsional, tergantung pemanggilan)
	visible = true 

# Fungsi utama untuk memanggil dialog dari Level
# Format data: [{"name": "...", "text": "...", "bg": "res://...", "portrait": "res://...", "posisi_x": 100}]
func mulai_dialog(data_array: Array) -> void:
	story_data = data_array
	current_dialogue_index = 0
	update_dialogue()

func update_dialogue() -> void:
	if current_dialogue_index < story_data.size():
		var data = story_data[current_dialogue_index]

		# 1. Update Nama
		name_label.text = str(data.get("name", "???"))

		# 2. Update Teks & Animasi Ketik
		text_label.text = str(data.get("text", "..."))
		text_label.visible_ratio = 0.0
		start_typewriter()

		# 3. Update Background (Jika ada di data)
		var bg_path = data.get("bg", "")
		if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
			background_node.texture = load(bg_path)
			background_node.show()

		# 4. Update Multi-Karakter (Portrait)
		# Jika di data ada "clear_portraits", hapus semua karakter di layar
		if data.get("clear_portraits", false) == true:
			for child in portrait_container.get_children():
				child.queue_free()

		# Jika di data ada "portrait", tambahkan karakter ke layar
		var portrait_path = data.get("portrait", "")
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			_tambah_karakter(
				data.get("name", ""),
				portrait_path, 
				float(data.get("posisi_x", 0))
			)

		# 5. Sorot Karakter yang Sedang Bicara
		_atur_fokus_karakter(data.get("name", ""))
		
	else:
		# Jika dialog habis
		_selesai_dialog()

# ==========================================
# LOGIKA ANIMASI KETIK
# ==========================================
func start_typewriter() -> void:
	is_typing = true
	if type_tween:
		type_tween.kill()
	
	type_tween = create_tween()
	# Kecepatan ngetik: 0.03 detik per huruf
	var duration = text_label.text.length() * 0.03 
	type_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	type_tween.finished.connect(_on_typing_finished)

func _on_typing_finished() -> void:
	is_typing = false
	text_label.visible_ratio = 1.0

# ==========================================
# INPUT & TOMBOL NEXT
# ==========================================
func _input(event: InputEvent) -> void:
	# Bisa klik layar atau tekan Spasi/Enter untuk lanjut
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_lanjut_dialog()
	elif event.is_action_pressed("ui_accept"): # Spasi / Enter
		_lanjut_dialog()

func _on_next_button_pressed() -> void:
	_lanjut_dialog()

func _lanjut_dialog() -> void:
	if is_typing:
		# Jika masih ngetik, percepat/hentikan animasi ketik
		if type_tween:
			type_tween.kill()
		_on_typing_finished()
	else:
		# Jika sudah selesai ngetik, lanjut ke dialog berikutnya
		current_dialogue_index += 1
		update_dialogue()

# ==========================================
# SISTEM MULTI-KARAKTER (PORTRAIT)
# ==========================================
func _tambah_karakter(nama: String, path: String, pos_x: float) -> void:
	# Cegah duplikasi jika karakter sudah ada di layar
	for child in portrait_container.get_children():
		if child.has_meta("nama_karakter") and child.get_meta("nama_karakter") == nama:
			return 

	var tex_rect = TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size = Vector2(400, 600) # Sesuaikan ukuran dengan layar Godot-mu
	tex_rect.texture = load(path)
	tex_rect.set_meta("nama_karakter", nama)
	
	portrait_container.add_child(tex_rect)
	
	# Atur posisi X dan letakkan di bawah (menempel di lantai/layar)
	tex_rect.position = Vector2(pos_x, portrait_container.size.y - tex_rect.size.y)
	
	# Efek Fade In (Muncul perlahan)
	tex_rect.self_modulate.a = 0.0 
	var tween = create_tween()
	tween.tween_property(tex_rect, "self_modulate:a", 1.0, 0.3) 

func _atur_fokus_karakter(speaker_name: String) -> void:
	# Sorot yang sedang bicara, redupkan yang diam
	for child in portrait_container.get_children():
		if child.has_meta("nama_karakter"):
			if child.get_meta("nama_karakter") == speaker_name:
				child.modulate = Color(1.0, 1.0, 1.0, 1.0) # Terang
			else:
				child.modulate = Color(0.4, 0.4, 0.4, 1.0) # Redup

# ==========================================
# SELESAI DIALOG
# ==========================================
func _selesai_dialog() -> void:
	set_process_input(false) # Matikan input agar tidak dobel klik
	next_button.disabled = true
	
	get_tree().paused = false
	# Kirim sinyal ke level bahwa dialog sudah selesai
	emit_signal("dialog_selesai")
	
	# Hancurkan UI dialog ini dari layar
	queue_free()
