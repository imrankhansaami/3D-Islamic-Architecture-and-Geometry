class_name ColumnGenerator
extends RefCounted
## Reusable columns: a stacked profile of base, shaft and capital rings,
## revolved around the Y axis. Round columns use many segments (soft
## faceting reads as fluted stone); polygonal columns use few.

## Returns the column mesh with its origin at the column base (y = 0).
static func column_mesh(height: float, radius: float, sides: int = 20,
		taper: float = 0.9) -> ArrayMesh:
	var r := maxf(radius, 0.05)
	var h := maxf(height, 0.4)
	var profile := PackedVector2Array()
	# base plinth (two steps)
	profile.append(Vector2(r * 1.45, 0.0))
	profile.append(Vector2(r * 1.45, h * 0.055))
	profile.append(Vector2(r * 1.22, h * 0.055))
	profile.append(Vector2(r * 1.22, h * 0.10))
	# shaft (slight taper towards the capital)
	profile.append(Vector2(r * 1.02, h * 0.10))
	profile.append(Vector2(r * taper, h * 0.74))
	# capital (neck ring, echinus, abacus)
	profile.append(Vector2(r * 1.05, h * 0.74))
	profile.append(Vector2(r * 1.05, h * 0.80))
	profile.append(Vector2(r * 1.35, h * 0.86))
	profile.append(Vector2(r * 1.30, h * 0.92))
	profile.append(Vector2(r * 1.60, h * 0.92))
	profile.append(Vector2(r * 1.60, h * 1.0))
	return MeshBuilder.revolve(profile, maxi(6, sides), false, true, true)


## Full column node: stone shaft plus a thin bronze ring near the top.
static func column_node(height: float, radius: float, sides: int = 20) -> Node3D:
	var root := Node3D.new()
	var mesh := column_mesh(height, radius, sides)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MaterialLibrary.get_material("sandstone")
	root.add_child(mi)
	var ring := MeshBuilder.revolve(PackedVector2Array([
		Vector2(radius * 1.08, height * 0.70), Vector2(radius * 1.08, height * 0.735)]),
		maxi(6, sides), false, true, true)
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.material_override = MaterialLibrary.get_material("bronze")
	root.add_child(ring_node)
	return root


## Simple baluster posts used for balustrades (placed in a MultiMesh by the
## assembly code).
static func baluster_mesh(height: float, radius: float) -> ArrayMesh:
	var profile := PackedVector2Array([
		Vector2(radius * 0.75, 0.0),
		Vector2(radius * 0.75, height * 0.15),
		Vector2(radius * 0.5, height * 0.25),
		Vector2(radius, height * 0.6),
		Vector2(radius * 0.5, height * 0.85),
		Vector2(radius * 0.72, height),
	])
	return MeshBuilder.revolve(profile, 10, true, true, true)
