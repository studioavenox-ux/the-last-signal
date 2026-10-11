class_name StationLevel
extends Node3D
## Raatpur Junction - level director for the prototype.
##
## Composition root: wires the player, HUD and world objects together and runs
## the story beats. Individual objects stay generic and reusable; everything
## specific to this level's story lives here (and in StoryText for the words).
##
## Flow: intro (doors slam) -> waiting hall announcement -> locked Platform 3 gate
## -> breaker puzzle in the Electrical Room -> PowerRestoredEvent -> apparition on
## the platform -> Kabir's phone -> EndingSequence -> end screen.

const WAITING_HALL_MIN := Vector2(-6.8, -17.8)
const WAITING_HALL_MAX := Vector2(6.8, -8.2)

## Skip the intro (handy when iterating on later beats).
@export var skip_intro: bool = false

var _apparition_done: bool = false
var _lightning_timer: float = 12.0

@onready var player: PlayerController = $Player
@onready var hud: Hud = $HUD
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var lightning: DirectionalLight3D = $LightningLight
@onready var entrance_doors: Door = $Interactables/EntranceDoors
@onready var platform_gate: Door = $Interactables/PlatformGate
@onready var breaker_panel: SwitchPuzzle = $Interactables/BreakerPanel
@onready var kabir_phone: StoryObject = $Interactables/KabirPhone
@onready var apparition: Apparition = $Interactables/Apparition
@onready var power_event: PowerRestoredEvent = $Events/PowerRestoredEvent
@onready var ending: EndingSequence = $Events/EndingSequence
@onready var triggers: Node3D = $Triggers


func _ready() -> void:
	GameState.reset_state()
	GameState.is_playing = true
	player.interactor.prompt_changed.connect(GameState.set_prompt)
	platform_gate.locked_attempted.connect(_on_gate_locked_attempted)
	platform_gate.opened.connect(func() -> void: GameState.set_flag(&"gate_opened"))
	breaker_panel.solved.connect(_on_breaker_panel_solved)
	kabir_phone.examined.connect(_on_phone_examined)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.pause_state_changed.connect(func(_paused: bool) -> void: _update_mouse_mode())
	GameState.game_ended.connect(_update_mouse_mode)
	VirtualInput.touch_ui_visibility_changed.connect(func(_visible: bool) -> void: _update_mouse_mode())
	for trigger in triggers.get_children():
		if trigger is StoryTrigger:
			(trigger as StoryTrigger).triggered.connect(_on_story_trigger)
	AudioManager.start_ambience(&"rain", -5.0, 3.0)
	_update_mouse_mode()
	if skip_intro:
		hud.fade_from_black(0.3)
		GameState.set_objective(StoryText.get_objective(&"find_platform"))
	else:
		_run_intro()


func _process(delta: float) -> void:
	_update_lightning(delta)
	_check_apparition()


func _unhandled_input(event: InputEvent) -> void:
	# Desktop: click back into the game to re-capture the mouse.
	if (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
		and _wants_captured_mouse()
	):
		_update_mouse_mode()


# --- Story beats ---------------------------------------------------------------


func _run_intro() -> void:
	player.movement_enabled = false
	hud.fade_from_black(2.5)
	GameState.notify('NEW MESSAGE - KABIR:  "Platform Three. Midnight."', 4.5)
	StoryText.say_lines(&"intro")
	await Sequence.wait(self, 2.4)
	entrance_doors.slam_and_lock()
	AudioManager.play(&"thunder", -6.0)
	flash_lightning()
	player.shake(0.06, 0.5)
	StoryText.say_lines(&"door_slam")
	await Sequence.wait(self, 0.8)
	player.movement_enabled = true
	GameState.set_objective(StoryText.get_objective(&"find_platform"))


