extends Node2D

const CARD_SCENE = preload("res://scenes/battle/Card.tscn")
const SHIELD_BAR_MAX: float = 30.0
const PLAYER_HURT: Texture2D = preload("res://assets/sprites/Player/Player_mata tertutup.png")

@onready var enemy_intent_label: Label = $EnemyArea/EnemyIntentLabel
@onready var enemy_name_label: Label = $EnemyArea/EnemyName
@onready var enemy_hp_bar: ProgressBar = $EnemyArea/EnemyHPBar
@onready var player_hp_bar: ProgressBar = $PlayerArea/PlayerHPBar
@onready var player_hp_number: Label = get_node_or_null("PlayerArea/PlayerHpNumber") as Label
@onready var enemy_hp_number: Label = get_node_or_null("EnemyArea/EnemyHpNumber") as Label
@onready var turn_label: Label = $UILayer/TurnLabel
@onready var energy_label: Label = $UILayer/EnergyLabel
@onready var hand_container: HBoxContainer = $UILayer/HandContainer
@onready var result_label: Label = $UILayer/ResultLabel
@onready var player_sprite: TextureRect = $PlayerArea/PlayerSprite
@onready var ui_layer: CanvasLayer = $UILayer 
@onready var enemy_sprite: TextureRect = $EnemyArea/EnemySprite

var last_player_hp: int = -1
var last_enemy_hp: int = -1
var last_player_shield: int = -1
var last_enemy_shield: int = -1
var player_shield_bar: ProgressBar
var enemy_shield_bar: ProgressBar
var player_shield_label: Label
var enemy_shield_label: Label
const EYES_OPEN: Texture2D = preload(
    "res://assets/sprites/Player/Player_mata terbuka.png"
)

const EYES_CLOSED: Texture2D = preload(
    "res://assets/sprites/Player/Player_mata tertutup.png"
)
const ATTACK_CARD_TEXTURE: Texture2D = preload(
	"res://assets/sprites/Cards/Attack.png"
)

const DEFENSE_CARD_TEXTURE: Texture2D = preload(
	"res://assets/sprites/Cards/Defense.png"
)

const EVADE_CARD_TEXTURE: Texture2D = preload(
	"res://assets/sprites/Cards/Evade.png"
)

func _ready() -> void:
	_create_shield_ui()

	# Connect before setup so the initial hand and turn events are not missed.
	BattleManager.player_hp_updated.connect(_on_player_hp_updated)
	BattleManager.enemy_hp_updated.connect(_on_enemy_hp_updated)
	BattleManager.shield_updated.connect(_on_shield_updated)
	BattleManager.turn_changed.connect(_on_turn_changed)
	BattleManager.battle_finished.connect(_on_battle_finished)
	BattleManager.enemy_intent_updated.connect(_on_enemy_intent_updated)
	BattleManager.player_evaded.connect(_on_player_evaded)
	result_label.visible = false
	energy_label.text = "PILIH SATU AKSI"
	_create_action_buttons()
	player_sprite.set_anchors_and_offsets_preset(
	Control.PRESET_TOP_LEFT
)
	player_sprite.position = Vector2(-87, -120)
	player_sprite.size = Vector2(299, 506.739)
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_sprite.texture = EYES_OPEN

	call_deferred("_blink_loop")

	BattleManager.setup_battle(GameManager.current_enemy_data)

	# Initialize HP display because setup does not emit initial HP signals.
	_on_player_hp_updated(BattleManager.player_hp, BattleManager.player_max_hp)
	_on_enemy_hp_updated(BattleManager.enemy_hp, BattleManager.enemy_max_hp)
	_on_shield_updated(BattleManager.player_block, BattleManager.enemy_block)

	if GameManager.current_enemy_data != null:
		enemy_name_label.text = GameManager.current_enemy_data.enemy_name
		if GameManager.current_enemy_data.battle_sprite != null:
			enemy_sprite.texture = GameManager.current_enemy_data.battle_sprite
		else:
			print("[Battle] Sprite musuh kosong di data!")
	else:
		enemy_name_label.text = "Musuh Misterius"
		print("[Battle] Tidak ada data musuh, pakai default")
		
		# Sembunyikan UI sementara sebelum animasi masuk
	enemy_name_label.modulate.a = 0.0
	enemy_hp_bar.modulate.a = 0.0
	enemy_intent_label.modulate.a = 0.0
	player_hp_bar.modulate.a = 0.0
	turn_label.modulate.a = 0.0
	energy_label.modulate.a = 0.0
	hand_container.modulate.a = 0.0
	player_sprite.modulate.a = 0.0
	enemy_sprite.modulate.a = 0.0
	if player_hp_number: player_hp_number.modulate.a = 0.0
	if enemy_hp_number: enemy_hp_number.modulate.a = 0.0
	
	# Panggil animasi masuk
	call_deferred("_play_intro_animation")

