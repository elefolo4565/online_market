class_name AIStrategy
extends RefCounted
## AI戦略の基底クラス


func decide(_game_state: GameState, _player: PlayerState) -> int:
	push_error("AIStrategy.decide() must be overridden")
	return -1


func _get_available_values(player: PlayerState) -> Array[int]:
	return player.get_hand_values()
