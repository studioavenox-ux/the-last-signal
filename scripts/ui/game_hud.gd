extends CanvasLayer
## One visual language across title, HUD, investigation, pause, and ending.
signal begin_requested
signal resume_requested
signal restart_requested
signal document_closed
signal interaction_requested
signal pause_requested
signal look_requested(relative: Vector2)
signal journal_requested
signal settings_requested
signal settings_closed
signal volume_changed(value: float)
signal sensitivity_changed(value: float)

const Joystick = preload("res://scripts/ui/touch_joystick.gd")
const LookZone = preload("res://scripts/ui/look_zone.gd")
const INK := Color(0.018, 0.045, 0.057, 0.96)
const AMBER := Color(0.97, 0.64, 0.23)
const PALE := Color(0.83, 0.9, 0.87)

var hud: Control
var title_screen: ColorRect
var reader: ColorRect
var pause_screen: ColorRect
var ending: ColorRect
var settings_screen: ColorRect
var volume_slider: HSlider
var sensitivity_slider: HSlider
var chapter_number := 1
var stamp_label: Label
var objective_label: Label
var prompt_label: Label
var reticle: Label
var status_label: Label
var reader_title: Label
var reader_body: RichTextLabel
var ending_body: RichTextLabel
var touch_controls: Control
var joystick
var look_zone
var status_seconds := 0.0


