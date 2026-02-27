extends Control
## メインゲーム画面 — ゲームの進行とUI表示を統括

var game_manager: GameManager = null
var _selected_card: CardData = null
var _human_player_id: int = 0

# UI参照
var _top_bar: HBoxContainer
var _round_label: Label
var _carried_label: Label
var _opponent_container: HBoxContainer
var _center_area: VBoxContainer
var _stock_card_display: CardDisplay
var _stock_card_container: CenterContainer
var _carried_over_container: HBoxContainer
var _player_info_bar: HBoxContainer
var _player_name_label: Label
var _player_score_label: Label
var _hand_container: HFlowContainer
var _bid_button: Button
var _hand_cards: Array[CardDisplay] = []
var _opponent_panels: Dictionary = {}  ## {player_id: int -> PlayerPanel}
var _message_label: Label
var _bg: ColorRect = null
var _bids_reveal_complete: bool = false
var _round_animation_complete: bool = false


func init_with_params(params: Dictionary) -> void:
	var configs: Variant = params.get("player_configs", [])
	if configs is Array:
		_start_game(configs as Array[Dictionary])


func _ready() -> void:
	_build_ui()
	GameEvents.bg_color_changed.connect(_on_bg_color_changed)


func _on_bg_color_changed(color: Color) -> void:
	if _bg:
		_bg.color = color


func _start_game(player_configs: Array[Dictionary]) -> void:
	game_manager = GameManager.new()
	add_child(game_manager)
	_connect_signals()
	game_manager.setup_game(player_configs)
	_human_player_id = game_manager.get_human_player_id()
	_setup_opponent_panels()
	_update_player_info()
	# 最初のラウンド開始
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self) and game_manager:
		game_manager.start_round()


func _build_ui() -> void:
	# 背景
	_bg = ColorRect.new()
	_bg.color = AudioManager.get_bg_color()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# メインレイアウト
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# === トップバー ===
	_top_bar = HBoxContainer.new()
	_top_bar.add_theme_constant_override("separation", 20)
	_top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	var top_margin: MarginContainer = _wrap_margin(main_vbox, _top_bar, 12, 12, 8, 8)
	var top_bg: StyleBoxFlat = StyleBoxFlat.new()
	top_bg.bg_color = Color(0.15, 0.18, 0.28)
	top_margin.add_theme_stylebox_override("panel", top_bg)

	_round_label = Label.new()
	_round_label.text = "ラウンド: 0/15"
	_round_label.add_theme_font_size_override("font_size", 20)
	_round_label.add_theme_color_override("font_color", Color.WHITE)
	_top_bar.add_child(_round_label)

	_carried_label = Label.new()
	_carried_label.text = ""
	_carried_label.visible = false
	_carried_label.add_theme_font_size_override("font_size", 18)
	_carried_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_top_bar.add_child(_carried_label)

	# === 対戦相手エリア ===
	_opponent_container = HBoxContainer.new()
	_opponent_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_opponent_container.add_theme_constant_override("separation", 12)
	_opponent_container.custom_minimum_size = Vector2(0, 110)
	main_vbox.add_child(_opponent_container)

	# === 中央エリア（銘柄カード + メッセージ） ===
	_center_area = VBoxContainer.new()
	_center_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_area.add_theme_constant_override("separation", 8)
	main_vbox.add_child(_center_area)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 24)
	_message_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_center_area.add_child(_message_label)

	_stock_card_container = CenterContainer.new()
	_stock_card_container.custom_minimum_size = Vector2(0, 140)
	_center_area.add_child(_stock_card_container)

	_stock_card_display = CardDisplay.new()
	_stock_card_display.custom_minimum_size = Vector2(100, 140)
	_stock_card_display.size = Vector2(100, 140)
	_stock_card_display.visible = false
	_stock_card_container.add_child(_stock_card_display)

	# 持ち越しカード表示
	var carried_center: CenterContainer = CenterContainer.new()
	_center_area.add_child(carried_center)

	_carried_over_container = HBoxContainer.new()
	_carried_over_container.add_theme_constant_override("separation", 6)
	carried_center.add_child(_carried_over_container)

	# === プレイヤー情報バー ===
	_player_info_bar = HBoxContainer.new()
	_player_info_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_info_bar.add_theme_constant_override("separation", 24)
	var info_margin: MarginContainer = _wrap_margin(main_vbox, _player_info_bar, 8, 8, 4, 4)
	var info_bg: StyleBoxFlat = StyleBoxFlat.new()
	info_bg.bg_color = Color(0.15, 0.18, 0.28)
	info_margin.add_theme_stylebox_override("panel", info_bg)

	_player_name_label = Label.new()
	_player_name_label.text = "あなた"
	_player_name_label.add_theme_font_size_override("font_size", 22)
	_player_name_label.add_theme_color_override("font_color", Color.WHITE)
	_player_info_bar.add_child(_player_name_label)

	_player_score_label = Label.new()
	_player_score_label.text = "0pt"
	_player_score_label.add_theme_font_size_override("font_size", 26)
	_player_score_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_player_info_bar.add_child(_player_score_label)

	# === 手札エリア ===
	var hand_scroll: ScrollContainer = ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 134)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(hand_scroll)

	var hand_margin: MarginContainer = MarginContainer.new()
	hand_margin.add_theme_constant_override("margin_left", 16)
	hand_margin.add_theme_constant_override("margin_right", 16)
	hand_margin.add_theme_constant_override("margin_top", 14)
	hand_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.add_child(hand_margin)

	_hand_container = HFlowContainer.new()
	_hand_container.add_theme_constant_override("h_separation", 6)
	_hand_container.add_theme_constant_override("v_separation", 6)
	_hand_container.alignment = FlowContainer.ALIGNMENT_CENTER
	_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_margin.add_child(_hand_container)

	# === 入札ボタン ===
	var btn_center: CenterContainer = CenterContainer.new()
	btn_center.custom_minimum_size = Vector2(0, 56)
	main_vbox.add_child(btn_center)

	_bid_button = Button.new()
	_bid_button.text = "入札する"
	_bid_button.custom_minimum_size = Vector2(240, 50)
	_bid_button.disabled = true
	_bid_button.add_theme_font_size_override("font_size", 24)
	_bid_button.pressed.connect(_on_bid_pressed)

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.3)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.content_margin_left = 20.0
	btn_style.content_margin_right = 20.0
	btn_style.content_margin_top = 10.0
	btn_style.content_margin_bottom = 10.0
	_bid_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover: StyleBoxFlat = btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.25, 0.6, 0.38)
	_bid_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled: StyleBoxFlat = btn_style.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.3, 0.32, 0.35)
	_bid_button.add_theme_stylebox_override("disabled", btn_disabled)

	_bid_button.add_theme_color_override("font_color", Color.WHITE)
	_bid_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_bid_button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))

	btn_center.add_child(_bid_button)

	# 下部スペーサー
	var bottom_spacer: Control = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	main_vbox.add_child(bottom_spacer)


