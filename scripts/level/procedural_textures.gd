@tool
class_name ProceduralTextures
extends RefCounted
## Tiny tileable greyscale textures generated at runtime (no image assets needed).
##
## Materials tint them with albedo_color. Kept at 128 px with mipmaps so they are
## cheap in memory and bandwidth on low-end Android GPUs.

static var _cache: Dictionary = {}


## Square floor/wall tiles with darker grout lines.
static func tiles(px: int = 128, count: int = 2, grout_px: int = 3, seed_value: int = 7) -> Texture2D:
	var key := "tiles_%d_%d_%d_%d" % [px, count, grout_px, seed_value]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(px, px, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cell: int = floori(px / float(count))
	var shades := PackedFloat32Array()
	for i in count * count:
		shades.append(rng.randf_range(0.8, 1.0))
	for y in px:
		for x in px:
			var lx := x % cell
			var ly := y % cell
			var v := 0.42
			if lx >= grout_px and ly >= grout_px:
				v = shades[floori(y / float(cell)) * count + floori(x / float(cell))] * (0.93 + rng.randf() * 0.07)
			img.set_pixel(x, y, Color(v, v, v))
	return _finish(key, img)


## Smooth value noise (tileable) for concrete, plaster and grime.
static func noise(px: int = 128, grid: int = 8, strength: float = 0.35, seed_value: int = 3) -> Texture2D:
	var key := "noise_%d_%d_%.2f_%d" % [px, grid, strength, seed_value]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lattice := PackedFloat32Array()
	for i in grid * grid:
		lattice.append(rng.randf())
	var img := Image.create_empty(px, px, false, Image.FORMAT_RGB8)
	for y in px:
		for x in px:
			var gx := float(x) / px * grid
			var gy := float(y) / px * grid
			var x0 := int(gx) % grid
			var y0 := int(gy) % grid
			var x1 := (x0 + 1) % grid
			var y1 := (y0 + 1) % grid
			var fx := smoothstep(0.0, 1.0, gx - floorf(gx))
			var fy := smoothstep(0.0, 1.0, gy - floorf(gy))
			var top := lerpf(lattice[y0 * grid + x0], lattice[y0 * grid + x1], fx)
			var bottom := lerpf(lattice[y1 * grid + x0], lattice[y1 * grid + x1], fx)
			var value := lerpf(top, bottom, fy) * 0.8 + rng.randf() * 0.2
			var v := 1.0 - strength + strength * value
			img.set_pixel(x, y, Color(v, v, v))
	return _finish(key, img)


static func _finish(key: String, img: Image) -> Texture2D:
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Convenience: a vertex-colour-aware StandardMaterial3D for blockout geometry.
static func material(
	color: Color,
	texture: Texture2D = null,
	metres_per_repeat: float = 1.0,
	roughness: float = 0.9,
	metallic: float = 0.0
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.vertex_color_use_as_albedo = true
	if texture != null:
		mat.albedo_texture = texture
		var s := 1.0 / maxf(metres_per_repeat, 0.01)
		mat.uv1_scale = Vector3(s, s, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat
