extends CharacterBody3D
## Desktop mouse/keys and HUD-provided touch stick/look share one camera.

signal target_changed(target: Node)

const SPEED := 4.0
const MOUSE_SENSITIVITY := 0.0022
const TOUCH_SENSITIVITY := 0.0033

var active := false
var look_scale := 1.0
var touch_move := Vector2.ZERO
var current_target: Node = null
var camera: Camera3D
var ray: RayCast3D


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.7
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.85
	add_child(collision)
	collision_layer = 4
	collision_mask = 3
	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.fov = 72.0
	camera.current = true
	add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.3)
	ray.collision_mask = 3
	ray.exclude_parent = true
	camera.add_child(ray)


func _physics_process(delta: float) -> void:
	if not active:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move.length() > direction.length():
		direction = touch_move
	var forward := global_transform.basis * Vector3(direction.x, 0, direction.y)
	velocity.x = forward.x * SPEED
	velocity.z = forward.z * SPEED
	if is_on_floor():
		velocity.y = -0.2
	else:
		velocity.y -= 16.0 * delta
	move_and_slide()
	ray.force_raycast_update()
	var next_target = ray.get_collider() if ray.is_colliding() else null
	if next_target != current_target:
		current_target = next_target
		target_changed.emit(current_target)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative, MOUSE_SENSITIVITY)
	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		interact()


func look(relative: Vector2, sensitivity: float = TOUCH_SENSITIVITY) -> void:
	if not active:
		return
	rotate_y(-relative.x * sensitivity * look_scale)
	camera.rotation.x = clampf(
		camera.rotation.x - relative.y * sensitivity * look_scale, -1.35, 1.35
	)


func interact() -> void:
	if not active:
		return
	ray.force_raycast_update()
	var target = ray.get_collider() if ray.is_colliding() else null
	if target != null and target.has_method("prompt") and target.get("enabled"):
		get_parent().call("activate", target)
