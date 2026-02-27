class_name GameManager
extends Node
## ゲーム進行制御（シグナルでUIと疎結合に接続）

signal phase_changed(new_phase: GameState.Phase)
signal stock_card_revealed(card: CardData)
signal bid_placed(player_id: int, card: CardData)
signal all_bids_revealed(result: RoundResolver.ResolveResult)
signal round_resolved(result: RoundResolver.ResolveResult)
signal cards_awarded(player_id: int, cards: Array[CardData])
signal cards_carried_over(cards: Array[CardData])
signal game_over(rankings: Array[PlayerState])

var state: GameState
var _ai_players: Dictionary = {}  ## {player_id: int -> AIPlayer}


func setup_game(player_configs: Array[Dictionary]) -> void:
	state = GameState.new()
	var player_states: Array[PlayerState] = []
	for i: int in range(player_configs.size()):
		var config: Dictionary = player_configs[i]
		var ps: PlayerState = PlayerState.new(
			i,
			config.get("name", "Player " + str(i + 1)) as String,
			config.get("is_ai", false) as bool,
			config.get("ai_difficulty", 0) as int
		)
		player_states.append(ps)
		if ps.is_ai:
			var ai: AIPlayer = AIPlayer.new()
			ai.difficulty = ps.ai_difficulty
			_ai_players[i] = ai
	# AIの性格をデバッグ出力
	for pid: Variant in _ai_players:
		var pid_int: int = pid as int
		var ai: AIPlayer = _ai_players[pid_int] as AIPlayer
		var ps: PlayerState = player_states[pid_int]
		var personality_info: String = ai.get_personality_info()
		if personality_info.is_empty():
			print("[AI] %s (id=%d) : %s" % [ps.player_name, pid_int, AIPlayer.get_difficulty_name(ai.difficulty)])
		else:
			print("[AI] %s (id=%d) : %s | %s" % [ps.player_name, pid_int, AIPlayer.get_difficulty_name(ai.difficulty), personality_info])
	state.init_game(player_states)
	_change_phase(GameState.Phase.REVEAL_STOCK)


func start_round() -> void:
	state.current_round += 1
	state.clear_bids()
	var card: CardData = state.draw_stock_card()
	if card == null:
		_end_game()
		return
	print("\n>>> ラウンド %d 開始: 銘柄=%s (値=%d)" % [state.current_round, card.display_name, card.value])
	stock_card_revealed.emit(card)
	_change_phase(GameState.Phase.BIDDING)
	_request_ai_bids()


func submit_bid(player_id: int, card_value: int) -> bool:
	if state.phase != GameState.Phase.BIDDING:
		return false
	var player: PlayerState = state.get_player(player_id)
	if player == null or not player.has_card(card_value):
		return false
	var card: CardData = player.play_card(card_value)
	if card == null:
		return false
	state.register_bid(player_id, card)
	print("  入札受付: %s (id=%d) → %d" % [player.player_name, player_id, card_value])
	bid_placed.emit(player_id, card)
	if state.all_bids_placed():
		_resolve_round()
	return true


func get_human_player_id() -> int:
	for player: PlayerState in state.players:
		if not player.is_ai:
			return player.player_id
	return -1


func _request_ai_bids() -> void:
	for pid: Variant in _ai_players:
		var pid_int: int = pid as int
		if state.phase != GameState.Phase.BIDDING:
			return
		var ai: AIPlayer = _ai_players[pid_int] as AIPlayer
		var player: PlayerState = state.get_player(pid_int)
		var bid_value: int = ai.decide_bid(state, player)
		# AI思考時間の演出
		var think_time: float = GameConfig.AI_THINK_TIME_MIN + randf() * (GameConfig.AI_THINK_TIME_MAX - GameConfig.AI_THINK_TIME_MIN)
		await get_tree().create_timer(think_time).timeout
		if not is_instance_valid(self) or state.phase != GameState.Phase.BIDDING:
			return
		submit_bid(pid_int, bid_value)


func _resolve_round() -> void:
	_change_phase(GameState.Phase.RESOLVING)
	var result: RoundResolver.ResolveResult = RoundResolver.resolve(
		state.bids, state.current_stock_card, state.carried_over_cards
	)
	all_bids_revealed.emit(result)

	if result.is_carried_over:
		state.carried_over_cards.append(state.current_stock_card)
		print(">>> 持ち越し: 累計%d枚" % state.carried_over_cards.size())
		cards_carried_over.emit(state.carried_over_cards)
	else:
		var winner: PlayerState = state.get_player(result.winner_id)
		if winner:
			winner.acquire_cards(result.awarded_cards)
			var card_vals: Array[int] = []
			for c: CardData in result.awarded_cards:
				card_vals.append(c.value)
			print(">>> 落札: %s (id=%d) がカード%sを獲得 → 合計スコア=%d" % [winner.player_name, winner.player_id, str(card_vals), winner.score])
		state.carried_over_cards.clear()
		cards_awarded.emit(result.winner_id, result.awarded_cards)

	# ラウンド履歴記録
	state.round_history.append({
		"round": state.current_round,
		"stock_card_value": state.current_stock_card.value,
		"stock_card_name": state.current_stock_card.display_name,
		"bids": result.all_bids.duplicate(),
		"winner_id": result.winner_id,
		"carried_over": result.is_carried_over,
		"batted_values": result.batted_values.duplicate(),
	})

	round_resolved.emit(result)
	_change_phase(GameState.Phase.ROUND_END)

	if state.current_round >= GameConfig.TOTAL_ROUNDS and state.stock_deck.is_empty():
		_end_game()


func _end_game() -> void:
	_change_phase(GameState.Phase.GAME_OVER)
	var rankings: Array[PlayerState] = state.get_rankings()
	game_over.emit(rankings)


func _change_phase(new_phase: GameState.Phase) -> void:
	state.phase = new_phase
	phase_changed.emit(new_phase)
