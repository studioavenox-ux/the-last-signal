class_name Interactable
extends Area3D
## Reusable interaction component.
##
## Add this Area3D (with a CollisionShape3D child) to any object the player can use:
## doors, notes, switches, story objects... The player's [PlayerInteractor] ray finds it,
## the HUD shows [method get_prompt], and pressing Interact calls [method interact],
## which emits [signal interacted]. The owning object's script reacts to that signal,
## so behaviour stays in the object while targeting/prompt logic is shared.
##
## Objects can also extend this class directly and override [method _on_interact].

signal interacted(interactor: Node)
signal focus_changed(focused: bool)

const INTERACTABLE_LAYER := 1 << 2  # physics layer 3: "interactable"

## Text shown in the HUD, e.g. "Read notice" or "Open door".
@export var prompt_text: String = "Interact"
## Disabled interactables are ignored by the player's ray.
@export var enabled: bool = true
## Automatically disable after the first successful interaction.
@export var one_shot: bool = false

var is_focused: bool = false


func _ready() -> void:
	collision_layer = INTERACTABLE_LAYER
	collision_mask = 0
	monitorable = true


func get_prompt() -> String:
	return prompt_text


func can_interact(_interactor: Node) -> bool:
	return enabled


func interact(interactor: Node) -> void:
	if not can_interact(interactor):
		return
	if one_shot:
		enabled = false
	_on_interact(interactor)
	interacted.emit(interactor)


func set_focused(focused: bool) -> void:
	if focused == is_focused:
		return
	is_focused = focused
	focus_changed.emit(focused)


## Override in subclasses for built-in behaviour.
func _on_interact(_interactor: Node) -> void:
	pass
