class_name BBSfx
extends Node
## Burger Blitz — retro chip SFX, synthesized at load (no asset files).
## Port of the reference WebAudio blips/noise bursts/sizzle loop.

const SR := 32000

var muted := false
var _fx: Dictionary = {}
var _add_cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _sizzle: AudioStreamPlayer = null
var _sizzle_tween: Tween = null


func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_sizzle = AudioStreamPlayer.new()
	add_child(_sizzle)
	_build_all()


func play(fx_name: String) -> void:
	if muted or not _fx.has(fx_name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _fx[fx_name]
			p.play()
			return
	_pool[0].stream = _fx[fx_name]
	_pool[0].play()


## pitch climbs with the stack height, like the reference add(n)
func play_add(n: int) -> void:
	if muted:
		return
	n = clampi(n, 0, 14)
	if not _add_cache.has(n):
		var f := 340.0 + float(n) * 36.0
		_add_cache[n] = _wav(_mix([
			[0.0, _blip(f, 0.06, "square", 0.09, f * 1.4)],
			[0.0, _noise(0.04, 0.04, 1500.0)],
		]))
	for p in _pool:
		if not p.playing:
			p.stream = _add_cache[n]
			p.play()
			return


func start_sizzle() -> void:
	if muted or _sizzle.playing:
		return
	if _sizzle_tween:
		_sizzle_tween.kill()
	_sizzle.volume_db = -60.0
	_sizzle.play()
	_sizzle_tween = create_tween()
	_sizzle_tween.tween_property(_sizzle, "volume_db", linear_to_db(0.05), 0.4)


func stop_sizzle() -> void:
	if not _sizzle.playing:
		return
	if _sizzle_tween:
		_sizzle_tween.kill()
	_sizzle_tween = create_tween()
	_sizzle_tween.tween_property(_sizzle, "volume_db", -60.0, 0.25)
	_sizzle_tween.tween_callback(_sizzle.stop)


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		stop_sizzle()
	return muted


# ---------- synthesis ----------

func _build_all() -> void:
	_fx["click"] = _wav(_blip(220, 0.05, "square", 0.08))
	_fx["place"] = _wav(_mix([[0.0, _blip(180, 0.07, "square", 0.1, 240)], [0.0, _noise(0.06, 0.05, 1200)]]))
	_fx["flip"] = _wav(_mix([[0.0, _blip(300, 0.09, "triangle", 0.1, 520)], [0.0, _noise(0.05, 0.05, 2500)]]))
	_fx["pull"] = _wav(_blip(520, 0.08, "square", 0.1, 700))
	_fx["ding"] = _wav(_mix([[0.0, _blip(880, 0.09, "square", 0.11)], [0.09, _blip(1320, 0.16, "square", 0.11)]]))
	_fx["cash"] = _wav(_mix([[0.0, _blip(660, 0.07, "square", 0.1)], [0.07, _blip(990, 0.07, "square", 0.1)], [0.15, _blip(1320, 0.12, "square", 0.1)]]))
	_fx["error"] = _wav(_blip(150, 0.18, "sawtooth", 0.1, 90))
	_fx["burn"] = _wav(_mix([[0.0, _blip(110, 0.3, "sawtooth", 0.1, 60)], [0.0, _noise(0.3, 0.08, 700)]]))
	_fx["leave"] = _wav(_mix([[0.0, _blip(330, 0.12, "square", 0.1, 160)], [0.12, _blip(200, 0.2, "square", 0.1, 120)]]))
	_fx["trash"] = _wav(_mix([[0.0, _blip(160, 0.09, "square", 0.1, 80)], [0.0, _noise(0.14, 0.09, 900)]]))
	_fx["star"] = _wav(_mix([[0.0, _blip(784, 0.08, "square", 0.1)], [0.08, _blip(1046, 0.12, "square", 0.1)]]))
	var start_parts: Array = []
	var notes := [523.0, 659.0, 784.0, 1046.0]
	for i in range(notes.size()):
		start_parts.append([i * 0.09, _blip(notes[i], 0.12, "square", 0.1)])
	_fx["start"] = _wav(_mix(start_parts))
	_sizzle.stream = _make_sizzle_loop()


func _blip(freq: float, dur: float, wave: String, vol: float, slide_to: float = 0.0) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var f := freq
		if slide_to > 0.0:
			f = freq * pow(slide_to / freq, t)
		phase = fmod(phase + f / SR, 1.0)
		var s: float
		match wave:
			"triangle":
				s = 4.0 * absf(phase - 0.5) - 1.0
			"sawtooth":
				s = 2.0 * phase - 1.0
			_:
				s = 1.0 if phase < 0.5 else -1.0
		# exponential decay to ~0.0001 like WebAudio exponentialRamp
		var g := vol * pow(0.0001 / maxf(vol, 0.001), t)
		out[i] = s * g
	return out


func _noise(dur: float, vol: float, lp_hz: float) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var a := 1.0 - exp(-TAU * lp_hz / SR)
	for i in range(n):
		var x := randf_range(-1.0, 1.0) * (1.0 - float(i) / float(n))
		y += a * (x - y)
		out[i] = y * vol * 2.0
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var total := 0
	for part in parts:
		total = maxi(total, int(part[0] * SR) + part[1].size())
	var out := PackedFloat32Array()
	out.resize(total)
	for part in parts:
		var off := int(part[0] * SR)
		var smp: PackedFloat32Array = part[1]
		for i in range(smp.size()):
			out[off + i] += smp[i]
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.data = bytes
	return wav


func _make_sizzle_loop() -> AudioStreamWAV:
	var dur := 1.5
	var n := int(SR * dur)
	var raw := PackedFloat32Array()
	raw.resize(n)
	# RBJ bandpass: fc 2600 Hz, Q 0.6
	var w0 := TAU * 2600.0 / SR
	var alpha := sin(w0) / (2.0 * 0.6)
	var b0 := alpha
	var b2 := -alpha
	var a0 := 1.0 + alpha
	var a1 := -2.0 * cos(w0)
	var a2 := 1.0 - alpha
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in range(n):
		var x := randf_range(-1.0, 1.0)
		var y := (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		raw[i] = clampf(y, -1.0, 1.0) * 0.8
	var wav := _wav(raw)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
