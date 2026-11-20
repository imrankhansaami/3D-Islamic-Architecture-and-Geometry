class_name StarGenerator
extends RefCounted
## n-point star patterns.
##
## Construction: 2n vertices alternate between the outer radius (star points)
## and the inner radius (valleys). The inner/outer radius ratio controls how
## sharp the star is; concentric rings are produced by scaling the same
## construction and rotating alternate rings by half an angular step, which is
## the classic way two star polygons interlock.

static func build(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var folds := config.star_points
	var r_out := config.outer_radius
	var r_in := r_out * config.inner_radius_ratio
	var rot := deg_to_rad(config.rotation_deg)
	var step := TAU / float(folds)

	# --- base plate (fill layer, sits under everything) ----------------------
	if config.show_fills:
		geo.add_fill(MathUtils.polygon_vertices(48, r_out * 1.04))

	# --- main star: accent fill + outline ------------------------------------
	var star := MathUtils.star_vertices(folds, r_out, r_in, rot)
	if config.show_fills:
		geo.add_accent(star)
	if config.show_lines:
		geo.add_outline(star, true)

	# --- concentric rings: line-only stars (never filled, so no coplanar
	#     fills can overlap) ---------------------------------------------------
	for i in range(1, config.repetition):
		var factor := 1.0 - 0.26 * float(i)
		var ring_rot := rot + step * 0.5 * float(i)
		var ring := MathUtils.star_vertices(folds, r_out * factor, r_in * factor, ring_rot)
		if config.show_lines:
			geo.add_outline(ring, true)
		geo.add_guide_circle(Vector2.ZERO, r_out * factor)
		for p in ring:
			geo.add_guide_point(p)

	# --- sunburst: short radial lines between centre and inner ring ----------
	if config.show_lines:
		var sun_start := r_in * 0.32
		var sun_end := r_in * 0.97
		for i in folds:
			var angle := rot + step * (float(i) + 0.5)
			geo.add_segment(
				MathUtils.polar_to_cart(sun_start, angle),
				MathUtils.polar_to_cart(sun_end, angle))

	# --- centre star (line-only: the accent main star already fills the centre
	#     region, so filled geometry here would be coplanar with it) -----------
	var centre := MathUtils.star_vertices(folds, r_in * 0.3, r_in * 0.3 * config.inner_radius_ratio, rot)
	if config.show_lines:
		geo.add_outline(centre, true)

	# --- accent bosses around the rim (symmetry parameter) -------------------
	var boss_count := config.symmetry_folds
	if boss_count >= 3:
		for i in boss_count:
			var angle := rot + TAU * float(i) / float(boss_count)
			var boss_centre := MathUtils.polar_to_cart(r_out * 1.12, angle)
			var boss := MathUtils.regular_dot(boss_centre, r_out * 0.065, 6)
			if config.show_fills:
				geo.add_accent(boss)
			if config.show_lines:
				geo.add_outline(boss, true)
			geo.add_guide_point(boss_centre)

	# --- construction guides --------------------------------------------------
	geo.add_guide_circle(Vector2.ZERO, r_out)
	geo.add_guide_circle(Vector2.ZERO, r_in)
	for i in folds:
		# outer vertex and its axis
		var outer_angle := rot + step * float(i)
		geo.add_guide(PackedVector2Array([
			MathUtils.polar_to_cart(r_in * 0.4, outer_angle),
			MathUtils.polar_to_cart(r_out * 1.18, outer_angle),
		]))
		geo.add_guide_point(MathUtils.polar_to_cart(r_out, outer_angle))
		geo.add_guide_point(MathUtils.polar_to_cart(r_in, rot + step * (float(i) + 0.5)))
	geo.add_guide_point(Vector2.ZERO)
	return geo
