class_name FlickerLight
extends OmniLight3D
## Station light with simple behaviour modes, driven by story events.
##
## OFF / STEADY / FLICKER / EMERGENCY. A child "Fixture" MeshInstance3D (optional)
## glows in sync with the light. Lights at zero energy are hidden so they cost
## nothing on low-end GPUs. Shadows are intentionally left off.

enum Mode { OFF, STEADY, FLICKER, EMERGENCY }

@export var mode: Mode = Mode.STEADY
@export var base_energy: float = 1.0
## 0 = rock steady, 1 = wildly unstable (FLICKER mode).
@export_range(0.0, 1.0) var flicker_amount: float = 0.3
@export var flicker_speed: float = 9.0
@export_group("Emergency power")
@export var emergency_color: Color = Color(1.0, 0.38, 0.2)
@export var emergency_energy: float = 1.1
@export_range(0.0, 1.0) var emergency_flicker: float = 0.06

var _time: float = 0.0
var _dropout: float = 0.0
var _fixture_material: StandardMaterial3D
var _boost: float = 1.0

@onready var fixture: MeshInstance3D = get_node_or_null(^"Fixture")


func _ready() -> void:
	_time = randf() * 100.0
	shadow_enabled = false
	if fixture != null:
		_fixture_material = StandardMaterial3D.new()
		_fixture_material.albedo_color = light_color.darkened(0.6)
		_fixture_material.emission_enabled = true
		_fixture_material.emission = light_color
		fixture.material_override = _fixture_material
	_update(0.0)


func _process(delta: float) -> void:
	_update(delta)


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if mode == Mode.EMERGENCY:
		light_color = emergency_color
		if _fixture_material != null:
			_fixture_material.emission = emergency_color
	_update(0.0)


## Temporarily multiplies brightness (used for surges / lightning-like pulses).
func surge(multiplier: float, duration: float) -> void:
	_boost = multiplier
	var tween := create_tween()
	tween.tween_property(self, "_boost", 1.0, duration)


func _update(delta: float) -> void:
	_time += delta
	var energy := 0.0
	match mode:
		Mode.STEADY:
			energy = base_energy
		Mode.FLICKER:
			energy = base_energy * _flicker_factor(flicker_amount, delta)
		Mode.EMERGENCY:
			energy = emergency_energy * (1.0 - emergency_flicker * (0.5 + 0.5 * sin(_time * 23.0)))
	energy *= _boost
	light_energy = energy
	visible = energy > 0.01
	if _fixture_material != null:
		_fixture_material.emission_energy_multiplier = energy * 2.0


## Mostly-on fluorescent-tube style flicker with occasional sharp dropouts.
func _flicker_factor(amount: float, delta: float) -> float:
	var wave := sin(_time * flicker_speed) * 0.5 + sin(_time * flicker_speed * 2.3 + 1.7) * 0.3 + sin(_time * 0.7) * 0.2
	var value := 1.0 - amount * (0.5 + 0.5 * wave) * 0.6
	if _dropout > 0.0:
		_dropout -= delta
		return 0.04
	if randf() < amount * 0.015:
		_dropout = randf_range(0.04, 0.18)
	return clampf(value, 0.0, 1.0)
