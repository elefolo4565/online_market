// ラウンド判定ロジック（GDScriptから移植）

/**
 * @param {Object} bids - {playerId: cardValue}
 * @param {Object} stockCard - {type, value, display_name}
 * @param {Object[]} carriedOver - 持ち越しカード配列
 * @returns {Object} result
 */
function resolve(bids, stockCard, carriedOver) {
  const result = {
    winner_id: -1,
    awarded_cards: [],
    is_carried_over: false,
    batted_values: [],
    all_bids: { ...bids },
  };

  // バッティング検出: 同じ値を出したプレイヤーを除外
  const valueCounts = {};
  for (const [pid, val] of Object.entries(bids)) {
    valueCounts[val] = (valueCounts[val] || []);
    valueCounts[val].push(Number(pid));
  }

  const validBids = {};
  const battedValues = [];
  for (const [val, pids] of Object.entries(valueCounts)) {
    if (pids.length > 1) {
      battedValues.push(Number(val));
    } else {
      validBids[pids[0]] = Number(val);
    }
  }
  result.batted_values = battedValues;

  // 有効な入札がなければ持ち越し
  if (Object.keys(validBids).length === 0) {
    result.is_carried_over = true;
    return result;
  }

  // 勝者決定
  let winnerId = -1;
  let winnerVal = null;

  if (stockCard.value > 0) {
    // プラスカード: 最大入札者が獲得
    for (const [pid, val] of Object.entries(validBids)) {
      if (winnerVal === null || val > winnerVal) {
        winnerId = Number(pid);
        winnerVal = val;
      }
    }
  } else {
    // マイナスカード: 最小入札者が引き取る
    for (const [pid, val] of Object.entries(validBids)) {
      if (winnerVal === null || val < winnerVal) {
        winnerId = Number(pid);
        winnerVal = val;
      }
    }
  }

  result.winner_id = winnerId;
  result.awarded_cards = [stockCard, ...carriedOver];
  return result;
}

module.exports = { resolve };
