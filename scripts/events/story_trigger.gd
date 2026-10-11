class_name StoryTrigger
extends Area3D
## Invisible volume that fires a story beat when the player walks into it.
##
## Optional flag conditions let one trigger wait for an earlier beat
## (required_flag) or stop once a later beat happened (blocking_flag). If the
## player is already inside when the conditions become true, it still fires.

signal triggered(trigger_id: StringName)

const CHECK_INTERVAL := 0.25

@export var trigger_id: StringName = &""
@export var one_shot: bool = true
@export var required_flag: StringName = &""
@export var blocking_flag: StringName = &""

var has_fired: bool = false
var _check_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# The periodic overlap check only covers the first firing (for triggers whose
	# flag condition became true while the player was already inside). Repeat
	# firings of non-one-shot triggers happen on re-entry via body_entered.
	if has_fired:
		set_physics_process(false)
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	for body in get_overlapping_bodies():
		if body.is_in_group(&"player"):
			try_fire()
			return


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		try_fire()


func can_fire() -> bool:
	if has_fired and one_shot:
		return false
	if required_flag != &"" and not GameState.has_flag(required_flag):
		return false
	if blocking_flag != &"" and GameState.has_flag(blocking_flag):
		return false
	return true


func try_fire() -> bool:
	if not can_fire():
		return false
	has_fired = true
	triggered.emit(trigger_id)
	return true
