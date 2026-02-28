// ルーム管理・自動マッチング
const { GameRoom } = require('./game_room');
const { ServerMsg, GameConfig } = require('./protocol');

// ルームコード用数字文字セット
const CODE_CHARS = '0123456789';

class RoomManager {
  constructor() {
    this.rooms = new Map();        // roomCode -> GameRoom
    this.playerRooms = new Map();  // ws -> roomCode
    this.matchQueue = [];          // [{ws, playerName, playerCount}]
  }

  generateCode() {
    let code;
    do {
      code = '';
      for (let i = 0; i < 6; i++) {
        code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
      }
    } while (this.rooms.has(code));
    return code;
  }

  createRoom(ws, playerName, playerCount, aiDifficulty) {
    const code = this.generateCode();
    const room = new GameRoom(code, null, playerCount, aiDifficulty);
    const playerId = room.addPlayer(playerName, ws);
    room.hostId = playerId;
    this.rooms.set(code, room);
    this.playerRooms.set(ws, code);

    this._send(ws, ServerMsg.ROOM_CREATED, {
      room_code: code,
      player_id: playerId,
      players: room.getPlayerList(),
    });

    return room;
  }

  joinRoom(ws, roomCode, playerName) {
    const room = this.rooms.get(roomCode.toUpperCase());
    if (!room) {
      this._send(ws, ServerMsg.ERROR, { message: 'ルームが見つかりません' });
      return null;
    }

    const playerId = room.addPlayer(playerName, ws);
    if (playerId === null) {
      this._send(ws, ServerMsg.ERROR, { message: 'ルームが満員です' });
      return null;
    }

    this.playerRooms.set(ws, roomCode.toUpperCase());

    // 参加者に通知
    this._send(ws, ServerMsg.ROOM_JOINED, {
      room_code: room.roomCode,
      player_id: playerId,
      players: room.getPlayerList(),
    });

    // 他のプレイヤーに通知
    room._broadcast(ServerMsg.PLAYER_JOINED, {
      player_id: playerId,
      player_name: playerName,
      is_ai: false,
      players: room.getPlayerList(),
    });

    return room;
  }

  addAI(ws, difficulty) {
    const code = this.playerRooms.get(ws);
    if (!code) return;
    const room = this.rooms.get(code);
    if (!room) return;

    // ホストのみ
    const hostPlayer = this._getPlayer(ws, room);
    if (!hostPlayer || hostPlayer.id !== room.hostId) {
      this._send(ws, ServerMsg.ERROR, { message: 'ホストのみがAIを追加できます' });
      return;
    }

    const aiId = room.addAI(difficulty);
    if (aiId === null) {
      this._send(ws, ServerMsg.ERROR, { message: 'これ以上プレイヤーを追加できません' });
      return;
    }

    const aiPlayer = room.players.get(aiId);
    room._broadcast(ServerMsg.PLAYER_JOINED, {
      player_id: aiId,
      player_name: aiPlayer.name,
      is_ai: true,
      players: room.getPlayerList(),
    });
  }

  removeAI(ws) {
    const code = this.playerRooms.get(ws);
    if (!code) return;
    const room = this.rooms.get(code);
    if (!room) return;

    // ホストのみ
    const hostPlayer = this._getPlayer(ws, room);
    if (!hostPlayer || hostPlayer.id !== room.hostId) return;

    // 最後に追加されたAIを削除
    let lastAI = null;
    for (const p of room.players.values()) {
      if (p.is_ai) lastAI = p;
    }
    if (!lastAI) return;

    room.players.delete(lastAI.id);
    room._broadcast(ServerMsg.PLAYER_LEFT, {
      player_id: lastAI.id,
      players: room.getPlayerList(),
    });
  }

  startGame(ws) {
    const code = this.playerRooms.get(ws);
    if (!code) return;
    const room = this.rooms.get(code);
    if (!room) return;

    // ホストのみ
    const hostPlayer = this._getPlayer(ws, room);
    if (!hostPlayer || hostPlayer.id !== room.hostId) {
      this._send(ws, ServerMsg.ERROR, { message: 'ホストのみがゲームを開始できます' });
      return;
    }

    if (room.players.size < GameConfig.MIN_PLAYERS) {
      this._send(ws, ServerMsg.ERROR, {
        message: `最低${GameConfig.MIN_PLAYERS}人必要です（現在${room.players.size}人）`,
      });
      return;
    }

    room.startGame();
  }

