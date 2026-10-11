class_name PauseMenu
extends CanvasLayer
## Pause menu: resume, restart, main menu, and the settings players need most on
## phones (look sensitivity, invert Y, touch controls).
##
## Opens with Pause (Esc / P / gamepad Start / on-screen II button), the Android
## Back button, or automatically when the app loses focus.

const PAUSE_SOURCE := &"pause_menu"

@onready var root: Control = $Root
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var title_button: Button = %TitleButton
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: Label = %SensitivityValue
@onready var invert_check: CheckButton = %InvertCheck
@onready var touch_check: CheckButton = %TouchCheck
@onready var controls_hint: Label = %ControlsHint


func _ready() -> void:
	root.visible = false
	resume_button.pressed.connect(close)
	restart_button.pressed.connect(_on_restart)
	title_button.pressed.connect(_on_title)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	invert_check.toggled.connect(_on_invert_toggled)
	touch_check.toggled.connect(_on_touch_toggled)


func _unhandled_input(event: InputEvent) -> void:
	# The document viewer handles Pause/Back itself while it is open.
	if _document_open():
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		toggle()
	elif root.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if not _document_open():
				toggle()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if _can_open():
				open()


func is_open() -> bool:
	return root.visible


func toggle() -> void:
	if root.visible:
		close()
	elif _can_open():
		open()


func open() -> void:
	if root.visible:
		return
	_sync_settings_ui()
	root.visible = true
	GameState.request_pause(PAUSE_SOURCE)
	resume_button.grab_focus()


func close() -> void:
	if not root.visible:
		return
	root.visible = false
	Settings.save_settings()
	GameState.release_pause(PAUSE_SOURCE)


func _can_open() -> bool:
	return GameState.is_playing and not _document_open()


func _document_open() -> bool:
	return GameState.is_pause_source_active(DocumentViewer.PAUSE_SOURCE)


func _sync_settings_ui() -> void:
	sensitivity_slider.set_value_no_signal(Settings.look_sensitivity)
	sensitivity_value.text = "%.2fx" % Settings.look_sensitivity
	invert_check.set_pressed_no_signal(Settings.invert_y)
	touch_check.set_pressed_no_signal(VirtualInput.is_touch_ui_enabled())
	if VirtualInput.is_mobile_platform():
		controls_hint.text = "Left thumb: move  |  Right thumb: look  |  USE: interact  |  LIGHT: torch"
	else:
		controls_hint.text = "WASD: move  |  Mouse: look  |  E / click: interact  |  F: torch  |  Shift: hurry  |  Esc: pause"


func _on_sensitivity_changed(value: float) -> void:
	Settings.set_look_sensitivity(value)
	sensitivity_value.text = "%.2fx" % Settings.look_sensitivity


func _on_invert_toggled(pressed: bool) -> void:
	Settings.set_invert_y(pressed)


func _on_touch_toggled(pressed: bool) -> void:
	if VirtualInput.is_mobile_platform():
		Settings.set_touch_mode(Settings.TouchMode.AUTO if pressed else Settings.TouchMode.NEVER)
	else:
		Settings.set_touch_mode(Settings.TouchMode.ALWAYS if pressed else Settings.TouchMode.AUTO)
		Input.emulate_touch_from_mouse = pressed


func _on_restart() -> void:
	AudioManager.play(&"ui_click")
	Settings.save_settings()
	GameState.restart_level()


func _on_title() -> void:
	AudioManager.play(&"ui_click")
	Settings.save_settings()
	GameState.go_to_title()
