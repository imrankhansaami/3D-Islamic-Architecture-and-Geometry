class_name PatternConfig
extends Resource
## Complete parameter set for one procedurally generated pattern.
##
## This is the single source of truth used by the geometry engine, the
## laboratory UI, the transformation studio, the learning mode examples and
## the architectural panels. It can be serialised to JSON (save/load).

enum PatternType {
	STAR,            ## n-point star with adjustable inner radius
	POLY_REGULAR,    ## regular polygon (with optional rotated copies)
	POLY_OVERLAP,    ## one polygon rotated N times into a flower
	POLY_CONCENTRIC, ## nested polygons of decreasing radius
	POLY_RADIAL,     ## small polygons arranged around a circle
	ROSETTE,         ## multi-layer radial rosette
	TESS_SQUARE,     ## square tessellation with inscribed stars
	TESS_HEX,        ## hexagonal tessellation
	TESS_TRIANGLE,   ## triangular tessellation
	GIRIH,           ## simplified girih-inspired star & cross network
}

const TYPE_NAMES: PackedStringArray = [
	"Star (n-point)",
	"Regular Polygon",
	"Overlapping Polygons",
	"Concentric Polygons",
	"Radial Arrangement",
	"Rosette",
	"Tessellation — Square",
	"Tessellation — Hexagonal",
	"Tessellation — Triangular",
	"Girih-Inspired (star & cross)",
]

# --- Parameters (mirror the laboratory control table in the README) ----------
@export var pattern_type: int = PatternType.STAR
@export var sides: int = 8                 ## number of polygon sides / tessellation base
@export var star_points: int = 8           ## star / rosette fold count
@export var rotation_deg: float = 0.0      ## pattern rotation in degrees
@export var symmetry_folds: int = 8        ## radial / reflection symmetry count
@export var scale: float = 1.0             ## overall size multiplier
@export var repetition: int = 1            ## ring / cell repetition count
@export var tile_size: float = 2.0         ## tessellation tile size (world units)
@export var line_thickness: float = 0.06   ## width of drawn geometric lines
@export var extrusion_depth: float = 0.12  ## 2D -> 3D extrusion depth (0 = flat)
@export var inner_radius_ratio: float = 0.45 ## inner/outer radius ratio for stars
@export var outer_radius: float = 2.5      ## overall pattern radius
@export var palette: int = 0               ## index into MaterialLibrary palette list

@export var color_fill: Color = Color("0E5A46")
@export var color_accent: Color = Color("C9A227")
@export var color_line: Color = Color("F4EEDF")

@export var show_fills: bool = true
@export var show_lines: bool = true
@export var show_guides: bool = false      ## construction overlay (vertices/axes/circles)

@export var seed: int = 20261               ## deterministic randomisation seed
@export var bevel: float = 0.0             ## chamfer width used by the 3D studio

# --- Validation ranges -------------------------------------------------------
const SIDES_MIN := 3
const SIDES_MAX := 24
const POINTS_MIN := 3
const POINTS_MAX := 24
const SYMMETRY_MIN := 1
const SYMMETRY_MAX := 24
const REPETITION_MIN := 1
const REPETITION_MAX := 12
const SCALE_MIN := 0.2
const SCALE_MAX := 3.0
const TILE_MIN := 0.4
const TILE_MAX := 6.0
const LINE_MIN := 0.005
const LINE_MAX := 0.3
const EXTRUDE_MIN := 0.0
const EXTRUDE_MAX := 0.8
const INNER_MIN := 0.1
const INNER_MAX := 0.95
const OUTER_MIN := 0.5
const OUTER_MAX := 6.0
const BEVEL_MIN := 0.0
const BEVEL_MAX := 0.5


func clamp_values() -> void:
	sides = clampi(sides, SIDES_MIN, SIDES_MAX)
	star_points = clampi(star_points, POINTS_MIN, POINTS_MAX)
	symmetry_folds = clampi(symmetry_folds, SYMMETRY_MIN, SYMMETRY_MAX)
	repetition = clampi(repetition, REPETITION_MIN, REPETITION_MAX)
	scale = clampf(scale, SCALE_MIN, SCALE_MAX)
	tile_size = clampf(tile_size, TILE_MIN, TILE_MAX)
	line_thickness = clampf(line_thickness, LINE_MIN, LINE_MAX)
	extrusion_depth = clampf(extrusion_depth, EXTRUDE_MIN, EXTRUDE_MAX)
	inner_radius_ratio = clampf(inner_radius_ratio, INNER_MIN, INNER_MAX)
	outer_radius = clampf(outer_radius, OUTER_MIN, OUTER_MAX)
	bevel = clampf(bevel, BEVEL_MIN, BEVEL_MAX)
	rotation_deg = fposmod(rotation_deg, 360.0)
	palette = clampi(palette, -1, MaterialLibrary.PALETTES.size() - 1)


func type_name() -> String:
	if pattern_type >= 0 and pattern_type < TYPE_NAMES.size():
		return TYPE_NAMES[pattern_type]
	return "Unknown"


func clone() -> PatternConfig:
	var copy := PatternConfig.new()
	copy.copy_from(self)
	return copy


func copy_from(other: PatternConfig) -> void:
	pattern_type = other.pattern_type
	sides = other.sides
	star_points = other.star_points
	rotation_deg = other.rotation_deg
	symmetry_folds = other.symmetry_folds
	scale = other.scale
	repetition = other.repetition
	tile_size = other.tile_size
	line_thickness = other.line_thickness
	extrusion_depth = other.extrusion_depth
	inner_radius_ratio = other.inner_radius_ratio
	outer_radius = other.outer_radius
	palette = other.palette
	color_fill = other.color_fill
	color_accent = other.color_accent
	color_line = other.color_line
	show_fills = other.show_fills
	show_lines = other.show_lines
	show_guides = other.show_guides
	seed = other.seed
	bevel = other.bevel


