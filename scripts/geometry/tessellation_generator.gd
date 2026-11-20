class_name TessellationGenerator
extends RefCounted
## Tessellations: square, hexagonal and triangular grids of decorated cells.
##
## Every cell is a small geometric composition (a filled tile plus inscribed
## star/polygon line work). Cells are placed on the lattice of their shape, so
## they cover the pattern area without gaps or overlaps — the definition of a
## tessellation. Cells whose centre falls outside the pattern's outer radius
## are skipped, which clips the field into a medallion.

const MAX_CELLS := 220

# --- Square tessellation -----------------------------------------------------

static func build_square(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var n := clampi(config.repetition, 1, 14)
	while n * n > MAX_CELLS:
		n -= 1
	var tile := config.tile_size
	var r_clip := config.outer_radius
	var folds := config.star_points
	var rot := deg_to_rad(config.rotation_deg)
	var half := float(n - 1) * 0.5

	for i in n:
		for j in n:
			var centre := Vector2((float(i) - half) * tile, (float(j) - half) * tile)
			if centre.length() > r_clip:
				continue
			_add_square_cell(geo, config, centre, (i + j) % 2, tile, folds)

	geo.add_guide_circle(Vector2.ZERO, r_clip)
	geo.add_guide_point(Vector2.ZERO)
	geo.rotate_all(rot)
	return geo


static func _add_square_cell(geo: PatternGeometry, config: PatternConfig, centre: Vector2,
		parity: int, tile: float, folds: int) -> void:
	var cell := MathUtils.translate_points(
		MathUtils.polygon_vertices(4, tile * 0.7071, PI * 0.25), centre)
	if config.show_fills:
		if parity == 0:
			geo.add_fill(cell)
		else:
			geo.add_accent(cell)
	if config.show_lines:
		geo.add_outline(cell, true, 0.0)

	# inscribed star + its half-step twin: an interlaced star lattice
	var r_star := tile * 0.36
	var inner_ratio := config.inner_radius_ratio
	var star := MathUtils.star_vertices(folds, r_star, r_star * inner_ratio, PI * 0.5)
	geo.add_outline(MathUtils.translate_points(star, centre), true)
	if folds % 2 == 0:
		var twin := MathUtils.star_vertices(folds, r_star, r_star * inner_ratio, PI * 0.5 + PI / float(folds))
		geo.add_outline(MathUtils.translate_points(twin, centre), true)

	# centre diamond only inside fill-coloured cells (accent layer sits above)
	if parity == 0 and config.show_fills:
		geo.add_accent(MathUtils.regular_dot(centre, tile * 0.11, 4))
	geo.add_guide_point(centre)


# --- Hexagonal tessellation --------------------------------------------------

static func build_hex(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var rings := clampi(config.repetition, 1, 6)
	var tile := config.tile_size
	var r_clip := config.outer_radius
	var folds := config.star_points
	var rot := deg_to_rad(config.rotation_deg)
	var spacing_y := sqrt(3.0) * tile
	var cells := 0

	for q in range(-rings, rings + 1):
		for r in range(-rings, rings + 1):
			if absi(q + r) > rings:
				continue
			var centre := Vector2(1.5 * tile * float(q), spacing_y * (float(r) + float(q) * 0.5))
			if centre.length() > r_clip:
				continue
			if cells >= MAX_CELLS:
				break
			cells += 1
			var parity := posmod(q - r, 3)
			var cell := MathUtils.translate_points(MathUtils.polygon_vertices(6, tile, 0.0), centre)
			if config.show_fills:
				if parity == 0:
					geo.add_fill(cell)
				elif parity == 1:
					geo.add_accent(cell)
				else:
					geo.add_fill(cell)
			if config.show_lines:
				geo.add_outline(cell, true)
				# hexagram: inscribed star plus a rotated hexagon outline
				var r_star := tile * 0.62
				var star := MathUtils.star_vertices(folds, r_star, r_star * config.inner_radius_ratio, PI * 0.5)
				geo.add_outline(MathUtils.translate_points(star, centre), true)
				var inner_hex := MathUtils.translate_points(
					MathUtils.polygon_vertices(6, tile * 0.34, PI / 6.0), centre)
				geo.add_outline(inner_hex, true)
			if parity == 0 and config.show_fills:
				geo.add_accent(MathUtils.regular_dot(centre, tile * 0.12, 6))
			geo.add_guide_point(centre)

	geo.add_guide_circle(Vector2.ZERO, r_clip)
	geo.add_guide_point(Vector2.ZERO)
	geo.rotate_all(rot)
	return geo


# --- Triangular tessellation -------------------------------------------------

static func build_triangle(config: PatternConfig) -> PatternGeometry:
	var geo := PatternGeometry.new()
	var rows := clampi(config.repetition, 1, 9)
	var s := config.tile_size
	var r_clip := config.outer_radius
	var rot := deg_to_rad(config.rotation_deg)
	var h := s * sqrt(3.0) * 0.5
	var y_origin := -float(rows) * h * 0.5
	var cells := 0

	for row in rows:
		var y0 := y_origin + float(row) * h
		var offset := 0.5 * s * float(row % 2)
		var k_min := -rows - 1
		var k_max := rows + 1
		for k in range(k_min, k_max + 1):
			var x := float(k) * s + offset
			# upward triangle with its base at the bottom of the row
			var up_centre := Vector2(x + s * 0.5, y0 + h / 3.0)
			if up_centre.length() <= r_clip and cells < MAX_CELLS:
				cells += 1
				var up := PackedVector2Array([
					Vector2(x, y0), Vector2(x + s, y0), Vector2(x + s * 0.5, y0 + h)])
				_add_triangle_cell(geo, config, up, up_centre, 0)
			# downward triangle filling the gap between consecutive up triangles
			var down_centre := Vector2(x + s, y0 + h * 2.0 / 3.0)
			if down_centre.length() <= r_clip and cells < MAX_CELLS:
				cells += 1
				var down := PackedVector2Array([
					Vector2(x + s * 0.5, y0 + h), Vector2(x + s * 1.5, y0 + h), Vector2(x + s, y0)])
				_add_triangle_cell(geo, config, down, down_centre, 1)

	geo.add_guide_circle(Vector2.ZERO, r_clip)
	geo.add_guide_point(Vector2.ZERO)
	geo.rotate_all(rot)
	return geo


static func _add_triangle_cell(geo: PatternGeometry, config: PatternConfig,
		cell: PackedVector2Array, centre: Vector2, parity: int) -> void:
	if config.show_fills:
		if parity == 0:
			geo.add_fill(cell)
		else:
			geo.add_accent(cell)
	if config.show_lines:
		geo.add_outline(cell, true)
		# medial triangle: connect the edge midpoints
		var mid_ab := (cell[0] + cell[1]) * 0.5
		var mid_bc := (cell[1] + cell[2]) * 0.5
		var mid_ca := (cell[2] + cell[0]) * 0.5
		geo.add_outline(PackedVector2Array([mid_ab, mid_bc, mid_ca]), true)
		geo.add_segment(centre, cell[0])
		geo.add_segment(centre, cell[1])
		geo.add_segment(centre, cell[2])
	if parity == 0 and config.show_fills:
		geo.add_accent(MathUtils.regular_dot(centre, config.tile_size * 0.09, 3))
