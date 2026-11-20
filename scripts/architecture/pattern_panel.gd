class_name PatternPanel
extends Node3D
## An architectural panel decorated with a generated pattern.
##
## The panel lives in its own XY plane (pattern facing +Z) with a stone
## backing plate and a raised gold frame; the assembly rotates and positions
## it on walls or floors. Panels listen to the PatternLibrary so applying a
## new pattern in the laboratory rebuilds only this panel.

static var _mesh_cache: Dictionary = {}

var panel_id := ""
var panel_size := Vector2(5.0, 4.0)
var relief := 0.05          ## pattern-space extrusion depth used on panels
var config: PatternConfig = null


func setup(id: String, size: Vector2, initial: PatternConfig) -> void:
	panel_id = id
	panel_size = size
	add_to_group("pattern_panels")
	set_meta("panel_id", id)
	rebuild(initial)


func rebuild(new_config: PatternConfig) -> void:
	config = new_config
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if config == null:
		return

	# --- stone backing plate -------------------------------------------------
	var backing := MeshBuilder.build_box(Vector3(panel_size.x + 0.30, panel_size.y + 0.30, 0.16))
	var backing_node := MeshInstance3D.new()
	backing_node.mesh = backing
	backing_node.material_override = MaterialLibrary.get_material("sandstone_dark")
	backing_node.position = Vector3(0, 0, -0.10)
	add_child(backing_node)

	# --- gold frame ----------------------------------------------------------
	var thickness := 0.09
	var frame_pieces: Array = [
		[Vector3(panel_size.x + 0.30, thickness, 0.09), Vector3(0, (panel_size.y + 0.30) * 0.5 - thickness * 0.5, 0.0)],
		[Vector3(panel_size.x + 0.30, thickness, 0.09), Vector3(0, -(panel_size.y + 0.30) * 0.5 + thickness * 0.5, 0.0)],
		[Vector3(thickness, panel_size.y + 0.30, 0.09), Vector3((panel_size.x + 0.30) * 0.5 - thickness * 0.5, 0, 0.0)],
		[Vector3(thickness, panel_size.y + 0.30, 0.09), Vector3(-(panel_size.x + 0.30) * 0.5 + thickness * 0.5, 0, 0.0)],
	]
	for piece: Array in frame_pieces:
		var frame_node := MeshInstance3D.new()
		frame_node.mesh = MeshBuilder.build_box(piece[0])
		frame_node.material_override = MaterialLibrary.get_material("gold")
		frame_node.position = piece[1]
		add_child(frame_node)

	# --- the pattern itself, fitted into the panel ---------------------------
	var eff := effective_config()
	var cache_key := "%s_w%.2f_h%.2f" % [eff.geometry_signature(), panel_size.x, panel_size.y]
	var entry: Dictionary = _mesh_cache.get(cache_key, {})
	if entry.is_empty():
		var geo := PatternEngine.generate(eff)
		var layers := MeshBuilder.build_pattern_layers(geo, eff)
		entry = {
			"layers": layers,
			"fit": minf(panel_size.x / maxf(geo.bounds.size.x, 0.01),
				panel_size.y / maxf(geo.bounds.size.y, 0.01)) * 0.94,
			"center": geo.bounds.get_center(),
		}
		if _mesh_cache.size() > 48:
			_mesh_cache.clear()
		_mesh_cache[cache_key] = entry

	var model := Node3D.new()
	model.scale = Vector3.ONE * float(entry["fit"])
	var centre: Vector2 = entry["center"]
	model.position = Vector3(-centre.x * float(entry["fit"]), -centre.y * float(entry["fit"]), 0.02)
	var colors := [eff.color_fill, eff.color_accent, eff.color_line]
	var roles := ["fill", "accent", "line"]
	var layers: Array = entry["layers"]
	for i in layers.size():
		var mesh: ArrayMesh = layers[i]
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = MaterialLibrary.pattern_material(colors[i], roles[i])
		model.add_child(mi)
	add_child(model)


## The config actually used for panels: the relief depth is clamped so the
## inlay stays physically plausible at architectural scale.
func effective_config() -> PatternConfig:
	var eff := config.clone()
	eff.extrusion_depth = clampf(eff.extrusion_depth, 0.0, relief)
	eff.clamp_values()
	return eff
