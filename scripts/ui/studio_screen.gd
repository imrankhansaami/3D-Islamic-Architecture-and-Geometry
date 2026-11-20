extends Control
## 3D Transformation Studio — turns a generated 2D pattern into a 3D object.
##
## Extrudes the pattern, applies a chamfer (bevel), lets the user assign real
## materials, rotate the object interactively (the rotation matrix is shown
## live), and export PNG / OBJ. All measurements are computed from the actual
## generated geometry.

signal screen_requested(id: String)
signal toast_requested(text: String)

const MATERIAL_CHOICES: PackedStringArray = [
	"Palette colours", "Ivory Stone", "Sandstone", "Marble", "Dark Wood",
	"Bronze", "Gold Accent", "Turquoise Tile", "Emerald Surface",
]
const MATERIAL_IDS: PackedStringArray = [
	"", "ivory_stone", "sandstone", "marble", "dark_wood",
	"bronze", "gold", "turquoise_tile", "emerald_surface",
]
const BACKGROUNDS: Array = [
	["Studio Dark", "studio"], ["Gallery Light", "gallery"], ["Night Gold", "night_gold"],
]

var _config: PatternConfig
var _geo: PatternGeometry = null
var _viewport: PatternViewport
var _model: Node3D = null
var _layers: Array[Node] = []
var _rot_deg := Vector3.ZERO

var _type_label: Label
var _stats_label: Label
var _measure_label: Label
var _matrix_label: Label
var _extrusion_slider: HSlider
var _bevel_slider: HSlider
var _scale_slider: HSlider
var _rot_sliders: Dictionary = {}
var _material_option: OptionButton
var _background_option: OptionButton
var _timer: Timer
var _syncing := false


func _ready() -> void:
	if PatternLibrary.studio_config == null:
		PatternLibrary.studio_config = PatternLibrary.lab_config.clone()
	_config = PatternLibrary.studio_config
	_build_ui()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.09
	_timer.timeout.connect(func() -> void: _rebuild(false))
	add_child(_timer)
	_sync_controls()
	_rebuild(true)


# --- UI ----------------------------------------------------------------------

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
	var stack := UIHelpers.panel_stack(340)
	var panel: PanelContainer = stack["panel"]
	var vbox: VBoxContainer = stack["vbox"]
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(UIHelpers.scroll_wrap(vbox))

	vbox.add_child(UIHelpers.title("3D Studio"))
	_type_label = UIHelpers.wrapped("", 14, NoorTheme.SAND)
	vbox.add_child(_type_label)
	var load_button := UIHelpers.button("Load from Laboratory", true, "Take the pattern currently in the Geometry Laboratory.")
	load_button.pressed.connect(func() -> void:
		_config.copy_from(PatternLibrary.lab_config)
		_config.pattern_type = PatternLibrary.lab_config.pattern_type
		_sync_controls()
		_rebuild(true)
		toast_requested.emit("Loaded '%s' from the laboratory." % _config.type_name()))
	vbox.add_child(load_button)

	vbox.add_child(UIHelpers.section("2D → 3D Extrusion"))
	var extrusion_row := UIHelpers.slider_row("Extrusion Depth", 0.0, 1.2, 0.005, _config.extrusion_depth,
		"The pattern's plane geometry is extruded along +Z by this depth.", 3)
	_extrusion_slider = extrusion_row["slider"]
	_extrusion_slider.value_changed.connect(func(v: float) -> void:
		if _syncing: return
		_config.extrusion_depth = v
		_schedule())
	vbox.add_child(extrusion_row["row"])

	var bevel_row := UIHelpers.slider_row("Bevel (chamfer)", 0.0, 0.4, 0.005, _config.bevel,
		"Chamfers the top and bottom edges of every extruded shape.", 3)
	_bevel_slider = bevel_row["slider"]
	_bevel_slider.value_changed.connect(func(v: float) -> void:
		if _syncing: return
		_config.bevel = v
		_schedule())
	vbox.add_child(bevel_row["row"])

	var scale_row := UIHelpers.slider_row("Scale", 0.2, 3.0, 0.01, _config.scale,
		"Uniform scale of the 3D object.", 2)
	_scale_slider = scale_row["slider"]
	_scale_slider.value_changed.connect(func(v: float) -> void:
		if _syncing: return
		_config.scale = v
		_schedule())
	vbox.add_child(scale_row["row"])

	vbox.add_child(UIHelpers.section("Object Transform"))
	for axis: Array in [["X", Vector3(1, 0, 0)], ["Y", Vector3(0, 1, 0)], ["Z", Vector3(0, 0, 1)]]:
		var row := UIHelpers.slider_row("Rotation %s" % axis[0], -180.0, 180.0, 1.0, 0.0,
			"Rotate the object about the %s axis (a live transformation matrix)." % axis[0], 0, "°")
		var slider: HSlider = row["slider"]
		var axis_vec: Vector3 = axis[1]
		slider.value_changed.connect(func(v: float) -> void:
			if _syncing: return
			if axis_vec.x > 0.5: _rot_deg.x = v
			elif axis_vec.y > 0.5: _rot_deg.y = v
			else: _rot_deg.z = v
			_apply_rotation())
		_rot_sliders[axis[0]] = slider
		vbox.add_child(row["row"])

	vbox.add_child(UIHelpers.section("Material & Background"))
	var material_row := UIHelpers.dropdown_row("Material", MATERIAL_CHOICES, 0,
		"Apply a real material to every layer, or keep the pattern palette colours.")
	_material_option = material_row["option"]
	_material_option.item_selected.connect(func(_i: int) -> void: _apply_materials())
	vbox.add_child(material_row["row"])

	var background_names := PackedStringArray()
	for entry: Array in BACKGROUNDS:
		background_names.append(entry[0])
	var background_row := UIHelpers.dropdown_row("Background", background_names, 0,
		"Preview environment (studio / gallery / night).")
	_background_option = background_row["option"]
	_background_option.item_selected.connect(func(i: int) -> void:
		_viewport.set_environment_preset(BACKGROUNDS[i][1]))
	vbox.add_child(background_row["row"])

	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 6)
	var autorotate := UIHelpers.check_row("Auto-rotate", false, "Continuously rotate the object.")
	autorotate["check"].toggled.connect(func(on: bool) -> void: _viewport.set_autorotate(on, 0.55, "spin"))
	extras.add_child(autorotate["row"])
	var wireframe := UIHelpers.check_row("Wireframe", false, "Show only the mesh edges.")
	wireframe["check"].toggled.connect(func(on: bool) -> void: _viewport.set_wireframe(on))
	extras.add_child(wireframe["row"])
	vbox.add_child(extras)

	vbox.add_child(UIHelpers.section("Export"))
	var export_box := HBoxContainer.new()
	export_box.add_theme_constant_override("separation", 6)
	var png_button := UIHelpers.button("Export PNG", false, "Save the current 3D preview.")
	png_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	png_button.pressed.connect(_on_export_png)
	export_box.add_child(png_button)
	var obj_button := UIHelpers.button("Export OBJ", false, "Save the 3D object as a Wavefront OBJ model.")
	obj_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_button.pressed.connect(_on_export_obj)
	export_box.add_child(obj_button)
	vbox.add_child(export_box)

	vbox.add_child(UIHelpers.section("Go Back"))
	var lab_button := UIHelpers.button("Open Geometry Laboratory", false, "Return to the pattern workbench.")
	lab_button.pressed.connect(func() -> void: screen_requested.emit("lab"))
	vbox.add_child(lab_button)
	return panel


