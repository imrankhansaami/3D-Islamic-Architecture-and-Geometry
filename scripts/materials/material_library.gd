class_name MaterialLibrary
extends RefCounted
## Central material and colour-palette factory.
##
## All architectural and pattern materials are created once and cached, so the
## whole application reuses a small number of material resources (material
## reuse keeps draw calls and GPU state changes low).

## Islamic-inspired colour palettes offered by the laboratory.
## Each entry: display name + fill / accent / line colours (sRGB).
const PALETTES := [
	{
		"name": "Emerald & Gold",
		"fill": Color(0.055, 0.353, 0.275),
		"accent": Color(0.788, 0.635, 0.153),
		"line": Color(0.957, 0.933, 0.875),
	},
	{
		"name": "Lapis & Ivory",
		"fill": Color(0.106, 0.227, 0.420),
		"accent": Color(0.910, 0.863, 0.753),
		"line": Color(0.788, 0.635, 0.153),
	},
	{
		"name": "Turquoise & Sand",
		"fill": Color(0.180, 0.545, 0.545),
		"accent": Color(0.847, 0.765, 0.604),
		"line": Color(0.420, 0.310, 0.165),
	},
	{
		"name": "Bronze & Navy",
		"fill": Color(0.133, 0.204, 0.310),
		"accent": Color(0.549, 0.420, 0.247),
		"line": Color(0.890, 0.773, 0.404),
	},
	{
		"name": "Marble & Malachite",
		"fill": Color(0.937, 0.918, 0.847),
		"accent": Color(0.184, 0.420, 0.310),
		"line": Color(0.110, 0.165, 0.200),
	},
	{
		"name": "Midnight & Gold",
		"fill": Color(0.078, 0.118, 0.180),
		"accent": Color(0.788, 0.635, 0.153),
		"line": Color(0.890, 0.773, 0.404),
	},
]

static var _cache: Dictionary = {}


static func get_palette(palette_id: int) -> Dictionary:
	if palette_id < 0 or palette_id >= PALETTES.size():
		return {}
	return PALETTES[palette_id]


static func palette_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry: Dictionary in PALETTES:
		names.append(String(entry["name"]))
	return names


## Returns a cached standard material by well-known architectural name.
static func get_material(id: String) -> StandardMaterial3D:
	if _cache.has(id):
		return _cache[id]
	var mat := _make_named_material(id)
	_cache[id] = mat
	return mat


static func _make_named_material(id: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.8
	match id:
		"ivory_stone":
			mat.albedo_color = Color(0.93, 0.90, 0.83)
			mat.roughness = 0.72
		"sandstone":
			mat.albedo_color = Color(0.80, 0.69, 0.51)
			mat.roughness = 0.88
		"sandstone_dark":
			mat.albedo_color = Color(0.58, 0.48, 0.34)
			mat.roughness = 0.92
		"marble":
			mat.albedo_color = Color(0.87, 0.86, 0.83)
			mat.roughness = 0.34
		"marble_polished":
			mat.albedo_color = Color(0.90, 0.89, 0.86)
			mat.roughness = 0.18
		"plaster":
			mat.albedo_color = Color(0.88, 0.86, 0.79)
			mat.roughness = 0.94
		"dark_wood":
			mat.albedo_color = Color(0.23, 0.14, 0.09)
			mat.roughness = 0.65
		"bronze":
			mat.albedo_color = Color(0.45, 0.31, 0.16)
			mat.metallic = 0.85
			mat.roughness = 0.42
		"gold":
			mat.albedo_color = Color(0.83, 0.66, 0.24)
			mat.metallic = 0.9
			mat.roughness = 0.28
		"turquoise_tile":
			mat.albedo_color = Color(0.11, 0.45, 0.47)
			mat.roughness = 0.32
		"emerald_surface":
			mat.albedo_color = Color(0.05, 0.33, 0.25)
			mat.roughness = 0.4
		"lantern_glow":
			mat.albedo_color = Color(0.12, 0.09, 0.05)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.76, 0.38)
			mat.emission_energy_multiplier = 1.7
		"highlight":
			## Overlay used for hover feedback (assigned to material_overlay).
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_color = Color(1.0, 0.82, 0.35, 0.22)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"guide_line":
			## Construction guides in the laboratory overlay.
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.95, 0.80, 0.35, 0.9)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"guide_point":
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.90, 0.98, 1.0, 0.95)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_:
			mat.albedo_color = Color(0.8, 0.8, 0.8)
	return mat


## Water surface (vertex-displaced shader).
static func get_water_material() -> ShaderMaterial:
	if _cache.has("water_shader"):
		return _cache["water_shader"]
	var shader: Shader = load("res://shaders/water.gdshader")
	var mat := ShaderMaterial.new()
	if shader != null:
		mat.shader = shader
	_cache["water_shader"] = mat
	return mat


## Pattern layer materials (fill / accent / line), cached per colour.
static func pattern_material(color: Color, role: String) -> StandardMaterial3D:
	var key := "pattern_%s_%s" % [role, color.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	match role:
		"fill":
			mat.roughness = 0.55
			mat.metallic = 0.0
		"accent":
			mat.roughness = 0.38
			mat.metallic = 0.35
		"line":
			mat.roughness = 0.3
			mat.metallic = 0.65
		_:
			mat.roughness = 0.5
	_cache[key] = mat
	return mat


## Flat, unshaded material used for the transparent PNG pattern export.
static func flat_export_material(color: Color) -> StandardMaterial3D:
	var key := "flat_export_%s" % color.to_html(true)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
