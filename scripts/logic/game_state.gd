class_name GameState
extends RefCounted
## ゲーム全体の状態管理（UIに依存しない純粋データ）

enum Phase {
	SETUP,        ## ゲーム開始前
	REVEAL_STOCK, ## 銘柄カードをめくる
	BIDDING,      ## 入札中（カード選択待ち）
	RESOLVING,    ## 判定中
	ROUND_END,    ## ラウンド終了
	GAME_OVER,    ## ゲーム終了
}

var phase: Phase = Phase.SETUP
var players: Array[PlayerState] = []
var stock_deck: Array[CardData] = []
var current_stock_card: CardData = null
var carried_over_cards: Array[CardData] = []
var current_round: int = 0
var bids: Dictionary = {}  ## {player_id: int -> CardData}
var round_history: Array[Dictionary] = []


func init_game(player_states: Array[PlayerState]) -> void:
	phase = Phase.SETUP
	players = player_states
	current_round = 0
	bids.clear()
	carried_over_cards.clear()
	round_history.clear()
	_init_stock_deck()
	for player: PlayerState in players:
		player.init_hand()


func _init_stock_deck() -> void:
	stock_deck.clear()
	# 銘柄カード +1〜+10
	for i: int in range(GameConfig.STOCK_CARD_MIN, GameConfig.STOCK_CARD_MAX + 1):
		stock_deck.append(CardData.create_stock_card(i))
	# ハゲタカカード -5〜-1
	for i: int in range(GameConfig.VULTURE_CARD_MIN, GameConfig.VULTURE_CARD_MAX + 1):
		stock_deck.append(CardData.create_vulture_card(i))
	stock_deck.shuffle()


func draw_stock_card() -> CardData:
	if stock_deck.is_empty():
		return null
	current_stock_card = stock_deck.pop_back()
	return current_stock_card


func register_bid(player_id: int, card: CardData) -> void:
	bids[player_id] = card


func all_bids_placed() -> bool:
	return bids.size() == players.size()


func get_player(player_id: int) -> PlayerState:
	for player: PlayerState in players:
		if player.player_id == player_id:
			return player
	return null


func get_rankings() -> Array[PlayerState]:
	var sorted_players: Array[PlayerState] = players.duplicate()
	sorted_players.sort_custom(func(a: PlayerState, b: PlayerState) -> bool:
		return a.score > b.score
	)
	return sorted_players


func clear_bids() -> void:
	bids.clear()