func _on_enemy_intent_updated(action: String, damage: int) -> void:
	match action:
		"ATTACK":
			enemy_intent_label.text = "⚠️ Akan Menyerang: %d Damage" % damage
			enemy_intent_label.modulate = Color.RED
		"DEFENSE":
			enemy_intent_label.text = "🛡️ Akan Bertahan"
			enemy_intent_label.modulate = Color.BLUE
		"ENHANCE":
			enemy_intent_label.text = "⚡ Akan Memperkuat Diri"
			enemy_intent_label.modulate = Color.YELLOW
		_:
			enemy_intent_label.text = ""
			
func _create_shield_ui() -> void:
	var player_ui: Dictionary = _make_shield_bar($PlayerArea, player_hp_bar, "PlayerShieldBar")
	player_shield_bar = player_ui["bar"] as ProgressBar
	player_shield_label = player_ui["label"] as Label

	var enemy_ui: Dictionary = _make_shield_bar($EnemyArea, enemy_hp_bar, "EnemyShieldBar")
	enemy_shield_bar = enemy_ui["bar"] as ProgressBar
	enemy_shield_label = enemy_ui["label"] as Label


func _make_shield_bar(parent_node: Node2D, hp_bar: ProgressBar, bar_name: String) -> Dictionary:
	var bar := ProgressBar.new()
	bar.name = bar_name
	bar.min_value = 0.0
	bar.max_value = SHIELD_BAR_MAX
	bar.value = 0.0
	bar.show_percentage = false
	bar.position = hp_bar.position + Vector2(0.0, hp_bar.size.y + 3.0)
	bar.size = Vector2(hp_bar.size.x, 18.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color("#17324D")
	background_style.corner_radius_top_left = 4
	background_style.corner_radius_top_right = 4
	background_style.corner_radius_bottom_left = 4
	background_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", background_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#269BFF")
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill_style)

	parent_node.add_child(bar)

	var label := Label.new()
	label.name = "ShieldNumber"
	label.text = "SHIELD 0"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(label)

	return {"bar": bar, "label": label}


func _on_hand_updated(hand: Array) -> void:
	for child in hand_container.get_children():
		child.queue_free()

	for card_data in hand:
		var card_ui = CARD_SCENE.instantiate()
		card_ui.card_data = card_data
		card_ui.card_clicked.connect(_on_card_clicked)
		hand_container.add_child(card_ui)


func _on_card_clicked(card_data: Resource) -> void:
	BattleManager.play_card(card_data)


func _on_energy_updated(current: int, max_val: int) -> void:
	energy_label.text = "Energy: %d/%d" % [current, max_val]

func _on_player_hp_updated(current: int, max_val: int) -> void:
	player_hp_bar.show_percentage = false
	player_hp_bar.max_value = max_val
	player_hp_bar.value = current
	if player_hp_number != null:
		player_hp_number.text = "%d / %d" % [current, max_val]
	
	if last_player_hp != -1 and current < last_player_hp:
		var dmg = last_player_hp - current
		spawn_floating_text("-%d" % dmg, Color.RED, player_sprite, Vector2(0, -100))
		_play_hit_effect(player_sprite, PLAYER_HURT)
	last_player_hp = current

