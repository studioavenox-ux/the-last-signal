extends RefCounted
## Low-poly station assembled from primitive meshes and box collisions at runtime.
const Interactable = preload("res://scripts/interactable.gd")

var root: Node3D
var materials := {}


func build(scene_root: Node3D) -> Dictionary:
	root = Node3D.new()
	root.name = "NirvaHalt"
	scene_root.add_child(root)
	materials = {
		"floor": mat(Color(0.13, 0.19, 0.20)),
		"wall": mat(Color(0.19, 0.25, 0.25)),
		"stripe": mat(Color(0.28, 0.36, 0.34)),
		"dark": mat(Color(0.035, 0.07, 0.085)),
		"metal": mat(Color(0.26, 0.32, 0.32)),
		"rust": mat(Color(0.37, 0.22, 0.13)),
		"paper": mat(Color(0.72, 0.62, 0.43)),
		"amber": mat(Color(0.96, 0.55, 0.16), true),
		"teal": mat(Color(0.25, 0.72, 0.69), true),
		"off": mat(Color(0.10, 0.13, 0.13)),
		"glass": mat(Color(0.12, 0.31, 0.34)),
		"water": mat(Color(0.10, 0.24, 0.27))
	}
	# Three tiny deterministic textures add wear without external assets or import dependencies.
	materials["floor"].albedo_texture = grime_texture(31, true)
	materials["wall"].albedo_texture = grime_texture(47, false)
	materials["rust"].albedo_texture = grime_texture(89, false)
	materials["floor"].roughness = 0.53
	materials["water"].roughness = 0.18
	materials["water"].metallic = 0.13
	var env := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.015, 0.039, 0.05)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.32, 0.46, 0.49)
	sky.ambient_light_energy = 0.32
	# Fog is an optional desktop accent; Compatibility/mobile renderers may omit it.
	sky.fog_enabled = not OS.has_feature("mobile")
	sky.fog_light_color = Color(0.07, 0.16, 0.18)
	sky.fog_density = 0.012
	env.environment = sky
	root.add_child(env)

	# Four readable zones: hall in the middle, waiting left, maintenance right, platform ahead.
	box("Concourse floor", Vector3(0, -0.15, 5.5), Vector3(20, 0.3, 11), "floor")
	box("Platform slab", Vector3(-2, -0.15, -6.5), Vector3(16, 0.3, 13), "floor")
	# Keep tracks level with the platform: no step-up trap if a player walks onto them.
	box("Track bed", Vector3(8, -0.15, -6.5), Vector3(4, 0.3, 13), "dark")
	for z in range(-12, 0, 2):
		box("Sleeper", Vector3(8, 0.07, float(z)), Vector3(3.8, 0.13, 0.22), "rust", false)
	for x in [6.55, 9.45]:
		box("Rail", Vector3(x, 0.14, -6.5), Vector3(0.13, 0.18, 13), "metal", false)
	box("Platform end barrier", Vector3(0, 0.8, -12.9), Vector3(20, 1.6, 0.22), "metal")
	box("Track-side boundary", Vector3(9.8, 0.55, -6.5), Vector3(0.3, 1.1, 13), "dark")
	box(
		"Yellow platform edge", Vector3(5.87, 0.012, -6.5), Vector3(0.12, 0.025, 13), "amber", false
	)
	# Wet floor seams and shallow puddles are flat geometry, not particles or shaders.
	for x in range(-8, 9, 4):
		for z in [2.5, 7.5]:
			box(
				"Tile seam", Vector3(float(x), 0.004, z), Vector3(0.025, 0.008, 4.6), "metal", false
			)
	for spot in [[-2.9, 3.4], [1.6, 8.2], [-7.5, -4.2], [-3.5, -7.1]]:
		box(
			"Rain puddle",
			Vector3(spot[0], 0.014, spot[1]),
			Vector3(1.0, 0.013, 0.56),
			"water",
			false
		)
	# Outer walls; platform's track side and open end face the night.
	box("Back wall left", Vector3(-5.6, 1.8, 11), Vector3(8.8, 3.6, 0.4), "wall")
	box("Back wall right", Vector3(5.6, 1.8, 11), Vector3(8.8, 3.6, 0.4), "wall")
	box("Entrance lintel", Vector3(0, 3.0, 11), Vector3(2.4, 1.2, 0.4), "wall")
	box("Exterior landing", Vector3(0, -0.15, 12.0), Vector3(3, 0.3, 2.4), "floor")
	for x in [-9.8, 9.8]:
		box("Side wall", Vector3(x, 1.8, 5.5), Vector3(0.4, 3.6, 11), "wall")
	box("Waiting wall north", Vector3(-5, 1.8, 9), Vector3(0.32, 3.6, 4), "wall")
	box("Waiting wall south", Vector3(-5, 1.8, 2), Vector3(0.32, 3.6, 4), "wall")
	box("Waiting doorway beam", Vector3(-5, 3.05, 5.5), Vector3(0.32, 1.1, 3), "wall")
	box("Maintenance wall north", Vector3(5, 1.8, 9), Vector3(0.32, 3.6, 4), "wall")
	box("Maintenance wall south", Vector3(5, 1.8, 2), Vector3(0.32, 3.6, 4), "wall")
	box("Maintenance doorway beam", Vector3(5, 3.05, 5.5), Vector3(0.32, 1.1, 3), "wall")
	box("Platform wall left", Vector3(-5.575, 1.8, 0), Vector3(8.85, 3.6, 0.35), "wall")
	box("Platform wall right", Vector3(5.575, 1.8, 0), Vector3(8.85, 3.6, 0.35), "wall")
	box("Door lintel", Vector3(0, 3.0, 0), Vector3(4.7, 1.2, 0.35), "wall")
	box("Platform left boundary", Vector3(-9.8, 1.6, -6.5), Vector3(0.4, 3.2, 13), "wall")
	box("Ceiling", Vector3(0, 3.65, 5.5), Vector3(20, 0.15, 11), "dark", false)
	for z in [2.5, 8.5]:
		box("Concourse beam", Vector3(0, 3.4, z), Vector3(20, 0.28, 0.32), "metal", false)
	box("Platform canopy", Vector3(-2, 3.65, -6.5), Vector3(16, 0.14, 13), "dark", false)
	for z in [-3.0, -8.0]:
		box("Canopy pillar", Vector3(-8.4, 1.7, z), Vector3(0.24, 3.4, 0.24), "rust")
		box("Canopy", Vector3(-2, 3.5, z), Vector3(16, 0.16, 0.4), "metal", false)
	# Repeated structural rhythm and broken paint make the same blockout read as a station.
	for z in [1.3, 5.5, 9.6]:
		for x in [-9.55, 9.55]:
			box("Wall pilaster", Vector3(x, 1.8, z), Vector3(0.12, 3.5, 0.32), "stripe", false)
	for x in [-9.53, 9.53]:
		box("Lower wall plaster", Vector3(x, 0.52, 5.5), Vector3(0.04, 0.95, 10), "stripe", false)
	# A barred, rain-dark window is applied to the inside of the solid perimeter wall.
	box("Waiting window", Vector3(-9.53, 2.04, 6.3), Vector3(0.07, 1.08, 1.65), "glass", false)
	for z in [5.85, 6.4, 6.85]:
		box("Window bar", Vector3(-9.48, 2.04, z), Vector3(0.07, 1.1, 0.035), "dark", false)
	box("Window sill", Vector3(-9.42, 1.48, 6.3), Vector3(0.25, 0.1, 1.9), "metal", false)
	box("Conduit", Vector3(9.44, 2.55, 5.5), Vector3(0.08, 0.08, 10), "rust", false)
	for z in [3.0, 5.6, 8.2]:
		box("Relay cable", Vector3(9.4, 2.13, z), Vector3(0.07, 0.85, 0.06), "rust", false)
	# Furniture uses simple silhouettes; decoration has no collision.
	for x in [-9.55, 9.55]:
		box("Wall paint band", Vector3(x, 1.05, 5.5), Vector3(0.025, 0.16, 10), "stripe", false)
	for z in [2.7, 4.2]:
		box("Waiting bench seat", Vector3(-8.0, 0.48, z), Vector3(2.4, 0.14, 0.55), "rust")
		box("Waiting bench back", Vector3(-8.0, 0.85, z + 0.25), Vector3(2.4, 0.78, 0.12), "metal")
		for x in [-8.9, -7.1]:
			box("Bench leg", Vector3(x, 0.22, z), Vector3(0.12, 0.44, 0.12), "dark", false)
	box("Log desk", Vector3(-8, 0.53, 8.2), Vector3(2.2, 1.05, 1.1), "rust")
	box("Ticket counter", Vector3(2.5, 0.5, 7.7), Vector3(1.8, 1.0, 0.95), "rust")
	box("Ticket grille", Vector3(3.65, 2.15, 8.55), Vector3(2.3, 1.2, 0.12), "metal", false)
	for x in [2.9, 3.4, 3.9, 4.4]:
		box("Ticket grille bar", Vector3(x, 2.14, 8.44), Vector3(0.045, 1.18, 0.05), "dark", false)
	for z in [-3.0, -8.0]:
		box("Platform notice", Vector3(-9.55, 2.1, z), Vector3(0.08, 0.8, 1.7), "glass", false)
	label("PLATFORM 03", Vector3(-4.6, 2.6, -3.5), 0.0, Color(0.97, 0.64, 0.23), 32)
	box("Monitor counter", Vector3(-8, 0.57, 1.0), Vector3(2.3, 1.14, 0.95), "metal")
	label("NIRVA HALT  /  PLATFORM 03", Vector3(0, 2.8, 0.23), 0.0, Color(0.95, 0.70, 0.37), 34)
	label("WAITING ROOM", Vector3(-3.5, 2.68, 2.35), 0.0, Color(0.62, 0.8, 0.79), 24)
	label("MAINTENANCE", Vector3(3.5, 2.68, 2.35), 0.0, Color(0.62, 0.8, 0.79), 24)
	var clock := label("11:47", Vector3(0, 2.89, 10.75), PI, Color(0.97, 0.60, 0.25), 44)
	box("Clock housing", Vector3(0, 2.89, 10.86), Vector3(1.9, 0.82, 0.13), "dark", false)
	# Entrance door locks behind Aarav; platform door responds to the puzzle.
	var entrance := object(
		"entrance",
		"entrance",
		"Sealed entrance",
		Vector3(0, 1.15, 10.66),
		Vector3(2.25, 2.3, 0.2),
		"rust"
	)
	var door := object(
		"door",
		"platform",
		"Platform Three gate",
		Vector3(0, 1.18, 0),
		Vector3(2.25, 2.36, 0.22),
		"metal"
	)
	box("Logbook cover", Vector3(-8, 1.085, 8.2), Vector3(0.84, 0.07, 0.62), "paper", false)
	var logbook := object(
		"document",
		"logbook",
		"Station logbook",
		Vector3(-8, 1.14, 8.2),
		Vector3(0.84, 0.08, 0.62),
		"paper"
	)
	box("Screen base", Vector3(-8, 1.46, 1.0), Vector3(1.7, 0.88, 0.22), "dark", false)
	var monitor := object(
		"monitor",
		"security",
		"Security monitor",
		Vector3(-8, 1.46, 0.85),
		Vector3(1.72, 0.94, 0.28),
		"off"
	)
	box("Monitor glass", Vector3(-8, 1.46, 0.69), Vector3(1.5, 0.74, 0.025), "stripe", false)
	var figure_body := box(
		"Feed silhouette", Vector3(-8.2, 1.39, 0.65), Vector3(0.17, 0.34, 0.025), "dark", false
	)
	var figure_head := box(
		"Feed silhouette head", Vector3(-8.2, 1.65, 0.65), Vector3(0.14, 0.14, 0.025), "dark", false
	)
	var screen_text := label(
		"03 / LIVE", Vector3(-7.8, 1.52, 0.64), 0.0, Color(0.43, 0.87, 0.78), 18
	)
	var timetable := object(
		"document",
		"timetable",
		"Departure board",
		Vector3(-8, 1.9, 10.45),
		Vector3(1.9, 0.9, 0.14),
		"paper"
	)
	label("TRAIN 03 / 11:59", Vector3(-8, 1.9, 10.34), PI, Color(0.14, 0.20, 0.19), 20)
	var transcript := object(
		"document",
		"transcript",
		"Operator transcript",
		Vector3(2.5, 1.05, 7.7),
		Vector3(0.85, 0.08, 0.65),
		"paper"
	)
	var indicators: Array[MeshInstance3D] = []
	# Physical left-to-right switch numbering, but clue order is 3 -> 1 -> 2.
	for i in range(3):
		var z := 8.2 - float(i) * 2.6
		box(
			"Electrical panel %d" % (i + 1),
			Vector3(9.44, 1.45, z),
			Vector3(0.25, 1.1, 1.15),
			"dark",
			false
		)
		var power_switch := object(
			"switch",
			str(i + 1),
			"Switch %d" % (i + 1),
			Vector3(9.21, 1.43, z),
			Vector3(0.3, 0.68, 0.68),
			"rust"
		)
		var indicator := box(
			"Indicator %d" % (i + 1), Vector3(9.01, 1.8, z), Vector3(0.04, 0.11, 0.25), "off", false
		)
		indicators.append(indicator)
		label("%d" % (i + 1), Vector3(8.98, 1.39, z), -PI / 2.0, Color(0.98, 0.81, 0.52), 36)
		power_switch.name = "Switch%d" % (i + 1)
	label(
		"3 : LAMP     1 : BELL     2 : LINE",
		Vector3(7.55, 2.57, 10.68),
		PI,
		Color(0.84, 0.64, 0.35),
		17
	)
	var clue := object(
		"document",
		"maintenance",
		"Maintenance memo",
		Vector3(7.4, 1.15, 9.1),
		Vector3(0.8, 0.07, 0.57),
		"paper"
	)
	box("Memo shelf", Vector3(7.4, 0.95, 9.1), Vector3(1.35, 0.35, 0.75), "metal")
	var phone := object(
		"phone",
		"rohan",
		"Ringing service phone",
		Vector3(-1.8, 0.9, -10.3),
		Vector3(0.55, 0.32, 0.38),
		"amber"
	)
	box("Phone pedestal", Vector3(-1.8, 0.39, -10.3), Vector3(0.9, 0.8, 0.7), "metal")
	box("Signal mast", Vector3(5.25, 1.38, -8.0), Vector3(0.18, 2.75, 0.18), "rust", false)
	box("Signal lens", Vector3(5.25, 2.56, -7.83), Vector3(0.26, 0.26, 0.12), "amber", false)
	box("Warning chevron", Vector3(5.2, 0.04, -6.5), Vector3(0.12, 0.03, 11), "amber", false)
	phone.enabled = false
	box("Override pedestal", Vector3(-4.0, 0.5, -9.1), Vector3(0.92, 1.0, 0.75), "metal")
	var override := object(
		"override",
		"speaker",
		"Emergency announcement cut-off",
		Vector3(-4.0, 1.19, -9.1),
		Vector3(0.65, 0.36, 0.45),
		"rust"
	)
	override.enabled = false
	label("PA / CUT-OFF", Vector3(-4, 1.8, -9.32), 0.0, Color(0.97, 0.64, 0.23), 19)
	var train := Node3D.new()
	train.name = "DistantTrain"
	root.add_child(train)
	train.visible = false
	train.position.z = -16.0
	var old_root := root
	root = train
	box("Train carriage", Vector3(8.1, 1.18, -10.4), Vector3(2.65, 2.4, 3.55), "dark", false)
	box("Train roof", Vector3(8.1, 2.44, -10.4), Vector3(2.82, 0.16, 3.7), "metal", false)
	box("Train waist stripe", Vector3(6.755, 1.0, -10.4), Vector3(0.035, 0.09, 3.5), "rust", false)
	for z in [-11.45, -10.55, -9.65]:
		box(
			"Unlit carriage window",
			Vector3(6.75, 1.76, z),
			Vector3(0.04, 0.56, 0.6),
			"glass",
			false
		)
		box(
			"Window upper rail", Vector3(6.71, 2.06, z), Vector3(0.045, 0.055, 0.67), "metal", false
		)
	for z in [-11.65, -9.25]:
		for x in [7.2, 8.9]:
			box("Train wheel", Vector3(x, 0.14, z), Vector3(0.42, 0.3, 0.22), "rust", false)
	box("Cab glass", Vector3(8.1, 1.86, -8.58), Vector3(1.9, 0.64, 0.07), "glass", false)
	box("Cab number plate", Vector3(8.1, 2.28, -8.55), Vector3(0.72, 0.2, 0.07), "metal", false)
	label("03", Vector3(8.1, 2.29, -8.49), 0.0, Color(0.94, 0.63, 0.24), 18)
	for x in [7.3, 8.9]:
		box("Headlamp", Vector3(x, 1.17, -8.56), Vector3(0.2, 0.2, 0.09), "amber", false)
	root = old_root
	var hall_light := light(Vector3(0, 2.92, 5.5), Color(0.97, 0.59, 0.31), 1.0, 8.0)
	light(Vector3(-7, 2.95, 5.0), Color(0.49, 0.78, 0.71), 0.65, 7.5)
	var power_light := light(Vector3(7, 2.93, 5.4), Color(0.91, 0.47, 0.21), 0.42, 7.5)
	var platform_light := light(Vector3(-2.0, 3.05, -6.9), Color(0.45, 0.78, 0.78), 0.3, 9.0)
	box("Hall lantern", Vector3(0, 3.15, 5.5), Vector3(0.58, 0.15, 0.28), "amber", false)
	box("Waiting lantern", Vector3(-7, 3.15, 5), Vector3(0.58, 0.15, 0.28), "teal", false)
	var relay_lamp := box(
		"Maintenance lantern", Vector3(7, 3.15, 5.4), Vector3(0.58, 0.15, 0.28), "amber", false
	)
	var platform_lamp := box(
		"Platform lantern", Vector3(-2, 3.24, -6.9), Vector3(0.66, 0.16, 0.28), "off", false
	)
	return {
		"door": door,
		"entrance": entrance,
		"logbook": logbook,
		"monitor": monitor,
		"screen_text": screen_text,
		"figure_parts": [figure_body, figure_head],
		"clock": clock,
		"indicators": indicators,
		"phone": phone,
		"timetable": timetable,
		"transcript": transcript,
		"override": override,
		"train": train,
		"hall_light": hall_light,
		"power_light": power_light,
		"platform_light": platform_light,
		"relay_lamp": relay_lamp,
		"platform_lamp": platform_lamp,
		"materials": materials,
		"clue": clue
	}


