extends Control
## メインゲーム画面 — ゲームの進行とUI表示を統括

var game_manager: GameManager = null
var _selected_card: CardData = null
var _human_player_id: int = 0

# オンラインモード
var _is_online: bool = false
var _network: NetworkClient = null
var _online_hand: Array[int] = []
var _online_players: Array[Dictionary] = []
var _online_scores: Dictionary = {}
var _online_current_round: int = 0
var _online_stock_card: CardData = null
var _online_carried_count: int = 0
var _online_phase: String = "bidding"
var _bid_timer_remaining: float = 0.0
var _bid_timer_active: bool = false
const BID_TIMEOUT_SEC: float = 30.0

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
var _hand_container: HBoxContainer
var _bid_button: Button
var _hand_cards: Array[CardDisplay] = []
var _opponent_panels: Dictionary = {}  ## {player_id: int -> PlayerPanel}
var _message_label: Label
var _bid_timer_label: Label
var _guide_label: RichTextLabel
var _bg: ColorRect = null
var _bids_reveal_complete: bool = false
var _round_animation_complete: bool = false


func init_with_params(params: Dictionary) -> void:
	if params.get("online", false):
		_start_online(params)
	else:
		var configs: Variant = params.get("player_configs", [])
		if configs is Array:
			_start_game(configs as Array[Dictionary])


func _ready() -> void:
	_build_ui()
	GameEvents.bg_color_changed.connect(_on_bg_color_changed)


func _process(delta: float) -> void:
	if not _bid_timer_active:
		return
	_bid_timer_remaining -= delta
	if _bid_timer_remaining <= 0.0:
		_bid_timer_remaining = 0.0
		_bid_timer_active = false
	_bid_timer_label.text = "⏱ " + str(ceili(_bid_timer_remaining))
	# 残り10秒以下で赤く点滅
	if _bid_timer_remaining <= 10.0:
		var blink: float = absf(sin(_bid_timer_remaining * 4.0))
		_bid_timer_label.add_theme_color_override("font_color", Color(1.0, 0.3 + blink * 0.3, 0.3))
	else:
		_bid_timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))


func _stop_bid_timer() -> void:
	_bid_timer_active = false
	_bid_timer_label.visible = false


func _on_bg_color_changed(color: Color) -> void:
	if _bg:
		_bg.color = color


func _exit_tree() -> void:
	if _is_online and _network:
		_network.leave()
		_network.close()
		_network.queue_free()
		_network = null


func _start_online(params: Dictionary) -> void:
	_is_online = true
	_network = params.get("network") as NetworkClient
	if _network:
		add_child(_network)
		_network.message_received.connect(_on_network_message)
		_network.disconnected.connect(_on_network_disconnected)

	_human_player_id = params.get("your_id", 0) as int
	_online_players = []
	var players_raw: Variant = params.get("players", [])
	if players_raw is Array:
		for p: Variant in players_raw:
			if p is Dictionary:
				_online_players.append(p as Dictionary)
	_online_hand = []
	var hand_raw: Variant = params.get("your_hand", [])
	if hand_raw is Array:
		for v: Variant in hand_raw:
			_online_hand.append(v as int)
	_online_hand.sort()

	# スコア初期化
	for p: Dictionary in _online_players:
		_online_scores[p.get("id", 0) as int] = 0

	# 対戦相手パネル
	_setup_online_opponent_panels()
	_update_online_player_info()
	_update_online_hand()


func _setup_online_opponent_panels() -> void:
	for child: Node in _opponent_container.get_children():
		child.queue_free()
	_opponent_panels.clear()

	for p: Dictionary in _online_players:
		var pid: int = p.get("id", 0) as int
		if pid == _human_player_id:
			continue
		var ps: PlayerState = PlayerState.new()
		ps.player_id = pid
		ps.player_name = p.get("name", "???") as String
		ps.is_ai = p.get("is_ai", false) as bool
		var panel: PlayerPanel = PlayerPanel.new()
		_opponent_container.add_child(panel)
		panel.setup(ps)
		_opponent_panels[pid] = panel


