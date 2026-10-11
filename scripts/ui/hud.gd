class_name Hud
extends CanvasLayer
## In-game HUD: objective, interaction prompt, crosshair, subtitles, notifications,
## screen flashes, fades and the end-of-prototype screen.
##
## Listens to the GameState event bus, so gameplay code never references the HUD.
## Sizes are tuned for phones (720p canvas, large text) and respect notches via
## the display safe area.

const SPEAKER_COLORS := {
	"Aarav": "#ffb27a",
	"Announcement": "#ffd36b",
}
const NARRATION_COLOR := "#c9d4e6"

var _subtitle_queue: Array[Dictionary] = []
var _subtitle_time_left: float = 0.0
var _notification_tween: Tween
var _flash_tween: Tween
var _fade_tween: Tween
var _prompt_text: String = ""

@onready var safe_area: MarginContainer = %SafeArea
@onready var objective_panel: PanelContainer = %ObjectivePanel
@onready var objective_label: Label = %ObjectiveLabel
@onready var notification_label: Label = %NotificationLabel
@onready var subtitle_panel: PanelContainer = %SubtitlePanel
@onready var subtitle_label: RichTextLabel = %SubtitleLabel
@onready var prompt_panel: PanelContainer = %PromptPanel
@onready var prompt_label: Label = %PromptLabel
@onready var crosshair: Panel = %Crosshair
@onready var flash_rect: ColorRect = %Flash
@onready var fade_rect: ColorRect = %Fade
@onready var end_screen: Control = %EndScreen
@onready var end_title: Label = %EndTitle
@onready var end_body: Label = %EndBody
@onready var restart_button: Button = %RestartButton
@onready var title_button: Button = %TitleButton


func _ready() -> void:
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.subtitle_requested.connect(_on_subtitle_requested)
	GameState.notification_requested.connect(_on_notification_requested)
	GameState.prompt_changed.connect(_on_prompt_changed)
	GameState.screen_flash_requested.connect(flash)
	GameState.game_ended.connect(_on_game_ended)
	VirtualInput.touch_ui_visibility_changed.connect(func(_visible: bool) -> void: _refresh_layout())
	get_viewport().size_changed.connect(_refresh_layout)
	restart_button.pressed.connect(_on_restart_pressed)
	title_button.pressed.connect(_on_title_pressed)
	objective_panel.visible = false
	subtitle_panel.visible = false
	notification_label.visible = false
	prompt_panel.visible = false
	end_screen.visible = false
	flash_rect.color.a = 0.0
	_refresh_layout()
	_on_objective_changed(GameState.objective)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _subtitle_time_left > 0.0:
		_subtitle_time_left -= delta
		if _subtitle_time_left <= 0.0:
			_show_next_subtitle()


# --- Public API ----------------------------------------------------------------


func fade_from_black(duration: float = 1.5) -> Signal:
	return _fade_to(0.0, duration)


func fade_to_black(duration: float = 1.5) -> Signal:
	return _fade_to(1.0, duration)


func flash(color: Color, duration: float = 0.35) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	flash_rect.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, duration)


func get_current_subtitle_text() -> String:
	return subtitle_label.get_parsed_text() if subtitle_panel.visible else ""


func get_prompt_text() -> String:
	return _prompt_text


# --- Signal handlers -----------------------------------------------------------


func _on_objective_changed(text: String) -> void:
	objective_label.text = text
	objective_panel.visible = not text.is_empty()
	if text.is_empty():
		return
	objective_panel.modulate = Color(1.6, 1.3, 1.2)
	create_tween().tween_property(objective_panel, "modulate", Color.WHITE, 1.2)
	AudioManager.play(&"ui_click", -8.0, 0.7)


func _on_subtitle_requested(text: String, speaker: String, duration: float) -> void:
	_subtitle_queue.append({"text": text, "speaker": speaker, "duration": duration})
	if _subtitle_time_left <= 0.0:
		_show_next_subtitle()


func _on_notification_requested(text: String, duration: float) -> void:
	notification_label.text = text
	notification_label.visible = true
	notification_label.modulate.a = 0.0
	if _notification_tween != null and _notification_tween.is_valid():
		_notification_tween.kill()
	_notification_tween = create_tween()
	_notification_tween.tween_property(notification_label, "modulate:a", 1.0, 0.3)
	_notification_tween.tween_interval(duration)
	_notification_tween.tween_property(notification_label, "modulate:a", 0.0, 0.6)
	_notification_tween.tween_callback(notification_label.hide)


func _on_prompt_changed(text: String) -> void:
	_prompt_text = text
	prompt_panel.visible = not text.is_empty()
	if text.is_empty():
		crosshair.modulate = Color(1, 1, 1, 0.55)
		crosshair.scale = Vector2.ONE
		return
	if VirtualInput.is_touch_ui_enabled():
		prompt_label.text = text
	else:
		prompt_label.text = "[E]  %s" % text
	crosshair.modulate = Color(1.0, 0.55, 0.4, 1.0)
	crosshair.scale = Vector2(1.6, 1.6)


func _on_game_ended() -> void:
	_subtitle_queue.clear()
	_subtitle_time_left = 0.0
	subtitle_panel.visible = false
	prompt_panel.visible = false
	crosshair.visible = false
	objective_panel.visible = false
	await fade_to_black(2.5)
	end_title.text = StoryText.END_TITLE
	end_body.text = StoryText.END_BODY
	end_screen.visible = true
	end_screen.modulate.a = 0.0
	create_tween().tween_property(end_screen, "modulate:a", 1.0, 1.0)
	restart_button.grab_focus()


func _on_restart_pressed() -> void:
	AudioManager.play(&"ui_click")
	GameState.restart_level()


func _on_title_pressed() -> void:
	AudioManager.play(&"ui_click")
	GameState.go_to_title()


# --- Internals -----------------------------------------------------------------


func _show_next_subtitle() -> void:
	if _subtitle_queue.is_empty():
		subtitle_panel.visible = false
		_subtitle_time_left = 0.0
		return
	var entry: Dictionary = _subtitle_queue.pop_front()
	var speaker: String = entry["speaker"]
	var text: String = entry["text"]
	if speaker.is_empty():
		subtitle_label.text = "[color=%s]%s[/color]" % [NARRATION_COLOR, _escape(text)]
	else:
		var color: String = SPEAKER_COLORS.get(speaker, "#ffffff")
		subtitle_label.text = "[color=%s]%s:[/color] %s" % [color, speaker, _escape(text)]
	subtitle_panel.visible = true
	_subtitle_time_left = float(entry["duration"])


func _fade_to(alpha: float, duration: float) -> Signal:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	fade_rect.visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", alpha, maxf(duration, 0.01))
	if alpha <= 0.0:
		_fade_tween.tween_callback(fade_rect.hide)
	return _fade_tween.finished


## Keeps HUD elements inside the display safe area (notches, rounded corners)
## and narrows subtitles when touch controls occupy the bottom corners.
func _refresh_layout() -> void:
	var margins := UiUtil.safe_area_margins(get_viewport())
	safe_area.add_theme_constant_override("margin_left", int(24 + margins.x))
	safe_area.add_theme_constant_override("margin_top", int(16 + margins.y))
	safe_area.add_theme_constant_override("margin_right", int(24 + margins.z))
	safe_area.add_theme_constant_override("margin_bottom", int(16 + margins.w))
	var touch := VirtualInput.is_touch_ui_enabled()
	subtitle_label.custom_minimum_size.x = 700.0 if touch else 900.0


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
