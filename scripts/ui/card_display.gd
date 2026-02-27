class_name CardDisplay
extends Control
## カード表示コンポーネント — _draw() で動的描画

signal card_clicked(card_data: CardData)

var card_data: CardData = null
var is_face_up: bool = true
var is_selectable: bool = false
var is_selected: bool = false
var is_batted: bool = false
var _batting_anim_progress: float = 0.0
var is_won: bool = false
var _win_anim_progress: float = 0.0
var _win_color: Color = Color.GREEN
var _tween: Tween = null
var _value_label: Label = null
var _name_label: Label = null
var _base_position_y: float = 0.0
var _base_position_saved: bool = false


func _ready() -> void:
	clip_contents = true

	# 数値ラベル（上部60%、左右4pxマージン）
	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 28)
	_value_label.anchor_left = 0.0
	_value_label.anchor_top = 0.1
	_value_label.anchor_right = 1.0
	_value_label.anchor_bottom = 0.6
	_value_label.offset_left = 4
	_value_label.offset_top = 0
	_value_label.offset_right = -4
	_value_label.offset_bottom = 0
	add_child(_value_label)

	# 名前ラベル（下部40%、横いっぱい）
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.anchor_left = 0.0
	_name_label.anchor_top = 0.6
	_name_label.anchor_right = 1.0
	_name_label.anchor_bottom = 1.0
	_name_label.offset_left = 0
	_name_label.offset_top = 0
	_name_label.offset_right = 0
	_name_label.offset_bottom = 0
	add_child(_name_label)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_labels()


func setup(data: CardData, face_up: bool = true) -> void:
	card_data = data
	is_face_up = face_up
	is_batted = false
	_batting_anim_progress = 0.0
	is_won = false
	_win_anim_progress = 0.0
	_update_labels()
	queue_redraw()


func set_font_sizes(value_size: int, name_size: int) -> void:
	if _value_label:
		_value_label.add_theme_font_size_override("font_size", value_size)
	if _name_label:
		_name_label.add_theme_font_size_override("font_size", name_size)


func set_selected(selected: bool) -> void:
	if is_selected == selected:
		return
	is_selected = selected
	_animate_selection()
	queue_redraw()


func flip(face_up: bool) -> void:
	if is_face_up == face_up:
		return
	is_face_up = face_up
	_animate_flip()


func _update_labels() -> void:
	if _value_label == null:
		return
	if card_data == null or not is_face_up:
		_value_label.text = ""
		_name_label.text = ""
		return

	# 数値表示
	if card_data.value > 0:
		_value_label.text = "+" + str(card_data.value)
	else:
		_value_label.text = str(card_data.value)

	# 名前表示（入札カードは「億」表記）
	if card_data.card_type == CardData.CardType.BID:
		_value_label.text = str(card_data.value)
		_name_label.text = "億"
	else:
		_name_label.text = card_data.display_name

	# 色設定
	var font_color: Color = _get_font_color()
	_value_label.add_theme_color_override("font_color", font_color)
	_name_label.add_theme_color_override("font_color", font_color.darkened(0.1))

	_layout_labels()


