class_name PatternGeometry
extends RefCounted
## Result of one pattern generation pass.
##
## The generators fill this container with 2D polygons and line segments;
## the mesh builder turns it into 3D geometry and the educational overlay
## uses the guide data for construction visualisation.
##
## Layers (bottom to top when meshed):
##   fills    — base filled shapes          (config.colour_fill)
##   accents  — secondary filled shapes     (config.colour_accent)
##   segments — pattern lines as ribbons    (config.colour_line)

var fills: Array[PackedVector2Array] = []
var accents: Array[PackedVector2Array] = []
var segments: Array[PackedVector2Array] = []          # each entry: [a, b]
var segment_widths: PackedFloat32Array = PackedFloat32Array()  # 0.0 = use default width

# Construction data (never meshed; used by "show construction guides"
# and by the learning mode explanations).
var guides: Array[PackedVector2Array] = []
var guide_circles: Array[Vector3] = []                 # (centre.x, centre.y, radius)
var guide_points: PackedVector2Array = PackedVector2Array()

var bounds: Rect2 = Rect2()

## Quantised segment keys so shared edges (e.g. the border between two
## tessellation cells) are emitted only once — duplicate coplanar ribbons
## would z-fight visually.
var _segment_keys: Dictionary = {}


# --- Adding geometry ---------------------------------------------------------

func add_fill(points: PackedVector2Array) -> void:
	var clean := _clean_polygon(points)
	if clean.size() >= 3:
		fills.append(clean)


func add_accent(points: PackedVector2Array) -> void:
	var clean := _clean_polygon(points)
	if clean.size() >= 3:
		accents.append(clean)


func add_segment(a: Vector2, b: Vector2, width: float = 0.0) -> void:
	if a.distance_squared_to(b) < 1e-10:
		return
	if not a.is_finite() or not b.is_finite():
		return
	var key_a := _segment_key(a)
	var key_b := _segment_key(b)
	var key := (key_a + "|" + key_b) if key_a <= key_b else (key_b + "|" + key_a)
	if _segment_keys.has(key):
		return
	_segment_keys[key] = true
	segments.append(PackedVector2Array([a, b]))
	segment_widths.append(width)


func _segment_key(p: Vector2) -> String:
	return "%d,%d" % [roundi(p.x * 1000.0), roundi(p.y * 1000.0)]


func add_outline(points: PackedVector2Array, close: bool = true, width: float = 0.0) -> void:
	var pts := MathUtils.dedupe_consecutive(points)
	if pts.size() < 2:
		return
	for i in pts.size() - 1:
		add_segment(pts[i], pts[i + 1], width)
	if close and pts.size() > 2:
		add_segment(pts[pts.size() - 1], pts[0], width)


func add_polyline(points: PackedVector2Array, width: float = 0.0) -> void:
	add_outline(points, false, width)


func add_guide(points: PackedVector2Array) -> void:
	if points.size() >= 2:
		guides.append(MathUtils.dedupe_consecutive(points))


func add_guide_circle(center: Vector2, radius: float) -> void:
	if radius > 0.0:
		guide_circles.append(Vector3(center.x, center.y, radius))


func add_guide_point(point: Vector2) -> void:
	guide_points.append(point)


## Merges another geometry result into this one.
func merge(other: PatternGeometry) -> void:
	fills.append_array(other.fills)
	accents.append_array(other.accents)
	segments.append_array(other.segments)
	segment_widths.append_array(other.segment_widths)
	guides.append_array(other.guides)
	guide_circles.append_array(other.guide_circles)
	guide_points.append_array(other.guide_points)


# --- Whole-geometry transforms ----------------------------------------------

func translate_all(offset: Vector2) -> void:
	for i in fills.size():
		fills[i] = MathUtils.translate_points(fills[i], offset)
	for i in accents.size():
		accents[i] = MathUtils.translate_points(accents[i], offset)
	_transform_segments(func(p: Vector2) -> Vector2: return p + offset)
	for i in guides.size():
		guides[i] = MathUtils.translate_points(guides[i], offset)
	for i in guide_circles.size():
		var c := guide_circles[i]
		guide_circles[i] = Vector3(c.x + offset.x, c.y + offset.y, c.z)
	for i in guide_points.size():
		guide_points[i] = guide_points[i] + offset


