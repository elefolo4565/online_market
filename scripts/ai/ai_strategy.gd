class_name AIStrategy
extends RefCounted
## レベル(1-10)ベースの統合AI戦略
## レベルからパラメータを算出し、個体差ランダムを加える

var level: int = 5

## 性格パラメータ（level + 個体差から算出）
var _skill: float         ## 評価精度 (0.0=ランダム 〜 1.0=最適)
var _noise: float         ## 判断のブレ幅
var _caution: float       ## バッティング回避度
var _aggression: float    ## プラスカードへの強気度
var _efficiency: float    ## 手札温存度
var _opponent_awareness: float  ## 相手手札の活用度 (Lv.8+で有効)


func setup(p_level: int) -> AIStrategy:
	level = clampi(p_level, 1, 10)
	_generate_params()
	return self


func _generate_params() -> void:
	var t: float = float(level - 1) / 9.0  # 0.0 〜 1.0

	# ベースパラメータ
	var base_skill: float = t
	var base_noise: float = lerpf(0.5, 0.08, t)
	var base_caution: float = lerpf(0.0, 0.9, t * t)
	var base_aggression: float = lerpf(1.0, 1.2, t)
	var base_efficiency: float = lerpf(0.0, 0.4, t)

	# 相手手札活用: Lv.8=0.33, Lv.9=0.67, Lv.10=1.0
	var base_awareness: float = 0.0
	if level >= 8:
		base_awareness = float(level - 7) / 3.0

	# 個体差（レベルが低いほど振れ幅大、最低0.08を保証）
	var variation: float = maxf((1.0 - t) * 0.3, 0.08)
	_skill = clampf(base_skill + randf_range(-variation, variation), 0.0, 1.0)
	_noise = maxf(base_noise + randf_range(-variation * 0.5, variation * 0.5), 0.01)
	_caution = clampf(base_caution + randf_range(-variation, variation), 0.0, 1.0)
	_aggression = maxf(base_aggression + randf_range(-variation, variation), 0.3)
	_efficiency = clampf(base_efficiency + randf_range(-variation * 0.5, variation * 0.5), 0.0, 0.6)
	_opponent_awareness = clampf(base_awareness, 0.0, 1.0)


func decide(game_state: GameState, player: PlayerState) -> int:
	var values: Array[int] = player.get_hand_values()
	if values.is_empty():
		return -1

	var stock_value: int = game_state.current_stock_card.value

	# 他プレイヤーの残り手札を取得
	var opponents_hands: Array[Array] = []
	for ps: PlayerState in game_state.players:
		if ps.player_id != player.player_id:
			opponents_hands.append(ps.get_hand_values())

	# 持ち越しボーナス（カード価値合計ベース）
	var carried_bonus: float = 0.0
	for card: CardData in game_state.carried_over_cards:
		carried_bonus += absf(float(card.value))
	carried_bonus *= 1.5

	var abs_stock: float = absf(float(stock_value)) + carried_bonus

	# 各手札のスコアを計算
	var best_val: int = values[0]
	var best_score: float = -999.0

	for val: int in values:
		# 戦略的スコア
		var strategic_score: float = _evaluate(val, stock_value, abs_stock, opponents_hands)

		# ランダムスコア（完全ランダム）
		var random_score: float = randf()

		# skillでブレンド: skill=0で完全ランダム、skill=1で計算通り
		var blended: float = lerpf(random_score, strategic_score, _skill)

		if blended > best_score:
			best_score = blended
			best_val = val

	return best_val


func _evaluate(bid_value: int, stock_value: int, abs_stock: float, opponents_hands: Array[Array]) -> float:
	var hand_ratio: float = float(bid_value) / 15.0

	# ポジション評価
	var position_value: float
	if stock_value > 0:
		position_value = hand_ratio * abs_stock * _aggression - float(bid_value) * _efficiency
	else:
		# マイナスカード: 最小入札を避けつつ高カードの浪費も抑える
		# hand_ratio 0.6付近にピークを作り、自然な分散を促す
		var safety: float = hand_ratio * abs_stock * _caution
		var waste: float = maxf(hand_ratio - 0.6, 0.0) * abs_stock * _efficiency * 3.0
		position_value = safety - waste

	# バッティングリスク
	var batting_risk: float = _estimate_batting_risk(bid_value, opponents_hands)

	# 高得点プラスカードではバッティングリスクを受け入れて積極的に入札する
	var effective_caution: float = _caution
	if stock_value > 0:
		var value_factor: float = minf(abs_stock / 10.0, 1.0)
		effective_caution = _caution * (1.0 - value_factor * 0.7)

	# ノイズ（マイナスカードでは分散を大きくしてバッティングを減らす）
	var noise_mult: float = 2.5 if stock_value < 0 else 1.0
	var noise_offset: float = randf_range(-_noise * noise_mult, _noise * noise_mult) * abs_stock

	# 最終スコア
	return position_value * (1.0 - batting_risk * effective_caution) + noise_offset


func _estimate_batting_risk(value: int, opponents_hands: Array[Array]) -> float:
	if opponents_hands.is_empty():
		return 0.0

	if _opponent_awareness > 0.0:
		# 相手の手札を実際に確認してリスク計算
		var count: int = 0
		for opp_hand: Array in opponents_hands:
			if opp_hand.has(value):
				count += 1
		var actual_risk: float = float(count) / float(opponents_hands.size())
		# awarenessで実際のリスクと推定リスクをブレンド
		var estimated_risk: float = 1.0 / float(opponents_hands.size() + 1)
		return lerpf(estimated_risk, actual_risk, _opponent_awareness)
	else:
		# 相手の手札不明: 全員が均等に持っていると仮定
		return 1.0 / float(opponents_hands.size() + 1)


## デバッグ用パラメータ情報
func get_params_info() -> String:
	return "skill=%.2f noise=%.2f caution=%.2f aggr=%.2f eff=%.2f aware=%.2f" % [
		_skill, _noise, _caution, _aggression, _efficiency, _opponent_awareness
	]
