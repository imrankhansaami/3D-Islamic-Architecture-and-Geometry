class_name GeometryCanvas
extends Control
## Interactive 2D construction canvas for the Mathematics & Learning mode.
##
## Draws every demonstration with the Godot 2D canvas API (lines, arcs,
## polygons, text) — deliberately 2D, so the mathematics is easy to read.
## The demonstrations animate subtly to draw attention to the construction
## (animated angular sweeps, advancing vertices, mirrored copies).

enum Topic {
	ROTATIONAL,
	REFLECTION,
	RADIAL,
	POLYGON,
	STAR_POLYGON,
	TESSELLATION,
	CARTESIAN_POLAR,
	TRANSFORM,
	STAR_EXAMPLE,
	ROSETTE_DRAFT,
}

const BG := Color(0.043, 0.078, 0.114, 0.85)
const GRID := Color(0.788, 0.635, 0.153, 0.10)
const IVORY := Color(0.949, 0.925, 0.863)
const MUTED := Color(0.624, 0.690, 0.749, 0.85)
const GOLD := Color(0.890, 0.773, 0.404)
const EMERALD := Color(0.11, 0.70, 0.53)
const ACCENT_FILL := Color(0.788, 0.635, 0.153, 0.18)

var topic: int = Topic.ROTATIONAL
var params: Dictionary = {
	"n": 8, "angle": 30.0, "k": 2, "rows": 3, "shape": 0,
	"r": 1.1, "theta": 40.0, "inner": 0.45, "matrix": 0, "scale": 1.3,
	"animate": true,
}
var _phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if bool(params.get("animate", true)):
		_phase += delta
		queue_redraw()


func set_topic(new_topic: int) -> void:
	topic = new_topic
	_phase = 0.0
	queue_redraw()


func set_param(key: String, value: Variant) -> void:
	params[key] = value
	queue_redraw()


func _font() -> Font:
	return ThemeDB.fallback_font


# --- Coordinate mapping ------------------------------------------------------

func _centre() -> Vector2:
	return size * 0.5


func _unit() -> float:
	return minf(size.x, size.y) * 0.34


func _map(p: Vector2) -> Vector2:
	return _centre() + p * _unit()


func _inv_unit() -> float:
	return maxf(_unit(), 1.0)


# --- Drawing primitives ------------------------------------------------------

func _line(a: Vector2, b: Vector2, color: Color, width: float = 1.6) -> void:
	draw_line(_map(a), _map(b), color, width, true)


func _dashed(a: Vector2, b: Vector2, color: Color, width: float = 1.2) -> void:
	draw_dashed_line(_map(a), _map(b), color, width, 6.0, true)


func _poly(points: PackedVector2Array, color: Color, closed: bool = true, width: float = 2.0) -> void:
	if points.size() < 2:
		return
	var screen := PackedVector2Array()
	for p in points:
		screen.append(_map(p))
	if closed:
		screen.append(screen[0])
	draw_polyline(screen, color, width, true)


func _fill_poly(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var screen := PackedVector2Array()
	for p in points:
		screen.append(_map(p))
	draw_colored_polygon(screen, color)


func _dot(p: Vector2, color: Color, radius: float = 4.0) -> void:
	draw_circle(_map(p), radius, color)


func _circle_guide(centre: Vector2, radius: float, color: Color, width: float = 1.2) -> void:
	draw_arc(_map(centre), radius * _unit(), 0.0, TAU, 96, color, width, true)


func _arc_guide(centre: Vector2, radius: float, from: float, to: float, color: Color, width: float = 2.0) -> void:
	draw_arc(_map(centre), radius * _unit(), from, to, 48, color, width, true)


func _label(p: Vector2, text: String, color: Color = IVORY, font_size: int = 13, offset: Vector2 = Vector2(8, -8)) -> void:
	draw_string(_font(), _map(p) + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _label_screen(p: Vector2, text: String, color: Color = IVORY, font_size: int = 13) -> void:
	draw_string(_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_axes() -> void:
	var extent := 1.45
	_line(Vector2(-extent, 0), Vector2(extent, 0), GRID, 1.2)
	_line(Vector2(0, -extent), Vector2(0, extent), GRID, 1.2)


func _draw_grid() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var step := _unit() * 0.25
	if step < 8.0:
		return
	var centre := _centre()
	var x := centre.x
	while x > 0:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID, 1.0)
		x -= step
	x = centre.x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID, 1.0)
		x += step
	var y := centre.y
	while y > 0:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID, 1.0)
		y -= step
	y = centre.y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID, 1.0)
		y += step