func _wrap_margin(parent: Control, child: Control, l: int, r: int, t: int, b: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", l)
	margin.add_theme_constant_override("margin_right", r)
	margin.add_theme_constant_override("margin_top", t)
	margin.add_theme_constant_override("margin_bottom", b)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(margin)
	margin.add_child(child)
	return margin


func _connect_signals() -> void:
	game_manager.phase_changed.connect(_on_phase_changed)
	game_manager.stock_card_revealed.connect(_on_stock_card_revealed)
	game_manager.bid_placed.connect(_on_bid_placed)
	game_manager.all_bids_revealed.connect(_on_all_bids_revealed)
	game_manager.round_resolved.connect(_on_round_resolved)
	game_manager.cards_awarded.connect(_on_cards_awarded)
	game_manager.cards_carried_over.connect(_on_cards_carried_over)
	game_manager.game_over.connect(_on_game_over)


func _setup_opponent_panels() -> void:
	for child: Node in _opponent_container.get_children():
		child.queue_free()
	_opponent_panels.clear()

	for player: PlayerState in game_manager.state.players:
		if player.player_id == _human_player_id:
			continue
		var panel: PlayerPanel = PlayerPanel.new()
		_opponent_container.add_child(panel)
		panel.setup(player)
		_opponent_panels[player.player_id] = panel


func _update_player_info() -> void:
	var human: PlayerState = game_manager.state.get_player(_human_player_id)
	if human:
		_player_name_label.text = human.player_name
		_player_score_label.text = str(human.score) + "pt"


func _update_hand() -> void:
	# 手札カードをクリア
	for card_ui: CardDisplay in _hand_cards:
		if is_instance_valid(card_ui):
			card_ui.queue_free()
	_hand_cards.clear()

	var human: PlayerState = game_manager.state.get_player(_human_player_id)
	if human == null:
		return

	for card: CardData in human.hand:
		var card_ui: CardDisplay = CardDisplay.new()
		card_ui.custom_minimum_size = Vector2(70, 98)
		card_ui.size = Vector2(70, 98)
		_hand_container.add_child(card_ui)
		card_ui.setup(card, true)
		card_ui.is_selectable = (game_manager.state.phase == GameState.Phase.BIDDING)
		card_ui.card_clicked.connect(_on_hand_card_clicked)
		_hand_cards.append(card_ui)


func _enable_hand(enabled: bool) -> void:
	for card_ui: CardDisplay in _hand_cards:
		if is_instance_valid(card_ui):
			card_ui.is_selectable = enabled


func _update_round_display() -> void:
	_round_label.text = "ラウンド: " + str(game_manager.state.current_round) + "/" + str(GameConfig.TOTAL_ROUNDS)


func _update_carried_display(cards: Array[CardData]) -> void:
	# 持ち越しカード表示クリア
	for child: Node in _carried_over_container.get_children():
		child.queue_free()

	if cards.is_empty():
		_carried_label.text = ""
		_carried_label.visible = false
		return

	_carried_label.visible = true
	_carried_label.text = "持越: " + str(cards.size()) + "枚"
	for card: CardData in cards:
		var mini_card: CardDisplay = CardDisplay.new()
		mini_card.custom_minimum_size = Vector2(36, 50)
		mini_card.size = Vector2(36, 50)
		mini_card.setup(card, true)
		mini_card.set_font_sizes(14, 8)
		_carried_over_container.add_child(mini_card)


# === シグナルハンドラ ===

func _on_phase_changed(new_phase: GameState.Phase) -> void:
	match new_phase:
		GameState.Phase.BIDDING:
			_bid_button.disabled = true
			_selected_card = null
			_enable_hand(true)
			_message_label.text = "カードを選んで入札してください"
		GameState.Phase.RESOLVING:
			_enable_hand(false)
			_message_label.text = "判定中..."
		GameState.Phase.ROUND_END:
			_message_label.text = ""
		GameState.Phase.GAME_OVER:
			_message_label.text = "ゲーム終了！"


func _on_stock_card_revealed(card: CardData) -> void:
	GameEvents.sfx_requested.emit("card_reveal")
	_update_round_display()
	_update_hand()

	# 対戦相手パネルをリセット
	for pid: Variant in _opponent_panels:
		var panel: PlayerPanel = _opponent_panels[pid] as PlayerPanel
		panel.clear_bid()
		panel.reset_highlight()
		panel.update_display()

	# 銘柄カード表示（アニメーション付き）
	_stock_card_display.visible = true
	_stock_card_display.setup(card, false)
	_stock_card_display.scale = Vector2(0.5, 0.5)

	var tween: Tween = create_tween()
	tween.tween_property(_stock_card_display, "scale", Vector2(1.0, 1.0), 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func() -> void: _stock_card_display.flip(true))

	if card.is_positive():
		_message_label.text = card.display_name + " [+" + str(card.value) + "] が出ました！"
	else:
		_message_label.text = card.display_name + " [" + str(card.value) + "] が出ました..."
	_message_label.add_theme_color_override(
		"font_color",
		Color(0.4, 0.85, 0.5) if card.is_positive() else Color(0.9, 0.4, 0.4)
	)


func _on_bid_placed(player_id: int, _card: CardData) -> void:
	if player_id == _human_player_id:
		return
	# AI入札: 裏向きカードを表示
	if _opponent_panels.has(player_id):
		var panel: PlayerPanel = _opponent_panels[player_id] as PlayerPanel
		panel.show_bid(_card)
		panel.show_bid_placed()


func _on_all_bids_revealed(result: RoundResolver.ResolveResult) -> void:
	_bids_reveal_complete = false
	GameEvents.sfx_requested.emit("bid_reveal")
	print("[UI] all_bids_revealed: winner_id=%d, carried=%s, bids=%s" % [result.winner_id, str(result.is_carried_over), str(result.all_bids)])

	# ステップ1: 全員の入札を公開（フリップアニメーション）
	_message_label.text = "入札結果を公開！"
	_message_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	for pid: Variant in _opponent_panels:
		var panel: PlayerPanel = _opponent_panels[pid] as PlayerPanel
		var pid_int: int = pid as int
		if result.all_bids.has(pid_int):
			var bid_val: int = result.all_bids[pid_int] as int
			var bid_card: CardData = CardData.create_bid_card(bid_val)
			panel.show_bid(bid_card)
		panel.reveal_bid()

	# フリップアニメーション完了を待機（0.12s×2 + 余裕）
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self):
		return

	# ステップ2: バッティングのバツマーク＋落札の丸マークを同時表示
	var has_batting: bool = not result.batted_values.is_empty()
	var has_winner: bool = not result.is_carried_over and result.winner_id >= 0

	if has_batting:
		GameEvents.sfx_requested.emit("batting")
		for pid: Variant in _opponent_panels:
			var pid_int: int = pid as int
			if result.all_bids.has(pid_int) and result.batted_values.has(result.all_bids[pid_int] as int):
				(_opponent_panels[pid] as PlayerPanel).mark_batting()
		if result.all_bids.has(_human_player_id):
			var my_bid: int = result.all_bids[_human_player_id] as int
			if result.batted_values.has(my_bid):
				for card_ui: CardDisplay in _hand_cards:
					if is_instance_valid(card_ui) and card_ui.card_data and card_ui.card_data.value == my_bid:
						card_ui.show_batting_mark()

	if has_winner:
		var is_positive: bool = _stock_card_display.card_data != null and _stock_card_display.card_data.is_positive()
		if result.winner_id == _human_player_id:
			# 自分が落札 → 自分の出した入札カードに丸マーク
			if result.all_bids.has(_human_player_id):
				var my_bid: int = result.all_bids[_human_player_id] as int
				for card_ui: CardDisplay in _hand_cards:
					if is_instance_valid(card_ui) and card_ui.card_data and card_ui.card_data.value == my_bid:
						card_ui.show_win_mark(is_positive)
		elif _opponent_panels.has(result.winner_id):
			# 相手が落札 → 相手パネルの入札カードに丸マーク
			(_opponent_panels[result.winner_id] as PlayerPanel).mark_win(is_positive)

	# バッティングでも落札でもないカードは暗くして傾ける
	for pid: Variant in _opponent_panels:
		var pid_int: int = pid as int
		if not result.all_bids.has(pid_int):
			continue
		var bid_val: int = result.all_bids[pid_int] as int
		var is_batted_card: bool = result.batted_values.has(bid_val)
		var is_winner_card: bool = has_winner and pid_int == result.winner_id
		if not is_batted_card and not is_winner_card:
			(_opponent_panels[pid] as PlayerPanel).mark_lose()
	# 自分の入札カードも同様
	if result.all_bids.has(_human_player_id):
		var my_bid_val: int = result.all_bids[_human_player_id] as int
		var my_batted: bool = result.batted_values.has(my_bid_val)
		var my_won: bool = has_winner and result.winner_id == _human_player_id
		if not my_batted and not my_won:
			for card_ui: CardDisplay in _hand_cards:
				if is_instance_valid(card_ui) and card_ui.card_data and card_ui.card_data.value == my_bid_val:
					card_ui.show_lose_effect()

	if has_batting or has_winner:
		# マークアニメーション完了を待機
		await get_tree().create_timer(0.6).timeout
		if not is_instance_valid(self):
			return

	if has_batting:
		var batted_str: String = ""
		for val: int in result.batted_values:
			if not batted_str.is_empty():
				batted_str += ", "
			batted_str += str(val) + "億"
		_message_label.text = "バッティング！ [" + batted_str + "]"
		_message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))

	_bids_reveal_complete = true


