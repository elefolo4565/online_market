class_name AdvancedStrategy
extends AIStrategy
## Lv2: カリスマ投資家 — 相手の手札を追跡、バッティング回避を重視


func decide(game_state: GameState, player: PlayerState) -> int:
	var values: Array[int] = _get_available_values(player)
	if values.is_empty():
		return -1

	var stock_value: int = game_state.current_stock_card.value

	# 他プレイヤーの残り手札を取得
	var opponents_hands: Array[Array] = []
	for ps: PlayerState in game_state.players:
		if ps.player_id != player.player_id:
			opponents_hands.append(ps.get_hand_values())

	# 各手札のスコアを計算
	var best_val: int = values[0]
	var best_score: float = -999.0

	for val: int in values:
		var batting_risk: float = _estimate_batting_risk(val, opponents_hands)
		var position_value: float = _evaluate_position(val, stock_value, game_state)
		var total_score: float = position_value * (1.0 - batting_risk * 0.7)
		if total_score > best_score:
			best_score = total_score
			best_val = val

	return best_val


func _estimate_batting_risk(value: int, opponents_hands: Array[Array]) -> float:
	var count: int = 0
	for opp_hand: Array in opponents_hands:
		if opp_hand.has(value):
			count += 1
	return float(count) / float(maxi(opponents_hands.size(), 1))


func _evaluate_position(bid_value: int, stock_value: int, game_state: GameState) -> float:
	var carried_bonus: float = float(game_state.carried_over_cards.size()) * 1.5
	var abs_stock: float = absf(float(stock_value)) + carried_bonus
	var hand_ratio: float = float(bid_value) / 15.0

	if stock_value > 0:
		# 高い手札ほど有利だが、コスパも考慮
		return hand_ratio * abs_stock - float(bid_value) * 0.3
	else:
		# マイナスカード: 低い手札で取らされるリスク vs 高い手札で回避
		return (1.0 - hand_ratio) * abs_stock + float(bid_value) * 0.2
