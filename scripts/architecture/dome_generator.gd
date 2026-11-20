class_name DomeGenerator
extends RefCounted
## Domes, drums and finials, all as surfaces of revolution.
##
## Profiles are parametric: a meridian curve (radius, height) is sampled and
## revolved around Y. Three classic shapes are supported:
##   * HEMISPHERE — quarter ellipse (r = R·cos t, y = H·sin t)
##   * ONION      — bulged profile that tapers to a point
##   * POINTED    — taller, more slender profile with a sharp tip

enum Style { HEMISPHERE, ONION, POINTED }


static func dome_profile(radius: float, height: float, style: int, samples: int = 22) -> PackedVector2Array:
	var profile := PackedVector2Array()
	for i in samples + 1:
		var u := float(i) / float(samples)
		var angle := u * PI * 0.5
		var r := radius
		var y := height
		match style:
			Style.ONION:
				r = radius * pow(cos(angle), 0.8)
				y = height * pow(sin(angle), 1.15)
			Style.POINTED:
				r = radius * pow(cos(angle), 1.25)
				y = height * pow(sin(angle), 0.85)
			_:
				r = radius * cos(angle)
				y = height * sin(angle)
		profile.append(Vector2(maxf(r, 0.0), y))
	# ensure a clean pole and base
	profile[0] = Vector2(radius, 0.0)
	profile[profile.size() - 1] = Vector2(0.0, height)
	return profile


## Dome shell. Origin at the springing ring (y = 0).
static func dome_mesh(radius: float, height: float, style: int, segments: int = 48) -> ArrayMesh:
	return MeshBuilder.revolve(dome_profile(radius, height, style), segments, true, false, false)


## Interior shell of a dome: the same surface mirrored, so its front faces
## point inwards (used so the hall interior is closed).
static func dome_interior_node(radius: float, height: float, style: int,
		segments: int = 48, material_id: String = "ivory_stone") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = dome_mesh(radius, height, style, segments)
	var material := MaterialLibrary.get_material(material_id).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = material
	mi.scale = Vector3(0.985, 0.985, -0.985)
	return mi


## Meridian ribs: thin raised bands along the dome surface (k longitudes).
static func ribs_mesh(radius: float, height: float, style: int, count: int,
		band_width: float, relief: float, samples: int = 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := dome_profile(radius, height, style, samples)
	var rows := profile.size()
	for k in count:
		var a0 := TAU * float(k) / float(count)
		var a1 := a0 + band_width / maxf(radius, 0.1)
		for i in rows - 1:
			var p0 := profile[i]
			var p1 := profile[i + 1]
			if p0.x < 0.02 or p1.x < 0.02:
				continue
			for band_angle: Array in [[a0, a1]]:
				var b0: float = band_angle[0]
				var b1: float = band_angle[1]
				var c00 := Vector3(p0.x * cos(b0), p0.y, p0.x * sin(b0))
				var c01 := Vector3(p0.x * cos(b1), p0.y, p0.x * sin(b1))
				var c11 := Vector3(p1.x * cos(b1), p1.y, p1.x * sin(b1))
				var c10 := Vector3(p1.x * cos(b0), p1.y, p1.x * sin(b0))
				var mid := (c00 + c01 + c11 + c10) * 0.25
				var radial := Vector3(mid.x, 0.0, mid.z)
				if radial.length_squared() < 1e-9:
					radial = Vector3.UP
				var outward := radial.normalized()
				# push outward slightly for relief
				c00 += outward * relief
				c01 += outward * relief
				c11 += outward * relief
				c10 += outward * relief
				MeshBuilder.add_triangle(st, c00, c01, c11, outward)
				MeshBuilder.add_triangle(st, c00, c11, c10, outward)
	return st.commit()


## Drum: a faceted prism (sides) with an optional top ring. Origin at the
## drum base.
static func drum_mesh(radius: float, height: float, sides: int = 16) -> ArrayMesh:
	var profile := PackedVector2Array([
		Vector2(radius, 0.0),
		Vector2(radius, height),
	])
	return MeshBuilder.revolve(profile, sides, false, true, true)


## Finial: stacked rings, a ball and a spike. Origin at the base.
static func finial_mesh(height: float, radius: float) -> ArrayMesh:
	var h := height
	var r := radius
	var profile := PackedVector2Array([
		Vector2(r * 0.9, 0.0),
		Vector2(r * 0.9, h * 0.08),
		Vector2(r * 0.45, h * 0.12),
		Vector2(r * 0.45, h * 0.22),
		Vector2(r * 0.85, h * 0.28),   # ball
		Vector2(r * 0.95, h * 0.36),
		Vector2(r * 0.7, h * 0.45),
		Vector2(r * 0.32, h * 0.55),
		Vector2(r * 0.26, h * 0.75),
		Vector2(r * 0.12, h * 0.9),
		Vector2(r * 0.0, h),
	])
	return MeshBuilder.revolve(profile, 20, true, true, false)
