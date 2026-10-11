@tool
class_name StationBuilder
extends Node3D
## Builds Raatpur Junction's static blockout geometry from code.
##
## Layout (metres, +X east, -Z north, floor at y = 0):
##   Entrance hall      X -6..6     Z -8..2     (entrance doors on the south wall)
##   Waiting hall       X -7..7     Z -18..-8   (Platform 3 gate on the north wall)
##   Maintenance corr.  X -15..-7   Z -13..-11  (door in the waiting hall's west wall)
##   Electrical room    X -21..-15  Z -15..-9   (breaker panel on the west wall)
##   Platform 3         X -10..10   Z -26..-18  (tracks beyond, Z -34..-26)
##
## Geometry is merged per room and per material (few draw calls, and each mesh is
## only touched by its room's lights). Colliders are plain boxes on layer 1 "world".
## Runs in the editor (@tool) for preview; generated nodes are never saved.

const WALL_T := 0.2
const DADO_H := 1.2
const HALL_H := 4.5
const CORRIDOR_H := 2.8
const ELECTRICAL_H := 3.2
const GENERATED_NAME := "Generated"

## Rebuild the preview in the editor after changing the code.
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if value and is_inside_tree():
			build()

var _materials: Dictionary = {}
var _rooms: Dictionary = {}
var _root: Node3D


func _ready() -> void:
	build()


func build() -> void:
	_clear()
	_rooms.clear()
	_create_materials()
	_root = Node3D.new()
	_root.name = GENERATED_NAME
	add_child(_root)
	_build_entrance_hall()
	_build_waiting_hall()
	_build_corridor()
	_build_electrical_room()
	_build_platform()
	_commit()
	_add_signs()


## Returns the generated StaticBody3D colliders (used by tests).
func get_collision_bodies() -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	if _root == null:
		return result
	for node in _root.find_children("*", "StaticBody3D", true, false):
		result.append(node as StaticBody3D)
	return result


# --- Rooms ---------------------------------------------------------------------


func _build_entrance_hall() -> void:
	var r := &"entrance"
	_box(r, &"floor_tile", Vector3(0, -0.1, -3), Vector3(12.4, 0.2, 10.4))
	_box(r, &"ceiling", Vector3(0, HALL_H + 0.1, -3), Vector3(12.4, 0.2, 10.4), false)
	_wall_x(r, 2.0, -6.1, 6.1, HALL_H, [[0.0, 2.4, 2.6]])
	_wall_z(r, -6.0, -8.0, 2.0, HALL_H)
	_wall_z(r, 6.0, -8.0, 2.0, HALL_H)
	# North wall is shared with the waiting hall; archway 3.0 m wide, 3.2 m high.
	_wall_x(r, -8.0, -7.1, 7.1, HALL_H, [[0.0, 3.0, 3.2]])
	# Booking office counter with dark glass above.
	_box(r, &"wood", Vector3(5.3, 0.55, -3.5), Vector3(1.2, 1.1, 5.0))
	_box(r, &"wood", Vector3(5.25, 1.125, -3.5), Vector3(1.4, 0.05, 5.2), false)
	_box(r, &"glass", Vector3(5.86, 1.8, -3.5), Vector3(0.05, 1.2, 4.6), false)
	_bench_z(r, Vector3(-5.45, 0, -1.9), 2.4, 1.0)
	_bench_z(r, Vector3(-5.45, 0, -5.6), 2.4, 1.0)
	# Abandoned luggage and a parcel crate.
	_box(r, &"wood", Vector3(-3.4, 0.3, 0.9), Vector3(0.9, 0.6, 0.6))
	_box(r, &"metal", Vector3(2.9, 0.35, -6.9), Vector3(0.5, 0.7, 0.35))