func _update_online_player_info() -> void:
	for p: Dictionary in _online_players:
		if (p.get("id", -1) as int) == _human_player_id:
			_player_name_label.text = p.get("name", "あなた") as String
			break
	_player_score_label.text = str(_online_scores.get(_human_player_id, 0)) + "pt"


func _update_online_hand() -> void:
	for card_ui: CardDisplay in _hand_cards:
		if is_instance_valid(card_ui):
			card_ui.queue_free()
	_hand_cards.clear()

	for val: int in _online_hand:
		var card: CardData = CardData.create_bid_card(val)
		var card_ui: CardDisplay = CardDisplay.new()
		card_ui.custom_minimum_size = Vector2(70, 98)
		card_ui.size = Vector2(70, 98)
		_hand_container.add_child(card_ui)
		card_ui.setup(card, true)
		card_ui.is_selectable = (_online_phase == "bidding")
		card_ui.card_clicked.connect(_on_hand_card_clicked)
		_hand_cards.append(card_ui)


# === オンラインメッセージ処理 ===

func _on_network_message(msg_type: String, data: Dictionary) -> void:
	match msg_type:
		NetworkProtocol.ROUND_START:
			_on_online_round_start(data)
		NetworkProtocol.BID_RECEIVED:
			_on_online_bid_received(data)
		NetworkProtocol.BIDS_REVEALED:
			_on_online_bids_revealed(data)
		NetworkProtocol.CARDS_AWARDED:
			_on_online_cards_awarded(data)
		NetworkProtocol.CARDS_CARRIED:
			_on_online_cards_carried(data)
		NetworkProtocol.GAME_OVER:
			_on_online_game_over(data)


func _on_network_disconnected() -> void:
	_message_label.text = "サーバーから切断されました"
	_message_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	_enable_hand(false)
	_bid_button.disabled = true


func _on_online_round_start(data: Dictionary) -> void:
	_bids_reveal_complete = false
	_round_animation_complete = false
	_online_current_round = data.get("round", 0) as int
	_online_carried_count = data.get("carried_count", 0) as int
	_online_phase = "bidding"

	# 銘柄カード生成
	var sc: Dictionary = data.get("stock_card", {}) as Dictionary
	var val: int = sc.get("value", 0) as int
	if val > 0:
		_online_stock_card = CardData.create_stock_card(val)
	else:
		_online_stock_card = CardData.create_vulture_card(val)

	# ラウンド表示更新
	_round_label.text = "ラウンド: " + str(_online_current_round) + "/" + str(GameConfig.TOTAL_ROUNDS)

	# 持ち越し表示
	if _online_carried_count > 0:
		_carried_label.visible = true
		_carried_label.text = "持越: " + str(_online_carried_count) + "枚"
	else:
		_carried_label.visible = false
		_carried_label.text = ""

	# 対戦相手パネルをリセット
	for pid: Variant in _opponent_panels:
		var panel: PlayerPanel = _opponent_panels[pid] as PlayerPanel
		panel.clear_bid()
		panel.reset_highlight()
		panel.update_display()

	# 銘柄カード表示
	GameEvents.sfx_requested.emit("card_reveal")
	_stock_card_display.visible = true
	_stock_card_display.setup(_online_stock_card, false)
	_stock_card_display.scale = Vector2(0.5, 0.5)

	var tween: Tween = create_tween()
	tween.tween_property(_stock_card_display, "scale", Vector2(1.0, 1.0), 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func() -> void: _stock_card_display.flip(true))

	if _online_stock_card.is_positive():
		_message_label.text = _online_stock_card.display_name + " [+" + str(_online_stock_card.value) + "] が出ました！"
	else:
		_message_label.text = _online_stock_card.display_name + " [" + str(_online_stock_card.value) + "] が出ました..."
	_message_label.add_theme_color_override(
		"font_color",
		Color(0.4, 0.85, 0.5) if _online_stock_card.is_positive() else Color(0.9, 0.4, 0.4)
	)

	# ガイドラベル
	if _online_stock_card.is_positive():
		_guide_label.text = "入札額が一番[color=#66da80]高い[/color]人が獲得できます"
	else:
		_guide_label.text = "入札額が一番[color=#e66666]低い[/color]人が引き取ります"
	_guide_label.visible = true

	# 手札更新・入札可能に
	_update_online_hand()
	_selected_card = null
	_bid_button.disabled = true
	_bid_button.text = "入札する"

	# 入札タイマー開始
	_bid_timer_remaining = BID_TIMEOUT_SEC
	_bid_timer_active = true
	_bid_timer_label.visible = true

	# BIDDINGメッセージを少し遅らせて表示
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		return
	_message_label.text = "カードを選んで入札してください"
	_message_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))


