class_name ProceduralAudio
extends RefCounted
## Runtime-generated placeholder sounds. Original synthesis code, no external assets.
##
## Every sound used by the prototype can be synthesised here, so the game runs with
## zero audio files. [AudioManager] prefers real files in res://audio/ when they exist
## and only falls back to these generators when they don't (see docs/AUDIO.md).
##
## Performance notes: sounds are short, mono, 16-bit and 8-22 kHz. They are generated
## once, cached by AudioManager and pre-warmed on a background thread from the title
## screen, so low-end phones don't hitch during gameplay. All functions are pure and
## static (no scene access), which makes them safe to run on a worker thread.

const RATE_HIGH := 22050
const RATE_LOW := 11025
## Old station loudspeakers are band-limited; 8 kHz keeps the voice cheap to synthesise.
const RATE_VOICE := 8000

## Every id this generator understands (also used by tests and pre-warming).
const IDS := [
	&"rain",
	&"hum",
	&"chime",
	&"announce_name",
	&"announce_power",
	&"announce_last_train",
	&"door_open",
	&"door_close",
	&"door_locked",
	&"door_slam",
	&"switch_on",
	&"breaker_trip",
	&"power_up",
	&"power_down",
	&"paper",
	&"footstep",
	&"thunder",
	&"stinger",
	&"train_horn",
	&"clock_tick",
	&"clock_bell",
	&"ui_click",
	&"monitor_on",
	&"phone_buzz",
]


static func generate(id: StringName) -> AudioStream:
	match id:
		&"rain":
			return rain_loop()
		&"hum":
			return hum_loop()
		&"chime":
			return chime()
		&"announce_name":
			return announcer_voice(3.4, 11, 215.0)
		&"announce_power":
			return announcer_voice(4.6, 23, 205.0)
		&"announce_last_train":
			return announcer_voice(3.8, 37, 198.0)
		&"door_open":
			return door_creak()
		&"door_close":
			return door_thud(0.7, 1.0)
		&"door_locked":
			return door_rattle()
		&"door_slam":
			return door_slam()
		&"switch_on":
			return switch_clunk()
		&"breaker_trip":
			return breaker_trip()
		&"power_up":
			return power_sweep(true)
		&"power_down":
			return power_sweep(false)
		&"paper":
			return paper_rustle()
		&"footstep":
			return footsteps()
		&"thunder":
			return thunder()
		&"stinger":
			return stinger()
		&"train_horn":
			return train_horn()
		&"clock_tick":
			return clock_tick()
		&"clock_bell":
			return clock_bell()
		&"ui_click":
			return ui_click()
		&"monitor_on":
			return monitor_on()
		&"phone_buzz":
			return phone_buzz()
	push_warning("ProceduralAudio: unknown sound id '%s', using silence." % id)
	return _to_stream(_buffer(0.05, RATE_LOW), RATE_LOW)


# --- Ambience ------------------------------------------------------------------


## Monsoon rain on a roof: filtered noise body + hiss + scattered droplets. Seamless loop.
static func rain_loop() -> AudioStreamWAV:
	var sr := RATE_HIGH
	var buf := _buffer(3.0, sr)
	var n := buf.size()
	var rng := _rng(101)
	var a_hiss := _lp_coef(4200.0, sr)
	var a_body := _lp_coef(380.0, sr)
	var hiss := 0.0
	var body := 0.0
	for i in n:
		var w := rng.randf() * 2.0 - 1.0
		hiss += (w - hiss) * a_hiss
		body += (w - body) * a_body
		var swell := 0.85 + 0.15 * sin(TAU * 2.0 * float(i) / float(n))
		buf[i] = (hiss * 0.45 + body * 1.5) * swell
	# Droplets wrap around the loop point so the seam stays inaudible.
	for _d in 130:
		var start := rng.randi_range(0, n - 1)
		var freq := rng.randf_range(1800.0, 5200.0)
		var amp := rng.randf_range(0.03, 0.14)
		var w_inc := TAU * freq / float(sr)
		for k in 140:
			buf[(start + k) % n] += sin(w_inc * k) * amp * exp(-float(k) / 20.0)
	_normalize(buf, 0.7)
	return _to_stream(_make_loopable(buf, 0.2, sr), sr, true)


