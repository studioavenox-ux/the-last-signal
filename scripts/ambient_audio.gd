extends Node
## Procedural rain/hum beds and signal chirp; no downloaded audio or voice acting.
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var phase := 0.0
var hiss := 0.0
var powered := false
var tone_remaining := 0
var step_remaining := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 38147
	player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.3
	player.stream = generator
	player.volume_db = -19.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if playback == null:
		return
	var count := mini(playback.get_frames_available(), 2205)
	if count <= 0:
		return
	var frames := PackedVector2Array()
	frames.resize(count)
	for i in range(count):
		hiss = lerpf(hiss, rng.randf_range(-1.0, 1.0), 0.24)
		phase += TAU * (72.0 if powered else 47.0) / 22050.0
		var hum := sin(phase) * (0.12 if powered else 0.035)
		var chirp := 0.0
		if tone_remaining > 0:
			chirp = sin(phase * 8.0) * 0.27
			tone_remaining -= 1
		var step_noise := 0.0
		if step_remaining > 0:
			step_noise = rng.randf_range(-1.0, 1.0) * 0.15 * float(step_remaining) / 1300.0
			step_remaining -= 1
		var sample := hiss * 0.095 + hum + chirp + step_noise
		frames[i] = Vector2(sample, sample)
	playback.push_buffer(frames)


func signal_chirp() -> void:
	tone_remaining = 3800


func footstep() -> void:
	step_remaining = 1300


func set_volume(value: float) -> void:
	if player != null:
		player.volume_db = -80.0 if value <= 0.001 else -19.0 + linear_to_db(value)
