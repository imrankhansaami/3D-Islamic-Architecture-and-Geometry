class_name NoorSelfTest
extends RefCounted
## Automated self tests for the geometry engine and project scripts.
##
## Run with:  godot --headless --path . -- --selftest
## The report prints one line per check; the process exit code is the number
## of failures, so the tests can gate any later step.

static var _checks: int = 0
static var _failures: int = 0
static var _current_group: String = ""


static func run_all() -> int:
	_checks = 0
	_failures = 0
	print("================ NOOR SELF TEST ================")
	_test_winding_convention()
	_test_math_utils()
	_test_symmetry_manager()
	_test_all_patterns()
	_test_mesh_building()
	_test_architecture_components()
	_test_architecture_assembly()
	_test_serialization()
	_test_save_load()
	_test_panel_apply_flow()
	_test_scene_loading()
	print("================ %d checks, %d failure(s) ================" % [_checks, _failures])
	return _failures


static func group(name: String) -> void:
	_current_group = name
	print("-- %s" % name)


static func check(condition: bool, label: String) -> bool:
	_checks += 1
	if condition:
		print("   [ok]   %s" % label)
	else:
		_failures += 1
		print("   [FAIL] %s" % label)
	return condition


# --- Winding convention ------------------------------------------------------

static func _test_winding_convention() -> void:
	group("winding convention probe")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(Vector3(0, 0, 0))
	st.add_vertex(Vector3(1, 0, 0))
	st.add_vertex(Vector3(0, 1, 0))
	st.generate_normals()
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		check(false, "probe mesh built")
		return
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var probe_normal := normals[0]
	print("   probe: triangle (0,0,0)->(1,0,0)->(0,1,0), cross=+Z, generate_normals -> %s" % str(probe_normal))
	if probe_normal.z > 0.5:
		print("   => front face side = cross-product side: FRONT_NORMAL_SIGN must be +1.0")
	elif probe_normal.z < -0.5:
		print("   => front face side = opposite the cross product: FRONT_NORMAL_SIGN must be -1.0")
	check(absf(absf(probe_normal.z) - 1.0) < 0.01, "probe normal is unit length along Z")


# --- Math utilities ----------------------------------------------------------

static func _test_math_utils() -> void:
	group("math utilities")
	var hex := MathUtils.polygon_vertices(6, 2.0)
	check(hex.size() == 6, "hexagon has 6 vertices")
	var radius_ok := true
	for p in hex:
		if absf(p.length() - 2.0) > 1e-5:
			radius_ok = false
	check(radius_ok, "all polygon vertices lie on the construction circle")
	var spacing := fposmod(hex[1].angle() - hex[0].angle(), TAU)
	check(absf(spacing - TAU / 6.0) < 1e-5, "angular interval is TAU/6")

	var star := MathUtils.star_vertices(8, 3.0, 1.2)
	check(star.size() == 16, "8-point star has 16 vertices (outer/inner alternating)")
	check(absf(star[0].length() - 3.0) < 1e-5, "even index = outer radius")
	check(absf(star[1].length() - 1.2) < 1e-5, "odd index = inner radius")

	var ccw := MathUtils.ensure_ccw(MathUtils.reverse_points(hex))
	check(MathUtils.signed_area(ccw) > 0.0, "ensure_ccw produces positive shoelace area")

	var mirrored := MathUtils.mirror_points_axis(hex, PI / 2.0)
	var mirror_ok := true
	for i in hex.size():
		# reflect hex across Y axis: x -> -x
		var expected := Vector2(-hex[i].x, hex[i].y)
		if mirrored[i].distance_to(expected) > 1e-4:
			mirror_ok = false
	check(mirror_ok, "reflection across the Y axis negates x")

	var polar := MathUtils.cart_to_polar(Vector2(3.0, 4.0))
	check(absf(polar.x - 5.0) < 1e-5, "cart_to_polar radius")
	check(absf(polar.y - atan2(4.0, 3.0)) < 1e-5, "cart_to_polar angle")

	var circuits := MathUtils.star_polygon_circuits(5, 2)
	check(circuits.size() == 1, "pentagram {5/2} is one closed circuit")
	var circuits2 := MathUtils.star_polygon_circuits(6, 2)
	check(circuits2.size() == 2, "hexagram {6/2} splits into two circuits (gcd 2)")