  submitBid(ws, cardValue) {
    const code = this.playerRooms.get(ws);
    if (!code) return;
    const room = this.rooms.get(code);
    if (!room) return;

    const player = this._getPlayer(ws, room);
    if (!player) return;

    if (!room.submitBid(player.id, cardValue)) {
      this._send(ws, ServerMsg.ERROR, { message: '入札が無効です' });
    }
  }

  // 自動マッチング
  joinAutoMatch(ws, playerName, playerCount) {
    // 既にキューにいたらキャンセル
    this.cancelAutoMatch(ws);

    this.matchQueue.push({ ws, playerName, playerCount });
    this._tryAutoMatch();
  }

  cancelAutoMatch(ws) {
    this.matchQueue = this.matchQueue.filter(e => e.ws !== ws);
  }

  _tryAutoMatch() {
    // 同じ人数設定のプレイヤーをグループ化
    const groups = {};
    for (const entry of this.matchQueue) {
      const key = entry.playerCount;
      if (!groups[key]) groups[key] = [];
      groups[key].push(entry);
    }

    for (const [countStr, entries] of Object.entries(groups)) {
      const count = Number(countStr);
      // 十分な人数が揃ったらマッチング
      if (entries.length >= count) {
        const matched = entries.slice(0, count);
        // キューから削除
        for (const m of matched) {
          this.matchQueue = this.matchQueue.filter(e => e.ws !== m.ws);
        }

        // ルーム作成
        const code = this.generateCode();
        const room = new GameRoom(code, null, count, 1);
        this.rooms.set(code, room);

        for (let i = 0; i < matched.length; i++) {
          const m = matched[i];
          const pid = room.addPlayer(m.playerName, m.ws);
          if (i === 0) room.hostId = pid;
          this.playerRooms.set(m.ws, code);

          this._send(m.ws, ServerMsg.MATCH_FOUND, { room_code: code });
          this._send(m.ws, ServerMsg.ROOM_JOINED, {
            room_code: code,
            player_id: pid,
            players: room.getPlayerList(),
          });
        }

        // 自動開始
        room.startGame();
      } else if (entries.length >= GameConfig.MIN_PLAYERS) {
        // MIN_PLAYERS以上いればAIで埋めて開始
        const matched = [...entries];
        for (const m of matched) {
          this.matchQueue = this.matchQueue.filter(e => e.ws !== m.ws);
        }

        const code = this.generateCode();
        const room = new GameRoom(code, null, count, 1);
        this.rooms.set(code, room);

        for (let i = 0; i < matched.length; i++) {
          const m = matched[i];
          const pid = room.addPlayer(m.playerName, m.ws);
          if (i === 0) room.hostId = pid;
          this.playerRooms.set(m.ws, code);

          this._send(m.ws, ServerMsg.MATCH_FOUND, { room_code: code });
          this._send(m.ws, ServerMsg.ROOM_JOINED, {
            room_code: code,
            player_id: pid,
            players: room.getPlayerList(),
          });
        }

        // AIで人数を埋める
        while (room.players.size < count) {
          room.addAI(1);
        }

        room.startGame();
      }
    }
  }

  // 切断処理
  handleDisconnect(ws) {
    // マッチングキューから削除
    this.cancelAutoMatch(ws);

    const code = this.playerRooms.get(ws);
    if (!code) return;

    const room = this.rooms.get(code);
    if (!room) return;

    const player = this._getPlayer(ws, room);
    if (!player) return;

    const wasInGame = room.phase !== 'waiting';
    room.removePlayer(player.id);
    this.playerRooms.delete(ws);

    if (wasInGame) {
      // ゲーム中の切断: AI置換を通知
      room._broadcast(ServerMsg.PLAYER_DISCONNECTED, {
        player_id: player.id,
        player_name: player.name,
        players: room.getPlayerList(),
      });
    } else {
      // ロビーでの退出
      room._broadcast(ServerMsg.PLAYER_LEFT, {
        player_id: player.id,
        players: room.getPlayerList(),
      });
    }

    // ルームが空なら削除
    const humanCount = [...room.players.values()].filter(p => !p.is_ai).length;
    if (humanCount === 0) {
      if (room.bidTimer) clearTimeout(room.bidTimer);
      this.rooms.delete(code);
    }
  }

  handleLeave(ws) {
    this.handleDisconnect(ws);
  }

  // --- ヘルパー ---

  _getPlayer(ws, room) {
    for (const player of room.players.values()) {
      if (player.ws === ws) return player;
    }
    return null;
  }

  _send(ws, type, data) {
    try {
      ws.send(JSON.stringify({ type, ...data }));
    } catch (e) {
      // 切断済み
    }
  }
}

module.exports = { RoomManager };
