extends Control
## Mathematics & Learning — interactive construction demonstrations.
##
## Ten topics, each with a live 2D construction drawn by GeometryCanvas, a
## small set of controlling parameters, and a short explanation whose formula
## block uses the actual current numbers.

signal screen_requested(id: String)
signal toast_requested(text: String)

const TOPICS: Array = [
	{"id": "rotational", "title": "Rotational Symmetry", "topic": GeometryCanvas.Topic.ROTATIONAL, "lab_type": PatternConfig.PatternType.STAR},
	{"id": "reflection", "title": "Reflection Symmetry", "topic": GeometryCanvas.Topic.REFLECTION, "lab_type": -1},
	{"id": "radial", "title": "Radial Symmetry", "topic": GeometryCanvas.Topic.RADIAL, "lab_type": PatternConfig.PatternType.POLY_RADIAL},
	{"id": "polygon", "title": "Regular Polygons", "topic": GeometryCanvas.Topic.POLYGON, "lab_type": PatternConfig.PatternType.POLY_REGULAR},
	{"id": "star_polygon", "title": "Star Polygons {n/k}", "topic": GeometryCanvas.Topic.STAR_POLYGON, "lab_type": PatternConfig.PatternType.STAR},
	{"id": "tessellation", "title": "Tessellation", "topic": GeometryCanvas.Topic.TESSELLATION, "lab_type": PatternConfig.PatternType.TESS_SQUARE},
	{"id": "cartesian", "title": "Cartesian & Polar Coordinates", "topic": GeometryCanvas.Topic.CARTESIAN_POLAR, "lab_type": -1},
	{"id": "transform", "title": "Transformations (Matrices)", "topic": GeometryCanvas.Topic.TRANSFORM, "lab_type": -1},
	{"id": "star_example", "title": "Worked Example: an n-point Star", "topic": GeometryCanvas.Topic.STAR_EXAMPLE, "lab_type": PatternConfig.PatternType.STAR},
	{"id": "rosette", "title": "Rosette Drafting (Wedge Method)", "topic": GeometryCanvas.Topic.ROSETTE_DRAFT, "lab_type": PatternConfig.PatternType.ROSETTE},
]

const PARAM_SPECS: Dictionary = {
	"rotational": [{"key": "n", "label": "Divisions N", "min": 3, "max": 24, "step": 1, "value": 8, "decimals": 0}],
	"reflection": [{"key": "angle", "label": "Axis angle α", "min": 0, "max": 180, "step": 1, "value": 30, "decimals": 0, "suffix": "°"}],
	"radial": [
		{"key": "n", "label": "Divisions N", "min": 3, "max": 24, "step": 1, "value": 10, "decimals": 0},
		{"key": "rings", "label": "Rings", "min": 1, "max": 4, "step": 1, "value": 3, "decimals": 0},
	],
	"polygon": [{"key": "n", "label": "Sides N", "min": 3, "max": 24, "step": 1, "value": 8, "decimals": 0}],
	"star_polygon": [
		{"key": "n", "label": "Vertices n", "min": 3, "max": 16, "step": 1, "value": 7, "decimals": 0},
		{"key": "k", "label": "Step k", "min": 1, "max": 7, "step": 1, "value": 2, "decimals": 0},
	],
	"tessellation": [
		{"key": "shape", "label": "Tile shape", "choice": ["Square", "Hexagonal", "Triangular"], "value": 0},
		{"key": "rows", "label": "Rows", "min": 2, "max": 5, "step": 1, "value": 3, "decimals": 0},
	],
	"cartesian": [
		{"key": "r", "label": "Radius r", "min": 0.2, "max": 1.4, "step": 0.02, "value": 1.1, "decimals": 2},
		{"key": "theta", "label": "Angle θ", "min": 0, "max": 360, "step": 1, "value": 40, "decimals": 0, "suffix": "°"},
	],
	"transform": [
		{"key": "matrix", "label": "Operation", "choice": ["Rotation", "Uniform scale", "Reflection (y-axis)", "Shear"], "value": 0},
		{"key": "angle", "label": "Angle / shear", "min": 0, "max": 180, "step": 1, "value": 40, "decimals": 0, "suffix": "°"},
		{"key": "scale", "label": "Scale factor", "min": 0.4, "max": 1.8, "step": 0.05, "value": 1.3, "decimals": 2},
	],
	"star_example": [
		{"key": "n", "label": "Star points n", "min": 4, "max": 16, "step": 2, "value": 8, "decimals": 0},
		{"key": "inner", "label": "Inner / outer radius", "min": 0.2, "max": 0.9, "step": 0.01, "value": 0.45, "decimals": 2},
	],
	"rosette": [{"key": "n", "label": "Folds N", "min": 4, "max": 16, "step": 1, "value": 12, "decimals": 0}],
}

