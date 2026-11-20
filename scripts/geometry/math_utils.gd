class_name MathUtils
extends RefCounted
## Pure mathematical helpers shared by every procedural generator.
##
## Coordinate conventions used across the project:
##   * patterns are built in the 2D (X, Y) plane,
##   * angles are radians, measured counter-clockwise from +X,
##   * polygons are stored counter-clockwise (positive shoelace area),
##   * extrusion happens along +Z when a pattern becomes 3D.

# --- Polar / cartesian -------------------------------------------------------

static func polar_to_cart(radius: float, angle_rad: float) -> Vector2:
	return Vector2(radius * cos(angle_rad), radius * sin(angle_rad))


## Returns (radius, angle_radians) of a cartesian point.
static func cart_to_polar(point: Vector2) -> Vector2:
	return Vector2(point.length(), point.angle())


static func wrap_angle(angle: float) -> float:
	return fposmod(angle, TAU)


# --- Polygon construction ----------------------------------------------------

## Vertices of a regular polygon: equal angular intervals of TAU / sides.
static func polygon_vertices(sides: int, radius: float, rotation_rad: float = 0.0) -> PackedVector2Array:
	sides = maxi(3, sides)
	var pts := PackedVector2Array()
	var step := TAU / float(sides)
	for i in sides:
		pts.append(polar_to_cart(radius, rotation_rad + step * float(i)))
	return pts


## Vertices of an n-point star: alternating outer and inner radii,
## producing 2n vertices (the inner vertices sit half a step between outers).
static func star_vertices(points: int, outer_radius: float, inner_radius: float, rotation_rad: float = 0.0) -> PackedVector2Array:
	points = maxi(3, points)
	inner_radius = clampf(inner_radius, 0.01, outer_radius)
	var pts := PackedVector2Array()
	var step := TAU / float(points)
	for i in points:
		pts.append(polar_to_cart(outer_radius, rotation_rad + step * float(i)))
		pts.append(polar_to_cart(inner_radius, rotation_rad + step * (float(i) + 0.5)))
	return pts


## Small regular polygon (used for junction dots and markers).
static func regular_dot(center: Vector2, radius: float, sides: int = 8) -> PackedVector2Array:
	return translate_points(polygon_vertices(sides, radius), center)


# --- Transformations ---------------------------------------------------------

static func rotate_points(pts: PackedVector2Array, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i].rotated(angle)
	return out


static func scale_points(pts: PackedVector2Array, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] * factor
	return out


