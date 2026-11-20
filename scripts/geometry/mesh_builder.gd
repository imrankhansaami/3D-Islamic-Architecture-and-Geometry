class_name MeshBuilder
extends RefCounted
## Procedural mesh construction.
##
## Everything visible in NOOR is built here at runtime:
##   * 2D polygons       -> flat or extruded (optionally chamfered) 3D slabs
##   * polyline segments -> extruded ribbons with junction dots
##   * revolution        -> domes, columns, minarets, rings (smooth/faceted)
##   * boxes and MultiMesh helpers for repeated architectural details
##
## Winding: triangles are added by [method add_triangle], which orders the
## vertices so the surface's geometric normal points along the requested
## outward direction using Godot's front-face convention (see
## FRONT_NORMAL_SIGN, verified by the self test).

## Winding convention: Godot's front face (the visible one with back-face
## culling) is the side OPPOSITE the geometric cross product (b-a)x(c-a),
## confirmed by the self test probe (generate_normals on a CCW triangle returns
## the flipped normal). add_triangle therefore orders vertices so
## cross ∝ outward * FRONT_NORMAL_SIGN. Set to +1.0 should a future engine
## build change the convention.
const FRONT_NORMAL_SIGN := -1.0

## Vertical gap between pattern layers (prevents coplanar z-fighting).
const LAYER_GAP := 0.004
## Lift of ribbon junction dots relative to the ribbon itself.
const JOINT_LIFT := 0.0015


# --- Primitive triangle ------------------------------------------------------

## Adds one triangle, ordering the vertices so the geometric front face points
## along [param outward]. The vertex normals are set to [param outward].
static func add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var cross := (b - a).cross(c - a)
	var want := outward * FRONT_NORMAL_SIGN
	if cross.dot(want) < 0.0:
		var tmp := b
		b = c
		c = tmp
	var normal := outward
	if normal.length_squared() < 1e-12:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)


## Adds one triangle with per-vertex normals, ordering vertices so the front
## face points along the average surface normal.
static func add_triangle_normals(st: SurfaceTool, a: Vector3, na: Vector3,
		b: Vector3, nb: Vector3, c: Vector3, nc: Vector3) -> void:
	var cross := (b - a).cross(c - a)
	var want := na + nb + nc
	if want.length_squared() < 1e-12:
		want = Vector3.UP
	if cross.dot(want * FRONT_NORMAL_SIGN) < 0.0:
		var tb := b
		var tn := nb
		b = c
		nb = nc
		c = tb
		nc = tn
	st.set_normal(na.normalized() if na.length_squared() > 1e-12 else Vector3.UP)
	st.add_vertex(a)
	st.set_normal(nb.normalized() if nb.length_squared() > 1e-12 else Vector3.UP)
	st.add_vertex(b)
	st.set_normal(nc.normalized() if nc.length_squared() > 1e-12 else Vector3.UP)
	st.add_vertex(c)


static func _ensure_outward_2d(pts: PackedVector2Array) -> PackedVector2Array:
	return MathUtils.ensure_ccw(pts)


## Uniform-scale approximation of an inward offset of [param amount] for a
## star-shaped polygon (documented approximation used for chamfers).
static func _inset_factor(pts: PackedVector2Array, amount: float) -> float:
	if amount <= 1e-6:
		return 1.0
	var centre := MathUtils.polygon_centroid(pts)
	var r_max := 0.0
	for p in pts:
		r_max = maxf(r_max, p.distance_to(centre))
	if r_max < 1e-5:
		return 1.0
	return clampf(1.0 - amount / r_max, 0.35, 1.0)


# --- Polygon slabs -----------------------------------------------------------

## Builds one mesh from a list of polygons extruded along +Z, optionally with
## a chamfer on the top and bottom edges.
static func build_extruded_polygons(polygons: Array, depth: float, bevel: float = 0.0) -> ArrayMesh:
	return build_slab_mesh(polygons, 0.0, depth, bevel)


