extends Node

signal hand_updated(hand: Array)
signal energy_updated(current: int, max: int)
signal player_hp_updated(current: int, max: int)
signal enemy_hp_updated(current: int, max: int)
signal shield_updated(player_block: int, enemy_block: int)
signal turn_changed(turn_owner: String)
signal battle_finished(result: String)
signal enemy_intent_updated(action: String, damage: int)
signal player_evaded(success: bool)

# Aksi musuh yang sedang "ditampilkan" ke pemain
var enemy_planned_action: String = ""
var enemy_planned_damage: int = 0

const RECORD_PATH := "user://battle_records.jsonl"
const MODEL_PATH := "res://data/decision_tree_rewards.json"
const FEATURES: Array[String] = [
	"enemy_hp_ratio",
	"player_hp_ratio",
	"enemy_damage",
	"player_expected_damage",
	"enhance_ready",
	"player_damage_to_enemy_ratio",
	"enemy_damage_to_player_ratio",
	"last_action_defense"
]
const ACTIONS: Array[String] = ["ATTACK", "DEFENSE", "ENHANCE"]
const EXPLORATION_RATE: float = 0.20
const DEFENSE_BLOCK: int = 8
const ENHANCE_BONUS: int = 3
const TERMINAL_REWARD: float = 100.0

var player_hp: int = 100
var player_max_hp: int = 100
var player_block: int = 0
var player_energy: int = 3
var player_max_energy: int = 3

var enemy_hp: int = 60
var enemy_max_hp: int = 60
var enemy_block: int = 0
var enemy_pattern: Array[int] = [4, 4, 6]
var enemy_turn_index: int = 0
var enemy_damage_bonus: int = 0
var enemy_enhance_ready: bool = true
var last_enemy_action: String = ""

var turn: String = "player"
var is_battle_over: bool = false

var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []

var learned_model: Dictionary = {}
var episode_id: String = ""
var decision_step: int = 0
var current_decision: Dictionary = {}


func setup_battle(enemy_data: Resource) -> void:
	player_hp = GameManager.player_hp
	player_max_hp = GameManager.player_max_hp
	player_block = 0
	player_energy = player_max_energy

	if enemy_data != null:
		enemy_hp = int(enemy_data.get("max_hp"))
		enemy_max_hp = enemy_hp
		enemy_pattern = enemy_data.get("attack_pattern")
	else:
		enemy_hp = 60
		enemy_max_hp = 60
		enemy_pattern = [4, 4, 6]

	if enemy_pattern.is_empty():
		enemy_pattern = [4, 4, 6]

	enemy_block = 0
	shield_updated.emit(player_block, enemy_block)
	enemy_turn_index = 0
	enemy_damage_bonus = 0
	enemy_enhance_ready = true
	last_enemy_action = ""
	turn = "player"
	is_battle_over = false

	draw_pile = DeckManager.get_shuffled_deck()
	hand.clear()
	discard_pile.clear()
	current_decision.clear()
	decision_step = 0
	episode_id = str(Time.get_unix_time_from_system()) + "_" + str(Time.get_ticks_usec())
	_load_learning_model()
	print("[AI Training] Catatan pertandingan: ", OS.get_user_data_dir().path_join("battle_records.jsonl"))

	plan_enemy_turn()

var player_evade_active: bool = false

func plan_enemy_turn() -> void:
	if is_battle_over: return
	
	# Musuh memilih aksi menggunakan AI (fungsi yang sudah ada)
	var base_damage: int = enemy_pattern[enemy_turn_index % enemy_pattern.size()]
	var features: Dictionary = _build_state_features(base_damage + enemy_damage_bonus)
	var action: String = _choose_enemy_action(features)
	
	# Simpan rencana musuh
	enemy_planned_action = action
	enemy_planned_damage = base_damage + enemy_damage_bonus
	
	# Catat untuk training AI
	current_decision = {
		"episode_id": episode_id,
		"step": decision_step,
		"features": features,
		"action": action,
		"player_hp_start": player_hp,
		"enemy_hp_start": enemy_hp
	}
	decision_step += 1
	
	print("[Enemy AI] Merencanakan: ", action, " | damage: ", enemy_planned_damage)
	
	# Pindah giliran ke player
	turn = "player"
	turn_changed.emit("player")
	
	# Tampilkan informasi ke UI (akan kita tangkap di battle.gd)
	enemy_intent_updated.emit(action, enemy_planned_damage)

