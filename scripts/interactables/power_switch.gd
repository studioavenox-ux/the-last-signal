class_name PowerSwitch
extends Node3D
## One emergency breaker: a lever with a colour-coded lamp and a text label.
##
## Emits [signal switched] when the player throws it. The breaker only goes ON
## from player input; puzzles reset it with [method reset_off].

signal switched(switch_id: StringName, is_on: bool)

const LEVER_OFF := 0.7
const LEVER_ON := -0.7

@export var switch_id: StringName = &"red"
## Written under the breaker (keep it readable for colour-blind players).
@export var label_text: String = "RED"
@export var lamp_color: Color = Color(1.0, 0.15, 0.1)
@export var is_on: bool = false

var locked: bool = false
var _lamp_material: StandardMaterial3D
var _tween: Tween

@onready var interactable: Interactable = $Interactable
@onready var lever_pivot: Node3D = $LeverPivot
@onready var lamp: MeshInstance3D = $Lamp
@onready var label: Label3D = $Label


func _ready() -> void:
	label.text = label_text
	label.modulate = lamp_color.lerp(Color.WHITE, 0.45)
	if lamp.material_override is StandardMaterial3D:
		_lamp_material = (lamp.material_override as StandardMaterial3D).duplicate()
	else:
		_lamp_material = StandardMaterial3D.new()
		_lamp_material.emission_enabled = true
	lamp.material_override = _lamp_material
	interactable.interacted.connect(_on_interacted)
	_apply_state(false)


func _on_interacted(_interactor: Node) -> void:
	if locked:
		return
	if is_on:
		GameState.say("The %s breaker is already on." % label_text)
		return
	is_on = true
	_apply_state(true)
	AudioManager.play_at(&"switch_on", global_position)
	switched.emit(switch_id, true)


## Snaps the breaker back to OFF (no event emitted).
func reset_off(animate: bool = true) -> void:
	is_on = false
	_apply_state(animate)


func set_locked(value: bool) -> void:
	locked = value
	interactable.enabled = not value
	_update_prompt()


## Quick red flicker used when the panel trips.
func flash_fault() -> void:
	var tween := create_tween()
	for i in 3:
		tween.tween_callback(_set_lamp.bind(Color(1.0, 0.1, 0.05), 4.0))
		tween.tween_interval(0.07)
		tween.tween_callback(_set_lamp.bind(lamp_color, 0.0))
		tween.tween_interval(0.07)


func _apply_state(animate: bool) -> void:
	var angle := LEVER_ON if is_on else LEVER_OFF
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(lever_pivot, "rotation:x", angle, 0.22)
	else:
		lever_pivot.rotation.x = angle
	_set_lamp(lamp_color, 3.0 if is_on else 0.0)
	_update_prompt()


func _set_lamp(color: Color, energy: float) -> void:
	_lamp_material.albedo_color = color * (1.0 if energy > 0.0 else 0.25)
	_lamp_material.emission_enabled = true
	_lamp_material.emission = color
	_lamp_material.emission_energy_multiplier = maxf(energy, 0.05)


func _update_prompt() -> void:
	if is_on:
		interactable.prompt_text = "%s breaker (ON)" % label_text
	else:
		interactable.prompt_text = "Pull the %s breaker" % label_text
