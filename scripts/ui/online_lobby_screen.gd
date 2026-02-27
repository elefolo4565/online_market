extends Control
## オンラインロビー画面 — ルーム作成/参加/自動マッチング

enum LobbyState { MENU, CREATING, JOINING, MATCHING, WAITING }

var _state: LobbyState = LobbyState.MENU
var _network: NetworkClient = null
var _bg: ColorRect = null
var _main_vbox: VBoxContainer = null
var _content_container: VBoxContainer = null
var _status_label: Label = null
var _room_code_label: Label = null
var _player_list_container: VBoxContainer = null
var _player_name: String = "あなた"
var _player_count: int = 3
var _ai_difficulty: int = 1
var _room_code: String = ""
var _is_host: bool = false
var _my_player_id: int = -1
var _start_btn: Button = null


func _ready() -> void:
	_load_settings()
	_build_ui()
	_show_menu()
	GameEvents.bg_color_changed.connect(_on_bg_color_changed)


func _exit_tree() -> void:
	if _network:
		_network.leave()
		_network.close()
		_network.queue_free()
		_network = null


func _on_bg_color_changed(color: Color) -> void:
	if _bg:
		_bg.color = color


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		_player_name = config.get_value("player", "name", "あなた") as String


func _connect_to_server() -> void:
	if _network:
		_network.close()
		_network.queue_free()

	_network = NetworkClient.new()
	add_child(_network)
	_network.connected.connect(_on_connected)
	_network.disconnected.connect(_on_disconnected)
	_network.connection_error.connect(_on_connection_error)
	_network.message_received.connect(_on_message_received)
	_network.connect_to_server()


# === UI構築 ===

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = AudioManager.get_bg_color()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_main_vbox = VBoxContainer.new()
	_main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_vbox.add_theme_constant_override("separation", 20)
	_main_vbox.custom_minimum_size = Vector2(500, 0)
	center.add_child(_main_vbox)

	# タイトル
	var title: Label = Label.new()
	title.text = "オンライン対戦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_main_vbox.add_child(title)

	# ステータス
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_main_vbox.add_child(_status_label)

	# コンテンツ（状態に応じて切り替え）
	_content_container = VBoxContainer.new()
	_content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_container.add_theme_constant_override("separation", 12)
	_main_vbox.add_child(_content_container)


func _clear_content() -> void:
	for child: Node in _content_container.get_children():
		child.queue_free()