func choose_player_action(action: String) -> void:
	if is_battle_over or turn != "player":
		return

	player_evade_active = false

	match action:
		"ATTACK":
			# Serangan dasar 6 damage.
			# Peluang critical 20% menghasilkan 12 damage.
			var is_critical: bool = randf() < 0.20
			var damage: int = 12 if is_critical else 6

			if is_critical:
				print("[Battle] CRITICAL HIT! Damage: ", damage)
			else:
				print("[Battle] Serangan biasa. Damage: ", damage)

			deal_damage_to_enemy(damage)

		"DEFENSE":
			# Shield sebesar 20% HP maksimal pemain.
			player_block = int(round(player_max_hp * 0.20))
			shield_updated.emit(player_block, enemy_block)

			print("[Battle] Defense! Shield: ", player_block)

		"EVADE":
			# Peluang menghindar diperiksa saat musuh menyerang.
			player_evade_active = true
			print("[Battle] Bersiap menghindar!")
			
	if is_battle_over: return
	
	turn = "enemy"
	turn_changed.emit("enemy")
	_execute_enemy_planned_action()

	# Setiap aksi pemain langsung mengakhiri gilirannya.
	if not is_battle_over:
		await get_tree().create_timer(1.0).timeout
		if not is_battle_over:
			plan_enemy_turn()


func draw_cards(amount: int) -> void:
	for _i in range(amount):
		if draw_pile.is_empty():
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
	hand_updated.emit(hand)


func play_card(card: Resource) -> void:
	if is_battle_over or turn != "player" or card == null:
		return

	var cost: int = int(card.get_meta("cost", 0))
	var damage: int = int(card.get_meta("damage", 0))
	var block: int = int(card.get_meta("block", 0))
	var heal: int = int(card.get_meta("heal", 0))
	var card_name: String = str(card.get_meta("card_name", "Unknown"))

	if player_energy < cost:
		print("[Battle] Energy tidak cukup!")
		return

	player_energy -= cost
	energy_updated.emit(player_energy, player_max_energy)

	if damage > 0:
		deal_damage_to_enemy(damage)
	if block > 0 and not is_battle_over:
		player_block += block
		shield_updated.emit(player_block, enemy_block)
		print("[Battle] Player mendapat ", block, " Block. Total: ", player_block)
	if heal > 0 and not is_battle_over:
		heal_player(heal)

	hand.erase(card)
	discard_pile.append(card)
	hand_updated.emit(hand)
	print("[Battle] Main kartu: ", card_name)

func _build_state_features(current_enemy_damage: int) -> Dictionary:
	var expected_player_damage: float = _estimate_next_player_damage()
	var enemy_hp_ratio: float = float(enemy_hp) / float(maxi(enemy_max_hp, 1))
	var player_hp_ratio: float = float(player_hp) / float(maxi(player_max_hp, 1))
	return {
		"enemy_hp_ratio": enemy_hp_ratio,
		"player_hp_ratio": player_hp_ratio,
		"enemy_damage": float(current_enemy_damage),
		"player_expected_damage": expected_player_damage,
		"enhance_ready": 1.0 if enemy_enhance_ready else 0.0,
		"player_damage_to_enemy_ratio": expected_player_damage / float(maxi(enemy_hp, 1)),
		"enemy_damage_to_player_ratio": float(current_enemy_damage) / float(maxi(player_hp, 1)),
		"last_action_defense": 1.0 if last_enemy_action == "DEFENSE" else 0.0
	}


func _estimate_next_player_damage() -> float:
	# Perkiraan damage Attack:
	# 80% x 6 + 20% x 12 = 7.2
	return 7.2


func _estimate_player_damage_this_turn() -> float:
	# Cari total damage tertinggi yang bisa dimainkan dari tangan dengan energy saat ini.
	return _max_damage_for_cards(hand, player_energy)


