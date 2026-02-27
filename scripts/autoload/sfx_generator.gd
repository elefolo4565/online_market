class_name SfxGenerator
extends RefCounted
## 効果音を AudioStreamWAV として動的に生成するユーティリティ

const MIX_RATE: int = 22050


## --- 公開メソッド: 各SE生成 ---

## 短い高音ブリップ（手札選択）
static func card_select() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var duration: float = 0.08
	var freq: float = 1200.0
	var count: int = int(duration * MIX_RATE)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var env: float = _envelope(t, 0.005, 0.02, 0.6, 0.03, duration)
		samples.append(sin(TAU * freq * t) * env * 0.5)
	return _to_wav(samples)


## 上昇2音ビープ（入札確定）
static func bid_confirm() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var duration: float = 0.2
	var count: int = int(duration * MIX_RATE)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var freq: float = 800.0 if t < 0.1 else 1100.0
		var env: float = _envelope(t, 0.005, 0.03, 0.7, 0.05, duration)
		samples.append(sin(TAU * freq * t) * env * 0.45)
	return _to_wav(samples)


## 下降スイープ（銘柄カード出現）
static func card_reveal() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var duration: float = 0.25
	var count: int = int(duration * MIX_RATE)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var ratio: float = t / duration
		var freq: float = lerpf(1400.0, 600.0, ratio)
		var env: float = _envelope(t, 0.01, 0.05, 0.6, 0.1, duration)
		samples.append(sin(TAU * freq * t) * env * 0.4)
	return _to_wav(samples)


## ドラムロール風（全入札公開）
static func bid_reveal() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var duration: float = 0.4
	var count: int = int(duration * MIX_RATE)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var ratio: float = t / duration
		# 加速するクリック列
		var click_rate: float = lerpf(8.0, 30.0, ratio)
		var phase: float = fmod(t * click_rate, 1.0)
		var click: float = 1.0 if phase < 0.15 else 0.0
		var freq: float = lerpf(300.0, 500.0, ratio)
		var env: float = _envelope(t, 0.01, 0.05, 0.8, 0.1, duration)
		samples.append(sin(TAU * freq * t) * click * env * 0.35)
	return _to_wav(samples)


## 衝突ノイズバースト（バッティング）
static func batting() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var duration: float = 0.2
	var count: int = int(duration * MIX_RATE)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42  # 再現性のために固定シード
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var env: float = _envelope(t, 0.002, 0.01, 0.3, 0.1, duration)
		var noise: float = rng.randf_range(-1.0, 1.0)
		# ノイズ + 低音サイン波を重ねる
		var tone: float = sin(TAU * 180.0 * t) * 0.4
		samples.append((noise * 0.6 + tone) * env * 0.5)
	return _to_wav(samples)


## 上昇3音アルペジオ（プラスカード獲得）
static func gain() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var duration: float = 0.35
	var count: int = int(duration * MIX_RATE)
	# C5, E5, G5 の上昇アルペジオ
	var notes: Array[float] = [523.25, 659.25, 783.99]
	var note_dur: float = duration / float(notes.size())
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var note_idx: int = mini(int(t / note_dur), notes.size() - 1)
		var local_t: float = t - float(note_idx) * note_dur
		var freq: float = notes[note_idx]
		var env: float = _envelope(local_t, 0.005, 0.02, 0.7, 0.05, note_dur)
		samples.append(sin(TAU * freq * t) * env * 0.4)
	return _to_wav(samples)


## 下降トーン（マイナスカード引取）
static func loss() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var duration: float = 0.35
	var count: int = int(duration * MIX_RATE)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var ratio: float = t / duration
		var freq: float = lerpf(500.0, 200.0, ratio)
		var env: float = _envelope(t, 0.01, 0.05, 0.7, 0.15, duration)
		# 矩形波風にする
		var wave: float = sign(sin(TAU * freq * t))
		samples.append(wave * env * 0.25)
	return _to_wav(samples)


## ファンファーレ4音和音（ゲーム終了）
static func game_over() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var duration: float = 0.8
	var count: int = int(duration * MIX_RATE)
	# C4, E4, G4, C5 を順に追加しつつ和音化
	var notes: Array[float] = [261.63, 329.63, 392.00, 523.25]
	var onset_interval: float = 0.12
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var val: float = 0.0
		for n: int in notes.size():
			var onset: float = float(n) * onset_interval
			if t >= onset:
				var local_t: float = t - onset
				var remaining: float = duration - onset
				var env: float = _envelope(local_t, 0.01, 0.05, 0.6, 0.3, remaining)
				val += sin(TAU * notes[n] * t) * env
		samples.append(val * 0.2)
	return _to_wav(samples)


## --- 内部ヘルパー ---

## ADSR エンベロープ
static func _envelope(t: float, attack: float, decay: float, sustain: float, release: float, duration: float) -> float:
	var release_start: float = duration - release
	if t < attack:
		return t / attack
	elif t < attack + decay:
		return lerpf(1.0, sustain, (t - attack) / decay)
	elif t < release_start:
		return sustain
	elif t < duration:
		return lerpf(sustain, 0.0, (t - release_start) / release)
	return 0.0


## PackedFloat32Array → AudioStreamWAV (16bit PCM)
static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false

	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		var val: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)

	wav.data = data
	return wav