const EXPLANATIONS: Dictionary = {
	"rotational": "Rotational symmetry means the pattern maps onto itself when rotated about its centre by some angle. A copy of the motif is placed at every multiple of θ = 360°/N — the same operation the generators use for every radial pattern in NOOR.",
	"reflection": "Reflection symmetry mirrors geometry across an axis. Reflecting across a line at angle α is: rotate the shape so the axis becomes horizontal (rotate by −α), flip y, then rotate back by +α. Every rosette in this project is drafted by mirroring a single wedge.",
	"radial": "A radial arrangement places repeated elements on concentric rings around a common centre. The angular spacing on every ring is 360°/N, which is why radial patterns read as perfectly balanced wheels.",
	"polygon": "A regular polygon has equal sides and equal angles. Vertices sit on a construction circle at angles k·360°/N. The side length follows from the chord formula s = 2R·sin(π/N) and the interior angle is (N−2)·180°/N.",
	"star_polygon": "A star polygon {n/k} connects every k-th vertex of an n-gon, continuing until the path closes. If gcd(n,k) = 1 there is a single circuit; otherwise the figure splits into gcd(n,k) separate closed circuits — the mathematical reason some stars are 'woven' from several strokes.",
	"tessellation": "A tessellation covers the plane without gaps or overlaps. It only works when the interior angles meeting at every vertex sum to exactly 360° — four squares (4×90°), three hexagons (3×120°) or six triangles (6×60°).",
	"cartesian": "Polar coordinates describe a point by its distance r from the origin and its angle θ from the +X axis. Cartesian coordinates use perpendicular distances instead, and the two systems are linked by x = r·cosθ and y = r·sinθ. Rotating a point is trivial in polar form: only θ changes.",
	"transform": "Transformations map points to new positions using a 2×2 matrix: p′ = M·p. Rotation, scaling, reflection and shear all fit this form — and because matrices compose, several transformations can be applied as one combined matrix, which is exactly how the 3D studio rotates the extruded object.",
	"star_example": "This is the complete recipe for the star motifs used by the Star pattern type: choose n points, place outer vertices at radius R every 360°/n, then place inner vertices at radius r exactly halfway between them. The star is the polygon through those 2n alternating vertices.",
	"rosette": "The classic drafting method: design the motif once inside a wedge of 360°/N, then replicate it by rotation and reflection. Because the construction is symmetric by design, the result is perfectly balanced — the method used by real pattern-drafters for centuries and by the Rosette generator here.",
}

var _canvas: GeometryCanvas
var _topic_index := 0
var _topic_buttons: Array[Button] = []
var _param_box: HBoxContainer
var _explain_label: Label
var _formula_label: Label
var _lab_button: Button


func _ready() -> void:
	_build_ui()
	_select_topic(0)


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

	# --- topic list ---
	var list_stack := UIHelpers.panel_stack(288)
	var list_panel: PanelContainer = list_stack["panel"]
	var list_vbox: VBoxContainer = list_stack["vbox"]
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(UIHelpers.scroll_wrap(list_vbox))
	list_vbox.add_child(UIHelpers.title("Mathematics"))
	list_vbox.add_child(UIHelpers.muted("Ten interactive demonstrations of the mathematics behind the patterns.", 12))
	for i in TOPICS.size():
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, TOPICS[i]["title"]]
		button.theme_type_variation = &"NavButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: _select_topic(i))
		_topic_buttons.append(button)
		list_vbox.add_child(button)
	list_vbox.add_child(UIHelpers.spacer(6))
	var back := UIHelpers.button("Back to Menu", false, "")
	back.pressed.connect(func() -> void: screen_requested.emit("menu"))
	list_vbox.add_child(back)
	hbox.add_child(list_panel)

	# --- canvas column ---
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	var toolbar := HBoxContainer.new()
	var title := UIHelpers.label("Rotational Symmetry", 20, NoorTheme.GOLD_LIGHT)
	title.name = "TopicTitle"
	toolbar.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	var animate_row := UIHelpers.check_row("Animate", true, "Animate the construction.")
	animate_row["check"].toggled.connect(_on_animate_toggled)
	toolbar.add_child(animate_row["row"])
	center.add_child(toolbar)

	_canvas = GeometryCanvas.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(_canvas)
	_param_box = HBoxContainer.new()
	_param_box.add_theme_constant_override("separation", 16)
	center.add_child(_param_box)
	hbox.add_child(center)

	# --- explanation column ---
	var right_stack := UIHelpers.panel_stack(330)
	var right_panel: PanelContainer = right_stack["panel"]
	var right_vbox: VBoxContainer = right_stack["vbox"]
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(UIHelpers.scroll_wrap(right_vbox))
	right_vbox.add_child(UIHelpers.title("Explanation"))
	_explain_label = UIHelpers.wrapped("", 14)
	right_vbox.add_child(_explain_label)
	right_vbox.add_child(UIHelpers.section("Live values"))
	_formula_label = UIHelpers.formula("")
	right_vbox.add_child(_formula_label)
	right_vbox.add_child(UIHelpers.spacer(8))
	_lab_button = UIHelpers.button("Open in Geometry Laboratory", true,
		"Continue this construction in the pattern workbench.")
	_lab_button.pressed.connect(_on_open_in_lab)
	right_vbox.add_child(_lab_button)
	hbox.add_child(right_panel)


