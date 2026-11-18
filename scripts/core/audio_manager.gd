extends Node

var muted: bool = false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_idx: int = 0
var _is_headless: bool = false

const SAMPLE_RATE := 22050
const POOL_SIZE := 8


func _ready() -> void:
	_is_headless = DisplayServer.get_name() == "headless"
	if _is_headless:
		return

	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)

	_build_sounds()


func play(sfx_name: String, volume_offset_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if muted or _is_headless or not _streams.has(sfx_name) or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next_idx]
	_next_idx = (_next_idx + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.volume_db = -8.0 + volume_offset_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter) if pitch_jitter > 0.0 else 1.0
	p.play()


func toggle_mute() -> bool:
	muted = not muted
	return muted


func _build_sounds() -> void:
	_streams["hit"] = _make_noise_impact(0.11, 180.0, 70.0, 0.7)
	_streams["crit"] = _make_chord_or_sweep(0.18, 420.0, 140.0, true, 0.85)
	_streams["cast_fire"] = _make_chord_or_sweep(0.24, 240.0, 680.0, true, 0.55)
	_streams["cast_frost"] = _make_chord_or_sweep(0.22, 880.0, 520.0, false, 0.50)
	_streams["heal"] = _make_arpeggio([523.25, 659.25, 783.99], 0.11, 0.45)
	_streams["level_up"] = _make_arpeggio([392.0, 493.88, 587.33, 783.99], 0.14, 0.65)
	_streams["quest_accept"] = _make_arpeggio([440.0, 554.37], 0.10, 0.50)
	_streams["quest_complete"] = _make_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.12, 0.60)
	_streams["loot"] = _make_arpeggio([987.77, 1318.5], 0.07, 0.40)
	_streams["stealth"] = _make_noise_impact(0.22, 500.0, 160.0, 0.35)
	_streams["charge"] = _make_chord_or_sweep(0.22, 160.0, 440.0, true, 0.60)
	_streams["ui_click"] = _make_chord_or_sweep(0.05, 620.0, 480.0, false, 0.30)
	_streams["error"] = _make_chord_or_sweep(0.14, 190.0, 135.0, true, 0.45)
	_streams["death"] = _make_arpeggio([329.63, 293.66, 246.94, 196.0], 0.16, 0.55)
	_streams["bow_shot"] = _make_chord_or_sweep(0.14, 920.0, 280.0, true, 0.42)
	_streams["gather"] = _make_noise_impact(0.14, 480.0, 180.0, 0.45)
	_streams["hearthstone"] = _make_arpeggio([392.0, 523.25, 659.25, 783.99, 1046.5], 0.14, 0.52)
	_streams["boss_slam"] = _make_noise_impact(0.32, 130.0, 42.0, 0.85)
	_streams["step"] = _make_noise_impact(0.05, 110.0, 60.0, 0.22)


func _samples_to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = clampi(int(round(samples[i] * 32767.0)), -32768, 32767)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _make_noise_impact(dur: float, start_freq: float, end_freq: float, amp: float) -> AudioStreamWAV:
	var count: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = pow(1.0 - t, 1.8)
		var freq: float = lerpf(start_freq, end_freq, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var tone: float = sin(phase) * 0.6 + randf_range(-0.5, 0.5) * 0.5
		buf[i] = tone * env * amp
	return _samples_to_wav(buf)


func _make_chord_or_sweep(dur: float, f0: float, f1: float, noisy: bool, amp: float) -> AudioStreamWAV:
	var count: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = sin(minf(1.0, t * 8.0) * PI * 0.5) * pow(1.0 - t, 1.4)
		var freq: float = lerpf(f0, f1, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var s: float = sin(phase) + (0.25 * sin(phase * 2.0))
		if noisy:
			s += randf_range(-0.35, 0.35)
		buf[i] = clampf(s * 0.6, -1.0, 1.0) * env * amp
	return _samples_to_wav(buf)


func _make_arpeggio(freqs: Array[float], note_dur: float, amp: float) -> AudioStreamWAV:
	var n_samples: int = int(note_dur * SAMPLE_RATE)
	var total: int = n_samples * freqs.size()
	var buf := PackedFloat32Array()
	buf.resize(total)
	for n in range(freqs.size()):
		var freq: float = freqs[n]
		var phase: float = 0.0
		for i in range(n_samples):
			var t: float = float(i) / float(n_samples)
			var env: float = sin(minf(1.0, t * 10.0) * PI * 0.5) * pow(1.0 - t, 1.2)
			phase += TAU * freq / float(SAMPLE_RATE)
			var s: float = sin(phase) * 0.75 + sin(phase * 2.0) * 0.25
			buf[n * n_samples + i] = s * env * amp
	return _samples_to_wav(buf)