static func _test_symmetry_manager() -> void:
	group("symmetry manager")
	var square := MathUtils.polygon_vertices(4, 1.0)
	var copies := SymmetryManager.radial_copies([square], 8)
	check(copies.size() == 8, "8-fold rotational symmetry produces 8 copies")
	check(absf(MathUtils.signed_area(copies[3]) - MathUtils.signed_area(square)) < 1e-5,
		"rotation preserves polygon area")
	var wedge := SymmetryManager.replicate_wedge([square], 4, true)
	check(wedge.size() == 8, "wedge replication with mirror produces 2 x folds copies")


# --- Pattern generation ------------------------------------------------------

static func _test_all_patterns() -> void:
	group("pattern generation (all 10 types)")
	for type in PatternConfig.TYPE_NAMES.size():
		var config: PatternConfig = PatternLibrary.make_preset(type)
		_test_one_pattern_visible(type, config, "preset")
		_test_one_pattern_visible(type, _extreme_config(type, false), "minimum parameters")
		_test_one_pattern_visible(type, _extreme_config(type, true), "maximum parameters")

	# determinism: the same configuration must always produce the same result
	var c1: PatternConfig = PatternLibrary.make_preset(PatternConfig.PatternType.ROSETTE)
	var c2: PatternConfig = PatternLibrary.make_preset(PatternConfig.PatternType.ROSETTE)
	var g1 := PatternEngine.generate(c1)
	var g2 := PatternEngine.generate(c2)
	var s1 := g1.stats()
	var s2 := g2.stats()
	check(s1["fills"] == s2["fills"] and s1["segments"] == s2["segments"],
		"generation is deterministic for identical configs")


static func _test_one_pattern_visible(type: int, config: PatternConfig, label: String) -> void:
	var result := PatternEngine.generate_timed(config)
	var geo: PatternGeometry = result[0]
	var msec: float = result[1]
	var stats := geo.stats()
	var total_shapes: int = int(stats["fills"]) + int(stats["accents"]) + int(stats["segments"])
	var ok := total_shapes > 0
	var finite := true
	for poly: PackedVector2Array in geo.fills:
		if not MathUtils.is_finite_points(poly):
			finite = false
	for poly: PackedVector2Array in geo.accents:
		if not MathUtils.is_finite_points(poly):
			finite = false
	for seg: PackedVector2Array in geo.segments:
		if not MathUtils.is_finite_points(seg):
			finite = false
	var bounds_ok := geo.bounds.size.x >= 0.0 and geo.bounds.size.y >= 0.0 and is_finite(geo.bounds.size.x)
	check(ok and finite and bounds_ok,
		"%s [%s]: %d fills, %d accents, %d lines, %.1f ms" % [
			PatternConfig.TYPE_NAMES[type], label,
			stats["fills"], stats["accents"], stats["segments"], msec])


static func _extreme_config(type: int, maximum: bool) -> PatternConfig:
	var c: PatternConfig = PatternLibrary.make_preset(type)
	if maximum:
		c.sides = PatternConfig.SIDES_MAX
		c.star_points = PatternConfig.POINTS_MAX
		c.symmetry_folds = PatternConfig.SYMMETRY_MAX
		c.repetition = PatternConfig.REPETITION_MAX
		c.scale = PatternConfig.SCALE_MAX
		c.tile_size = PatternConfig.TILE_MAX
		c.line_thickness = PatternConfig.LINE_MAX
		c.extrusion_depth = PatternConfig.EXTRUDE_MAX
		c.inner_radius_ratio = PatternConfig.INNER_MAX
		c.outer_radius = PatternConfig.OUTER_MAX
		c.rotation_deg = 359.9
	else:
		c.sides = PatternConfig.SIDES_MIN
		c.star_points = PatternConfig.POINTS_MIN
		c.symmetry_folds = PatternConfig.SYMMETRY_MIN
		c.repetition = PatternConfig.REPETITION_MIN
		c.scale = PatternConfig.SCALE_MIN
		c.tile_size = PatternConfig.TILE_MIN
		c.line_thickness = PatternConfig.LINE_MIN
		c.extrusion_depth = 0.0
		c.inner_radius_ratio = PatternConfig.INNER_MIN
		c.outer_radius = PatternConfig.OUTER_MIN
		c.rotation_deg = 0.0
	c.clamp_values()
	return c


