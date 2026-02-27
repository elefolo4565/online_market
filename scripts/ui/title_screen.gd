extends Control
## タイトル画面


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# 背景
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.12, 0.15, 0.22)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 中央揃えコンテナ
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# メインコンテナ
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 30)
	vbox.custom_minimum_size = Vector2(600, 400)
	center.add_child(vbox)

	# タイトルラベル
	var title_label: Label = Label.new()
	title_label.text = "セカンダリー\nマーケット"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	vbox.add_child(title_label)

	# サブタイトル
	var subtitle: Label = Label.new()
	subtitle.text = "— 入札と駆け引きのカードゲーム —"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(subtitle)

	# スペーサー
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	# ボタンコンテナ
	var btn_container: VBoxContainer = VBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_container)

	# 対戦開始ボタン
	var play_btn: Button = _create_button("対戦開始", Color(0.28, 0.55, 0.35))
	play_btn.pressed.connect(_on_play_pressed)
	btn_container.add_child(play_btn)

	# ルール説明ボタン
	var rules_btn: Button = _create_button("ルール説明", Color(0.35, 0.4, 0.55))
	rules_btn.pressed.connect(_on_rules_pressed)
	btn_container.add_child(rules_btn)

	# 設定ボタン
	var settings_btn: Button = _create_button("設定", Color(0.4, 0.38, 0.5))
	settings_btn.pressed.connect(_on_settings_pressed)
	btn_container.add_child(settings_btn)


func _create_button(text: String, color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 56)
	btn.add_theme_font_size_override("font_size", 24)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover_style.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))

	return btn


func _on_play_pressed() -> void:
	GameEvents.scene_change_requested.emit("lobby", {})


func _on_rules_pressed() -> void:
	_show_rules_popup()


func _on_settings_pressed() -> void:
	_show_settings_popup()


func _show_rules_popup() -> void:
	var rules_font: Font = load("res://assets/fonts/KosugiMaru-Regular.ttf") as Font
	var heading_font: Font = load("res://assets/fonts/DelaGothicOne-Regular.ttf") as Font

	# 半透明オーバーレイ
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# パネルを画面いっぱいに表示
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(panel)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.95, 0.93, 0.88)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# タイトル
	var title: Label = Label.new()
	title.text = "ルール説明"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	title.add_theme_font_override("font", heading_font)
	vbox.add_child(title)

	# セパレータ
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# ルール本文（スクロール可能）
	var body: RichTextLabel = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = false
	body.scroll_active = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(460, 200)
	body.add_theme_font_size_override("normal_font_size", 18)
	body.add_theme_font_size_override("bold_font_size", 18)
	body.add_theme_color_override("default_color", Color(0.2, 0.18, 0.15))
	body.add_theme_font_override("normal_font", rules_font)
	body.add_theme_font_override("bold_font", rules_font)
	body.text = """[b]■ 概要[/b]
銘柄カード（得点カード）を入札で競り合うゲームです。
15ラウンドで最も多くの資産を獲得した人が勝ちです。

[b]■ カード構成[/b]
・銘柄カード: [color=#2a8c3a]+1〜+10[/color]（成長株）と [color=red]-1〜-5[/color]（暴落株）の計15枚
・入札カード: 1〜15の15枚（各プレイヤーが所持）

[b]■ ラウンドの流れ[/b]
1. 銘柄カードを1枚めくる
2. 全員同時に入札カードを1枚出す
3. 成長株(+): [color=#2a8c3a]最大の数字[/color]の人が獲得
   暴落株(-): [color=red]最小の数字[/color]の人が引き取る

[b]■ バッティング[/b]
同じ数字を出した人は無効！次の候補者が獲得します。
全員バッティングした場合は次のラウンドに持ち越し。

[b]■ 勝利条件[/b]
15ラウンド終了後、獲得した銘柄カードの合計点が最も高い人の勝ち！"""
	vbox.add_child(body)

	# 閉じるボタン
	var btn_center: CenterContainer = CenterContainer.new()
	vbox.add_child(btn_center)

	var close_btn: Button = _create_button("閉じる", Color(0.35, 0.4, 0.55))
	close_btn.custom_minimum_size = Vector2(180, 48)
	close_btn.add_theme_font_override("font", heading_font)
	close_btn.pressed.connect(func() -> void: overlay.queue_free())
	btn_center.add_child(close_btn)


func _show_settings_popup() -> void:
	# 半透明オーバーレイ
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# パネル（中央配置）
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.95, 0.93, 0.88)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 32.0
	panel_style.content_margin_right = 32.0
	panel_style.content_margin_top = 28.0
	panel_style.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# タイトル
	var title: Label = Label.new()
	title.text = "設定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	vbox.add_child(title)

	# セパレータ
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# BGM ON/OFF
	var bgm_row: HBoxContainer = HBoxContainer.new()
	bgm_row.add_theme_constant_override("separation", 12)
	vbox.add_child(bgm_row)

	var bgm_label: Label = Label.new()
	bgm_label.text = "BGM"
	bgm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_label.add_theme_font_size_override("font_size", 22)
	bgm_label.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	bgm_row.add_child(bgm_label)

	var bgm_toggle: CheckButton = CheckButton.new()
	bgm_toggle.button_pressed = AudioManager.is_bgm_enabled()
	bgm_toggle.toggled.connect(func(enabled: bool) -> void:
		AudioManager.set_bgm_enabled(enabled)
	)
	bgm_row.add_child(bgm_toggle)

	# BGM 音量スライダー
	var vol_row: HBoxContainer = HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	vbox.add_child(vol_row)

	var vol_label: Label = Label.new()
	vol_label.text = "音量"
	vol_label.custom_minimum_size = Vector2(60, 0)
	vol_label.add_theme_font_size_override("font_size", 22)
	vol_label.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	vol_row.add_child(vol_label)

	var vol_slider: HSlider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.01
	vol_slider.value = AudioManager.get_bgm_volume_linear()
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.custom_minimum_size = Vector2(250, 0)
	vol_slider.value_changed.connect(func(val: float) -> void:
		AudioManager.set_bgm_volume_linear(val)
	)
	vol_row.add_child(vol_slider)

	# 閉じるボタン
	var btn_center: CenterContainer = CenterContainer.new()
	vbox.add_child(btn_center)

	var close_btn: Button = _create_button("閉じる", Color(0.35, 0.4, 0.55))
	close_btn.custom_minimum_size = Vector2(180, 48)
	close_btn.pressed.connect(func() -> void: overlay.queue_free())
	btn_center.add_child(close_btn)
