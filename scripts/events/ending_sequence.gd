class_name EndingSequence
extends Node
## Prototype ending: Kabir's phone reveals the message was sent three years ago,
## the clock strikes midnight, a train horn sounds and the platform signal turns
## green - "the last signal". Then the end screen.

signal finished

@export var station_clock_path: NodePath
@export var railway_signal_path: NodePath
@export var phone_path: NodePath

var has_started: bool = false


func play(player: PlayerController) -> void:
	if has_started:
		return
	has_started = true
	GameState.set_flag(&"ending_started")
	GameState.set_objective(StoryText.get_objective(&"end"))
	var clock := get_node_or_null(station_clock_path) as StationClock
	var rail_signal := get_node_or_null(railway_signal_path) as RailwaySignal
	var phone := get_node_or_null(phone_path) as StoryObject
	if player != null:
		player.movement_enabled = false
		player.interaction_enabled = false
	if phone != null:
		phone.stop_glow()
	AudioManager.play(&"phone_buzz", -2.0)
	StoryText.say_lines(&"phone_found")
	await Sequence.wait(self, 11.0)

	# Midnight.
	if clock != null:
		clock.set_time(0, 0, 0.0)
	AudioManager.play(&"clock_bell", 0.0)
	await Sequence.wait(self, 1.6)
	AudioManager.play(&"train_horn", -2.0)
	if rail_signal != null:
		rail_signal.set_aspect(&"yellow")
		if player != null:
			_turn_player_towards(player, rail_signal.global_position + Vector3.UP * 4.2, 1.6)
	await Sequence.wait(self, 1.8)
	if rail_signal != null:
		rail_signal.set_aspect(&"green")
	AudioManager.play_announcement(&"announce_last_train")
	StoryText.say_lines(&"midnight")
	await Sequence.wait(self, 5.0)
	GameState.set_flag(&"game_completed")
	finished.emit()
	GameState.end_game()


func _turn_player_towards(player: PlayerController, target: Vector3, duration: float) -> void:
	var dir := target - player.camera.global_position
	var target_yaw := atan2(-dir.x, -dir.z)
	var current_yaw := player.rotation.y
	target_yaw = current_yaw + wrapf(target_yaw - current_yaw, -PI, PI)
	var target_pitch := clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -1.2, 1.2)
	player.look_enabled = false
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "rotation:y", target_yaw, duration)
	tween.tween_method(player.set_pitch, player.get_pitch(), target_pitch, duration)
	tween.chain().tween_callback(func() -> void: player.look_enabled = true)
