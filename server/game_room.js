// 1ルームのゲーム進行管理
const { ServerMsg, GameConfig, makeCard } = require('./protocol');
const { resolve } = require('./round_resolver');
const { decideBid, createAIParams, getAIName, getDifficultyName } = require('./server_ai');

const Phase = {
  WAITING: 'waiting',
  PLAYING: 'playing',
  ROUND_BIDDING: 'round_bidding',
  ROUND_RESOLVING: 'round_resolving',
  FINISHED: 'finished',
};

class GameRoom {
  constructor(roomCode, hostId, playerCount, aiDifficulty) {
    this.roomCode = roomCode;
    this.hostId = hostId;
    this.maxPlayers = playerCount;
    this.aiDifficulty = aiDifficulty;
    this.phase = Phase.WAITING;

    // プレイヤー管理 {id: {id, name, is_ai, ws, hand[], acquired[], score, ai_difficulty}}
    this.players = new Map();
    this.nextPlayerId = 0;

    // ゲーム状態
    this.stockDeck = [];
    this.currentStockCard = null;
    this.carriedOverCards = [];
    this.currentRound = 0;
    this.bids = {};
    this.bidTimer = null;
  }

  // --- ルーム管理 ---

  addPlayer(name, ws) {
    if (this.players.size >= this.maxPlayers) return null;
    if (this.phase !== Phase.WAITING) return null;

    const id = this.nextPlayerId++;
    this.players.set(id, {
      id, name, is_ai: false, ws,
      hand: [], acquired_cards: [], score: 0, ai_difficulty: 0,
    });
    return id;
  }

  addAI(difficulty) {
    if (this.players.size >= this.maxPlayers) return null;
    if (this.phase !== Phase.WAITING) return null;

    const usedNames = [...this.players.values()].map(p => p.name);
    const name = getAIName(usedNames);
    const id = this.nextPlayerId++;
    this.players.set(id, {
      id, name, is_ai: true, ws: null,
      hand: [], acquired_cards: [], score: 0, ai_difficulty: difficulty,
      ai_params: createAIParams(difficulty),
    });
    return id;
  }

  removePlayer(playerId) {
    const player = this.players.get(playerId);
    if (!player) return;

    if (this.phase === Phase.WAITING) {
      this.players.delete(playerId);
    } else {
      // ゲーム中の切断 → AIに置換
      player.is_ai = true;
      player.ws = null;
      player.ai_difficulty = 5;
      player.ai_params = createAIParams(5);

      // 入札フェーズで未入札なら即座にAI入札
      if (this.phase === Phase.ROUND_BIDDING && this.bids[playerId] === undefined) {
        if (player.hand.length > 0) {
          const cardValue = decideBid(
            player.ai_difficulty,
            player.hand,
            this.currentStockCard,
            this.carriedOverCards,
            { playerCount: this.players.size, otherPlayersHands: [] },
            player.ai_params
          );
          this.bids[playerId] = cardValue;
          this._broadcast(ServerMsg.BID_RECEIVED, { player_id: playerId });
          this._checkAllBids();
        }
      }
    }
  }

  getPlayerList() {
    return [...this.players.values()].map(p => ({
      id: p.id,
      name: p.name,
      is_ai: p.is_ai,
    }));
  }

  // --- ゲーム進行 ---

  startGame() {
    if (this.players.size < GameConfig.MIN_PLAYERS) return false;
    if (this.phase !== Phase.WAITING) return false;

    this.phase = Phase.PLAYING;
    this._initDeck();
    this._initHands();

    // AIのパラメータをデバッグ出力
    for (const [pid, player] of this.players) {
      if (player.is_ai && player.ai_params) {
        const p = player.ai_params;
        console.log(`[AI] ${player.name} (id=${pid}) : ${getDifficultyName(player.ai_difficulty)} | skill=${p.skill.toFixed(2)} noise=${p.noise.toFixed(2)} caution=${p.caution.toFixed(2)} aggr=${p.aggression.toFixed(2)} eff=${p.efficiency.toFixed(2)} aware=${p.opponentAwareness.toFixed(2)}`);
      }
    }

    // 各プレイヤーにゲーム開始を通知
    for (const [pid, player] of this.players) {
      if (!player.is_ai && player.ws) {
        this._send(player.ws, ServerMsg.GAME_START, {
          players: this.getPlayerList(),
          your_hand: player.hand.map(v => v),
          your_id: pid,
        });
      }
    }

    // 最初のラウンド開始
    setTimeout(() => this._startRound(), 500);
    return true;
  }

  submitBid(playerId, cardValue) {
    if (this.phase !== Phase.ROUND_BIDDING) return false;

    const player = this.players.get(playerId);
    if (!player || player.is_ai) return false;
    if (this.bids[playerId] !== undefined) return false; // 二重入札防止
    if (!player.hand.includes(cardValue)) return false; // 手札にないカード

    this.bids[playerId] = cardValue;

    // 入札受付を全員に通知（値は非公開）
    this._broadcast(ServerMsg.BID_RECEIVED, { player_id: playerId });

    // 全員入札完了チェック
    this._checkAllBids();
    return true;
  }

  // --- 内部処理 ---

