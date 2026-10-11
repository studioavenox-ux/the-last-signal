extends "res://tests/test_suite.gd"
## End-to-end playthrough of the prototype in the real level, headless.
##
## Drives the player through the same paths real input uses: VirtualInput (the touch
## joystick bridge), Input Map actions (what the USE button sends) and the
## interaction ray. Checks collisions, prompts, documents, the puzzle (including
## mistakes), the suspense event, the platform and the ending.

var level: StationLevel
var player: PlayerController


func test_full_playthrough() -> void:
	Settings.set_touch_mode(Settings.TouchMode.AUTO)
	level = (load("res://scenes/levels/station.tscn") as PackedScene).instantiate() as StationLevel
	tree.root.add_child(level)
	tree.current_scene = level
	await frames(5)
	player = level.player
	check(player != null, "player spawned")

	_check_world_built()
	await _check_intro()
	await _check_walking_and_collision()
	await _check_reading_notice()
	await _check_touch_controls()
	await _check_pause_menu()
	await _check_gate_is_locked()
	await _check_route_to_electrical_room()
	await _check_breaker_puzzle()
	await _check_suspense_event()
	await _check_platform_and_ending()

	Engine.time_scale = 1.0
	level.queue_free()
	tree.current_scene = null
	await frames(3)


func _check_world_built() -> void:
	var builder := level.get_node("Geometry") as StationBuilder
	var bodies := builder.get_collision_bodies()
	check(bodies.size() == 5, "five rooms have colliders (got %d)" % bodies.size())
	var shapes := 0
	for body in bodies:
		shapes += body.get_child_count()
	check(shapes >= 60, "station has box colliders (%d)" % shapes)
	# Every sign must face open space (not be buried in, or facing into, a wall).
	var space := level.get_world_3d().direct_space_state
	var signs := builder.find_children("*", "Label3D", true, false)
	check(signs.size() >= 7, "station signs generated (%d)" % signs.size())
	for node in signs:
		var label := node as Label3D
		var forward := label.global_transform.basis.z.normalized()
		var from := label.global_position + forward * 0.02
		var query := PhysicsRayQueryParameters3D.create(from, from + forward * 0.6, 1)
		var hit := space.intersect_ray(query)
		check(hit.is_empty(), "sign '%s' faces open space" % label.text.replace("\n", " "))
	var meshes := builder.find_children("*", "MeshInstance3D", true, false).size()
	check(meshes > 20 and meshes < 120, "geometry is merged into a modest number of meshes (%d)" % meshes)


func _check_intro() -> void:
	await seconds(4.0)
	check_eq(GameState.objective, StoryText.get_objective(&"find_platform"), "intro sets the first objective")
	check(level.entrance_doors.locked, "entrance doors are locked after slamming shut")
	check(player.movement_enabled, "movement re-enabled after the intro")


func _check_walking_and_collision() -> void:
	var start := player.global_position
	VirtualInput.move_vector = Vector2(0, -1)
	await seconds(1.0)
	VirtualInput.move_vector = Vector2.ZERO
	await seconds(0.3)
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z)
	check(
		moved.length() > 1.5 and moved.length() < 3.5,
		"joystick input walks ~2.4 m in 1 s (moved %.2f m)" % moved.length()
	)
	check(moved.y < -1.5, "forward on the joystick moves north (dz %.2f)" % moved.y)
	check(absf(player.global_position.y) < 0.2, "player stays on the floor (y %.2f)" % player.global_position.y)
	# Walk into the west wall between the benches.
	player.teleport(Vector3(-4.2, 0.05, -3.75), deg_to_rad(90.0))
	VirtualInput.move_vector = Vector2(0, -1)
	await seconds(2.0)
	VirtualInput.move_vector = Vector2.ZERO
	var x := player.global_position.x
	check(x > -5.9 and x < -5.3, "the wall stops the player (x %.2f)" % x)


func _check_reading_notice() -> void:
	var notice := level.get_node("Interactables/StationNotice") as ReadableNote
	player.teleport(Vector3(-4.7, 0.05, -3.75), deg_to_rad(90.0))
	player.face_point(notice.interactable.global_position)
	await physics_frames(3)
	player.interactor.refresh()
	check(player.interactor.current_target == notice.interactable, "interaction ray targets the notice")
	await frames(1)
	check_eq(level.hud.get_prompt_text(), "Read the notice", "HUD shows the contextual prompt")
	# Press Interact exactly like the on-screen USE button does.
	VirtualInput.send_action(&"interact", true)
	await frames(3)
	VirtualInput.send_action(&"interact", false)
	await frames(2)
	var viewer := level.get_node("DocumentViewer") as DocumentViewer
	check(viewer.is_open(), "Interact action opens the document viewer")
	check(tree.paused, "reading pauses the game")
	check(GameState.has_flag(&"read_station_notice"), "reading sets the story flag")
	viewer.close()
	await frames(2)
	check(not tree.paused, "closing the document resumes the game")
	check_eq(GameState.objective, StoryText.get_objective(&"restore_power"), "notice updates the objective")


