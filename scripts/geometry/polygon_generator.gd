class_name PolygonGenerator
extends RefCounted
## Polygon-based patterns:
##   * regular polygon            (single polygon + nested layers)
##   * overlapping polygons       (one polygon rotated N times)
##   * concentric polygons        (nested polygons linked by connecting lines)
##   * radial arrangement         (small polygons placed around a circle)
##
## All four reuse [method MathUtils.polygon_vertices]: vertices are placed at
## equal angular intervals of TAU / sides on a circle of the given radius.

# --- Regular polygon ---------------------------------------------------------

static func build_regular(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var sides := config.sides
	var r := config.outer_radius
	var rot := deg_to_rad(config.rotation_deg)

	if config.show_fills:
		geo.add_fill(MathUtils.polygon_vertices(48, r * 1.04))

	var outer := MathUtils.polygon_vertices(sides, r, rot)
	if config.show_fills:
		geo.add_accent(outer)
	if config.show_lines:
		geo.add_outline(outer, true)

	for i in range(1, config.repetition):
		var factor := 1.0 - 0.25 * float(i)
		var layer_rot := rot + (TAU / float(sides)) * 0.5 * float(i % 2)
		var layer := MathUtils.polygon_vertices(sides, r * factor, layer_rot)
		if config.show_lines:
			geo.add_outline(layer, true)
		geo.add_guide_circle(Vector2.ZERO, r * factor)
		for p in layer:
			geo.add_guide_point(p)

	# connecting lines between corresponding vertices of adjacent layers
	# (a classic optical "woven" effect)
	if config.show_lines:
		for i in range(1, config.repetition):
			var factor_outer := 1.0 - 0.25 * float(i - 1)
			var factor_inner := 1.0 - 0.25 * float(i)
			var rot_outer := rot + (TAU / float(sides)) * 0.5 * float((i - 1) % 2)
			var rot_inner := rot + (TAU / float(sides)) * 0.5 * float(i % 2)
			for j in sides:
				var a := MathUtils.polar_to_cart(r * factor_outer, rot_outer + TAU * float(j) / float(sides))
				var b := MathUtils.polar_to_cart(r * factor_inner, rot_inner + TAU * float(j) / float(sides))
				geo.add_segment(a, b)

	geo.add_guide_circle(Vector2.ZERO, r)
	for p in outer:
		geo.add_guide_point(p)
	return geo


# --- Overlapping polygons ----------------------------------------------------

static func build_overlap(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var sides := config.sides
	var r := config.outer_radius
	var rot := deg_to_rad(config.rotation_deg)
	var copies := maxi(2, config.symmetry_folds)
	var step := PI / float(sides)   # half the side angle: the classic overlap

	if config.show_fills:
		geo.add_fill(MathUtils.polygon_vertices(48, r * 1.04))

	for k in copies:
		var p := MathUtils.polygon_vertices(sides, r, rot + step * float(k))
		if k == 0 and config.show_fills:
			geo.add_accent(p)
		if config.show_lines:
			geo.add_outline(p, true)

	geo.add_guide_circle(Vector2.ZERO, r)
	geo.add_guide_circle(Vector2.ZERO, r * cos(PI / float(sides)))
	for k in sides:
		var angle := rot + TAU * float(k) / float(sides)
		geo.add_guide(PackedVector2Array([
			MathUtils.polar_to_cart(r * 0.4, angle),
			MathUtils.polar_to_cart(r * 1.15, angle),
		]))
		geo.add_guide_point(MathUtils.polar_to_cart(r, angle))
	return geo


# --- Concentric polygons -----------------------------------------------------

static func build_concentric(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var sides := config.sides
	var r := config.outer_radius
	var rot := deg_to_rad(config.rotation_deg)
	var layers := maxi(2, config.repetition)

	if config.show_fills:
		geo.add_fill(MathUtils.polygon_vertices(48, r * 1.04))

	var outer := MathUtils.polygon_vertices(sides, r, rot)
	if config.show_fills:
		geo.add_accent(outer)
	if config.show_lines:
		geo.add_outline(outer, true)

	for i in range(1, layers):
		var factor := maxf(0.1, 1.0 - 0.3 * float(i))
		var layer_rot := rot + (TAU / float(sides)) * 0.5 * float(i % 2)
		var layer := MathUtils.polygon_vertices(sides, r * factor, layer_rot)
		if config.show_lines:
			geo.add_outline(layer, true)
		geo.add_guide_circle(Vector2.ZERO, r * factor)
		# connecting lines between the corresponding vertices of adjacent
		# layers (a classic optical "woven" effect)
		if config.show_lines and i > 0:
			var prev_factor := maxf(0.1, 1.0 - 0.3 * float(i - 1))
			var prev_rot := rot + (TAU / float(sides)) * 0.5 * float((i - 1) % 2)
			for j in sides:
				var a := MathUtils.polar_to_cart(r * prev_factor, prev_rot + TAU * float(j) / float(sides))
				geo.add_segment(a, layer[j])
		for p in layer:
			geo.add_guide_point(p)

	geo.add_guide_circle(Vector2.ZERO, r)
	geo.add_guide_point(Vector2.ZERO)
	return geo


# --- Radial arrangement ------------------------------------------------------

static func build_radial(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var sides := config.sides
	var r := config.outer_radius
	var rot := deg_to_rad(config.rotation_deg)
	var count := maxi(3, config.symmetry_folds)
	var orbits := clampi(config.repetition, 1, 4)

	# central hub: accent dot so the spokes converge on a visible centre
	if config.show_fills:
		geo.add_accent(MathUtils.regular_dot(Vector2.ZERO, r * 0.07, 12))

	for ring in orbits:
		var orbit_r := r * minf(1.05, 0.45 + 0.3 * float(ring))
		var spacing := TAU * orbit_r / float(count)
		var small_r := minf(r * 0.17, spacing * 0.42)
		var stagger := PI / float(count) * float(ring % 2)
		var ring_geo := PatternGeometry.new()
		for i in count:
			var angle := rot + stagger + TAU * float(i) / float(count)
			var centre := MathUtils.polar_to_cart(orbit_r, angle)
			var poly := MathUtils.translate_points(
				MathUtils.polygon_vertices(sides, small_r, angle), centre)
			# alternate colours between neighbouring polygons
			if config.show_fills:
				if (i + ring) % 2 == 0:
					ring_geo.add_accent(poly)
				else:
					ring_geo.add_fill(poly)
			if config.show_lines:
				ring_geo.add_outline(poly, true)
			ring_geo.add_guide_point(centre)
			# spoke from the hub to each polygon's inner edge
			if config.show_lines:
				ring_geo.add_segment(MathUtils.polar_to_cart(r * 0.075, angle), centre - MathUtils.polar_to_cart(small_r, angle))
		ring_geo.add_guide_circle(Vector2.ZERO, orbit_r)
		geo.merge(ring_geo)

	geo.add_guide_circle(Vector2.ZERO, r)
	geo.add_guide_point(Vector2.ZERO)
	return geo