## Core slab builder: every polygon is extruded from [param z_offset] to
## [param z_offset] + [param depth]. A depth of ~0 produces a flat, double
## sided decal.
static func build_slab_mesh(polygons: Array, z_offset: float, depth: float, bevel: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flat := depth <= 1e-5
	for poly: PackedVector2Array in polygons:
		if poly.size() < 3:
			continue
		_add_slab(st, _ensure_outward_2d(poly), z_offset, maxf(depth, 0.0), bevel if not flat else 0.0)
	return st.commit()


static func _add_slab(st: SurfaceTool, pts: PackedVector2Array, z0: float, depth: float, bevel: float) -> void:
	var flat := depth <= 1e-5
	if flat:
		_add_cap(st, pts, z0, Vector3(0, 0, 1))
		_add_cap(st, pts, z0, Vector3(0, 0, -1))
		return

	var b := minf(bevel, depth * 0.45)
	var inset := _inset_factor(pts, b)
	var levels: Array = []
	if b < 1e-5:
		levels = [[1.0, z0], [1.0, z0 + depth]]
	else:
		levels = [[inset, z0], [1.0, z0 + b], [1.0, z0 + depth - b], [inset, z0 + depth]]

	var centre := MathUtils.polygon_centroid(pts)
	# bottom cap (faces -Z), inset when chamfered
	var bottom_pts := _set_loop(pts, centre, levels[0][0], levels[0][1])
	_add_cap(st, bottom_pts, levels[0][1], Vector3(0, 0, -1))
	# top cap (faces +Z)
	var top_pts := _set_loop(pts, centre, levels[levels.size() - 1][0], levels[levels.size() - 1][1])
	_add_cap(st, top_pts, levels[levels.size() - 1][1], Vector3(0, 0, 1))

	# side walls between consecutive levels
	for k in levels.size() - 1:
		var factor_a: float = levels[k][0]
		var za: float = levels[k][1]
		var factor_b: float = levels[k + 1][0]
		var zb: float = levels[k + 1][1]
		if absf(zb - za) < 1e-6 and absf(factor_b - factor_a) < 1e-6:
			continue
		var n := pts.size()
		for i in n:
			var j := (i + 1) % n
			var a0 := _loop_point(pts[i], centre, factor_a, za)
			var a1 := _loop_point(pts[j], centre, factor_a, za)
			var b1 := _loop_point(pts[j], centre, factor_b, zb)
			var b0 := _loop_point(pts[i], centre, factor_b, zb)
			_add_quad(st, a0, a1, b1, b0, centre)


static func _loop_point(p: Vector2, centre: Vector2, factor: float, z: float) -> Vector3:
	var q := centre + (p - centre) * factor
	return Vector3(q.x, q.y, z)


static func _set_loop(pts: PackedVector2Array, centre: Vector2, factor: float, z: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		var q := centre + (pts[i] - centre) * factor
		out[i] = Vector2(q.x, q.y)
	return out


## Fan cap of a (star-shaped) polygon, facing [param outward] (0,0,±1).
static func _add_cap(st: SurfaceTool, pts: PackedVector2Array, z: float, outward: Vector3) -> void:
	var centre := MathUtils.polygon_centroid(pts)
	var c := Vector3(centre.x, centre.y, z)
	var n := pts.size()
	for i in n:
		var j := (i + 1) % n
		var a := Vector3(pts[i].x, pts[i].y, z)
		var b := Vector3(pts[j].x, pts[j].y, z)
		add_triangle(st, c, a, b, outward)


## Quad a0->a1->b1->b0 (2D, each with its own z) with a corrected normal.
static func _add_quad(st: SurfaceTool, a0: Vector3, a1: Vector3, b1: Vector3, b0: Vector3, in_plane_centre: Vector2) -> void:
	var a0v := Vector2(a0.x, a0.y)
	var a1v := Vector2(a1.x, a1.y)
	var edge := (a1v - a0v)
	if edge.length_squared() < 1e-12:
		return
	var edge_dir := edge.normalized()
	var outward_2d := Vector2(edge_dir.y, -edge_dir.x)  # right of travel = outward for CCW
	var mid := (a0v + a1v + Vector2(b1.x, b1.y) + Vector2(b0.x, b0.y)) * 0.25
	if (mid - in_plane_centre).dot(outward_2d) < 0.0:
		outward_2d = -outward_2d
	var outward := Vector3(outward_2d.x, outward_2d.y, 0.0)
	# For chamfered walls the true normal also has a Z component; use the
	# quad's geometric normal corrected against the horizontal outward test.
	var geo_normal := (a1 - a0).cross(b0 - a0)
	if geo_normal.dot(outward) < 0.0:
		geo_normal = -geo_normal
	if geo_normal.length_squared() > 1e-12:
		outward = geo_normal.normalized()
	add_triangle(st, a0, a1, b1, outward)
	add_triangle(st, a0, b1, b0, outward)


# --- Pattern layers ----------------------------------------------------------

## Builds the mesh layers of a generated pattern.
## Returns [fill_mesh_or_null, accent_mesh_or_null, line_mesh_or_null].
## Layer stacking uses LAYER_GAP so no two surfaces are ever coplanar.
static func build_pattern_layers(geo: PatternGeometry, config: PatternConfig,
		flat: bool = false, bevel_override: float = -1.0) -> Array:
	var d := 0.0 if flat else config.extrusion_depth
	var bevel := config.bevel if bevel_override < 0.0 else bevel_override
	var fill_mesh: ArrayMesh = null
	var accent_mesh: ArrayMesh = null
	var line_mesh: ArrayMesh = null

	if config.show_fills and not geo.fills.is_empty():
		fill_mesh = build_slab_mesh(geo.fills, 0.0, d, bevel)

	var accent_z := d + LAYER_GAP
	var accent_depth := (0.0 if flat else maxf(0.25 * d, 0.0))
	var accent_top := accent_z + accent_depth
	if config.show_fills and not geo.accents.is_empty():
		accent_mesh = build_slab_mesh(geo.accents, accent_z, accent_depth, bevel)

	if config.show_lines and not geo.segments.is_empty():
		var line_z := (accent_top if (config.show_fills and not geo.accents.is_empty()) else d) + LAYER_GAP
		var line_depth := (0.0 if flat else maxf(0.2 * d, 0.02))
		line_mesh = build_ribbon_mesh(geo.segments, geo.segment_widths, config.line_thickness,
			line_z, line_depth, true)

	return [fill_mesh, accent_mesh, line_mesh]


## Builds extruded ribbons for a list of segments. [param widths] may contain
## per-segment overrides (0.0 = use default_width). Junction dots are placed
## where two or more segment endpoints meet, so corners never show gaps.
static func build_ribbon_mesh(segments: Array, widths: PackedFloat32Array,
		default_width: float, z_offset: float, depth: float, joints: bool = true) -> ArrayMesh:
	var polys: Array = []
	var junctions: Dictionary = {}
	var n := segments.size()
	for i in n:
		var seg: PackedVector2Array = segments[i]
		if seg.size() != 2:
			continue
		var w := default_width
		if i < widths.size() and widths[i] > 0.0:
			w = widths[i]
		var quad := MathUtils.segment_quad(seg[0], seg[1], w)
		if quad.size() == 4:
			polys.append(quad)
		if joints:
			for p in seg:
				var key := "%d,%d" % [roundi(p.x * 1000.0), roundi(p.y * 1000.0)]
				if junctions.has(key):
					var entry: Dictionary = junctions[key]
					entry["count"] = int(entry["count"]) + 1
					entry["width"] = maxf(float(entry["width"]), w)
				else:
					junctions[key] = {"point": p, "count": 1, "width": w}

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly: PackedVector2Array in polys:
		_add_slab(st, _ensure_outward_2d(poly), z_offset, maxf(depth, 0.0), 0.0)
	if joints:
		for key: String in junctions:
			var entry: Dictionary = junctions[key]
			if int(entry["count"]) < 2:
				continue
			var w: float = float(entry["width"])
			var dot := MathUtils.regular_dot(entry["point"], w * 0.62, 8)
			_add_slab(st, _ensure_outward_2d(dot), z_offset + JOINT_LIFT, maxf(depth, 0.0), 0.0)
	return st.commit()


# --- Boxes -------------------------------------------------------------------

## Axis aligned box centred on the origin.
static func build_box(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var corners := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var faces := [
		[0, 3, 2, 1, Vector3(0, 0, -1)],
		[4, 5, 6, 7, Vector3(0, 0, 1)],
		[0, 4, 7, 3, Vector3(-1, 0, 0)],
		[1, 2, 6, 5, Vector3(1, 0, 0)],
		[3, 7, 6, 2, Vector3(0, 1, 0)],
		[0, 1, 5, 4, Vector3(0, -1, 0)],
	]
	for face: Array in faces:
		var a: Vector3 = corners[face[0]]
		var b: Vector3 = corners[face[1]]
		var c: Vector3 = corners[face[2]]
		var d: Vector3 = corners[face[3]]
		var outward: Vector3 = face[4]
		add_triangle(st, a, b, c, outward)
		add_triangle(st, a, c, d, outward)
	return st.commit()


# --- Revolution surfaces -----------------------------------------------------

## Revolves a profile around the Y axis.
## [param profile] points are (radius, y) ordered bottom to top. Set
## [param smooth] for curved surfaces (domes, columns) or false for faceted
## ones (polygonal minaret bases). Radius 0 at an end adds a pole.
static func revolve(profile: PackedVector2Array, segments: int, smooth: bool = true,
		cap_bottom: bool = true, cap_top: bool = true) -> ArrayMesh:
	segments = maxi(3, segments)
	var rows := profile.size()
	if rows < 2:
		return ArrayMesh.new()

	if smooth:
		# Smooth pass: analytic per-vertex normals from the profile tangent.
		# (profile normal at a point: rotate the tangent (dr, dy) by -90°.)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rows_count := profile.size()
		for r in rows_count - 1:
			var r0: float = profile[r].x
			var r1: float = profile[r + 1].x
			for c in segments:
				var a0 := TAU * float(c) / float(segments)
				var a1 := TAU * float(c + 1) / float(segments)
				var p00 := Vector3(r0 * cos(a0), profile[r].y, r0 * sin(a0))
				var p01 := Vector3(r0 * cos(a1), profile[r].y, r0 * sin(a1))
				var p11 := Vector3(r1 * cos(a1), profile[r + 1].y, r1 * sin(a1))
				var p10 := Vector3(r1 * cos(a0), profile[r + 1].y, r1 * sin(a0))
				var n0 := _profile_normal(profile, r)
				var n1 := _profile_normal(profile, r + 1)
				var na00 := Vector3(n0.x * cos(a0), n0.y, n0.x * sin(a0))
				var na01 := Vector3(n0.x * cos(a1), n0.y, n0.x * sin(a1))
				var na11 := Vector3(n1.x * cos(a1), n1.y, n1.x * sin(a1))
				var na10 := Vector3(n1.x * cos(a0), n1.y, n1.x * sin(a0))
				if r0 <= 1e-5 and r1 <= 1e-5:
					continue
				if r0 <= 1e-5:
					add_triangle_normals(st, p00, na00, p10, na10, p11, na11)
					continue
				if r1 <= 1e-5:
					add_triangle_normals(st, p00, na00, p11, na11, p01, na01)
					continue
				add_triangle_normals(st, p00, na00, p01, na01, p11, na11)
				add_triangle_normals(st, p00, na00, p11, na11, p10, na10)
		_add_revolution_caps(st, profile, segments, cap_bottom, cap_top)
		return st.commit()

	# Faceted version: independent quads with flat normals.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows - 1:
		var r0 := profile[r].x
		var r1 := profile[r + 1].x
		var y0 := profile[r].y
		var y1 := profile[r + 1].y
		for c in segments:
			var a0 := TAU * float(c) / float(segments)
			var a1 := TAU * float(c + 1) / float(segments)
			var p00 := Vector3(r0 * cos(a0), y0, r0 * sin(a0))
			var p01 := Vector3(r0 * cos(a1), y0, r0 * sin(a1))
			var p11 := Vector3(r1 * cos(a1), y1, r1 * sin(a1))
			var p10 := Vector3(r1 * cos(a0), y1, r1 * sin(a0))
			var mid := (p00 + p01 + p11 + p10) * 0.25
			var radial := Vector3(mid.x, 0.0, mid.z)
			if radial.length_squared() < 1e-10:
				radial = Vector3.UP
			var outward := radial.normalized()
			var geo_normal := (p01 - p00).cross(p10 - p00)
			if geo_normal.dot(outward) < 0.0:
				geo_normal = -geo_normal
			if geo_normal.length_squared() > 1e-12:
				outward = geo_normal.normalized()
			if r0 <= 1e-5:
				add_triangle(st, p00, p10, p11, outward)
			elif r1 <= 1e-5:
				add_triangle(st, p00, p11, p01, outward)
			else:
				add_triangle(st, p00, p01, p11, outward)
				add_triangle(st, p00, p11, p10, outward)
	_add_revolution_caps(st, profile, segments, cap_bottom, cap_top)
	return st.commit()


## Outward in-plane normal of a revolve profile at row [param r]
## (profile points are (radius, y), ordered bottom to top).
static func _profile_normal(profile: PackedVector2Array, r: int) -> Vector2:
	var prev := profile[maxi(0, r - 1)]
	var next := profile[mini(profile.size() - 1, r + 1)]
	var tangent := next - prev
	var normal := Vector2(tangent.y, -tangent.x)
	if normal.length_squared() < 1e-12:
		return Vector2(1.0, 0.0)
	return normal.normalized()


static func _add_revolution_caps(st: SurfaceTool, profile: PackedVector2Array, segments: int,
		cap_bottom: bool, cap_top: bool) -> void:
	var bottom: Vector2 = profile[0]
	var top: Vector2 = profile[profile.size() - 1]
	if cap_bottom and bottom.x > 1e-5:
		var centre := Vector3(0, bottom.y, 0)
		for c in segments:
			var a0 := TAU * float(c) / float(segments)
			var a1 := TAU * float(c + 1) / float(segments)
			var p0 := Vector3(bottom.x * cos(a0), bottom.y, bottom.x * sin(a0))
			var p1 := Vector3(bottom.x * cos(a1), bottom.y, bottom.x * sin(a1))
			add_triangle(st, centre, p1, p0, Vector3(0, -1, 0))
	if cap_top and top.x > 1e-5:
		var centre := Vector3(0, top.y, 0)
		for c in segments:
			var a0 := TAU * float(c) / float(segments)
			var a1 := TAU * float(c + 1) / float(segments)
			var p0 := Vector3(top.x * cos(a0), top.y, top.x * sin(a0))
			var p1 := Vector3(top.x * cos(a1), top.y, top.x * sin(a1))
			add_triangle(st, centre, p0, p1, Vector3(0, 1, 0))


# --- Repeated elements -------------------------------------------------------

## Creates a MultiMeshInstance3D drawing one mesh at many transforms.
## Used for balustrade posts, parapet crenellations and similar repeated
## architectural details (one draw call for hundreds of copies).
static func multimesh_instance(mesh: Mesh, material: Material,
		transforms: Array, node_name: String = "MultiMesh") -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	node.multimesh = mm
	if material != null:
		node.material_override = material
	return node


# --- Statistics --------------------------------------------------------------

static func mesh_stats(mesh: Mesh) -> Dictionary:
	var vertices := 0
	var triangles := 0
	var surfaces := 0
	if mesh == null:
		return {"surfaces": 0, "vertices": 0, "triangles": 0}
	if mesh is ArrayMesh:
		var array_mesh := mesh as ArrayMesh
		surfaces = array_mesh.get_surface_count()
		for s in surfaces:
			var arrays := array_mesh.surface_get_arrays(s)
			var verts_variant: Variant = arrays[Mesh.ARRAY_VERTEX]
			if verts_variant == null:
				continue
			var verts: PackedVector3Array = verts_variant
			vertices += verts.size()
			var index_variant: Variant = arrays[Mesh.ARRAY_INDEX]
			if index_variant != null:
				var indices: PackedInt32Array = index_variant
				triangles += indices.size() / 3
			else:
				triangles += verts.size() / 3
	else:
		surfaces = 1
	return {"surfaces": surfaces, "vertices": vertices, "triangles": triangles}