## 50 Hz mains hum (India's grid frequency) with harmonics and a faint buzz.
## Exactly 1 second, so every component completes whole cycles: a perfect loop.
static func hum_loop() -> AudioStreamWAV:
	var sr := RATE_LOW
	var buf := _buffer(1.0, sr)
	var rng := _rng(202)
	for i in buf.size():
		var t := float(i) / float(sr)
		var s := sin(TAU * 50.0 * t) * 0.55
		s += sin(TAU * 100.0 * t) * 0.4
		s += sin(TAU * 150.0 * t) * 0.18
		s += sin(TAU * 250.0 * t) * 0.07
		s += signf(sin(TAU * 100.0 * t)) * 0.05
		var wobble := 0.9 + 0.1 * sin(TAU * 1.0 * t)
		buf[i] = s * wobble + (rng.randf() * 2.0 - 1.0) * 0.012
	_normalize(buf, 0.6)
	return _to_stream(buf, sr, true)


# --- Announcements -------------------------------------------------------------


## Four-note station chime (an original pattern written for this project).
static func chime() -> AudioStreamWAV:
	var sr := RATE_LOW
	var notes := [554.37, 739.99, 659.26, 440.0]
	var spacing := 0.38
	var buf := _buffer(spacing * notes.size() + 1.1, sr)
	for k in notes.size():
		_add_bell(buf, sr, spacing * k, float(notes[k]), 0.5, 0.55, 1.15)
	_echo(buf, 0.13, 0.25, sr)
	_normalize(buf, 0.75)
	return _to_stream(buf, sr)


## Unintelligible PA-system "speech": a buzz source shaped by moving formants,
## band-limited like an old loudspeaker. Subtitles carry the actual words.
static func announcer_voice(seconds: float, seed_value: int, base_pitch: float) -> AudioStreamWAV:
	var sr := RATE_VOICE
	var buf := _buffer(seconds, sr)
	var n := buf.size()
	var rng := _rng(seed_value)

	# 1) Plan syllables: amplitude envelope + formant targets per sample.
	var env := PackedFloat32Array()
	env.resize(n)
	env.fill(0.0)
	var f1_track := PackedFloat32Array()
	f1_track.resize(n)
	f1_track.fill(500.0)
	var f2_track := PackedFloat32Array()
	f2_track.resize(n)
	f2_track.fill(1500.0)
	var pos := int(0.1 * sr)
	var f1 := 500.0
	var f2 := 1500.0
	while pos < n - int(0.2 * sr):
		var length := int(rng.randf_range(0.1, 0.22) * sr)
		var nf1 := rng.randf_range(320.0, 820.0)
		var nf2 := rng.randf_range(950.0, 2300.0)
		var amp := rng.randf_range(0.55, 1.0)
		for k in length:
			var idx := pos + k
			if idx >= n:
				break
			var x := float(k) / float(length)
			env[idx] = amp * sin(PI * x)
			var glide := minf(1.0, x * 4.0)
			f1_track[idx] = lerpf(f1, nf1, glide)
			f2_track[idx] = lerpf(f2, nf2, glide)
		f1 = nf1
		f2 = nf2
		pos += length + int(rng.randf_range(0.0, 0.035) * sr)
		if rng.randf() < 0.2:
			pos += int(rng.randf_range(0.1, 0.22) * sr)

	# 2) Synthesis: sawtooth glottal source through two resonant band-pass filters.
	var phase := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var ya1 := 0.0
	var ya2 := 0.0
	var yb1 := 0.0
	var yb2 := 0.0
	var a_b0 := 0.0
	var a_a1 := 0.0
	var a_a2 := 0.0
	var b_b0 := 0.0
	var b_a1 := 0.0
	var b_a2 := 0.0
	for i in n:
		if i % 32 == 0:
			var ca := _bandpass_coefs(f1_track[i], 5.0, sr)
			a_b0 = ca[0]
			a_a1 = ca[1]
			a_a2 = ca[2]
			var cb := _bandpass_coefs(f2_track[i], 7.0, sr)
			b_b0 = cb[0]
			b_a1 = cb[1]
			b_a2 = cb[2]
		var progress := float(i) / float(n)
		var pitch := base_pitch * (1.06 - 0.14 * progress) * (1.0 + 0.012 * sin(TAU * 5.0 * float(i) / float(sr)))
		phase += pitch / float(sr)
		if phase >= 1.0:
			phase -= 1.0
		var src := phase * 2.0 - 1.0 + (rng.randf() - 0.5) * 0.2
		var ya := a_b0 * (src - x2) - a_a1 * ya1 - a_a2 * ya2
		ya2 = ya1
		ya1 = ya
		var yb := b_b0 * (src - x2) - b_a1 * yb1 - b_a2 * yb2
		yb2 = yb1
		yb1 = yb
		x2 = x1
		x1 = src
		buf[i] = (ya + yb * 0.7) * env[i]

	# 3) Loudspeaker colouring: remove lows, overdrive slightly, add hall slap and hiss.
	_highpass(buf, 300.0, sr)
	_normalize(buf, 1.0)
	for i in n:
		buf[i] = tanh(buf[i] * 2.2) + (rng.randf() - 0.5) * 0.02
	_echo(buf, 0.09, 0.3, sr)
	_fade(buf, 0.02, 0.15, sr)
	_normalize(buf, 0.75)
	return _to_stream(buf, sr)