# --- Main draw ---------------------------------------------------------------

func _draw() -> void:
	_draw_grid()
	match topic:
		Topic.ROTATIONAL: _draw_rotational()
		Topic.REFLECTION: _draw_reflection()
		Topic.RADIAL: _draw_radial()
		Topic.POLYGON: _draw_polygon()
		Topic.STAR_POLYGON: _draw_star_polygon()
		Topic.TESSELLATION: _draw_tessellation()
		Topic.CARTESIAN_POLAR: _draw_cartesian_polar()
		Topic.TRANSFORM: _draw_transform()
		Topic.STAR_EXAMPLE: _draw_star_example()
		Topic.ROSETTE_DRAFT: _draw_rosette_draft()


# --- 1. Rotational symmetry --------------------------------------------------

func _draw_rotational() -> void:
	var n: int = int(params["n"])
	var step := TAU / float(n)
	_circle_guide(Vector2.ZERO, 1.15, MUTED, 1.0)
	# animated wedge highlight
	var highlight := int(_phase * 1.2) % n
	var a0 := step * float(highlight)
	draw_colored_polygon(PackedVector2Array([
		_map(Vector2.ZERO),
		_map(MathUtils.polar_to_cart(1.15, a0)),
		_map(MathUtils.polar_to_cart(1.15, a0 + step)),
	]), ACCENT_FILL)
	# spokes and motif copies
	var motif := PackedVector2Array([
		Vector2(0.55, -0.09), Vector2(1.05, 0.0), Vector2(0.55, 0.09), Vector2(0.7, 0.0),
	])
	for i in n:
		var angle := step * float(i)
		_dashed(Vector2.ZERO, MathUtils.polar_to_cart(1.2, angle), GRID, 1.0)
		var copy := MathUtils.rotate_points(motif, angle)
		var is_highlight := i == highlight
		_poly(copy, GOLD if is_highlight else IVORY, true, 2.2 if is_highlight else 1.6)
		_dot(MathUtils.polar_to_cart(1.05, angle), GOLD if is_highlight else MUTED, 3.5)
	_arc_guide(Vector2.ZERO, 0.5, 0.0, step, EMERALD, 2.0)
	_label(MathUtils.polar_to_cart(0.55, step * 0.5), "θ = %.1f°" % rad_to_deg(step), EMERALD, 14, Vector2(6, 4))
	_dot(Vector2.ZERO, IVORY, 4.0)
	_label_screen(Vector2(16, 28), "Rotational symmetry of order N = %d" % n, GOLD, 15)
	_label_screen(Vector2(16, 48), "copy i: rotate(p, i·θ),  θ = 360°/N = %.2f°" % rad_to_deg(step), MUTED, 13)


# --- 2. Reflection symmetry --------------------------------------------------