func _layout_labels() -> void:
	# アンカーで自動レイアウトされるため手動計算は不要
	pass


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)

	if is_face_up and card_data:
		# カード背景
		var bg_color: Color = _get_card_color()
		draw_rect(rect, bg_color, true)

		# 枠線
		var border_color: Color = bg_color.darkened(0.3)
		draw_rect(rect, border_color, false, 2.0)

		# 選択中ハイライト
		if is_selected:
			draw_rect(rect, Color(1.0, 0.85, 0.0, 0.25), true)
			draw_rect(rect, Color(1.0, 0.85, 0.0), false, 3.0)

		# バッティングバツマーク
		if is_batted and _batting_anim_progress > 0.0:
			var cx: float = size.x * 0.5
			var cy: float = size.y * 0.5
			var arm: float = minf(size.x, size.y) * 0.45 * _batting_anim_progress
			var line_w: float = 5.0 * _batting_anim_progress
			var x_color: Color = Color(0.95, 0.15, 0.15, _batting_anim_progress)
			draw_line(Vector2(cx - arm, cy - arm), Vector2(cx + arm, cy + arm), x_color, line_w)
			draw_line(Vector2(cx + arm, cy - arm), Vector2(cx - arm, cy + arm), x_color, line_w)

		# 落札丸マーク
		if is_won and _win_anim_progress > 0.0:
			var cx2: float = size.x * 0.5
			var cy2: float = size.y * 0.5
			var radius: float = minf(size.x, size.y) * 0.45 * _win_anim_progress
			var line_w2: float = 5.0 * _win_anim_progress
			var circle_color: Color = Color(_win_color, _win_anim_progress)
			draw_arc(Vector2(cx2, cy2), radius, 0.0, TAU, 64, circle_color, line_w2)
	else:
		# 裏面
		draw_rect(rect, Color(0.2, 0.3, 0.5), true)
		# パターン
		var inner: Rect2 = rect.grow(-4)
		draw_rect(inner, Color(0.25, 0.35, 0.55), false, 1.5)
		# 中央に「？」
		draw_rect(rect, Color(0.15, 0.25, 0.42), false, 2.0)


func _get_card_color() -> Color:
	if card_data == null:
		return Color.GRAY
	match card_data.card_type:
		CardData.CardType.STOCK:
			var t: float = float(card_data.value) / 10.0
			return Color(1.0, 0.95 - t * 0.15, 0.75 - t * 0.35)
		CardData.CardType.VULTURE:
			var t: float = absf(float(card_data.value)) / 5.0
			return Color(0.55 + t * 0.1, 0.2, 0.25 + t * 0.1)
		CardData.CardType.BID:
			return Color(0.85, 0.93, 0.88)
	return Color.WHITE


func _get_font_color() -> Color:
	if card_data == null:
		return Color.BLACK
	match card_data.card_type:
		CardData.CardType.STOCK:
			return Color(0.15, 0.1, 0.05)
		CardData.CardType.VULTURE:
			return Color(1.0, 0.9, 0.85)
		CardData.CardType.BID:
			return Color(0.1, 0.2, 0.15)
	return Color.BLACK


func show_lose_effect() -> void:
	var lt: Tween = create_tween()
	lt.set_parallel(true)
	lt.tween_property(self, "modulate", Color(0.5, 0.5, 0.55), 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	lt.tween_property(self, "rotation", deg_to_rad(5.0), 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func show_batting_mark() -> void:
	is_batted = true
	_batting_anim_progress = 0.0
	var bt: Tween = create_tween()
	bt.tween_method(_set_batting_progress, 0.0, 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _set_batting_progress(value: float) -> void:
	_batting_anim_progress = value
	queue_redraw()


func show_win_mark(is_positive: bool) -> void:
	is_won = true
	_win_anim_progress = 0.0
	_win_color = Color(0.15, 0.75, 0.25) if is_positive else Color(0.95, 0.15, 0.15)
	var wt: Tween = create_tween()
	wt.tween_method(_set_win_progress, 0.0, 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _set_win_progress(value: float) -> void:
	_win_anim_progress = value
	queue_redraw()


func _animate_flip() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale:x", 0.0, 0.12)
	_tween.tween_callback(_update_labels)
	_tween.tween_callback(queue_redraw)
	_tween.tween_property(self, "scale:x", 1.0, 0.12)


func _animate_selection() -> void:
	if not _base_position_saved:
		_base_position_y = position.y
		_base_position_saved = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var target_y: float = _base_position_y + (-12.0 if is_selected else 0.0)
	_tween.tween_property(self, "position:y", target_y, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_mouse_entered() -> void:
	if is_selectable and not is_selected:
		modulate = Color(1.1, 1.1, 1.15)


func _on_mouse_exited() -> void:
	if is_selectable:
		modulate = Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if not is_selectable:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(card_data)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			card_clicked.emit(card_data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_labels()
		queue_redraw()
