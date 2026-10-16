extends Node

# === Sinyal ===
signal hand_updated(hand: Array)
signal energy_updated(current: int, max: int)
signal player_hp_updated(current: int, max: int)
signal enemy_hp_updated(current: int, max: int)
signal turn_changed(turn_owner: String)   # "player" atau "enemy"
signal battle_finished(result: String)    # "win" atau "lose"

# === State ===
var player_hp: int = 100
var player_max_hp: int = 100
var player_block: int = 0
var player_energy: int = 3
var player_max_energy: int = 3

var enemy_hp: int = 30
var enemy_max_hp: int = 30
var enemy_block: int = 0
var enemy_pattern: Array[int] = [5, 5, 8]
var enemy_turn_index: int = 0

var turn: String = "player"
var is_battle_over: bool = false

# Deck
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []

# === Setup ===
func setup_battle(enemy_data: Resource) -> void:
	# Reset
	player_hp = GameManager.player_hp
	player_max_hp = GameManager.player_max_hp
	player_block = 0
	player_energy = player_max_energy

	if enemy_data:
		enemy_hp = enemy_data.max_hp
		enemy_max_hp = enemy_data.max_hp
		enemy_pattern = enemy_data.attack_pattern
	else:
		enemy_hp = 30
		enemy_max_hp = 30
		enemy_pattern = [5, 5, 8]
	enemy_block = 0
	enemy_turn_index = 0

	turn = "player"
	is_battle_over = false

	# Setup deck
	draw_pile = DeckManager.get_shuffled_deck()
	hand.clear()
	discard_pile.clear()

	# Mulai turn player
	start_player_turn()

# === Turn Player ===
func start_player_turn() -> void:
	if is_battle_over: return
	turn = "player"
	player_block = 0
	player_energy = player_max_energy
	draw_cards(5)
	turn_changed.emit("player")
	energy_updated.emit(player_energy, player_max_energy)

func draw_cards(n: int) -> void:
	for i in n:
		if draw_pile.is_empty():
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
	hand_updated.emit(hand)

func play_card(card: Resource) -> void:
	if is_battle_over or turn != "player":
		return
	if player_energy < card.cost:
		print("[Battle] Energy tidak cukup!")
		return

	player_energy -= card.cost
	energy_updated.emit(player_energy, player_max_energy)

	if card.damage > 0:
		deal_damage_to_enemy(card.damage)
	if card.block > 0:
		player_block += card.block
	if card.heal > 0:
		heal_player(card.heal)

	hand.erase(card)
	discard_pile.append(card)
	hand_updated.emit(hand)
	print("[Battle] Main kartu: ", card.card_name)

func end_player_turn() -> void:
	if is_battle_over: return
	# Buang semua kartu di tangan
	for c in hand:
		discard_pile.append(c)
	hand.clear()
	hand_updated.emit(hand)
	enemy_turn()

# === Turn Musuh ===
func enemy_turn() -> void:
	if is_battle_over: return
	turn = "enemy"
	turn_changed.emit("enemy")

	# Pola attack musuh
	var dmg = enemy_pattern[enemy_turn_index % enemy_pattern.size()]
	enemy_turn_index += 1

	print("[Battle] Musuh menyerang! Damage: ", dmg)
	deal_damage_to_player(dmg)

	# Delay biar terasa natural
	await get_tree().create_timer(1.0).timeout

	if not is_battle_over:
		start_player_turn()

# === Damage & Heal ===
func deal_damage_to_enemy(amount: int) -> void:
	var actual = max(0, amount - enemy_block)
	enemy_block = max(0, enemy_block - amount)
	enemy_hp = max(0, enemy_hp - actual)
	enemy_hp_updated.emit(enemy_hp, enemy_max_hp)
	print("[Battle] Musuh kena ", actual, " damage. HP: ", enemy_hp)

	if enemy_hp <= 0:
		finish_battle("win")

func deal_damage_to_player(amount: int) -> void:
	var actual = max(0, amount - player_block)
	player_block = max(0, player_block - amount)
	player_hp = max(0, player_hp - actual)
	GameManager.player_hp = player_hp
	player_hp_updated.emit(player_hp, player_max_hp)
	print("[Battle] Player kena ", actual, " damage. HP: ", player_hp)

	if player_hp <= 0:
		finish_battle("lose")

func heal_player(amount: int) -> void:
	player_hp = min(player_max_hp, player_hp + amount)
	GameManager.player_hp = player_hp
	player_hp_updated.emit(player_hp, player_max_hp)

func finish_battle(result: String) -> void:
	is_battle_over = true
	battle_finished.emit(result)
	print("[Battle] Selesai: ", result)
