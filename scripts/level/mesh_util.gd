@tool
class_name MeshUtil
extends RefCounted
## Small procedural-mesh helpers shared by the station builder and props.
##
## Boxes are emitted as non-indexed triangles with world-space UVs (in metres),
## so textures tile continuously across neighbouring boxes. Winding is clockwise
## when seen from the front, matching Godot's front-face convention.

## For each face: [normal, u (right), v (up)] with u x v = normal.
const FACES := [
	[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
]


## Appends an axis-aligned box to a SurfaceTool that has begun PRIMITIVE_TRIANGLES.
static func add_box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color = Color.WHITE) -> void:
	var half := size * 0.5
	for face: Array in FACES:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var hn := absf(half.dot(n))
		var hu := absf(half.dot(u))
		var hv := absf(half.dot(v))
		var c := center + n * hn
		var p0 := c - u * hu + v * hv
		var p1 := c + u * hu + v * hv
		var p2 := c + u * hu - v * hv
		var p3 := c - u * hu - v * hv
		for p: Vector3 in [p0, p1, p2, p0, p2, p3]:
			st.set_color(color)
			st.set_normal(n)
			st.set_uv(Vector2(p.dot(u), -p.dot(v)))
			st.add_vertex(p)


## Builds a single mesh from a list of [center, size] pairs (one draw call).
static func boxes_to_mesh(boxes: Array, material: Material, color: Color = Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box: Array in boxes:
		add_box(st, box[0], box[1], color)
	var mesh := st.commit()
	if material != null and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material)
	return mesh
