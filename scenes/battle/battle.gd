extends Node2D

const CARD_SCENE = preload("res://scenes/battle/Card.tscn")
const SHIELD_BAR_MAX: float = 30.0

@onready var enemy_name_label: Label = $EnemyArea/EnemyName
@onready var enemy_hp_bar: ProgressBar = $EnemyArea/EnemyHPBar
@onready var player_hp_bar: ProgressBar = $PlayerArea/PlayerHPBar
@onready var player_hp_number: Label = get_node_or_null("PlayerArea/PlayerHpNumber") as Label
@onready var enemy_hp_number: Label = get_node_or_null("EnemyArea/EnemyHpNumber") as Label
@onready var turn_label: Label = $UILayer/TurnLabel
@onready var energy_label: Label = $UILayer/EnergyLabel
@onready var hand_container: HBoxContainer = $UILayer/HandContainer
@onready var end_turn_button: Button = $UILayer/EndTurnButton
@onready var result_label: Label = $UILayer/ResultLabel

var player_shield_bar: ProgressBar
var enemy_shield_bar: ProgressBar
var player_shield_label: Label
var enemy_shield_label: Label


func _ready() -> void:
	_create_shield_ui()

	# Connect before setup so the initial hand and turn events are not missed.
	BattleManager.hand_updated.connect(_on_hand_updated)
	BattleManager.energy_updated.connect(_on_energy_updated)
	BattleManager.player_hp_updated.connect(_on_player_hp_updated)
	BattleManager.enemy_hp_updated.connect(_on_enemy_hp_updated)
	BattleManager.shield_updated.connect(_on_shield_updated)
	BattleManager.turn_changed.connect(_on_turn_changed)
	BattleManager.battle_finished.connect(_on_battle_finished)

	end_turn_button.pressed.connect(_on_end_turn_pressed)
	result_label.visible = false

	BattleManager.setup_battle(GameManager.current_enemy_data)

	# Initialize HP display because setup does not emit initial HP signals.
	_on_player_hp_updated(BattleManager.player_hp, BattleManager.player_max_hp)
	_on_enemy_hp_updated(BattleManager.enemy_hp, BattleManager.enemy_max_hp)
	_on_shield_updated(BattleManager.player_block, BattleManager.enemy_block)

	if GameManager.current_enemy_data != null:
		enemy_name_label.text = GameManager.current_enemy_data.enemy_name
	else:
		enemy_name_label.text = "Musuh Misterius"
		print("[Battle] Tidak ada data musuh, pakai default")


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


func _on_enemy_hp_updated(current: int, max_val: int) -> void:
	enemy_hp_bar.show_percentage = false
	enemy_hp_bar.max_value = max_val
	enemy_hp_bar.value = current
	if enemy_hp_number != null:
		enemy_hp_number.text = "%d / %d" % [current, max_val]


func _on_shield_updated(player_block: int, enemy_block: int) -> void:
	if is_instance_valid(player_shield_bar):
		player_shield_bar.max_value = SHIELD_BAR_MAX
		player_shield_bar.value = clampf(float(player_block), 0.0, SHIELD_BAR_MAX)
		player_shield_label.text = "SHIELD %d" % player_block

	if is_instance_valid(enemy_shield_bar):
		enemy_shield_bar.max_value = SHIELD_BAR_MAX
		enemy_shield_bar.value = clampf(float(enemy_block), 0.0, SHIELD_BAR_MAX)
		enemy_shield_label.text = "SHIELD %d" % enemy_block


func _on_turn_changed(turn_owner: String) -> void:
	if turn_owner == "player":
		turn_label.text = "Giliranmu"
		end_turn_button.disabled = false
	else:
		turn_label.text = "Giliran Musuh"
		end_turn_button.disabled = true


func _on_end_turn_pressed() -> void:
	BattleManager.end_player_turn()


func _on_battle_finished(result: String) -> void:
	end_turn_button.disabled = true
	result_label.visible = true
	if result == "win":
		result_label.text = "MENANG!"
		await get_tree().create_timer(2.0).timeout
		GameManager.end_battle("win")
	else:
		result_label.text = "KALAH..."
		await get_tree().create_timer(2.0).timeout
		GameManager.end_battle("lose")
