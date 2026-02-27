extends Control
## ロビー画面 — プレイヤー数・AI設定

const AI_NAMES: Array[String] = [
	"田中", "鈴木", "佐藤", "山本", "渡辺",
	"伊藤", "中村", "小林", "加藤", "吉田",
]
const SETTINGS_PATH: String = "user://settings.cfg"

var _player_count: int = 4
var _ai_difficulty: int = 1
var _player_name: String = "あなた"
var _bg: ColorRect
var _count_label: Label
var _difficulty_label: Label
var _name_edit: LineEdit


func _ready() -> void:
	_load_settings()
	_build_ui()
	GameEvents.bg_color_changed.connect(_on_bg_color_changed)


func _on_bg_color_changed(color: Color) -> void:
	_bg.color = color


func _build_ui() -> void:
	# 背景
	_bg = ColorRect.new()
	_bg.color = AudioManager.get_bg_color()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# スクロール対応のメインコンテナ
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# タイトル
	var title: Label = Label.new()
	title.text = "対戦設定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	vbox.add_child(title)

	# --- プレイヤー名 ---
	var name_section: VBoxContainer = _create_section("プレイヤー名")
	vbox.add_child(name_section)

	_name_edit = LineEdit.new()
	_name_edit.text = _player_name
	_name_edit.placeholder_text = "名前を入力..."
	_name_edit.max_length = 12
	_name_edit.custom_minimum_size = Vector2(300, 44)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.text_changed.connect(func(new_text: String) -> void: _player_name = new_text)
	_name_edit.focus_entered.connect(_on_name_edit_focus_entered)
	_name_edit.focus_exited.connect(_on_name_edit_focus_exited)
	name_section.add_child(_name_edit)

	# --- プレイヤー人数 ---
	var count_section: VBoxContainer = _create_section("参加人数（AI含む）")
	vbox.add_child(count_section)

	var count_row: HBoxContainer = HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 16)
	count_section.add_child(count_row)

	var minus_btn: Button = _create_small_button("-")
	minus_btn.pressed.connect(_on_count_minus)
	count_row.add_child(minus_btn)

	_count_label = Label.new()
	_count_label.text = str(_player_count) + "人"
	_count_label.custom_minimum_size = Vector2(80, 0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 32)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	count_row.add_child(_count_label)

	var plus_btn: Button = _create_small_button("+")
	plus_btn.pressed.connect(_on_count_plus)
	count_row.add_child(plus_btn)

	# --- AI難易度 ---
	var diff_section: VBoxContainer = _create_section("AI難易度")
	vbox.add_child(diff_section)

	var diff_row: HBoxContainer = HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 16)
	diff_section.add_child(diff_row)

	var diff_minus: Button = _create_small_button("<")
	diff_minus.pressed.connect(_on_diff_minus)
	diff_row.add_child(diff_minus)

	_difficulty_label = Label.new()
	_difficulty_label.text = AIPlayer.get_difficulty_name(_ai_difficulty)
	_difficulty_label.custom_minimum_size = Vector2(200, 0)
	_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_difficulty_label.add_theme_font_size_override("font_size", 26)
	_difficulty_label.add_theme_color_override("font_color", Color.WHITE)
	diff_row.add_child(_difficulty_label)

	var diff_plus: Button = _create_small_button(">")
	diff_plus.pressed.connect(_on_diff_plus)
	diff_row.add_child(diff_plus)

	# スペーサー
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# --- ボタン ---
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var back_btn: Button = _create_action_button("戻る", Color(0.5, 0.45, 0.4))
	back_btn.pressed.connect(_on_back_pressed)
	btn_row.add_child(back_btn)

	var start_btn: Button = _create_action_button("ゲーム開始", Color(0.28, 0.55, 0.35))
	start_btn.pressed.connect(_on_start_pressed)
	btn_row.add_child(start_btn)


func _create_section(title_text: String) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var label: Label = Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(label)

	return section


func _create_small_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(52, 52)
	btn.add_theme_font_size_override("font_size", 28)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.35, 0.45)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.4, 0.45, 0.55)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	return btn


func _create_action_button(text: String, color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 52)
	btn.add_theme_font_size_override("font_size", 24)

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

	var pressed: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	return btn


func _on_count_minus() -> void:
	_player_count = maxi(_player_count - 1, GameConfig.MIN_PLAYERS)
	_count_label.text = str(_player_count) + "人"


func _on_count_plus() -> void:
	_player_count = mini(_player_count + 1, GameConfig.MAX_PLAYERS)
	_count_label.text = str(_player_count) + "人"


func _on_diff_minus() -> void:
	_ai_difficulty = maxi(_ai_difficulty - 1, 0)
	_difficulty_label.text = AIPlayer.get_difficulty_name(_ai_difficulty)


func _on_diff_plus() -> void:
	_ai_difficulty = mini(_ai_difficulty + 1, 2)
	_difficulty_label.text = AIPlayer.get_difficulty_name(_ai_difficulty)


func _on_back_pressed() -> void:
	GameEvents.back_to_title_requested.emit()


func _on_name_edit_focus_entered() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_show(_name_edit.text)


func _on_name_edit_focus_exited() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_hide()


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_player_name = config.get_value("player", "name", "あなた") as String
		_player_count = config.get_value("game", "player_count", 4) as int
		_ai_difficulty = config.get_value("game", "ai_difficulty", 1) as int
		_player_count = clampi(_player_count, GameConfig.MIN_PLAYERS, GameConfig.MAX_PLAYERS)
		_ai_difficulty = clampi(_ai_difficulty, 0, 2)


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("player", "name", _player_name)
	config.set_value("game", "player_count", _player_count)
	config.set_value("game", "ai_difficulty", _ai_difficulty)
	config.save(SETTINGS_PATH)


func _on_start_pressed() -> void:
	if _name_edit.text.strip_edges().is_empty():
		_player_name = "あなた"
	else:
		_player_name = _name_edit.text.strip_edges()

	_save_settings()

	var configs: Array[Dictionary] = []
	# プレイヤー（人間）
	configs.append({
		"name": _player_name,
		"is_ai": false,
		"ai_difficulty": 0,
	})
	# AI
	var shuffled_names: Array[String] = AI_NAMES.duplicate()
	shuffled_names.shuffle()
	for i: int in range(_player_count - 1):
		configs.append({
			"name": shuffled_names[i],
			"is_ai": true,
			"ai_difficulty": _ai_difficulty,
		})

	GameEvents.scene_change_requested.emit("game", {"player_configs": configs})
