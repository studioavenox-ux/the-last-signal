extends SceneTree
## Headless test runner for THE LAST SIGNAL.
##
## Usage (from the project folder):
##   godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
## Optional: append `-- --suite=gameplay` to run suites whose file name contains "gameplay".
## Exit code: 0 when every check passes, 1 otherwise.

const SUITES := [
	"res://tests/test_sequence_lock.gd",
	"res://tests/test_project_config.gd",
	"res://tests/test_content_integrity.gd",
	"res://tests/test_procedural_assets.gd",
	"res://tests/test_scenes_load.gd",
	"res://tests/test_gameplay_flow.gd",
]

## Safety net: a broken suite must never hang CI or a terminal.
const WATCHDOG_MSEC := 240000

var _passed: int = 0
var _failed: Array[String] = []
var _started_msec: int = 0


func _initialize() -> void:
	_started_msec = Time.get_ticks_msec()
	# Defer so autoload singletons are fully ready before tests touch them.
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started_msec > WATCHDOG_MSEC:
		printerr("WATCHDOG: tests exceeded %.0f s - aborting." % (WATCHDOG_MSEC / 1000.0))
		for message in _failed:
			printerr("  FAILED: ", message)
		quit(2)
	return false


func record(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed.append(message)
		printerr("    FAIL: ", message)


func _run() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			filter = arg.trim_prefix("--suite=")
	var started := Time.get_ticks_msec()
	print("\n=== THE LAST SIGNAL - headless tests (Godot %s) ===" % Engine.get_version_info().string)
	for path: String in SUITES:
		if not filter.is_empty() and not path.get_file().contains(filter):
			continue
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			record(false, "could not load suite %s (see script errors above)" % path)
			continue
		var suite: Object = script.new()
		suite.set("tree", self)
		suite.set("runner", self)
		print("\n[%s]" % path.get_file())
		for method in suite.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			suite.set("current_test", "%s.%s" % [path.get_file().get_basename(), method_name])
			var before := _failed.size()
			await suite.call(method_name)
			print("  %s %s" % ["ok  " if _failed.size() == before else "FAIL", method_name])
	Engine.time_scale = 1.0
	paused = false
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("\n=== %d checks passed, %d failed (%.1f s real time) ===" % [_passed, _failed.size(), elapsed])
	for message in _failed:
		print("  FAILED: ", message)
	quit(1 if not _failed.is_empty() else 0)