# --- Mesh building -----------------------------------------------------------

static func _test_mesh_building() -> void:
	group("mesh building")
	var total_triangles := 0
	for type in PatternConfig.TYPE_NAMES.size():
		var config: PatternConfig = PatternLibrary.make_preset(type)
		var geo := PatternEngine.generate(config)
		var layers := MeshBuilder.build_pattern_layers(geo, config, false)
		var triangles := 0
		var all_valid := true
		for layer: Variant in layers:
			if layer == null:
				continue
			var mesh: ArrayMesh = layer
			if mesh.get_surface_count() == 0:
				all_valid = false
				continue
			for s in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				if verts.size() == 0:
					all_valid = false
				for v in verts:
					if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)):
						all_valid = false
						break
				if normals.size() == verts.size():
					for nrm in normals:
						if absf(nrm.length() - 1.0) > 0.05:
							all_valid = false
							break
			var stats := MeshBuilder.mesh_stats(mesh)
			triangles += int(stats["triangles"])
		total_triangles += triangles
		check(all_valid and triangles > 0,
			"%s: extruded layers valid, %d triangles" % [PatternConfig.TYPE_NAMES[type], triangles])

		# flat variant (used by the PNG export)
		var flat_layers := MeshBuilder.build_pattern_layers(geo, config, true)
		var flat_triangles := 0
		for layer: Variant in flat_layers:
			if layer != null:
				flat_triangles += int(MeshBuilder.mesh_stats(layer)["triangles"])
		check(flat_triangles > 0, "%s: flat layers valid" % PatternConfig.TYPE_NAMES[type])

	# architecture primitives
	var box := MeshBuilder.build_box(Vector3(2, 3, 4))
	check(int(MeshBuilder.mesh_stats(box)["triangles"]) == 12, "box = 12 triangles")

	var dome_profile := PackedVector2Array()
	for i in 12:
		var t := float(i) / 11.0
		dome_profile.append(Vector2(cos(t * PI / 2.0) * 3.0, sin(t * PI / 2.0) * 3.0))
	var dome := MeshBuilder.revolve(dome_profile, 32, true, true, false)
	var dome_stats := MeshBuilder.mesh_stats(dome)
	check(int(dome_stats["triangles"]) > 500, "smooth dome revolve: %d triangles" % dome_stats["triangles"])

	var faceted := MeshBuilder.revolve(PackedVector2Array([Vector2(1, 0), Vector2(1, 2)]), 8, false, true, true)
	check(int(MeshBuilder.mesh_stats(faceted)["triangles"]) == 16 + 16, "faceted octagon column = sides*2 + caps")

	print("   total pattern triangles across 10 types: %d" % total_triangles)


# --- Architecture ------------------------------------------------------------