func _draw_reflection() -> void:
	var axis := deg_to_rad(float(params["angle"]))
	var motif := PackedVector2Array([
		Vector2(0.25, 0.1), Vector2(0.95, 0.35), Vector2(0.8, 0.75), Vector2(0.45, 0.5),
	])
	# axis of reflection
	_dashed(MathUtils.polar_to_cart(1.5, axis), MathUtils.polar_to_cart(-1.5, axis), GOLD, 1.6)
	_label(MathUtils.polar_to_cart(1.35, axis), "axis α = %.0f°" % float(params["angle"]), GOLD, 13)
	var mirror := MathUtils.mirror_points_axis(motif, axis)
	var pulse := 0.35 + 0.65 * absf(sin(_phase * 1.4))
	# perpendicular guide from a sample point to its image
	var sample := motif[1]
	var sample_mirror := mirror[1]
	_dashed(sample, sample_mirror, EMERALD, 1.4)
	_dot(sample, IVORY, 4.0)
	_dot(sample_mirror, Color(GOLD.r, GOLD.g, GOLD.b, pulse), 4.0)
	_label(sample, "p", IVORY)
	_label(sample_mirror, "p′", Color(GOLD.r, GOLD.g, GOLD.b, pulse))
	_poly(motif, IVORY, true, 2.0)
	_fill_poly(motif, Color(0.95, 0.93, 0.86, 0.12))
	_poly(mirror, Color(GOLD.r, GOLD.g, GOLD.b, pulse), true, 2.0)
	_fill_poly(mirror, Color(GOLD.r, GOLD.g, GOLD.b, 0.10 * pulse))
	_label_screen(Vector2(16, 28), "Reflection symmetry", GOLD, 15)
	_label_screen(Vector2(16, 48), "p′ = R(2α)·p̄   (rotate to axis, flip y, rotate back)", MUTED, 13)


# --- 3. Radial symmetry ------------------------------------------------------

func _draw_radial() -> void:
	var n: int = int(params["n"])
	var rings: int = int(params["rings"]) if params.has("rings") else int(params["rows"])
	var step := TAU / float(n)
	_circle_guide(Vector2.ZERO, 1.2, GRID, 1.0)
	for ring in rings:
		var radius := 0.4 + 0.32 * float(ring)
		_circle_guide(Vector2.ZERO, radius, Color(MUTED.r, MUTED.g, MUTED.b, 0.35), 1.0)
		var pulse_ring := int(_phase * 1.5) % maxi(rings, 1)
		for i in n:
			var angle := step * float(i) + (PI / float(n)) * float(ring % 2)
			var p := MathUtils.polar_to_cart(radius, angle)
			var is_current := ring == pulse_ring and i == int(_phase * 2.0 * float(n)) % n
			var size_factor := 0.06 + 0.02 * float(ring)
			var petal := MathUtils.star_vertices(4, size_factor, size_factor * 0.42, angle)
			_poly(MathUtils.translate_points(petal, p), GOLD if is_current else IVORY, true, 1.5)
			_dot(p, EMERALD if is_current else MUTED, 2.5)
	_arc_guide(Vector2.ZERO, 1.3, 0.0, step, EMERALD, 2.0)
	_label(MathUtils.polar_to_cart(1.32, step * 0.5), "Δθ = %.1f°" % rad_to_deg(step), EMERALD, 13, Vector2(4, 0))
	_dot(Vector2.ZERO, GOLD, 4.5)
	_label_screen(Vector2(16, 28), "Radial arrangement, N = %d, rings = %d" % [n, rings], GOLD, 15)
	_label_screen(Vector2(16, 48), "element (i, ring): r = ring radius, angle = i·360°/N + offset", MUTED, 13)


# --- 4. Regular polygons -----------------------------------------------------