func mat(color: Color, glowing: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if glowing:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.8
	return material


func box(
	title: String, pos: Vector3, dimensions: Vector3, material_name: String, solid: bool = true
) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	var cube := BoxMesh.new()
	cube.size = dimensions
	mesh.mesh = cube
	mesh.material_override = materials[material_name]
	mesh.position = pos
	root.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.name = title + " collision"
		body.position = pos
		var shape := CollisionShape3D.new()
		var collision_box := BoxShape3D.new()
		collision_box.size = dimensions
		shape.shape = collision_box
		body.add_child(shape)
		root.add_child(body)
	return mesh


func object(
	kind: String,
	key: String,
	caption: String,
	pos: Vector3,
	dimensions: Vector3,
	material_name: String
) -> StaticBody3D:
	var body = Interactable.new()
	body.kind = kind
	body.key = key
	body.caption = caption
	body.name = caption
	body.position = pos
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var collision_box := BoxShape3D.new()
	collision_box.size = dimensions
	shape.shape = collision_box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = dimensions
	mesh.mesh = cube
	mesh.material_override = materials[material_name]
	body.add_child(mesh)
	root.add_child(body)
	return body


func label(text: String, pos: Vector3, angle: float, color: Color, font_size: int) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = font_size
	sign.pixel_size = 0.008
	sign.modulate = color
	sign.position = pos
	sign.rotation.y = angle
	root.add_child(sign)
	return sign


func light(pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var bulb := OmniLight3D.new()
	bulb.position = pos
	bulb.light_color = color
	bulb.light_energy = energy
	bulb.omni_range = radius
	bulb.shadow_enabled = false
	root.add_child(bulb)
	return bulb


func grime_texture(seed: int, tiled: bool) -> ImageTexture:
	# One 64 px image per surface family. No runtime image files or external textures.
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	var random := RandomNumberGenerator.new()
	random.seed = seed
	for y in range(64):
		for x in range(64):
			var shade := random.randf_range(0.72, 0.98)
			if tiled and (x % 16 == 0 or y % 16 == 0):
				shade *= 0.72
			if not tiled and (x + 3 * y) % 43 < 2:
				shade *= 0.82
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