func _on_story_trigger(trigger_id: StringName) -> void:
	match trigger_id:
		&"enter_waiting":
			GameState.set_flag(&"heard_name")
			AudioManager.play_announcement(&"announce_name")
			StoryText.say_lines(&"announce_name")
		&"enter_electrical":
			if not GameState.has_flag(&"power_restored"):
				GameState.set_objective(StoryText.get_objective(&"breakers"))
				StoryText.say_lines(&"enter_electrical")
		&"enter_platform":
			GameState.set_flag(&"on_platform")
			GameState.set_objective(StoryText.get_objective(&"find_kabir"))
			StoryText.say_lines(&"reach_platform")
			AudioManager.start_ambience(&"rain", 0.0, 2.0)


func _on_gate_locked_attempted() -> void:
	if not GameState.has_flag(&"knows_power_needed"):
		GameState.set_flag(&"knows_power_needed")
		_advance_objective_to(&"restore_power")


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag == &"read_station_notice" or flag == &"read_kabir_note":
		_advance_objective_to(&"restore_power")


## Moves the objective forward only if the player hasn't progressed past it yet.
func _advance_objective_to(id: StringName) -> void:
	if GameState.has_flag(&"power_restored"):
		return
	if GameState.objective == StoryText.get_objective(&"find_platform"):
		GameState.set_objective(StoryText.get_objective(id))


func _on_breaker_panel_solved() -> void:
	power_event.play()


func _check_apparition() -> void:
	if _apparition_done or not power_event.has_finished or GameState.has_flag(&"gate_opened"):
		return
	var pos := player.global_position
	if (
		pos.x < WAITING_HALL_MIN.x
		or pos.x > WAITING_HALL_MAX.x
		or pos.z < WAITING_HALL_MIN.y
		or pos.z > WAITING_HALL_MAX.y
	):
		return
	var to_spot := apparition.global_position + Vector3.UP * 1.1 - player.camera.global_position
	if to_spot.length() > 15.0:
		return
	if player.get_look_direction().angle_to(to_spot.normalized()) < deg_to_rad(20.0):
		_apparition_done = true
		_play_apparition()


func _play_apparition() -> void:
	GameState.set_flag(&"saw_apparition")
	AudioManager.play(&"stinger", 0.0)
	apparition.appear(1.3)
	for light in power_event.get_station_lights():
		light.surge(0.05, 1.3)
	await Sequence.wait(self, 0.6)
	StoryText.say_lines(&"apparition")


func _on_phone_examined(_object_id: StringName) -> void:
	ending.play(player)


# --- Atmosphere ----------------------------------------------------------------


func flash_lightning() -> void:
	# The light is hidden between flashes so it costs nothing while idle.
	lightning.light_energy = 0.0
	lightning.visible = true
	var tween := create_tween()
	tween.tween_property(lightning, "light_energy", 1.6, 0.05)
	tween.tween_property(lightning, "light_energy", 0.2, 0.08)
	tween.tween_property(lightning, "light_energy", 1.2, 0.05)
	tween.tween_property(lightning, "light_energy", 0.0, 0.35)
	tween.tween_callback(lightning.hide)


func _update_lightning(delta: float) -> void:
	_lightning_timer -= delta
	if _lightning_timer > 0.0:
		return
	_lightning_timer = randf_range(16.0, 38.0)
	flash_lightning()
	# Node-bound tween: dies with the level, so it can never fire after a restart.
	var tween := create_tween()
	tween.tween_interval(randf_range(0.4, 1.6))
	tween.tween_callback(AudioManager.play.bind(&"thunder", randf_range(-12.0, -6.0)))


# --- Mouse capture (desktop) -----------------------------------------------------


func _wants_captured_mouse() -> bool:
	return (
		GameState.is_playing
		and not get_tree().paused
		and not VirtualInput.is_touch_ui_enabled()
		and not DisplayServer.get_name().begins_with("headless")
	)


func _update_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _wants_captured_mouse() else Input.MOUSE_MODE_VISIBLE