# --- Doors ---------------------------------------------------------------------


static func door_creak() -> AudioStreamWAV:
	var sr := RATE_LOW
	var buf := _buffer(1.0, sr)
	var n := buf.size()
	var rng := _rng(303)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(sr)
		var f := 120.0 + 70.0 * sin(TAU * 1.3 * t) + rng.randf_range(-25.0, 25.0)
		phase += f / float(sr)
		phase -= floorf(phase)
		var flutter := 0.6 + 0.4 * sin(TAU * 9.0 * t + sin(TAU * 2.1 * t) * 3.0)
		buf[i] = (phase * 2.0 - 1.0) * flutter
	_bandpass(buf, 780.0, 3.0, sr)
	_fade(buf, 0.06, 0.25, sr)
	_add_thud(buf, sr, 0.9, 85.0, 0.25, 0.08)
	_normalize(buf, 0.5)
	return _to_stream(buf, sr)


static func door_thud(seconds: float, strength: float) -> AudioStreamWAV:
	var sr := RATE_LOW
	var buf := _buffer(seconds, sr)
	_add_thud(buf, sr, 0.0, 70.0, strength, 0.12)
	_add_noise_burst(buf, sr, 0.0, 0.05, 900.0, 0.5 * strength, 404)
	_normalize(buf, 0.7)
	return _to_stream(buf, sr)


static func door_slam() -> AudioStreamWAV:
	var sr := RATE_LOW
	var buf := _buffer(1.6, sr)
	_add_thud(buf, sr, 0.0, 62.0, 1.0, 0.18)
	_add_noise_burst(buf, sr, 0.0, 0.09, 1400.0, 0.9, 505)
	_add_click(buf, sr, 0.16, 2200.0, 0.35, 0.03)
	_echo(buf, 0.11, 0.38, sr)
	_normalize(buf, 0.9)
	return _to_stream(buf, sr)


static func door_rattle() -> AudioStreamWAV:
	var sr := RATE_HIGH
	var buf := _buffer(0.55, sr)
	var times := [0.0, 0.1, 0.19, 0.31]
	for k in times.size():
		_add_noise_burst(buf, sr, float(times[k]), 0.012, 3000.0, 0.6, 600 + k)
		_add_click(buf, sr, float(times[k]), 1650.0 + 120.0 * k, 0.4, 0.035)
	_normalize(buf, 0.6)
	return _to_stream(buf, sr)


# --- Electrical ----------------------------------------------------------------


static func switch_clunk() -> AudioStreamWAV:
	var sr := RATE_HIGH
	var buf := _buffer(0.4, sr)
	_add_noise_burst(buf, sr, 0.0, 0.006, 5000.0, 0.8, 707)
	_add_thud(buf, sr, 0.0, 110.0, 0.8, 0.06)
	_add_click(buf, sr, 0.004, 1400.0, 0.3, 0.05)
	_normalize(buf, 0.75)
	return _to_stream(buf, sr)


static func breaker_trip() -> AudioStreamWAV:
	var sr := RATE_HIGH
	var buf := _buffer(1.1, sr)
	var n := buf.size()
	var rng := _rng(808)
	var gate := 0.0
	for i in n:
		var t := float(i) / float(sr)
		if rng.randf() < 0.004:
			gate = rng.randf_range(0.4, 1.0)
		gate *= 0.993
		var decay := exp(-t * 2.6)
		var crackle := (rng.randf() * 2.0 - 1.0) * gate
		var buzz := signf(sin(TAU * 100.0 * t)) * 0.25
		buf[i] = (crackle + buzz) * decay
	_highpass(buf, 400.0, sr)
	_add_thud(buf, sr, 0.0, 90.0, 0.9, 0.1)
	_normalize(buf, 0.85)
	return _to_stream(buf, sr)


