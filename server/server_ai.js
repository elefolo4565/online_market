// サーバーサイドAI — レベル(1-10)ベースの統合戦略

/**
 * レベルからAIパラメータを生成する（個体差ランダム付き）
 * @param {number} level - 1〜10
 * @returns {Object} AIパラメータ
 */
function createAIParams(level) {
  level = Math.max(1, Math.min(10, level));
  const t = (level - 1) / 9.0; // 0.0 〜 1.0

  const variation = Math.max((1.0 - t) * 0.3, 0.08);
  const vary = (base, v) => base + (Math.random() * 2 - 1) * v;

  return {
    level,
    skill: Math.max(0, Math.min(1, vary(t, variation))),
    noise: Math.max(0.01, lerp(0.5, 0.08, t) + (Math.random() * 2 - 1) * variation * 0.5),
    caution: Math.max(0, Math.min(1, vary(lerp(0.0, 0.9, t * t), variation))),
    aggression: Math.max(0.3, vary(lerp(1.0, 1.2, t), variation)),
    efficiency: Math.max(0, Math.min(0.6, vary(lerp(0.0, 0.4, t), variation * 0.5))),
    opponentAwareness: Math.max(0, Math.min(1, level < 8 ? 0.0 : (level - 7) / 3.0)),
  };
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

/**
 * AI入札を決定する
 * @param {number} level - 1〜10
 * @param {number[]} hand - 残り手札の値配列
 * @param {Object} stockCard - {type, value}
 * @param {Object[]} carriedOver - 持ち越しカード
 * @param {Object} gameInfo - {playerCount, otherPlayersHands}
 * @param {Object} [params] - createAIParams()で生成済みのパラメータ（省略時は自動生成）
 * @returns {number} 入札値
 */
function decideBid(level, hand, stockCard, carriedOver, gameInfo, params) {
  if (hand.length === 0) return -1;

  const p = params || createAIParams(level);
  const sorted = [...hand].sort((a, b) => a - b);

  // 持ち越しボーナス（カード価値合計ベース）
  const carriedBonus = carriedOver.reduce((sum, c) => sum + Math.abs(c.value), 0) * 1.5;
  const absStock = Math.abs(stockCard.value) + carriedBonus;

  const otherHands = gameInfo.otherPlayersHands || [];

  let bestCard = sorted[0];
  let bestScore = -Infinity;

  for (const card of sorted) {
    // 戦略的スコア
    const strategicScore = evaluate(card, stockCard.value, absStock, otherHands, p);

    // ランダムスコア
    const randomScore = Math.random();

    // skillでブレンド: skill=0で完全ランダム、skill=1で計算通り
    const blended = lerp(randomScore, strategicScore, p.skill);

    if (blended > bestScore) {
      bestScore = blended;
      bestCard = card;
    }
  }

  return bestCard;
}

function evaluate(bidValue, stockValue, absStock, otherHands, p) {
  const handRatio = bidValue / 15;

  // ポジション評価
  let positionValue;
  if (stockValue > 0) {
    positionValue = handRatio * absStock * p.aggression - bidValue * p.efficiency;
  } else {
    // マイナスカード: 最小入札を避けつつ高カードの浪費も抑える
    // handRatio 0.6付近にピークを作り、自然な分散を促す
    const safety = handRatio * absStock * p.caution;
    const waste = Math.max(handRatio - 0.6, 0) * absStock * p.efficiency * 3.0;
    positionValue = safety - waste;
  }

  // バッティングリスク
  const battingRisk = estimateBattingRisk(bidValue, otherHands, p.opponentAwareness);

  // 高得点プラスカードではバッティングリスクを受け入れて積極的に入札する
  let effectiveCaution = p.caution;
  if (stockValue > 0) {
    const valueFactor = Math.min(absStock / 10.0, 1.0);
    effectiveCaution = p.caution * (1.0 - valueFactor * 0.7);
  }

  // ノイズ（マイナスカードでは分散を大きくしてバッティングを減らす）
  const noiseMult = stockValue < 0 ? 2.5 : 1.0;
  const noiseOffset = (Math.random() * 2 - 1) * p.noise * noiseMult * absStock;

  return positionValue * (1.0 - battingRisk * effectiveCaution) + noiseOffset;
}

function estimateBattingRisk(value, otherHands, awareness) {
  if (otherHands.length === 0) return 0;

  const estimatedRisk = 1.0 / (otherHands.length + 1);

  if (awareness > 0) {
    let count = 0;
    for (const h of otherHands) {
      if (h.includes(value)) count++;
    }
    const actualRisk = count / otherHands.length;
    return lerp(estimatedRisk, actualRisk, awareness);
  }

  return estimatedRisk;
}

// AI名プール
const AI_NAMES = ['田中', '鈴木', '佐藤', '山本', '渡辺', '伊藤', '中村', '小林', '加藤', '吉田'];

function getAIName(usedNames) {
  const available = AI_NAMES.filter(n => !usedNames.includes(n));
  if (available.length === 0) return 'AI_' + Math.floor(Math.random() * 100);
  return available[Math.floor(Math.random() * available.length)];
}

function getDifficultyName(level) {
  return `Lv.${level}`;
}

module.exports = { decideBid, createAIParams, getAIName, getDifficultyName };