func _on_online_bid_received(data: Dictionary) -> void:
	var pid: int = data.get("player_id", -1) as int
	if pid == _human_player_id:
		return
	if _opponent_panels.has(pid):
		var panel: PlayerPanel = _opponent_panels[pid] as PlayerPanel
		panel.show_bid_placed()


func _on_online_bids_revealed(data: Dictionary) -> void:
	_bids_reveal_complete = false
	_online_phase = "resolving"
	_stop_bid_timer()
	_guide_label.visible = false
	GameEvents.sfx_requested.emit("bid_reveal")

	var all_bids: Dictionary = data.get("all_bids", {}) as Dictionary
	var batted_values_raw: Variant = data.get("batted_values", [])
	var batted_values: Array[int] = []
	if batted_values_raw is Array:
		for v: Variant in batted_values_raw:
			batted_values.append(v as int)
	var winner_id: int = data.get("winner_id", -1) as int
	var is_carried: bool = data.get("is_carried_over", false) as bool

	_message_label.text = "入札結果を公開！"
	_message_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_enable_hand(false)

	# 全員の入札を公開
	for pid_str: Variant in all_bids:
		var pid: int = int(str(pid_str))
		var bid_val: int = all_bids[pid_str] as int
		if pid != _human_player_id and _opponent_panels.has(pid):
			var bid_card: CardData = CardData.create_bid_card(bid_val)
			var panel: PlayerPanel = _opponent_panels[pid] as PlayerPanel
			panel.show_bid(bid_card)
			panel.reveal_bid()

	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self):
		return

	# バッティング表示
	var has_batting: bool = not batted_values.is_empty()
	var has_winner: bool = not is_carried and winner_id >= 0
	var is_positive: bool = _online_stock_card != null and _online_stock_card.is_positive()

	if has_batting:
		var bat_color: Color = Color(0.15, 0.75, 0.25) if not is_positive else Color(0.95, 0.15, 0.15)
		var bat_shield: bool = not is_positive
		for pid_str: Variant in all_bids:
			var pid: int = int(str(pid_str))
			var bid_val: int = all_bids[pid_str] as int
			if batted_values.has(bid_val):
				if pid != _human_player_id and _opponent_panels.has(pid):
					(_opponent_panels[pid] as PlayerPanel).mark_batting(bat_color, bat_shield)
				elif pid == _human_player_id:
					for card_ui: CardDisplay in _hand_cards:
						if is_instance_valid(card_ui) and card_ui.card_data and card_ui.card_data.value == bid_val:
							card_ui.show_batting_mark(bat_color, bat_shield)

	if has_winner:
		if winner_id == _human_player_id:
			var my_pid_str: String = str(_human_player_id)
			if all_bids.has(my_pid_str):
				var my_bid: int = all_bids[my_pid_str] as int
				for card_ui: CardDisplay in _hand_cards:
					if is_instance_valid(card_ui) and card_ui.card_data and card_ui.card_data.value == my_bid:
						card_ui.show_win_mark(is_positive)
		elif _opponent_panels.has(winner_id):
			(_opponent_panels[winner_id] as PlayerPanel).mark_win(is_positive)

	# 負けエフェクト
	for pid_str: Variant in all_bids:
		var pid: int = int(str(pid_str))
		var bid_val: int = all_bids[pid_str] as int
		var is_batted: bool = batted_values.has(bid_val)
		var is_winner: bool = has_winner and pid == winner_id
		if not is_batted and not is_winner:
			if pid != _human_player_id and _opponent_panels.has(pid):
				(_opponent_panels[pid] as PlayerPanel).mark_lose()
			elif pid == _human_player_id:
				for card_ui: CardDisplay in _hand_cards:
					if is_instance_valid(card_ui) and card_ui.card_data and card_ui.card_data.value == bid_val:
						card_ui.show_lose_effect()

	if has_batting or has_winner:
		await get_tree().create_timer(0.6).timeout
		if not is_instance_valid(self):
			return

	# 自分の入札カードを手札から消費
	var my_bid_str: String = str(_human_player_id)
	if all_bids.has(my_bid_str):
		var my_bid_val: int = all_bids[my_bid_str] as int
		_online_hand.erase(my_bid_val)

	_bids_reveal_complete = true


