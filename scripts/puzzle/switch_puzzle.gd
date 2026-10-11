class_name SwitchPuzzle
extends Node3D
## The emergency breaker panel: close the PowerSwitch children in the right order.
##
## Correct order (red -> yellow -> green) is hinted by the maintenance log and the
## signal-aspect poster. A wrong breaker trips the panel: sparks, red flash, all
## breakers reset. Hints get more direct after repeated mistakes. Solving unlocks
## [member door_path] and emits [signal solved] for the suspense event.

signal progressed(step: int, total: int)
signal mistake_made(mistakes: int)
signal solved

@export var solution: PackedStringArray = PackedStringArray(["red", "yellow", "green"])
@export var door_path: NodePath
@export var reset_delay: float = 0.9
@export var hint_after_mistakes: int = 2
@export var strong_hint_after_mistakes: int = 4

var is_solved: bool = false
var switches: Array[PowerSwitch] = []
var _lock: SequenceLock
var _busy: bool = false


func _ready() -> void:
	var ids: Array[StringName] = []
	for id in solution:
		ids.append(StringName(id))
	_lock = SequenceLock.new(ids)
	for child in get_children():
		if child is PowerSwitch:
			var power_switch := child as PowerSwitch
			switches.append(power_switch)
			power_switch.switched.connect(_on_switched)


func get_mistakes() -> int:
	return _lock.mistakes


func get_progress() -> int:
	return _lock.get_progress()


func get_switch(id: StringName) -> PowerSwitch:
	for power_switch in switches:
		if power_switch.switch_id == id:
			return power_switch
	return null


func _on_switched(id: StringName, is_on: bool) -> void:
	if not is_on or _busy or is_solved:
		return
	match _lock.press(id):
		SequenceLock.Result.PROGRESS:
			AudioManager.play(&"power_up", -14.0, 0.8 + 0.2 * _lock.get_progress())
			progressed.emit(_lock.get_progress(), solution.size())
		SequenceLock.Result.MISTAKE:
			_trip()
		SequenceLock.Result.SOLVED:
			_solve()


func _trip() -> void:
	_busy = true
	for power_switch in switches:
		power_switch.set_locked(true)
		power_switch.flash_fault()
	AudioManager.play_at(&"breaker_trip", global_position + Vector3.UP * 1.4, 2.0)
	GameState.flash_screen(Color(1.0, 0.25, 0.1, 0.45), 0.35)
	StoryText.say_lines(&"breaker_mistake")
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method(&"shake"):
		player.call(&"shake", 0.04, 0.35)
	mistake_made.emit(_lock.mistakes)
	await Sequence.wait(self, reset_delay)
	for power_switch in switches:
		power_switch.reset_off()
		power_switch.set_locked(false)
	_busy = false
	if _lock.mistakes >= strong_hint_after_mistakes:
		StoryText.say_lines(&"breaker_hint_strong")
	elif _lock.mistakes >= hint_after_mistakes:
		StoryText.say_lines(&"breaker_hint")


func _solve() -> void:
	is_solved = true
	for power_switch in switches:
		power_switch.set_locked(true)
	var door := get_node_or_null(door_path) as Door
	if door != null:
		door.unlock(false)
	solved.emit()