static func _test_architecture_components() -> void:
	group("architecture components")

	# arch curves
	var pointed := ArchGenerator.curve(ArchGenerator.Kind.POINTED, 2.0, 3.0, 0.5, 24)
	check(pointed.size() >= 20, "pointed arch curve sampled (%d points)" % pointed.size())
	check(absf(pointed[0].y - 3.0) < 0.01 and absf(pointed[pointed.size() - 1].y - 3.0) < 0.01,
		"pointed arch springs from the springing height at both ends")
	check(absf(pointed[0].x + 2.0) < 0.01 and absf(pointed[pointed.size() - 1].x - 2.0) < 0.01,
		"pointed arch spans the opening half-width")
	check(ArchGenerator.curve_apex(pointed) > 3.0, "pointed arch apex above springing")

	var horseshoe := ArchGenerator.curve(ArchGenerator.Kind.HORSESHOE, 2.0, 1.0, 0.0, 24)
	check(absf(horseshoe[0].y - 1.0) < 0.02, "horseshoe arch ends at the springing height")
	check(ArchGenerator.curve_apex(horseshoe) > 3.0, "horseshoe arch reach")

	var round_arch := ArchGenerator.curve(ArchGenerator.Kind.ROUND, 2.0, 3.0, 0.0, 24)
	check(absf(ArchGenerator.curve_apex(round_arch) - 5.0) < 0.05, "semicircular arch apex = springing + radius")

	# arch wall: three bays are wider than one bay and the mesh is valid
	var one_bay := ArchGenerator.wall_with_arches(8.0, 8.0, [{
		"x": 0.0, "half": 2.0, "spring": 3.0, "pointiness": 0.5, "kind": ArchGenerator.Kind.POINTED,
	}], 1.0)
	var three_bays := ArchGenerator.wall_with_arches(20.0, 8.0, [
		{"x": -6.0, "half": 2.0, "spring": 3.0, "pointiness": 0.5, "kind": ArchGenerator.Kind.POINTED},
		{"x": 0.0, "half": 2.0, "spring": 3.0, "pointiness": 0.5, "kind": ArchGenerator.Kind.POINTED},
		{"x": 6.0, "half": 2.0, "spring": 3.0, "pointiness": 0.5, "kind": ArchGenerator.Kind.POINTED},
	], 1.0)
	var one_stats := MeshBuilder.mesh_stats(one_bay)
	var three_stats := MeshBuilder.mesh_stats(three_bays)
	check(int(one_stats["triangles"]) > 100 and int(three_stats["triangles"]) > int(one_stats["triangles"]) * 2,
		"arched wall meshes build (1 bay: %d tris, 3 bays: %d tris)" % [
			one_stats["triangles"], three_stats["triangles"]])

	var band := ArchGenerator.band_mesh(pointed, 0.3, 0.15)
	check(int(MeshBuilder.mesh_stats(band)["triangles"]) > 20, "arch band ribbon builds")

	# column / dome / drum / finial
	var column := ColumnGenerator.column_mesh(5.0, 0.45, 20)
	check(int(MeshBuilder.mesh_stats(column)["triangles"]) > 200, "column revolve")

	var dome := DomeGenerator.dome_mesh(7.0, 8.0, DomeGenerator.Style.ONION, 32)
	check(int(MeshBuilder.mesh_stats(dome)["triangles"]) > 900, "onion dome revolve")
	var profile := DomeGenerator.dome_profile(7.0, 8.0, DomeGenerator.Style.ONION)
	check(profile[0].x > 6.9 and profile[profile.size() - 1].x < 0.01, "dome profile from base radius to pole")
	var ribs := DomeGenerator.ribs_mesh(7.0, 8.0, DomeGenerator.Style.ONION, 8, 0.3, 0.08)
	check(int(MeshBuilder.mesh_stats(ribs)["triangles"]) > 100, "dome ribs")

	var minaret := MinaretGenerator.build(24.0)
	var minaret_meshes := 0
	for child in minaret.get_children():
		if child is MeshInstance3D or child is MultiMeshInstance3D:
			minaret_meshes += 1
	check(minaret_meshes >= 10, "minaret node has %d mesh parts" % minaret_meshes)

	var fountain := DecorationGenerator.fountain_node()
	check(fountain.get_child_count() >= 6, "fountain assembles")
	var lantern := DecorationGenerator.lantern_node()
	check(lantern.get_child_count() == 3, "hanging lantern assembles")
	var bands := DecorationGenerator.floor_band_nodes(20.0)
	check(bands.size() == 2, "floor inlay bands")

	var panel := PatternPanel.new()
	panel.setup("gate_panel", Vector2(4, 3), PatternLibrary.get_panel_config("gate_panel"))
	var panel_children := panel.get_child_count()
	var alt: PatternConfig = PatternLibrary.make_preset(PatternConfig.PatternType.TESS_HEX)
	panel.rebuild(alt)
	check(panel_children >= 6 and panel.get_child_count() >= 6,
		"pattern panel builds and rebuilds (%d -> %d children)" % [panel_children, panel.get_child_count()])
	panel.free()