func _build_waiting_hall() -> void:
	var r := &"waiting"
	_box(r, &"floor_tile", Vector3(0, -0.1, -13), Vector3(14.4, 0.2, 10.4))
	_box(r, &"ceiling", Vector3(0, HALL_H + 0.1, -13), Vector3(14.4, 0.2, 10.4), false)
	_wall_z(r, -7.0, -18.0, -8.0, HALL_H, [[-12.0, 1.2, 2.2]])
	_wall_z(r, 7.0, -18.0, -8.0, HALL_H)
	# North wall faces the platform and spans its full width; Platform 3 gate opening.
	_wall_x(r, -18.0, -10.1, 10.1, HALL_H + 0.2, [[0.0, 2.4, 2.6]])
	_bench_x(r, Vector3(-3.5, 0, -11.0), 2.4, 1.0)
	_bench_x(r, Vector3(3.5, 0, -11.0), 2.4, 1.0)
	_bench_x(r, Vector3(-3.5, 0, -14.5), 2.4, -1.0)
	_bench_x(r, Vector3(3.5, 0, -14.5), 2.4, -1.0)
	_box(r, &"plaster", Vector3(-3.5, HALL_H * 0.5, -16.6), Vector3(0.5, HALL_H, 0.5))
	_box(r, &"plaster", Vector3(3.5, HALL_H * 0.5, -16.6), Vector3(0.5, HALL_H, 0.5))
	# Drinking-water cooler.
	_box(r, &"metal", Vector3(6.55, 0.6, -9.0), Vector3(0.5, 1.2, 0.5))


func _build_corridor() -> void:
	var r := &"corridor"
	_box(r, &"floor_concrete", Vector3(-11.0, -0.1, -12.0), Vector3(8.2, 0.2, 2.4))
	_box(r, &"ceiling", Vector3(-11.0, CORRIDOR_H + 0.1, -12.0), Vector3(8.2, 0.2, 2.4), false)
	_wall_x(r, -13.0, -15.0, -7.0, CORRIDOR_H, [], &"concrete_wall", &"dado")
	_wall_x(r, -11.0, -15.0, -7.0, CORRIDOR_H, [], &"concrete_wall", &"dado")
	# Pipes and a cable tray along the ceiling.
	_box(r, &"metal", Vector3(-11.0, 2.55, -12.72), Vector3(8.0, 0.12, 0.12), false)
	_box(r, &"metal", Vector3(-11.0, 2.38, -12.72), Vector3(8.0, 0.08, 0.08), false)
	_box(r, &"metal", Vector3(-11.0, 2.62, -11.32), Vector3(8.0, 0.05, 0.3), false)
	_box(r, &"metal", Vector3(-13.6, 1.3, -11.16), Vector3(0.5, 0.7, 0.12))


func _build_electrical_room() -> void:
	var r := &"electrical"
	_box(r, &"floor_concrete", Vector3(-18.0, -0.1, -12.0), Vector3(6.4, 0.2, 6.4))
	_box(r, &"ceiling", Vector3(-18.0, ELECTRICAL_H + 0.1, -12.0), Vector3(6.4, 0.2, 6.4), false)
	_wall_z(r, -15.0, -15.0, -9.0, ELECTRICAL_H, [[-12.0, 2.0, CORRIDOR_H]], &"concrete_wall", &"dado")
	_wall_z(r, -21.0, -15.0, -9.0, ELECTRICAL_H, [], &"concrete_wall", &"dado")
	_wall_x(r, -15.0, -21.1, -14.9, ELECTRICAL_H, [], &"concrete_wall", &"dado")
	_wall_x(r, -9.0, -21.1, -14.9, ELECTRICAL_H, [], &"concrete_wall", &"dado")
	# Desk, cabinets and a cable tray feeding the breaker panel.
	_box(r, &"wood", Vector3(-17.2, 0.77, -9.45), Vector3(1.8, 0.06, 0.7), false)
	_box(r, &"metal", Vector3(-17.2, 0.37, -9.45), Vector3(1.7, 0.74, 0.6))
	_box(r, &"metal", Vector3(-20.55, 1.0, -9.6), Vector3(0.7, 2.0, 0.8))
	_box(r, &"metal", Vector3(-15.6, 0.9, -14.55), Vector3(0.8, 1.8, 0.5))
	_box(r, &"metal", Vector3(-19.4, 2.95, -12.0), Vector3(3.0, 0.06, 0.4), false)


