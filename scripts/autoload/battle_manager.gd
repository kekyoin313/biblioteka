extends Node

signal player_hp_updated(current: int, max: int)
signal enemy_hp_updated(current: int, max: int)
signal shield_updated(player_block: int, enemy_block: int)
signal turn_changed(turn_owner: String)
signal battle_finished(result: String)
signal enemy_intent_updated(action: String, damage: int)
signal player_evaded(success: bool)
signal enemy_attacked

const ENEMY_ATTACK_WINDUP: float = 0.35
const RECORD_PATH := "user://battle_records.jsonl"
const MODEL_PATH := "res://data/decision_tree_rewards.json"
const SFX_ATTACK_MC := "res://assets/audio/sfx/attack_mc_1.mp3"
const SFX_ATTACK_ENEMY := "res://assets/audio/sfx/Attack_Enemy.mp3"
const SFX_DEFENSE_MC := "res://assets/audio/sfx/Defence_Up_Mc.mp3"

const TERMINAL_REWARD: float = 100.0
const PLAYER_ACTION_DELAY: float = 1.0
const ENEMY_WINDUP_DELAY: float = 0.8
const ENEMY_ACTION_DELAY: float = 1.0

# Nilai di bawah ini disetel per musuh lewat EnemyData saat setup_battle.
var defense_block: int = 8
var enhance_bonus: int = 3
var exploration_rate: float = 0.20
var player_damage_multiplier: float = 1.0
var is_boss_fight: bool = false

var player_hp: int = 100
var player_max_hp: int = 100
var player_block: int = 0
var player_evade_active: bool = false

var enemy_hp: int = 60
var enemy_max_hp: int = 60
var enemy_block: int = 0
var enemy_pattern: Array[int] = [4, 4, 6]
var enemy_turn_index: int = 0
var enemy_damage_bonus: int = 0
var enemy_enhance_ready: bool = true
var last_enemy_action: String = ""
var enemy_planned_action: String = ""
var enemy_planned_damage: int = 0

var turn: String = "player"
var is_battle_over: bool = false

var learned_model: Dictionary = {}
var episode_id: String = ""
var decision_step: int = 0
var current_decision: Dictionary = {}


func setup_battle(enemy_data: Resource) -> void:
	player_hp = GameManager.player_hp
	player_max_hp = GameManager.player_max_hp
	player_block = 0
	player_evade_active = false

	defense_block = 8
	enhance_bonus = 3
	exploration_rate = 0.20
	player_damage_multiplier = 1.0
	is_boss_fight = false

	if enemy_data != null:
		enemy_hp = int(enemy_data.get("max_hp"))
		enemy_max_hp = enemy_hp
		enemy_pattern = enemy_data.get("attack_pattern")

		var tuning: EnemyData = enemy_data as EnemyData
		if tuning != null:
			defense_block = tuning.defense_block
			enhance_bonus = tuning.enhance_bonus
			exploration_rate = tuning.exploration_rate
			player_damage_multiplier = tuning.player_damage_multiplier
			is_boss_fight = tuning.is_boss
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

	current_decision.clear()
	decision_step = 0
	episode_id = str(Time.get_unix_time_from_system()) + "_" + str(Time.get_ticks_usec())
	_load_learning_model()
	print("[AI Training] Catatan pertandingan: ", OS.get_user_data_dir().path_join("battle_records.jsonl"))

	plan_enemy_turn()


func plan_enemy_turn() -> void:
	if is_battle_over:
		return

	var pattern_damage: int = enemy_pattern[enemy_turn_index % enemy_pattern.size()]
	var base_damage: int = int(round(float(pattern_damage) * _phase_damage_multiplier()))
	var features: Dictionary = _build_state_features(base_damage + enemy_damage_bonus)
	var action: String = _choose_enemy_action(features)

	enemy_planned_action = action
	enemy_planned_damage = base_damage + enemy_damage_bonus

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

	turn = "player"
	turn_changed.emit("player")
	enemy_intent_updated.emit(action, enemy_planned_damage)