static func _test_architecture_assembly() -> void:
	group("architecture assembly")
	var start := Time.get_ticks_msec()
	var ctx := ArchitectureGenerator.generate()
	var elapsed := Time.get_ticks_msec() - start
	var root: Node3D = ctx["root"]
	check(root.get_child_count() >= 15, "architecture root has %d children (built in %d ms)" % [root.get_child_count(), elapsed])
	check(ctx["collision"].size() > 40, "%d collision entries" % ctx["collision"].size())
	check(ctx["proxies"].size() > 30, "%d interactive proxies" % ctx["proxies"].size())
	check(ctx["panels"].size() == 5, "5 pattern panels registered")
	check(ctx["lights"].size() > 10, "%d lantern light positions" % ctx["lights"].size())
	var total_tris := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			total_tris += int(MeshBuilder.mesh_stats((node as MeshInstance3D).mesh)["triangles"])
		for child in node.get_children():
			stack.append(child)
	check(total_tris > 40000, "architecture triangle count: %d" % total_tris)
	print("   (all architecture meshes: %d triangles)" % total_tris)
	root.free()


# --- Serialisation -----------------------------------------------------------

static func _test_serialization() -> void:
	group("serialisation")
	var config: PatternConfig = PatternLibrary.make_preset(PatternConfig.PatternType.GIRIH)
	config.rotation_deg = 33.5
	config.color_accent = Color(0.1, 0.2, 0.3)
	var text := config.to_json()
	var restored := PatternConfig.from_json(text)
	check(restored != null, "JSON round trip parses")
	if restored != null:
		check(restored.pattern_type == config.pattern_type, "type survives round trip")
		check(absf(restored.rotation_deg - config.rotation_deg) < 1e-3, "rotation survives round trip")
		check(restored.sides == config.sides and restored.star_points == config.star_points,
			"int parameters survive round trip")
		check(_color_close(restored.color_accent, config.color_accent),
			"colours survive round trip")

	var geo_a := PatternEngine.generate(config)
	var geo_b := PatternEngine.generate(restored)
	check(geo_a.stats()["segments"] == geo_b.stats()["segments"],
		"restored config regenerates identical geometry")


# --- Saved patterns ----------------------------------------------------------

static func _test_save_load() -> void:
	group("saved patterns")
	var config: PatternConfig = PatternLibrary.make_preset(PatternConfig.PatternType.TESS_HEX)
	config.rotation_deg = 17.0
	var error := PatternLibrary.save_pattern("selftest pattern", config)
	check(error.is_empty(), "save_pattern succeeds")
	var names := PatternLibrary.list_saved_patterns()
	check("selftest pattern" in names, "saved pattern appears in the list (%d entries)" % names.size())
	var loaded := PatternLibrary.load_pattern("selftest pattern")
	check(loaded != null, "saved pattern loads")
	if loaded != null:
		check(loaded.pattern_type == config.pattern_type and absf(loaded.rotation_deg - 17.0) < 0.01,
			"saved pattern round-trips exactly")
		check(loaded.geometry_signature() == config.geometry_signature(),
			"loaded signature matches (mesh cache would hit)")
	PatternLibrary.delete_pattern("selftest pattern")
	check(not ("selftest pattern" in PatternLibrary.list_saved_patterns()), "saved pattern deletes")


