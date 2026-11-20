class_name ArchGenerator
extends RefCounted
## Procedural arches and arched walls.
##
## Everything is built as a 2D elevation profile in the (x, y) plane
## (x lateral, y up) and extruded along +Z, so a wall piece can be rotated
## into any orientation by its node transform.
##
## Arch curves are constructed analytically:
##   * POINTED  — two-centred arch: two circular arcs of radius R = a + o
##     centred at (∓o, springing); o = pointiness·a controls the sharpness.
##   * HORSESHOE — one circle of radius R = sqrt(a² + e²) centred below the
##     springing line at depth e; the arc extends past the springing points
##     until the tangent is vertical (the classic keyhole profile).
##   * ROUND    — a semicircle of radius a.

enum Kind { POINTED, HORSESHOE, ROUND }


## 2D curve (x, y) of the arch soffit from the left springing point to the
## right one, y = springing at both ends (horseshoe curves are shifted so
## their lowest points sit at y = 0 with springing height honoured).
static func curve(kind: int, half_width: float, spring_height: float,
		pointiness: float, segments: int = 26) -> PackedVector2Array:
	segments = maxi(6, segments)
	var pts := PackedVector2Array()
	match kind:
		Kind.POINTED:
			var a := maxf(half_width, 0.05)
			var o := clampf(pointiness, 0.0, 0.95) * a
			var radius := a + o
			var apex_angle := atan2(sqrt(maxf(radius * radius - o * o, 0.0)), -o)
			# left half uses the centre at (+o, spring), right half at (−o, spring)
			for i in segments + 1:
				var t := float(i) / float(segments)
				if t <= 0.5:
					var angle := lerpf(PI, apex_angle, t * 2.0)
					pts.append(Vector2(o, spring_height) + MathUtils.polar_to_cart(radius, angle))
				else:
					var angle := lerpf(apex_angle, 0.0, (t - 0.5) * 2.0)
					pts.append(Vector2(-o, spring_height) + MathUtils.polar_to_cart(radius, angle))
		Kind.HORSESHOE:
			var a := maxf(half_width, 0.05)
			var e := 0.32 * a
			var radius := sqrt(a * a + e * e)
			var theta_e := atan2(e, a)
			var lowest := -e - radius * sin(theta_e)  # = -2e
			for i in segments + 1:
				var t := float(i) / float(segments)
				var angle := lerpf(-theta_e, PI + theta_e, t)
				var p := Vector2(0.0, -e) + MathUtils.polar_to_cart(radius, angle)
				p.y -= lowest  # shift so the ends touch y = 0
				p.y += spring_height
				pts.append(p)
		_:
			var a := maxf(half_width, 0.05)
			for i in segments + 1:
				var t := float(i) / float(segments)
				var angle := lerpf(PI, 0.0, t)
				pts.append(Vector2(0.0, spring_height) + MathUtils.polar_to_cart(a, angle))
	return MathUtils.dedupe_consecutive(pts, 0.001)


## Highest y of the curve.
static func curve_apex(curve_points: PackedVector2Array) -> float:
	var apex := 0.0
	for p in curve_points:
		apex = maxf(apex, p.y)
	return apex


## A wall elevation with arched openings.
## [param arches]: array of dictionaries
##   {"x": centre, "half": half width, "spring": springing height,
##    "pointiness": float, "kind": Kind}
## [param depth]: extrusion thickness along +Z.
static func wall_with_arches(width: float, height: float, arches: Array,
		depth: float, segments: int = 26) -> ArrayMesh:
	var half_width := width * 0.5
	var spans: Array = []
	for arch: Dictionary in arches:
		var a := float(arch.get("half", 1.0))
		spans.append({
			"left": float(arch.get("x", 0.0)) - a,
			"right": float(arch.get("x", 0.0)) + a,
			"arch": arch,
		})
	spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["left"] < q["left"])

	var polygons: Array = []
	# piers between / around the openings
	var cursor := -half_width
	for span: Dictionary in spans:
		var left: float = maxf(span["left"], -half_width)
		if left - cursor > 0.001:
			polygons.append(PackedVector2Array([
				Vector2(cursor, 0.0), Vector2(left, 0.0),
				Vector2(left, height), Vector2(cursor, height)]))
		cursor = maxf(cursor, float(span["right"]))
	if half_width - cursor > 0.001:
		polygons.append(PackedVector2Array([
			Vector2(cursor, 0.0), Vector2(half_width, 0.0),
			Vector2(half_width, height), Vector2(cursor, height)]))

	# regions above each arch, triangulated as a fan from the wall top centre
	for span: Dictionary in spans:
		var arch: Dictionary = span["arch"]
		var cx: float = float(arch.get("x", 0.0))
		var apex_limit := height - 0.05
		var kind: int = int(arch.get("kind", Kind.POINTED))
		var spring: float = minf(float(arch.get("spring", 1.0)), apex_limit - 0.3)
		var pointiness: float = float(arch.get("pointiness", 0.5))
		var pts := curve(kind, float(arch.get("half", 1.0)), spring, pointiness, segments)
		var apex := curve_apex(pts)
		if apex > apex_limit:
			# flatten the arch until it fits below the wall top
			var scale := (apex_limit - spring) / maxf(apex - spring, 0.001)
			for i in pts.size():
				pts[i] = Vector2(lerpf(cx, pts[i].x, scale), spring + (pts[i].y - spring) * scale)
		var top := Vector2(cx, height)
		for i in pts.size() - 1:
			polygons.append(PackedVector2Array([
				pts[i] + Vector2(cx, 0.0), pts[i + 1] + Vector2(cx, 0.0), top]))
	return MeshBuilder.build_slab_mesh(polygons, 0.0, depth)


## A free-standing arch frame: two pillars plus the spandrel above the curve.
static func frame_mesh(half_width: float, spring_height: float, wall_height: float,
		pillar_width: float, pointiness: float, kind: int, depth: float,
		segments: int = 26) -> ArrayMesh:
	return wall_with_arches(half_width * 2.0 + pillar_width * 2.0, wall_height, [{
		"x": 0.0, "half": half_width, "spring": spring_height,
		"pointiness": pointiness, "kind": kind,
	}], depth, segments)


## Decorative band following the arch curve: a ribbon of the given width on
## the outside of the curve, optionally raised in front of the wall face.
static func band_mesh(curve_points: PackedVector2Array, band_width: float,
		depth: float, z_offset: float = 0.0) -> ArrayMesh:
	var n := curve_points.size()
	if n < 2:
		return ArrayMesh.new()
	# outward normals (away from the opening interior)
	var normals: Array = []
	var opening_centre := Vector2(0.0, curve_points[n / 2].y * 0.4)
	for i in n:
		var prev := curve_points[maxi(0, i - 1)]
		var next := curve_points[mini(n - 1, i + 1)]
		var tangent := (next - prev)
		if tangent.length_squared() < 1e-9:
			tangent = Vector2(1, 0)
		var normal := Vector2(tangent.y, -tangent.x).normalized()
		if (curve_points[i] - opening_centre).dot(normal) < 0.0:
			normal = -normal
		normals.append(normal)
	var polygons: Array = []
	for i in n - 1:
		var p0: Vector2 = curve_points[i]
		var p1: Vector2 = curve_points[i + 1]
		var q1: Vector2 = p1 + normals[i + 1] * band_width
		var q0: Vector2 = p0 + normals[i] * band_width
		polygons.append(PackedVector2Array([p0, p1, q1, q0]))
	var mesh := MeshBuilder.build_slab_mesh(polygons, z_offset, depth)
	return mesh
