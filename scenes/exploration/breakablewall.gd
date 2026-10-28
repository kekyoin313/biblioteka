extends StaticBody2D

@export var wall_id: String = ""
@export var hp: int = 3

var is_broken: bool = false


func _ready() -> void:
	# Level dimuat ulang setelah battle, jadi tembok yang sudah pecah harus hilang lagi
	if wall_id != "" and GameManager.is_wall_broken(wall_id):
		queue_free()


func take_hit(damage: int) -> void:
	if is_broken:
		return
	hp -= damage
	if hp <= 0:
		_break()
		return
	modulate = Color(1.0, 0.5, 0.5)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


func _break() -> void:
	is_broken = true
	$CollisionShape2D.set_deferred("disabled", true)
	if wall_id != "":
		GameManager.mark_wall_broken(wall_id)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