static func power_sweep(rising: bool) -> AudioStreamWAV:
	var sr := RATE_LOW
	var seconds := 1.5
	var buf := _buffer(seconds, sr)
	var n := buf.size()
	var phase := 0.0
	for i in n:
		var x := float(i) / float(n)
		var f := lerpf(60.0, 420.0, x * x) if rising else lerpf(420.0, 40.0, sqrt(x))
		phase += f / float(sr)
		phase -= floorf(phase)
		var s := sin(TAU * phase) * 0.7 + sin(TAU * phase * 2.0) * 0.25 + signf(sin(TAU * phase * 3.0)) * 0.05
		var amp := minf(1.0, x * 3.0) if rising else (1.0 - x)
		buf[i] = s * amp
	if rising:
		_add_thud(buf, sr, 0.0, 80.0, 0.7, 0.08)
	_fade(buf, 0.01, 0.2, sr)
	_normalize(buf, 0.6)
	return _to_stream(buf, sr)


static func monitor_on() -> AudioStreamWAV:
	var sr := RATE_HIGH
	var buf := _buffer(0.9, sr)
	var n := buf.size()
	var rng := _rng(909)
	for i in n:
		var t := float(i) / float(sr)
		var whine := sin(TAU * 7800.0 * t) * 0.05 * minf(1.0, t * 6.0)
		var hum := sin(TAU * 100.0 * t) * 0.25 * minf(1.0, t * 3.0)
		var static_noise := (rng.randf() * 2.0 - 1.0) * 0.35 * exp(-t * 7.0)
		buf[i] = whine + hum + static_noise
	_add_click(buf, sr, 0.0, 2500.0, 0.5, 0.02)
	_fade(buf, 0.0, 0.3, sr)
	_normalize(buf, 0.5)
	return _to_stream(buf, sr)


# --- Foley ---------------------------------------------------------------------


static func paper_rustle() -> AudioStreamWAV:
	var sr := RATE_HIGH
	var buf := _buffer(0.45, sr)
	var n := buf.size()
	var rng := _rng(1001)
	var flutter := 0.0
	for i in n:
		if rng.randf() < 0.003:
			flutter = rng.randf_range(0.5, 1.0)
		flutter *= 0.9985
		buf[i] = (rng.randf() * 2.0 - 1.0) * flutter
	_bandpass(buf, 3200.0, 0.9, sr)
	_fade(buf, 0.01, 0.1, sr)
	_normalize(buf, 0.45)
	return _to_stream(buf, sr)


## Three concrete-floor step variants, randomised in pitch and volume on playback.
static func footsteps() -> AudioStream:
	var randomizer := AudioStreamRandomizer.new()
	randomizer.random_pitch = 1.1
	randomizer.random_volume_offset_db = 2.0
	for k in 3:
		var sr := RATE_LOW
		var buf := _buffer(0.2, sr)
		_add_noise_burst(buf, sr, 0.0, 0.05, 700.0 + 180.0 * k, 0.7, 1100 + k)
		_add_thud(buf, sr, 0.0, 75.0 + 10.0 * k, 0.6, 0.045)
		_normalize(buf, 0.5)
		randomizer.add_stream(-1, _to_stream(buf, sr))
	return randomizer


static func clock_tick() -> AudioStreamWAV:
	var sr := RATE_HIGH
	var buf := _buffer(0.06, sr)
	_add_noise_burst(buf, sr, 0.0, 0.002, 6000.0, 0.6, 1200)
	_add_click(buf, sr, 0.0, 3100.0, 0.5, 0.01)
	_normalize(buf, 0.5)
	return _to_stream(buf, sr)


static func ui_click() -> AudioStreamWAV:
	var sr := RATE_HIGH
	var buf := _buffer(0.07, sr)
	_add_click(buf, sr, 0.0, 1250.0, 0.6, 0.018)
	_normalize(buf, 0.4)
	return _to_stream(buf, sr)


static func phone_buzz() -> AudioStreamWAV:
	var sr := RATE_LOW
	var buf := _buffer(0.95, sr)
	for i in buf.size():
		var t := float(i) / float(sr)
		var on := 1.0 if (t < 0.32 or (t > 0.5 and t < 0.82)) else 0.0
		buf[i] = (signf(sin(TAU * 160.0 * t)) * 0.5 + sin(TAU * 320.0 * t) * 0.3) * on
	_lowpass(buf, 900.0, sr)
	_normalize(buf, 0.45)
	return _to_stream(buf, sr)


# --- Atmosphere ----------------------------------------------------------------