func _on_round_resolved(_result: RoundResolver.ResolveResult) -> void:
	# カード演出完了を待機してから次ラウンドへ
	while not _round_animation_complete:
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or game_manager == null:
		return
	if game_manager.state.phase == GameState.Phase.GAME_OVER:
		return
	game_manager.start_round()


func _on_cards_awarded(player_id: int, cards: Array[CardData]) -> void:
	_round_animation_complete = false
	var card_vals: Array[int] = []
	for c: CardData in cards:
		card_vals.append(c.value)
	print("[UI] cards_awarded: player_id=%d, cards=%s" % [player_id, str(card_vals)])

	# await前にカードデータを保存（次ラウンド開始で上書きされる前に）
	var stock_card_data: CardData = _stock_card_display.card_data

	# 入札公開アニメーション完了を待機
	while not _bids_reveal_complete:
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return
	# バッティングメッセージを読む時間
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self):
		return

	var total: int = 0
	for card: CardData in cards:
		total += card.value

	var player: PlayerState = game_manager.state.get_player(player_id)
	var pname: String = player.player_name if player else "???"

	if total > 0:
		GameEvents.sfx_requested.emit("gain")
		_message_label.text = pname + " が +" + str(total) + "pt を獲得！"
		_message_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	else:
		GameEvents.sfx_requested.emit("loss")
		_message_label.text = pname + " が " + str(total) + "pt を引き取った..."
		_message_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	# 勝者パネルをハイライト
	if _opponent_panels.has(player_id):
		(_opponent_panels[player_id] as PlayerPanel).highlight_winner()

	# カードが落札者のほうへ飛んでいく演出（保存済みのカードデータを使用）
	await _animate_card_to_winner(player_id, stock_card_data)

	# スコア更新
	_update_player_info()
	for pid: Variant in _opponent_panels:
		(_opponent_panels[pid] as PlayerPanel).update_display()

	# 持ち越しクリア
	_update_carried_display([])
	_round_animation_complete = true


