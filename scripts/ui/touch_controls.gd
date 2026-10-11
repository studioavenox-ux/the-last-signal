class_name TouchControls
extends Control
## On-screen controls for phones and tablets.
##
## - Left ~42% of the screen: floating joystick (appears under the thumb) for walking.
## - Rest of the screen: drag to look around.
## - Big USE button (pulses when something can be used), LIGHT (torch) and II (pause).
##
## Multi-touch aware (each finger keeps its role until lifted). Writes movement and
## look into the VirtualInput autoload and sends buttons as Input Map actions, so
## gameplay code treats touch exactly like keyboard or gamepad input.
## Everything is drawn in _draw(): no textures, one canvas item.

const JOYSTICK_RADIUS := 95.0
const KNOB_RADIUS := 42.0
const DEADZONE := 0.12
const LEFT_ZONE_RATIO := 0.42
const BUTTON_HIT_SCALE := 1.25

var _move_finger: int = -1
var _look_finger: int = -1
var _button_fingers: Dictionary = {}
var _joy_home: Vector2 = Vector2.ZERO
var _joy_center: Vector2 = Vector2.ZERO
var _joy_knob: Vector2 = Vector2.ZERO
var _buttons: Dictionary = {}
var _prompt_text: String = ""
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.prompt_changed.connect(_on_prompt_changed)
	VirtualInput.touch_ui_visibility_changed.connect(_on_visibility_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_on_visibility_changed(VirtualInput.is_touch_ui_enabled())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		# Releases sent now still reach Input; avoids stuck actions after resuming.
		release_all()


func _process(delta: float) -> void:
	_time += delta
	if not _prompt_text.is_empty():
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_touch_down(touch.index, touch.position)
		else:
			_on_touch_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_on_drag(drag.index, drag.position, drag.relative)


## Lets go of every finger (used on pause, hide and scene changes).
func release_all() -> void:
	for index: int in _button_fingers.keys():
		_set_button(_button_fingers[index], false)
	_button_fingers.clear()
	_move_finger = -1
	_look_finger = -1
	_joy_center = _joy_home
	_joy_knob = _joy_home
	VirtualInput.move_vector = Vector2.ZERO
	queue_redraw()


func get_button_center(id: StringName) -> Vector2:
	return (_buttons[id] as Dictionary)["center"] if _buttons.has(id) else Vector2.ZERO


# --- Touch handling ------------------------------------------------------------


func _on_touch_down(index: int, pos: Vector2) -> void:
	for id: StringName in _buttons.keys():
		var button: Dictionary = _buttons[id]
		if pos.distance_to(button["center"]) <= float(button["radius"]) * BUTTON_HIT_SCALE:
			_button_fingers[index] = id
			_set_button(id, true)
			get_viewport().set_input_as_handled()
			return
	var view_size := get_viewport_rect().size
	if pos.x < view_size.x * LEFT_ZONE_RATIO and _move_finger == -1:
		_move_finger = index
		var margin := Vector2(JOYSTICK_RADIUS, JOYSTICK_RADIUS)
		_joy_center = pos.clamp(margin, view_size - margin)
		_update_joystick(pos)
		get_viewport().set_input_as_handled()
		return
	if _look_finger == -1:
		_look_finger = index
		get_viewport().set_input_as_handled()


func _on_touch_up(index: int) -> void:
	if _button_fingers.has(index):
		_set_button(_button_fingers[index], false)
		_button_fingers.erase(index)
	elif index == _move_finger:
		_move_finger = -1
		_joy_center = _joy_home
		_joy_knob = _joy_home
		VirtualInput.move_vector = Vector2.ZERO
	elif index == _look_finger:
		_look_finger = -1
	queue_redraw()


func _on_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _move_finger:
		_update_joystick(pos)
		get_viewport().set_input_as_handled()
	elif index == _look_finger:
		VirtualInput.add_look(relative)
		get_viewport().set_input_as_handled()


func _update_joystick(pos: Vector2) -> void:
	var offset := (pos - _joy_center).limit_length(JOYSTICK_RADIUS)
	_joy_knob = _joy_center + offset
	var v := offset / JOYSTICK_RADIUS
	var magnitude := v.length()
	if magnitude < DEADZONE:
		v = Vector2.ZERO
	else:
		v = v / magnitude * inverse_lerp(DEADZONE, 1.0, minf(magnitude, 1.0))
	# Screen "up" is negative y, which matches move_forward in Input.get_vector().
	VirtualInput.move_vector = v
	queue_redraw()


func _set_button(id: StringName, pressed: bool) -> void:
	var button: Dictionary = _buttons.get(id, {})
	if button.is_empty():
		return
	VirtualInput.send_action(button["action"], pressed)
	queue_redraw()


# --- Layout & drawing ----------------------------------------------------------


func _layout() -> void:
	var view_size := get_viewport_rect().size
	var m := UiUtil.safe_area_margins(get_viewport())
	_joy_home = Vector2(60.0 + m.x + JOYSTICK_RADIUS, view_size.y - 50.0 - m.w - JOYSTICK_RADIUS)
	if _move_finger == -1:
		_joy_center = _joy_home
		_joy_knob = _joy_home
	var right := view_size.x - m.z
	var bottom := view_size.y - m.w
	_buttons = {
		&"interact":
		{"center": Vector2(right - 140.0, bottom - 170.0), "radius": 82.0, "label": "USE", "action": &"interact"},
		&"flashlight":
		{
			"center": Vector2(right - 300.0, bottom - 85.0),
			"radius": 50.0,
			"label": "LIGHT",
			"action": &"toggle_flashlight"
		},
		&"pause": {"center": Vector2(right - 62.0, 62.0 + m.y), "radius": 38.0, "label": "II", "action": &"pause"},
	}
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var active := _move_finger != -1
	draw_circle(_joy_center, JOYSTICK_RADIUS, Color(1, 1, 1, 0.12 if active else 0.07))
	draw_arc(_joy_center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.45 if active else 0.28), 3.0, true)
	draw_circle(_joy_knob, KNOB_RADIUS, Color(1, 1, 1, 0.42 if active else 0.24))
	for id: StringName in _buttons.keys():
		var button: Dictionary = _buttons[id]
		var center: Vector2 = button["center"]
		var radius: float = button["radius"]
		var pressed := _button_fingers.values().has(id)
		var fill := Color(1, 1, 1, 0.14)
		var ring := Color(1, 1, 1, 0.5)
		if id == &"interact" and not _prompt_text.is_empty():
			var pulse := 0.5 + 0.5 * sin(_time * 6.0)
			fill = Color(0.95, 0.32, 0.22, 0.35 + 0.2 * pulse)
			ring = Color(1.0, 0.62, 0.46, 0.95)
		if pressed:
			fill.a = minf(fill.a + 0.3, 0.9)
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 48, ring, 3.0, true)
		var font_size := 30 if id == &"interact" else 20
		var text: String = button["label"]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(
			font,
			center + Vector2(-text_size.x * 0.5, font_size * 0.35),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(1, 1, 1, 0.92)
		)
	if not _prompt_text.is_empty() and _buttons.has(&"interact"):
		var center: Vector2 = (_buttons[&"interact"] as Dictionary)["center"]
		var font_size := 22
		var text_size := font.get_string_size(_prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2(
			minf(center.x - text_size.x * 0.5, get_viewport_rect().size.x - text_size.x - 12.0), center.y - 100.0
		)
		draw_string_outline(font, pos, _prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.85))
		draw_string(font, pos, _prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.85, 0.75))


func _on_prompt_changed(text: String) -> void:
	_prompt_text = text
	queue_redraw()


func _on_visibility_changed(show_controls: bool) -> void:
	if not show_controls:
		release_all()
	visible = show_controls
	set_process_input(show_controls)
