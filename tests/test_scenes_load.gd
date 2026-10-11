extends "res://tests/test_suite.gd"
## Every scene in the project loads and instantiates.


func test_all_scenes_instantiate() -> void:
	var scenes: Array[String] = []
	_collect("res://scenes", scenes)
	check(scenes.size() >= 15, "found the project's scenes (%d)" % scenes.size())
	for path in scenes:
		var packed := load(path) as PackedScene
		if not check(packed != null, "%s loads" % path):
			continue
		var instance := packed.instantiate()
		check(instance != null, "%s instantiates" % path)
		if instance != null:
			instance.free()


func test_title_screen_runs() -> void:
	var title := (load("res://scenes/main/title_screen.tscn") as PackedScene).instantiate()
	tree.root.add_child(title)
	await frames(10)
	check(title.get_node("%BeginButton") is Button, "title has a Begin button")
	check(title.get_node("%BeginButton").has_focus(), "Begin button has focus (gamepad/keyboard friendly)")
	title.queue_free()
	await frames(2)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file_name in dir.get_files():
		if file_name.ends_with(".tscn"):
			out.append(dir_path.path_join(file_name))


func test_credits_include_engine_license() -> void:
	var title_script := load("res://scripts/ui/title_screen.gd") as GDScript
	var text: String = title_script.call(&"build_credits_text")
	check(text.contains("Godot Engine"), "credits mention Godot Engine")
	check(text.contains("Permission is hereby granted"), "credits include the Godot MIT license text")
	check(text.contains("FreeType"), "credits list third-party components such as FreeType")
