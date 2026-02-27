class_name RandomStrategy
extends AIStrategy
## Lv0: ランダム投資家 — 完全ランダムで入札


func decide(_game_state: GameState, player: PlayerState) -> int:
	var values: Array[int] = _get_available_values(player)
	if values.is_empty():
		return -1
	return values[randi() % values.size()]
