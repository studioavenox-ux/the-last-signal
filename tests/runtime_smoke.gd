extends SceneTree
## Run with: godot --headless --path . --script res://tests/runtime_smoke.gd
## Logic route only; still playtest navigation, visuals, sound, and real touch hardware.


func _initialize() -> void:
	call_deferred("run_route")


func require(condition: bool, message: String) -> void:
	if not condition:
		push_error("ROUTE TEST: " + message)
		quit(1)


func run_route() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	require(scene.state == "title", "title did not open")
	require(scene.world["materials"]["floor"].albedo_texture != null, "wear texture missing")
	scene.open_settings()
	require(scene.state == "settings" and scene.ui.settings_screen.visible, "title settings failed")
	scene.close_settings()
	require(scene.state == "title", "settings did not return to title")
	scene.start_game()
	require(scene.state == "reading", "intro should be readable")
	scene.close_document()
	scene.ui.joystick.finger = 7
	scene.ui.joystick.value = Vector2(1, 0)
	scene.toggle_pause()
	require(scene.state == "paused" and not scene.player.active, "pause failed")
	require(scene.ui.joystick.finger == -1, "pause left a held touch stick")
	scene.resume_game()
	require(scene.state == "playing" and scene.player.active, "resume failed")
	scene.open_journal()
	require(scene.state == "reading", "journal failed")
	scene.close_document()
	scene.activate(scene.world["logbook"])
	scene.close_document()
	scene.activate(scene.world["timetable"])
	scene.close_document()
	require(scene.chapter == 2, "chapter 2 did not start")
	scene.activate(scene.world["monitor"])
	scene.close_document()
	scene.activate(scene.world["transcript"])
	scene.close_document()
	scene.activate(scene.world["clue"])
	scene.close_document()
	require(scene.chapter == 3, "chapter 3 did not start")
	scene.player.position = Vector3(0, 0.08, 1.8)
	scene.player.rotation.y = 0.0
	scene.player.camera.rotation.x = 0.0
	scene.player.ray.force_raycast_update()
	require(scene.player.ray.get_collider() == scene.world["door"], "gate not raycastable")
	scene.activate_switch("1")
	require(scene.sequence.size() == 0, "wrong switch did not reset")
	scene.activate_switch("3")
	scene.activate_switch("1")
	scene.activate_switch("2")
	require(scene.puzzle_solved, "correct order failed")
	scene.activate(scene.world["monitor"])
	scene.close_document()
	scene.activate(scene.world["door"])
	require(scene.door_open, "gate did not open")
	await process_frame
	scene.player.ray.force_raycast_update()
	require(scene.player.ray.get_collider() != scene.world["door"], "gate still blocks ray")
	scene.activate(scene.world["phone"])
	scene.close_document()
	require(scene.arrival_started and scene.chapter == 4, "train call failed")
	scene.activate(scene.world["override"])
	require(scene.override_cut, "speaker cut-off failed")
	require(not scene.world["entrance"].visible, "exit did not unlock")
	await create_timer(6.2).timeout
	require(scene.state == "ending" and scene.ui.ending.visible, "ending did not display")
	print("ROUTE TEST PASS: title -> four chapters -> wrong/reset -> solution -> ending")
	quit(0)