static func translate_points(pts: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + offset
	return out


## Reflection across the X axis (y -> -y).
static func mirror_x_points(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = Vector2(pts[i].x, -pts[i].y)
	return out


## Reflection across the line through the origin with angle axis_angle.
static func mirror_points_axis(pts: PackedVector2Array, axis_angle: float) -> PackedVector2Array:
	return rotate_points(mirror_x_points(rotate_points(pts, -axis_angle)), axis_angle)


# --- Polygon analysis --------------------------------------------------------

## Shoelace signed area. Positive when the polygon is counter-clockwise.
static func signed_area(pts: PackedVector2Array) -> float:
	if pts.size() < 3:
		return 0.0
	var total := 0.0
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		total += a.x * b.y - b.x * a.y
	return total * 0.5


static func total_area(polygons: Array) -> float:
	var total := 0.0
	for poly: PackedVector2Array in polygons:
		total += absf(signed_area(poly))
	return total


## Forces counter-clockwise ordering (needed for consistent normals).
static func ensure_ccw(pts: PackedVector2Array) -> PackedVector2Array:
	if signed_area(pts) >= 0.0:
		return pts
	return reverse_points(pts)


static func reverse_points(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	var n := pts.size()
	for i in n:
		out[i] = pts[n - 1 - i]
	return out


static func polygon_centroid(pts: PackedVector2Array) -> Vector2:
	var n := pts.size()
	if n == 0:
		return Vector2.ZERO
	if n < 3:
		var avg := Vector2.ZERO
		for p in pts:
			avg += p
		return avg / float(n)
	var area := signed_area(pts)
	if absf(area) < 1e-9:
		var avg2 := Vector2.ZERO
		for p in pts:
			avg2 += p
		return avg2 / float(n)
	var cx := 0.0
	var cy := 0.0
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var cross := a.x * b.y - b.x * a.y
		cx += (a.x + b.x) * cross
		cy += (a.y + b.y) * cross
	var factor := 1.0 / (6.0 * area)
	return Vector2(cx * factor, cy * factor)


# --- Segments and arcs -------------------------------------------------------

## Rectangle polygon covering a line segment (used to draw pattern lines as
## extruded ribbons). Ordered counter-clockwise.
static func segment_quad(a: Vector2, b: Vector2, thickness: float) -> PackedVector2Array:
	var half := thickness * 0.5
	var dir := (b - a)
	if dir.length_squared() < 1e-12:
		return PackedVector2Array()
	dir = dir.normalized()
	var nrm := Vector2(-dir.y, dir.x) * half
	return PackedVector2Array([
		a - nrm, b - nrm, b + nrm, a + nrm,
	])


## Points along a circular arc (inclusive of both ends).
static func arc_points(center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int) -> PackedVector2Array:
	segments = maxi(2, segments)
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / float(segments)
		pts.append(center + polar_to_cart(radius, lerpf(start_angle, end_angle, t)))
	return pts


# --- Star polygons {n/k} -----------------------------------------------------

## Vertex circuits of the star polygon {n/k}: connect every k-th vertex.
## When gcd(n, k) > 1 the figure splits into gcd(n, k) closed circuits.
static func star_polygon_circuits(n: int, k: int) -> Array:
	n = maxi(3, n)
	k = clampi(k, 1, n - 1)
	var visited := PackedByteArray()
	visited.resize(n)
	var circuits: Array = []
	for start in n:
		if visited[start] == 1:
			continue
		var circuit := PackedInt32Array()
		var current := start
		while visited[current] == 0:
			visited[current] = 1
			circuit.append(current)
			current = (current + k) % n
		if circuit.size() > 1:
			circuits.append(circuit)
	return circuits


## Point polylines of the star polygon {n/k} fitted to a circle.
static func star_polygon_circuits_points(n: int, k: int, radius: float, rotation_rad: float = 0.0) -> Array:
	var verts := polygon_vertices(n, radius, rotation_rad)
	var result: Array = []
	for circuit: PackedInt32Array in star_polygon_circuits(n, k):
		var pts := PackedVector2Array()
		for index in circuit:
			pts.append(verts[index])
		pts.append(verts[circuit[0]])  # close the circuit
		result.append(pts)
	return result


# --- Validation and bounds ---------------------------------------------------

static func is_finite_point(p: Vector2) -> bool:
	return is_finite(p.x) and is_finite(p.y)


static func is_finite_points(pts: PackedVector2Array) -> bool:
	for p in pts:
		if not is_finite_point(p):
			return false
	return true


## Removes consecutive duplicate points within eps.
static func dedupe_consecutive(pts: PackedVector2Array, eps: float = 0.0005) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > eps:
			out.append(p)
	return out


## Combined bounding rectangle of a list of point arrays.
static func bounds_of(point_lists: Array) -> Rect2:
	var found := false
	var rect := Rect2()
	for list: PackedVector2Array in point_lists:
		for p in list:
			if not found:
				rect = Rect2(p, Vector2.ZERO)
				found = true
			else:
				rect = rect.expand(p)
	return rect


## Distance from the origin to the farthest point of the lists.
static func max_radius_of(point_lists: Array) -> float:
	var best := 0.0
	for list: PackedVector2Array in point_lists:
		for p in list:
			best = maxf(best, p.length())
	return best