func _draw_polygon() -> void:
	var n: int = int(params["n"])
	var radius := 1.1
	var rot := -PI * 0.5 + PI / float(n)
	var step := TAU / float(n)
	_circle_guide(Vector2.ZERO, radius, MUTED, 1.1)
	var verts := MathUtils.polygon_vertices(n, radius, rot)
	# fill
	_fill_poly(verts, Color(0.11, 0.70, 0.53, 0.10))
	# radius lines
	for v in verts:
		_dashed(Vector2.ZERO, v, GRID, 1.0)
	# edges
	_poly(verts, GOLD, true, 2.2)
	# vertices
	for v in verts:
		_dot(v, IVORY, 4.0)
	# apothem + side midpoint
	var mid := (verts[0] + verts[1]) * 0.5
	_dashed(Vector2.ZERO, mid, EMERALD, 1.6)
	_dot(mid, EMERALD, 3.5)
	_label(mid, "a", EMERALD, 14, Vector2(4, 14))
	# angle arc at centre for one sector
	_arc_guide(Vector2.ZERO, 0.42, rot, rot + step, GOLD, 2.0)
	_label(MathUtils.polar_to_cart(0.5, rot + step * 0.5), "%.1f°" % rad_to_deg(step), GOLD, 13)
	# live rotating radius vector
	var sweep := rot + fposmod(_phase * 0.9, float(n)) * step
	_line(Vector2.ZERO, MathUtils.polar_to_cart(radius, sweep), Color(EMERALD.r, EMERALD.g, EMERALD.b, 0.8), 2.0)
	_dot(MathUtils.polar_to_cart(radius, sweep), EMERALD, 4.0)
	_label_screen(Vector2(16, 28), "Regular %d-gon" % n, GOLD, 15)
	_label_screen(Vector2(16, 48), "θ = 360°/%d = %.2f°   s = 2R·sin(π/n)   a = R·cos(π/n)" % [n, rad_to_deg(step)], MUTED, 13)


# --- 5. Star polygons {n/k} --------------------------------------------------

func _draw_star_polygon() -> void:
	var n: int = maxi(3, int(params["n"]))
	var k: int = clampi(int(params["k"]), 1, n - 1)
	var step := TAU / float(n)
	var rot := -PI * 0.5
	_circle_guide(Vector2.ZERO, 1.15, MUTED, 1.0)
	var verts := MathUtils.polygon_vertices(n, 1.15, rot)
	for v in verts:
		_dot(v, IVORY, 4.0)
		_dashed(Vector2.ZERO, v, GRID, 1.0)
	var circuits := MathUtils.star_polygon_circuits_points(n, k, 1.15, rot)
	var tones := [GOLD, EMERALD, Color(0.85, 0.55, 0.35), Color(0.6, 0.75, 0.95)]
	for i in circuits.size():
		_poly(circuits[i], tones[i % tones.size()], true, 2.0)
	# animated traversal
	var progress := fposmod(_phase * 0.8, 1.0)
	var travelled := int(progress * float(n * maxi(1, circuits.size())))
	var index := 0
	var current := 0
	var visited := 0
	while index < n * circuits.size() and visited < travelled:
		index += 1
		current = (current + k) % n
		if index % n == 0:
			current = 0
		visited += 1
	_dot(verts[current], GOLD, 5.0)
	var gcd_value := _gcd(n, k)
	_label_screen(Vector2(16, 28), "Star polygon {%d/%d}" % [n, k], GOLD, 15)
	_label_screen(Vector2(16, 48), "step angle = k·360°/n = %.2f°   gcd(%d,%d) = %d circuits" % [
		rad_to_deg(step * float(k)), n, k, gcd_value], MUTED, 13)
	if k >= n * 0.5:
		_label_screen(Vector2(16, 68), "note: k > n/2 repeats earlier figures (k ≡ n−k)", EMERALD, 12)


func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return maxi(a, 1)


# --- 6. Tessellation ---------------------------------------------------------

func _draw_tessellation() -> void:
	var shape: int = int(params["shape"])
	var rows: int = int(params["rows"])
	if shape == 0:
		_draw_tess_square(rows)
	elif shape == 1:
		_draw_tess_hex(rows)
	else:
		_draw_tess_triangle(rows)