func _on_animate_toggled(on: bool) -> void:
	_canvas.set_param("animate", on)


func _select_topic(index: int) -> void:
	_topic_index = index
	var topic: Dictionary = TOPICS[index]
	for i in _topic_buttons.size():
		_topic_buttons[i].button_pressed = false
	_topic_buttons[index].button_pressed = true
	_canvas.set_topic(topic["topic"])
	_build_params(topic["id"])
	var title := _find_topic_title()
	if title != null:
		title.text = String(topic["title"])
	_explain_label.text = String(EXPLANATIONS.get(topic["id"], ""))
	_lab_button.visible = int(topic["lab_type"]) >= 0
	_update_formulas()


func _find_topic_title() -> Label:
	var node := find_child("TopicTitle", true, false)
	return node as Label


func _build_params(topic_id: String) -> void:
	for child in _param_box.get_children():
		child.queue_free()
	var specs: Array = PARAM_SPECS.get(topic_id, [])
	for spec: Dictionary in specs:
		if spec.has("choice"):
			var row := UIHelpers.dropdown_row(String(spec["label"]), PackedStringArray(spec["choice"]),
				int(spec["value"]), "")
			var option: OptionButton = row["option"]
			var key := String(spec["key"])
			option.item_selected.connect(func(i: int) -> void:
				_canvas.set_param(key, i)
				_update_formulas())
			row["row"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_param_box.add_child(row["row"])
		else:
			var key := String(spec["key"])
			var row := UIHelpers.slider_row(String(spec["label"]),
				float(spec["min"]), float(spec["max"]), float(spec["step"]), float(spec["value"]),
				"", int(spec.get("decimals", 1)), String(spec.get("suffix", "")))
			var slider: HSlider = row["slider"]
			slider.value_changed.connect(func(v: float) -> void:
				_canvas.set_param(key, v)
				_update_formulas())
			row["row"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_param_box.add_child(row["row"])


func _update_formulas() -> void:
	var topic_id := String(TOPICS[_topic_index]["id"])
	var p := _canvas.params
	var lines: PackedStringArray = []
	match topic_id:
		"rotational":
			var n := int(p["n"])
			lines.append("θ = 360° / %d = %.2f°" % [n, 360.0 / float(n)])
			lines.append("M_i = [cos iθ  −sin iθ ;  sin iθ  cos iθ]")
			lines.append("order of symmetry: N = %d" % n)
		"reflection":
			var a := deg_to_rad(float(p["angle"]))
			lines.append("axis α = %.0f°,  2α = %.0f°" % [float(p["angle"]), 2.0 * float(p["angle"])])
			lines.append("p′ = (x·cos2α + y·sin2α,  x·sin2α − y·cos2α)")
			lines.append("cos2α = %+.3f,  sin2α = %+.3f" % [cos(2.0 * a), sin(2.0 * a)])
		"radial":
			var n := int(p["n"])
			var rings := int(p["rings"])
			lines.append("Δθ = 360° / %d = %.2f°" % [n, 360.0 / float(n)])
			lines.append("rings = %d,  total elements = %d × %d = %d" % [rings, rings, n, rings * n])
		"polygon":
			var n := int(p["n"])
			lines.append("θ = 360°/%d = %.2f°" % [n, 360.0 / float(n)])
			lines.append("side s = 2R·sin(π/%d) = %.3f·R" % [n, 2.0 * sin(PI / float(n))])
			lines.append("apothem a = R·cos(π/%d) = %.3f·R" % [n, cos(PI / float(n))])
			lines.append("interior angle = %.2f°,  sum = %.1f°" % [
				float(n - 2) * 180.0 / float(n), float(n - 2) * 180.0])
		"star_polygon":
			var n := int(p["n"])
			var k := int(p["k"])
			var g := _gcd(n, k)
			lines.append("{n/k} = {%d/%d},  step = %d·360°/%d = %.2f°" % [n, k, k, n, 360.0 * float(k) / float(n)])
			lines.append("gcd(%d, %d) = %d → %s" % [n, k, g, "1 circuit" if g == 1 else "%d circuits" % g])
			lines.append("vertices visited per circuit = %d" % int(n / g))
		"tessellation":
			var shape := int(p["shape"])
			var names := ["square", "hexagon", "triangle"]
			var angle := [90.0, 120.0, 60.0]
			var count := [4, 3, 6]
			lines.append("tile: %s,  interior angle = %.0f°" % [names[shape], angle[shape]])
			lines.append("%d × %.0f° = %.0f°  at every vertex" % [count[shape], angle[shape], count[shape] * angle[shape]])
			lines.append("vertices: each is shared by %d tiles" % count[shape])
		"cartesian":
			var r := float(p["r"])
			var theta := deg_to_rad(float(p["theta"]))
			var x := r * cos(theta)
			var y := r * sin(theta)
			lines.append("x = r·cosθ = %.2f · %.3f = %.3f" % [r, cos(theta), x])
			lines.append("y = r·sinθ = %.2f · %.3f = %.3f" % [r, sin(theta), y])
			lines.append("r = √(x² + y²) = %.3f,  θ = atan2(y, x) = %.1f°" % [sqrt(x * x + y * y), rad_to_deg(atan2(y, x))])
		"transform":
			var matrix := int(p["matrix"])
			var angle := deg_to_rad(float(p["angle"]))
			var scale_factor := float(p["scale"])
			match matrix:
				0:
					lines.append("[cosθ  −sinθ ;  sinθ  cosθ],  θ = %.0f°" % float(p["angle"]))
					lines.append("= [%+.3f  %+.3f ; %+.3f  %+.3f]" % [cos(angle), -sin(angle), sin(angle), cos(angle)])
				1:
					lines.append("[s  0 ; 0  s],  s = %.2f" % scale_factor)
					lines.append("area scales by s² = %.3f" % (scale_factor * scale_factor))
				2:
					lines.append("[−1  0 ; 0  1]  (det = −1, orientation flips)")
				3:
					lines.append("[1  0 ; tan(θ/2)  1],  θ = %.0f°" % float(p["angle"]))
					lines.append("shear preserves area (det = 1)")
		"star_example":
			var n := int(p["n"])
			var inner := float(p["inner"])
			lines.append("folds n = %d → 2n = %d vertices" % [n, n * 2])
			lines.append("θ = 360°/%d = %.2f°,  half step = %.2f°" % [n, 360.0 / float(n), 180.0 / float(n)])
			lines.append("R = 1.15,  r = R × %.2f = %.3f" % [inner, 1.15 * inner])
		"rosette":
			var n := int(p["n"])
			lines.append("wedge = 360°/%d = %.2f°" % [n, 360.0 / float(n)])
			lines.append("copies = N rotations × 2 (mirror) = %d" % (n * 2))
			lines.append("reflection axes = N = %d" % n)
	_formula_label.text = "\n".join(lines)


func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return maxi(a, 1)


func _on_open_in_lab() -> void:
	var topic: Dictionary = TOPICS[_topic_index]
	var lab_type := int(topic["lab_type"])
	if lab_type < 0:
		return
	var config: PatternConfig = PatternLibrary.make_preset(lab_type)
	var p := _canvas.params
	match String(topic["id"]):
		"rotational":
			config.star_points = int(p["n"])
		"radial":
			config.symmetry_folds = int(p["n"])
			config.repetition = int(p["rings"])
		"polygon":
			config.sides = int(p["n"])
		"star_polygon":
			config.star_points = int(p["n"])
			config.inner_radius_ratio = 0.5
		"tessellation":
			var shape := int(p["shape"])
			config = PatternLibrary.make_preset([
				PatternConfig.PatternType.TESS_SQUARE,
				PatternConfig.PatternType.TESS_HEX,
				PatternConfig.PatternType.TESS_TRIANGLE][shape])
		"star_example":
			config.star_points = int(p["n"])
			config.inner_radius_ratio = float(p["inner"])
		"rosette":
			config.star_points = int(p["n"])
			config.symmetry_folds = int(p["n"])
	config.clamp_values()
	PatternLibrary.lab_config.copy_from(config)
	PatternLibrary.lab_config.pattern_type = config.pattern_type
	PatternLibrary.set_active_panel("")
	screen_requested.emit("lab")
	toast_requested.emit("Loaded the demonstration into the Geometry Laboratory.")
