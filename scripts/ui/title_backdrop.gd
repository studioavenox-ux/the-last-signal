extends Control
## Animated title background: falling monsoon rain and a pulsing red railway signal.
## Pure 2D drawing; no textures or shaders.

const DROP_COUNT := 140

var _drops: Array[Vector3] = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in DROP_COUNT:
		_drops.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.7, 1.3)))


func _process(delta: float) -> void:
	_time += delta
	for i in _drops.size():
		var d := _drops[i]
		d.y += delta * 1.4 * d.z
		if d.y > 1.05:
			d.y = -0.05
			d.x = fposmod(d.x + 0.37, 1.0)
		_drops[i] = d
	queue_redraw()


func _draw() -> void:
	var s := size
	for d in _drops:
		var p := Vector2(d.x * s.x, d.y * s.y)
		draw_line(p, p + Vector2(-3.0, 22.0) * d.z, Color(0.62, 0.7, 0.85, 0.22), 1.5)
	# Signal post and head.
	var c := Vector2(s.x * 0.78, s.y * 0.38)
	draw_rect(Rect2(c.x - 7.0, c.y + 70.0, 14.0, s.y), Color(0.11, 0.12, 0.15))
	draw_rect(Rect2(c.x - 40.0, c.y - 90.0, 80.0, 180.0), Color(0.07, 0.08, 0.1))
	draw_circle(c + Vector2(0, -50.0), 20.0, Color(0.06, 0.16, 0.1))
	draw_circle(c, 20.0, Color(0.18, 0.15, 0.05))
	var pulse := 0.65 + 0.35 * sin(_time * 2.2)
	var lamp := c + Vector2(0, 50.0)
	for i in 7:
		draw_circle(lamp, 24.0 + i * 16.0, Color(1.0, 0.18, 0.08, 0.05 * pulse))
	draw_circle(lamp, 21.0, Color(1.0, 0.26, 0.12, 0.35 + 0.65 * pulse))
