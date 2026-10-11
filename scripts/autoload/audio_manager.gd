extends Node
## Central audio service: ambience loops, one-shot SFX, positional one-shots and
## station announcements.
##
## Asset lookup order for every sound id:
##   1. A real audio file at CATALOGUE[id] + ".ogg" / ".wav" / ".mp3" (if present).
##   2. A procedurally generated placeholder from [ProceduralAudio].
## So the project always runs, with or without audio files. See docs/AUDIO.md.

const BUS_AMBIENCE := &"Ambience"
const BUS_SFX := &"SFX"
const BUS_ANNOUNCER := &"Announcer"
const ASSET_EXTENSIONS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 10

## Sound id -> asset path stem (no extension). Drop a file at one of these paths to
## replace the procedural placeholder; no code changes are needed.
const CATALOGUE := {
	&"rain": "res://audio/ambience/rain_loop",
	&"hum": "res://audio/ambience/electrical_hum",
	&"chime": "res://audio/announcements/chime",
	&"announce_name": "res://audio/announcements/announce_name",
	&"announce_power": "res://audio/announcements/announce_power",
	&"announce_last_train": "res://audio/announcements/announce_last_train",
	&"door_open": "res://audio/sfx/door_open",
	&"door_close": "res://audio/sfx/door_close",
	&"door_locked": "res://audio/sfx/door_locked",
	&"door_slam": "res://audio/sfx/door_slam",
	&"switch_on": "res://audio/sfx/switch_on",
	&"breaker_trip": "res://audio/sfx/breaker_trip",
	&"power_up": "res://audio/sfx/power_up",
	&"power_down": "res://audio/sfx/power_down",
	&"paper": "res://audio/sfx/paper",
	&"footstep": "res://audio/sfx/footstep",
	&"thunder": "res://audio/sfx/thunder",
	&"stinger": "res://audio/sfx/stinger",
	&"train_horn": "res://audio/sfx/train_horn",
	&"clock_tick": "res://audio/sfx/clock_tick",
	&"clock_bell": "res://audio/sfx/clock_bell",
	&"ui_click": "res://audio/sfx/ui_click",
	&"monitor_on": "res://audio/sfx/monitor_on",
	&"phone_buzz": "res://audio/sfx/phone_buzz",
}

## Ids that must loop even when a replacement file was imported without loop enabled.
const LOOPING_IDS := [&"rain", &"hum"]

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _ambience_players: Dictionary = {}
var _ambience_tweens: Dictionary = {}
## Fallback pre-warm path (one sound per frame) when threads are unavailable.
var _prewarm_queue: Array[StringName] = []
## Background pre-warm: results land in _pending (guarded by _mutex) and are moved
## into _cache on the main thread.
var _prewarm_task_id: int = -1
var _pending: Dictionary = {}
var _mutex: Mutex = Mutex.new()
var _cancel_prewarm: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = BUS_SFX
		add_child(player)
		_pool.append(player)


func _process(_delta: float) -> void:
	_collect_pending()
	if _prewarm_task_id != -1 and WorkerThreadPool.is_task_completed(_prewarm_task_id):
		WorkerThreadPool.wait_for_task_completion(_prewarm_task_id)
		_prewarm_task_id = -1
		_collect_pending()
	# Fallback path: generate at most one queued sound per frame.
	if not _prewarm_queue.is_empty():
		get_stream(_prewarm_queue.pop_front())


func _exit_tree() -> void:
	if _prewarm_task_id != -1:
		_cancel_prewarm = true
		WorkerThreadPool.wait_for_task_completion(_prewarm_task_id)
		_prewarm_task_id = -1


# --- Public API ----------------------------------------------------------------


## Generates every procedural placeholder ahead of time (called by the title screen).
## Uses a WorkerThreadPool task so the main thread never stalls; falls back to one
## sound per frame on platforms without threads (e.g. single-threaded web exports).
func prewarm_all() -> void:
	if _prewarm_task_id != -1:
		return
	var ids: Array[StringName] = []
	for id: StringName in CATALOGUE.keys():
		if not _cache.has(id) and not _prewarm_queue.has(id) and _find_asset_path(id).is_empty():
			ids.append(id)
	if ids.is_empty():
		return
	if OS.has_feature("threads"):
		_cancel_prewarm = false
		_prewarm_task_id = WorkerThreadPool.add_task(_generate_in_background.bind(ids), false, "Audio prewarm")
	else:
		_prewarm_queue.append_array(ids)


func is_prewarm_done() -> bool:
	return _prewarm_queue.is_empty() and _prewarm_task_id == -1


## Returns the stream for a sound id (real file if present, otherwise procedural).
func get_stream(id: StringName) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	_collect_pending()
	if _cache.has(id):
		return _cache[id]
	var stream := _load_asset(id)
	if stream == null:
		stream = ProceduralAudio.generate(id)
	_store(id, stream)
	return stream


## True when a real audio file (rather than a procedural placeholder) backs this id.
func has_asset_file(id: StringName) -> bool:
	return _find_asset_path(id) != ""


