class_name MinaretGenerator
extends RefCounted
## Tall, slender towers: a faceted base, tapered shafts, a decorated balcony
## with balustrade, a lantern and an onion cap with a finial.
## All proportions are relative to the total height H.

## Returns a Node3D with several MeshInstance3D children (stone / bronze /
## glow materials). The origin is the tower base.
static func build(height: float) -> Node3D:
	var h := maxf(height, 8.0)
	var root := Node3D.new()
	root.name = "Minaret"
	var stone := MaterialLibrary.get_material("sandstone")
	var bronze := MaterialLibrary.get_material("bronze")
	var gold := MaterialLibrary.get_material("gold")

	# base: faceted prism with a chamfered cap
	var base_profile := PackedVector2Array([
		Vector2(h * 0.075, 0.0),
		Vector2(h * 0.075, h * 0.105),
		Vector2(h * 0.062, h * 0.13),
	])
	var base_node := _mesh_node(MeshBuilder.revolve(base_profile, 8, false, true, true), stone)
	root.add_child(base_node)

	# shaft 1: tapered cylinder
	var shaft1 := PackedVector2Array([
		Vector2(h * 0.058, h * 0.13),
		Vector2(h * 0.050, h * 0.52),
	])
	root.add_child(_mesh_node(MeshBuilder.revolve(shaft1, 14, false, true, true), stone))

	# decorative bands on the shaft
	for t: float in [0.22, 0.38]:
		var band := PackedVector2Array([
			Vector2(h * 0.061, h * t),
			Vector2(h * 0.061, h * (t + 0.012)),
		])
		root.add_child(_mesh_node(MeshBuilder.revolve(band, 14, false, true, true), bronze))

	# balcony: slab, rail ring, balustrade posts
	var balcony_y := h * 0.55
	var slab := PackedVector2Array([
		Vector2(h * 0.098, balcony_y - h * 0.014),
		Vector2(h * 0.098, balcony_y),
	])
	root.add_child(_mesh_node(MeshBuilder.revolve(slab, 16, false, true, true), stone))
	var bowl := PackedVector2Array([
		Vector2(h * 0.062, balcony_y - h * 0.03),
		Vector2(h * 0.09, balcony_y - h * 0.014),
	])
	root.add_child(_mesh_node(MeshBuilder.revolve(bowl, 14, false, false, false), stone))
	var rail := PackedVector2Array([
		Vector2(h * 0.075, balcony_y + h * 0.032),
		Vector2(h * 0.088, balcony_y + h * 0.038),
		Vector2(h * 0.088, balcony_y + h * 0.046),
	])
	root.add_child(_mesh_node(MeshBuilder.revolve(rail, 16, false, false, true), bronze))

	# balustrade posts (MultiMesh: one draw call)
	var post_mesh := ColumnGenerator.baluster_mesh(h * 0.042, h * 0.006)
	var transforms: Array = []
	var post_count := 18
	for i in post_count:
		var angle := TAU * float(i) / float(post_count)
		var pos := MathUtils.polar_to_cart(h * 0.086, angle)
		transforms.append(Transform3D(Basis(), Vector3(pos.x, balcony_y, pos.y)))
	root.add_child(MeshBuilder.multimesh_instance(post_mesh, stone, transforms, "Balustrade"))

	# shaft 2 (upper)
	var shaft2 := PackedVector2Array([
		Vector2(h * 0.046, balcony_y + h * 0.05),
		Vector2(h * 0.038, h * 0.82),
	])
	root.add_child(_mesh_node(MeshBuilder.revolve(shaft2, 12, false, true, true), stone))
	for t: float in [0.66, 0.74]:
		var band2 := _band_profile(h, t)
		root.add_child(_mesh_node(MeshBuilder.revolve(band2, 12, false, true, true), bronze))

	# lantern (glowing box with a bronze roof)
	var lantern := MeshBuilder.build_box(Vector3(h * 0.045, h * 0.05, h * 0.045))
	var lantern_node := _mesh_node(lantern, MaterialLibrary.get_material("lantern_glow"))
	lantern_node.position = Vector3(0, h * 0.855, 0)
	root.add_child(lantern_node)
	var lantern_roof := _mesh_node(MeshBuilder.build_box(Vector3(h * 0.068, h * 0.016, h * 0.068)), bronze)
	lantern_roof.position = Vector3(0, h * 0.885, 0)
	root.add_child(lantern_roof)

	# cap: onion dome + finial
	var cap_radius := h * 0.055
	var cap_height := h * 0.062
	var cap_node := _mesh_node(DomeGenerator.dome_mesh(cap_radius, cap_height, DomeGenerator.Style.ONION, 20), stone)
	cap_node.position = Vector3(0, h * 0.91, 0)
	root.add_child(cap_node)
	var finial := _mesh_node(DomeGenerator.finial_mesh(h * 0.075, cap_radius * 0.5), gold)
	finial.position = Vector3(0, h * 0.97, 0)
	root.add_child(finial)

	# metadata for the assembly: interactive proxy + lantern light position
	root.set_meta("info_id", "minaret")
	root.set_meta("collision", {"shape": "cylinder", "radius": h * 0.085, "height": h})
	root.set_meta("lantern_position", Vector3(0, h * 0.855, 0))
	return root


static func _mesh_node(mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node


## Simple ring profile used for the upper shaft decorations.
static func _band_profile(h: float, t: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(h * 0.048, h * t),
		Vector2(h * 0.048, h * (t + 0.01)),
	])
