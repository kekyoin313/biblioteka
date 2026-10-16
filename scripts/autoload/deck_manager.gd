extends Node
## DeckManager: menyimpan deck, collection, dan operasi kartu

signal deck_changed()

# Deck aktif yang dipakai battle
var deck: Array[Resource] = []   # isi: CardData
# Semua kartu yang dimiliki (untuk deck building)
var collection: Array[Resource] = []

func _ready() -> void:
	load_default_deck()

func load_default_deck() -> void:
	# Isi deck awal (nanti load dari .tres)
	deck.clear()
	# Contoh: 5 Strike + 4 Defend
	for i in 5: deck.append(load("res://data/cards/strike.tres"))
	for i in 4: deck.append(load("res://data/cards/defend.tres"))
	deck_changed.emit()

func add_card_to_collection(card: Resource) -> void:
	collection.append(card)
	deck_changed.emit()

func add_card_to_deck(card: Resource) -> void:
	deck.append(card)
	deck_changed.emit()

func remove_card_from_deck(card: Resource) -> void:
	var idx = deck.find(card)
	if idx != -1:
		deck.remove_at(idx)
		deck_changed.emit()

func get_shuffled_deck() -> Array:
	var copy = deck.duplicate()
	copy.shuffle()
	return copy
