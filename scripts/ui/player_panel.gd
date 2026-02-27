class_name PlayerPanel
extends PanelContainer
## 対戦相手の情報パネル

var player_state: PlayerState = null
var _name_label: Label
var _score_label: Label
var _bid_card: CardDisplay = null
var _status_label: Label


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(160, 100)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.32, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_score_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	# 入札カード表示エリア
	var card_container: CenterContainer = CenterContainer.new()
	card_container.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(card_container)

	_bid_card = CardDisplay.new()
	_bid_card.custom_minimum_size = Vector2(40, 56)
	_bid_card.size = Vector2(40, 56)
	_bid_card.visible = false
	card_container.add_child(_bid_card)


func setup(state: PlayerState) -> void:
	player_state = state
	update_display()


func update_display() -> void:
	if player_state == null:
		return
	_name_label.text = player_state.player_name
	_score_label.text = str(player_state.score) + "pt"
	_status_label.text = "残り " + str(player_state.hand.size()) + "枚"


func show_bid(card: CardData) -> void:
	if _bid_card == null:
		return
	_bid_card.setup(card, false)
	_bid_card.visible = true


func reveal_bid() -> void:
	if _bid_card == null or not _bid_card.visible:
		return
	_bid_card.flip(true)


func mark_batting() -> void:
	if _bid_card and _bid_card.visible:
		_bid_card.show_batting_mark()


func mark_win(is_positive: bool) -> void:
	if _bid_card and _bid_card.visible:
		_bid_card.show_win_mark(is_positive)


func mark_lose() -> void:
	if _bid_card and _bid_card.visible:
		_bid_card.show_lose_effect()


func clear_bid() -> void:
	if _bid_card:
		_bid_card.visible = false
		_bid_card.is_batted = false
		_bid_card._batting_anim_progress = 0.0
		_bid_card.is_won = false
		_bid_card._win_anim_progress = 0.0
		_bid_card.modulate = Color.WHITE
		_bid_card.rotation = 0.0


func show_bid_placed() -> void:
	_status_label.text = "入札済み"
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))


func highlight_winner() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.45, 0.25, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)


func reset_highlight() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.32, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)
