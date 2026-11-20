extends Control
## Geometry Laboratory — the main procedural pattern workbench.
##
## Left: pattern type, parameters, colours, actions. Centre: live 3D preview
## of the generated geometry (with optional construction overlay). Right:
## the construction explained with live numbers.
##
## The screen edits PatternLibrary.lab_config in place (so the configuration
## survives navigation) and applies it to an architectural panel when one is
## selected in the explorer.

signal screen_requested(id: String)
signal toast_requested(text: String)

const TYPE_DESCRIPTIONS := {
	PatternConfig.PatternType.STAR:
		"An n-point star: 2n vertices alternate between the outer radius (the points) and the inner radius (the valleys). The inner/outer ratio controls how sharp the star reads.",
	PatternConfig.PatternType.POLY_REGULAR:
		"A regular polygon with equal side lengths. Extra layers are rotated by half an angular step; connecting lines between layers create the classic woven effect.",
	PatternConfig.PatternType.POLY_OVERLAP:
		"One polygon rotated repeatedly around the centre by half the side angle — the classic interlocking flower construction.",
	PatternConfig.PatternType.POLY_CONCENTRIC:
		"Nested polygons of decreasing radius, linked vertex-to-vertex between adjacent layers.",
	PatternConfig.PatternType.POLY_RADIAL:
		"Small polygons placed at equal angular intervals on concentric orbits; alternating colours emphasise the radial arrangement.",
	PatternConfig.PatternType.ROSETTE:
		"The signature Islamic motif: a ring of petals on the symmetry axes, interlocked by two n-point stars offset half an angular step, with nested rings for depth.",
	PatternConfig.PatternType.TESS_SQUARE:
		"A square lattice of decorated tiles. Each tile carries an inscribed star and its half-step twin; centres carry accent diamonds. Cells cover the plane without gaps or overlaps.",
	PatternConfig.PatternType.TESS_HEX:
		"A hexagonal lattice. Hexagons tile with three tiles around every vertex (3 x 120° = 360°). Cells alternate colours in a three-colour cycle.",
	PatternConfig.PatternType.TESS_TRIANGLE:
		"A triangular lattice of alternating up/down triangles, each decorated with its medial (midpoint) triangle — six triangles meet at every vertex (6 x 60° = 360°).",
	PatternConfig.PatternType.GIRIH:
		"A simplified star & cross network: stars on a square lattice joined by parallel strap bands, with diamonds in the cell centres. (Simplified construction — not the historical girih tile drafting method.)",
}

var _config: PatternConfig
var _geo: PatternGeometry = null
var _viewport: PatternViewport
var _rows: Dictionary = {}
var _type_option: OptionButton
var _palette_option: OptionButton
var _fill_picker: ColorPickerButton
var _accent_picker: ColorPickerButton
var _line_picker: ColorPickerButton
var _fills_check: CheckButton
var _lines_check: CheckButton
var _guides_check: CheckButton
var _stats_label: Label
var _title_label: Label
var _math_label: Label
var _how_label: Label
var _target_label: Label
var _apply_button: Button
var _save_name: LineEdit
var _load_option: OptionButton
var _rebuild_timer: Timer
var _syncing := false
var _dirty_stat := ""
var _full_rebuild_count := 0


func _ready() -> void:
	if PatternLibrary.active_panel_id != "":
		var panel_config: PatternConfig = PatternLibrary.get_panel_config(PatternLibrary.active_panel_id)
		if panel_config != null:
			PatternLibrary.lab_config.copy_from(panel_config)
	_config = PatternLibrary.lab_config
	_build_ui()
	_rebuild_timer = Timer.new()
	_rebuild_timer.one_shot = true
	_rebuild_timer.wait_time = 0.09
	_rebuild_timer.timeout.connect(func() -> void: _rebuild(false))
	add_child(_rebuild_timer)
	_sync_controls()
	_rebuild(true)
	if PatternLibrary.active_panel_changed.is_connected(_on_active_panel_changed) == false:
		PatternLibrary.active_panel_changed.connect(_on_active_panel_changed)
	_update_target_label()


# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	var bg := OrnamentalBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.line_color = Color(0.788, 0.635, 0.153, 0.045)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	hbox.add_child(_build_left_panel())
	hbox.add_child(_build_center_column())
	hbox.add_child(_build_right_panel())


func _build_left_panel() -> Control:
	var stack := UIHelpers.panel_stack(378)
	var panel: PanelContainer = stack["panel"]
	var vbox: VBoxContainer = stack["vbox"]
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(UIHelpers.scroll_wrap(vbox))
	_build_left_panel_content(vbox)
	return panel


func _build_left_panel_content(vbox: VBoxContainer) -> void:
	vbox.add_child(UIHelpers.title("Geometry Laboratory"))

	vbox.add_child(UIHelpers.section("Pattern"))
	var type_row := UIHelpers.dropdown_row("", PatternConfig.TYPE_NAMES, _config.pattern_type,
		"Choose the mathematical construction to generate.")
	_type_option = type_row["option"]
	_type_option.item_selected.connect(_on_type_selected)
	vbox.add_child(type_row["row"])

	vbox.add_child(UIHelpers.section("Parameters"))
	_add_slider(vbox, "sides", "Number of Sides", PatternConfig.SIDES_MIN, PatternConfig.SIDES_MAX, 1.0,
		_config.sides, "Sides of the regular polygon / tessellation base.", 0)
	_add_slider(vbox, "star_points", "Star Points", PatternConfig.POINTS_MIN, PatternConfig.POINTS_MAX, 1.0,
		_config.star_points, "Number of star / rosette folds (radial symmetry count).", 0)
	_add_slider(vbox, "symmetry_folds", "Symmetry", PatternConfig.SYMMETRY_MIN, PatternConfig.SYMMETRY_MAX, 1.0,
		_config.symmetry_folds, "Reflection axes / accent elements placed by symmetry.", 0)
	_add_slider(vbox, "repetition", "Repetition Count", PatternConfig.REPETITION_MIN, PatternConfig.REPETITION_MAX, 1.0,
		_config.repetition, "Concentric rings or tessellation cells per side.", 0)
	_add_slider(vbox, "rotation_deg", "Rotation", 0.0, 360.0, 0.5, _config.rotation_deg,
		"Rotates the generated geometry about the centre.", 1, "°")
	_add_slider(vbox, "inner_radius_ratio", "Inner Radius", PatternConfig.INNER_MIN, PatternConfig.INNER_MAX, 0.01,
		_config.inner_radius_ratio, "Inner / outer radius ratio — controls star proportions.", 2)
	_add_slider(vbox, "outer_radius", "Outer Radius", PatternConfig.OUTER_MIN, PatternConfig.OUTER_MAX, 0.05,
		_config.outer_radius, "Overall construction radius in world units.", 2)
	_add_slider(vbox, "scale", "Scale", PatternConfig.SCALE_MIN, PatternConfig.SCALE_MAX, 0.01,
		_config.scale, "Uniform scale applied to the finished geometry.", 2)
	_add_slider(vbox, "tile_size", "Tile Size", PatternConfig.TILE_MIN, PatternConfig.TILE_MAX, 0.05,
		_config.tile_size, "Edge length of one tessellation tile.", 2)
	_add_slider(vbox, "line_thickness", "Line Thickness", PatternConfig.LINE_MIN, PatternConfig.LINE_MAX, 0.005,
		_config.line_thickness, "Width of the drawn geometric lines.", 3)
	_add_slider(vbox, "extrusion_depth", "Extrusion Depth", PatternConfig.EXTRUDE_MIN, PatternConfig.EXTRUDE_MAX, 0.005,
		_config.extrusion_depth, "0 = flat 2D pattern; larger values extrude it into 3D relief.", 3)

	vbox.add_child(UIHelpers.section("Colours & Layers"))
	var palette_row := UIHelpers.dropdown_row("Palette", MaterialLibrary.palette_names(),
		maxi(_config.palette, 0), "Curated Islamic colour combinations.")
	_palette_option = palette_row["option"]
	_palette_option.item_selected.connect(_on_palette_selected)
	vbox.add_child(palette_row["row"])

	var fill_row := UIHelpers.color_row("Fills", _config.color_fill, "Colour of the base filled shapes.")
	_fill_picker = fill_row["picker"]
	_fill_picker.color_changed.connect(func(c: Color) -> void: _on_color_edited("fill", c))
	vbox.add_child(fill_row["row"])
	var accent_row := UIHelpers.color_row("Accents", _config.color_accent, "Colour of the secondary (highlight) shapes.")
	_accent_picker = accent_row["picker"]
	_accent_picker.color_changed.connect(func(c: Color) -> void: _on_color_edited("accent", c))
	vbox.add_child(accent_row["row"])
	var line_row := UIHelpers.color_row("Lines", _config.color_line, "Colour of the geometric line work.")
	_line_picker = line_row["picker"]
	_line_picker.color_changed.connect(func(c: Color) -> void: _on_color_edited("line", c))
	vbox.add_child(line_row["row"])

	var fills_row := UIHelpers.check_row("Filled shapes", _config.show_fills, "Draw the filled layers.")
	_fills_check = fills_row["check"]
	_fills_check.toggled.connect(func(on: bool) -> void:
		if _syncing: return
		_config.show_fills = on
		_mark_dirty())
	vbox.add_child(fills_row["row"])
	var lines_row := UIHelpers.check_row("Line work", _config.show_lines, "Draw the extruded line ribbons.")
	_lines_check = lines_row["check"]
	_lines_check.toggled.connect(func(on: bool) -> void:
		if _syncing: return
		_config.show_lines = on
		_mark_dirty())
	vbox.add_child(lines_row["row"])
	var guides_row := UIHelpers.check_row("Construction guides", _config.show_guides,
		"Show vertices, symmetry axes and construction circles — the drafting overlay.")
	_guides_check = guides_row["check"]
	_guides_check.toggled.connect(func(on: bool) -> void:
		if _syncing: return
		_config.show_guides = on
		_mark_dirty())
	vbox.add_child(guides_row["row"])

	_build_actions(vbox)