func _on_enemy_hp_updated(current: int, max_val: int) -> void:
	enemy_hp_bar.show_percentage = false
	enemy_hp_bar.max_value = max_val
	enemy_hp_bar.value = current
	if enemy_hp_number != null:
		enemy_hp_number.text = "%d / %d" % [current, max_val]
		
	if last_enemy_hp != -1 and current < last_enemy_hp:
		var dmg = last_enemy_hp - current
		spawn_floating_text("-%d" % dmg, Color.RED, enemy_name_label, Vector2(0, 50))
		
		var hurt_tex = null
		if GameManager.current_enemy_data != null:
			hurt_tex = GameManager.current_enemy_data.hurt_sprite
			
		# Panggil efek hit dengan data yang dinamis
		_play_hit_effect(enemy_sprite, hurt_tex)
		
	last_enemy_hp = current

func _on_shield_updated(player_block: int, enemy_block: int) -> void:
	if is_instance_valid(player_shield_bar):
		player_shield_bar.max_value = SHIELD_BAR_MAX
		player_shield_bar.value = clampf(float(player_block), 0.0, SHIELD_BAR_MAX)
		player_shield_label.text = "SHIELD %d" % player_block

	if is_instance_valid(enemy_shield_bar):
		enemy_shield_bar.max_value = SHIELD_BAR_MAX
		enemy_shield_bar.value = clampf(float(enemy_block), 0.0, SHIELD_BAR_MAX)
		enemy_shield_label.text = "SHIELD %d" % enemy_block
		
	if last_player_shield != -1 and player_block > last_player_shield:
		var gain = player_block - last_player_shield
		spawn_floating_text("+%d" % gain, Color.CYAN, player_sprite, Vector2(50, -80))
	last_player_shield = player_block

	if last_enemy_shield != -1 and enemy_block > last_enemy_shield:
		var gain = enemy_block - last_enemy_shield
		spawn_floating_text("+%d" % gain, Color.CYAN, enemy_name_label, Vector2(50, 30))
	last_enemy_shield = enemy_block

func _on_turn_changed(turn_owner: String) -> void:
	if turn_owner == "player":
		turn_label.text = "Giliranmu"
		for child in hand_container.get_children():
			if child is BaseButton:
				child.disabled = false
	else:
		turn_label.text = "Giliran Musuh"
		for child in hand_container.get_children():
			if child is BaseButton:
				child.disabled = true

func _on_battle_finished(result: String) -> void:
	# Matikan interaksi tombol
	for child in hand_container.get_children():
		if child is BaseButton:
			child.disabled = true
			
	# Set teks hasil
	if result == "win":
		result_label.text = "MENANG!"
		result_label.modulate = Color.GOLD # Warna emas kalau menang
	else:
		result_label.text = "KALAH"
		result_label.modulate = Color.RED # Warna merah kalau kalah

	# Jalankan animasi keluar (sembunyikan UI, munculkan tulisan)
	await _play_outro_animation(result == "win")
	
	# Tunggu sebentar agar pemain bisa menikmati hasilnya
	await get_tree().create_timer(1.5).timeout
	
	# Kembali ke eksplorasi / game over
	if result == "win":
		GameManager.end_battle("win")
	else:
		GameManager.end_battle("lose")

func _blink_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(
			randf_range(2.0, 5.0)
		).timeout

		if not is_inside_tree():
			return

		player_sprite.texture = EYES_CLOSED

		await get_tree().create_timer(0.12).timeout

		if not is_inside_tree():
			return

		player_sprite.texture = EYES_OPEN

