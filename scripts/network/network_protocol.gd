class_name NetworkProtocol
## メッセージ型定義（サーバーと同期）

# クライアント → サーバー
const CREATE_ROOM: String = "create_room"
const JOIN_ROOM: String = "join_room"
const AUTO_MATCH: String = "auto_match"
const CANCEL_MATCH: String = "cancel_match"
const ADD_AI: String = "add_ai"
const REMOVE_AI: String = "remove_ai"
const START_GAME: String = "start_game"
const SUBMIT_BID: String = "submit_bid"
const LEAVE: String = "leave"

# サーバー → クライアント
const ROOM_CREATED: String = "room_created"
const ROOM_JOINED: String = "room_joined"
const PLAYER_JOINED: String = "player_joined"
const PLAYER_LEFT: String = "player_left"
const GAME_START: String = "game_start"
const ROUND_START: String = "round_start"
const BID_RECEIVED: String = "bid_received"
const BIDS_REVEALED: String = "bids_revealed"
const CARDS_AWARDED: String = "cards_awarded"
const CARDS_CARRIED: String = "cards_carried"
const GAME_OVER: String = "game_over"
const ERROR: String = "error"
const MATCH_FOUND: String = "match_found"
const ROOM_UPDATE: String = "room_update"
const PLAYER_DISCONNECTED: String = "player_disconnected"