func _draw_tess_square(rows: int) -> void:
	var tile := 1.35 / float(rows)
	for i in range(-rows, rows + 1):
		for j in range(-rows, rows + 1):
			var centre := Vector2(float(i), float(j)) * tile
			if centre.length() > 1.45:
				continue
			var cell := MathUtils.translate_points(
				MathUtils.polygon_vertices(4, tile * 0.7071, PI * 0.25), centre)
			_fill_poly(cell, Color(0.11, 0.70, 0.53, 0.08) if (i + j) % 2 == 0 else ACCENT_FILL)
			_poly(cell, Color(MUTED.r, MUTED.g, MUTED.b, 0.75), true, 1.2)
	# highlight vertex + four tiles
	var v := Vector2.ZERO
	_dot(v, GOLD, 5.0)
	_poly(MathUtils.polygon_vertices(4, tile * 0.6, PI * 0.25), EMERALD, true, 2.4)
	_label_screen(Vector2(16, 28), "Square tiling — 4 tiles × 90° = 360° at each vertex", GOLD, 15)


func _draw_tess_hex(rows: int) -> void:
	var tile := 0.62 * float(rows) / float(rows)
	tile = 1.1 / float(rows)
	var spacing := sqrt(3.0) * tile
	var count := 0
	for q in range(-rows, rows + 1):
		for r in range(-rows, rows + 1):
			if absi(q + r) > rows:
				continue
			var centre := Vector2(1.5 * tile * float(q), spacing * (float(r) + float(q) * 0.5))
			if centre.length() > 1.45:
				continue
			count += 1
			var cell := MathUtils.translate_points(MathUtils.polygon_vertices(6, tile, 0.0), centre)
			_fill_poly(cell, ACCENT_FILL if count % 3 == 0 else Color(0.11, 0.70, 0.53, 0.08))
			_poly(cell, Color(MUTED.r, MUTED.g, MUTED.b, 0.75), true, 1.2)
	_dot(Vector2.ZERO, GOLD, 5.0)
	_label_screen(Vector2(16, 28), "Hexagonal tiling — 3 tiles × 120° = 360° at each vertex", GOLD, 15)


func _draw_tess_triangle(rows: int) -> void:
	var s := 1.5 / float(rows)
	var h := s * sqrt(3.0) * 0.5
	for row in range(-rows, rows + 1):
		var y0 := float(row) * h
		var offset := 0.5 * s * float(row & 1)
		for k in range(-rows - 1, rows + 1):
			var x := float(k) * s + offset
			var up := PackedVector2Array([Vector2(x, y0), Vector2(x + s, y0), Vector2(x + s * 0.5, y0 + h)])
			var down := PackedVector2Array([Vector2(x + s * 0.5, y0 + h), Vector2(x + s * 1.5, y0 + h), Vector2(x + s, y0)])
			for tri: Array in [[up, 0.08], [down, 0.18]]:
				var pts: PackedVector2Array = tri[0]
				var centroid := (pts[0] + pts[1] + pts[2]) / 3.0
				if centroid.length() > 1.5:
					continue
				_fill_poly(pts, Color(0.11, 0.70, 0.53, float(tri[1])))
				_poly(pts, Color(MUTED.r, MUTED.g, MUTED.b, 0.7), true, 1.0)
	_dot(Vector2.ZERO, GOLD, 5.0)
	_label_screen(Vector2(16, 28), "Triangular tiling — 6 triangles × 60° = 360° at each vertex", GOLD, 15)


# --- 7. Cartesian & polar coordinates ---------------------------------------

