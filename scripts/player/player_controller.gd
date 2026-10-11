class_name PlayerController
extends CharacterBody3D
## First-person controller for Aarav: walking, looking, footsteps, phone torch.
##
## Tuned for a slow, tense pace and for touch screens (no jumping, gentle
## acceleration, analog joystick speed). Input comes from [PlayerInput].

signal footstep

@export_group("Movement")
@export var walk_speed: float = 2.5
@export var sprint_speed: float = 4.0
@export var acceleration: float = 12.0
@export var deceleration: float = 14.0
@export_group("Camera")
@export var max_pitch_degrees: float = 85.0
@export var head_bob_height: float = 0.025
@export_group("Audio")
@export var step_distance: float = 1.55
@export var footstep_volume_db: float = -12.0

var movement_enabled: bool = true
var look_enabled: bool = true
var interaction_enabled: bool = true

var _pitch: float = 0.0
var _step_accumulator: float = 0.0
var _bob_phase: float = 0.0
var _head_base_y: float = 0.0
var _gravity: float = 9.8
var _shake_strength: float = 0.0
var _shake_time: float = 0.0
var _shake_total: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interactor: PlayerInteractor = $Head/Camera3D/Interactor
@onready var input: PlayerInput = $PlayerInput


func _ready() -> void:
	add_to_group(&"player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_head_base_y = head.position.y
	input.interact_requested.connect(_on_interact_requested)
	input.flashlight_toggle_requested.connect(toggle_flashlight)
	flashlight.visible = Settings.flashlight_on_start


func _process(delta: float) -> void:
	var look := input.consume_look(delta)
	if look_enabled:
		rotate_y(-look.x)
		var limit := deg_to_rad(max_pitch_degrees)
		_pitch = clampf(_pitch + look.y, -limit, limit)
		head.rotation.x = _pitch
	_update_shake(delta)


func _physics_process(delta: float) -> void:
	var move := input.get_move_vector() if movement_enabled else Vector2.ZERO
	# Rotation is yaw-only, so this keeps the analog magnitude of the stick.
	var wish := global_transform.basis * Vector3(move.x, 0.0, move.y)
	wish.y = 0.0
	var speed := sprint_speed if input.is_sprinting() else walk_speed
	var target := wish * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if move.length_squared() > 0.0001 else deceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	_update_steps_and_bob(delta)


# --- Public API ----------------------------------------------------------------


func set_controls_enabled(value: bool) -> void:
	movement_enabled = value
	look_enabled = value
	interaction_enabled = value
	input.enabled = value
	if not value:
		velocity = Vector3.ZERO


func toggle_flashlight() -> void:
	flashlight.visible = not flashlight.visible
	AudioManager.play(&"ui_click", -10.0, 1.7)


## Instantly moves the player (spawns, tests, scripted moments).
func teleport(world_position: Vector3, yaw_radians: float, pitch_radians: float = 0.0) -> void:
	global_position = world_position
	rotation = Vector3(0.0, yaw_radians, 0.0)
	_pitch = pitch_radians
	head.rotation.x = _pitch
	velocity = Vector3.ZERO


## Turns the view to look at a world point.
func face_point(target: Vector3) -> void:
	var dir := target - camera.global_position
	rotation.y = atan2(-dir.x, -dir.z)
	var limit := deg_to_rad(max_pitch_degrees)
	_pitch = clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -limit, limit)
	head.rotation.x = _pitch


func get_look_direction() -> Vector3:
	return -camera.global_transform.basis.z


func set_pitch(value: float) -> void:
	var limit := deg_to_rad(max_pitch_degrees)
	_pitch = clampf(value, -limit, limit)
	head.rotation.x = _pitch


func get_pitch() -> float:
	return _pitch


func shake(strength: float = 0.05, duration: float = 0.4) -> void:
	_shake_strength = strength
	_shake_time = duration
	_shake_total = maxf(duration, 0.001)


# --- Internals -----------------------------------------------------------------


func _on_interact_requested() -> void:
	if interaction_enabled:
		interactor.try_interact(self)


func _update_steps_and_bob(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed > 0.3:
		_step_accumulator += speed * delta
		_bob_phase += speed * delta * PI / step_distance
		if _step_accumulator >= step_distance:
			_step_accumulator -= step_distance
			AudioManager.play(&"footstep", footstep_volume_db)
			footstep.emit()
	var bob_weight := clampf(speed / walk_speed, 0.0, 1.0)
	head.position.y = _head_base_y + sin(_bob_phase * 2.0) * head_bob_height * bob_weight


func _update_shake(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		var k := clampf(_shake_time / _shake_total, 0.0, 1.0)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake_strength * k
		camera.v_offset = randf_range(-1.0, 1.0) * _shake_strength * k
	elif camera.h_offset != 0.0 or camera.v_offset != 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