## Plays a non-positional one-shot. Returns the player used (or null).
func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0, bus: StringName = BUS_SFX) -> AudioStreamPlayer:
	var player := _get_free_player()
	player.stream = get_stream(id)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = bus
	player.play()
	return player


## Plays a positional one-shot in the current scene; it frees itself when done.
func play_at(
	id: StringName, position: Vector3, volume_db: float = 0.0, max_distance: float = 30.0
) -> AudioStreamPlayer3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = get_stream(id)
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.unit_size = 4.0
	player.bus = BUS_SFX
	scene.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Starts (or fades in) a looping ambience track.
func start_ambience(id: StringName, volume_db: float = 0.0, fade_time: float = 1.5) -> void:
	var player: AudioStreamPlayer = _ambience_players.get(id)
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "Ambience_%s" % id
		player.bus = BUS_AMBIENCE
		player.stream = get_stream(id)
		add_child(player)
		_ambience_players[id] = player
	if not player.playing:
		player.volume_db = -60.0
		player.play()
	_tween_ambience(id, player, volume_db, fade_time, false)


func stop_ambience(id: StringName, fade_time: float = 1.0) -> void:
	var player: AudioStreamPlayer = _ambience_players.get(id)
	if player != null and player.playing:
		_tween_ambience(id, player, -60.0, fade_time, true)


func stop_all_ambience(fade_time: float = 0.5) -> void:
	for id: StringName in _ambience_players.keys():
		stop_ambience(id, fade_time)


func is_ambience_playing(id: StringName) -> bool:
	var player: AudioStreamPlayer = _ambience_players.get(id)
	return player != null and player.playing


## Plays the station chime followed by an announcement voice clip.
## Returns the total duration in seconds so callers can time subtitles.
func play_announcement(voice_id: StringName) -> float:
	var chime := get_stream(&"chime")
	var voice := get_stream(voice_id)
	play(&"chime", -2.0, 1.0, BUS_ANNOUNCER)
	var delay := chime.get_length() * 0.8
	get_tree().create_timer(delay, true).timeout.connect(play.bind(voice_id, 0.0, 1.0, BUS_ANNOUNCER))
	return delay + voice.get_length()


func stop_all_one_shots() -> void:
	for player in _pool:
		player.stop()


# --- Internals -----------------------------------------------------------------


## Runs on a worker thread: pure procedural synthesis only (no scene tree access).
func _generate_in_background(ids: Array[StringName]) -> void:
	for id in ids:
		if _cancel_prewarm:
			return
		var stream := ProceduralAudio.generate(id)
		_mutex.lock()
		_pending[id] = stream
		_mutex.unlock()


func _collect_pending() -> void:
	_mutex.lock()
	if _pending.is_empty():
		_mutex.unlock()
		return
	var finished_streams := _pending.duplicate()
	_pending.clear()
	_mutex.unlock()
	for id: StringName in finished_streams.keys():
		if not _cache.has(id):
			_store(id, finished_streams[id])


func _store(id: StringName, stream: AudioStream) -> void:
	if id in LOOPING_IDS:
		_force_loop(stream)
	_cache[id] = stream


func _find_asset_path(id: StringName) -> String:
	var stem: String = CATALOGUE.get(id, "")
	if stem.is_empty():
		return ""
	for ext: String in ASSET_EXTENSIONS:
		var path := "%s.%s" % [stem, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


func _load_asset(id: StringName) -> AudioStream:
	var path := _find_asset_path(id)
	if path.is_empty():
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: '%s' exists but is not an AudioStream; using placeholder." % path)
	return stream


func _force_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			var bytes_per_frame := (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
			wav.loop_end = floori(wav.data.size() / float(bytes_per_frame))
	elif "loop" in stream:
		# AudioStreamOggVorbis and AudioStreamMP3 expose a simple `loop` flag.
		stream.set("loop", true)


func _get_free_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	# All busy: steal the first player (oldest sounds are least important).
	var stolen: AudioStreamPlayer = _pool.pop_front()
	_pool.append(stolen)
	stolen.stop()
	return stolen


func _tween_ambience(
	id: StringName, player: AudioStreamPlayer, target_db: float, fade_time: float, stop_after: bool
) -> void:
	var old: Tween = _ambience_tweens.get(id)
	if old != null and old.is_valid():
		old.kill()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, maxf(fade_time, 0.01))
	if stop_after:
		tween.tween_callback(player.stop)
	_ambience_tweens[id] = tween


## Makes sure the expected buses exist even if the bus layout file is missing.
func _ensure_buses() -> void:
	for bus_name: StringName in [BUS_AMBIENCE, BUS_SFX, BUS_ANNOUNCER]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
		if bus_name == BUS_ANNOUNCER:
			var reverb := AudioEffectReverb.new()
			reverb.room_size = 0.75
			reverb.damping = 0.5
			reverb.wet = 0.3
			AudioServer.add_bus_effect(index, reverb)
