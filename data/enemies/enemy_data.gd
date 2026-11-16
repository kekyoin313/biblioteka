extends Resource
class_name EnemyData

@export var enemy_name: String = "Unknown"
@export var max_hp: int = 30
@export var attack_pattern: Array[int] = [5, 5, 8]
@export var level: int = 0
@export_range(0.0, 1.0) var evade_chance: float = 0.2
@export var cards_reward: Array[Resource] = []

@export_group("Battle Sprites")
@export var battle_idle_sprite: Texture2D
@export var battle_hurt_sprite: Texture2D
@export var battle_attack_sprite: Texture2D

@export_group("Combat Tuning")
@export var defense_block: int = 8
@export var enhance_bonus: int = 3
@export_range(0.0, 1.0) var exploration_rate: float = 0.2
@export var player_damage_multiplier: float = 1.0

@export_group("Boss")

@export var is_boss: bool = false
@export_file("*.tscn") var scene_after_win: String = ""
