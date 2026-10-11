class_name PlayerInput
extends Node
## Collects player intent from every input source and exposes it device-agnostically.
##
## Sources: keyboard + mouse (desktop), gamepad, and on-screen touch controls (via the
## [code]VirtualInput[/code] autoload). The controller only asks "how do I want to move/look?",
## so adding a new device never touches movement code.

signal interact_requested
signal flashlight_toggle_requested

## Radians per (unscaled) screen pixel of mouse motion.
@export var mouse_sensitivity: float = 0.0022
## Radians per full viewport height of touch drag.
@export var touch_sensitivity: float = 2.8
## Radians per second at full right-stick deflection.
@export var gamepad_look_speed: float = 2.6

## When false, all movement/look/actions are ignored (cutscenes, ending).
var enabled: bool = true

var _mouse_delta: Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	# Mouse events emulated from touch carry DEVICE_ID_EMULATION; touch look is handled
	# by the touch controls instead, so ignore them here to avoid double input.
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and motion.device != InputEvent.DEVICE_ID_EMULATION:
			_mouse_delta += motion.screen_relative
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if (
			button.pressed
			and button.button_index == MOUSE_BUTTON_LEFT
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			and button.device != InputEvent.DEVICE_ID_EMULATION
		):
			get_viewport().set_input_as_handled()
			interact_requested.emit()
		return
	if event.is_action_pressed(&"interact"):
		# Consume it so a UI opened by this interaction can't receive the same press.
		get_viewport().set_input_as_handled()
		interact_requested.emit()
	elif event.is_action_pressed(&"toggle_flashlight"):
		get_viewport().set_input_as_handled()
		flashlight_toggle_requested.emit()


## Movement intent: x = strafe right, y = backwards (forward is negative). Length <= 1.
func get_move_vector() -> Vector2:
	if not enabled:
		return Vector2.ZERO
	var move := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	move += VirtualInput.move_vector
	return move.limit_length(1.0)


func is_sprinting() -> bool:
	return enabled and Input.is_action_pressed(&"sprint")


## Look delta in radians since the last call: x = yaw right, y = pitch up.
func consume_look(delta: float) -> Vector2:
	var look := _mouse_delta * mouse_sensitivity
	_mouse_delta = Vector2.ZERO
	var touch := VirtualInput.consume_look()
	if touch != Vector2.ZERO:
		var height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
		look += touch / height * touch_sensitivity
	look += Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down") * gamepad_look_speed * delta
	if not enabled:
		return Vector2.ZERO
	look *= Settings.look_sensitivity
	var pitch := -look.y
	if Settings.invert_y:
		pitch = -pitch
	return Vector2(look.x, pitch)
