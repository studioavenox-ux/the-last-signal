extends Node
## Global game state and event bus.
##
## Holds story flags and the current objective, and broadcasts UI-facing events
## (subtitles, notifications, interaction prompts, documents). Gameplay objects
## call into this singleton; UI scenes listen to its signals. Nothing here knows
## about specific scenes, which keeps objects reusable.

signal objective_changed(text: String)
signal subtitle_requested(text: String, speaker: String, duration: float)
signal notification_requested(text: String, duration: float)
signal prompt_changed(text: String)
signal document_requested(document_id: StringName)
signal screen_flash_requested(color: Color, duration: float)
signal flag_changed(flag: StringName, value: Variant)
signal pause_state_changed(paused: bool)
signal game_ended

const TITLE_SCENE := "res://scenes/main/title_screen.tscn"
const LEVEL_SCENE := "res://scenes/levels/station.tscn"

var objective: String = ""
var flags: Dictionary = {}
## Seconds spent in the level (excluding pauses); useful for playtest notes.
var play_time: float = 0.0
var is_playing: bool = false

var _pause_sources: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if is_playing and not get_tree().paused:
		play_time += delta


# --- Story state -------------------------------------------------------------


func reset_state() -> void:
	objective = ""
	flags.clear()
	play_time = 0.0
	is_playing = false
	_pause_sources.clear()


func set_flag(flag: StringName, value: Variant = true) -> void:
	if flags.get(flag) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: StringName) -> bool:
	return bool(flags.get(flag, false))


func get_flag(flag: StringName, default_value: Variant = null) -> Variant:
	return flags.get(flag, default_value)


func set_objective(text: String) -> void:
	if text == objective:
		return
	objective = text
	objective_changed.emit(text)


# --- UI events ---------------------------------------------------------------


## Shows a subtitle line. A negative duration picks one based on text length.
func say(text: String, speaker: String = "", duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = estimate_read_time(text)
	subtitle_requested.emit(text, speaker, duration)


func notify(text: String, duration: float = 3.5) -> void:
	notification_requested.emit(text, duration)


func set_prompt(text: String) -> void:
	prompt_changed.emit(text)


func open_document(document_id: StringName) -> void:
	document_requested.emit(document_id)


func flash_screen(color: Color, duration: float = 0.35) -> void:
	screen_flash_requested.emit(color, duration)


func end_game() -> void:
	is_playing = false
	game_ended.emit()


static func estimate_read_time(text: String) -> float:
	return clampf(1.6 + text.length() * 0.055, 2.4, 8.0)


# --- Pause handling ----------------------------------------------------------
# Several systems can pause the game (pause menu, document viewer, ending).
# Each registers a source; the tree stays paused while any source is active.


func request_pause(source: StringName) -> void:
	_pause_sources[source] = true
	_apply_pause()


func release_pause(source: StringName) -> void:
	_pause_sources.erase(source)
	_apply_pause()


func is_pause_source_active(source: StringName) -> bool:
	return _pause_sources.has(source)


func _apply_pause() -> void:
	var should_pause := not _pause_sources.is_empty()
	if get_tree().paused != should_pause:
		get_tree().paused = should_pause
		pause_state_changed.emit(should_pause)


# --- Scene flow --------------------------------------------------------------


func start_new_game() -> void:
	_change_scene(LEVEL_SCENE)


func restart_level() -> void:
	_change_scene(LEVEL_SCENE)


func go_to_title() -> void:
	_change_scene(TITLE_SCENE)


func _change_scene(path: String) -> void:
	reset_state()
	get_tree().paused = false
	VirtualInput.reset()
	AudioManager.stop_all_one_shots()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("GameState: failed to change scene to %s (error %d)" % [path, err])