func _check_touch_controls() -> void:
	Settings.set_touch_mode(Settings.TouchMode.ALWAYS)
	await frames(2)
	var touch := level.get_node("TouchControls/Controls") as TouchControls
	check(touch.visible, "touch controls appear when enabled")
	var view_size := touch.get_viewport_rect().size
	var thumb := Vector2(200, view_size.y - 160)
	_touch(0, thumb, true)
	await frames(1)
	_drag(0, thumb + Vector2(0, -120), Vector2(0, -120))
	await frames(2)
	check(
		VirtualInput.move_vector.y < -0.9,
		"dragging the joystick up means walk forward (%.2f)" % VirtualInput.move_vector.y
	)
	_touch(0, thumb + Vector2(0, -120), false)
	await frames(2)
	check(VirtualInput.move_vector == Vector2.ZERO, "lifting the thumb stops walking")
	var yaw_before := player.rotation.y
	var look_start := Vector2(view_size.x * 0.6, view_size.y * 0.4)
	_touch(1, look_start, true)
	await frames(1)
	_drag(1, look_start + Vector2(120, 0), Vector2(120, 0))
	await frames(3)
	_touch(1, look_start + Vector2(120, 0), false)
	await frames(1)
	check(player.rotation.y < yaw_before - 0.05, "dragging right on the look area turns right")
	var torch_before := player.flashlight.visible
	var torch_button := touch.get_button_center(&"flashlight")
	_touch(2, torch_button, true)
	await frames(2)
	_touch(2, torch_button, false)
	await frames(2)
	check(player.flashlight.visible != torch_before, "LIGHT button toggles the phone torch")
	Settings.set_touch_mode(Settings.TouchMode.AUTO)
	await frames(1)
	if not player.flashlight.visible:
		player.toggle_flashlight()


func _check_pause_menu() -> void:
	VirtualInput.send_action(&"pause", true)
	await frames(2)
	VirtualInput.send_action(&"pause", false)
	await frames(1)
	var pause_menu := level.get_node("PauseMenu") as PauseMenu
	check(pause_menu.is_open() and tree.paused, "Pause action opens the pause menu and pauses")
	pause_menu.close()
	await frames(2)
	check(not tree.paused, "Resume unpauses")


func _check_gate_is_locked() -> void:
	# Walk from the entrance hall through the archway into the waiting hall.
	player.teleport(Vector3(0.0, 0.05, -6.0), 0.0)
	VirtualInput.move_vector = Vector2(0, -1)
	await seconds(2.5)
	VirtualInput.move_vector = Vector2.ZERO
	await seconds(0.3)
	check(
		player.global_position.z < -10.0,
		"walked through the archway into the waiting hall (z %.2f)" % player.global_position.z
	)
	var gate := level.platform_gate
	await _use(gate, gate.interactable, 2.0)
	await seconds(0.3)
	check(gate.locked and not gate.is_open, "Platform 3 gate stays locked without power")
	check(GameState.has_flag(&"heard_name"), "the announcement fired on entering the waiting hall")


func _check_route_to_electrical_room() -> void:
	var door := level.get_node("Interactables/MaintenanceDoor") as Door
	await _use(door, door.interactable, 1.4)
	await seconds(1.2)
	check(door.is_open, "maintenance door opens")
	player.teleport(Vector3(-5.6, 0.05, -12.0), deg_to_rad(90.0))
	VirtualInput.move_vector = Vector2(0, -1)
	await seconds(4.6)
	VirtualInput.move_vector = Vector2.ZERO
	await seconds(0.3)
	var pos := player.global_position
	check(
		pos.x < -15.3 and pos.x > -20.9,
		"walked through the door and corridor into the electrical room (x %.2f)" % pos.x
	)
	check_eq(GameState.objective, StoryText.get_objective(&"breakers"), "electrical room sets the breaker objective")


func _check_breaker_puzzle() -> void:
	var panel := level.breaker_panel
	var green := panel.get_switch(&"green")
	var red := panel.get_switch(&"red")
	var yellow := panel.get_switch(&"yellow")
	await _use(green, green.interactable, 1.1)
	await frames(2)
	check_eq(panel.get_mistakes(), 1, "wrong first breaker trips the panel")
	await seconds(1.3)
	check(not green.is_on and not red.is_on and not yellow.is_on, "all breakers reset after a trip")
	await _use(red, red.interactable, 1.1)
	check(red.is_on and panel.get_progress() == 1, "RED first is accepted")
	await _use(green, green.interactable, 1.1)
	await frames(2)
	check_eq(panel.get_mistakes(), 2, "GREEN before YELLOW is a mistake")
	await seconds(1.3)
	check(not red.is_on, "progress resets after the second mistake")
	await _use(red, red.interactable, 1.1)
	await _use(yellow, yellow.interactable, 1.1)
	await _use(green, green.interactable, 1.1)
	await frames(2)
	check(panel.is_solved, "RED -> YELLOW -> GREEN solves the puzzle")
	check(not level.platform_gate.locked, "solving unlocks the Platform 3 gate")
	check(GameState.has_flag(&"power_restored"), "suspense event started")