func _build_platform() -> void:
	var r := &"platform"
	# Platform slab; its north face is the platform wall seen from the tracks.
	_box(r, &"platform", Vector3(0, -0.65, -22.0), Vector3(20.4, 1.3, 8.0))
	_box(r, &"concrete_wall", Vector3(0, 0.01, -25.8), Vector3(20.4, 0.02, 0.4), false)
	_box(r, &"yellow", Vector3(0, 0.012, -25.3), Vector3(20.4, 0.024, 0.14), false)
	# Canopy roof and pillars.
	_box(r, &"metal", Vector3(0, 4.76, -22.3), Vector3(21.0, 0.12, 9.4), false)
	for x: float in [-6.0, 0.0, 6.0]:
		_box(r, &"metal", Vector3(x, 2.35, -24.6), Vector3(0.22, 4.7, 0.22))
	_wall_z(r, -10.0, -26.0, -18.0, 3.0, [], &"concrete_wall", &"concrete_wall")
	_wall_z(r, 10.0, -26.0, -18.0, 3.0, [], &"concrete_wall", &"concrete_wall")
	# Invisible safety barrier at the platform edge (no falling onto the tracks).
	_collider(r, Vector3(0, 1.5, -25.75), Vector3(20.0, 3.0, 0.2))
	# Benches face the gate so Kabir's phone is visible (and reachable) on arrival.
	_bench_x(r, Vector3(4.0, 0, -20.5), 2.4, 1.0)
	_bench_x(r, Vector3(-4.5, 0, -20.5), 2.4, 1.0)
	# Track bed: ballast, concrete sleepers and broad-gauge rails (1.676 m apart).
	_box(r, &"ballast", Vector3(0, -1.35, -30.0), Vector3(26.0, 0.1, 8.0), false)
	var x := -12.6
	while x <= 12.6:
		_box(r, &"sleeper", Vector3(x, -1.24, -30.0), Vector3(0.26, 0.12, 2.7), false)
		x += 0.65
	for z: float in [-29.162, -30.838]:
		_box(r, &"rail", Vector3(0, -1.105, z), Vector3(26.0, 0.15, 0.08), false)
	_box(r, &"concrete_wall", Vector3(0, 1.0, -34.2), Vector3(26.0, 5.0, 0.4), false)


func _add_signs() -> void:
	var black := Color(0.06, 0.06, 0.06)
	var white := Color(0.92, 0.92, 0.88)
	_sign("RAATPUR JUNCTION", Vector3(0, 3.55, 1.86), 180.0, black, 72, &"sign_yellow", Vector2(4.8, 0.75))
	_sign("WAITING HALL  -  PLATFORMS", Vector3(0, 3.8, -7.86), 0.0, white, 48, &"sign_blue", Vector2(4.4, 0.5))
	_sign("BOOKING OFFICE", Vector3(5.83, 2.7, -3.5), -90.0, white, 44, &"sign_blue", Vector2(2.8, 0.45))
	_sign("MAINTENANCE\nSTAFF ONLY", Vector3(-6.86, 2.65, -12.0), 90.0, white, 36, &"sign_blue", Vector2(1.7, 0.6))
	# Hangs from the corridor ceiling, facing players walking west towards the room.
	_sign(
		"ELECTRICAL ROOM\nDANGER 440 V",
		Vector3(-14.7, 2.45, -12.0),
		90.0,
		Color(1, 0.85, 0.2),
		26,
		&"trim",
		Vector2(1.3, 0.5),
		true
	)
	_sign("RAATPUR JN.", Vector3(-6.0, 2.4, -18.14), 180.0, black, 72, &"sign_yellow", Vector2(3.2, 0.7))
	_sign("3", Vector3(-3.0, 3.6, -22.0), 0.0, black, 120, &"sign_yellow", Vector2(0.8, 0.8), true)


# --- Building blocks -----------------------------------------------------------


func _room(room: StringName) -> Dictionary:
	if not _rooms.has(room):
		_rooms[room] = {"boxes": {}, "colliders": []}
	return _rooms[room]


func _box(room: StringName, mat: StringName, center: Vector3, size: Vector3, collide: bool = true) -> void:
	var data := _room(room)
	var boxes: Dictionary = data["boxes"]
	if not boxes.has(mat):
		boxes[mat] = []
	(boxes[mat] as Array).append([center, size])
	if collide:
		(data["colliders"] as Array).append([center, size])


func _collider(room: StringName, center: Vector3, size: Vector3) -> void:
	(_room(room)["colliders"] as Array).append([center, size])


## Wall running along X at depth z. Openings: [center_x, width, height].
func _wall_x(
	room: StringName,
	z: float,
	x0: float,
	x1: float,
	height: float,
	openings: Array = [],
	upper: StringName = &"plaster",
	lower: StringName = &"dado"
) -> void:
	for span: Array in _solid_spans(x0, x1, openings):
		_wall_piece(room, Vector2(span[0], span[1]), z, 0.0, height, true, upper, lower)
	for o: Array in openings:
		_wall_piece(room, Vector2(o[0] - o[1] * 0.5, o[0] + o[1] * 0.5), z, o[2], height, true, upper, lower)


