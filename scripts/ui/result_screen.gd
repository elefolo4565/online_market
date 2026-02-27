extends Control
## リザルト画面 — ゲーム結果表示

var _rankings: Array[Dictionary] = []


func init_with_params(params: Dictionary) -> void:
	_rankings = []
	var raw: Variant = params.get("rankings", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				_rankings.append(item as Dictionary)
	_build_results()


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# 背景
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.13, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build_results() -> void:
	GameEvents.sfx_requested.emit("game_over")

	# スクロール対応
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# タイトル
	var title: Label = Label.new()
	title.text = "取引結果"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	vbox.add_child(title)

	# ランキング表示
	for i: int in range(_rankings.size()):
		var entry: Dictionary = _rankings[i]
		var rank: int = i + 1
		var panel: PanelContainer = _create_rank_panel(
			rank,
			entry.get("name", "???") as String,
			entry.get("score", 0) as int,
			entry.get("is_ai", true) as bool
		)
		vbox.add_child(panel)

		# アニメーション: フェードイン（positionはコンテナが管理するため変更しない）
		panel.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.4) \
			.set_delay(float(i) * 0.15) \
			.set_ease(Tween.EASE_OUT)

	# スペーサー
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# ボタン
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var title_btn: Button = _create_button("タイトルに戻る", Color(0.5, 0.45, 0.4))
	title_btn.pressed.connect(func() -> void: GameEvents.back_to_title_requested.emit())
	btn_row.add_child(title_btn)

	var retry_btn: Button = _create_button("もう一度", Color(0.28, 0.55, 0.35))
	retry_btn.pressed.connect(func() -> void: GameEvents.scene_change_requested.emit("lobby", {}))
	btn_row.add_child(retry_btn)


func _create_rank_panel(rank: int, player_name: String, score: int, is_ai: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)

	var bg_color: Color
	match rank:
		1: bg_color = Color(0.35, 0.45, 0.2, 0.9)  # 金
		2: bg_color = Color(0.3, 0.35, 0.4, 0.9)    # 銀
		3: bg_color = Color(0.35, 0.28, 0.2, 0.9)    # 銅
		_: bg_color = Color(0.2, 0.22, 0.3, 0.9)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	# 順位
	var rank_label: Label = Label.new()
	var rank_text: String
	match rank:
		1: rank_text = "1st"
		2: rank_text = "2nd"
		3: rank_text = "3rd"
		_: rank_text = str(rank) + "th"
	rank_label.text = rank_text
	rank_label.custom_minimum_size = Vector2(100, 0)
	rank_label.add_theme_font_size_override("font_size", 28)
	rank_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4) if rank == 1 else Color.WHITE)
	hbox.add_child(rank_label)

	# 名前
	var name_label: Label = Label.new()
	var display_text: String = player_name
	if is_ai:
		display_text += " (AI)"
	name_label.text = display_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(name_label)

	# スコア
	var score_label: Label = Label.new()
	score_label.text = str(score) + "pt"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.custom_minimum_size = Vector2(100, 0)
	score_label.add_theme_font_size_override("font_size", 28)
	var score_color: Color = Color(0.4, 0.85, 0.5) if score >= 0 else Color(0.9, 0.4, 0.4)
	score_label.add_theme_color_override("font_color", score_color)
	hbox.add_child(score_label)

	return panel


func _create_button(text: String, color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 50)
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

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	return btn
