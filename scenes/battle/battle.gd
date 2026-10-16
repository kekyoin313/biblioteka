extends Node2D

const CARD_SCENE = preload("res://scenes/battle/Card.tscn")

@onready var enemy_name_label: Label = $EnemyArea/EnemyName
@onready var enemy_hp_bar: ProgressBar = $EnemyArea/EnemyHPBar
@onready var player_hp_bar: ProgressBar = $PlayerArea/PlayerHPBar
@onready var turn_label: Label = $UILayer/TurnLabel
@onready var energy_label: Label = $UILayer/EnergyLabel
@onready var hand_container: HBoxContainer = $UILayer/HandContainer
@onready var end_turn_button: Button = $UILayer/EndTurnButton
@onready var result_label: Label = $UILayer/ResultLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	BattleManager.setup_battle(GameManager.current_enemy_data)
	
	BattleManager.hand_updated.connect(_on_hand_updated)
	BattleManager.energy_updated.connect(_on_energy_updated)
	BattleManager.player_hp_updated.connect(_on_player_hp_updated)
	BattleManager.enemy_hp_updated.connect(_on_enemy_hp_updated)
	BattleManager.turn_changed.connect(_on_turn_changed)
	BattleManager.battle_finished.connect(_on_battle_finished)
	
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	result_label.visible = false
	
	# Update UI awal
	_on_player_hp_updated(BattleManager.player_hp, BattleManager.player_max_hp)
	_on_enemy_hp_updated(BattleManager.enemy_hp, BattleManager.enemy_max_hp)
	_on_energy_updated(BattleManager.player_energy, BattleManager.player_max_energy)
	_on_hand_updated(BattleManager.hand)

	if GameManager.current_enemy_data:
		enemy_name_label.text = GameManager.current_enemy_data.enemy_name
	else:
		enemy_name_label.text = "Musuh Misterius"
		print("[Battle] Tidak ada data musuh, pakai default")

func _on_hand_updated(hand: Array) -> void:
	# Hapus kartu lama
	for child in hand_container.get_children():
		child.queue_free()
	# Tambah kartu baru
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
	player_hp_bar.max_value = max_val
	player_hp_bar.value = current

func _on_enemy_hp_updated(current: int, max_val: int) -> void:
	enemy_hp_bar.max_value = max_val
	enemy_hp_bar.value = current

func _on_turn_changed(owner: String) -> void:
	if owner == "player":
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