func _draw_cartesian_polar() -> void:
	var r: float = float(params["r"])
	var theta := deg_to_rad(float(params["theta"]))
	_draw_axes()
	var p := MathUtils.polar_to_cart(r, theta)
	# grid squares (unit)
	for i in range(-2, 3):
		_dashed(Vector2(float(i), -1.5), Vector2(float(i), 1.5), GRID, 1.0)
		_dashed(Vector2(-1.5, float(i)), Vector2(1.5, float(i)), GRID, 1.0)
	# projections
	_dashed(p, Vector2(p.x, 0), EMERALD, 1.6)
	_dashed(p, Vector2(0, p.y), EMERALD, 1.6)
	_dot(Vector2(p.x, 0), EMERALD, 3.5)
	_dot(Vector2(0, p.y), EMERALD, 3.5)
	_label(Vector2(p.x, 0), "x = r·cosθ = %.2f" % p.x, EMERALD, 12, Vector2(4, 8))
	_label(Vector2(0, p.y), "y = r·sinθ = %.2f" % p.y, EMERALD, 12, Vector2(8, -6))
	# radius vector
	_line(Vector2.ZERO, p, GOLD, 2.4)
	_arc_guide(Vector2.ZERO, 0.45, 0.0, theta, EMERALD, 2.0)
	_label(MathUtils.polar_to_cart(0.5, theta * 0.5), "θ = %.1f°" % float(params["theta"]), EMERALD, 13)
	_label(p, "P", GOLD, 15, Vector2(8, -10))
	_dot(p, GOLD, 5.0)
	_dot(Vector2.ZERO, IVORY, 4.0)
	_label_screen(Vector2(16, 28), "Cartesian ↔ polar", GOLD, 15)
	_label_screen(Vector2(16, 48), "P = (x, y) = (%.2f, %.2f)   |   P = (r, θ) = (%.2f, %.1f°)" % [
		p.x, p.y, r, float(params["theta"])], MUTED, 13)


# --- 8. Transformations ------------------------------------------------------

func _draw_transform() -> void:
	var matrix: int = int(params["matrix"])
	var angle := deg_to_rad(float(params["angle"]))
	var scale_factor: float = float(params["scale"])
	var m := Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2.ZERO)
	match matrix:
		0:  # rotation
			m = Transform2D(Vector2(cos(angle), -sin(angle)), Vector2(sin(angle), cos(angle)), Vector2.ZERO)
		1:  # scale
			m = Transform2D(Vector2(scale_factor, 0), Vector2(0, scale_factor), Vector2.ZERO)
		2:  # reflection across Y axis
			m = Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)
		3:  # shear
			m = Transform2D(Vector2(1, 0), Vector2(tan(angle * 0.5), 1), Vector2.ZERO)
	var motif := PackedVector2Array([
		Vector2(0, 0), Vector2(0.9, 0), Vector2(0.9, 0.28),
		Vector2(0.28, 0.28), Vector2(0.28, 0.9), Vector2(0, 0.9),
	])
	_draw_axes()
	_poly(motif, Color(MUTED.r, MUTED.g, MUTED.b, 0.8), true, 1.6)
	_label_screen(_map(Vector2(0.45, 0.45)), "original", MUTED, 12)
	var transformed := PackedVector2Array()
	for p in motif:
		transformed.append(m.x * p.x + m.y * p.y)
	_poly(transformed, GOLD, true, 2.2)
	_fill_poly(transformed, ACCENT_FILL)
	# basis vectors
	var i_vec := m.x * 0.7
	var j_vec := m.y * 0.7
	_line(Vector2.ZERO, i_vec, EMERALD, 2.6)
	_line(Vector2.ZERO, j_vec, Color(0.85, 0.55, 0.35), 2.6)
	_label(i_vec, "î′", EMERALD)
	_label(j_vec, "ĵ′", Color(0.85, 0.55, 0.35))
	_dot(Vector2.ZERO, IVORY, 4.0)
	var names := ["rotation", "uniform scale", "reflection (y-axis)", "shear"]
	_label_screen(Vector2(16, 28), "2D transformation: %s" % names[matrix], GOLD, 15)
	_label_screen(Vector2(16, 48), "[ a  b ]   [ %+.2f  %+.2f ]" % [m.x.x, m.y.x], MUTED, 13)
	_label_screen(Vector2(16, 66), "[ c  d ] = [ %+.2f  %+.2f ]" % [m.x.y, m.y.y], MUTED, 13)


# --- 9. Worked example: constructing a star ---------------------------------

