class_name RailwaySignal
extends Node3D
## Three-aspect colour-light signal (green top, yellow middle, red bottom).
## The title's "last signal" - it turns green at the end of the prototype.

const ASPECT_COLORS := {
	&"red": Color(1.0, 0.1, 0.06),
	&"yellow": Color(1.0, 0.72, 0.08),
	&"green": Color(0.12, 1.0, 0.35),
}

@export var aspect: StringName = &"red"

var _materials: Dictionary = {}

@onready var glow: OmniLight3D = $Glow


func _ready() -> void:
	for id: StringName in ASPECT_COLORS.keys():
		var lamp := get_node_or_null(NodePath("Head/Lamp_%s" % id)) as MeshInstance3D
		if lamp == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		lamp.material_override = mat
		_materials[id] = mat
	set_aspect(aspect)


func set_aspect(new_aspect: StringName) -> void:
	aspect = new_aspect
	for id: StringName in _materials.keys():
		var mat: StandardMaterial3D = _materials[id]
		var color: Color = ASPECT_COLORS[id]
		var lit: bool = id == aspect
		mat.albedo_color = color if lit else color * 0.15
		mat.emission = color
		mat.emission_energy_multiplier = 4.0 if lit else 0.0
	if ASPECT_COLORS.has(aspect):
		glow.visible = true
		glow.light_color = ASPECT_COLORS[aspect]
	else:
		glow.visible = false