func _animate_card_to_winner(winner_id: int, card_data: CardData) -> void:
	if not is_instance_valid(_stock_card_display) or not _stock_card_display.visible:
		return

	# 移動先の座標を決定（落札者パネルの中央）
	var target_pos: Vector2
	if winner_id == _human_player_id:
		# 自分が落札 → プレイヤー情報バーへ
		target_pos = _player_score_label.global_position + _player_score_label.size * 0.5
	elif _opponent_panels.has(winner_id):
		var panel: PlayerPanel = _opponent_panels[winner_id] as PlayerPanel
		target_pos = panel.global_position + panel.size * 0.5
	else:
		return

	# 飛ばす用のカードをオーバーレイとして生成（保存済みのカードデータを使用）
	var flying_card: CardDisplay = CardDisplay.new()
	flying_card.custom_minimum_size = Vector2(100, 140)
	flying_card.size = Vector2(100, 140)
	flying_card.setup(card_data, true)
	flying_card.z_index = 100
	# グローバル座標で配置するためトップレベルに追加
	add_child(flying_card)
	var start_pos: Vector2 = _stock_card_display.global_position
	flying_card.global_position = start_pos

	# 元の銘柄カード表示を隠す
	_stock_card_display.visible = false

	# ビヨーンアニメーション
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# 位置移動（BACK イージングでビヨーン感を出す）
	tween.tween_property(flying_card, "global_position", target_pos - Vector2(50, 70), 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)

	# 縮小しながら飛ぶ
	tween.tween_property(flying_card, "scale", Vector2(0.4, 0.4), 0.6) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# 少し回転
	tween.tween_property(flying_card, "rotation", 0.3, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	tween.set_parallel(false)

	# 到着後にポンっと跳ねる
	tween.tween_property(flying_card, "scale", Vector2(0.55, 0.55), 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(flying_card, "scale", Vector2(0.0, 0.0), 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# フェードアウト
	tween.parallel().tween_property(flying_card, "modulate:a", 0.0, 0.15)

	await tween.finished
	if is_instance_valid(flying_card):
		flying_card.queue_free()


func _on_cards_carried_over(cards: Array[CardData]) -> void:
	_round_animation_complete = false
	# 入札公開アニメーション完了を待機
	while not _bids_reveal_complete:
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self):
		return
	_message_label.text = "全員バッティング！次のラウンドに持ち越し"
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	_update_carried_display(cards)
	_round_animation_complete = true


func _on_game_over(rankings: Array[PlayerState]) -> void:
	GameEvents.sfx_requested.emit("game_over")
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		var ranking_data: Array[Dictionary] = []
		for ps: PlayerState in rankings:
			ranking_data.append({
				"name": ps.player_name,
				"score": ps.score,
				"is_ai": ps.is_ai,
			})
		GameEvents.scene_change_requested.emit("result", {"rankings": ranking_data})


func _on_hand_card_clicked(card: CardData) -> void:
	if game_manager.state.phase != GameState.Phase.BIDDING:
		return

	GameEvents.sfx_requested.emit("card_select")
	# 選択状態を更新
	_selected_card = card
	for card_ui: CardDisplay in _hand_cards:
		if is_instance_valid(card_ui) and card_ui.card_data:
			card_ui.set_selected(card_ui.card_data.value == card.value)

	_bid_button.disabled = false
	_bid_button.text = str(card.value) + "億で入札する"


func _on_bid_pressed() -> void:
	if _selected_card == null or game_manager.state.phase != GameState.Phase.BIDDING:
		return
	GameEvents.sfx_requested.emit("bid_confirm")
	_bid_button.disabled = true
	_bid_button.text = "入札済み"
	_enable_hand(false)
	game_manager.submit_bid(_human_player_id, _selected_card.value)
	_selected_card = null
