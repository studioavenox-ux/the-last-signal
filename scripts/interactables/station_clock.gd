class_name StationClock
extends StoryObject
## The station clock: stopped at 11:57 until the power returns, then it runs again.
##
## While stopped, the second hand "twitches" now and then (a small unsettling detail).

signal time_reached(hours: int, minutes: int)

@export var hours: int = 23
@export var minutes: int = 57
@export var seconds: float = 0.0
@export var running: bool = false
## Game seconds per real second while running (story beats can speed it up).
@export var time_scale: float = 1.0
@export var tick_volume_db: float = -16.0

var _twitch_timer: float = 1.5
var _twitching: bool = false

@onready var hour_hand: Node3D = $HourHand
@onready var minute_hand: Node3D = $MinuteHand
@onready var second_hand: Node3D = $SecondHand
@onready var ticks: MeshInstance3D = $Ticks


func _ready() -> void:
	super._ready()
	_build_ticks()
	_update_hands()
	set_process(true)


func _process(delta: float) -> void:
	super._process(delta)
	if running:
		var previous_second := int(seconds)
		var previous_minute := minutes
		seconds += delta * time_scale
		while seconds >= 60.0:
			seconds -= 60.0
			minutes += 1
		while minutes >= 60:
			minutes -= 60
			hours = (hours + 1) % 24
		if int(seconds) != previous_second and tick_volume_db > -60.0:
			AudioManager.play_at(&"clock_tick", global_position, tick_volume_db, 14.0)
		_update_hands()
		if minutes != previous_minute:
			time_reached.emit(hours, minutes)
	else:
		_twitch_timer -= delta
		if _twitch_timer <= 0.0 and not _twitching:
			_twitch_timer = randf_range(1.4, 3.0)
			_twitch()


func start(speed: float = 1.0) -> void:
	time_scale = speed
	running = true


func stop() -> void:
	running = false


func set_time(h: int, m: int, s: float = 0.0) -> void:
	hours = h
	minutes = m
	seconds = s
	_update_hands()


func get_time_text() -> String:
	return "%02d:%02d" % [hours, minutes]


func _update_hands() -> void:
	var s_frac := seconds / 60.0
	var m_frac := (float(minutes) + s_frac) / 60.0
	var h_frac := (float(hours % 12) + m_frac) / 12.0
	# Clockwise when viewed from the front (+Z) is a negative rotation about Z.
	second_hand.rotation.z = -TAU * (floorf(seconds) / 60.0)
	minute_hand.rotation.z = -TAU * m_frac
	hour_hand.rotation.z = -TAU * h_frac


func _twitch() -> void:
	_twitching = true
	var base := second_hand.rotation.z
	var tween := create_tween()
	tween.tween_property(second_hand, "rotation:z", base - TAU / 60.0, 0.05)
	tween.tween_property(second_hand, "rotation:z", base, 0.12)
	tween.tween_callback(func() -> void: _twitching = false)
	AudioManager.play_at(&"clock_tick", global_position, tick_volume_db - 4.0, 10.0)


## Twelve hour marks merged into one mesh (a single draw call).
func _build_ticks() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var dir := Vector3(sin(angle), cos(angle), 0.0)
		var long_mark := i % 3 == 0
		var size := Vector3(0.03, 0.09 if long_mark else 0.05, 0.006)
		var center := dir * (0.38 if long_mark else 0.4)
		# Rotate the mark to point at the centre by building it in a rotated basis.
		_add_oriented_box(st, center, size, Basis(Vector3.BACK, -angle))
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.08)
	mesh.surface_set_material(0, mat)
	ticks.mesh = mesh


static func _add_oriented_box(st: SurfaceTool, center: Vector3, size: Vector3, orientation: Basis) -> void:
	var half := size * 0.5
	for face: Array in MeshUtil.FACES:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var hn := absf(half.dot(n))
		var hu := absf(half.dot(u))
		var hv := absf(half.dot(v))
		var c := n * hn
		var corners := [
			c - u * hu + v * hv,
			c + u * hu + v * hv,
			c + u * hu - v * hv,
			c - u * hu + v * hv,
			c + u * hu - v * hv,
			c - u * hu - v * hv
		]
		for p: Vector3 in corners:
			st.set_normal(orientation * n)
			st.add_vertex(center + orientation * p)
