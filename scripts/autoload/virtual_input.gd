extends Node
## Bridge between on-screen touch controls and gameplay.
##
## Touch widgets write into this singleton; [PlayerInput] reads from it alongside
## keyboard, mouse and gamepad. Gameplay code therefore never needs to know which
## device produced an input.
##
## Button-style inputs (interact, pause, flashlight) are injected as regular
## [InputEventAction]s, so they flow through the same Input Map actions that
## keyboards and gamepads use.

signal touch_ui_visibility_changed(visible: bool)

## Analog movement from the virtual joystick. x = strafe (right +), y = forward (-) / back (+),
## matching Input.get_vector("move_left", "move_right", "move_forward", "move_back").
var move_vector: Vector2 = Vector2.ZERO

var _look_accumulator: Vector2 = Vector2.ZERO
var _debug_force_touch: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.changed.connect(_on_settings_changed)


func _unhandled_input(event: InputEvent) -> void:
	# F3 toggles the touch overlay on desktop so it can be tested with a mouse.
	if event.is_action_pressed(&"toggle_touch_ui"):
		set_debug_force_touch(not _debug_force_touch)
		get_viewport().set_input_as_handled()


## Adds a look delta in viewport pixels (from a touch drag).
func add_look(delta_pixels: Vector2) -> void:
	_look_accumulator += delta_pixels


## Returns and clears the accumulated touch look delta (viewport pixels).
func consume_look() -> Vector2:
	var value := _look_accumulator
	_look_accumulator = Vector2.ZERO
	return value


## Sends a press or release of an Input Map action through the normal input pipeline.
func send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func reset() -> void:
	move_vector = Vector2.ZERO
	_look_accumulator = Vector2.ZERO


func is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## True when the on-screen touch controls should be shown.
func is_touch_ui_enabled() -> bool:
	if _debug_force_touch:
		return true
	match Settings.touch_mode:
		Settings.TouchMode.ALWAYS:
			return true
		Settings.TouchMode.NEVER:
			return false
	return is_mobile_platform()


func set_debug_force_touch(enabled: bool) -> void:
	_debug_force_touch = enabled
	# Let a desktop mouse drive the touch widgets while testing.
	Input.emulate_touch_from_mouse = enabled and not is_mobile_platform()
	touch_ui_visibility_changed.emit(is_touch_ui_enabled())


func _on_settings_changed() -> void:
	touch_ui_visibility_changed.emit(is_touch_ui_enabled())
