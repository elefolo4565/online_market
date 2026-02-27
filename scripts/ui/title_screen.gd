extends Control
## タイトル画面

var _bg: ColorRect = null


func _ready() -> void:
	_build_ui()
	GameEvents.bg_color_changed.connect(_on_bg_color_changed)


func _on_bg_color_changed(color: Color) -> void:
	if _bg:
		_bg.color = color


func _build_ui() -> void:
	# 背景
	_bg = ColorRect.new()
	_bg.color = AudioManager.get_bg_color()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# 中央揃えコンテナ
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 終了ボタン（右上 — centerより後に追加してクリックを受け取れるようにする）
	var quit_btn: Button = Button.new()
	quit_btn.text = "終了"
	quit_btn.add_theme_font_size_override("font_size", 16)
	var quit_style: StyleBoxFlat = StyleBoxFlat.new()
	quit_style.bg_color = Color(0.5, 0.2, 0.2)
	quit_style.corner_radius_top_left = 6
	quit_style.corner_radius_top_right = 6
	quit_style.corner_radius_bottom_left = 6
	quit_style.corner_radius_bottom_right = 6
	quit_style.content_margin_left = 12.0
	quit_style.content_margin_right = 12.0
	quit_style.content_margin_top = 4.0
	quit_style.content_margin_bottom = 4.0
	quit_btn.add_theme_stylebox_override("normal", quit_style)
	var quit_hover: StyleBoxFlat = quit_style.duplicate() as StyleBoxFlat
	quit_hover.bg_color = Color(0.6, 0.25, 0.25)
	quit_btn.add_theme_stylebox_override("hover", quit_hover)
	quit_btn.add_theme_color_override("font_color", Color.WHITE)
	quit_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	quit_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quit_btn.position = Vector2(-80, 12)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	add_child(quit_btn)

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

	# オンライン対戦ボタン
	var online_btn: Button = _create_button("オンライン対戦", Color(0.2, 0.4, 0.6))
	online_btn.pressed.connect(_on_online_pressed)
	btn_container.add_child(online_btn)

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


func _on_online_pressed() -> void:
	GameEvents.scene_change_requested.emit("online_lobby", {})


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
15ラウンド終了後、獲得した銘柄カードの合計点が最も高い人の勝ち！

