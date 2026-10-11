extends "res://tests/test_suite.gd"
## Procedural audio, textures and mesh helpers.


func test_every_sound_generates() -> void:
	var total_ms := 0
	for id: StringName in ProceduralAudio.IDS:
		var t0 := Time.get_ticks_usec()
		var stream := ProceduralAudio.generate(id)
		var ms := floori((Time.get_ticks_usec() - t0) / 1000.0)
		total_ms += ms
		if not check(stream != null, "sound '%s' generated" % id):
			continue
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			check(wav.data.size() > 100, "sound '%s' has audio data" % id)
			check(
				wav.get_length() > 0.01 and wav.get_length() < 10.0,
				"sound '%s' length is sane (%.2fs)" % [id, wav.get_length()]
			)
		elif stream is AudioStreamRandomizer:
			check((stream as AudioStreamRandomizer).streams_count >= 3, "sound '%s' has variations" % id)
	print(
		(
			"    procedural audio: %d sounds generated in %d ms (debug -O0 editor build)"
			% [ProceduralAudio.IDS.size(), total_ms]
		)
	)


func test_ambience_loops() -> void:
	for id: StringName in [&"rain", &"hum"]:
		var stream := AudioManager.get_stream(id) as AudioStreamWAV
		if check(stream != null, "%s stream is a WAV" % id):
			check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % id)


func test_audio_manager_fallback_never_returns_null() -> void:
	check(not AudioManager.has_asset_file(&"rain"), "no rain file shipped: procedural fallback in use")
	check(
		AudioManager.get_stream(&"definitely_missing_sound") != null,
		"unknown ids return a silent stream instead of null"
	)


func test_mesh_util_winding_matches_godot() -> void:
	# Godot front faces are clockwise: cross(b - a, c - a) points away from the normal.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshUtil.add_box(st, Vector3.ZERO, Vector3.ONE)
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check_eq(verts.size(), 36, "box has 12 triangles")
	var all_clockwise := true
	for i in range(0, verts.size(), 3):
		var cross := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
		all_clockwise = all_clockwise and cross.dot(normals[i]) < 0.0
	check(all_clockwise, "every procedural face uses Godot's clockwise front-face winding")


func test_textures_generate() -> void:
	var tiles := ProceduralTextures.tiles()
	var noise := ProceduralTextures.noise()
	check(tiles != null and tiles.get_width() == 128, "tile texture generated")
	check(noise != null and noise.get_height() == 128, "noise texture generated")
	check(ProceduralTextures.tiles() == tiles, "textures are cached")


func test_background_prewarm_completes() -> void:
	AudioManager.prewarm_all()
	var start := Time.get_ticks_msec()
	var frames_waited := 0
	while not AudioManager.is_prewarm_done() and Time.get_ticks_msec() - start < 20000:
		await frames(1)
		frames_waited += 1
	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	check(
		AudioManager.is_prewarm_done(),
		"background audio prewarm finishes (%.2f s, %d frames kept running)" % [elapsed, frames_waited]
	)
	check(frames_waited > 10, "main thread kept rendering frames while audio generated in the background")
	var t0 := Time.get_ticks_usec()
	for id: StringName in AudioManager.CATALOGUE.keys():
		AudioManager.get_stream(id)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	check(ms < 20.0, "after prewarm, fetching every sound is instant (%.1f ms)" % ms)