func _create_action_buttons() -> void:
	for child in hand_container.get_children():
		child.queue_free()

	# Posisikan ketiga gambar di tengah bawah.
	hand_container.anchor_left = 0.5
	hand_container.anchor_right = 0.5
	hand_container.anchor_top = 1.0
	hand_container.anchor_bottom = 1.0

	hand_container.offset_left = -270.0
	hand_container.offset_right = 270.0
	hand_container.offset_top = -245.0
	hand_container.offset_bottom = -10.0

	hand_container.custom_minimum_size = Vector2(540, 235)
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.add_theme_constant_override("separation", 10)

	var actions: Array[Dictionary] = [
		{
			"id": "ATTACK",
			"texture": ATTACK_CARD_TEXTURE,
			"tooltip": "20% critical hit, damage ganda"
		},
		{
			"id": "DEFENSE",
			"texture": DEFENSE_CARD_TEXTURE,
			"tooltip": "Shield sebesar 20% HP"
		},
		{
			"id": "EVADE",
			"texture": EVADE_CARD_TEXTURE,
			"tooltip": "Peluang menghindar 50%"
		}
	]

	for action in actions:
		var button := TextureButton.new()

		button.name = str(action["id"]) + "Button"
		button.texture_normal = action["texture"] as Texture2D
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(165, 220)
		button.tooltip_text = str(action["tooltip"])
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		button.pressed.connect(
			_on_action_pressed.bind(str(action["id"]))
		)

		hand_container.add_child(button)

func _on_action_pressed(action: String) -> void:
	BattleManager.choose_player_action(action)

# Fungsi untuk spawn floating text
func spawn_floating_text(text: String, color: Color, target_node: Node, offset: Vector2 = Vector2.ZERO) -> void:
	var ft = FloatingText.new()
	ui_layer.add_child(ft) # Tambahkan ke scene Battle
	# Hitung posisi tengah dari target (Player / Enemy)
	var spawn_pos = target_node.global_position + offset
	var random_offset = Vector2(randf_range(-20, 20), randf_range(-10, 10))
	ft.play(text, color, spawn_pos + random_offset)

func _on_player_evaded(success: bool) -> void:
	if success:
		spawn_floating_text("Evade!", Color.YELLOW, player_sprite, Vector2(0, -120))
	else:
		spawn_floating_text("Miss!", Color.GRAY, player_sprite, Vector2(0, -120))

func _shake_node(node: Control, intensity: float = 10.0, duration: float = 0.3) -> void:
	if not node: return
	
	var original_pos = node.position
	var tween = create_tween()
	
	# Bergetar ke kiri kanan selama durasi tertentu
	var steps = int(duration / 0.05) 
	for i in range(steps):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(node, "position", original_pos + offset, 0.03)
		
	# Kembalikan ke posisi semula
	tween.tween_property(node, "position", original_pos, 0.05)
	
func _play_hit_effect(sprite: TextureRect, hurt_texture: Texture2D) -> void:
	if not sprite: return
	
	# 1. Simpan tekstur asli (karena player punya animasi kedip mata)
	var original_texture = sprite.texture
	
	# 2. Ganti ke tekstur sakit (jika ada)
	if hurt_texture != null:
		sprite.texture = hurt_texture
		
	# 3. Beri warna merah sejenak (Modulate)
	sprite.modulate = Color(2.0, 0.5, 0.5) # Merah terang
	
	# 4. Getarkan sprite
	_shake_node(sprite, 15.0, 0.3)
	
	# 5. Tunggu sebentar (0.3 detik), lalu kembalikan semuanya
	await get_tree().create_timer(0.3).timeout
	
	# Pastikan sprite belum dihapus dari scene
	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE # Kembalikan normal
		
		# Jika ini Player, kembalikan ke tekstur mata aslinya
		# (supaya loop kedipan mata tidak rusak)
		if sprite == player_sprite:
			sprite.texture = EYES_OPEN
		elif hurt_texture != null:
			sprite.texture = original_texture