## Wall running along Z at x. Openings: [center_z, width, height].
func _wall_z(
	room: StringName,
	x: float,
	z0: float,
	z1: float,
	height: float,
	openings: Array = [],
	upper: StringName = &"plaster",
	lower: StringName = &"dado"
) -> void:
	for span: Array in _solid_spans(z0, z1, openings):
		_wall_piece(room, Vector2(span[0], span[1]), x, 0.0, height, false, upper, lower)
	for o: Array in openings:
		_wall_piece(room, Vector2(o[0] - o[1] * 0.5, o[0] + o[1] * 0.5), x, o[2], height, false, upper, lower)


## One wall slab from y0 to y1, split into a painted dado band and plaster above.
func _wall_piece(
	room: StringName,
	span: Vector2,
	depth: float,
	y0: float,
	y1: float,
	along_x: bool,
	upper: StringName,
	lower: StringName
) -> void:
	if span.y - span.x <= 0.001 or y1 - y0 <= 0.001:
		return
	var mid := (span.x + span.y) * 0.5
	var length := span.y - span.x
	var bands: Array = []
	if y0 < DADO_H:
		bands.append([y0, minf(y1, DADO_H), lower])
	if y1 > DADO_H:
		bands.append([maxf(y0, DADO_H), y1, upper])
	for band: Array in bands:
		var h: float = band[1] - band[0]
		if h <= 0.001:
			continue
		var cy: float = (band[0] + band[1]) * 0.5
		if along_x:
			_box(room, band[2], Vector3(mid, cy, depth), Vector3(length, h, WALL_T))
		else:
			_box(room, band[2], Vector3(depth, cy, mid), Vector3(WALL_T, h, length))


static func _solid_spans(a: float, b: float, openings: Array) -> Array:
	var sorted := openings.duplicate()
	sorted.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var spans: Array = []
	var cursor := a
	for o: Array in sorted:
		var oa: float = o[0] - o[1] * 0.5
		var ob: float = o[0] + o[1] * 0.5
		if oa > cursor:
			spans.append([cursor, oa])
		cursor = maxf(cursor, ob)
	if cursor < b:
		spans.append([cursor, b])
	return spans


## Bench with its long axis along X; facing = +1 faces +Z (south), -1 faces -Z.
func _bench_x(room: StringName, base: Vector3, length: float, facing: float) -> void:
	_box(room, &"wood", base + Vector3(0, 0.45, 0), Vector3(length, 0.08, 0.5))
	_box(room, &"wood", base + Vector3(0, 0.78, -0.22 * facing), Vector3(length, 0.45, 0.06))
	for dx: float in [-length * 0.4, length * 0.4]:
		_box(room, &"metal", base + Vector3(dx, 0.205, 0), Vector3(0.06, 0.41, 0.42), false)


## Bench with its long axis along Z; facing = +1 faces +X (east), -1 faces -X.
func _bench_z(room: StringName, base: Vector3, length: float, facing: float) -> void:
	_box(room, &"wood", base + Vector3(0, 0.45, 0), Vector3(0.5, 0.08, length))
	_box(room, &"wood", base + Vector3(-0.22 * facing, 0.78, 0), Vector3(0.06, 0.45, length))
	for dz: float in [-length * 0.4, length * 0.4]:
		_box(room, &"metal", base + Vector3(0, 0.205, dz), Vector3(0.42, 0.41, 0.06), false)


## Unshaded sign text on a board. rot_y must be a multiple of 90 degrees.
## Wall signs put the board just behind [param pos]; hanging signs get text on both faces.
func _sign(
	text: String,
	pos: Vector3,
	rot_y: float,
	color: Color,
	font_size: int,
	board_mat: StringName,
	board_size: Vector2,
	hanging: bool = false
) -> void:
	var forward := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3.BACK
	var depth := 0.06
	var size := Vector3(board_size.x, board_size.y, depth)
	if absf(forward.x) > 0.5:
		size = Vector3(depth, board_size.y, board_size.x)
	var board_center := pos if hanging else pos - forward * (depth * 0.5 + 0.01)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = MeshUtil.boxes_to_mesh([[board_center, size]], _materials[board_mat])
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mesh_instance)
	var sides: Array = [1.0, -1.0] if hanging else [1.0]
	for side: float in sides:
		var label := Label3D.new()
		label.text = text
		label.font_size = font_size
		label.pixel_size = 0.005
		label.modulate = color
		label.outline_size = 0
		label.shaded = false
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = (board_center + forward * side * (depth * 0.5 + 0.005)) if hanging else pos
		label.rotation_degrees = Vector3(0, rot_y + (0.0 if side > 0.0 else 180.0), 0)
		_root.add_child(label)