func _build_actions(vbox: VBoxContainer) -> void:
	vbox.add_child(UIHelpers.section("Actions"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	var generate := UIHelpers.button("Generate", true, "Regenerate the pattern and re-frame the view.")
	generate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate.pressed.connect(func() -> void: _rebuild(true))
	grid.add_child(generate)
	var randomize := UIHelpers.button("Randomize", false, "Random parameters from the current seed (deterministic).")
	randomize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	randomize.pressed.connect(_on_randomize)
	grid.add_child(randomize)
	var reset := UIHelpers.button("Reset", false, "Restore this pattern type's default parameters.")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_on_reset)
	grid.add_child(reset)

	# Save / load
	var save_box := HBoxContainer.new()
	_save_name = LineEdit.new()
	_save_name.placeholder_text = "Pattern name…"
	_save_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_box.add_child(_save_name)
	var save_button := UIHelpers.button("Save", false, "Save this configuration to the pattern library (JSON).")
	save_button.pressed.connect(_on_save)
	save_box.add_child(save_button)
	vbox.add_child(save_box)

	var load_box := HBoxContainer.new()
	var load_row := UIHelpers.dropdown_row("", PackedStringArray(), 0, "Saved configurations.")
	_load_option = load_row["option"]
	_load_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_box.add_child(load_row["row"])
	var load_button := UIHelpers.button("Load", false, "")
	load_button.pressed.connect(_on_load)
	load_box.add_child(load_button)
	var delete_button := UIHelpers.button("Delete", false, "Delete the selected saved pattern.")
	delete_button.theme_type_variation = &"DangerButton"
	delete_button.pressed.connect(_on_delete)
	load_box.add_child(delete_button)
	vbox.add_child(load_box)
	_refresh_load_list()

	# Export
	var export_box := HBoxContainer.new()
	export_box.add_theme_constant_override("separation", 6)
	var export_view := UIHelpers.button("Export PNG", false, "Save the current 3D preview as a PNG image.")
	export_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_view.pressed.connect(_on_export_view_png)
	export_box.add_child(export_view)
	var export_flat := UIHelpers.button("Export Flat", false, "Save a transparent, flat (2D) PNG of the pattern.")
	export_flat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_flat.pressed.connect(_on_export_flat_png)
	export_box.add_child(export_flat)
	vbox.add_child(export_box)

	# Studio link
	var studio := UIHelpers.button("Send to 3D Studio", false, "Open this pattern in the Transformation Studio.")
	studio.pressed.connect(func() -> void:
		PatternLibrary.studio_config = _config.clone()
		screen_requested.emit("studio"))
	vbox.add_child(studio)

	# Apply to panel
	vbox.add_child(UIHelpers.section("Architectural Panel"))
	_target_label = UIHelpers.wrapped("No panel selected. Click a decorative panel in the Architecture Explorer to link it here.", 13, NoorTheme.MUTED)
	vbox.add_child(_target_label)
	_apply_button = UIHelpers.button("Apply to Panel", true, "Apply this pattern to the linked architectural panel.")
	_apply_button.pressed.connect(_on_apply_to_panel)
	vbox.add_child(_apply_button)
	var detach := UIHelpers.button("Detach panel", false, "Stop editing the linked panel.")
	detach.pressed.connect(func() -> void: PatternLibrary.set_active_panel(""))
	vbox.add_child(detach)


func _build_center_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	_title_label = UIHelpers.label("Rosette", 20, NoorTheme.GOLD_LIGHT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_title_label)
	for preset: Array in [["Front", "front"], ["Top", "top"], ["Iso", "iso"]]:
		var button := UIHelpers.button(preset[0], false, "Jump the camera to the %s view." % preset[0].to_lower())
		button.theme_type_variation = &"ToolButton"
		button.pressed.connect(func() -> void: _viewport.set_view(preset[1]))
		toolbar.add_child(button)
	var autorotate_row := UIHelpers.check_row("Auto-rotate", false, "Slowly rotate the preview.")
	autorotate_row["check"].toggled.connect(func(on: bool) -> void: _viewport.set_autorotate(on, 0.5, "spin"))
	toolbar.add_child(autorotate_row["row"])
	var wireframe_row := UIHelpers.check_row("Wireframe", false, "Draw the preview as a wireframe.")
	wireframe_row["check"].toggled.connect(func(on: bool) -> void: _viewport.set_wireframe(on))
	toolbar.add_child(wireframe_row["row"])
	column.add_child(toolbar)

	_viewport = preload("res://scenes/geometry/pattern_viewport.tscn").instantiate()
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_viewport)

	_stats_label = UIHelpers.muted("", 12)
	column.add_child(_stats_label)
	return column


