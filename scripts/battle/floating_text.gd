extends Label
class_name FloatingText

func _ready() -> void:
	# Pengaturan dasar visual
	set_anchors_preset(Control.PRESET_CENTER)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100 # Biar selalu di depan
	add_theme_font_size_override("font_size", 28)
	add_theme_constant_override("outline_size", 6)
	add_theme_color_override("font_outline_color", Color.BLACK)

func play(text: String, color: Color, start_pos: Vector2, direction: Vector2 = Vector2.UP) -> void:
	self.text = text
	modulate = color
	position = start_pos
	
	# Mulai animasi
	var tween = create_tween().set_parallel(true)
	
	# 1. Gerakan naik/turun
	tween.tween_property(self, "position", position + (direction * 60.0), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# 2. Efek memudar (fade out)
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_delay(0.5) # Tunggu 0.5 detik baru pudar
	
	# 3. Efek pop-up (membesar lalu normal)
	scale = Vector2(0.5, 0.5)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_delay(0.0)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.2)

	# Hancurkan diri setelah animasi selesai
	await tween.finished
	queue_free()
