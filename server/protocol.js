// メッセージ型定義
// クライアント → サーバー
const ClientMsg = {
  CREATE_ROOM: 'create_room',
  JOIN_ROOM: 'join_room',
  AUTO_MATCH: 'auto_match',
  CANCEL_MATCH: 'cancel_match',
  ADD_AI: 'add_ai',
  REMOVE_AI: 'remove_ai',
  START_GAME: 'start_game',
  SUBMIT_BID: 'submit_bid',
  LEAVE: 'leave',
};

// サーバー → クライアント
const ServerMsg = {
  ROOM_CREATED: 'room_created',
  ROOM_JOINED: 'room_joined',
  PLAYER_JOINED: 'player_joined',
  PLAYER_LEFT: 'player_left',
  GAME_START: 'game_start',
  ROUND_START: 'round_start',
  BID_RECEIVED: 'bid_received',
  BIDS_REVEALED: 'bids_revealed',
  CARDS_AWARDED: 'cards_awarded',
  CARDS_CARRIED: 'cards_carried',
  GAME_OVER: 'game_over',
  ERROR: 'error',
  MATCH_FOUND: 'match_found',
  ROOM_UPDATE: 'room_update',
};

// ゲーム定数
const GameConfig = {
  MIN_PLAYERS: 3,
  MAX_PLAYERS: 6,
  TOTAL_ROUNDS: 15,
  BID_CARD_MIN: 1,
  BID_CARD_MAX: 15,
  STOCK_CARD_MIN: 1,
  STOCK_CARD_MAX: 10,
  VULTURE_CARD_MIN: -5,
  VULTURE_CARD_MAX: -1,
  BID_TIMEOUT_MS: 30000,
  AI_THINK_TIME_MIN: 500,
  AI_THINK_TIME_MAX: 1500,
};

// 銘柄カード名
const STOCK_NAMES = {
  1: '町工場株', 2: '地方銀行株', 3: '食品メーカー株', 4: '不動産株',
  5: '自動車株', 6: '電機メーカー株', 7: '製薬会社株', 8: '通信大手株',
  9: '半導体株', 10: 'AI企業株',
};
const VULTURE_NAMES = {
  '-1': '業績下方修正', '-2': '粉飾決算', '-3': 'リコール発覚',
  '-4': '経営破綻', '-5': '上場廃止',
};

function makeCard(value) {
  if (value > 0) {
    return { type: 'stock', value, display_name: STOCK_NAMES[value] || `株${value}` };
  } else {
    return { type: 'vulture', value, display_name: VULTURE_NAMES[String(value)] || `暴落${value}` };
  }
}

function makeBidCard(value) {
  return { type: 'bid', value, display_name: `${value}億` };
}

module.exports = { ClientMsg, ServerMsg, GameConfig, makeCard, makeBidCard };