func _build_right_panel() -> Control:
	var stack := UIHelpers.panel_stack(330)
	var panel: PanelContainer = stack["panel"]
	var vbox: VBoxContainer = stack["vbox"]
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(UIHelpers.scroll_wrap(vbox))
	_build_right_panel_content(vbox)
	return panel


func _build_right_panel_content(vbox: VBoxContainer) -> void:
	vbox.add_child(UIHelpers.title("About"))
	vbox.add_child(UIHelpers.section("Construction"))
	_math_label = UIHelpers.formula("")
	vbox.add_child(_math_label)
	vbox.add_child(UIHelpers.section("How it is generated"))
	_how_label = UIHelpers.wrapped("", 13, NoorTheme.MUTED)
	vbox.add_child(_how_label)


# --- Parameter plumbing ------------------------------------------------------

func _add_slider(parent: VBoxContainer, key: String, title: String, min_v: float, max_v: float,
		step: float, value: float, tooltip: String, decimals: int, suffix: String = "") -> void:
	var row := UIHelpers.slider_row(title, min_v, max_v, step, value, tooltip, decimals, suffix)
	var slider: HSlider = row["slider"]
	slider.value_changed.connect(func(v: float) -> void:
		if _syncing: return
		_set_config_value(key, v)
		_mark_dirty())
	_rows[key] = row
	parent.add_child(row["row"])


