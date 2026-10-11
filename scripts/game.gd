extends Node3D
## Four-chapter, recoverable story flow with reusable world targets and evidence journal.
const Interactable = preload("res://scripts/interactable.gd")
const StationBuilder = preload("res://scripts/station_builder.gd")
const PlayerController = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/ui/game_hud.gd")
const AmbientAudio = preload("res://scripts/ambient_audio.gd")
const Story = preload("res://scripts/story_text.gd")
const ORDER := ["3", "1", "2"]
const SETTINGS_PATH := "user://settings.cfg"

var world: Dictionary
var player
var ui
var audio
var state := "title"
var settings_return := "title"
var chapter := 1
var chapter_notice := ""
var log_read := false
var timetable_read := false
var feed_seen := false
var transcript_read := false
var memo_read := false
var list_read := false
var puzzle_solved := false
var door_open := false
var call_read := false
var arrival_started := false
var override_cut := false
var sequence: Array[String] = []
var step_clock := 0.0
var arrival_tween: Tween
var volume := 0.65
var look_scale := 1.0


func _ready() -> void:
	world = StationBuilder.new().build(self)
	player = PlayerController.new()
	player.name = "Aarav"
	player.position = Vector3(0, 0.08, 8.7)
	add_child(player)
	player.target_changed.connect(_on_target_changed)
	ui = Hud.new()
	add_child(ui)
	ui.begin_requested.connect(start_game)
	ui.resume_requested.connect(resume_game)
	ui.restart_requested.connect(restart_game)
	ui.document_closed.connect(close_document)
	ui.interaction_requested.connect(func() -> void: player.interact())
	ui.pause_requested.connect(toggle_pause)
	ui.look_requested.connect(func(relative: Vector2) -> void: player.look(relative))
	ui.journal_requested.connect(open_journal)
	ui.settings_requested.connect(open_settings)
	ui.settings_closed.connect(close_settings)
	ui.volume_changed.connect(set_volume)
	ui.sensitivity_changed.connect(set_sensitivity)
	audio = AmbientAudio.new()
	add_child(audio)
	load_settings()
	update_objective()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if state != "playing":
		return
	player.touch_move = ui.get_move()
	if player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() > 0.8:
		step_clock += delta
		if step_clock >= 0.46:
			step_clock = 0.0
			audio.footstep()
	else:
		step_clock = 0.3


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal") and state == "playing":
		get_viewport().set_input_as_handled()
		open_journal()
	elif event.is_action_pressed("pause_game") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if state == "reading":
			close_document()
		elif state == "settings":
			close_settings()
		elif state == "playing" or state == "paused":
			toggle_pause()
	elif (
		event is InputEventMouseButton
		and event.pressed
		and state == "playing"
		and not DisplayServer.is_touchscreen_available()
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func start_game() -> void:
	ui.title_screen.visible = false
	ui.hud.visible = true
	state = "playing"
	player.active = true
	capture_mouse()
	read("CHAPTER 01 / THE LOCKED DOOR", Story.INTRO)


func capture_mouse() -> void:
	if not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_pause() -> void:
	if state == "playing":
		state = "paused"
		player.active = false
		player.touch_move = Vector2.ZERO
		ui.reset_touch()
		ui.hud.visible = false
		ui.pause_screen.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif state == "paused":
		resume_game()


func resume_game() -> void:
	ui.pause_screen.visible = false
	ui.hud.visible = true
	state = "playing"
	player.active = true
	capture_mouse()


func restart_game() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


func _on_target_changed(target: Node) -> void:
	if target != null and target.has_method("prompt") and target.get("enabled"):
		ui.set_prompt(target.call("prompt"))
	else:
		ui.set_prompt("")


func activate(target: Node) -> void:
	if state != "playing" or not target is Interactable:
		return
	var item = target as Interactable
	match item.kind:
		"entrance":
			ui.flash("The entrance is locked from the other side.")
		"document":
			read_document(item.key)
		"monitor":
			feed_seen = true
			if puzzle_solved:
				list_read = true
				read("CHAPTER 03 / THE IMPOSSIBLE MANIFEST", Story.PASSENGERS)
			else:
				read("CHAPTER 02 / SECURITY ARCHIVE", Story.FEED)
		"switch":
			activate_switch(item.key)
		"door":
			if not puzzle_solved:
				ui.flash("PLATFORM 03 / EMERGENCY POWER REQUIRED")
			elif not list_read:
				ui.flash("The monitor has a new passenger list. Read it first.")
			else:
				open_gate(item)
		"phone":
			if door_open and not call_read:
				call_read = true
				item.enabled = false
				ui.set_prompt("")
				read("CHAPTER 04 / ROHAN'S CALL", Story.CALL)
		"override":
			if arrival_started and not override_cut:
				cut_announcement(item)
	update_objective()


func read_document(key: String) -> void:
	match key:
		"logbook":
			log_read = true
			read("CHAPTER 01 / STATION LOG", Story.LOGBOOK)
		"timetable":
			timetable_read = true
			read("CHAPTER 01 / DEPARTURE BOARD", Story.TIMETABLE)
		"transcript":
			transcript_read = true
			read("CHAPTER 02 / LAST SHIFT", Story.TRANSCRIPT)
		"maintenance":
			memo_read = true
			read("CHAPTER 03 / MAINTENANCE MEMO", Story.MEMO)


func activate_switch(number: String) -> void:
	if puzzle_solved:
		ui.flash("Emergency power is already restored.")
		return
	if number == ORDER[sequence.size()]:
		sequence.append(number)
		var indicators: Array = world["indicators"]
		indicators[int(number) - 1].material_override = world["materials"]["teal"]
		if sequence.size() == ORDER.size():
			solve_puzzle()
		else:
			ui.flash("RELAY %s ACTIVE  /  %d OF 3" % [number, sequence.size()], 2.5)
	else:
		sequence.clear()
		for indicator in world["indicators"]:
			indicator.material_override = world["materials"]["off"]
		ui.flash("BREAKER TRIPPED. Wrong order — all relays reset.", 4.0)
		audio.signal_chirp()


func solve_puzzle() -> void:
	puzzle_solved = true
	world["power_light"].light_energy = 1.45
	world["power_light"].light_color = Color(0.24, 0.88, 0.76)
	world["hall_light"].light_energy = 0.42
	world["platform_light"].light_energy = 1.15
	world["relay_lamp"].material_override = world["materials"]["teal"]
	world["platform_lamp"].material_override = world["materials"]["teal"]
	world["screen_text"].text = "PASSENGERS\n2014 / OPEN"
	for part in world["figure_parts"]:
		part.visible = false
	world["clock"].text = "11:59"
	ui.set_clock("11:59")
	world["door"].caption = "Platform Three gate / unlocked"
	audio.powered = true
	audio.signal_chirp()
	ui.flash("ANNOUNCEMENT: 'Aarav Sen. Your name is on the list.'", 7.0)
	update_objective()


func open_gate(item: Node) -> void:
	door_open = true
	unlock_door(item)
	world["phone"].enabled = true
	ui.set_prompt("")
	ui.flash("The gate releases. A phone rings at the far end of Platform Three.", 5.0)


func unlock_door(item: Node) -> void:
	item.set("enabled", false)
	item.visible = false
	item.collision_layer = 0
	item.get_node("CollisionShape3D").set_deferred("disabled", true)


func start_arrival() -> void:
	if arrival_started or not is_inside_tree():
		return
	arrival_started = true
	world["train"].visible = true
	world["train"].position.z = -16.0
	arrival_tween = create_tween()
	arrival_tween.tween_property(world["train"], "position:z", 0.0, 8.0)
	world["override"].enabled = true
	player.look_at(Vector3(8.1, player.global_position.y, -10.4), Vector3.UP)
	player.camera.rotation.x = 0.0
	audio.signal_chirp()
	ui.flash("The rails are humming. Find the speaker cut-off near the phone.", 7.0)
	update_objective()


func cut_announcement(item: Node) -> void:
	override_cut = true
	item.set("enabled", false)
	if arrival_tween != null and arrival_tween.is_running():
		arrival_tween.kill()
	create_tween().tween_property(world["train"], "position:z", -16.0, 5.0)
	world["power_light"].light_energy = 0.08
	world["platform_light"].light_energy = 0.0
	world["platform_lamp"].material_override = world["materials"]["off"]
	world["relay_lamp"].material_override = world["materials"]["off"]
	world["hall_light"].light_energy = 0.8
	unlock_door(world["entrance"])
	world["clock"].text = "12:00"
	ui.set_clock("12:00")
	audio.powered = false
	audio.signal_chirp()
	state = "reveal"
	player.active = false
	player.touch_move = Vector2.ZERO
	ui.reset_touch()
	ui.set_prompt("")
	ui.flash("The announcement stops. The train withdraws into the rain.", 6.0)
	await get_tree().create_timer(6.0).timeout
	if not is_inside_tree():
		return
	state = "ending"
	ui.show_end(Story.ENDING)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func update_objective() -> void:
	var next_chapter := 1
	var objective := "Find the station logbook in the waiting room"
	if not log_read:
		pass
	elif not timetable_read:
		objective = "Read the departure board in the waiting room"
	elif not feed_seen:
		next_chapter = 2
		objective = "Inspect the security monitor near the platform wall"
	elif not transcript_read:
		next_chapter = 2
		objective = "Find the operator's transcript at the ticket counter"
	elif not memo_read:
		next_chapter = 3
		objective = "Find the relay memo in the maintenance corridor"
	elif not puzzle_solved:
		next_chapter = 3
		objective = "Restore power: follow the clue, not the switch numbers"
	elif not list_read:
		next_chapter = 3
		objective = "Read the new passenger list on the monitor"
	elif not door_open:
		next_chapter = 4
		objective = "Open the gate to Platform Three"
	elif not call_read:
		next_chapter = 4
		objective = "Answer the ringing phone at the end of the platform"
	elif not override_cut:
		next_chapter = 4
		objective = "Cut off the announcement beside the service phone"
	else:
		next_chapter = 4
		objective = "The announcement has stopped"
	if next_chapter != chapter:
		chapter_notice = [
			"", "THE LOCKED DOOR", "THE SECURITY ARCHIVE", "EMERGENCY POWER", "PLATFORM THREE"
		][next_chapter]
	chapter = next_chapter
	ui.set_chapter(chapter)
	ui.set_objective(objective)


func journal_text() -> String:
	var notes := ""
	if log_read:
		notes += "LOGBOOK: Train 03 vanished in 2014. Relay: LAMP, BELL, LINE.\n\n"
	if timetable_read:
		notes += "BOARD: An announced arrival may open the train doors.\n\n"
	if feed_seen:
		notes += "FEED: The camera shows a man with a logbook on Platform Three.\n\n"
	if transcript_read:
		notes += "TRANSCRIPT: Cutting the speaker line made the train vanish.\n\n"
	if memo_read:
		notes += "MEMO: LAMP = 3. BELL = 1. LINE = 2. Wrong order resets all.\n\n"
	if list_read:
		notes += "MANIFEST: Rohan is aboard; five-year-old Aarav is 'expected'.\n\n"
	if call_read:
		notes += "ROHAN: Cut the platform speaker before the doors open.\n\n"
	if notes.is_empty():
		return "No evidence collected. Begin with the waiting-room logbook."
	return notes.strip_edges()


func open_journal() -> void:
	if state == "playing":
		read("AARAV'S NOTES / COLLECTED EVIDENCE", journal_text())


func read(heading: String, body: String) -> void:
	state = "reading"
	player.active = false
	player.touch_move = Vector2.ZERO
	ui.reset_touch()
	ui.open_document(heading, body)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_objective()


func close_document() -> void:
	if state != "reading":
		return
	ui.reader.visible = false
	ui.hud.visible = true
	state = "playing"
	player.active = true
	capture_mouse()
	if not chapter_notice.is_empty():
		ui.flash("CHAPTER %02d / %s" % [chapter, chapter_notice], 4.0)
		chapter_notice = ""
	if call_read and not arrival_started:
		start_arrival()


func open_settings() -> void:
	if state != "title" and state != "paused":
		return
	settings_return = state
	state = "settings"
	ui.title_screen.visible = false
	ui.pause_screen.visible = false
	ui.show_settings(volume, look_scale)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_settings() -> void:
	if state != "settings":
		return
	ui.settings_screen.visible = false
	state = settings_return
	if state == "paused":
		ui.pause_screen.visible = true
	else:
		ui.title_screen.visible = true


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	if audio != null:
		audio.set_volume(volume)
	save_settings()


func set_sensitivity(value: float) -> void:
	look_scale = clampf(value, 0.5, 1.7)
	if player != null:
		player.look_scale = look_scale
	save_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		volume = clampf(float(config.get_value("audio", "volume", volume)), 0.0, 1.0)
		look_scale = clampf(float(config.get_value("controls", "look", look_scale)), 0.5, 1.7)
	player.look_scale = look_scale
	audio.set_volume(volume)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume)
	config.set_value("controls", "look", look_scale)
	config.save(SETTINGS_PATH)
