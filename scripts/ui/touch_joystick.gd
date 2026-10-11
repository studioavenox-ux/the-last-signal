extends Control
## Single-finger analogue stick; separate from keyboard input.

var finger := -1
var value := Vector2.ZERO
var center := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	center = size * 0.5
	resized.connect(_on_resized)


func _on_resized() -> void:
	center = size * 0.5
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			set_stick(event.position)
			accept_event()
		elif not event.pressed and event.index == finger:
			finger = -1
			value = Vector2.ZERO
			queue_redraw()
			accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		set_stick(event.position)
		accept_event()


func set_stick(point: Vector2) -> void:
	value = ((point - center) / (minf(size.x, size.y) * 0.37)).limit_length(1.0)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.37
	draw_circle(center, radius, Color(0.03, 0.11, 0.14, 0.5))
	draw_arc(center, radius, 0, TAU, 48, Color(0.4, 0.75, 0.74, 0.68), 2.0)
	draw_circle(center + value * radius, radius * 0.38, Color(0.94, 0.63, 0.24, 0.77))


func reset() -> void:
	finger = -1
	value = Vector2.ZERO
	queue_redraw()