func _max_damage_for_cards(cards: Array, available_energy: int) -> float:
	# Tangan biasanya kecil (5 kartu), sehingga mencoba kombinasi subset cukup murah.
	var card_count: int = cards.size()
	var best_damage: int = 0
	for mask in range(1 << card_count):
		var cost_sum: int = 0
		var damage_sum: int = 0
		for index in range(card_count):
			if (mask & (1 << index)) != 0:
				var card: Resource = cards[index]
				cost_sum += int(card.get_meta("cost", 0))
				damage_sum += int(card.get_meta("damage", 0))
		if cost_sum <= available_energy:
			best_damage = maxi(best_damage, damage_sum)
	return float(best_damage)


func _choose_enemy_action(features: Dictionary) -> String:
	var legal_actions: Array[String] = ["ATTACK", "DEFENSE"]
	if enemy_enhance_ready:
		legal_actions.append("ENHANCE")

	# Eksplorasi 20% membantu mengumpulkan hasil untuk berbagai aksi, bukan ATTACK saja.
	if randf() < EXPLORATION_RATE:
		return legal_actions[randi_range(0, legal_actions.size() - 1)]

	if not learned_model.is_empty():
		var best_action: String = legal_actions[0]
		var best_value: float = -INF
		for action in legal_actions:
			var value: float = _predict_action_value(features, action)
			if value > best_value:
				best_value = value
				best_action = action
		return best_action

	return _starter_policy(features)


func _starter_policy(features: Dictionary) -> String:
	# Fallback sebelum model hasil training tersedia.
	var enemy_hp_ratio: float = float(features["enemy_hp_ratio"])
	var player_hp_ratio: float = float(features["player_hp_ratio"])
	var incoming_ratio: float = float(features["enemy_damage_to_player_ratio"])
	var player_threat: float = float(features["player_damage_to_enemy_ratio"])

	if float(features["enemy_damage"]) >= player_hp:
		return "ATTACK"
	if enemy_hp_ratio < 0.25 and player_threat > 0.25:
		return "DEFENSE"
	if enemy_enhance_ready and player_hp_ratio > 0.35 and incoming_ratio < 0.50 and player_threat < 0.75:
		return "ENHANCE"
	if last_enemy_action == "DEFENSE":
		return "ATTACK"
	return "ATTACK"