func _play_intro_animation() -> void:
	# Tunggu sebentar biar layar fade in dari SceneTransition selesai
	await get_tree().create_timer(0.3).timeout
	
	var tween = create_tween().set_parallel(true)
	
	# 1. Munculkan Sprite (Fade in)
	tween.tween_property(player_sprite, "modulate:a", 1.0, 0.5)
	tween.tween_property(enemy_sprite, "modulate:a", 1.0, 0.5)
	
	# 2. Munculkan UI (Fade in dengan delay sedikit biar bergantian)
	tween.tween_property(enemy_name_label, "modulate:a", 1.0, 0.4).set_delay(0.3)
	tween.tween_property(enemy_hp_bar, "modulate:a", 1.0, 0.4).set_delay(0.4)
	if enemy_hp_number: tween.tween_property(enemy_hp_number, "modulate:a", 1.0, 0.4).set_delay(0.4)
	
	tween.tween_property(player_hp_bar, "modulate:a", 1.0, 0.4).set_delay(0.5)
	if player_hp_number: tween.tween_property(player_hp_number, "modulate:a", 1.0, 0.4).set_delay(0.5)
	
	tween.tween_property(turn_label, "modulate:a", 1.0, 0.4).set_delay(0.6)
	tween.tween_property(energy_label, "modulate:a", 1.0, 0.4).set_delay(0.6)
	
	# 3. Animasi Hand Container meluncur dari bawah
	var original_hand_y = hand_container.position.y
	hand_container.position.y += 100 # Geser ke bawah dulu
	hand_container.modulate.a = 1.0  # Langsung set visible
	tween.tween_property(hand_container, "position:y", original_hand_y, 0.5).set_delay(0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 4. Animasi Sprite sedikit "maju" (pop)
	player_sprite.scale = Vector2(0.8, 0.8)
	enemy_sprite.scale = Vector2(0.8, 0.8)
	tween.tween_property(player_sprite, "scale", Vector2(1.0, 1.0), 0.4).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy_sprite, "scale", Vector2(1.0, 1.0), 0.4).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
func _play_outro_animation(is_win: bool) -> void:
	var tween = create_tween().set_parallel(true)
	
	# 1. Sembunyikan semua UI (kecuali sprite)
	tween.tween_property(enemy_name_label, "modulate:a", 0.0, 0.3)
	tween.tween_property(enemy_hp_bar, "modulate:a", 0.0, 0.3)
	tween.tween_property(enemy_intent_label, "modulate:a", 0.0, 0.3)
	tween.tween_property(player_hp_bar, "modulate:a", 0.0, 0.3)
	if player_hp_number: tween.tween_property(player_hp_number, "modulate:a", 0.0, 0.3)
	if enemy_hp_number: tween.tween_property(enemy_hp_number, "modulate:a", 0.0, 0.3)
	tween.tween_property(turn_label, "modulate:a", 0.0, 0.3)
	tween.tween_property(energy_label, "modulate:a", 0.0, 0.3)
	
	# Hand Container turun ke bawah lalu hilang
	var current_hand_y = hand_container.position.y
	tween.tween_property(hand_container, "position:y", current_hand_y + 100, 0.3)
	tween.tween_property(hand_container, "modulate:a", 0.0, 0.3)
	
	# Sembunyikan Shield bar juga
	if player_shield_bar: tween.tween_property(player_shield_bar, "modulate:a", 0.0, 0.3)
	if enemy_shield_bar: tween.tween_property(enemy_shield_bar, "modulate:a", 0.0, 0.3)
	if player_shield_label: tween.tween_property(player_shield_label, "modulate:a", 0.0, 0.3)
	if enemy_shield_label: tween.tween_property(enemy_shield_label, "modulate:a", 0.0, 0.3)
	
	# 2. Animasikan Sprite (Pemenang maju, pecundang mundur/pudar)
	if is_win:
		tween.tween_property(enemy_sprite, "modulate:a", 0.3, 0.5)
		tween.tween_property(enemy_sprite, "scale", Vector2(0.5, 0.5), 0.5)
		tween.tween_property(player_sprite, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(player_sprite, "modulate:a", 0.3, 0.5)
		tween.tween_property(player_sprite, "scale", Vector2(0.5, 0.5), 0.5)
		tween.tween_property(enemy_sprite, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 3. Munculkan Teks MENANG / KALAH dengan efek Pop
	await tween.finished # Tunggu UI hilang dulu baru teks muncul
	
	result_label.modulate.a = 0.0
	result_label.scale = Vector2(0.2, 0.2)
	result_label.pivot_offset = result_label.size / 2 # Agar scale dari tengah
	result_label.visible = true
	
	var text_tween = create_tween().set_parallel(true)
	text_tween.tween_property(result_label, "modulate:a", 1.0, 0.4)
	text_tween.tween_property(result_label, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