func _ready() -> void:
	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	var top := panel(
		hud, Vector2(0.018, 0.025), Vector2(0.62, 0.19), Color(0.02, 0.065, 0.078, 0.83)
	)
	stamp_label = text(
		top,
		"●  AVENOX GAMES   /   NIRVA HALT      11:47 PM",
		Vector2(0.03, 0.12),
		Vector2(0.98, 0.45),
		17,
		AMBER
	)
	stamp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label = text(
		top,
		"OBJECTIVE  /  Find the station logbook",
		Vector2(0.03, 0.49),
		Vector2(0.98, 0.96),
		20,
		PALE
	)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label = text(hud, "", Vector2(0.26, 0.79), Vector2(0.74, 0.87), 25, AMBER)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label = text(hud, "", Vector2(0.19, 0.21), Vector2(0.81, 0.31), 23, PALE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reticle = text(hud, "+", Vector2(0.48, 0.47), Vector2(0.52, 0.53), 25, PALE)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var journal_btn := button(hud, "NOTES", Vector2(0.66, 0.03), Vector2(0.81, 0.12))
	journal_btn.pressed.connect(func() -> void: journal_requested.emit())
	var pause_btn := button(hud, "II  PAUSE", Vector2(0.83, 0.03), Vector2(0.98, 0.12))
	pause_btn.pressed.connect(func() -> void: pause_requested.emit())

	touch_controls = Control.new()
	touch_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(touch_controls)
	look_zone = LookZone.new()
	place(look_zone, Vector2(0.50, 0.14), Vector2(1.0, 1.0))
	touch_controls.add_child(look_zone)
	look_zone.moved.connect(func(relative: Vector2) -> void: look_requested.emit(relative))
	joystick = Joystick.new()
	place(joystick, Vector2(0.025, 0.67), Vector2(0.195, 0.97))
	touch_controls.add_child(joystick)
	var act := button(touch_controls, "INTERACT", Vector2(0.79, 0.76), Vector2(0.98, 0.94))
	act.pressed.connect(func() -> void: interaction_requested.emit())
	touch_controls.visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

	title_screen = overlay(canvas)
	title_screen.color = Color(0.006, 0.019, 0.028, 0.76)
	var title_panel := panel(
		title_screen, Vector2(0.08, 0.12), Vector2(0.92, 0.90), Color(0.018, 0.045, 0.057, 0.89)
	)
	text(
		title_panel,
		"AVENOX GAMES   /   AN ORIGINAL THRILLER",
		Vector2(0.06, 0.09),
		Vector2(0.94, 0.17),
		18,
		AMBER
	)
	text(title_panel, "THE LAST SIGNAL", Vector2(0.06, 0.23), Vector2(0.94, 0.42), 53, PALE)
	var tagline := text(
		title_panel,
		(
			"NIRVA HALT  •  MONSOON NIGHT  •  11:47 PM\n\n"
			+ "Aarav... if you're hearing this, don't let them announce the train.\n"
			+ "Platform Three. Midnight."
		),
		Vector2(0.06, 0.45),
		Vector2(0.94, 0.71),
		22,
		PALE
	)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var begin_button := button(
		title_panel, "BEGIN  /  ENTER THE STATION", Vector2(0.53, 0.77), Vector2(0.94, 0.90)
	)
	begin_button.pressed.connect(func() -> void: begin_requested.emit())
	button(title_panel, "SETTINGS", Vector2(0.06, 0.77), Vector2(0.42, 0.90)).pressed.connect(
		func() -> void: settings_requested.emit()
	)

	reader = overlay(canvas)
	var paper := panel(reader, Vector2(0.14, 0.11), Vector2(0.86, 0.89), INK)
	reader_title = text(paper, "", Vector2(0.06, 0.08), Vector2(0.94, 0.2), 31, AMBER)
	reader_body = scroll_text(paper, Vector2(0.06, 0.23), Vector2(0.94, 0.78), 24)
	button(paper, "CLOSE  /  CONTINUE", Vector2(0.58, 0.82), Vector2(0.94, 0.95)).pressed.connect(
		func() -> void: document_closed.emit()
	)
	reader.visible = false

	pause_screen = overlay(canvas)
	var pause_panel := panel(pause_screen, Vector2(0.28, 0.16), Vector2(0.72, 0.84), INK)
	text(pause_panel, "SIGNAL INTERRUPTED", Vector2(0.07, 0.11), Vector2(0.94, 0.29), 34, AMBER)
	button(pause_panel, "RESUME", Vector2(0.1, 0.35), Vector2(0.9, 0.49)).pressed.connect(
		func() -> void: resume_requested.emit()
	)
	button(pause_panel, "SETTINGS", Vector2(0.1, 0.53), Vector2(0.9, 0.67)).pressed.connect(
		func() -> void: settings_requested.emit()
	)
	button(pause_panel, "RESTART", Vector2(0.1, 0.72), Vector2(0.9, 0.86)).pressed.connect(
		func() -> void: restart_requested.emit()
	)
	pause_screen.visible = false

	settings_screen = overlay(canvas)
	var settings_panel := panel(settings_screen, Vector2(0.21, 0.12), Vector2(0.79, 0.88), INK)
	text(
		settings_panel,
		"SETTINGS  /  THE LAST SIGNAL",
		Vector2(0.08, 0.07),
		Vector2(0.94, 0.20),
		30,
		AMBER
	)
	text(
		settings_panel,
		"AMBIENCE + EFFECTS VOLUME",
		Vector2(0.10, 0.25),
		Vector2(0.9, 0.32),
		21,
		PALE
	)
	volume_slider = slider(settings_panel, Vector2(0.1, 0.34), Vector2(0.9, 0.42), 0.0, 1.0)
	volume_slider.value_changed.connect(func(value: float) -> void: volume_changed.emit(value))
	text(settings_panel, "LOOK SENSITIVITY", Vector2(0.10, 0.48), Vector2(0.9, 0.55), 21, PALE)
	sensitivity_slider = slider(settings_panel, Vector2(0.1, 0.57), Vector2(0.9, 0.65), 0.5, 1.7)
	sensitivity_slider.value_changed.connect(
		func(value: float) -> void: sensitivity_changed.emit(value)
	)
	button(settings_panel, "BACK", Vector2(0.55, 0.76), Vector2(0.9, 0.9)).pressed.connect(
		func() -> void: settings_closed.emit()
	)
	settings_screen.visible = false

	ending = overlay(canvas)
	var end_panel := panel(ending, Vector2(0.12, 0.1), Vector2(0.88, 0.9), INK)
	text(
		end_panel,
		"PLATFORM THREE  /  12:00 AM",
		Vector2(0.06, 0.08),
		Vector2(0.94, 0.17),
		20,
		AMBER
	)
	text(end_panel, "THE LAST SIGNAL", Vector2(0.06, 0.2), Vector2(0.94, 0.34), 43, PALE)
	ending_body = scroll_text(end_panel, Vector2(0.06, 0.38), Vector2(0.94, 0.73), 25)
	button(end_panel, "PLAY AGAIN", Vector2(0.53, 0.78), Vector2(0.94, 0.91)).pressed.connect(
		func() -> void: restart_requested.emit()
	)
	ending.visible = false
	hud.visible = false


func _process(delta: float) -> void:
	if status_seconds > 0.0:
		status_seconds -= delta
		if status_seconds <= 0.0:
			status_label.text = ""


func reset_touch() -> void:
	joystick.reset()
	look_zone.reset()


func get_move() -> Vector2:
	if joystick.finger != -1 and touch_controls.visible:
		return joystick.value
	return Vector2.ZERO


func set_clock(time: String) -> void:
	stamp_label.text = (
		"●  AVENOX GAMES   /   NIRVA HALT      " + time + " PM"
		if time != "12:00"
		else "●  AVENOX GAMES   /   NIRVA HALT      12:00 AM"
	)


func set_chapter(number: int) -> void:
	chapter_number = number


func set_objective(message: String) -> void:
	objective_label.text = "CHAPTER %02d  /  OBJECTIVE\n%s" % [chapter_number, message]


func set_prompt(message: String) -> void:
	prompt_label.text = message
	reticle.add_theme_color_override("font_color", AMBER if not message.is_empty() else PALE)


func flash(message: String, seconds: float = 4.0) -> void:
	status_label.text = message
	status_seconds = seconds


func open_document(heading: String, body: String) -> void:
	reader_title.text = heading
	reader_body.text = body
	reader.visible = true
	hud.visible = false


func show_settings(saved_volume: float, saved_sensitivity: float) -> void:
	volume_slider.set_value_no_signal(saved_volume)
	sensitivity_slider.set_value_no_signal(saved_sensitivity)
	settings_screen.visible = true


func show_end(body: String) -> void:
	ending_body.text = body
	ending.visible = true
	hud.visible = false


func place(control: Control, start: Vector2, finish: Vector2) -> void:
	control.anchor_left = start.x
	control.anchor_top = start.y
	control.anchor_right = finish.x
	control.anchor_bottom = finish.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func overlay(parent: Control) -> ColorRect:
	var layer := ColorRect.new()
	place(layer, Vector2.ZERO, Vector2.ONE)
	layer.color = Color(0.006, 0.019, 0.028, 0.89)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(layer)
	return layer


func panel(parent: Control, start: Vector2, finish: Vector2, color: Color) -> ColorRect:
	var background := ColorRect.new()
	place(background, start, finish)
	background.color = color
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)
	return background


