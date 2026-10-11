extends Node
## Persistent player preferences (look sensitivity, invert Y, touch UI mode).
##
## Stored in user://settings.cfg so they survive restarts on desktop and Android.

signal changed

enum TouchMode { AUTO, ALWAYS, NEVER }

const SAVE_PATH := "user://settings.cfg"

## Multiplier applied to every look source (mouse, touch, gamepad).
var look_sensitivity: float = 1.0
var invert_y: bool = false
## AUTO shows touch controls on Android/iOS (or touch-capable web) only.
var touch_mode: TouchMode = TouchMode.AUTO
## Phone torch starts switched on because the station is dark.
var flashlight_on_start: bool = true


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	look_sensitivity = clampf(float(cfg.get_value("controls", "look_sensitivity", 1.0)), 0.2, 3.0)
	invert_y = bool(cfg.get_value("controls", "invert_y", false))
	touch_mode = clampi(int(cfg.get_value("controls", "touch_mode", TouchMode.AUTO)), 0, 2) as TouchMode
	changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "look_sensitivity", look_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("controls", "touch_mode", int(touch_mode))
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Settings: could not save %s (error %d)" % [SAVE_PATH, err])


func set_look_sensitivity(value: float) -> void:
	look_sensitivity = clampf(value, 0.2, 3.0)
	changed.emit()


func set_invert_y(value: bool) -> void:
	invert_y = value
	changed.emit()


func set_touch_mode(value: TouchMode) -> void:
	touch_mode = value
	changed.emit()
