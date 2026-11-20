class_name MeshExporter
extends RefCounted
## Exports generated meshes to the Wavefront OBJ format (text, universally
## loadable by 3D tools and slicers).

## Writes every MeshInstance3D found under [param nodes] as a single OBJ file.
## Vertices are baked into the coordinate space of the first node's parent.
## Returns the absolute path or "" on failure.
static func export_obj(nodes: Array, path: String) -> String:
	var lines := PackedStringArray()
	lines.append("# NOOR — Procedural Islamic Geometry & Heritage Architecture")
	lines.append("# Extruded pattern export")
	lines.append("# %s" % Time.get_datetime_string_from_system())
	var vertex_offset := 1
	for node: Node in nodes:
		if not (node is MeshInstance3D):
			continue
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xform := mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts_variant: Variant = arrays[Mesh.ARRAY_VERTEX]
			if verts_variant == null:
				continue
			var verts: PackedVector3Array = verts_variant
			for v in verts:
				var p := xform * v
				lines.append("v %.6f %.6f %.6f" % [p.x, p.y, p.z])
			var index_variant: Variant = arrays[Mesh.ARRAY_INDEX]
			if index_variant != null:
				var indices: PackedInt32Array = index_variant
				var i := 0
				while i + 2 < indices.size():
					lines.append("f %d %d %d" % [
						indices[i] + vertex_offset,
						indices[i + 1] + vertex_offset,
						indices[i + 2] + vertex_offset])
					i += 3
				vertex_offset += verts.size()
			else:
				var i := 0
				while i + 2 < verts.size():
					lines.append("f %d %d %d" % [
						i + vertex_offset, i + 1 + vertex_offset, i + 2 + vertex_offset])
					i += 3
				vertex_offset += verts.size()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string("\n".join(lines))
	file.close()
	return path


## Default destination for exports (user://exports).
static func default_export_path(prefix: String, extension: String) -> String:
	var dir := "user://exports"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	return "%s/noor_%s_%s.%s" % [dir, prefix, stamp, extension]
