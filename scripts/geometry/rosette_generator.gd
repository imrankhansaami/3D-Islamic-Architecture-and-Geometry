class_name RosetteGenerator
extends RefCounted
## Multi-layer radial rosettes — the signature motif of Islamic geometric art.
##
## Construction layers (repeated `folds` times by rotation around the centre):
##   1. base disc (fill)
##   2. petal ring: accent-filled kites on the symmetry axes
##   3. nested petal rings at 0.45x scale for `repetition` > 1 (line work)
##   4. two interlocking line stars (one rotated half an angular step)
##   5. accent bosses on the disc rim — count = symmetry slider
##
## Only the petal layer receives an accent fill, so no two accent polygons
## ever overlap (which would z-fight); deeper layers are line work above it.

static func build(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var folds := config.star_points
	var r := config.outer_radius
	var r_in := r * config.inner_radius_ratio
	var rot := deg_to_rad(config.rotation_deg)
	var step := TAU / float(folds)

	# --- base disc -----------------------------------------------------------
	if config.show_fills:
		geo.add_fill(MathUtils.polygon_vertices(64, r * 1.18))

	# --- petal rings ---------------------------------------------------------
	# Outermost ring is accent filled; each nested ring (repetition > 1) is
	# line work only, so the accent layer never overlaps itself.
	add_petal_ring(geo, config, folds, r, r_in, rot, step * 0.46, 1.0, true)
	for layer in range(1, config.repetition):
		var factor := pow(0.45, float(layer))
		var layer_rot := rot + step * 0.5 * float(layer)
		add_petal_ring(geo, config, folds, r, r_in, layer_rot, step * 0.46, factor, false)
		geo.add_guide_circle(Vector2.ZERO, r * 0.97 * factor)

	# --- two interlocking line stars -----------------------------------------
	# The classic construction: an n-point star and the same star rotated half
	# an angular step, their arms interlacing around the petal ring.
	if config.show_lines:
		var star_a := MathUtils.star_vertices(folds, r * 0.97, r * 0.97 * config.inner_radius_ratio, rot)
		geo.add_outline(star_a, true)
		var star_b := MathUtils.star_vertices(folds, r * 0.97, r * 0.97 * config.inner_radius_ratio, rot + step * 0.5)
		geo.add_outline(star_b, true)

	# --- rim bosses (symmetry parameter) ------------------------------------
	# Placed on the disc margin between petal tips, so they never overlap any
	# other accent polygon.
	var boss_count := maxi(3, config.symmetry_folds)
	for i in boss_count:
		var angle := rot + TAU * float(i) / float(boss_count) + step * 0.5
		var boss_centre := MathUtils.polar_to_cart(r * 1.065, angle)
		var boss := MathUtils.regular_dot(boss_centre, r * 0.052, 6)
		if config.show_fills:
			geo.add_accent(boss)
		if config.show_lines:
			geo.add_outline(boss, true)
		geo.add_guide_point(boss_centre)

	# --- construction guides -------------------------------------------------
	geo.add_guide_circle(Vector2.ZERO, r)
	geo.add_guide_circle(Vector2.ZERO, r_in)
	var axis_count := maxi(2, config.symmetry_folds)
	for i in axis_count:
		var angle := rot + TAU * float(i) / float(axis_count)
		geo.add_guide(PackedVector2Array([
			MathUtils.polar_to_cart(r * 0.5, angle),
			MathUtils.polar_to_cart(r * 1.2, angle),
		]))
	for i in folds:
		geo.add_guide_point(MathUtils.polar_to_cart(r * 0.97, rot + step * float(i)))
		geo.add_guide_point(MathUtils.polar_to_cart(r_in, rot + step * (float(i) + 0.5)))
	geo.add_guide_point(Vector2.ZERO)
	return geo


## One ring of `folds` petal kites along the symmetry axes.
## [param factor] scales the entire petal (nested layers); [param filled]
## adds the accent fill (only the outermost ring uses it).
static func add_petal_ring(geo: PatternGeometry, config: PatternConfig, folds: int,
		r: float, r_in: float, rot: float, petal_half: float,
		factor: float, filled: bool) -> void:
	for i in folds:
		var axis := rot + TAU * float(i) / float(folds)
		var tip_in := MathUtils.polar_to_cart(r_in * 0.82 * factor, axis)
		var tip_out := MathUtils.polar_to_cart(r * 0.97 * factor, axis)
		var side_left := MathUtils.polar_to_cart(r * 0.52 * factor, axis + petal_half)
		var side_right := MathUtils.polar_to_cart(r * 0.52 * factor, axis - petal_half)
		var petal := PackedVector2Array([tip_in, side_left, tip_out, side_right])
		if filled and config.show_fills:
			geo.add_accent(petal)
		if config.show_lines:
			geo.add_outline(petal, true)