func _show_menu() -> void:
	_state = LobbyState.MENU
	_clear_content()
	_status_label.text = ""

	# プレイヤー名入力
	var name_row: HBoxContainer = _create_row("名前")
	var name_input: LineEdit = LineEdit.new()
	name_input.text = _player_name
	name_input.max_length = 12
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.add_theme_font_size_override("font_size", 20)
	name_input.text_changed.connect(func(t: String) -> void: _player_name = t)
	name_row.add_child(name_input)

	# 人数設定
	var count_row: HBoxContainer = _create_row("人数")
	var count_label: Label = Label.new()
	count_label.text = str(_player_count) + "人"
	count_label.add_theme_font_size_override("font_size", 22)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.custom_minimum_size = Vector2(60, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var minus_btn: Button = _create_small_button("-")
	minus_btn.pressed.connect(func() -> void:
		_player_count = max(GameConfig.MIN_PLAYERS, _player_count - 1)
		count_label.text = str(_player_count) + "人"
	)
	var plus_btn: Button = _create_small_button("+")
	plus_btn.pressed.connect(func() -> void:
		_player_count = min(GameConfig.MAX_PLAYERS, _player_count + 1)
		count_label.text = str(_player_count) + "人"
	)
	count_row.add_child(minus_btn)
	count_row.add_child(count_label)
	count_row.add_child(plus_btn)

	# セパレータ
	var sep: HSeparator = HSeparator.new()
	_content_container.add_child(sep)

	# ルーム作成ボタン
	var create_btn: Button = _create_action_button("ルームを作る", Color(0.28, 0.55, 0.35))
	create_btn.pressed.connect(_on_create_room)
	_content_container.add_child(create_btn)

	# ルームコード入力 + 参加
	var join_row: HBoxContainer = HBoxContainer.new()
	join_row.alignment = BoxContainer.ALIGNMENT_CENTER
	join_row.add_theme_constant_override("separation", 8)
	_content_container.add_child(join_row)

	var code_input: LineEdit = LineEdit.new()
	code_input.placeholder_text = "コード入力"
	code_input.max_length = 4
	code_input.custom_minimum_size = Vector2(140, 44)
	code_input.add_theme_font_size_override("font_size", 22)
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.text_changed.connect(func(t: String) -> void: _room_code = t.to_upper())
	join_row.add_child(code_input)

	var join_btn: Button = _create_action_button("参加する", Color(0.2, 0.4, 0.6))
	join_btn.custom_minimum_size = Vector2(140, 44)
	join_btn.pressed.connect(_on_join_room)
	join_row.add_child(join_btn)

	# 自動マッチング
	var match_btn: Button = _create_action_button("自動マッチング", Color(0.5, 0.35, 0.55))
	match_btn.pressed.connect(_on_auto_match)
	_content_container.add_child(match_btn)

	# 戻るボタン
	var back_btn: Button = _create_action_button("戻る", Color(0.4, 0.38, 0.5))
	back_btn.pressed.connect(func() -> void: GameEvents.back_to_title_requested.emit())
	_content_container.add_child(back_btn)


func _show_waiting_room(players: Array) -> void:
	_state = LobbyState.WAITING
	_clear_content()

	# ルームコード表示
	_room_code_label = Label.new()
	_room_code_label.text = "ルームコード: " + _room_code
	_room_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_code_label.add_theme_font_size_override("font_size", 28)
	_room_code_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_content_container.add_child(_room_code_label)

	_status_label.text = "プレイヤーを待っています..."

	# プレイヤーリスト
	_player_list_container = VBoxContainer.new()
	_player_list_container.add_theme_constant_override("separation", 6)
	_content_container.add_child(_player_list_container)
	_update_player_list(players)

	# ホスト用ボタン
	if _is_host:
		var btn_row: HBoxContainer = HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 8)
		_content_container.add_child(btn_row)

		var ai_btn: Button = _create_action_button("AI追加", Color(0.35, 0.4, 0.55))
		ai_btn.custom_minimum_size = Vector2(130, 44)
		ai_btn.pressed.connect(func() -> void:
			if _network:
				_network.add_ai(_ai_difficulty)
		)
		btn_row.add_child(ai_btn)

		var remove_ai_btn: Button = _create_action_button("AI削除", Color(0.5, 0.35, 0.35))
		remove_ai_btn.custom_minimum_size = Vector2(130, 44)
		remove_ai_btn.pressed.connect(func() -> void:
			if _network:
				_network.remove_ai()
		)
		btn_row.add_child(remove_ai_btn)

		_start_btn = _create_action_button("ゲーム開始", Color(0.28, 0.55, 0.35))
		_start_btn.pressed.connect(func() -> void:
			if _network:
				_network.start_game()
		)
		_content_container.add_child(_start_btn)

	# 退出ボタン
	var leave_btn: Button = _create_action_button("退出", Color(0.5, 0.2, 0.2))
	leave_btn.pressed.connect(func() -> void:
		if _network:
			_network.leave()
			_network.close()
		_show_menu()
	)
	_content_container.add_child(leave_btn)


func _update_player_list(players: Array) -> void:
	if not _player_list_container:
		return
	for child: Node in _player_list_container.get_children():
		child.queue_free()

	for p: Variant in players:
		var pdict: Dictionary = p as Dictionary
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_player_list_container.add_child(row)

		var icon_label: Label = Label.new()
		if pdict.get("is_ai", false):
			icon_label.text = "[AI]"
			icon_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		else:
			icon_label.text = "[人]"
			icon_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
		icon_label.add_theme_font_size_override("font_size", 18)
		row.add_child(icon_label)

		var name_label: Label = Label.new()
		name_label.text = pdict.get("name", "???") as String
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(name_label)

	# 開始ボタンの有効/無効
	if _start_btn and is_instance_valid(_start_btn):
		_start_btn.disabled = players.size() < GameConfig.MIN_PLAYERS


