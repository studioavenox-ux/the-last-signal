class_name PowerRestoredEvent
extends Node
## Suspense beat after the breaker puzzle is solved.
##
## Blackout -> emergency power surges on (lighting change, hum) -> monitors boot ->
## the announcement greets Aarav by name ("Welcome back") -> the stopped clock
## starts again -> a stinger and a flicker. Cheap by design: light energy/colour
## tweens, Label3D text and procedural audio - no particles or post effects.

signal finished

@export var control_monitor_path: NodePath
@export var departure_board_path: NodePath
@export var station_clock_path: NodePath
@export var breaker_panel_path: NodePath
@export var world_environment_path: NodePath
@export var emergency_ambient: Color = Color(0.3, 0.13, 0.1)
@export var emergency_fog: Color = Color(0.16, 0.06, 0.05)

var has_started: bool = false
var has_finished: bool = false


## Lights taking part in the event are FlickerLights in the "station_lights" group.
func get_station_lights() -> Array[FlickerLight]:
	var lights: Array[FlickerLight] = []
	for node in get_tree().get_nodes_in_group(&"station_lights"):
		if node is FlickerLight:
			lights.append(node as FlickerLight)
	return lights


func play() -> void:
	if has_started:
		return
	has_started = true
	GameState.set_flag(&"power_restored")
	var lights := get_station_lights()
	var control_monitor := get_node_or_null(control_monitor_path) as StationMonitor
	var departure_board := get_node_or_null(departure_board_path) as StationMonitor
	var clock := get_node_or_null(station_clock_path) as StationClock
	var panel := get_node_or_null(breaker_panel_path) as Node3D
	var env_node := get_node_or_null(world_environment_path) as WorldEnvironment

	# 1) Everything dies for a heartbeat.
	AudioManager.play(&"power_down", -2.0)
	for light in lights:
		light.set_mode(FlickerLight.Mode.OFF)
	await Sequence.wait(self, 1.3)

	# 2) Emergency power surges on: new colour, new mood.
	AudioManager.play(&"power_up", 0.0)
	AudioManager.start_ambience(&"hum", -18.0, 2.5)
	if panel != null:
		AudioManager.play_at(&"hum", panel.global_position + Vector3.UP * 1.4, -6.0, 12.0)
	for light in lights:
		light.set_mode(FlickerLight.Mode.EMERGENCY)
		light.surge(1.8, 0.9)
	if env_node != null and env_node.environment != null:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(env_node.environment, "ambient_light_color", emergency_ambient, 2.0)
		tween.tween_property(env_node.environment, "fog_light_color", emergency_fog, 2.0)
	StoryText.say_lines(&"power_restored")
	await Sequence.wait(self, 1.4)

	# 3) The screens wake up.
	if control_monitor != null:
		control_monitor.power_on(StoryText.CONTROL_MONITOR_BOOT)
	if departure_board != null:
		departure_board.power_on(StoryText.DEPARTURE_BOARD_TEXT)
	await Sequence.wait(self, 2.8)

	# 4) The station speaks to Aarav.
	AudioManager.play_announcement(&"announce_power")
	StoryText.say_lines(&"announce_power")
	await Sequence.wait(self, 2.5)
	if control_monitor != null:
		control_monitor.glitch_to(StoryText.CONTROL_MONITOR_FINAL)
	if clock != null:
		clock.start(1.0)
	await Sequence.wait(self, 4.5)

	# 5) Something is wrong: stinger + the lights choke for a moment.
	AudioManager.play(&"stinger", -3.0)
	for light in lights:
		light.surge(0.08, 0.7)
	await Sequence.wait(self, 1.5)
	GameState.set_objective(StoryText.get_objective(&"go_platform"))
	has_finished = true
	finished.emit()
