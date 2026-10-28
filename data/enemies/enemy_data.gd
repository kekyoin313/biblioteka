extends Resource
class_name EnemyData

@export var enemy_name: String = "Unknown"
@export var max_hp: int = 30
@export var attack_pattern: Array[int] = [5, 5, 8]  # pola damage per turn
@export var sprite: Texture2D
@export var battle_sprite: Texture2D
@export var hurt_sprite: Texture2D
@export var cards_reward: Array[Resource] = []