func _set_config_value(key: String, value: float) -> void:
	match key:
		"sides": _config.sides = int(value)
		"star_points": _config.star_points = int(value)
		"symmetry_folds": _config.symmetry_folds = int(value)
		"repetition": _config.repetition = int(value)
		"rotation_deg": _config.rotation_deg = value
		"inner_radius_ratio": _config.inner_radius_ratio = value
		"outer_radius": _config.outer_radius = value
		"scale": _config.scale = value
		"tile_size": _config.tile_size = value
		"line_thickness": _config.line_thickness = value
		"extrusion_depth": _config.extrusion_depth = value
	_config.clamp_values()


func _mark_dirty() -> void:
	_rebuild_timer.start()


func _on_type_selected(index: int) -> void:
	if _syncing:
		return
	_config.copy_from(PatternLibrary.make_preset(index))
	_config.pattern_type = index
	_config.clamp_values()
	_sync_controls()
	_rebuild(true)


func _on_palette_selected(index: int) -> void:
	if _syncing:
		return
	_config.apply_palette(index)
	_sync_controls()
	_mark_dirty()


func _on_color_edited(role: String, color: Color) -> void:
	if _syncing:
		return
	match role:
		"fill": _config.color_fill = color
		"accent": _config.color_accent = color
		"line": _config.color_line = color
	_config.palette = -1  # custom colours
	_mark_dirty()


func _on_randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _config.seed
	_config.randomize_params(rng)
	_sync_controls()
	_rebuild(true)


func _on_reset() -> void:
	var type := _config.pattern_type
	_config.copy_from(PatternLibrary.make_preset(type))
	_config.pattern_type = type
	_sync_controls()
	_rebuild(true)


func _sync_controls() -> void:
	_syncing = true
	_type_option.selected = _config.pattern_type
	var values := {
		"sides": _config.sides,
		"star_points": _config.star_points,
		"symmetry_folds": _config.symmetry_folds,
		"repetition": _config.repetition,
		"rotation_deg": _config.rotation_deg,
		"inner_radius_ratio": _config.inner_radius_ratio,
		"outer_radius": _config.outer_radius,
		"scale": _config.scale,
		"tile_size": _config.tile_size,
		"line_thickness": _config.line_thickness,
		"extrusion_depth": _config.extrusion_depth,
	}
	for key: String in values:
		if _rows.has(key):
			var slider: HSlider = _rows[key]["slider"]
			slider.value = float(values[key])
	var relevant := PatternEngine.relevant_params(_config.pattern_type)
	for key: String in _rows:
		var row: Control = _rows[key]["row"]
		var show := bool(relevant.get(key, false))
		# sliders every type uses stay visible
		if key in ["rotation_deg", "outer_radius", "scale", "line_thickness", "extrusion_depth", "repetition"]:
			show = true
		row.visible = show
	_palette_option.selected = maxi(_config.palette, 0)
	_fill_picker.color = _config.color_fill
	_accent_picker.color = _config.color_accent
	_line_picker.color = _config.color_line
	_fills_check.button_pressed = _config.show_fills
	_lines_check.button_pressed = _config.show_lines
	_guides_check.button_pressed = _config.show_guides
	_syncing = false
	_title_label.text = _config.type_name()


# --- Generation --------------------------------------------------------------

func _rebuild(reframe: bool) -> void:
	_config.clamp_values()
	var result := PatternEngine.generate_timed(_config)
	_geo = result[0]
	var msec: float = result[1]
	_full_rebuild_count += 1

	_viewport.clear_model()
	var layers := MeshBuilder.build_pattern_layers(_geo, _config)
	var colors := [_config.color_fill, _config.color_accent, _config.color_line]
	var roles := ["fill", "accent", "line"]
	var triangles := 0
	for i in layers.size():
		var mesh: ArrayMesh = layers[i]
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = MaterialLibrary.pattern_material(colors[i], roles[i])
		_viewport.add_model_node(mi)
		triangles += int(MeshBuilder.mesh_stats(mesh)["triangles"])

	if _config.show_guides:
		var guides := _build_guides_node()
		if guides != null:
			_viewport.add_model_node(guides)

	_viewport.set_backdrop_radius(_config.outer_radius * _config.scale * 1.3)
	if reframe:
		_viewport.frame_content(1.18)

	var stats := _geo.stats()
	_stats_label.text = "%d fills · %d accents · %d lines · %d triangles · generated in %.1f ms · seed %d" % [
		stats["fills"], stats["accents"], stats["segments"], triangles, msec, _config.seed]
	_update_math_text()


