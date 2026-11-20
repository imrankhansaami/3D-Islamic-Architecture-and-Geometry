class_name DecorationGenerator
extends RefCounted
## Decorative procedural elements: the courtyard fountain, floor inlay bands,
## hanging lanterns, crenellations and steps.

## Octagonal fountain: basin wall, animated water surface, pedestal and cap.
## Origin at the centre of the courtyard floor.
static func fountain_node() -> Node3D:
	var root := Node3D.new()
	root.name = "Fountain"

	# octagonal basin wall (a ring: outer and inner octagon prism)
	var outer_r := 3.4
	var inner_r := 3.0
	var height := 0.62
	var polygons: Array = []
	var ring_outer := MathUtils.polygon_vertices(8, outer_r)
	var ring_inner := MathUtils.polygon_vertices(8, inner_r)
	# the ring is built as 8 quads between the octagons
	for i in 8:
		var j := (i + 1) % 8
		polygons.append(PackedVector2Array([
			ring_inner[i], ring_outer[i], ring_outer[j], ring_inner[j]]))
	var basin := MeshBuilder.build_slab_mesh(polygons, 0.0, height)
	var basin_node := MeshInstance3D.new()
	basin_node.mesh = basin
	basin_node.material_override = MaterialLibrary.get_material("marble")
	root.add_child(basin_node)
	# basin rim ring (gold)
	var rim := MeshBuilder.revolve(PackedVector2Array([
		Vector2(inner_r - 0.06, height), Vector2(outer_r + 0.06, height),
		Vector2(outer_r + 0.06, height + 0.05), Vector2(inner_r - 0.06, height + 0.05)]),
		8, false, true, true)
	var rim_node := MeshInstance3D.new()
	rim_node.mesh = rim
	rim_node.material_override = MaterialLibrary.get_material("gold")
	root.add_child(rim_node)

	# water surface (vertex-displaced shader)
	var water := MeshBuilder.revolve(PackedVector2Array([
		Vector2(inner_r - 0.05, 0.0), Vector2(inner_r - 0.05, 0.02)]), 40, true, true, true)
	var water_node := MeshInstance3D.new()
	water_node.mesh = water
	water_node.material_override = MaterialLibrary.get_water_material()
	water_node.position = Vector3(0, height - 0.1, 0)
	water_node.set_meta("is_water", true)
	root.add_child(water_node)

	# central pedestal + onion cap
	var pedestal := MeshBuilder.revolve(PackedVector2Array([
		Vector2(0.75, 0.0), Vector2(0.75, 0.25), Vector2(0.45, 0.35), Vector2(0.45, 0.95),
		Vector2(0.62, 1.05), Vector2(0.62, 1.25)]), 16, false, true, true)
	var pedestal_node := MeshInstance3D.new()
	pedestal_node.mesh = pedestal
	pedestal_node.material_override = MaterialLibrary.get_material("marble")
	root.add_child(pedestal_node)
	var cap := MeshBuilder.revolve(DomeGenerator.dome_profile(1.0, 0.95, DomeGenerator.Style.ONION, 16), 20, true, false, false)
	var cap_node := MeshInstance3D.new()
	cap_node.mesh = cap
	cap_node.material_override = MaterialLibrary.get_material("turquoise_tile")
	cap_node.position = Vector3(0, 1.2, 0)
	root.add_child(cap_node)
	var finial := DomeGenerator.finial_mesh(0.7, 0.11)
	var finial_node := MeshInstance3D.new()
	finial_node.mesh = finial
	finial_node.material_override = MaterialLibrary.get_material("gold")
	finial_node.position = Vector3(0, 2.1, 0)
	root.add_child(finial_node)

	root.set_meta("info_id", "fountain")
	return root