func _show_matching() -> void:
	_state = LobbyState.MATCHING
	_clear_content()
	_status_label.text = "マッチング中..."

	var cancel_btn: Button = _create_action_button("キャンセル", Color(0.5, 0.2, 0.2))
	cancel_btn.pressed.connect(func() -> void:
		if _network:
			_network.cancel_match()
			_network.close()
		_show_menu()
	)
	_content_container.add_child(cancel_btn)


# === ネットワークイベント ===

var _pending_action: String = ""

func _on_connected() -> void:
	match _pending_action:
		"create":
			_network.create_room(_player_name, _player_count, _ai_difficulty)
		"join":
			_network.join_room(_room_code, _player_name)
		"match":
			_network.auto_match(_player_name, _player_count)


func _on_disconnected() -> void:
	_status_label.text = "サーバーから切断されました"
	if _state != LobbyState.MENU:
		_show_menu()


func _on_connection_error(msg: String) -> void:
	_status_label.text = msg
	if _state != LobbyState.MENU:
		_show_menu()


func _on_message_received(msg_type: String, data: Dictionary) -> void:
	match msg_type:
		NetworkProtocol.ROOM_CREATED:
			_room_code = data.get("room_code", "") as String
			_my_player_id = data.get("player_id", -1) as int
			_is_host = true
			var players: Array = data.get("players", []) as Array
			_show_waiting_room(players)

		NetworkProtocol.ROOM_JOINED:
			_room_code = data.get("room_code", "") as String
			_my_player_id = data.get("player_id", -1) as int
			var players: Array = data.get("players", []) as Array
			_show_waiting_room(players)

		NetworkProtocol.PLAYER_JOINED:
			var players: Array = data.get("players", []) as Array
			_update_player_list(players)
			_status_label.text = "プレイヤーが参加しました"

		NetworkProtocol.PLAYER_LEFT:
			var players: Array = data.get("players", []) as Array
			_update_player_list(players)
			_status_label.text = "プレイヤーが退出しました"

		NetworkProtocol.MATCH_FOUND:
			_room_code = data.get("room_code", "") as String
			_status_label.text = "マッチング成立！"

		NetworkProtocol.GAME_START:
			# ゲーム画面に遷移（ネットワーク情報を渡す）
			var params: Dictionary = {
				"online": true,
				"network": _network,
				"players": data.get("players", []),
				"your_hand": data.get("your_hand", []),
				"your_id": data.get("your_id", 0),
			}
			# _networkの所有権をゲーム画面に移す
			_network.get_parent().remove_child(_network)
			_network = null
			GameEvents.scene_change_requested.emit("game", params)

		NetworkProtocol.ERROR:
			_status_label.text = data.get("message", "エラー") as String


# === ボタンアクション ===

func _on_create_room() -> void:
	_status_label.text = "サーバーに接続中..."
	_pending_action = "create"
	_is_host = true
	_connect_to_server()


func _on_join_room() -> void:
	if _room_code.length() != 4:
		_status_label.text = "4文字のルームコードを入力してください"
		return
	_status_label.text = "サーバーに接続中..."
	_pending_action = "join"
	_is_host = false
	_connect_to_server()


func _on_auto_match() -> void:
	_status_label.text = "サーバーに接続中..."
	_pending_action = "match"
	_is_host = false
	_connect_to_server()
	_show_matching()


# === UIヘルパー ===

func _create_row(label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_container.add_child(row)

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(60, 0)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	row.add_child(label)

	return row


func _create_action_button(text: String, color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 50)
	btn.add_theme_font_size_override("font_size", 22)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	btn.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var disabled_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.3, 0.32, 0.35)
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))

	return btn


func _create_small_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(40, 36)
	btn.add_theme_font_size_override("font_size", 20)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.35, 0.45)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.4, 0.45, 0.55)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	return btn