# --- Panel apply flow (laboratory -> architecture) ---------------------------

static func _test_panel_apply_flow() -> void:
	group("pattern -> architectural panel")
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene: PackedScene = load("res://scenes/screens/world_screen.tscn")
	if scene == null:
		check(false, "world screen scene loads")
		return
	var world := scene.instantiate()
	tree.root.add_child(world)

	# find the floor medallion panel
	var panels := tree.get_nodes_in_group("pattern_panels")
	check(panels.size() == 5, "%d architectural panels exist" % panels.size())
	var medallion: PatternPanel = null
	for panel in panels:
		var p := panel as PatternPanel
		if p != null and p.panel_id == "floor_medallion":
			medallion = p
			break
	check(medallion != null, "floor medallion panel found")
	if medallion != null:
		var original_count := medallion.get_child_count()
		var original_config: PatternConfig = PatternLibrary.get_panel_config("floor_medallion").clone()
		# apply a different pattern through the library signal chain
		var replacement: PatternConfig = PatternLibrary.make_preset(PatternConfig.PatternType.STAR)
		replacement.star_points = 16
		replacement.apply_palette(3)
		replacement.clamp_values()
		PatternLibrary.assign_panel("floor_medallion", replacement)
		var applied: PatternConfig = PatternLibrary.get_panel_config("floor_medallion")
		check(applied.star_points == 16 and applied.pattern_type == PatternConfig.PatternType.STAR,
			"library stores the applied config")
		check(medallion.get_child_count() >= original_count - 1 and medallion.get_child_count() >= 6,
			"panel rebuilt through the signal chain (%d -> %d children)" % [
				original_count, medallion.get_child_count()])
		check(medallion.config != null and medallion.config.pattern_type == PatternConfig.PatternType.STAR,
			"panel node now shows the new pattern")
		# restore the original configuration so no state is modified
		PatternLibrary.assign_panel("floor_medallion", original_config)

	tree.root.remove_child(world)
	world.free()


# --- Scenes ------------------------------------------------------------------

static func _test_scene_loading() -> void:
	group("project scan")
	var scripts := _find_files("res://scripts", ".gd")
	var scenes := _find_files("res://scenes", ".tscn")
	var all_ok := true
	for path: String in scripts:
		if load(path) == null:
			all_ok = false
			print("   failed to load %s" % path)
	check(scripts.size() > 0 and all_ok, "%d scripts load" % scripts.size())
	var scenes_ok := true
	for path: String in scenes:
		if load(path) == null:
			scenes_ok = false
			print("   failed to load %s" % path)
	check(scenes_ok, "%d scenes load" % scenes.size())

	# build every screen in the tree once (catches broken node paths and
	# null references without needing rendering)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for path: String in [
		"res://scenes/screens/main_menu.tscn",
		"res://scenes/screens/lab_screen.tscn",
		"res://scenes/screens/studio_screen.tscn",
		"res://scenes/screens/learning_screen.tscn",
		"res://scenes/screens/settings_screen.tscn",
		"res://scenes/screens/world_screen.tscn",
	]:
		var scene: PackedScene = load(path)
		if scene == null:
			check(false, "scene %s loads" % path)
			continue
		var instance := scene.instantiate()
		tree.root.add_child(instance)
		var child_count := instance.get_child_count()
		check(child_count >= 1, "%s builds (%d top-level children)" % [path.get_file(), child_count])
		tree.root.remove_child(instance)
		instance.free()


static func _color_close(a: Color, b: Color) -> bool:
	# 8-bit hex quantisation in the JSON save format allows ~1/255 error.
	var dr := absf(a.r - b.r) <= 0.01 and absf(a.g - b.g) <= 0.01
	var db := absf(a.b - b.b) <= 0.01 and absf(a.a - b.a) <= 0.01
	return dr and db


static func _find_files(root: String, suffix: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				found.append_array(_find_files(path, suffix))
		elif entry.ends_with(suffix):
			found.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