## Courtyard perimeter inlay: a gold line frame plus a row of accent squares.
## Returns an array of MeshInstance3D (origin at courtyard centre, lying flat
## in the XZ plane at y ≈ 0.03).
static func floor_band_nodes(court_half: float) -> Array:
	var material_line := MaterialLibrary.pattern_material(NoorTheme.GOLD, "line")
	var material_accent := MaterialLibrary.pattern_material(Color(0.20, 0.45, 0.38), "fill")
	var nodes: Array = []

	# frame: two concentric square ribbons (built as flat slabs, then rotated)
	var frame_polys: Array = []
	for inset: float in [0.9, 1.35]:
		var half := court_half - inset
		var w := 0.16
		var quads: Array = [
			PackedVector2Array([Vector2(-half, half), Vector2(half, half), Vector2(half, half - w), Vector2(-half, half - w)]),
			PackedVector2Array([Vector2(-half, -half + w), Vector2(half, -half + w), Vector2(half, -half), Vector2(-half, -half)]),
			PackedVector2Array([Vector2(-half, -half + w), Vector2(-half + w, -half + w), Vector2(-half + w, half - w), Vector2(-half, half - w)]),
			PackedVector2Array([Vector2(half - w, -half + w), Vector2(half, -half + w), Vector2(half, half - w), Vector2(half - w, half - w)]),
		]
		frame_polys.append_array(quads)
	var frame_node := MeshInstance3D.new()
	frame_node.mesh = MeshBuilder.build_slab_mesh(frame_polys, 0.0, 0.0)
	frame_node.rotation_degrees.x = -90
	frame_node.position = Vector3(0, 0.035, 0)
	frame_node.material_override = material_line
	nodes.append(frame_node)

	# accent square rosettes along the band
	var squares: Array = []
	var step := 4.0
	var count := int((court_half - 2.6) / step * 2.0)
	for i in range(-count, count + 1):
		var pos := float(i) * step
		if absf(pos) > court_half - 2.6:
			continue
		for axis: int in [0, 1]:
			for side: float in [-1.0, 1.0]:
				var centre := Vector2(pos, side * (court_half - 1.85)) if axis == 0 else Vector2(side * (court_half - 1.85), pos)
				var square := MathUtils.regular_dot(centre, 0.42, 4)
				squares.append(square)
				squares.append(MathUtils.regular_dot(centre, 0.24, 8))
	var square_node := MeshInstance3D.new()
	square_node.mesh = MeshBuilder.build_slab_mesh(squares, 0.0, 0.0)
	square_node.rotation_degrees.x = -90
	square_node.position = Vector3(0, 0.03, 0)
	square_node.material_override = material_accent
	nodes.append(square_node)
	return nodes


## Hanging lantern: bronze body with an emissive core. Origin at the hanging
## point (the lantern hangs below it).
static func lantern_node(hang: float = 0.75) -> Node3D:
	var root := Node3D.new()
	var chain := MeshBuilder.revolve(PackedVector2Array([
		Vector2(0.02, -hang), Vector2(0.02, 0.0)]), 6, false, true, true)
	var chain_node := MeshInstance3D.new()
	chain_node.mesh = chain
	chain_node.material_override = MaterialLibrary.get_material("bronze")
	root.add_child(chain_node)
	var body := MeshBuilder.revolve(PackedVector2Array([
		Vector2(0.10, -hang), Vector2(0.26, -hang - 0.20), Vector2(0.30, -hang - 0.48),
		Vector2(0.14, -hang - 0.72), Vector2(0.10, -hang - 0.78)]), 8, false, true, true)
	var body_node := MeshInstance3D.new()
	body_node.mesh = body
	body_node.material_override = MaterialLibrary.get_material("bronze")
	root.add_child(body_node)
	var core := MeshBuilder.revolve(PackedVector2Array([
		Vector2(0.16, -hang - 0.24), Vector2(0.20, -hang - 0.44)]), 8, false, true, true)
	var core_node := MeshInstance3D.new()
	core_node.mesh = core
	core_node.material_override = MaterialLibrary.get_material("lantern_glow")
	root.add_child(core_node)
	return root


## Transform list for a row of crenellation cubes along a line.
static func crenellation_transforms(from: Vector3, to: Vector3, spacing: float,
		size: Vector3, height_offset: float = 0.0) -> Array:
	var transforms: Array = []
	var span := to - from
	var length := span.length()
	if length < 0.1:
		return transforms
	var count := maxi(2, int(length / spacing))
	var dir := span.normalized()
	for i in count:
		var p := from + dir * (length * float(i) / float(count - 1))
		p.y += height_offset + size.y * 0.5
		transforms.append(Transform3D(Basis(), p))
	return transforms


## Step stairs: returns {"node": Node3D, "collision": Array}.
## Stairs run along +Z from the origin, rising by count*rise.
static func stairs(width: float, run: float, rise: float, count: int,
		material_id: String = "sandstone") -> Dictionary:
	var node := Node3D.new()
	var collision: Array = []
	for i in count:
		var step_h := rise * float(i + 1)
		var step := MeshBuilder.build_box(Vector3(width, step_h, run))
		var mi := MeshInstance3D.new()
		mi.mesh = step
		mi.material_override = MaterialLibrary.get_material(material_id)
		var z := run * (float(i) + 0.5)
		mi.position = Vector3(0, step_h * 0.5, z)
		node.add_child(mi)
		collision.append({
			"shape": "box",
			"position": Vector3(0, step_h * 0.5, z),
			"size": Vector3(width, step_h, run),
		})
	return {"node": node, "collision": collision}
