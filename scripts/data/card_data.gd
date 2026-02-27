class_name CardData
extends Resource
## カードのデータ定義（銘柄カード・入札カード共通）

enum CardType {
	STOCK,    ## 銘柄カード（得点カード: +1~+10）
	VULTURE,  ## ハゲタカカード（得点カード: -1~-5）
	BID,      ## 入札カード（手札: 1~15）
}

@export var card_type: CardType
@export var value: int
@export var display_name: String


static func create_stock_card(val: int) -> CardData:
	var card: CardData = CardData.new()
	card.card_type = CardType.STOCK
	card.value = val
	card.display_name = _get_stock_name(val)
	return card


static func create_vulture_card(val: int) -> CardData:
	var card: CardData = CardData.new()
	card.card_type = CardType.VULTURE
	card.value = val
	card.display_name = _get_vulture_name(val)
	return card


static func create_bid_card(val: int) -> CardData:
	var card: CardData = CardData.new()
	card.card_type = CardType.BID
	card.value = val
	card.display_name = str(val) + "億"
	return card


func is_positive() -> bool:
	return value > 0


static func _get_stock_name(val: int) -> String:
	var names: Dictionary = {
		1: "町工場株",
		2: "地方銀行株",
		3: "食品メーカー株",
		4: "不動産株",
		5: "自動車株",
		6: "電機メーカー株",
		7: "製薬会社株",
		8: "通信大手株",
		9: "半導体株",
		10: "AI企業株",
	}
	return names.get(val, "不明株")


static func _get_vulture_name(val: int) -> String:
	var names: Dictionary = {
		-1: "業績下方修正",
		-2: "粉飾決算",
		-3: "リコール発覚",
		-4: "経営破綻",
		-5: "上場廃止",
	}
	return names.get(val, "不明")