[b]■ 攻略のヒント[/b]
・[color=#2a8c3a]高得点カード（+8〜+10）[/color]には大きい数字を温存しよう
・[color=red]暴落株（-）[/color]が出たら、相手が出しそうな小さい数字を読んでずらす
・バッティング狙いで相手と同じ数字をあえて出し、妨害するのも有効
・小さい得点カードに大きい入札を使うのはもったいない — メリハリが大事
・残りの手札と相手の使用済みカードを覚えておくと有利に"""
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

	# セパレータ（BGM / SFX）
	var sep_sfx: HSeparator = HSeparator.new()
	vbox.add_child(sep_sfx)

	# SFX ON/OFF
	var sfx_row: HBoxContainer = HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 12)
	vbox.add_child(sfx_row)

	var sfx_label: Label = Label.new()
	sfx_label.text = "効果音"
	sfx_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_label.add_theme_font_size_override("font_size", 22)
	sfx_label.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	sfx_row.add_child(sfx_label)

	var sfx_toggle: CheckButton = CheckButton.new()
	sfx_toggle.button_pressed = AudioManager.is_sfx_enabled()
	sfx_toggle.toggled.connect(func(enabled: bool) -> void:
		AudioManager.set_sfx_enabled(enabled)
	)
	sfx_row.add_child(sfx_toggle)

	# SFX 音量スライダー
	var sfx_vol_row: HBoxContainer = HBoxContainer.new()
	sfx_vol_row.add_theme_constant_override("separation", 12)
	vbox.add_child(sfx_vol_row)

	var sfx_vol_label: Label = Label.new()
	sfx_vol_label.text = "音量"
	sfx_vol_label.custom_minimum_size = Vector2(60, 0)
	sfx_vol_label.add_theme_font_size_override("font_size", 22)
	sfx_vol_label.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	sfx_vol_row.add_child(sfx_vol_label)

	var sfx_vol_slider: HSlider = HSlider.new()
	sfx_vol_slider.min_value = 0.0
	sfx_vol_slider.max_value = 1.0
	sfx_vol_slider.step = 0.01
	sfx_vol_slider.value = AudioManager.get_sfx_volume_linear()
	sfx_vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_vol_slider.custom_minimum_size = Vector2(250, 0)
	sfx_vol_slider.value_changed.connect(func(val: float) -> void:
		AudioManager.set_sfx_volume_linear(val)
	)
	sfx_vol_row.add_child(sfx_vol_slider)

	# セパレータ（SFX / 背景色）
	var sep2: HSeparator = HSeparator.new()
	vbox.add_child(sep2)

	# 背景色セクション
	var bg_label: Label = Label.new()
	bg_label.text = "背景色"
	bg_label.add_theme_font_size_override("font_size", 22)
	bg_label.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	vbox.add_child(bg_label)

	# プリセット色ボタン
	var presets: Array[Dictionary] = [
		{"name": "ダークネイビー", "color": Color(0.1, 0.13, 0.2)},
		{"name": "スカイブルー", "color": Color(0.55, 0.75, 0.9)},
		{"name": "フォレストグリーン", "color": Color(0.15, 0.3, 0.2)},
		{"name": "ワインレッド", "color": Color(0.35, 0.12, 0.15)},
		{"name": "ダークパープル", "color": Color(0.2, 0.12, 0.3)},
		{"name": "ウォームグレー", "color": Color(0.3, 0.28, 0.26)},
	]

	var preset_grid: GridContainer = GridContainer.new()
	preset_grid.columns = 3
	preset_grid.add_theme_constant_override("h_separation", 8)
	preset_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(preset_grid)

	var current_color: Color = AudioManager.get_bg_color()
	for preset: Dictionary in presets:
		var p_color: Color = preset["color"] as Color
		var p_name: String = preset["name"] as String
		var p_btn: Button = Button.new()
		p_btn.custom_minimum_size = Vector2(130, 40)
		p_btn.text = p_name
		p_btn.add_theme_font_size_override("font_size", 13)

		var p_style: StyleBoxFlat = StyleBoxFlat.new()
		p_style.bg_color = p_color
		p_style.corner_radius_top_left = 6
		p_style.corner_radius_top_right = 6
		p_style.corner_radius_bottom_left = 6
		p_style.corner_radius_bottom_right = 6
		p_style.content_margin_left = 8.0
		p_style.content_margin_right = 8.0
		p_style.content_margin_top = 6.0
		p_style.content_margin_bottom = 6.0
		# 選択中は枠線で示す
		if p_color.is_equal_approx(current_color):
			p_style.border_width_top = 3
			p_style.border_width_bottom = 3
			p_style.border_width_left = 3
			p_style.border_width_right = 3
			p_style.border_color = Color(0.95, 0.85, 0.4)
		p_btn.add_theme_stylebox_override("normal", p_style)

		var p_hover: StyleBoxFlat = p_style.duplicate() as StyleBoxFlat
		p_hover.bg_color = p_color.lightened(0.15)
		p_btn.add_theme_stylebox_override("hover", p_hover)

		p_btn.add_theme_color_override("font_color", Color.WHITE)
		p_btn.add_theme_color_override("font_hover_color", Color.WHITE)

		p_btn.pressed.connect(func() -> void:
			AudioManager.set_bg_color(p_color)
			overlay.queue_free()
			_show_settings_popup()
		)
		preset_grid.add_child(p_btn)

	# カスタムカラー
	var custom_row: HBoxContainer = HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 12)
	vbox.add_child(custom_row)

	var custom_label: Label = Label.new()
	custom_label.text = "カスタム"
	custom_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_label.add_theme_font_size_override("font_size", 22)
	custom_label.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	custom_row.add_child(custom_label)

	var color_picker_btn: ColorPickerButton = ColorPickerButton.new()
	color_picker_btn.color = AudioManager.get_bg_color()
	color_picker_btn.custom_minimum_size = Vector2(80, 36)
	color_picker_btn.color_changed.connect(func(color: Color) -> void:
		AudioManager.set_bg_color(color)
	)
	custom_row.add_child(color_picker_btn)

	# 閉じるボタン
	var btn_center: CenterContainer = CenterContainer.new()
	vbox.add_child(btn_center)

	var close_btn: Button = _create_button("閉じる", Color(0.35, 0.4, 0.55))
	close_btn.custom_minimum_size = Vector2(180, 48)
	close_btn.pressed.connect(func() -> void: overlay.queue_free())
	btn_center.add_child(close_btn)

	# 設定初期化ボタン（右下）
	var reset_row: HBoxContainer = HBoxContainer.new()
	reset_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(reset_row)

	var reset_btn: Button = Button.new()
	reset_btn.text = "設定を初期化"
	reset_btn.add_theme_font_size_override("font_size", 14)
	var reset_style: StyleBoxFlat = StyleBoxFlat.new()
	reset_style.bg_color = Color(0.5, 0.3, 0.3)
	reset_style.corner_radius_top_left = 4
	reset_style.corner_radius_top_right = 4
	reset_style.corner_radius_bottom_left = 4
	reset_style.corner_radius_bottom_right = 4
	reset_style.content_margin_left = 12.0
	reset_style.content_margin_right = 12.0
	reset_style.content_margin_top = 6.0
	reset_style.content_margin_bottom = 6.0
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	var reset_hover: StyleBoxFlat = reset_style.duplicate() as StyleBoxFlat
	reset_hover.bg_color = Color(0.6, 0.35, 0.35)
	reset_btn.add_theme_stylebox_override("hover", reset_hover)
	reset_btn.add_theme_color_override("font_color", Color.WHITE)
	reset_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	reset_btn.pressed.connect(func() -> void:
		AudioManager.reset_settings()
		overlay.queue_free()
		_show_settings_popup()
	)
	reset_row.add_child(reset_btn)
