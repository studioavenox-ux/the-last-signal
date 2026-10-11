extends "res://tests/test_suite.gd"
## Edge cases outside the main playthrough order.

const LEVEL_SCENE := "res://scenes/levels/station.tscn"


func test_rushing_to_platform_keeps_objective() -> void:
	var level := _spawn_level()
	await frames(3)
	# Solve the breakers directly (order RED -> YELLOW -> GREEN), then rush to the platform
	# before the ~14 s suspense event has finished.
	for id: StringName in [&"red", &"yellow", &"green"]:
		level.breaker_panel.get_switch(id).interactable.interact(level.player)
		await frames(1)
	check(level.breaker_panel.is_solved, "puzzle solved directly")
	level.player.teleport(Vector3(0.0, 0.05, -21.5), 0.0)
	await seconds(0.6)
	check(GameState.has_flag(&"on_platform"), "platform reached while the event is still running")
	check(not level.power_event.has_finished, "suspense event still in progress")
	Engine.time_scale = 4.0
	await seconds(16.0)
	Engine.time_scale = 1.0
	check(level.power_event.has_finished, "suspense event finished")
	check_eq(
		GameState.objective, StoryText.get_objective(&"find_kabir"), "objective stays 'Find Kabir' (no regression)"
	)
	await _despawn(level)


func test_restart_stops_power_hum() -> void:
	AudioManager.start_ambience(&"hum", -18.0, 0.0)
	await frames(2)
	check(AudioManager.is_ambience_playing(&"hum"), "hum playing before restart")
	var level := _spawn_level()
	await seconds(0.8)
	check(not AudioManager.is_ambience_playing(&"hum"), "a fresh (unpowered) level stops the hum")
	check(AudioManager.is_ambience_playing(&"rain"), "rain ambience plays in the level")
	await _despawn(level)


func test_pause_freezes_story_sequences() -> void:
	var level := _spawn_level(false)
	await frames(3)
	var pause_menu := level.get_node("PauseMenu") as PauseMenu
	pause_menu.open()
	await seconds(4.0)
	check(not level.entrance_doors.locked, "intro does not advance while paused")
	pause_menu.close()
	await seconds(4.0)
	check(level.entrance_doors.locked, "intro continues after resuming")
	await _despawn(level)


func _spawn_level(skip_intro: bool = true) -> StationLevel:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate() as StationLevel
	level.skip_intro = skip_intro
	tree.root.add_child(level)
	tree.current_scene = level
	return level


func _despawn(level: StationLevel) -> void:
	tree.paused = false
	level.queue_free()
	tree.current_scene = null
	await frames(3)
