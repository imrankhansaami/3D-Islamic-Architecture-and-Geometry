class_name SymmetryManager
extends RefCounted
## Symmetry operations on 2D geometry.
##
## Islamic geometric patterns are constructed by repeating a designed motif
## around a centre (rotational / radial symmetry) and by mirroring it across
## axes (reflection symmetry). This class implements those operations so the
## generators can apply them explicitly and the learning mode can demonstrate
## them.

## Rotational symmetry: [param count] rotated copies of a polygon list,
## copy i rotated by start_angle + i * TAU / count.
static func radial_copies(polygons: Array, count: int, start_angle: float = 0.0) -> Array:
	count = maxi(1, count)
	var out: Array = []
	var step := TAU / float(count)
	for i in count:
		var angle := start_angle + step * float(i)
		for poly: PackedVector2Array in polygons:
			out.append(MathUtils.rotate_points(poly, angle))
	return out


## Reflection symmetry: the original polygons plus their mirror image across
## the line through the origin at [param axis_angle].
static func mirror_copies(polygons: Array, axis_angle: float) -> Array:
	var out: Array = []
	for poly: PackedVector2Array in polygons:
		out.append(poly)
		out.append(MathUtils.mirror_points_axis(poly, axis_angle))
	return out


## The classic Islamic pattern drafting method: design the motif inside one
## wedge spanning [0, wedge_angle], then replicate it radially. With
## [param include_mirror] enabled, every rotated copy is also mirrored, which
## makes each copy's boundaries reflection axes of the finished pattern.
static func replicate_wedge(polygons: Array, folds: int, include_mirror: bool = true) -> Array:
	folds = maxi(1, folds)
	var wedge := TAU / float(folds)
	var out: Array = []
	for i in folds:
		var angle := wedge * float(i)
		for poly: PackedVector2Array in polygons:
			var rotated := MathUtils.rotate_points(poly, angle)
			out.append(rotated)
			if include_mirror:
				out.append(MathUtils.mirror_points_axis(rotated, angle))
	return out


## Point-set version of radial_copies (for marker points / vertex rings).
static func radial_point_copies(points: PackedVector2Array, count: int) -> PackedVector2Array:
	count = maxi(1, count)
	var out := PackedVector2Array()
	var step := TAU / float(count)
	for i in count:
		var angle := step * float(i)
		for p in points:
			out.append(p.rotated(angle))
	return out


## Applies rotational symmetry to a whole geometry result (fills, accents and
## segments are each rotated count times around the origin).
static func apply_rotational_symmetry(geo: PatternGeometry, folds: int, start_angle: float = 0.0) -> PatternGeometry:
	folds = maxi(1, folds)
	var result := PatternGeometry.new()
	result.fills = radial_copies(geo.fills, folds, start_angle)
	result.accents = radial_copies(geo.accents, folds, start_angle)
	var step := TAU / float(folds)
	for seg: PackedVector2Array in geo.segments:
		if seg.size() != 2:
			continue
		for i in folds:
			var angle := start_angle + step * float(i)
			result.add_segment(seg[0].rotated(angle), seg[1].rotated(angle))
	for poly: PackedVector2Array in geo.guides:
		for i in folds:
			result.add_guide(MathUtils.rotate_points(poly, start_angle + step * float(i)))
	return result


## Applies reflection symmetry across one or more axes.
static func apply_reflection_symmetry(geo: PatternGeometry, axis_angles: Array) -> PatternGeometry:
	var result := PatternGeometry.new()
	result.fills = geo.fills.duplicate()
	result.accents = geo.accents.duplicate()
	for seg: PackedVector2Array in geo.segments:
		if seg.size() == 2:
			result.add_segment(seg[0], seg[1])
	for axis: float in axis_angles:
		result.fills.append_array(mirrored_list(geo.fills, axis))
		result.accents.append_array(mirrored_list(geo.accents, axis))
		for seg: PackedVector2Array in geo.segments:
			if seg.size() == 2:
				var mirrored := MathUtils.mirror_points_axis(seg, axis)
				result.add_segment(mirrored[0], mirrored[1])
	for poly: PackedVector2Array in geo.guides:
		result.add_guide(poly)
	return result


## Mirrors every polygon in [param polygons] across the axis and returns the list.
static func mirrored_list(polygons: Array, axis_angle: float) -> Array:
	var out: Array = []
	for poly: PackedVector2Array in polygons:
		out.append(MathUtils.mirror_points_axis(poly, axis_angle))
	return out
