class_name StationMonitor
extends Node3D
## A CRT-style monitor or departure board that can boot up and type messages.
##
## Meshes in the scene are local-to-scene, so each instance can have its own
## [member screen_size]. Text uses Label3D (cheap; no viewports).

signal text_finished

@export var screen_size: Vector2 = Vector2(0.9, 0.52)
@export var powered: bool = false
@export_multiline var text: String = ""
@export var text_color: Color = Color(1.0, 0.62, 0.22)
@export var font_size: int = 26
## Glyph height in metres (keeps text readable at the intended viewing distance).
@export var text_height: float = 0.03
## Lines id (StoryText) used when the player examines the screen while it's off.
@export var off_lines_id: StringName = &"control_monitor_off"
@export var examine_prompt: String = "Examine the monitor"

var _screen_material: StandardMaterial3D
var _type_tween: Tween
var _full_text: String = ""

@onready var body: MeshInstance3D = $Body
@onready var screen: MeshInstance3D = $Screen
@onready var label: Label3D = $Text
@onready var interactable: Interactable = get_node_or_null(^"Interactable")


func _ready() -> void:
	if body.mesh is BoxMesh:
		(body.mesh as BoxMesh).size = Vector3(screen_size.x + 0.1, screen_size.y + 0.1, 0.1)
	if screen.mesh is QuadMesh:
		(screen.mesh as QuadMesh).size = screen_size
	_screen_material = StandardMaterial3D.new()
	_screen_material.emission_enabled = true
	screen.material_override = _screen_material
	label.font_size = font_size
	label.pixel_size = text_height / float(maxi(font_size, 1))
	label.modulate = text_color
	label.width = screen_size.x * 0.92 / label.pixel_size
	if interactable != null:
		interactable.prompt_text = examine_prompt
		interactable.interacted.connect(_on_interacted)
		var shape_node := interactable.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			(shape_node.shape as BoxShape3D).size = Vector3(screen_size.x + 0.1, screen_size.y + 0.15, 0.4)
	_full_text = text
	_apply_power_visuals()


func power_on(boot_text: String = "") -> void:
	powered = true
	AudioManager.play_at(&"monitor_on", global_position, -2.0)
	_apply_power_visuals()
	flicker(0.5)
	if not boot_text.is_empty():
		type_text(boot_text)


func power_off() -> void:
	powered = false
	_apply_power_visuals()


## Types text onto the screen at [param chars_per_second].
func type_text(new_text: String, chars_per_second: float = 45.0) -> void:
	_full_text = new_text
	text = new_text
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	label.text = ""
	var duration := maxf(new_text.length() / maxf(chars_per_second, 1.0), 0.05)
	_type_tween = create_tween()
	_type_tween.tween_method(_set_visible_count, 0, new_text.length(), duration)
	_type_tween.tween_callback(text_finished.emit)


## Shows text immediately (no typing).
func set_text_now(new_text: String) -> void:
	_full_text = new_text
	text = new_text
	label.text = new_text if powered else ""


## Brief brightness flicker; cheap "glitch" effect.
func flicker(duration: float = 0.6) -> void:
	var tween := create_tween()
	var steps := int(duration / 0.06)
	for i in steps:
		tween.tween_callback(_set_screen_energy.bind(randf_range(0.1, 1.6)))
		tween.tween_interval(0.06)
	tween.tween_callback(_apply_power_visuals)


## Replaces the text with scrambled characters for a moment, then shows new text.
func glitch_to(new_text: String) -> void:
	var tween := create_tween()
	for i in 6:
		tween.tween_callback(func() -> void: label.text = _scramble(_full_text))
		tween.tween_interval(0.07)
	tween.tween_callback(func() -> void: type_text(new_text, 30.0))
	flicker(0.45)


func _set_visible_count(count: int) -> void:
	label.text = _full_text.substr(0, count)


func _set_screen_energy(energy: float) -> void:
	_screen_material.emission_energy_multiplier = energy


func _apply_power_visuals() -> void:
	if powered:
		_screen_material.albedo_color = Color(0.05, 0.04, 0.02)
		_screen_material.emission = text_color.darkened(0.82)
		_screen_material.emission_energy_multiplier = 1.0
		label.visible = true
		if label.text.is_empty():
			label.text = _full_text
	else:
		_screen_material.albedo_color = Color(0.02, 0.025, 0.03)
		_screen_material.emission = Color.BLACK
		_screen_material.emission_energy_multiplier = 0.0
		label.visible = false


func _on_interacted(_interactor: Node) -> void:
	if powered and not _full_text.is_empty():
		GameState.notify(_full_text.replace("\n", "   "), 5.0)
	elif off_lines_id != &"":
		StoryText.say_lines(off_lines_id)


static func _scramble(source: String) -> String:
	const GLYPHS := "#%&@*+=?/\\|<>_"
	var out := ""
	for ch in source:
		out += ch if ch == "\n" or ch == " " else GLYPHS[randi() % GLYPHS.length()]
	return out