func text(
	parent: Control, content: String, start: Vector2, finish: Vector2, font_size: int, color: Color
) -> Label:
	var line := Label.new()
	place(line, start, finish)
	line.text = content
	line.add_theme_font_size_override("font_size", font_size)
	line.add_theme_color_override("font_color", color)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line


func scroll_text(parent: Control, start: Vector2, finish: Vector2, font_size: int) -> RichTextLabel:
	var page := RichTextLabel.new()
	place(page, start, finish)
	page.bbcode_enabled = false
	page.scroll_active = true
	page.add_theme_font_size_override("normal_font_size", font_size)
	page.add_theme_color_override("default_color", PALE)
	parent.add_child(page)
	return page


func slider(parent: Control, start: Vector2, finish: Vector2, low: float, high: float) -> HSlider:
	var control := HSlider.new()
	place(control, start, finish)
	control.min_value = low
	control.max_value = high
	control.step = 0.05
	parent.add_child(control)
	return control


func button(parent: Control, content: String, start: Vector2, finish: Vector2) -> Button:
	var action := Button.new()
	place(action, start, finish)
	action.text = content
	action.add_theme_font_size_override("font_size", 21)
	action.add_theme_color_override("font_color", Color(0.05, 0.08, 0.09))
	var normal := StyleBoxFlat.new()
	normal.bg_color = AMBER
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	action.add_theme_stylebox_override("normal", normal)
	parent.add_child(action)
	return action
