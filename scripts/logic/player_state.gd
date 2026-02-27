class_name PlayerState
extends RefCounted
## プレイヤー個別の状態管理

var player_id: int
var player_name: String
var is_ai: bool
var ai_difficulty: int
var hand: Array[CardData]
var acquired_cards: Array[CardData]
var score: int


func _init(id: int = 0, p_name: String = "", ai: bool = false, difficulty: int = 0) -> void:
	player_id = id
	player_name = p_name
	is_ai = ai
	ai_difficulty = difficulty
	hand = []
	acquired_cards = []
	score = 0


func init_hand() -> void:
	hand.clear()
	for i: int in range(GameConfig.BID_CARD_MIN, GameConfig.BID_CARD_MAX + 1):
		hand.append(CardData.create_bid_card(i))


func play_card(card_value: int) -> CardData:
	for i: int in range(hand.size()):
		if hand[i].value == card_value:
			return hand.pop_at(i)
	return null


func acquire_cards(cards: Array[CardData]) -> void:
	for card: CardData in cards:
		acquired_cards.append(card)
		score += card.value


func has_card(card_value: int) -> bool:
	for card: CardData in hand:
		if card.value == card_value:
			return true
	return false


func get_hand_values() -> Array[int]:
	var values: Array[int] = []
	for card: CardData in hand:
		values.append(card.value)
	values.sort()
	return values
