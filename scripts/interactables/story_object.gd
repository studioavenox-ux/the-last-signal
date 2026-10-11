class_name StoryObject
extends Node3D
## An examinable object that advances the story.
##
## Shows lines from [StoryText] (EXAMINE or LINES, by [member lines_id]) and emits
## [signal examined] so level scripts can trigger bigger moments (e.g. the ending).
## An optional glowing mesh / light pulses to draw the player's eye.

signal examined(object_id: StringName)

@export var object_id: StringName = &""
@export var prompt_text: String = "Examine"
@export var lines_id: StringName = &""
@export var one_shot: bool = false
@export_group("Attention glow")
@export var glow_mesh_path: NodePath
@export var glow_light_path: NodePath
@export var glow_color: Color = Color(0.55, 0.75, 1.0)
@export var glow_energy: float = 1.5
@export var pulse_speed: float = 2.2

var times_examined: int = 0
var _glow_material: StandardMaterial3D
var _glow_light: Light3D
var _glow_base_light_energy: float = 0.0
var _time: float = 0.0

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.prompt_text = prompt_text
	interactable.one_shot = one_shot
	interactable.interacted.connect(_on_interacted)
	var glow_mesh := get_node_or_null(glow_mesh_path) as MeshInstance3D
	if glow_mesh != null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.albedo_color = glow_color * 0.4
		_glow_material.emission_enabled = true
		_glow_material.emission = glow_color
		_glow_material.emission_energy_multiplier = glow_energy
		glow_mesh.material_override = _glow_material
	_glow_light = get_node_or_null(glow_light_path) as Light3D
	if _glow_light != null:
		_glow_base_light_energy = _glow_light.light_energy
	set_process(_glow_material != null or _glow_light != null)


func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.65 + 0.35 * sin(_time * pulse_speed)
	if _glow_material != null:
		_glow_material.emission_energy_multiplier = glow_energy * pulse
	if _glow_light != null:
		_glow_light.light_energy = _glow_base_light_energy * pulse


func stop_glow() -> void:
	set_process(false)
	if _glow_material != null:
		_glow_material.emission_energy_multiplier = glow_energy * 0.3
	if _glow_light != null:
		_glow_light.visible = false


func _on_interacted(_interactor: Node) -> void:
	times_examined += 1
	if lines_id != &"":
		StoryText.say_lines(lines_id)
	GameState.set_flag(StringName("examined_%s" % object_id))
	examined.emit(object_id)
