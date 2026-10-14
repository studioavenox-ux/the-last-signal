extends SceneTree
## Run with: godot --headless --path . --script res://tests/runtime_smoke.gd
## Logic route only; still playtest navigation, visuals, sound, and real touch hardware.

## World-space footprint each imported track module must land in once _rebase() and the
## wrapper scale have been applied: [min x, max x, min z, max z]. Mirrors tests/test_railway.py.
## Laid gauge 1.680 m (Indian broad gauge), rail top 0.280 m, 11.200 m modules from z -33.6.
const LAID_TRACK := [
	[7.02, 8.98, -33.6, -22.4],
	[6.561, 9.439, -22.4, -11.2],
	[6.60, 9.40, -11.2, 0.00]
]


func _initialize() -> void:
	call_deferred("run_route")


func require(condition: bool, message: String) -> void:
	if not condition:
		push_error("ROUTE TEST: " + message)
		quit(1)


func check_railway(scene: Node) -> void:
	var railway: Node3D = scene.world["railway"]
	require(railway.get_child_count() == LAID_TRACK.size(), "not every railway module instanced")
	var fallback: Node3D = railway.get_parent().get_node("ProceduralTrackFallback")
	require(not fallback.visible, "procedural fallback stayed visible with modules loaded")
	for index in railway.get_child_count():
		var track: Node3D = railway.get_child(index)
		var expected: Array = LAID_TRACK[index]
		var laid := laid_bounds(track)
		var rests := laid.position.y > -0.005 and laid.position.y < 0.005
		require(rests, "module %d does not rest on the bed: %s" % [index + 1, laid])
		require(absf(laid.end.y - 0.28) < 0.01, "module %d rail height wrong: %s" % [index + 1, laid])
		var on_bed := (
			absf(laid.position.x - float(expected[0])) < 0.01
			and absf(laid.end.x - float(expected[1])) < 0.01
		)
		require(on_bed, "module %d is off the track bed: %s" % [index + 1, laid])
		var on_line := (
			absf(laid.position.z - float(expected[2])) < 0.01
			and absf(laid.end.z - float(expected[3])) < 0.01
		)
		require(on_line, "module %d is off the running line: %s" % [index + 1, laid])
		for surface in track.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = surface
			require(mesh.material_override != null, "module %d needs the unshipped colormap" % index)
	var station: Node3D = railway.get_parent()
	if station.has_node("TracksideParapet"):
		var parapet: MultiMeshInstance3D = station.get_node("TracksideParapet")
		require(parapet.multimesh != null, "building kit parapet has no mesh")
		require(parapet.multimesh.instance_count == 6, "parapet instance count is wrong")
		require(parapet.material_override != null, "parapet needs the unshipped colormap")


func laid_bounds(track: Node3D) -> AABB:
	var total := AABB()
	var found := false
	for surface in track.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = surface
		if mesh.mesh == null:
			continue
		var local: AABB = track.global_transform.affine_inverse() * (
			mesh.global_transform * mesh.get_aabb()
		)
		total = local if not found else total.merge(local)
		found = true
	return total


func run_route() -> void:
	var preview_resource: PackedScene = load("res://scenes/station_preview.tscn")
	require(preview_resource != null, "station preview scene did not load")
	var preview: Node3D = preview_resource.instantiate()
	root.add_child(preview)
	await process_frame
	var preview_station := preview.get_node_or_null("NirvaHalt") as Node3D
	require(preview_station != null, "station preview did not build its station")
	var preview_camera := preview.get_node_or_null("PreviewCamera") as Camera3D
	require(preview_camera != null and preview_camera.current, "station preview camera is not active")
	require(
		preview_station.get_node_or_null("TracksideParapet") is MultiMeshInstance3D,
		"station preview did not build the parapet"
	)
	require(
		preview_station.find_children("*", "OmniLight3D", true, false).size() == 4,
		"station preview did not build all four station lights"
	)
	preview.queue_free()
	await process_frame

	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	require(scene.state == "title", "title did not open")
	require(scene.world["materials"]["floor"].albedo_texture != null, "wear texture missing")
	check_railway(scene)
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