## Deterministic randomisation: the same seed always yields the same pattern.
func randomize_params(rng: RandomNumberGenerator) -> void:
	pattern_type = rng.randi_range(0, TYPE_NAMES.size() - 1)
	sides = rng.randi_range(3, 12)
	star_points = rng.randi_range(4, 16)
	symmetry_folds = rng.randi_range(4, 12)
	rotation_deg = rng.randf_range(0.0, 360.0)
	repetition = rng.randi_range(1, 4)
	tile_size = rng.randf_range(1.2, 3.0)
	inner_radius_ratio = rng.randf_range(0.25, 0.7)
	outer_radius = rng.randf_range(1.8, 3.2)
	line_thickness = rng.randf_range(0.04, 0.1)
	palette = rng.randi_range(0, MaterialLibrary.PALETTES.size() - 1)
	apply_palette(palette)
	clamp_values()


func apply_palette(palette_id: int) -> void:
	var entry: Dictionary = MaterialLibrary.get_palette(palette_id)
	if entry.is_empty():
		return
	palette = palette_id
	color_fill = entry["fill"]
	color_accent = entry["accent"]
	color_line = entry["line"]


## Parameter signature used as a mesh-cache key. Deliberately excludes
## colours (meshes are colour-independent) and UI-only flags.
func geometry_signature(flat: bool = false) -> String:
	return "t%d_s%d_p%d_r%.2f_y%d_sc%.3f_rep%d_ts%.3f_ln%.4f_ex%.3f_in%.3f_out%.3f_bv%.3f_flat%d" % [
		pattern_type, sides, star_points, rotation_deg, symmetry_folds, scale,
		repetition, tile_size, line_thickness, extrusion_depth,
		inner_radius_ratio, outer_radius, bevel, 1 if flat else 0,
	]


## Human readable summary of the parameters that shape this pattern (used in
## the laboratory info panel and the architectural panel tooltips).
func describe_short() -> String:
	var lines: Array[String] = []
	lines.append("Type: %s" % type_name())
	match pattern_type:
		PatternType.STAR:
			lines.append("Fold: %d points, inner/outer radius ratio %.2f" % [star_points, inner_radius_ratio])
		PatternType.POLY_REGULAR, PatternType.POLY_OVERLAP, PatternType.POLY_CONCENTRIC, PatternType.POLY_RADIAL:
			lines.append("Polygon sides: %d" % sides)
		PatternType.ROSETTE:
			lines.append("Fold: %d, layers: %d, mirror folds: %d" % [star_points, repetition, symmetry_folds])
		PatternType.TESS_SQUARE, PatternType.TESS_HEX, PatternType.TESS_TRIANGLE:
			lines.append("Cells per side: %d, tile size: %.2f" % [repetition, tile_size])
		PatternType.GIRIH:
			lines.append("Star folds: %d, lattice: %d cells" % [star_points, repetition])
	lines.append("Outer radius: %.2f, scale: %.2f, rotation: %.1f°" % [outer_radius, scale, rotation_deg])
	return "\n".join(lines)


# --- Serialisation -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"type": pattern_type,
		"sides": sides,
		"star_points": star_points,
		"rotation": rotation_deg,
		"symmetry": symmetry_folds,
		"scale": scale,
		"repetition": repetition,
		"tile_size": tile_size,
		"line_thickness": line_thickness,
		"extrusion": extrusion_depth,
		"inner_ratio": inner_radius_ratio,
		"outer_radius": outer_radius,
		"palette": palette,
		"color_fill": color_fill.to_html(true),
		"color_accent": color_accent.to_html(true),
		"color_line": color_line.to_html(true),
		"show_fills": show_fills,
		"show_lines": show_lines,
		"show_guides": show_guides,
		"seed": seed,
		"bevel": bevel,
	}


func from_dict(data: Dictionary) -> void:
	pattern_type = int(data.get("type", PatternType.STAR))
	sides = int(data.get("sides", 8))
	star_points = int(data.get("star_points", 8))
	rotation_deg = float(data.get("rotation", 0.0))
	symmetry_folds = int(data.get("symmetry", 8))
	scale = float(data.get("scale", 1.0))
	repetition = int(data.get("repetition", 1))
	tile_size = float(data.get("tile_size", 2.0))
	line_thickness = float(data.get("line_thickness", 0.06))
	extrusion_depth = float(data.get("extrusion", 0.12))
	inner_radius_ratio = float(data.get("inner_ratio", 0.45))
	outer_radius = float(data.get("outer_radius", 2.5))
	palette = int(data.get("palette", 0))
	color_fill = Color.html(String(data.get("color_fill", "0E5A46")))
	color_accent = Color.html(String(data.get("color_accent", "C9A227")))
	color_line = Color.html(String(data.get("color_line", "F4EEDF")))
	show_fills = bool(data.get("show_fills", true))
	show_lines = bool(data.get("show_lines", true))
	show_guides = bool(data.get("show_guides", false))
	seed = int(data.get("seed", 20261))
	bevel = float(data.get("bevel", 0.0))
	clamp_values()


func to_json() -> String:
	return JSON.stringify(to_dict(), "\t")


static func from_json(text: String) -> PatternConfig:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var config := PatternConfig.new()
	config.from_dict(data)
	return config
