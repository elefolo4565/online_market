// セカンダリーマーケット WebSocketサーバー
const { WebSocketServer } = require('ws');
const { RoomManager } = require('./room_manager');
const { ClientMsg } = require('./protocol');

const PORT = process.env.PORT || 8080;
const roomManager = new RoomManager();

const wss = new WebSocketServer({ port: PORT });

console.log(`セカンダリーマーケット サーバー起動: ポート ${PORT}`);

wss.on('connection', (ws) => {
  console.log('クライアント接続');

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch (e) {
      return;
    }

    const { type } = msg;

    switch (type) {
      case ClientMsg.CREATE_ROOM:
        roomManager.createRoom(
          ws,
          msg.player_name || 'プレイヤー',
          msg.player_count || 3,
          msg.ai_difficulty || 1
        );
        break;

      case ClientMsg.JOIN_ROOM:
        roomManager.joinRoom(ws, msg.room_code || '', msg.player_name || 'プレイヤー');
        break;

      case ClientMsg.AUTO_MATCH:
        roomManager.joinAutoMatch(ws, msg.player_name || 'プレイヤー', msg.player_count || 3);
        break;

      case ClientMsg.CANCEL_MATCH:
        roomManager.cancelAutoMatch(ws);
        break;

      case ClientMsg.ADD_AI:
        roomManager.addAI(ws, msg.ai_difficulty || 1);
        break;

      case ClientMsg.REMOVE_AI:
        roomManager.removeAI(ws);
        break;

      case ClientMsg.START_GAME:
        roomManager.startGame(ws);
        break;

      case ClientMsg.SUBMIT_BID:
        roomManager.submitBid(ws, msg.card_value);
        break;

      case ClientMsg.LEAVE:
        roomManager.handleLeave(ws);
        break;

      default:
        console.log('不明なメッセージ:', type);
    }
  });

  ws.on('close', () => {
    console.log('クライアント切断');
    roomManager.handleDisconnect(ws);
  });

  ws.on('error', (err) => {
    console.error('WebSocketエラー:', err.message);
    roomManager.handleDisconnect(ws);
  });
});

// 定期的に空ルームをクリーンアップ
setInterval(() => {
  for (const [code, room] of roomManager.rooms) {
    const humanCount = [...room.players.values()].filter(p => !p.is_ai).length;
    if (humanCount === 0) {
      if (room.bidTimer) clearTimeout(room.bidTimer);
      roomManager.rooms.delete(code);
    }
  }
}, 60000);
