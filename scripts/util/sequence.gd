class_name Sequence
extends RefCounted
## Helpers for scripted, time-based story sequences.
##
## [code]await Sequence.wait(self, 1.5)[/code] waits using a Tween bound to [param node]:
## - it pauses automatically while the game is paused (reading a note, pause menu);
## - if the node is freed (restart / scene change) the wait never resumes, so
##   sequences cannot touch freed objects.


static func wait(node: Node, seconds: float) -> Signal:
	var tween := node.create_tween()
	tween.tween_interval(maxf(seconds, 0.0))
	return tween.finished
