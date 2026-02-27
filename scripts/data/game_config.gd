class_name GameConfig
extends RefCounted
## ゲーム設定定数

const MIN_PLAYERS: int = 3
const MAX_PLAYERS: int = 6
const TOTAL_ROUNDS: int = 15
const BID_CARD_MIN: int = 1
const BID_CARD_MAX: int = 15
const STOCK_CARD_MIN: int = 1
const STOCK_CARD_MAX: int = 10
const VULTURE_CARD_MIN: int = -5
const VULTURE_CARD_MAX: int = -1

## AI思考時間（秒）
const AI_THINK_TIME_MIN: float = 0.5
const AI_THINK_TIME_MAX: float = 1.5