func choose_player_action(action: String) -> void:
	if is_battle_over or turn != "player":
		return

	turn = "busy"
	player_evade_active = false

	match action:
		"ATTACK":
			var is_critical: bool = randf() < 0.20
			var base_damage: int = GameManager.player_base_damage
			var damage: int = base_damage * 2 if is_critical else base_damage
			damage = int(round(float(damage) * player_damage_multiplier))
			AudioManager.play_sfx(SFX_ATTACK_MC)

			if is_critical:
				print("[Battle] CRITICAL HIT! Damage: ", damage)
			else:
				print("[Battle] Serangan biasa. Damage: ", damage)

			deal_damage_to_enemy(damage)

		"DEFENSE":
			player_block = int(round(player_max_hp * 0.20))
			shield_updated.emit(player_block, enemy_block)
			AudioManager.play_sfx(SFX_DEFENSE_MC)
			print("[Battle] Defense! Shield: ", player_block)

		"EVADE":
			player_evade_active = true
			print("[Battle] Bersiap menghindar!")

	if is_battle_over:
		return

	await get_tree().create_timer(PLAYER_ACTION_DELAY).timeout
	if is_battle_over:
		return

	turn = "enemy"
	turn_changed.emit("enemy")
	await get_tree().create_timer(ENEMY_WINDUP_DELAY).timeout
	if is_battle_over:
		return

	await _execute_enemy_planned_action()
	if is_battle_over:
		return

	await get_tree().create_timer(ENEMY_ACTION_DELAY).timeout
	if is_battle_over:
		return

	plan_enemy_turn()


# Boss makin berbahaya saat HP-nya turun: fase 2 (<=60%) x1.25, fase 3 (<=30%) x1.5.
func _phase_damage_multiplier() -> float:
	if not is_boss_fight:
		return 1.0
	var ratio: float = float(enemy_hp) / float(maxi(enemy_max_hp, 1))
	if ratio <= 0.30:
		return 1.5
	if ratio <= 0.60:
		return 1.25
	return 1.0


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
	# Perkiraan damage Attack: 80% x base + 20% x 2*base = 1.2 x base
	return float(GameManager.player_base_damage) * 1.2 * player_damage_multiplier


func _choose_enemy_action(features: Dictionary) -> String:
	if is_boss_fight:
		return _boss_learned_policy(features)

	var legal_actions: Array[String] = ["ATTACK", "DEFENSE"]
	if enemy_enhance_ready:
		legal_actions.append("ENHANCE")

	if randf() < exploration_rate:
		return legal_actions[randi_range(0, legal_actions.size() - 1)]

	if not learned_model.is_empty():
		var best_action: String = ""
		var best_value: float = -INF
		for action in legal_actions:
			var value: float = _predict_action_value(features, action)
			if value > best_value:
				best_value = value
				best_action = action
		# Kalau tidak ada aksi yang bisa dinilai, jangan asal ATTACK: pakai starter policy.
		if not best_action.is_empty():
			return best_action

	return _starter_policy(features)


# Boss memakai model hasil belajar dari pertarungan melawan musuh biasa.
# Tanpa aksi acak. Dua pengaman agar pertarungan tetap adil dan bisa dimenangkan:
#  1. Kalau serangan sekarang bisa menghabisi pemain, selalu ATTACK.
#  2. Tidak boleh DEFENSE dua kali berturut-turut (shield boss besar, bisa membuatnya kebal).
# Kalau model belum tersedia/belum reliable, jatuh ke aturan di _boss_policy.
func _boss_learned_policy(features: Dictionary) -> String:
	if int(features["enemy_damage"]) >= player_hp + player_block:
		return "ATTACK"

	if learned_model.is_empty():
		return _boss_policy(features)

	var legal_actions: Array[String] = ["ATTACK", "DEFENSE"]
	if enemy_enhance_ready:
		legal_actions.append("ENHANCE")
	if last_enemy_action == "DEFENSE":
		legal_actions.erase("DEFENSE")

	var best_action: String = ""
	var best_value: float = -INF
	for action in legal_actions:
		var value: float = _predict_action_value(features, action)
		if value > best_value:
			best_value = value
			best_action = action

	if not best_action.is_empty():
		return best_action
	return _boss_policy(features)