func _load_learning_model() -> void:
	learned_model.clear()
	if not FileAccess.file_exists(MODEL_PATH):
		print("[Enemy AI] Model hasil training belum ada. Menggunakan starter policy + eksplorasi.")
		return
	var file: FileAccess = FileAccess.open(MODEL_PATH, FileAccess.READ)
	if file == null:
		push_warning("Tidak bisa membuka model: " + MODEL_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.get("model_type", "") == "action_value_regression":
		learned_model = parsed
		print("[Enemy AI] Model hasil training berhasil dimuat.")
	else:
		push_warning("Format model AI tidak dikenal. Menggunakan starter policy.")


func _predict_action_value(features: Dictionary, action: String) -> float:
	var input_names: Array = learned_model.get("input_features", [])
	var input_values: Array[float] = []
	for input_name_variant in input_names:
		var input_name: String = str(input_name_variant)
		if input_name.begins_with("action_"):
			input_values.append(1.0 if input_name == "action_" + action else 0.0)
		else:
			input_values.append(float(features.get(input_name, 0.0)))

	var left: Array = learned_model.get("children_left", [])
	var right: Array = learned_model.get("children_right", [])
	var feature_indices: Array = learned_model.get("feature", [])
	var thresholds: Array = learned_model.get("threshold", [])
	var values: Array = learned_model.get("value", [])
	if left.is_empty() or right.is_empty() or values.is_empty():
		return -INF

	var node: int = 0
	var guard: int = 0
	while int(left[node]) != -1 and guard < left.size():
		var feature_index: int = int(feature_indices[node])
		if feature_index < 0 or feature_index >= input_values.size():
			break
		if input_values[feature_index] <= float(thresholds[node]):
			node = int(left[node])
		else:
			node = int(right[node])
		guard += 1
	return float(values[node])


func _finalize_current_decision(done: bool, result: String) -> void:
	if current_decision.is_empty():
		return

	var player_hp_start: int = int(current_decision.get("player_hp_start", player_hp))
	var enemy_hp_start: int = int(current_decision.get("enemy_hp_start", enemy_hp))
	var player_damage_received: int = player_hp_start - player_hp
	var enemy_damage_received: int = enemy_hp_start - enemy_hp
	# Reward positif menguntungkan musuh: damage ke Player dikurangi damage yang diterima musuh.
	var reward: float = float(player_damage_received - enemy_damage_received)
	if done:
		# GameManager memakai "win" untuk kemenangan Player, "lose" untuk kekalahan Player.
		reward += TERMINAL_REWARD if result == "lose" else -TERMINAL_REWARD

	var record: Dictionary = {
		"episode_id": str(current_decision.get("episode_id", episode_id)),
		"step": int(current_decision.get("step", 0)),
		"features": current_decision.get("features", {}),
		"action": str(current_decision.get("action", "ATTACK")),
		"reward": reward,
		"done": done,
		"result": result
	}
	_append_record(record)
	current_decision.clear()


func _append_record(record: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(RECORD_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(RECORD_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Tidak bisa menyimpan battle record ke " + RECORD_PATH)
		return
	file.seek_end()
	file.store_line(JSON.stringify(record))
	file.close()


func deal_damage_to_enemy(amount: int) -> void:
	var actual: int = maxi(0, amount - enemy_block)
	enemy_block = maxi(0, enemy_block - amount)
	enemy_hp = maxi(0, enemy_hp - actual)
	shield_updated.emit(player_block, enemy_block)
	enemy_hp_updated.emit(enemy_hp, enemy_max_hp)
	print("[Battle] Musuh menerima ", actual, " damage. HP: ", enemy_hp)
	if enemy_hp <= 0:
		finish_battle("win")



func deal_damage_to_player(amount: int) -> void:
	if player_evade_active:
		player_evade_active = false
		var success = randf() < 0.50
		player_evaded.emit(success) # <--- Tambahkan ini
		
		if success:
			print("[Battle] Evade berhasil!")
			return
		print("[Battle] Evade gagal!")

	var actual: int = maxi(0, amount - player_block)
	player_block = maxi(0, player_block - amount)
	player_hp = maxi(0, player_hp - actual)

	shield_updated.emit(player_block, enemy_block)
	GameManager.player_hp = player_hp
	player_hp_updated.emit(player_hp, player_max_hp)

	print("[Battle] Player menerima ", actual, " damage. HP: ", player_hp)

	if player_hp <= 0:
		finish_battle("lose")

func heal_player(amount: int) -> void:
	player_hp = mini(player_max_hp, player_hp + amount)
	GameManager.player_hp = player_hp
	player_hp_updated.emit(player_hp, player_max_hp)


func finish_battle(result: String) -> void:
	if is_battle_over:
		return
	is_battle_over = true
	_finalize_current_decision(true, result)
	battle_finished.emit(result)
	print("[Battle] Selesai: ", result)

func _execute_enemy_planned_action() -> void:
	_finalize_current_decision(false, "")
	enemy_block = 0
	shield_updated.emit(player_block, enemy_block)
	
	last_enemy_action = enemy_planned_action
	print("[Battle] Musuh eksekusi: ", enemy_planned_action)
	
	match enemy_planned_action:
		"ATTACK":
			enemy_turn_index += 1
			enemy_damage_bonus = 0
			enemy_enhance_ready = true
			deal_damage_to_player(enemy_planned_damage)
		"DEFENSE":
			enemy_block += DEFENSE_BLOCK
			shield_updated.emit(player_block, enemy_block)
			print("[Battle] Musuh bertahan.")
		"ENHANCE":
			enemy_damage_bonus += ENHANCE_BONUS
			enemy_enhance_ready = false
			print("[Battle] Musuh enhance +", ENHANCE_BONUS)