  _initDeck() {
    this.stockDeck = [];
    for (let i = GameConfig.STOCK_CARD_MIN; i <= GameConfig.STOCK_CARD_MAX; i++) {
      this.stockDeck.push(makeCard(i));
    }
    for (let i = GameConfig.VULTURE_CARD_MIN; i <= GameConfig.VULTURE_CARD_MAX; i++) {
      this.stockDeck.push(makeCard(i));
    }
    // シャッフル
    for (let i = this.stockDeck.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.stockDeck[i], this.stockDeck[j]] = [this.stockDeck[j], this.stockDeck[i]];
    }
  }

  _initHands() {
    for (const player of this.players.values()) {
      player.hand = [];
      for (let i = GameConfig.BID_CARD_MIN; i <= GameConfig.BID_CARD_MAX; i++) {
        player.hand.push(i);
      }
      player.acquired_cards = [];
      player.score = 0;
    }
  }

  _startRound() {
    if (this.stockDeck.length === 0) {
      this._endGame();
      return;
    }

    this.currentRound++;
    this.currentStockCard = this.stockDeck.pop();
    this.bids = {};
    this.phase = Phase.ROUND_BIDDING;

    // ラウンド開始を通知
    this._broadcast(ServerMsg.ROUND_START, {
      round: this.currentRound,
      stock_card: this.currentStockCard,
      carried_count: this.carriedOverCards.length,
    });

    // AI入札をスケジュール
    this._scheduleAIBids();

    // 入札タイムアウト設定
    this.bidTimer = setTimeout(() => this._onBidTimeout(), GameConfig.BID_TIMEOUT_MS);
  }

  _scheduleAIBids() {
    for (const player of this.players.values()) {
      if (!player.is_ai) continue;

      const delay = GameConfig.AI_THINK_TIME_MIN +
        Math.random() * (GameConfig.AI_THINK_TIME_MAX - GameConfig.AI_THINK_TIME_MIN);

      setTimeout(() => {
        if (this.phase !== Phase.ROUND_BIDDING) return;
        if (this.bids[player.id] !== undefined) return;

        // 他プレイヤーの手札情報を収集（高レベルAI用）
        const otherHands = [];
        for (const p of this.players.values()) {
          if (p.id !== player.id) {
            otherHands.push([...p.hand]);
          }
        }

        const cardValue = decideBid(
          player.ai_difficulty,
          player.hand,
          this.currentStockCard,
          this.carriedOverCards,
          { playerCount: this.players.size, otherPlayersHands: otherHands },
          player.ai_params
        );

        this.bids[player.id] = cardValue;
        this._broadcast(ServerMsg.BID_RECEIVED, { player_id: player.id });
        this._checkAllBids();
      }, delay);
    }
  }

  _onBidTimeout() {
    // タイムアウト: 未入札の人間プレイヤーにランダム入札
    for (const player of this.players.values()) {
      if (player.is_ai) continue;
      if (this.bids[player.id] !== undefined) continue;

      const randomCard = player.hand[Math.floor(Math.random() * player.hand.length)];
      this.bids[player.id] = randomCard;
      this._broadcast(ServerMsg.BID_RECEIVED, { player_id: player.id });
    }
    this._checkAllBids();
  }

  _checkAllBids() {
    // 全員入札済みかチェック
    for (const player of this.players.values()) {
      if (this.bids[player.id] === undefined) return;
    }

    // タイマーキャンセル
    if (this.bidTimer) {
      clearTimeout(this.bidTimer);
      this.bidTimer = null;
    }

    this._resolveRound();
  }

  _resolveRound() {
    this.phase = Phase.ROUND_RESOLVING;

    // 手札からカードを消費
    for (const [pid, val] of Object.entries(this.bids)) {
      const player = this.players.get(Number(pid));
      if (player) {
        player.hand = player.hand.filter(v => v !== val);
      }
    }

    // 判定
    const result = resolve(this.bids, this.currentStockCard, this.carriedOverCards);

    // 全入札を公開
    this._broadcast(ServerMsg.BIDS_REVEALED, {
      all_bids: result.all_bids,
      batted_values: result.batted_values,
      winner_id: result.winner_id,
      is_carried_over: result.is_carried_over,
    });

    // 結果を適用
    setTimeout(() => {
      if (result.is_carried_over) {
        this.carriedOverCards.push(this.currentStockCard);
        this._broadcast(ServerMsg.CARDS_CARRIED, {
          carried_cards: this.carriedOverCards.map(c => ({ value: c.value, display_name: c.display_name })),
        });
      } else {
        const winner = this.players.get(result.winner_id);
        if (winner) {
          for (const card of result.awarded_cards) {
            winner.acquired_cards.push(card);
            winner.score += card.value;
          }
        }

        // スコア情報を収集
        const scores = {};
        for (const [pid, p] of this.players) {
          scores[pid] = p.score;
        }

        this._broadcast(ServerMsg.CARDS_AWARDED, {
          player_id: result.winner_id,
          cards: result.awarded_cards.map(c => ({ value: c.value, display_name: c.display_name })),
          scores,
        });

        this.carriedOverCards = [];
      }

      // 次ラウンドまたはゲーム終了
      setTimeout(() => {
        if (this.currentRound >= GameConfig.TOTAL_ROUNDS) {
          this._endGame();
        } else {
          this._startRound();
        }
      }, 2000);
    }, 1500);
  }

  _endGame() {
    this.phase = Phase.FINISHED;

    // ランキング作成
    const rankings = [...this.players.values()]
      .sort((a, b) => b.score - a.score)
      .map(p => ({
        id: p.id,
        name: p.name,
        score: p.score,
        is_ai: p.is_ai,
      }));

    this._broadcast(ServerMsg.GAME_OVER, { rankings });
  }

  // --- 通信 ---

  _send(ws, type, data) {
    try {
      ws.send(JSON.stringify({ type, ...data }));
    } catch (e) {
      // 切断済み
    }
  }

  _broadcast(type, data) {
    for (const player of this.players.values()) {
      if (!player.is_ai && player.ws) {
        this._send(player.ws, type, data);
      }
    }
  }
}

module.exports = { GameRoom, Phase };
