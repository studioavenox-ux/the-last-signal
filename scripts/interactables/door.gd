class_name Door
extends Node3D
## Hinged door or gate driven by an [Interactable] child.
##
## Expected children: "Hinge" (Node3D, rotates around Y) holding the panel body,
## optional "HingeB" for double doors (rotates the opposite way), optional
## "LockLamp" (MeshInstance3D) showing red when locked / green when unlocked, and
## "Interactable". Panels open away from whoever opens them.

signal opened
signal closed
signal unlocked
signal locked_attempted

@export var door_id: StringName = &""
@export var display_name: String = "door"
@export var locked: bool = false
@export var start_open: bool = false
@export var open_angle_degrees: float = 100.0
@export var open_time: float = 0.9
## Shown when the player tries a locked door (ignored if locked_lines_id is set).
@export_multiline var locked_message: String = "It's locked."
## Optional StoryText lines id spoken instead of locked_message.
@export var locked_lines_id: StringName = &""

var is_open: bool = false
var _tween: Tween
var _lamp_material: StandardMaterial3D

@onready var interactable: Interactable = $Interactable
@onready var hinge: Node3D = $Hinge
@onready var hinge_b: Node3D = get_node_or_null(^"HingeB")
@onready var lock_lamp: MeshInstance3D = get_node_or_null(^"LockLamp")


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	# Let the player's ray target the panel bodies as well as the trigger area.
	for node in find_children("*", "CollisionObject3D", true, false):
		if node != interactable:
			node.set_meta(PlayerInteractor.META_KEY, interactable)
	if lock_lamp != null and lock_lamp.material_override is StandardMaterial3D:
		_lamp_material = (lock_lamp.material_override as StandardMaterial3D).duplicate()
		lock_lamp.material_override = _lamp_material
	if start_open:
		is_open = true
		_set_angle(deg_to_rad(open_angle_degrees))
	_refresh()


func open(opener: Node = null) -> void:
	if is_open:
		return
	is_open = true
	var side := 1.0
	if opener is Node3D:
		side = 1.0 if to_local((opener as Node3D).global_position).z >= 0.0 else -1.0
	_animate(deg_to_rad(open_angle_degrees) * side, open_time)
	AudioManager.play_at(&"door_open", _sound_position())
	opened.emit()
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_animate(0.0, open_time * 0.8)
	AudioManager.play_at(&"door_close", _sound_position())
	closed.emit()
	_refresh()


## Slams the door shut and locks it (used by the intro).
func slam_and_lock() -> void:
	is_open = false
	locked = true
	_animate(0.0, 0.15)
	AudioManager.play(&"door_slam", 0.0)
	_refresh()


func unlock(play_sound: bool = true) -> void:
	if not locked:
		return
	locked = false
	if play_sound:
		AudioManager.play_at(&"switch_on", _sound_position(), 2.0)
	unlocked.emit()
	_refresh()


func lock() -> void:
	locked = true
	_refresh()


func _on_interacted(interactor: Node) -> void:
	if locked:
		AudioManager.play_at(&"door_locked", _sound_position())
		if locked_lines_id != &"":
			StoryText.say_lines(locked_lines_id)
		elif not locked_message.is_empty():
			GameState.say(locked_message)
		locked_attempted.emit()
		return
	if is_open:
		close()
	else:
		open(interactor)


func _refresh() -> void:
	if locked:
		interactable.prompt_text = "Try the %s" % display_name
	elif is_open:
		interactable.prompt_text = "Close the %s" % display_name
	else:
		interactable.prompt_text = "Open the %s" % display_name
	if _lamp_material != null:
		var c := Color(1.0, 0.12, 0.08) if locked else Color(0.15, 1.0, 0.35)
		_lamp_material.albedo_color = c
		_lamp_material.emission = c


func _animate(angle: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(hinge, "rotation:y", angle, duration)
	if hinge_b != null:
		_tween.parallel().tween_property(hinge_b, "rotation:y", -angle, duration)


func _set_angle(angle: float) -> void:
	hinge.rotation.y = angle
	if hinge_b != null:
		hinge_b.rotation.y = -angle


func _sound_position() -> Vector3:
	return global_position + Vector3.UP * 1.2
