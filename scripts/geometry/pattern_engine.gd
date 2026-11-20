class_name PatternEngine
extends RefCounted
## Orchestrates pattern generation: picks the right generator for the
## requested pattern type, applies the global scale, validates the result and
## reports generation statistics.
##
## The engine is deliberately free of any UI, rendering or scene logic: it maps
## a [PatternConfig] to pure geometry data.

static func generate(config: PatternConfig) -> PatternGeometry:
	var c := config.clone()
	c.clamp_values()
	var geo: PatternGeometry
	match c.pattern_type:
		PatternConfig.PatternType.STAR:
			geo = StarGenerator.build(c)
		PatternConfig.PatternType.POLY_REGULAR:
			geo = PolygonGenerator.build_regular(c)
		PatternConfig.PatternType.POLY_OVERLAP:
			geo = PolygonGenerator.build_overlap(c)
		PatternConfig.PatternType.POLY_CONCENTRIC:
			geo = PolygonGenerator.build_concentric(c)
		PatternConfig.PatternType.POLY_RADIAL:
			geo = PolygonGenerator.build_radial(c)
		PatternConfig.PatternType.ROSETTE:
			geo = RosetteGenerator.build(c)
		PatternConfig.PatternType.TESS_SQUARE:
			geo = TessellationGenerator.build_square(c)
		PatternConfig.PatternType.TESS_HEX:
			geo = TessellationGenerator.build_hex(c)
		PatternConfig.PatternType.TESS_TRIANGLE:
			geo = TessellationGenerator.build_triangle(c)
		PatternConfig.PatternType.GIRIH:
			geo = GirihGenerator.build(c)
		_:
			geo = StarGenerator.build(c)
	if c.scale != 1.0:
		geo.scale_all(c.scale)
	geo.compute()
	return geo


## Returns [geometry, generation_time_msec] for the laboratory status bar.
static func generate_timed(config: PatternConfig) -> Array:
	var start := Time.get_ticks_usec()
	var geo := generate(config)
	var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0
	return [geo, elapsed_ms]


## Which parameters actually affect each pattern type — the laboratory UI uses
## this to show only the relevant controls.
static func relevant_params(pattern_type: int) -> Dictionary:
	match pattern_type:
		PatternConfig.PatternType.STAR:
			return {
				"star_points": true, "inner_radius_ratio": true, "outer_radius": true,
				"sides": false, "tile_size": false, "symmetry_folds": true,
				"repetition": true, "rotation_deg": true,
			}
		PatternConfig.PatternType.POLY_REGULAR:
			return {"sides": true, "repetition": true, "outer_radius": true, "rotation_deg": true}
		PatternConfig.PatternType.POLY_OVERLAP:
			return {"sides": true, "symmetry_folds": true, "outer_radius": true, "rotation_deg": true}
		PatternConfig.PatternType.POLY_CONCENTRIC:
			return {"sides": true, "repetition": true, "outer_radius": true, "rotation_deg": true}
		PatternConfig.PatternType.POLY_RADIAL:
			return {"sides": true, "symmetry_folds": true, "repetition": true, "outer_radius": true, "rotation_deg": true}
		PatternConfig.PatternType.ROSETTE:
			return {
				"star_points": true, "inner_radius_ratio": true, "outer_radius": true,
				"repetition": true, "symmetry_folds": true, "rotation_deg": true,
			}
		PatternConfig.PatternType.TESS_SQUARE, PatternConfig.PatternType.TESS_HEX, PatternConfig.PatternType.TESS_TRIANGLE:
			return {
				"tile_size": true, "repetition": true, "outer_radius": true,
				"star_points": true, "inner_radius_ratio": true, "rotation_deg": true,
			}
		PatternConfig.PatternType.GIRIH:
			return {
				"star_points": true, "tile_size": true, "repetition": true,
				"outer_radius": true, "symmetry_folds": true, "rotation_deg": true,
			}
	return {}