func scale_all(factor: float) -> void:
	for i in fills.size():
		fills[i] = MathUtils.scale_points(fills[i], factor)
	for i in accents.size():
		accents[i] = MathUtils.scale_points(accents[i], factor)
	_transform_segments(func(p: Vector2) -> Vector2: return p * factor)
	for i in guides.size():
		guides[i] = MathUtils.scale_points(guides[i], factor)
	for i in guide_circles.size():
		var c := guide_circles[i]
		guide_circles[i] = Vector3(c.x * factor, c.y * factor, c.z * factor)
	for i in guide_points.size():
		guide_points[i] = guide_points[i] * factor


func rotate_all(angle: float) -> void:
	for i in fills.size():
		fills[i] = MathUtils.rotate_points(fills[i], angle)
	for i in accents.size():
		accents[i] = MathUtils.rotate_points(accents[i], angle)
	_transform_segments(func(p: Vector2) -> Vector2: return p.rotated(angle))
	for i in guides.size():
		guides[i] = MathUtils.rotate_points(guides[i], angle)
	for i in guide_circles.size():
		var c := guide_circles[i]
		var rotated := Vector2(c.x, c.y).rotated(angle)
		guide_circles[i] = Vector3(rotated.x, rotated.y, c.z)
	for i in guide_points.size():
		guide_points[i] = guide_points[i].rotated(angle)


func _transform_segments(transform_fn: Callable) -> void:
	for i in segments.size():
		var seg := segments[i]
		if seg.size() == 2:
			segments[i] = PackedVector2Array([transform_fn.call(seg[0]), transform_fn.call(seg[1])])


# --- Finalisation ------------------------------------------------------------

## Validates, drops degenerate data and computes the bounding rectangle.
func compute() -> void:
	fills = _filter_polygons(fills)
	accents = _filter_polygons(accents)
	var valid_segments: Array[PackedVector2Array] = []
	var valid_widths := PackedFloat32Array()
	for i in segments.size():
		var seg := segments[i]
		if seg.size() != 2:
			continue
		if not seg[0].is_finite() or not seg[1].is_finite():
			continue
		if seg[0].distance_squared_to(seg[1]) < 1e-10:
			continue
		valid_segments.append(seg)
		valid_widths.append(segment_widths[i] if i < segment_widths.size() else 0.0)
	segments = valid_segments
	segment_widths = valid_widths

	# Rebuild the dedupe key set from the surviving segments.
	_segment_keys.clear()
	for seg: PackedVector2Array in segments:
		var key_a := _segment_key(seg[0])
		var key_b := _segment_key(seg[1])
		_segment_keys[(key_a + "|" + key_b) if key_a <= key_b else (key_b + "|" + key_a)] = true

	var all_lists: Array = []
	all_lists.append_array(fills)
	all_lists.append_array(accents)
	bounds = MathUtils.bounds_of(all_lists)
	if bounds.size == Vector2.ZERO and not fills.is_empty():
		bounds.size = Vector2(0.001, 0.001)


func is_valid() -> bool:
	if fills.is_empty() and accents.is_empty() and segments.is_empty():
		return false
	if not MathUtils.is_finite_points(fills[0] if not fills.is_empty() else PackedVector2Array()):
		return false
	return true


func stats() -> Dictionary:
	var poly_count := fills.size() + accents.size()
	var vertex_count := 0
	for poly: PackedVector2Array in fills:
		vertex_count += poly.size()
	for poly: PackedVector2Array in accents:
		vertex_count += poly.size()
	vertex_count += segments.size() * 2
	return {
		"fills": fills.size(),
		"accents": accents.size(),
		"segments": segments.size(),
		"vertices": vertex_count,
	}


func _clean_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var pts := MathUtils.dedupe_consecutive(points)
	if pts.size() >= 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.0005:
		pts.remove_at(pts.size() - 1)
	if not MathUtils.is_finite_points(pts):
		return PackedVector2Array()
	return MathUtils.ensure_ccw(pts)


func _filter_polygons(list: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly in list:
		var clean := _clean_polygon(poly)
		if clean.size() >= 3 and absf(MathUtils.signed_area(clean)) > 1e-8:
			out.append(clean)
	return out
