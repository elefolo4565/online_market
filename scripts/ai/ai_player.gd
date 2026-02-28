class_name AIPlayer
extends RefCounted
## AIコントローラー — レベル(1-10)に応じた戦略で入札を決定

var difficulty: int = 5  ## 1〜10
var _strategy: AIStrategy = null


func decide_bid(game_state: GameState, player: PlayerState) -> int:
	_ensure_strategy()
	return _strategy.decide(game_state, player)


func _ensure_strategy() -> void:
	if _strategy != null:
		return
	_strategy = AIStrategy.new().setup(difficulty)


func get_personality_info() -> String:
	_ensure_strategy()
	return _strategy.get_params_info()


static func get_difficulty_name(level: int) -> String:
	return "Lv." + str(level)
