extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -400.0

# Tambahkan referensi ke AnimatedSprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimationPlayer

const SFX_WALK = "res://assets/audio/sfx/Jalan.wav" # Ganti jika foldernya beda
const SFX_JUMP = "res://assets/audio/sfx/Lompat.wav"
const SFX_LAND = "res://assets/audio/sfx/Lompat(selesai).wav"

# Variabel untuk timer langkah kaki
var walk_timer: float = 0.0
const WALK_SFX_INTERVAL: float = 0.35 # Jeda antar suara langkah (detik)

func _ready() -> void:
	add_to_group("player")
	if animated_sprite:
		animated_sprite.play("idle")

func _physics_process(delta: float) -> void:
	# Simpan status sebelum gerakan (untuk deteksi mendarat)
	var was_on_floor: bool = is_on_floor()

	# Gravitasi
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# Lompat
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		# === SUARA LOMPAT ===
		AudioManager.play_sfx(SFX_JUMP) 

	# Gerak horizontal
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# ==========================================
	# LOGIKA ANIMASI & SUARA LANGKAH
	# ==========================================
	if animated_sprite:
		if not is_on_floor():
			animated_sprite.play("jump")
		elif direction != 0:
			animated_sprite.play("walk")
			
			if direction > 0:
				animated_sprite.flip_h = false
			else:
				animated_sprite.flip_h = true
				
			# === SUARA LANGKAH KAKI ===
			walk_timer += delta
			if walk_timer >= WALK_SFX_INTERVAL:
				AudioManager.play_sfx(SFX_WALK)
				walk_timer = 0.0 # Reset timer
		else:
			animated_sprite.play("idle")
			walk_timer = 0.0 # Reset timer saat diam

	# Eksekusi gerakan
	move_and_slide()

	# ==========================================
	# DETEKSI MENDARAT (LANDING)
	# ==========================================
	# Jika sebelumnya di udara, dan sekarang menyentuh tanah
	if not was_on_floor and is_on_floor():
		AudioManager.play_sfx(SFX_LAND)