func _build_center_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)

	var toolbar := HBoxContainer.new()
	var title := UIHelpers.label("3D Transformation Studio", 20, NoorTheme.GOLD_LIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	for preset: Array in [["Front", "front"], ["Top", "top"], ["Iso", "iso"], ["Side", "side"]]:
		var button := UIHelpers.button(preset[0], false, "Jump to the %s view." % preset[0].to_lower())
		button.theme_type_variation = &"ToolButton"
		button.pressed.connect(func() -> void: _viewport.set_view(preset[1]))
		toolbar.add_child(button)
	var reframe := UIHelpers.button("Frame", false, "Re-centre the object in the view.")
	reframe.theme_type_variation = &"ToolButton"
	reframe.pressed.connect(func() -> void: _viewport.frame_content(1.3))
	toolbar.add_child(reframe)
	column.add_child(toolbar)

	_viewport = preload("res://scenes/geometry/pattern_viewport.tscn").instantiate()
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_viewport)

	_stats_label = UIHelpers.muted("", 12)
	column.add_child(_stats_label)
	return column


func _build_right_panel() -> Control:
	var stack := UIHelpers.panel_stack(320)
	var panel: PanelContainer = stack["panel"]
	var vbox: VBoxContainer = stack["vbox"]
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(UIHelpers.scroll_wrap(vbox))

	vbox.add_child(UIHelpers.title("Object Data"))
	vbox.add_child(UIHelpers.section("Measurements"))
	_measure_label = UIHelpers.formula("")
	vbox.add_child(_measure_label)
	vbox.add_child(UIHelpers.section("Transformation Matrix"))
	_matrix_label = UIHelpers.formula("")
	vbox.add_child(_matrix_label)
	vbox.add_child(UIHelpers.section("Extrusion explained"))
	vbox.add_child(UIHelpers.wrapped(
		"Each closed polygon of the pattern becomes a prism: its 2D outline is triangulated by a fan from the polygon centre (valid for star-shaped outlines), duplicated at z = 0 and z = depth, and the walls are quads.\n\nWith a bevel, two extra inset loops are inserted near the caps so the top and bottom edges are chamfered — the inset is a uniform scale towards the polygon centroid.\n\nLines become thin extruded ribbons with junction dots where segments meet, so corners never show gaps.",
		13, NoorTheme.MUTED))
	return panel