func _on_online_cards_awarded(data: Dictionary) -> void:
	_round_animation_complete = false

	var awarded_pid: int = data.get("player_id", -1) as int
	var cards_raw: Variant = data.get("cards", [])
	var scores_raw: Variant = data.get("scores", {})
	var stock_card_data: CardData = _online_stock_card

	# 入札公開完了を待機
	while not _bids_reveal_complete:
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self):
		return

	# スコア更新
	if scores_raw is Dictionary:
		for pid_str: Variant in scores_raw:
			_online_scores[int(str(pid_str))] = (scores_raw as Dictionary)[pid_str] as int

	var total: int = 0
	if cards_raw is Array:
		for c: Variant in cards_raw:
			var cd: Dictionary = c as Dictionary
			total += cd.get("value", 0) as int

	# 落札者名
	var pname: String = "???"
	for p: Dictionary in _online_players:
		if (p.get("id", -1) as int) == awarded_pid:
			pname = p.get("name", "???") as String
			break

	if total > 0:
		GameEvents.sfx_requested.emit("gain")
		_message_label.text = pname + " が +" + str(total) + "pt を獲得！"
		_message_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	else:
		GameEvents.sfx_requested.emit("loss")
		_message_label.text = pname + " が " + str(total) + "pt を引き取った..."
		_message_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	if _opponent_panels.has(awarded_pid):
		(_opponent_panels[awarded_pid] as PlayerPanel).highlight_winner()

	await _animate_card_to_winner(awarded_pid, stock_card_data)

	# スコア表示更新
	_update_online_player_info()
	for pid: Variant in _opponent_panels:
		var panel: PlayerPanel = _opponent_panels[pid] as PlayerPanel
		var ps: PlayerState = panel.player_state
		if ps:
			ps.score = _online_scores.get(pid as int, 0) as int
			panel.update_display()

	# 持ち越しクリア
	for child: Node in _carried_over_container.get_children():
		child.queue_free()
	_carried_label.visible = false
	_carried_label.text = ""

	_round_animation_complete = true


func _on_online_cards_carried(data: Dictionary) -> void:
	_round_animation_complete = false

	while not _bids_reveal_complete:
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self):
		return

	_message_label.text = "全員バッティング！次のラウンドに持ち越し"
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))

	# 持ち越しカード表示
	var carried_raw: Variant = data.get("carried_cards", [])
	for child: Node in _carried_over_container.get_children():
		child.queue_free()
	if carried_raw is Array:
		_carried_label.visible = true
		_carried_label.text = "持越: " + str((carried_raw as Array).size()) + "枚"
		var idx: int = 0
		for c: Variant in carried_raw:
			var cd: Dictionary = c as Dictionary
			var val: int = cd.get("value", 0) as int
			var card: CardData
			if val > 0:
				card = CardData.create_stock_card(val)
			else:
				card = CardData.create_vulture_card(val)
			var mini_card: CardDisplay = CardDisplay.new()
			mini_card.name = "CarriedCard_" + str(idx) + "_val" + str(val)
			mini_card.custom_minimum_size = Vector2(36, 50)
			mini_card.size = Vector2(36, 50)
			_carried_over_container.add_child(mini_card)
			mini_card.setup(card, true)
			mini_card.set_font_sizes(12, 0)
			mini_card.set_value_only_mode()
			idx += 1

	_round_animation_complete = true


