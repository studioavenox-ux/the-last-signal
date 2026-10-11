extends RefCounted
## Minimal base class for headless test suites (no external test framework needed).
## Test methods are named test_*; they may use `await`.

var tree: SceneTree
var runner: Object
var current_test: String = ""


func check(condition: bool, message: String) -> bool:
	runner.call(&"record", condition, "%s :: %s" % [current_test, message])
	return condition


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	var ok: bool = typeof(actual) == typeof(expected) and actual == expected
	if not ok and (actual is String or actual is StringName) and (expected is String or expected is StringName):
		ok = String(actual) == String(expected)
	return check(ok, "%s (expected %s, got %s)" % [message, var_to_str(expected), var_to_str(actual)])


func frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


## Waits for game time (respects Engine.time_scale; not affected by pause).
func seconds(duration: float) -> void:
	await tree.create_timer(duration, true, false, false).timeout