func _draw_star_example() -> void:
	var n: int = int(params["n"])
	var inner_ratio: float = float(params["inner"])
	var step := TAU / float(n)
	var rot := -PI * 0.5
	var r_out := 1.15
	var r_in := r_out * inner_ratio
	_circle_guide(Vector2.ZERO, r_out, MUTED, 1.1)
	_circle_guide(Vector2.ZERO, r_in, Color(MUTED.r, MUTED.g, MUTED.b, 0.5), 1.0)
	# axes every θ
	for i in n:
		_dashed(Vector2.ZERO, MathUtils.polar_to_cart(r_out * 1.12, rot + step * float(i)), GRID, 1.0)
	var star := MathUtils.star_vertices(n, r_out, r_in, rot)
	_fill_poly(star, ACCENT_FILL)
	_poly(star, GOLD, true, 2.2)
	for i in star.size():
		var p := star[i]
		var is_outer := i % 2 == 0
		_dot(p, IVORY if is_outer else EMERALD, 3.6)
		if i < 4:
			_label(p, "%s_%d" % ["R" if is_outer else "r", int(i / 2)], MUTED, 11)
	# animated current vertex
	var current := int(_phase * 1.6) % (n * 2)
	_dot(star[current], GOLD, 5.5)
	_line(Vector2.ZERO, star[current], Color(GOLD.r, GOLD.g, GOLD.b, 0.75), 1.8)
	_dot(Vector2.ZERO, IVORY, 4.0)
	_label_screen(Vector2(16, 28), "Constructing a %d-point star: 2n = %d vertices" % [n, n * 2], GOLD, 15)
	_label_screen(Vector2(16, 48), "outer vertex k: (R·cos(k·%.1f°), R·sin(k·%.1f°))" % [rad_to_deg(step), rad_to_deg(step)], MUTED, 13)
	_label_screen(Vector2(16, 66), "inner vertex k: (r·cos((k+½)·%.1f°), r·sin((k+½)·%.1f°))   r/R = %.2f" % [
		rad_to_deg(step), inner_ratio], MUTED, 13)


# --- 10. Rosette drafting (wedge method) ------------------------------------

func _draw_rosette_draft() -> void:
	var n: int = int(params["n"])
	var step := TAU / float(n)
	var rot := -PI * 0.5
	_circle_guide(Vector2.ZERO, 1.15, GRID, 1.0)
	# faint full replication
	var motif := _wedge_motif(step)
	for i in n:
		var copy := MathUtils.rotate_points(motif, rot + step * float(i))
		_poly(copy, Color(MUTED.r, MUTED.g, MUTED.b, 0.45), true, 1.0)
	# highlighted wedge + its mirror
	var wedge_index := int(_phase * 0.7) % n
	var base := rot + step * float(wedge_index)
	var wedge := MathUtils.rotate_points(motif, base)
	_fill_poly(wedge, ACCENT_FILL)
	_poly(wedge, GOLD, true, 2.2)
	var mirrored := MathUtils.mirror_points_axis(wedge, base + step * 0.5)
	_poly(mirrored, Color(EMERALD.r, EMERALD.g, EMERALD.b, 0.8), true, 1.6)
	_dashed(Vector2.ZERO, MathUtils.polar_to_cart(1.3, base + step * 0.5), EMERALD, 1.4)
	_label_screen(Vector2(16, 28), "Rosette drafting by wedge replication, N = %d" % n, GOLD, 15)
	_label_screen(Vector2(16, 48), "wedge = 360°/N = %.1f°   drafted once, then rotated + mirrored N times" % rad_to_deg(step), MUTED, 13)


func _wedge_motif(step: float) -> PackedVector2Array:
	# petal motif spanning half a wedge, as used by the real generators
	var half := step * 0.46
	var pts := PackedVector2Array([
		MathUtils.polar_to_cart(0.42, 0.0),
		MathUtils.polar_to_cart(0.62, half),
		MathUtils.polar_to_cart(1.1, 0.0),
		MathUtils.polar_to_cart(0.62, -half),
	])
	return pts
