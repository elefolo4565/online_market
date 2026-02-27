class_name BasicStrategy
extends AIStrategy
## Lv1: 堅実投資家 — 銘柄価値に比例した入札、多少のランダム性あり


func decide(game_state: GameState, player: PlayerState) -> int:
	var values: Array[int] = _get_available_values(player)
	if values.is_empty():
		return -1

	var stock_value: int = game_state.current_stock_card.value
	var carried_bonus: float = float(game_state.carried_over_cards.size()) * 2.0

	# 銘柄の実効価値を計算（持ち越しカード分も加味）
	var effective_value: float = absf(float(stock_value)) + carried_bonus

	if stock_value > 0:
		# プラスカード: 価値に比例して高い手札を出す
		var ratio: float = clampf(effective_value / 12.0, 0.0, 1.0)
		var target_index: int = int(ratio * float(values.size() - 1))
		target_index = clampi(target_index + randi_range(-1, 1), 0, values.size() - 1)
		return values[target_index]
	else:
		# マイナスカード: 価値に比例して高い手札で回避を試みる
		var ratio: float = clampf(effective_value / 7.0, 0.0, 1.0)
		var target_index: int = int(ratio * float(values.size() - 1))
		target_index = clampi(target_index + randi_range(-1, 1), 0, values.size() - 1)
		return values[target_index]