func _build_guides_node() -> Node3D:
	var root := Node3D.new()
	var segments: Array = []
	for circle: Vector3 in _geo.guide_circles:
		var centre := Vector2(circle.x, circle.y)
		var pts := MathUtils.arc_points(centre, circle.z, 0.0, TAU, 72)
		for i in pts.size() - 1:
			segments.append(PackedVector2Array([pts[i], pts[i + 1]]))
	for line: PackedVector2Array in _geo.guides:
		for i in line.size() - 1:
			segments.append(PackedVector2Array([line[i], line[i + 1]]))
	var z := _config.extrusion_depth + 0.05
	if not segments.is_empty():
		var mesh := MeshBuilder.build_ribbon_mesh(segments, PackedFloat32Array(), 0.018, z, 0.008, false)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = MaterialLibrary.get_material("guide_line")
		root.add_child(mi)
	var dots: Array = []
	for p in _geo.guide_points:
		dots.append(MathUtils.regular_dot(p, 0.045, 8))
	if not dots.is_empty():
		var mesh := MeshBuilder.build_slab_mesh(dots, z + 0.004, 0.01, 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = MaterialLibrary.get_material("guide_point")
		root.add_child(mi)
	return root


func _update_math_text() -> void:
	var lines: PackedStringArray = []
	var folds := _config.star_points
	var sides := _config.sides
	var r_out := _config.outer_radius
	var r_in := r_out * _config.inner_radius_ratio
	match _config.pattern_type:
		PatternConfig.PatternType.STAR, PatternConfig.PatternType.ROSETTE:
			lines.append("folds n = %d, angular step θ = 360°/%d = %.2f°" % [folds, folds, 360.0 / float(folds)])
			lines.append("outer radius R = %.3f, inner radius r = R·%.2f = %.3f" % [r_out, _config.inner_radius_ratio, r_in])
			lines.append("vertex k of 2n = %d:  R_k ∈ {R, r}, angle_k = k·θ/2 + φ" % (folds * 2))
			lines.append("P_k = (R_k·cos(angle_k), R_k·sin(angle_k)),  φ = %.1f°" % _config.rotation_deg)
			lines.append("side length between outer points = 2R·sin(π/n) = %.3f" % (2.0 * r_out * sin(PI / float(folds))))
		PatternConfig.PatternType.POLY_REGULAR, PatternConfig.PatternType.POLY_OVERLAP, \
		PatternConfig.PatternType.POLY_CONCENTRIC, PatternConfig.PatternType.POLY_RADIAL:
			lines.append("sides n = %d, angular step θ = 360°/%d = %.2f°" % [sides, sides, 360.0 / float(sides)])
			lines.append("circumradius R = %.3f" % r_out)
			lines.append("side length s = 2R·sin(π/n) = %.3f" % (2.0 * r_out * sin(PI / float(sides))))
			lines.append("interior angle = (n−2)·180°/n = %.2f°" % (float(sides - 2) * 180.0 / float(sides)))
			lines.append("apothem a = R·cos(π/n) = %.3f" % (r_out * cos(PI / float(sides))))
		PatternConfig.PatternType.TESS_SQUARE, PatternConfig.PatternType.TESS_HEX, PatternConfig.PatternType.TESS_TRIANGLE:
			var tile_angle := 90.0
			var per_vertex := 4
			if _config.pattern_type == PatternConfig.PatternType.TESS_HEX:
				tile_angle = 120.0
				per_vertex = 3
			elif _config.pattern_type == PatternConfig.PatternType.TESS_TRIANGLE:
				tile_angle = 60.0
				per_vertex = 6
			lines.append("tile edge s = %.3f units" % _config.tile_size)
			lines.append("tile interior angle = %.0f°" % tile_angle)
			lines.append("%d tiles meet at every vertex: %d × %.0f° = 360°" % [per_vertex, per_vertex, tile_angle])
			lines.append("cells per side = %d" % _config.repetition)
		PatternConfig.PatternType.GIRIH:
			lines.append("lattice spacing d = %.3f, star folds n = %d" % [_config.tile_size, folds])
			lines.append("star radius = 0.42·d = %.3f" % (_config.tile_size * 0.42))
			lines.append("strap width follows the star edge: 2·r_star·sin(π/n) = %.3f" % (2.0 * _config.tile_size * 0.42 * sin(PI / float(folds))))
			lines.append("centred medallion fold count = %d (symmetry slider)" % maxi(3, _config.symmetry_folds))
	var area := MathUtils.total_area(_geo.fills) + MathUtils.total_area(_geo.accents)
	lines.append("filled area ≈ %.3f units², extrusion depth = %.3f" % [area, _config.extrusion_depth])
	_math_label.text = "\n".join(lines)
	if _how_label != null:
		_how_label.text = String(TYPE_DESCRIPTIONS.get(_config.pattern_type, ""))


# --- Panel linking -----------------------------------------------------------

func _on_active_panel_changed(_panel_id: String) -> void:
	_update_target_label()


func _update_target_label() -> void:
	var panel_id := PatternLibrary.active_panel_id
	if panel_id.is_empty():
		_target_label.text = "No panel selected. Click a decorative panel in the Architecture Explorer to link it here."
		_apply_button.disabled = true
	else:
		_target_label.text = "Editing: %s — changes apply live when you press Apply to Panel." % PatternLibrary.panel_display_name(panel_id)
		_apply_button.disabled = false


func _on_apply_to_panel() -> void:
	var panel_id := PatternLibrary.active_panel_id
	if panel_id.is_empty():
		return
	PatternLibrary.assign_panel(panel_id, _config)
	toast_requested.emit("Pattern applied to %s." % PatternLibrary.panel_display_name(panel_id))


# --- Save / load / export ----------------------------------------------------

func _on_save() -> void:
	var err := PatternLibrary.save_pattern(_save_name.text, _config)
	if err.is_empty():
		toast_requested.emit("Saved pattern '%s'." % _save_name.text.strip_edges())
		_save_name.text = ""
		_refresh_load_list()
	else:
		toast_requested.emit(err)


func _refresh_load_list() -> void:
	if _load_option == null:
		return
	_load_option.clear()
	var names := PatternLibrary.list_saved_patterns()
	for i in names.size():
		_load_option.add_item(names[i], i)
	if names.is_empty():
		_load_option.add_item("(no saved patterns)", 0)
		_load_option.disabled = true
	else:
		_load_option.disabled = false


func _on_load() -> void:
	if _load_option.disabled:
		return
	var name := _load_option.get_item_text(_load_option.selected)
	var config := PatternLibrary.load_pattern(name)
	if config == null:
		toast_requested.emit("Could not load '%s'." % name)
		return
	_config.copy_from(config)
	_sync_controls()
	_rebuild(true)
	toast_requested.emit("Loaded pattern '%s'." % name)


func _on_delete() -> void:
	if _load_option.disabled:
		return
	var name := _load_option.get_item_text(_load_option.selected)
	PatternLibrary.delete_pattern(name)
	_refresh_load_list()
	toast_requested.emit("Deleted '%s'." % name)


func _on_export_view_png() -> void:
	var img: Image = await _viewport.capture_image()
	if img == null:
		toast_requested.emit("Export failed: no rendered image.")
		return
	var path := PatternViewport.default_export_path("view")
	if img.save_png(path) == OK:
		toast_requested.emit("Saved %s" % ProjectSettings.globalize_path(path))
	else:
		toast_requested.emit("Could not save the image.")


func _on_export_flat_png() -> void:
	var path: String = await _viewport.export_flat_png(_config, _geo, 1024, "")
	if path.is_empty():
		toast_requested.emit("Flat export failed.")
	else:
		toast_requested.emit("Saved flat pattern: %s" % ProjectSettings.globalize_path(path))


# --- Screen lifecycle --------------------------------------------------------

func on_shown() -> void:
	_update_target_label()
	if _geo == null:
		_rebuild(true)
	else:
		_viewport.frame_content(1.18)
