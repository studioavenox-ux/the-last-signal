extends Control
## Title screen: start the game, read the controls, quit.
## Also pre-generates procedural audio in the background (one sound per frame).

const HOW_TO_PLAY := """PHONE / TABLET
  Left thumb - drag to walk
  Right thumb - drag to look around
  USE - doors, notes, switches, objects
  LIGHT - phone torch on / off
  II - pause

KEYBOARD & MOUSE
  WASD / arrows - walk      Shift - hurry
  Mouse - look      E or left click - interact
  F - torch      Esc / P - pause      F3 - test touch controls

GAMEPAD
  Left stick - walk      Right stick - look
  A - interact      Y - torch      Start - pause"""

var _starting: bool = false

@onready var begin_button: Button = %BeginButton
@onready var how_button: Button = %HowButton
@onready var quit_button: Button = %QuitButton
@onready var how_panel: Control = %HowPanel
@onready var how_text: Label = %HowText
@onready var how_back_button: Button = %HowBackButton
@onready var version_label: Label = %VersionLabel
@onready var credits_button: Button = %CreditsButton
@onready var credits_panel: Control = %CreditsPanel
@onready var credits_text: RichTextLabel = %CreditsText
@onready var credits_back_button: Button = %CreditsBackButton


func _ready() -> void:
	GameState.reset_state()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_ambience(&"hum", 0.5)
	AudioManager.start_ambience(&"rain", -9.0, 2.0)
	AudioManager.prewarm_all()
	begin_button.pressed.connect(_on_begin_pressed)
	how_button.pressed.connect(_on_how_pressed)
	how_back_button.pressed.connect(_on_how_back_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	credits_back_button.pressed.connect(_on_credits_back_pressed)
	credits_panel.visible = false
	quit_button.visible = not OS.has_feature("web")
	how_text.text = HOW_TO_PLAY
	how_panel.visible = false
	version_label.text = (
		"AVENOX Games  |  Prototype v%s  |  Made with Godot Engine"
		% str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	)
	begin_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if how_panel.visible:
			_on_how_back_pressed()
		elif credits_panel.visible:
			_on_credits_back_pressed()
		else:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		return
	if how_panel.visible:
		get_viewport().set_input_as_handled()
		_on_how_back_pressed()
	elif credits_panel.visible:
		get_viewport().set_input_as_handled()
		_on_credits_back_pressed()


func _on_begin_pressed() -> void:
	if _starting:
		return
	_starting = true
	AudioManager.play(&"ui_click")
	begin_button.disabled = true
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, 0.8)
	await tween.finished
	GameState.start_new_game()


func _on_how_pressed() -> void:
	AudioManager.play(&"ui_click")
	how_panel.visible = true
	how_back_button.grab_focus()


func _on_how_back_pressed() -> void:
	AudioManager.play(&"ui_click")
	how_panel.visible = false
	how_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_credits_pressed() -> void:
	AudioManager.play(&"ui_click")
	if credits_text.text.is_empty():
		credits_text.text = build_credits_text()
	credits_panel.visible = true
	credits_back_button.grab_focus()


func _on_credits_back_pressed() -> void:
	AudioManager.play(&"ui_click")
	credits_panel.visible = false
	credits_button.grab_focus()


## Credits plus the engine's own license notices, generated from the running engine
## so they always match the Godot version the game was exported with.
static func build_credits_text() -> String:
	var lines: PackedStringArray = []
	lines.append(
		"[b]THE LAST SIGNAL[/b] - prototype v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	)
	lines.append("A game in development by AVENOX Games.")
	lines.append("")
	lines.append("Story, design, code, level geometry, textures and sound effects are original work")
	lines.append("created for this project (geometry, textures and audio are generated procedurally).")
	lines.append("No third-party art, music, fonts or sound assets are included.")
	lines.append("")
	lines.append("[b]Built with Godot Engine[/b] - https://godotengine.org")
	lines.append(Engine.get_license_text().strip_edges().replace("[", "[lb]"))
	lines.append("")
	lines.append("[b]Third-party components included in Godot Engine[/b]")
	for component: Dictionary in Engine.get_copyright_info():
		var licenses: PackedStringArray = []
		for part: Dictionary in component.get("parts", []):
			var license_name := str(part.get("license", ""))
			if not license_name.is_empty() and not licenses.has(license_name):
				licenses.append(license_name)
		lines.append("- %s (%s)" % [str(component.get("name", "")), ", ".join(licenses)])
	lines.append("")
	lines.append("[b]License texts[/b]")
	var license_info := Engine.get_license_info()
	for license_name: String in license_info.keys():
		lines.append("")
		lines.append("[b]%s[/b]" % license_name)
		lines.append(str(license_info[license_name]).strip_edges().replace("[", "[lb]"))
	return "\n".join(lines)
