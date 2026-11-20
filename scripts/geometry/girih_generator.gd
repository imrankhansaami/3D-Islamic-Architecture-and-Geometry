class_name GirihGenerator
extends RefCounted
## Simplified girih-inspired network — a "star and cross" construction.
##
## IMPORTANT (documented limitation): this is a simplified procedural
## construction, NOT the historical girih tile method. Historically, girih
## patterns are drafted from a small set of decorated tiles (decagons,
## pentagons, hexagons, bowties and rhombs) that are assembled and then
## interlaced. Here the classic *outcome* is generated computationally:
##   * one n-fold star at every point of a square lattice (accent filled),
##   * strap polygons running along each star's facing edges to its four
##     neighbours (two parallel straps per neighbour, as in real strapwork),
##   * diamond tiles at the cell centres between four stars,
##   * an optional centred medallion whose fold count is the symmetry slider.
## The traditional tile-drafting rule set is explicitly NOT implemented.

static func build(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var folds := config.star_points
	var d := config.tile_size
	var n := clampi(config.repetition, 1, 7)
	var r_clip := config.outer_radius
	var rot := deg_to_rad(config.rotation_deg)
	var half := int((n - 1) / 2.0 + 0.5)
	var r_star := d * 0.42
	var medallion_enabled := config.symmetry_folds >= 3
	var medallion_folds := maxi(3, config.symmetry_folds)

	# --- stars on the square lattice -----------------------------------------
	for i in n:
		for j in n:
			var centre := Vector2(float(i - half) * d, float(j - half) * d)
			if centre.length() > r_clip:
				continue
			if medallion_enabled and i == half and j == half:
				_add_medallion(geo, config, centre, medallion_folds, d)
				continue
			var star := MathUtils.translate_points(
				MathUtils.star_vertices(folds, r_star, r_star * 0.5, PI * 0.5), centre)
			if config.show_fills:
				geo.add_accent(star)
			if config.show_lines:
				geo.add_outline(star, true)
			geo.add_guide_point(centre)

	# --- strap bands between neighbouring stars ------------------------------
	for i in n:
		for j in n:
			var centre := Vector2(float(i - half) * d, float(j - half) * d)
			if centre.length() > r_clip:
				continue
			if medallion_enabled and i == half and j == half:
				continue
			if i < n - 1:
				var right := centre + Vector2(d, 0.0)
				if right.length() <= r_clip:
					_add_band_pair(geo, config, folds, r_star, centre, right)
			if j < n - 1:
				var up := centre + Vector2(0.0, d)
				if up.length() <= r_clip:
					_add_band_pair(geo, config, folds, r_star, centre, up)

	# --- diamond tiles at the cell centres -----------------------------------
	for i in n - 1:
		for j in n - 1:
			var centre := Vector2((float(i - half) + 0.5) * d, (float(j - half) + 0.5) * d)
			if centre.length() > r_clip:
				continue
			# keep clear space around the medallion
			if medallion_enabled and centre.length() < d * 0.8:
				continue
			var diamond := MathUtils.regular_dot(centre, d * 0.25, 4)
			if config.show_fills:
				geo.add_accent(diamond)
			if config.show_lines:
				geo.add_outline(diamond, true)

	geo.add_guide_circle(Vector2.ZERO, r_clip)
	geo.add_guide_circle(Vector2.ZERO, d * 0.5)
	geo.rotate_all(rot)
	return geo


## The centred medallion: a star whose fold count is the symmetry slider,
## with construction circles (drawn as guides).
static func _add_medallion(geo: PatternGeometry, config: PatternConfig,
		centre: Vector2, folds: int, d: float) -> void:
	var star := MathUtils.translate_points(
		MathUtils.star_vertices(folds, d * 0.5, d * 0.5 * 0.5, PI * 0.5), centre)
	if config.show_fills:
		geo.add_accent(star)
	if config.show_lines:
		geo.add_outline(star, true)
	geo.add_guide_circle(centre, d * 0.5)
	geo.add_guide_circle(centre, d * 0.62)
	geo.add_guide_point(centre)


## Adds the two parallel strap polygons connecting the star at [param a] to the
## star at [param b]. Each strap runs from a star point along the star's own
## edge into the gap, so straps share edges with the stars instead of
## overlapping them.
static func _add_band_pair(geo: PatternGeometry, config: PatternConfig,
		folds: int, r_star: float, a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	var list_a := MathUtils.star_vertices(folds, r_star, r_star * 0.5, PI * 0.5)
	var list_b := MathUtils.star_vertices(folds, r_star, r_star * 0.5, PI * 0.5)
	var n := list_a.size()
	var ia := _best_outer_index(folds, dir, PI * 0.5)
	var ib := _best_outer_index(folds, -dir, PI * 0.5)
	var a_out := a + list_a[ia]
	var b_out := b + list_b[ib]
	var a_in_up := a + list_a[(ia + 1) % n]
	var b_in_up := b + list_b[(ib - 1 + n) % n]
	var a_in_down := a + list_a[(ia - 1 + n) % n]
	var b_in_down := b + list_b[(ib + 1) % n]
	var upper := PackedVector2Array([a_out, a_in_up, b_in_up, b_out])
	var lower := PackedVector2Array([a_out, b_out, b_in_down, a_in_down])
	for strap: PackedVector2Array in [upper, lower]:
		if config.show_fills:
			geo.add_accent(strap)
		if config.show_lines:
			geo.add_outline(strap, true)


## Index (into the star vertex list) of the outer vertex pointing most closely
## along [param dir].
static func _best_outer_index(folds: int, dir: Vector2, rotation: float) -> int:
	var best := 0
	var best_dot := -INF
	var step := TAU / float(folds)
	for i in folds:
		var angle := rotation + step * float(i)
		var dd := Vector2(cos(angle), sin(angle)).dot(dir)
		if dd > best_dot:
			best_dot = dd
			best = i * 2
	return best
