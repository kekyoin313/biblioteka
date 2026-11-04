extends Resource
class_name EnemyData

@export var enemy_name: String = "Unknown"
@export var max_hp: int = 30
@export var attack_pattern: Array[int] = [5, 5, 8]
@export var level: int = 0
@export_range(0.0, 1.0) var evade_chance: float = 0.2
@export var sprite: Texture2D
@export var battle_sprite: Texture2D
@export var hurt_sprite: Texture2D
@export var cards_reward: Array[Resource] = []