# --- Behaviour ---------------------------------------------------------------

func _schedule() -> void:
	_timer.start()


func _sync_controls() -> void:
	_syncing = true
	_extrusion_slider.value = _config.extrusion_depth
	_bevel_slider.value = _config.bevel
	_scale_slider.value = _config.scale
	for axis: String in _rot_sliders:
		_rot_sliders[axis].value = 0.0
	_rot_deg = Vector3.ZERO
	_syncing = false
	_type_label.text = "Source pattern: %s" % _config.type_name()


func _rebuild(reframe: bool) -> void:
	_config.clamp_values()
	var result := PatternEngine.generate_timed(_config)
	_geo = result[0]
	var msec: float = result[1]

	_viewport.clear_model()
	_model = Node3D.new()
	_layers.clear()
	var layers := MeshBuilder.build_pattern_layers(_geo, _config)
	for i in layers.size():
		var mesh: ArrayMesh = layers[i]
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		_layers.append(mi)
		_model.add_child(mi)
	_viewport.add_model_node(_model)
	_viewport.set_backdrop_radius(_config.outer_radius * _config.scale * 1.15)
	_apply_materials()
	_apply_rotation()
	if reframe:
		_viewport.frame_content(1.25)

	var triangles := 0
	for layer: Node in _layers:
		triangles += int(MeshBuilder.mesh_stats((layer as MeshInstance3D).mesh)["triangles"])
	_stats_label.text = "generated in %.1f ms · %d triangles · depth %.3f · bevel %.3f" % [
		msec, triangles, _config.extrusion_depth, _config.bevel]
	_update_measurements(triangles)


func _apply_materials() -> void:
	if _layers.is_empty():
		return
	var choice := _material_option.selected
	var colors := [_config.color_fill, _config.color_accent, _config.color_line]
	var roles := ["fill", "accent", "line"]
	for i in _layers.size():
		var mi := _layers[i] as MeshInstance3D
		if choice == 0:
			mi.material_override = MaterialLibrary.pattern_material(colors[mini(i, 2)], roles[mini(i, 2)])
		else:
			mi.material_override = MaterialLibrary.get_material(MATERIAL_IDS[choice])


func _apply_rotation() -> void:
	if _model == null:
		return
	# Explicit composition R = Rz(γ)·Ry(β)·Rx(α) (X applied first), matching
	# the matrix shown in the data panel.
	var euler := Vector3(deg_to_rad(_rot_deg.x), deg_to_rad(_rot_deg.y), deg_to_rad(_rot_deg.z))
	var rx := Basis(Vector3.RIGHT, euler.x)
	var ry := Basis(Vector3.UP, euler.y)
	var rz := Basis(Vector3.BACK, euler.z)
	var basis := rz * ry * rx
	var transform := _model.transform
	transform.basis = basis
	_model.transform = transform
	_update_matrix(basis)


func _update_matrix(basis: Basis) -> void:
	_matrix_label.text = "R = Rz(%.0f°)·Ry(%.0f°)·Rx(%.0f°)\n[ %+.3f  %+.3f  %+.3f ]\n[ %+.3f  %+.3f  %+.3f ]\n[ %+.3f  %+.3f  %+.3f ]" % [
		_rot_deg.z, _rot_deg.y, _rot_deg.x,
		basis.x.x, basis.y.x, basis.z.x,
		basis.x.y, basis.y.y, basis.z.y,
		basis.x.z, basis.y.z, basis.z.z]


func _update_measurements(triangles: int) -> void:
	var area := MathUtils.total_area(_geo.fills) + MathUtils.total_area(_geo.accents)
	var volume := area * _config.extrusion_depth
	var bounds := _geo.bounds
	_measure_label.text = "filled area A = %.3f units²\nextrusion d = %.3f units\nvolume ≈ A × d = %.3f units³\npattern bounds: %.2f × %.2f units\nmesh triangles: %d" % [
		area, _config.extrusion_depth, volume, bounds.size.x, bounds.size.y, triangles]


# --- Export ------------------------------------------------------------------

func _on_export_png() -> void:
	var img: Image = await _viewport.capture_image()
	if img == null:
		toast_requested.emit("Export failed: no rendered image.")
		return
	var path := PatternViewport.default_export_path("studio")
	if img.save_png(path) == OK:
		toast_requested.emit("Saved %s" % ProjectSettings.globalize_path(path))
	else:
		toast_requested.emit("Could not save the image.")


func _on_export_obj() -> void:
	if _model == null:
		return
	var nodes: Array = []
	for child in _model.get_children():
		nodes.append(child)
	var path := MeshExporter.default_export_path("object", "obj")
	var saved := MeshExporter.export_obj(nodes, path)
	if saved.is_empty():
		toast_requested.emit("OBJ export failed.")
	else:
		toast_requested.emit("Saved 3D object: %s" % ProjectSettings.globalize_path(saved))


func on_shown() -> void:
	if _geo == null:
		_rebuild(true)
	else:
		_viewport.frame_content(1.25)
