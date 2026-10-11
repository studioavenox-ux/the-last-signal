extends Control
## Invisible right-side touch look surface. Buttons above it consume their own events.

signal moved(relative: Vector2)
var finger := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			accept_event()
		elif not event.pressed and event.index == finger:
			finger = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		moved.emit(event.relative)
		accept_event()


func reset() -> void:
	finger = -1