# Cadangan: kebijakan boss berbasis aturan (tanpa model).
# Kebijakan boss: tanpa aksi acak dan tanpa model. Membaca kondisi saat ini.
# Catatan: aksi pemain di giliran ini belum diketahui, jadi boss bereaksi pada
# keadaan (shield pemain, HP, ancaman damage), bukan menebak pilihan pemain.
func _boss_policy(features: Dictionary) -> String:
	var hp_ratio: float = float(features["enemy_hp_ratio"])
	var damage: int = int(features["enemy_damage"])
	var player_threat: float = float(features["player_damage_to_enemy_ratio"])

	# 1. Bisa menghabisi pemain sekarang: selalu serang.
	if damage >= player_hp + player_block:
		return "ATTACK"

	# 2. Serangan akan habis diserap shield pemain: jangan buang giliran, isi ENHANCE.
	if player_block >= damage and enemy_enhance_ready:
		return "ENHANCE"

	# 3. Dalam bahaya (HP rendah atau pukulan pemain terlalu besar): bertahan,
	#    tapi tidak dua kali berturut-turut.
	if (hp_ratio < 0.30 or player_threat >= 0.45) and last_enemy_action != "DEFENSE":
		return "DEFENSE"

	# 4. Selebihnya menekan dengan serangan.
	return "ATTACK"


func _starter_policy(features: Dictionary) -> String:
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
	if not (parsed is Dictionary) or parsed.get("model_type", "") != "action_value_regression":
		push_warning("Format model AI tidak dikenal. Menggunakan starter policy.")
		return

	# Model hanya dipakai kalau datanya cukup (flag ini ditulis oleh tools/train_from_matches.py).
	if not bool(parsed.get("reliable", false)):
		print("[Enemy AI] Model belum reliable (%d battle tercatat). Menggunakan starter policy + eksplorasi." % int(parsed.get("episodes", 0)))
		return

	# Format v2: satu pohon per aksi di dalam "trees", nama fitur di "features".
	if not (parsed.get("trees") is Dictionary) or not (parsed.get("features") is Array):
		push_warning("Model AI tidak punya 'trees' dan 'features' (format v2). Menggunakan starter policy.")
		return

	learned_model = parsed
	print("[Enemy AI] Model hasil training berhasil dimuat.")


func _predict_action_value(features: Dictionary, action: String) -> float:
	var trees: Dictionary = learned_model.get("trees", {})
	if not trees.has(action):
		return -INF
	var tree: Dictionary = trees[action]

	# Urutan fitur harus sama dengan urutan saat training (indeks "feature" merujuk ke sini).
	var feature_names: Array = learned_model.get("features", [])
	var input_values: Array[float] = []
	for feature_name in feature_names:
		input_values.append(float(features.get(str(feature_name), 0.0)))

	var left: Array = tree.get("children_left", [])
	var right: Array = tree.get("children_right", [])
	var feature_indices: Array = tree.get("feature", [])
	var thresholds: Array = tree.get("threshold", [])
	var values: Array = tree.get("value", [])
	if left.is_empty() or right.is_empty() or values.is_empty():
		return -INF

	# Telusuri dari akar (node 0) sampai daun (children_left == -1).
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
	# Pertarungan boss tidak dicatat, supaya data training musuh biasa tidak tercemar.
	if is_boss_fight:
		current_decision.clear()
		return
	if current_decision.is_empty():
		return

	var player_hp_start: int = int(current_decision.get("player_hp_start", player_hp))
	var enemy_hp_start: int = int(current_decision.get("enemy_hp_start", enemy_hp))
	var player_damage_received: int = player_hp_start - player_hp
	var enemy_damage_received: int = enemy_hp_start - enemy_hp
	var reward: float = float(player_damage_received - enemy_damage_received)
	if done:
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
		var success: bool = randf() < 0.50
		player_evaded.emit(success)

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
			enemy_attacked.emit()
			await get_tree().create_timer(ENEMY_ATTACK_WINDUP).timeout
			if is_battle_over:
				return
			AudioManager.play_sfx(SFX_ATTACK_ENEMY)
			enemy_turn_index += 1
			enemy_damage_bonus = 0
			enemy_enhance_ready = true
			deal_damage_to_player(enemy_planned_damage)
		"DEFENSE":
			enemy_block += defense_block
			shield_updated.emit(player_block, enemy_block)
			print("[Battle] Musuh bertahan.")
		"ENHANCE":
			enemy_damage_bonus += enhance_bonus
			enemy_enhance_ready = false
			print("[Battle] Musuh enhance +", enhance_bonus)	
