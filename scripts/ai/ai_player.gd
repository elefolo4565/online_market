class_name AIPlayer
extends RefCounted
## AI基底クラス — 難易度に応じて戦略を切り替える

var difficulty: int = 0  ## 0=ランダム, 1=堅実, 2=カリスマ
var _strategy: AIStrategy = null


func decide_bid(game_state: GameState, player: PlayerState) -> int:
	_ensure_strategy()
	return _strategy.decide(game_state, player)


func _ensure_strategy() -> void:
	if _strategy != null:
		return
	match difficulty:
		0:
			_strategy = RandomStrategy.new()
		1:
			_strategy = BasicStrategy.new()
		2:
			_strategy = AdvancedStrategy.new()
		_:
			_strategy = RandomStrategy.new()


static func get_difficulty_name(level: int) -> String:
	match level:
		0: return "ランダム投資家"
		1: return "堅実投資家"
		2: return "カリスマ投資家"
		_: return "不明"
