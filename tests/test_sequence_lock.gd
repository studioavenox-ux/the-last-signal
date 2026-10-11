extends "res://tests/test_suite.gd"
## Unit tests for the breaker puzzle's pure logic.

const R := SequenceLock.Result


func _make() -> SequenceLock:
	var solution: Array[StringName] = [&"red", &"yellow", &"green"]
	return SequenceLock.new(solution)


func test_correct_order_solves() -> void:
	var lock := _make()
	check_eq(lock.press(&"red"), R.PROGRESS, "first correct input progresses")
	check_eq(lock.press(&"yellow"), R.PROGRESS, "second correct input progresses")
	check_eq(lock.press(&"green"), R.SOLVED, "third correct input solves")
	check(lock.solved, "solved flag set")
	check_eq(lock.mistakes, 0, "no mistakes recorded")


func test_wrong_input_resets_progress() -> void:
	var lock := _make()
	lock.press(&"red")
	check_eq(lock.press(&"green"), R.MISTAKE, "skipping yellow is a mistake")
	check_eq(lock.get_progress(), 0, "progress cleared after a mistake")
	check_eq(lock.mistakes, 1, "mistake counted")
	check_eq(lock.press(&"yellow"), R.MISTAKE, "starting with yellow is a mistake")
	check_eq(lock.mistakes, 2, "second mistake counted")
	lock.press(&"red")
	lock.press(&"yellow")
	check_eq(lock.press(&"green"), R.SOLVED, "can still solve after mistakes")


func test_repeats_and_after_solve_are_ignored() -> void:
	var lock := _make()
	lock.press(&"red")
	check_eq(lock.press(&"red"), R.IGNORED, "pressing an already-entered input is ignored")
	check_eq(lock.mistakes, 0, "ignored input is not a mistake")
	lock.press(&"yellow")
	lock.press(&"green")
	check_eq(lock.press(&"red"), R.IGNORED, "inputs after solving are ignored")


func test_empty_solution_is_safe() -> void:
	var lock := SequenceLock.new()
	check_eq(lock.press(&"red"), R.IGNORED, "empty lock ignores input instead of crashing")
