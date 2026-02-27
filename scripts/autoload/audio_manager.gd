extends Node
## BGM・SFX管理（Autoload）
## 音量・ON/OFF設定をConfigFileで永続化

const CONFIG_PATH: String = "user://audio_settings.cfg"
const BGM_BUS: String = "Master"
const SFX_POOL_SIZE: int = 4

var _bgm_player: AudioStreamPlayer = null
var _bgm_enabled: bool = true
var _bgm_volume_db: float = 0.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}  ## {String -> AudioStreamWAV}
var _sfx_enabled: bool = true
var _sfx_volume_db: float = 0.0

const DEFAULT_BG_COLOR: Color = Color(0.1, 0.13, 0.2)
var _bg_color: Color = DEFAULT_BG_COLOR

## 設定変更通知
signal bgm_settings_changed()
signal sfx_settings_changed()


func _ready() -> void:
	_load_settings()
	_setup_bgm_player()
	_setup_sfx()
	GameEvents.sfx_requested.connect(play_sfx)


func _setup_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BGM_BUS
	_bgm_player.volume_db = _bgm_volume_db
	add_child(_bgm_player)
	# BGMをロードして再生
	var stream: AudioStream = load("res://assets/sounds/盤面の闘い.mp3") as AudioStream
	if stream:
		# MP3のループ設定
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_bgm_player.stream = stream
		if _bgm_enabled:
			_bgm_player.play()


func _setup_sfx() -> void:
	# SFXプレイヤープール作成
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BGM_BUS
		player.volume_db = _sfx_volume_db
		add_child(player)
		_sfx_players.append(player)

	# 全SEを事前生成・キャッシュ
	_sfx_streams["card_select"] = SfxGenerator.card_select()
	_sfx_streams["bid_confirm"] = SfxGenerator.bid_confirm()
	_sfx_streams["card_reveal"] = SfxGenerator.card_reveal()
	_sfx_streams["bid_reveal"] = SfxGenerator.bid_reveal()
	_sfx_streams["batting"] = SfxGenerator.batting()
	_sfx_streams["gain"] = SfxGenerator.gain()
	_sfx_streams["loss"] = SfxGenerator.loss()
	_sfx_streams["game_over"] = SfxGenerator.game_over()


## SFX再生（空いているプレイヤーを使用）
func play_sfx(sfx_name: String) -> void:
	if not _sfx_enabled:
		return
	if not _sfx_streams.has(sfx_name):
		push_warning("Unknown SFX: " + sfx_name)
		return

	var stream: AudioStreamWAV = _sfx_streams[sfx_name] as AudioStreamWAV
	# 空いているプレイヤーを探す
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = _sfx_volume_db
			player.play()
			return
	# 全て使用中なら最初のプレイヤーを強制再利用
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = _sfx_volume_db
	_sfx_players[0].play()


# === BGM設定 ===

func set_bgm_enabled(enabled: bool) -> void:
	_bgm_enabled = enabled
	if _bgm_player:
		if _bgm_enabled:
			if not _bgm_player.playing:
				_bgm_player.play()
		else:
			_bgm_player.stop()
	_save_settings()
	bgm_settings_changed.emit()


func is_bgm_enabled() -> bool:
	return _bgm_enabled


func set_bgm_volume_db(volume_db: float) -> void:
	_bgm_volume_db = volume_db
	if _bgm_player:
		_bgm_player.volume_db = _bgm_volume_db
	_save_settings()
	bgm_settings_changed.emit()


func get_bgm_volume_db() -> float:
	return _bgm_volume_db


## dB値を0.0〜1.0の線形値に変換
func get_bgm_volume_linear() -> float:
	return db_to_linear(_bgm_volume_db)


## 0.0〜1.0の線形値をdBに変換して設定
func set_bgm_volume_linear(linear: float) -> void:
	var clamped: float = clampf(linear, 0.0, 1.0)
	if clamped < 0.01:
		set_bgm_volume_db(-80.0)
	else:
		set_bgm_volume_db(linear_to_db(clamped))


# === SFX設定 ===

func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled
	_save_settings()
	sfx_settings_changed.emit()


func is_sfx_enabled() -> bool:
	return _sfx_enabled


func set_sfx_volume_db(volume_db: float) -> void:
	_sfx_volume_db = volume_db
	for player: AudioStreamPlayer in _sfx_players:
		player.volume_db = _sfx_volume_db
	_save_settings()
	sfx_settings_changed.emit()


func get_sfx_volume_db() -> float:
	return _sfx_volume_db


func get_sfx_volume_linear() -> float:
	return db_to_linear(_sfx_volume_db)


func set_sfx_volume_linear(linear: float) -> void:
	var clamped: float = clampf(linear, 0.0, 1.0)
	if clamped < 0.01:
		set_sfx_volume_db(-80.0)
	else:
		set_sfx_volume_db(linear_to_db(clamped))


# === 背景色設定 ===

func set_bg_color(color: Color) -> void:
	_bg_color = color
	_save_settings()
	GameEvents.bg_color_changed.emit(color)


func get_bg_color() -> Color:
	return _bg_color


# === 設定永続化 ===

func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("bgm", "enabled", _bgm_enabled)
	config.set_value("bgm", "volume_db", _bgm_volume_db)
	config.set_value("sfx", "enabled", _sfx_enabled)
	config.set_value("sfx", "volume_db", _sfx_volume_db)
	config.set_value("display", "bg_color", _bg_color.to_html(false))
	config.save(CONFIG_PATH)


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(CONFIG_PATH)
	if err == OK:
		_bgm_enabled = config.get_value("bgm", "enabled", true) as bool
		_bgm_volume_db = config.get_value("bgm", "volume_db", 0.0) as float
		_sfx_enabled = config.get_value("sfx", "enabled", true) as bool
		_sfx_volume_db = config.get_value("sfx", "volume_db", 0.0) as float
		var bg_html: String = config.get_value("display", "bg_color", "") as String
		if not bg_html.is_empty():
			_bg_color = Color.from_string(bg_html, DEFAULT_BG_COLOR)
