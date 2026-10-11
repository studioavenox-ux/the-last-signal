extends "res://tests/test_suite.gd"
## Project configuration checks: input map, autoloads, audio buses, platform settings.

const REQUIRED_ACTIONS := [
	&"move_forward",
	&"move_back",
	&"move_left",
	&"move_right",
	&"look_left",
	&"look_right",
	&"look_up",
	&"look_down",
	&"interact",
	&"pause",
	&"toggle_flashlight",
	&"sprint",
	&"toggle_touch_ui",
]


func test_input_actions_exist_with_events() -> void:
	for action: StringName in REQUIRED_ACTIONS:
		if check(InputMap.has_action(action), "input action '%s' exists" % action):
			check(InputMap.action_get_events(action).size() > 0, "input action '%s' has at least one binding" % action)
	# Keyboard + gamepad coverage for core actions.
	for action: StringName in [&"move_forward", &"interact", &"pause"]:
		var has_key := false
		var has_pad := false
		for event in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_pad = has_pad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		check(has_key and has_pad, "'%s' is bound on keyboard and gamepad" % action)


func test_autoloads_present() -> void:
	for autoload_name: String in ["Settings", "GameState", "VirtualInput", "AudioManager"]:
		check(tree.root.has_node(autoload_name), "autoload %s is running" % autoload_name)


func test_audio_buses() -> void:
	var layout_path: String = ProjectSettings.get_setting("audio/buses/default_bus_layout")
	check(load(layout_path) is AudioBusLayout, "bus layout file loads: %s" % layout_path)
	for bus_name: String in ["Ambience", "SFX", "Announcer"]:
		check(AudioServer.get_bus_index(bus_name) != -1, "audio bus '%s' exists" % bus_name)
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Announcer")) >= 1, "announcer bus has its reverb")


func test_platform_settings() -> void:
	check_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"),
		"gl_compatibility",
		"mobile renderer is Compatibility (widest low-end Android support)"
	)
	check_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 4, "sensor-landscape orientation")
	check_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "UI scales with screen size")
	check_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "UI adapts to phone aspect ratios")
	check_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics", "Jolt physics selected")
	check_eq(
		ProjectSettings.get_setting("application/config/quit_on_go_back"), false, "Android Back is handled by the game"
	)
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	check(ResourceLoader.exists(main_scene), "main scene exists: %s" % main_scene)
