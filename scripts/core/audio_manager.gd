extends Node
## Autoload "Audio" (AudioManager): audio buses plus PLACEHOLDER sound effects
## synthesized in code at startup (no audio files yet). Replace a sound by
## putting a file in assets/audio/<name>.wav or .ogg - it is used automatically.
##
## Buses: Music, SFX, Ambience, UI (all send to Master).

const RATE := 22050
const POOL_SIZE := 16
const BUSES := ["Music", "SFX", "Ambience", "UI"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _ambience: AudioStreamPlayer
var _last_played := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -10.0)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)


## Plays a one-shot effect. Very fast repeats of the same sound are thinned out.
func play(sound: String, volume_db := 0.0, pitch_variation := 0.08, bus := "SFX") -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 35:
		return
	_last_played[sound] = now
	var stream := _get_stream(sound)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()


func _exit_tree() -> void:
	# Stop everything so no playback is still alive when the engine shuts down.
	for p in _pool:
		p.stop()
		p.stream = null
	_ambience.stop()
	_ambience.stream = null
	_streams.clear()


func start_ambience() -> void:
	_ambience.stream = _get_stream("ambience")
	if not _ambience.playing:
		_ambience.play()


func _get_stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var stream: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path := "res://assets/audio/%s.%s" % [sound, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		stream = _synth(sound)
	_streams[sound] = stream
	return stream


# ================================================================ synthesis

func _synth(sound: String) -> AudioStreamWAV:
	match sound:
		"whoosh":
			return _make(0.13, func(t: float, n: float, s: Dictionary) -> float:
				return _bandnoise(s, n, lerpf(0.15, 0.5, t / 0.13)) * _env(t, 0.01, 0.12) * 0.7)
		"whoosh_heavy":
			return _make(0.22, func(t: float, n: float, s: Dictionary) -> float:
				return _bandnoise(s, n, lerpf(0.08, 0.35, t / 0.22)) * _env(t, 0.02, 0.2) * 0.9)
		"hit":
			return _make(0.11, func(t: float, n: float, _s: Dictionary) -> float:
				return (sin(TAU * lerpf(180.0, 70.0, t / 0.11) * t) * 0.8 + n * 0.5 * _env(t, 0.0, 0.025)) * _env(t, 0.0, 0.1))
		"hit_heavy":
			return _make(0.2, func(t: float, n: float, _s: Dictionary) -> float:
				return (sin(TAU * lerpf(140.0, 45.0, t / 0.2) * t) + n * 0.6 * _env(t, 0.0, 0.04)) * _env(t, 0.0, 0.19))
		"crit":
			return _make(0.22, func(t: float, n: float, _s: Dictionary) -> float:
				var thump := sin(TAU * lerpf(200.0, 70.0, t / 0.1) * t) * _env(t, 0.0, 0.1)
				var ping := sin(TAU * 1760.0 * t) * 0.35 * _env(t, 0.0, 0.2)
				return thump + ping + n * 0.3 * _env(t, 0.0, 0.02))
		"dash":
			return _make(0.18, func(t: float, n: float, s: Dictionary) -> float:
				return _bandnoise(s, n, lerpf(0.4, 0.1, t / 0.18)) * _env(t, 0.005, 0.17) * 0.6)
		"hurt":
			return _make(0.25, func(t: float, n: float, _s: Dictionary) -> float:
				return (sin(TAU * lerpf(220.0, 90.0, t / 0.25) * t) * 0.7 + n * 0.4) * _env(t, 0.0, 0.24) * 0.8)
		"charge_ready":
			return _make(0.25, func(t: float, _n: float, _s: Dictionary) -> float:
				return (sin(TAU * 1320.0 * t) + sin(TAU * 1980.0 * t) * 0.5) * _env(t, 0.0, 0.24) * 0.35)
		"switch":
			return _make(0.08, func(t: float, _n: float, _s: Dictionary) -> float:
				return _square(lerpf(660.0, 990.0, t / 0.08), t) * _env(t, 0.0, 0.08) * 0.18)
		"cast_sun":
			return _make(0.35, func(t: float, n: float, s: Dictionary) -> float:
				var roar := _lownoise(s, n, 0.25) * _env(t, 0.01, 0.33)
				var rise := sin(TAU * lerpf(200.0, 500.0, t / 0.35) * t) * 0.3 * _env(t, 0.0, 0.3)
				return roar * 0.9 + rise)
		"cast_comet":
			return _make(0.4, func(t: float, _n: float, _s: Dictionary) -> float:
				var chime := sin(TAU * 2093.0 * t) + sin(TAU * 3136.0 * t) * 0.5 + sin(TAU * 4186.0 * t) * 0.25
				return chime * _env(t, 0.0, 0.38) * 0.3)
		"cast_storm":
			return _make(0.3, func(t: float, n: float, _s: Dictionary) -> float:
				var buzz := _square(90.0 + 60.0 * sin(t * 300.0), t) * 0.4
				var crackle := (n if absf(n) > 0.75 else 0.0) * 0.9
				return (buzz + crackle) * _env(t, 0.0, 0.28))
		"cast_gravity":
			return _make(0.5, func(t: float, n: float, s: Dictionary) -> float:
				var wob := sin(TAU * lerpf(110.0, 40.0, t / 0.5) * t + sin(t * 40.0) * 2.0)
				return (wob + _lownoise(s, n, 0.05) * 0.4) * _env(t, 0.05, 0.45) * 0.8)
		"cast_void":
			return _make(0.4, func(t: float, n: float, _s: Dictionary) -> float:
				var k := t / 0.4
				var saw := fmod(t * lerpf(300.0, 120.0, k), 1.0) * 2.0 - 1.0
				var saw2 := fmod(t * lerpf(303.0, 118.0, k), 1.0) * 2.0 - 1.0
				return (saw + saw2) * 0.25 * _env(t, 0.15, 0.25) + n * 0.15 * _env(t, 0.2, 0.2))
		"explode":
			return _make(0.5, func(t: float, n: float, s: Dictionary) -> float:
				return (_lownoise(s, n, lerpf(0.4, 0.05, t / 0.5)) * 1.4 + sin(TAU * 55.0 * t) * 0.5) * _env(t, 0.0, 0.48))
		"freeze":
			return _make(0.45, func(t: float, n: float, s: Dictionary) -> float:
				return (_bandnoise(s, n, 0.8) * 0.5 + sin(TAU * 2637.0 * t) * 0.3) * _env(t, 0.0, 0.43))
		"shatter":
			return _make(0.45, func(t: float, n: float, s: Dictionary) -> float:
				var glass := (n if absf(n) > 0.6 else 0.0) * _env(t, 0.0, 0.4)
				return glass + sin(TAU * 3520.0 * t) * 0.3 * _env(t, 0.0, 0.3) + _lownoise(s, n, 0.2) * 0.5 * _env(t, 0.0, 0.1))
		"combo":
			return _make(0.5, func(t: float, _n: float, _s: Dictionary) -> float:
				var a := sin(TAU * 523.0 * t) * _env(t, 0.0, 0.45)
				var b := sin(TAU * 784.0 * t) * _env(maxf(t - 0.06, 0.0), 0.0, 0.4) * (1.0 if t > 0.06 else 0.0)
				return (a + b) * 0.3)
		"enemy_die":
			return _make(0.35, func(t: float, n: float, s: Dictionary) -> float:
				return (sin(TAU * lerpf(400.0, 60.0, t / 0.35) * t) * 0.6 + _lownoise(s, n, 0.3) * 0.5) * _env(t, 0.0, 0.33))
		"enemy_windup":
			return _make(0.3, func(t: float, n: float, s: Dictionary) -> float:
				return _bandnoise(s, n, lerpf(0.1, 0.6, t / 0.3)) * _env(t, 0.2, 0.08) * 0.45)
		"saber_crackle":
			return _make(0.35, func(t: float, n: float, _s: Dictionary) -> float:
				var hum := _square(120.0, t) * 0.25
				var crack := (n if absf(n) > 0.8 else 0.0) * 0.6
				return (hum + crack) * _env(t, 0.25, 0.08))
		"rifle_charge":
			return _make(0.5, func(t: float, _n: float, _s: Dictionary) -> float:
				return sin(TAU * lerpf(300.0, 1200.0, t / 0.5) * t) * 0.18 * _env(t, 0.4, 0.08))
		"rifle_shot":
			return _make(0.25, func(t: float, n: float, s: Dictionary) -> float:
				return (_square(lerpf(900.0, 200.0, t / 0.25), t) * 0.35 + _lownoise(s, n, 0.3) * 0.5) * _env(t, 0.0, 0.23))
		"spawn":
			return _make(0.45, func(t: float, n: float, s: Dictionary) -> float:
				return (sin(TAU * lerpf(150.0, 600.0, t / 0.45) * t) * 0.3 + _bandnoise(s, n, 0.3) * 0.3) * _env(t, 0.1, 0.33))
		"chirp":
			return _make(0.16, func(t: float, _n: float, _s: Dictionary) -> float:
				var f := 1400.0 + 900.0 * sin(t * 40.0) + t * 3000.0
				return sin(TAU * f * t) * _env(t, 0.01, 0.15) * 0.3)
		"chirp_happy":
			return _make(0.28, func(t: float, _n: float, _s: Dictionary) -> float:
				var f := 1500.0 if t < 0.09 else (1900.0 if t < 0.18 else 2300.0)
				return sin(TAU * f * t) * _env(fmod(t, 0.09), 0.005, 0.085) * 0.3)
		"chirp_hurt":
			return _make(0.2, func(t: float, _n: float, _s: Dictionary) -> float:
				return sin(TAU * lerpf(1800.0, 700.0, t / 0.2) * t) * _env(t, 0.0, 0.19) * 0.35)
		"wingbeat":
			return _make(0.12, func(t: float, n: float, s: Dictionary) -> float:
				return _lownoise(s, n, 0.08) * _env(t, 0.03, 0.09) * 1.2)
		"roar":
			return _make(0.7, func(t: float, n: float, s: Dictionary) -> float:
				var k := t / 0.7
				var saw := fmod(t * lerpf(320.0, 180.0, k) + sin(t * 30.0) * 0.3, 1.0) * 2.0 - 1.0
				return (saw * 0.35 + _bandnoise(s, n, 0.3) * 0.4 + sin(TAU * 2200.0 * t) * 0.08) * _env(t, 0.05, 0.65))
		"breath":
			return _make(0.3, func(t: float, n: float, s: Dictionary) -> float:
				return (_bandnoise(s, n, 0.7) * 0.6 + sin(TAU * 2637.0 * t) * 0.15) * _env(t, 0.02, 0.28))
		"comet_impact":
			return _make(0.35, func(t: float, n: float, s: Dictionary) -> float:
				var crack := (n if absf(n) > 0.7 else 0.0) * _env(t, 0.0, 0.25)
				return crack * 0.8 + _lownoise(s, n, 0.2) * 0.8 * _env(t, 0.0, 0.2) + sin(TAU * 3136.0 * t) * 0.15 * _env(t, 0.0, 0.3))
		"ui":
			return _make(0.06, func(t: float, _n: float, _s: Dictionary) -> float:
				return sin(TAU * 880.0 * t) * _env(t, 0.0, 0.06) * 0.3)
		"wave":
			return _make(0.7, func(t: float, _n: float, _s: Dictionary) -> float:
				var horn := _square(220.0, t) * 0.12 + sin(TAU * 440.0 * t) * 0.2
				return horn * _env(t, 0.05, 0.6))
		"ambience":
			var hum := func(t: float, n: float, s: Dictionary) -> float:
				var lfo := 0.6 + 0.4 * sin(TAU * t / 4.0)
				return _lownoise(s, n, 0.02) * 1.5 * lfo + sin(TAU * 55.0 * t) * 0.08 + sin(TAU * 82.5 * t) * 0.05
			return _make(4.0, hum, true)
	push_warning("Audio: unknown sound '%s'" % sound)
	return null


## Renders `fn(t, noise, state)` into a 16-bit mono WAV.
func _make(duration: float, fn: Callable, loop := false) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var state := {"lp": 0.0, "lp2": 0.0, "bp": 0.0}
	for i in n:
		var t := float(i) / RATE
		var v: float = fn.call(t, rng.randf_range(-1.0, 1.0), state)
		if loop:
			# Crossfade the loop edges to avoid a click.
			var edge := minf(t, duration - t)
			v *= clampf(edge / 0.05, 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	return w


## Attack/decay envelope.
func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return maxf(0.0, 1.0 - (t - attack) / maxf(decay, 0.001))


func _square(freq: float, t: float) -> float:
	return 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0


## One-pole low-pass filtered noise (k: 0..1, lower = darker).
func _lownoise(s: Dictionary, n: float, k: float) -> float:
	s["lp"] = s["lp"] + (n - s["lp"]) * k
	return s["lp"] * 2.0


## Crude band-pass noise (two filters) for whooshes.
func _bandnoise(s: Dictionary, n: float, k: float) -> float:
	s["bp"] = s["bp"] + (n - s["bp"]) * k
	s["lp2"] = s["lp2"] + (s["bp"] - s["lp2"]) * (k * 0.3)
	return (s["bp"] - s["lp2"]) * 3.0