static func thunder() -> AudioStreamWAV:
	var sr := RATE_LOW
	var buf := _buffer(5.0, sr)
	var n := buf.size()
	var rng := _rng(1300)
	var brown := 0.0
	var mod := 1.0
	for i in n:
		var t := float(i) / float(sr)
		brown = clampf(brown + (rng.randf() * 2.0 - 1.0) * 0.08, -1.0, 1.0) * 0.998
		if rng.randf() < 0.0015:
			mod = rng.randf_range(0.5, 1.4)
		var env := minf(1.0, t / 0.25) * exp(-t / 1.6)
		var crack := (rng.randf() * 2.0 - 1.0) * exp(-t / 0.06) * 0.6
		buf[i] = brown * env * mod + crack
	_lowpass(buf, 420.0, sr)
	_fade(buf, 0.0, 0.8, sr)
	_normalize(buf, 0.9)
	return _to_stream(buf, sr)


## Low dissonant swell used for scares.
static func stinger() -> AudioStreamWAV:
	var sr := RATE_LOW
	var buf := _buffer(2.8, sr)
	var n := buf.size()
	var rng := _rng(1400)
	for i in n:
		var t := float(i) / float(sr)
		var env := minf(1.0, t / 0.35) * exp(-maxf(0.0, t - 0.35) / 0.9)
		var s := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 58.27 * t) * 0.45
		s += sin(TAU * 82.4 * t) * 0.25 + sin(TAU * 1244.5 * t) * 0.04 + sin(TAU * 1318.5 * t) * 0.04
		s += (rng.randf() * 2.0 - 1.0) * 0.1 * env
		buf[i] = s * env
	_echo(buf, 0.17, 0.3, sr)
	_normalize(buf, 0.8)
	return _to_stream(buf, sr)


## A distant two-tone train horn with a long platform echo.
static func train_horn() -> AudioStreamWAV:
	var sr := RATE_LOW
	var buf := _buffer(4.2, sr)
	var n := buf.size()
	var pa := 0.0
	var pb := 0.0
	for i in n:
		var t := float(i) / float(sr)
		var env := minf(1.0, t / 0.35) * clampf((2.6 - t) / 0.6, 0.0, 1.0)
		pa += 277.2 / float(sr)
		pb += 349.2 / float(sr)
		pa -= floorf(pa)
		pb -= floorf(pb)
		buf[i] = ((pa * 2.0 - 1.0) + (pb * 2.0 - 1.0)) * 0.5 * env
	_lowpass(buf, 850.0, sr)
	_lowpass(buf, 1100.0, sr)
	_echo(buf, 0.33, 0.42, sr)
	_normalize(buf, 0.7)
	return _to_stream(buf, sr)


## Deep bell strike for midnight.
static func clock_bell() -> AudioStreamWAV:
	var sr := RATE_LOW
	var buf := _buffer(3.5, sr)
	_add_bell(buf, sr, 0.0, 196.0, 0.8, 1.4, 3.2)
	_echo(buf, 0.21, 0.3, sr)
	_normalize(buf, 0.8)
	return _to_stream(buf, sr)


# --- Building blocks -----------------------------------------------------------


