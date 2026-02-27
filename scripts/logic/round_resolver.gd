class_name RoundResolver
extends RefCounted
## ラウンド判定ロジック（バッティング検出・勝者決定・持ち越し）


class ResolveResult extends RefCounted:
	var winner_id: int = -1
	var awarded_cards: Array[CardData] = []
	var is_carried_over: bool = false
	var batted_values: Array[int] = []
	var all_bids: Dictionary = {}  ## {player_id: int -> int(bid_value)}


static func resolve(
	bids: Dictionary,
	stock_card: CardData,
	carried_over: Array[CardData]
) -> ResolveResult:
	var result: ResolveResult = ResolveResult.new()

	print("=== [RoundResolver] 判定開始 ===")
	print("  銘柄カード: %s (値: %d, positive: %s)" % [stock_card.display_name, stock_card.value, str(stock_card.is_positive())])

	# 全入札を記録
	for pid: Variant in bids:
		var card: CardData = bids[pid] as CardData
		result.all_bids[pid as int] = card.value
		print("  入札: Player%d → カード値=%d (type=%s)" % [pid as int, card.value, CardData.CardType.keys()[card.card_type]])

	# バッティング検出: 各入札値ごとにプレイヤーIDをグループ化
	var value_groups: Dictionary = {}  ## {bid_value: int -> Array[int](player_ids)}
	for pid: Variant in bids:
		var val: int = (bids[pid] as CardData).value
		if not value_groups.has(val):
			value_groups[val] = [] as Array[int]
		(value_groups[val] as Array[int]).append(pid as int)

	# バッティングしていない有効な入札を抽出
	var valid_bids: Dictionary = {}  ## {player_id: int -> bid_value: int}
	var batted: Array[int] = []
	for val: Variant in value_groups:
		var pids: Array[int] = value_groups[val] as Array[int]
		if pids.size() > 1:
			batted.append(val as int)
			print("  バッティング: 値=%d → Players=%s" % [val as int, str(pids)])
		else:
			valid_bids[pids[0]] = val as int
	result.batted_values = batted

	print("  有効入札: %s" % str(valid_bids))

	# 有効な入札がない場合 → 持ち越し
	if valid_bids.is_empty():
		result.is_carried_over = true
		result.winner_id = -1
		print("  結果: 全員バッティング → 持ち越し")
		return result

	# 勝者決定
	var winner_id: int = -1
	if stock_card.is_positive():
		# プラスカード: 最大値が勝ち
		var max_val: int = -1
		for pid: Variant in valid_bids:
			var bid_val: int = valid_bids[pid] as int
			if bid_val > max_val:
				max_val = bid_val
				winner_id = pid as int
		print("  判定(+): 最大入札値=%d → 勝者=Player%d" % [max_val, winner_id])
	else:
		# マイナスカード: 最小値が勝ち（取らされる）
		var min_val: int = 999
		for pid: Variant in valid_bids:
			var bid_val: int = valid_bids[pid] as int
			if bid_val < min_val:
				min_val = bid_val
				winner_id = pid as int
		print("  判定(-): 最小入札値=%d → 引取り=Player%d" % [min_val, winner_id])

	result.winner_id = winner_id
	result.awarded_cards.append(stock_card)
	result.awarded_cards.append_array(carried_over)
	result.is_carried_over = false
	print("  獲得カード数: %d (持ち越し含む)" % result.awarded_cards.size())
	print("=== [RoundResolver] 判定終了 ===")
	return result
