extends "res://tests/test_suite.gd"
## Content integrity: every res:// path resolves, every story id used by a scene
## exists in StoryText, and the puzzle matches the switches in the level.

const SCAN_DIRS := ["res://scenes", "res://scripts", "res://ui", "res://audio", "res://tests"]
const SCAN_EXTENSIONS := ["tscn", "tres", "gd", "godot"]
const LEVEL_SCENE := "res://scenes/levels/station.tscn"


func test_all_resource_paths_resolve() -> void:
	var files: Array[String] = ["res://project.godot"]
	for dir: String in SCAN_DIRS:
		_collect_files(dir, files)
	var regex := RegEx.new()
	regex.compile("res://[A-Za-z0-9_\\-./]+\\.[a-z0-9]+")
	var checked := 0
	for file_path in files:
		var text := FileAccess.get_file_as_string(file_path)
		for m in regex.search_all(text):
			var path := m.get_string()
			if _is_optional_asset_path(path):
				continue
			checked += 1
			check(
				ResourceLoader.exists(path) or FileAccess.file_exists(path),
				"%s references existing %s" % [file_path.get_file(), path]
			)
	check(checked > 30, "scanned a meaningful number of resource references (%d)" % checked)


func test_story_ids_used_by_level_exist() -> void:
	var level := _instantiate_level()
	for node in level.find_children("*", "", true, false):
		if node is ReadableNote:
			var note := node as ReadableNote
			check(StoryText.DOCUMENTS.has(note.document_id), "%s: document '%s' exists" % [node.name, note.document_id])
		if node is StoryObject:
			var story := node as StoryObject
			if story.lines_id != &"":
				check(
					not StoryText.get_lines(story.lines_id).is_empty(),
					"%s: lines '%s' exist" % [node.name, story.lines_id]
				)
		if node is Door:
			var door := node as Door
			if door.locked_lines_id != &"":
				check(
					not StoryText.get_lines(door.locked_lines_id).is_empty(),
					"%s: lines '%s' exist" % [node.name, door.locked_lines_id]
				)
		if node is StationMonitor:
			var monitor := node as StationMonitor
			if monitor.off_lines_id != &"":
				check(
					not StoryText.get_lines(monitor.off_lines_id).is_empty(),
					"%s: lines '%s' exist" % [node.name, monitor.off_lines_id]
				)
	level.free()


func test_story_lines_used_in_code_exist() -> void:
	var regex := RegEx.new()
	regex.compile('say_lines\\(&"([a-z_]+)"\\)')
	var files: Array[String] = []
	_collect_files("res://scripts", files)
	var count := 0
	for file_path in files:
		for m in regex.search_all(FileAccess.get_file_as_string(file_path)):
			count += 1
			var id := StringName(m.get_string(1))
			check(not StoryText.get_lines(id).is_empty(), "%s: StoryText lines '%s' exist" % [file_path.get_file(), id])
	check(count >= 10, "found story line references in code (%d)" % count)
	for key: StringName in [&"find_platform", &"restore_power", &"breakers", &"go_platform", &"find_kabir"]:
		check(not StoryText.get_objective(key).is_empty(), "objective '%s' has text" % key)


func test_puzzle_matches_level_switches() -> void:
	var level := _instantiate_level()
	var panel := level.get_node("Interactables/BreakerPanel")
	var ids: Array[String] = []
	for child in panel.get_children():
		if child is PowerSwitch:
			ids.append(String((child as PowerSwitch).switch_id))
	var solution: PackedStringArray = panel.get("solution")
	check_eq(ids.size(), 3, "breaker panel has three switches")
	for id in solution:
		check(ids.has(id), "solution id '%s' matches a switch in the level" % id)
	check(ids[0] != solution[0] or ids[1] != solution[1], "switches are not physically laid out in solution order")
	check(panel.get_node_or_null(panel.get("door_path")) is Door, "puzzle door path points at a Door")
	level.free()


func test_audio_catalogue_is_complete() -> void:
	for id: StringName in AudioManager.CATALOGUE.keys():
		check(ProceduralAudio.IDS.has(id), "sound '%s' has a procedural fallback" % id)


func _is_optional_asset_path(path: String) -> bool:
	# Replacement audio files are optional by design (procedural fallback).
	return path.begins_with("res://audio/") and not path.ends_with(".tres")


func _collect_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_collect_files(dir_path.path_join(sub), out)
	for file_name in dir.get_files():
		if file_name.get_extension() in SCAN_EXTENSIONS:
			out.append(dir_path.path_join(file_name))


func _instantiate_level() -> Node:
	return (load(LEVEL_SCENE) as PackedScene).instantiate()
