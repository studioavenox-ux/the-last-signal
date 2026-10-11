class_name SequenceLock
extends RefCounted
## Pure puzzle logic: inputs must arrive in a specific order.
##
## No nodes, no scenes - so it is trivially unit-testable (see tests/).
## A wrong input counts a mistake and clears progress.

enum Result { PROGRESS, MISTAKE, SOLVED, IGNORED }

var solution: Array[StringName] = []
var entered: Array[StringName] = []
var mistakes: int = 0
var solved: bool = false


func _init(p_solution: Array[StringName] = []) -> void:
	solution = p_solution.duplicate()


func press(id: StringName) -> Result:
	if solved or solution.is_empty() or entered.has(id):
		return Result.IGNORED
	if id != solution[entered.size()]:
		mistakes += 1
		entered.clear()
		return Result.MISTAKE
	entered.append(id)
	if entered.size() == solution.size():
		solved = true
		return Result.SOLVED
	return Result.PROGRESS


func reset_progress() -> void:
	entered.clear()


func get_progress() -> int:
	return entered.size()
