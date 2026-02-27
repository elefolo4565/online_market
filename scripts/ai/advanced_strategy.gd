class_name AdvancedStrategy
extends AIStrategy
## Lv2: カリスマ投資家 — 相手の手札を追跡、バッティング回避を重視
## 各インスタンスが異なる「性格」を持ち、複数AI同士のバッティングを軽減

## 性格パラメータ（インスタンスごとにランダム生成）
var _aggression: float    ## 攻撃性: 高いほどプラスカードに強気で入札 (0.5〜1.5)
var _caution: float       ## 慎重さ: 高いほどバッティング回避を重視 (0.3〜1.0)
var _efficiency: float    ## 効率重視: 高いほど手札温存を優先 (0.1〜0.5)
var _noise: float         ## 揺らぎ幅: 判断にランダム性を加える (0.0〜0.3)


func _init() -> void:
	_randomize_personality()


func _randomize_personality() -> void:
	_aggression = randf_range(0.5, 1.5)
	_caution = randf_range(0.3, 1.0)
	_efficiency = randf_range(0.1, 0.5)
	_noise = randf_range(0.05, 0.3)


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
		var noise_offset: float = randf_range(-_noise, _noise) * absf(position_value + 1.0)
		var total_score: float = position_value * (1.0 - batting_risk * _caution) + noise_offset
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
		# 攻撃性が高い→高い手札をより高く評価、効率重視→温存コストを重く見る
		return hand_ratio * abs_stock * _aggression - float(bid_value) * _efficiency
	else:
		# マイナスカード: 慎重な性格ほど高い手札で回避しようとする
		return (1.0 - hand_ratio) * abs_stock + float(bid_value) * _efficiency * _caution
