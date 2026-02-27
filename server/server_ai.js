// サーバーサイドAI（GDScriptから移植）

/**
 * AI入札を決定する
 * @param {number} difficulty - 0:ランダム, 1:堅実, 2:カリスマ
 * @param {number[]} hand - 残り手札の値配列
 * @param {Object} stockCard - {type, value}
 * @param {Object[]} carriedOver - 持ち越しカード
 * @param {Object} gameInfo - 追加情報 {playerCount, otherPlayersHands}
 * @param {Object} [personality] - カリスマAI用の性格パラメータ
 * @returns {number} 入札値
 */
function decideBid(difficulty, hand, stockCard, carriedOver, gameInfo, personality) {
  if (hand.length === 0) return -1;

  switch (difficulty) {
    case 0: return randomStrategy(hand);
    case 1: return basicStrategy(hand, stockCard, carriedOver);
    case 2: return advancedStrategy(hand, stockCard, carriedOver, gameInfo, personality);
    default: return randomStrategy(hand);
  }
}

/**
 * カリスマAI用の性格パラメータを生成する
 * @returns {Object} {aggression, caution, efficiency, noise}
 */
function generatePersonality() {
  return {
    aggression: 0.5 + Math.random(),        // 0.5〜1.5
    caution: 0.3 + Math.random() * 0.7,     // 0.3〜1.0
    efficiency: 0.1 + Math.random() * 0.4,  // 0.1〜0.5
    noise: 0.05 + Math.random() * 0.25,     // 0.05〜0.3
  };
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

function advancedStrategy(hand, stockCard, carriedOver, gameInfo, personality) {
  const p = personality || generatePersonality();
  const sorted = [...hand].sort((a, b) => a - b);
  const carriedBonus = carriedOver.reduce((sum, c) => sum + Math.abs(c.value), 0);
  const absStock = Math.abs(stockCard.value) + carriedBonus * 1.5;

  // 他プレイヤーの残り手札からバッティング確率を推定
  const otherHands = gameInfo.otherPlayersHands || [];

  let bestCard = sorted[0];
  let bestScore = -Infinity;

  for (const card of sorted) {
    const handRatio = card / 15;

    // ポジション評価（性格パラメータで重み付け）
    let positionValue;
    if (stockCard.value > 0) {
      positionValue = handRatio * absStock * p.aggression - card * p.efficiency;
    } else {
      positionValue = (1 - handRatio) * absStock + card * p.efficiency * p.caution;
    }

    // バッティングリスク
    let battingCount = 0;
    for (const h of otherHands) {
      if (h.includes(card)) battingCount++;
    }
    const battingRisk = otherHands.length > 0
      ? battingCount / otherHands.length
      : 0.1;

    // ノイズ付きスコア
    const noiseOffset = (Math.random() * 2 - 1) * p.noise * (Math.abs(positionValue) + 1);
    const score = positionValue * (1.0 - battingRisk * p.caution) + noiseOffset;

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

module.exports = { decideBid, generatePersonality, getAIName, getDifficultyName };