func _on_online_game_over(data: Dictionary) -> void:
	_stop_bid_timer()

	# 最終ラウンドのアニメーション完了を待機
	while not _round_animation_complete:
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return

	_message_label.text = "ゲーム終了！"
	_message_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))

	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		return

	var rankings_raw: Variant = data.get("rankings", [])
	var ranking_data: Array[Dictionary] = []
	if rankings_raw is Array:
		for r: Variant in rankings_raw:
			var rd: Dictionary = r as Dictionary
			ranking_data.append({
				"name": rd.get("name", "???"),
				"score": rd.get("score", 0),
				"is_ai": rd.get("is_ai", false),
			})

	GameEvents.scene_change_requested.emit("result", {"rankings": ranking_data})


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

	# 入札タイムリミット表示
	_bid_timer_label = Label.new()
	_bid_timer_label.text = ""
	_bid_timer_label.visible = false
	_bid_timer_label.add_theme_font_size_override("font_size", 20)
	_bid_timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_top_bar.add_child(_bid_timer_label)

	# スペーサー（ラウンド表示と退出ボタンを左右に分ける）
	var top_spacer: Control = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(top_spacer)

	# 退出ボタン
	var exit_btn: Button = Button.new()
	exit_btn.text = "退出"
	exit_btn.add_theme_font_size_override("font_size", 16)
	var exit_style: StyleBoxFlat = StyleBoxFlat.new()
	exit_style.bg_color = Color(0.5, 0.2, 0.2)
	exit_style.corner_radius_top_left = 6
	exit_style.corner_radius_top_right = 6
	exit_style.corner_radius_bottom_left = 6
	exit_style.corner_radius_bottom_right = 6
	exit_style.content_margin_left = 12.0
	exit_style.content_margin_right = 12.0
	exit_style.content_margin_top = 4.0
	exit_style.content_margin_bottom = 4.0
	exit_btn.add_theme_stylebox_override("normal", exit_style)
	var exit_hover: StyleBoxFlat = exit_style.duplicate() as StyleBoxFlat
	exit_hover.bg_color = Color(0.6, 0.25, 0.25)
	exit_btn.add_theme_stylebox_override("hover", exit_hover)
	exit_btn.add_theme_color_override("font_color", Color.WHITE)
	exit_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	exit_btn.pressed.connect(_on_exit_pressed)
	_top_bar.add_child(exit_btn)

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

	_guide_label = RichTextLabel.new()
	_guide_label.bbcode_enabled = true
	_guide_label.text = ""
	_guide_label.fit_content = true
	_guide_label.scroll_active = false
	_guide_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_guide_label.add_theme_font_size_override("normal_font_size", 15)
	_guide_label.add_theme_color_override("default_color", Color(0.7, 0.7, 0.75))
	_guide_label.visible = false
	var guide_center: CenterContainer = CenterContainer.new()
	guide_center.add_child(_guide_label)
	_center_area.add_child(guide_center)

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

	# main_vbox下端にフッター分の余白を確保
	var footer_spacer: Control = Control.new()
	footer_spacer.custom_minimum_size = Vector2(0, 240)
	main_vbox.add_child(footer_spacer)

	# === フッター（プレイヤー情報 + 手札 + 入札ボタン：画面下部固定） ===
	var footer: PanelContainer = PanelContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -240.0
	footer.offset_bottom = 0.0
	var footer_bg: StyleBoxFlat = StyleBoxFlat.new()
	footer_bg.bg_color = Color(0.12, 0.14, 0.22, 0.95)
	footer_bg.content_margin_top = 4.0
	footer_bg.content_margin_bottom = 8.0
	footer_bg.content_margin_left = 0.0
	footer_bg.content_margin_right = 0.0
	footer.add_theme_stylebox_override("panel", footer_bg)
	add_child(footer)

	var footer_vbox: VBoxContainer = VBoxContainer.new()
	footer_vbox.add_theme_constant_override("separation", 4)
	footer.add_child(footer_vbox)

	# === プレイヤー情報バー ===
	_player_info_bar = HBoxContainer.new()
	_player_info_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_info_bar.add_theme_constant_override("separation", 24)
	var info_margin: MarginContainer = MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 8)
	info_margin.add_theme_constant_override("margin_right", 8)
	info_margin.add_theme_constant_override("margin_top", 4)
	info_margin.add_theme_constant_override("margin_bottom", 4)
	info_margin.add_child(_player_info_bar)
	var info_bg: StyleBoxFlat = StyleBoxFlat.new()
	info_bg.bg_color = Color(0.15, 0.18, 0.28)
	info_margin.add_theme_stylebox_override("panel", info_bg)
	footer_vbox.add_child(info_margin)

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

	# 手札エリア
	var hand_scroll: ScrollContainer = ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 130)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_vbox.add_child(hand_scroll)

	var hand_margin: MarginContainer = MarginContainer.new()
	hand_margin.add_theme_constant_override("margin_left", 16)
	hand_margin.add_theme_constant_override("margin_right", 16)
	hand_margin.add_theme_constant_override("margin_top", 6)
	hand_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.add_child(hand_margin)

	_hand_container = HBoxContainer.new()
	_hand_container.add_theme_constant_override("separation", 6)
	_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_margin.add_child(_hand_container)

	# 入札ボタン
	var btn_center: CenterContainer = CenterContainer.new()
	footer_vbox.add_child(btn_center)

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
	for i: int in cards.size():
		var card: CardData = cards[i]
		var mini_card: CardDisplay = CardDisplay.new()
		mini_card.name = "CarriedCard_" + str(i) + "_val" + str(card.value)
		mini_card.custom_minimum_size = Vector2(36, 50)
		mini_card.size = Vector2(36, 50)
		_carried_over_container.add_child(mini_card)
		mini_card.setup(card, true)
		mini_card.set_font_sizes(12, 0)
		mini_card.set_value_only_mode()