static func _buffer(seconds: float, rate: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(maxi(1, int(seconds * rate)))
	buf.fill(0.0)
	return buf


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _lp_coef(cutoff_hz: float, rate: int) -> float:
	return 1.0 - exp(-TAU * cutoff_hz / float(rate))


## Returns [b0, a1, a2] of an RBJ band-pass (b1 = 0, b2 = -b0), normalised by a0.
static func _bandpass_coefs(f0: float, q: float, rate: int) -> PackedFloat32Array:
	var w0 := TAU * clampf(f0, 20.0, rate * 0.45) / float(rate)
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	return PackedFloat32Array([alpha / a0, -2.0 * cos(w0) / a0, (1.0 - alpha) / a0])


static func _bandpass(buf: PackedFloat32Array, f0: float, q: float, rate: int) -> void:
	var c := _bandpass_coefs(f0, q, rate)
	var b0 := c[0]
	var a1 := c[1]
	var a2 := c[2]
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in buf.size():
		var x := buf[i]
		var y := b0 * (x - x2) - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[i] = y


static func _lowpass(buf: PackedFloat32Array, cutoff_hz: float, rate: int) -> void:
	var a := _lp_coef(cutoff_hz, rate)
	var y := 0.0
	for i in buf.size():
		y += (buf[i] - y) * a
		buf[i] = y


static func _highpass(buf: PackedFloat32Array, cutoff_hz: float, rate: int) -> void:
	var a := _lp_coef(cutoff_hz, rate)
	var low := 0.0
	for i in buf.size():
		low += (buf[i] - low) * a
		buf[i] -= low


## Feedback echo (in place); simulates the slap-back of a large tiled hall.
static func _echo(buf: PackedFloat32Array, delay_s: float, feedback: float, rate: int) -> void:
	var d := int(delay_s * rate)
	for i in range(d, buf.size()):
		buf[i] += buf[i - d] * feedback


static func _fade(buf: PackedFloat32Array, fade_in_s: float, fade_out_s: float, rate: int) -> void:
	var n := buf.size()
	var fi := mini(int(fade_in_s * rate), n)
	for i in fi:
		buf[i] *= float(i) / float(fi)
	var fo := mini(int(fade_out_s * rate), n)
	for i in fo:
		buf[n - 1 - i] *= float(i) / float(fo)


static func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var m := 0.0
	for v in buf:
		m = maxf(m, absf(v))
	if m < 0.00001:
		return
	var g := peak / m
	for i in buf.size():
		buf[i] *= g


## Crossfades the tail into the head so the buffer loops without a click.
static func _make_loopable(buf: PackedFloat32Array, crossfade_s: float, rate: int) -> PackedFloat32Array:
	var n := buf.size()
	var fade := int(crossfade_s * rate)
	if fade * 2 >= n:
		return buf
	var out := buf.slice(0, n - fade)
	for i in fade:
		var t := float(i) / float(fade)
		out[i] = buf[i] * sqrt(t) + buf[n - fade + i] * sqrt(1.0 - t)
	return out


## Struck bell / chime tone with three inharmonic partials.
static func _add_bell(
	buf: PackedFloat32Array, rate: int, start_s: float, freq: float, amp: float, decay_s: float, max_len_s: float
) -> void:
	var start := int(start_s * rate)
	var length := mini(int(max_len_s * rate), buf.size() - start)
	var w1 := TAU * freq / float(rate)
	var w2 := w1 * 2.0
	var w3 := w1 * 2.76
	var d1 := exp(-1.0 / (decay_s * rate))
	var d2 := exp(-1.0 / (decay_s * 0.6 * rate))
	var d3 := exp(-1.0 / (decay_s * 0.35 * rate))
	var e1 := 1.0
	var e2 := 0.5
	var e3 := 0.3
	var attack := maxi(1, int(0.004 * rate))
	for i in length:
		var a := minf(1.0, float(i) / float(attack))
		buf[start + i] += (sin(w1 * i) * e1 + sin(w2 * i) * e2 + sin(w3 * i) * e3) * a * amp
		e1 *= d1
		e2 *= d2
		e3 *= d3


## Low "body" impact with a slight downward pitch bend.
static func _add_thud(
	buf: PackedFloat32Array, rate: int, start_s: float, freq: float, amp: float, decay_s: float
) -> void:
	var start := int(start_s * rate)
	var length := mini(int(decay_s * 6.0 * rate), buf.size() - start)
	var phase := 0.0
	for i in length:
		var t := float(i) / float(rate)
		phase += freq * (1.0 + 0.6 * exp(-t / 0.03)) / float(rate)
		buf[start + i] += sin(TAU * phase) * amp * exp(-t / decay_s)


## Short metallic ring.
static func _add_click(
	buf: PackedFloat32Array, rate: int, start_s: float, freq: float, amp: float, decay_s: float
) -> void:
	var start := int(start_s * rate)
	var length := mini(int(decay_s * 6.0 * rate), buf.size() - start)
	var w := TAU * freq / float(rate)
	for i in length:
		var t := float(i) / float(rate)
		buf[start + i] += sin(w * i) * amp * exp(-t / decay_s)


## Low-passed noise burst with exponential decay.
static func _add_noise_burst(
	buf: PackedFloat32Array, rate: int, start_s: float, decay_s: float, cutoff_hz: float, amp: float, seed_value: int
) -> void:
	var rng := _rng(seed_value)
	var start := int(start_s * rate)
	var length := mini(int(decay_s * 6.0 * rate), buf.size() - start)
	var a := _lp_coef(cutoff_hz, rate)
	var y := 0.0
	for i in length:
		var t := float(i) / float(rate)
		y += ((rng.randf() * 2.0 - 1.0) - y) * a
		buf[start + i] += y * amp * exp(-t / decay_s)


static func _to_stream(buf: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream
