class_name UiUtil
extends RefCounted
## Shared UI helpers.


## Returns extra margins (left, top, right, bottom) in viewport units so UI stays
## clear of notches / camera cut-outs on phones. Zero on desktop.
static func safe_area_margins(viewport: Viewport) -> Vector4:
	if viewport == null or DisplayServer.get_name() == "headless":
		return Vector4.ZERO
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Vector4.ZERO
	var visible_size := viewport.get_visible_rect().size
	var scale := visible_size / window_size
	var window_pos := Vector2(DisplayServer.window_get_position())
	var left := maxf(0.0, safe.position.x - window_pos.x) * scale.x
	var top := maxf(0.0, safe.position.y - window_pos.y) * scale.y
	var right := maxf(0.0, (window_pos.x + window_size.x) - (safe.position.x + safe.size.x)) * scale.x
	var bottom := maxf(0.0, (window_pos.y + window_size.y) - (safe.position.y + safe.size.y)) * scale.y
	# Desktop monitors report the work area (taskbars) - ignore implausible values.
	if left + right > visible_size.x * 0.3 or top + bottom > visible_size.y * 0.3:
		return Vector4.ZERO
	return Vector4(left, top, right, bottom)