# === シグナルハンドラ ===

func _on_phase_changed(new_phase: GameState.Phase) -> void:
	match new_phase:
		GameState.Phase.BIDDING:
			_bid_button.disabled = true
			_selected_card = null
			_enable_hand(true)
			_message_label.text = "カードを選んで入札してください"
			var stock: CardData = game_manager.state.current_stock_card
			if stock:
				if stock.is_positive():
					_guide_label.text = "入札額が一番[color=#66da80]高い[/color]人が獲得できます"
				else:
					_guide_label.text = "入札額が一番[color=#e66666]低い[/color]人が引き取ります"
				_guide_label.visible = true
			else:
				_guide_label.visible = false
		GameState.Phase.RESOLVING:
			_enable_hand(false)
			_message_label.text = "判定中..."
			_guide_label.visible = false
		GameState.Phase.ROUND_END:
			_message_label.text = ""
			_guide_label.visible = false
		GameState.Phase.GAME_OVER:
			_message_label.text = "ゲーム終了！"
			_guide_label.visible = false


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
		var off_is_positive: bool = _stock_card_display.card_data != null and _stock_card_display.card_data.is_positive()
		var bat_color: Color = Color(0.15, 0.75, 0.25) if not off_is_positive else Color(0.95, 0.15, 0.15)
		var bat_shield: bool = not off_is_positive
		for pid: Variant in _opponent_panels:
			var pid_int: int = pid as int
			if result.all_bids.has(pid_int) and result.batted_values.has(result.all_bids[pid_int] as int):
				(_opponent_panels[pid] as PlayerPanel).mark_batting(bat_color, bat_shield)
		if result.all_bids.has(_human_player_id):
			var my_bid: int = result.all_bids[_human_player_id] as int
			if result.batted_values.has(my_bid):
				for card_ui: CardDisplay in _hand_cards:
					if is_instance_valid(card_ui) and card_ui.card_data and card_ui.card_data.value == my_bid:
						card_ui.show_batting_mark(bat_color, bat_shield)

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
	# 最終ラウンドのアニメーション完了を待機
	while not _round_animation_complete:
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return

	await get_tree().create_timer(1.5).timeout
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
	if _is_online:
		if _online_phase != "bidding":
			return
	else:
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
	if _selected_card == null:
		return
	if _is_online:
		if _online_phase != "bidding":
			return
		GameEvents.sfx_requested.emit("bid_confirm")
		_bid_button.disabled = true
		_bid_button.text = "入札済み"
		_enable_hand(false)
		_online_phase = "bid_sent"
		_stop_bid_timer()
		if _network:
			_network.submit_bid(_selected_card.value)
		_selected_card = null
	else:
		if game_manager.state.phase != GameState.Phase.BIDDING:
			return
		GameEvents.sfx_requested.emit("bid_confirm")
		_bid_button.disabled = true
		_bid_button.text = "入札済み"
		_enable_hand(false)
		game_manager.submit_bid(_human_player_id, _selected_card.value)
		_selected_card = null