func _commit() -> void:
	var with_collision := not Engine.is_editor_hint()
	for room: StringName in _rooms.keys():
		var data: Dictionary = _rooms[room]
		var room_node := Node3D.new()
		room_node.name = String(room).capitalize()
		_root.add_child(room_node)
		var boxes: Dictionary = data["boxes"]
		for mat: StringName in boxes.keys():
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for box: Array in boxes[mat]:
				MeshUtil.add_box(st, box[0], box[1], _tint_for(box[0]))
			var mesh := st.commit()
			mesh.surface_set_material(0, _materials[mat])
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.name = String(mat)
			mesh_instance.mesh = mesh
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			room_node.add_child(mesh_instance)
		var colliders: Array = data["colliders"]
		if with_collision and not colliders.is_empty():
			var body := StaticBody3D.new()
			body.name = "Collision"
			body.collision_layer = 1
			body.collision_mask = 0
			room_node.add_child(body)
			for c: Array in colliders:
				var shape := BoxShape3D.new()
				shape.size = c[1]
				var cs := CollisionShape3D.new()
				cs.shape = shape
				cs.position = c[0]
				body.add_child(cs)


## Deterministic subtle brightness variation per box (cheap visual noise).
static func _tint_for(center: Vector3) -> Color:
	var h := fposmod(sin(center.x * 12.9898 + center.y * 78.233 + center.z * 37.719) * 43758.5453, 1.0)
	var v := 0.86 + 0.14 * h
	return Color(v, v, v)


func _clear() -> void:
	var old := get_node_or_null(GENERATED_NAME)
	if old != null:
		remove_child(old)
		old.queue_free()
	_root = null


func _create_materials() -> void:
	if not _materials.is_empty():
		return
	var tiles := ProceduralTextures.tiles()
	var noise := ProceduralTextures.noise()
	var grit := ProceduralTextures.noise(128, 16, 0.6, 11)
	_materials = {
		&"floor_tile": ProceduralTextures.material(Color(0.62, 0.6, 0.55), tiles, 1.2),
		&"floor_concrete": ProceduralTextures.material(Color(0.46, 0.46, 0.45), noise, 2.0),
		&"platform": ProceduralTextures.material(Color(0.52, 0.47, 0.42), noise, 2.5),
		&"plaster": ProceduralTextures.material(Color(0.8, 0.76, 0.63), noise, 3.0),
		&"dado": ProceduralTextures.material(Color(0.17, 0.32, 0.29), noise, 2.0),
		&"concrete_wall": ProceduralTextures.material(Color(0.44, 0.44, 0.43), noise, 2.0),
		&"ceiling": ProceduralTextures.material(Color(0.32, 0.32, 0.33), noise, 3.0),
		&"wood": ProceduralTextures.material(Color(0.4, 0.25, 0.14), noise, 1.0, 0.75),
		&"metal": ProceduralTextures.material(Color(0.3, 0.32, 0.34), null, 1.0, 0.55, 0.5),
		&"rail": ProceduralTextures.material(Color(0.55, 0.55, 0.57), null, 1.0, 0.35, 0.85),
		&"sleeper": ProceduralTextures.material(Color(0.4, 0.39, 0.37), noise, 1.0),
		&"ballast": ProceduralTextures.material(Color(0.28, 0.27, 0.26), grit, 0.8),
		&"yellow": ProceduralTextures.material(Color(0.86, 0.7, 0.1)),
		&"glass": ProceduralTextures.material(Color(0.05, 0.07, 0.09), null, 1.0, 0.1, 0.3),
		&"sign_yellow": ProceduralTextures.material(Color(0.9, 0.74, 0.12), null, 1.0, 0.6),
		&"sign_blue": ProceduralTextures.material(Color(0.08, 0.17, 0.38), null, 1.0, 0.6),
		&"trim": ProceduralTextures.material(Color(0.1, 0.1, 0.1)),
	}
