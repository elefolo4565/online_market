// サーバーサイドAI（GDScriptから移植）

/**
 * AI入札を決定する
 * @param {number} difficulty - 0:ランダム, 1:堅実, 2:カリスマ
 * @param {number[]} hand - 残り手札の値配列
 * @param {Object} stockCard - {type, value}
 * @param {Object[]} carriedOver - 持ち越しカード
 * @param {Object} gameInfo - 追加情報 {playerCount, otherPlayersHands}
 * @returns {number} 入札値
 */
function decideBid(difficulty, hand, stockCard, carriedOver, gameInfo) {
  if (hand.length === 0) return -1;

  switch (difficulty) {
    case 0: return randomStrategy(hand);
    case 1: return basicStrategy(hand, stockCard, carriedOver);
    case 2: return advancedStrategy(hand, stockCard, carriedOver, gameInfo);
    default: return randomStrategy(hand);
  }
}

function randomStrategy(hand) {
  return hand[Math.floor(Math.random() * hand.length)];
}

function basicStrategy(hand, stockCard, carriedOver) {
  const sorted = [...hand].sort((a, b) => a - b);
  const stockValue = Math.abs(stockCard.value);
  const carriedBonus = carriedOver.reduce((sum, c) => sum + Math.abs(c.value), 0);
  const effectiveValue = stockValue + carriedBonus;

  // 実効価値に応じたカード位置を決定（15段階中何番目を出すか）
  const ratio = Math.min(effectiveValue / 15, 1.0);
  // ランダム性を加味
  const jitter = (Math.random() - 0.5) * 0.2;
  const adjustedRatio = Math.max(0, Math.min(1, ratio + jitter));

  let index;
  if (stockCard.value > 0) {
    // プラスカード: 高い値を出したい
    index = Math.floor(adjustedRatio * (sorted.length - 1));
  } else {
    // マイナスカード: 低い値は出したくない → 中〜高めを出す
    index = Math.floor((0.3 + adjustedRatio * 0.7) * (sorted.length - 1));
  }

  return sorted[Math.min(index, sorted.length - 1)];
}

function advancedStrategy(hand, stockCard, carriedOver, gameInfo) {
  const sorted = [...hand].sort((a, b) => a - b);
  const stockValue = Math.abs(stockCard.value);
  const carriedBonus = carriedOver.reduce((sum, c) => sum + Math.abs(c.value), 0);
  const effectiveValue = stockValue + carriedBonus;

  // 他プレイヤーの残り手札からバッティング確率を推定
  const otherHands = gameInfo.otherPlayersHands || [];
  const otherCardCounts = {};
  for (const h of otherHands) {
    for (const v of h) {
      otherCardCounts[v] = (otherCardCounts[v] || 0) + 1;
    }
  }

  let bestCard = sorted[0];
  let bestScore = -Infinity;

  for (const card of sorted) {
    // ポジション評価
    let positionValue;
    const ratio = effectiveValue / 15;
    if (stockCard.value > 0) {
      positionValue = (card / 15) * ratio;
    } else {
      // マイナスカード: 中間の値が安全
      const midDist = Math.abs(card - 8) / 7;
      positionValue = midDist * 0.5 + (1 - card / 15) * 0.3;
    }

    // バッティングリスク
    const battingCount = otherCardCounts[card] || 0;
    const battingRisk = otherHands.length > 0
      ? battingCount / otherHands.length
      : 0.1;

    const score = positionValue * (1.0 - battingRisk * 0.7);

    if (score > bestScore) {
      bestScore = score;
      bestCard = card;
    }
  }

  return bestCard;
}

// AI名プール
const AI_NAMES = ['田中', '鈴木', '佐藤', '山本', '渡辺', '伊藤', '中村', '小林', '加藤', '吉田'];

function getAIName(usedNames) {
  const available = AI_NAMES.filter(n => !usedNames.includes(n));
  if (available.length === 0) return 'AI_' + Math.floor(Math.random() * 100);
  return available[Math.floor(Math.random() * available.length)];
}

function getDifficultyName(level) {
  switch (level) {
    case 0: return 'ランダム投資家';
    case 1: return '堅実投資家';
    case 2: return 'カリスマ投資家';
    default: return '投資家';
  }
}

module.exports = { decideBid, getAIName, getDifficultyName };
