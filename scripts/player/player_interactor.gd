class_name PlayerInteractor
extends RayCast3D
## Finds the [Interactable] the player is looking at and forwards interaction.
##
## Attach to a RayCast3D under the camera. The ray collides with the world (so
## walls block interaction) and with the "interactable" layer. Physics bodies can
## point at their interactable through metadata ("interactable"), so aiming at a
## door panel works as well as aiming at its trigger area.

signal target_changed(target: Interactable)
signal prompt_changed(text: String)

const META_KEY := &"interactable"

@export var reach: float = 2.4:
	set(value):
		reach = value
		target_position = Vector3(0.0, 0.0, -reach)

var current_target: Interactable = null
var _last_prompt: String = ""


func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -reach)
	collide_with_areas = true
	collide_with_bodies = true
	collision_mask = 1 | Interactable.INTERACTABLE_LAYER
	enabled = true
	var body := get_parent()
	while body != null and not (body is CollisionObject3D):
		body = body.get_parent()
	if body is CollisionObject3D:
		add_exception(body as CollisionObject3D)


func _physics_process(_delta: float) -> void:
	refresh(false)


## Re-evaluates the current target. [param force] re-casts the ray immediately
## instead of using the result from the last physics step (used on interact and by tests).
func refresh(force: bool = true) -> void:
	if force:
		force_raycast_update()
	var target: Interactable = null
	if is_colliding():
		target = resolve_interactable(get_collider())
		if target != null and not target.enabled:
			target = null
	_set_target(target)
	var prompt := current_target.get_prompt() if current_target != null else ""
	if prompt != _last_prompt:
		_last_prompt = prompt
		prompt_changed.emit(prompt)


## Interacts with the current target. Returns true if something was used.
func try_interact(interactor: Node) -> bool:
	refresh()
	if current_target == null or not is_instance_valid(current_target):
		return false
	if not current_target.can_interact(interactor):
		return false
	current_target.interact(interactor)
	# The prompt may have changed (e.g. "Open" -> "Close").
	refresh()
	return true


static func resolve_interactable(collider: Object) -> Interactable:
	if collider is Interactable:
		return collider as Interactable
	if collider is Node and (collider as Node).has_meta(META_KEY):
		return (collider as Node).get_meta(META_KEY) as Interactable
	return null


func _set_target(target: Interactable) -> void:
	if target == current_target:
		return
	if current_target != null and is_instance_valid(current_target):
		current_target.set_focused(false)
	current_target = target
	if current_target != null:
		current_target.set_focused(true)
	target_changed.emit(current_target)