func _check_suspense_event() -> void:
	Engine.time_scale = 4.0
	await seconds(16.0)
	Engine.time_scale = 1.0
	var event := level.power_event
	check(event.has_finished, "power-restored event finished")
	check_eq(GameState.objective, StoryText.get_objective(&"go_platform"), "objective now points to Platform 3")
	var monitor := level.get_node("Interactables/ControlMonitor") as StationMonitor
	check(monitor.powered, "control monitor booted")
	check(monitor.label.text.contains("WELCOME BACK"), "monitor reveals the new message")
	var clock := level.get_node("Interactables/StationClock") as StationClock
	check(clock.running, "the stopped clock is running again")
	var emergency := 0
	for light in event.get_station_lights():
		if light.mode == FlickerLight.Mode.EMERGENCY:
			emergency += 1
	check(emergency >= 6, "station lights switched to emergency mode (%d)" % emergency)
	check(AudioManager.is_ambience_playing(&"hum"), "electrical hum ambience started")


func _check_platform_and_ending() -> void:
	# Looking at the gate from the waiting hall triggers the apparition.
	player.teleport(Vector3(0.0, 0.05, -15.5), 0.0)
	player.face_point(level.apparition.global_position + Vector3.UP * 1.1)
	await frames(4)
	check(GameState.has_flag(&"saw_apparition"), "the apparition appears when the player looks at the platform")
	await seconds(1.5)
	var gate := level.platform_gate
	await _use(gate, gate.interactable, 2.0)
	await seconds(1.6)
	check(gate.is_open, "the unlocked gate opens")
	player.teleport(Vector3(0.0, 0.05, -16.5), 0.0)
	VirtualInput.move_vector = Vector2(0, -1)
	await seconds(1.8)
	VirtualInput.move_vector = Vector2.ZERO
	await seconds(0.5)
	check(
		player.global_position.z < -18.5,
		"walked through the gate onto the platform (z %.2f)" % player.global_position.z
	)
	check(GameState.has_flag(&"on_platform"), "platform trigger fired")
	check_eq(GameState.objective, StoryText.get_objective(&"find_kabir"), "objective: find Kabir")
	# The edge barrier keeps the player off the tracks.
	player.teleport(Vector3(2.0, 0.05, -23.0), 0.0)
	VirtualInput.move_vector = Vector2(0, -1)
	await seconds(2.0)
	VirtualInput.move_vector = Vector2.ZERO
	check(
		player.global_position.z > -25.7 and player.global_position.y > -0.3,
		"platform edge barrier stops the player (z %.2f)" % player.global_position.z
	)
	var phone := level.kabir_phone
	player.teleport(Vector3(4.3, 0.05, -19.6), 0.0)
	player.face_point(phone.interactable.global_position)
	await physics_frames(3)
	player.interactor.refresh()
	check(player.interactor.current_target == phone.interactable, "Kabir's phone can be targeted from the gate side")
	player.interactor.try_interact(player)
	await frames(2)
	check(GameState.has_flag(&"ending_started"), "picking up the phone starts the ending")
	check(not player.movement_enabled, "movement locked during the ending")
	Engine.time_scale = 4.0
	await seconds(25.0)
	Engine.time_scale = 1.0
	var rail_signal := level.get_node("Interactables/RailwaySignal") as RailwaySignal
	check_eq(rail_signal.aspect, &"green", "the last signal turns green")
	check(GameState.has_flag(&"game_completed"), "ending completed")
	check(level.hud.end_screen.visible, "end-of-prototype screen is shown")
	check(not GameState.is_playing, "game is no longer in the playing state")


# --- Helpers ---------------------------------------------------------------------


## Stands in front of [param target] (along its local +Z), looks at it and interacts.
func _use(target: Node3D, interactable: Interactable, distance: float) -> bool:
	var forward := target.global_transform.basis.z.normalized()
	var stand := target.global_position + forward * distance
	stand.y = 0.05
	player.teleport(stand, 0.0)
	player.face_point(interactable.global_position)
	await physics_frames(2)
	player.interactor.refresh()
	var ok := player.interactor.current_target == interactable
	check(ok, "can target %s from %.1f m" % [target.name, distance])
	if ok:
		player.interactor.try_interact(player)
	await frames(1)
	return ok


## Touch events arrive in window pixels (like on a real phone) and Godot converts them
## to viewport units. Tests think in viewport units, so convert with the stretch transform.
func _to_window(viewport_pos: Vector2) -> Vector2:
	return tree.root.get_final_transform() * viewport_pos


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _to_window(pos)
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _to_window(pos)
	event.relative = tree.root.get_final_transform().basis_xform(relative)
	event.screen_relative = event.relative
	Input.parse_input_event(event)