func _on_exit_pressed() -> void:
	# 確認ダイアログ
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.2, 0.28)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var msg: Label = Label.new()
	msg.text = "対戦を中断してタイトルに戻りますか？"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(msg)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	# キャンセルボタン
	var cancel_btn: Button = Button.new()
	cancel_btn.text = "続ける"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 20)
	var cancel_style: StyleBoxFlat = StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.3, 0.35, 0.45)
	cancel_style.corner_radius_top_left = 8
	cancel_style.corner_radius_top_right = 8
	cancel_style.corner_radius_bottom_left = 8
	cancel_style.corner_radius_bottom_right = 8
	cancel_style.content_margin_left = 16.0
	cancel_style.content_margin_right = 16.0
	cancel_style.content_margin_top = 8.0
	cancel_style.content_margin_bottom = 8.0
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	var cancel_hover: StyleBoxFlat = cancel_style.duplicate() as StyleBoxFlat
	cancel_hover.bg_color = Color(0.4, 0.45, 0.55)
	cancel_btn.add_theme_stylebox_override("hover", cancel_hover)
	cancel_btn.add_theme_color_override("font_color", Color.WHITE)
	cancel_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	cancel_btn.pressed.connect(func() -> void: overlay.queue_free())
	btn_row.add_child(cancel_btn)

	# 退出確定ボタン
	var confirm_btn: Button = Button.new()
	confirm_btn.text = "退出する"
	confirm_btn.custom_minimum_size = Vector2(140, 44)
	confirm_btn.add_theme_font_size_override("font_size", 20)
	var confirm_style: StyleBoxFlat = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.55, 0.2, 0.2)
	confirm_style.corner_radius_top_left = 8
	confirm_style.corner_radius_top_right = 8
	confirm_style.corner_radius_bottom_left = 8
	confirm_style.corner_radius_bottom_right = 8
	confirm_style.content_margin_left = 16.0
	confirm_style.content_margin_right = 16.0
	confirm_style.content_margin_top = 8.0
	confirm_style.content_margin_bottom = 8.0
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	var confirm_hover: StyleBoxFlat = confirm_style.duplicate() as StyleBoxFlat
	confirm_hover.bg_color = Color(0.65, 0.25, 0.25)
	confirm_btn.add_theme_stylebox_override("hover", confirm_hover)
	confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	confirm_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	confirm_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameEvents.back_to_title_requested.emit()
	)
	btn_row.add_child(confirm_btn)
