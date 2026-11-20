class_name ArchitectureGenerator
extends RefCounted
## Assembles the whole heritage-inspired environment from the procedural
## component generators. One call builds the complete node tree.
##
## Layout (an interpretation inspired by historical courtyard architecture):
##   * courtyard 44 x 44 with a marble floor, inlay bands and a central
##     fountain over a great floor medallion
##   * arcades with seven pointed-arch bays along the east and west sides
##   * domed prayer hall on the north side (four-iwan plan)
##   * grand entrance portal with towers on the south side, opening to a
##     walled forecourt
##   * four minarets at the hall and portal corners
##
## Returns a context dictionary:
##   {"root": Node3D, "collision": Array, "lights": Array[Vector3],
##    "proxies": Array, "panels": Array, "courtyard_half": float,
##    "spawn": Vector3, "focus_points": Dictionary}

const COURT := 22.0            # half extent of the inner courtyard
const PLATFORM_H := 0.55
const BAY := 5.5
const BAY_COUNT := 7
const COURT_EDGE := -22.0      # x of the west courtyard edge
const ARCADE_TOP := 8.4


static func generate() -> Dictionary:
	var ctx := {
		"root": Node3D.new(),
		"collision": [],
		"lights": [],
		"proxies": [],
		"panels": [],
		"courtyard_half": COURT,
		"spawn": Vector3(0, 0.1, 18.0),
		"focus_points": {},
	}
	ctx["root"].name = "Architecture"
	_build_ground(ctx)
	_build_courtyard_floor(ctx)
	_build_fountain(ctx)
	_build_arcade(ctx, -1)   # west
	_build_arcade(ctx, 1)    # east
	_build_hall(ctx)
	_build_north_walls(ctx)
	_build_portal(ctx)
	_build_forecourt(ctx)
	_build_minarets(ctx)
	return ctx


# --- Small helpers -----------------------------------------------------------

static func _mesh_node(mesh: Mesh, material_id: String, position := Vector3.ZERO,
		rotation_deg := Vector3.ZERO, name := "") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if not name.is_empty():
		node.name = name
	node.mesh = mesh
	node.material_override = MaterialLibrary.get_material(material_id)
	node.position = position
	node.rotation_degrees = rotation_deg
	return node


static func _box_node(size: Vector3, material_id: String, position: Vector3,
		rotation_deg := Vector3.ZERO, name := "") -> MeshInstance3D:
	return _mesh_node(MeshBuilder.build_box(size), material_id, position, rotation_deg, name)


static func _add_box_collision(ctx: Dictionary, position: Vector3, size: Vector3,
		rotation_deg := Vector3.ZERO) -> void:
	ctx["collision"].append({
		"shape": "box", "position": position, "size": size, "rotation_deg": rotation_deg,
	})


static func _add_cylinder_collision(ctx: Dictionary, position: Vector3,
		radius: float, height: float) -> void:
	ctx["collision"].append({
		"shape": "cylinder", "position": position, "radius": radius, "height": height,
	})


static func _add_proxy(ctx: Dictionary, info_id: String, position: Vector3,
		size: Vector3, highlight: Node3D, rotation_deg := Vector3.ZERO) -> void:
	ctx["proxies"].append({
		"info_id": info_id, "position": position, "size": size,
		"highlight": highlight, "rotation_deg": rotation_deg,
	})


static func _add_cylinder_proxy(ctx: Dictionary, info_id: String, position: Vector3,
		radius: float, height: float, highlight: Node3D) -> void:
	ctx["proxies"].append({
		"info_id": info_id, "shape": "cylinder", "position": position,
		"radius": radius, "height": height, "highlight": highlight,
	})


# --- Ground and courtyard floor ---------------------------------------------

static func _build_ground(ctx: Dictionary) -> void:
	ctx["root"].add_child(_box_node(Vector3(120, 0.6, 120), "sandstone_dark",
		Vector3(0, -0.3, 0), Vector3.ZERO, "Ground"))
	_add_box_collision(ctx, Vector3(0, -0.3, 0), Vector3(120, 0.6, 120))


static func _build_courtyard_floor(ctx: Dictionary) -> void:
	ctx["root"].add_child(_box_node(Vector3(COURT * 2.0 + 0.4, 0.04, COURT * 2.0 + 0.4),
		"marble", Vector3(0, 0.02, 0), Vector3.ZERO, "CourtyardFloor"))
	for node: Node3D in DecorationGenerator.floor_band_nodes(COURT):
		ctx["root"].add_child(node)

	var medallion_config: PatternConfig = PatternLibrary.get_panel_config("floor_medallion")
	var medallion := PatternPanel.new()
	medallion.name = "FloorMedallion"
	medallion.setup("floor_medallion", Vector2(17, 17), medallion_config)
	medallion.rotation_degrees.x = -90
	medallion.position = Vector3(0, 0.045, 0)
	ctx["root"].add_child(medallion)
	ctx["panels"].append(medallion)
	ctx["focus_points"]["medallion"] = {"point": Vector3(0, 0.1, 0), "radius": 9.0}

	# interactive floor quadrants
	var q := COURT - 1.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_add_proxy(ctx, "ground", Vector3(sx * q * 0.5, 0.1, sz * q * 0.5),
				Vector3(q, 0.4, q), medallion)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_add_proxy(ctx, "floor_medallion", Vector3(sx * 5.5, 0.3, sz * 5.5),
				Vector3(7.0, 0.7, 7.0), medallion)


# --- Fountain ----------------------------------------------------------------

static func _build_fountain(ctx: Dictionary) -> void:
	var fountain := DecorationGenerator.fountain_node()
	fountain.position = Vector3(0, 0.06, 0)
	ctx["root"].add_child(fountain)
	_add_cylinder_collision(ctx, Vector3(0, 0.35, 0), 3.5, 0.7)
	var pad := MeshBuilder.revolve(PackedVector2Array([
		Vector2(4.3, 0.0), Vector2(4.3, 0.16)]), 8, false, true, true)
	ctx["root"].add_child(_mesh_node(pad, "marble", Vector3(0, 0.04, 0), Vector3.ZERO, "FountainPad"))
	_add_cylinder_collision(ctx, Vector3(0, 0.12, 0), 4.35, 0.24)

	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var pos := MathUtils.polar_to_cart(3.1, angle)
		_add_proxy(ctx, "fountain", Vector3(pos.x, 0.5, pos.y), Vector3(2.0, 1.0, 2.0), fountain)
	_add_cylinder_proxy(ctx, "water", Vector3(0, 0.45, 0), 2.9, 0.5, fountain)
	ctx["lights"].append(Vector3(0, 2.3, 0))
	var lantern := DecorationGenerator.lantern_node(0.0)
	lantern.position = Vector3(0, 2.4, 0)
	ctx["root"].add_child(lantern)
	ctx["focus_points"]["fountain"] = {"point": Vector3(0, 1.6, 0), "radius": 5.5}


# --- Arcades -----------------------------------------------------------------
## side = -1 for west, +1 for east. "Outward" (away from the courtyard centre)
## is always the direction of `side` along X.

static func _build_arcade(ctx: Dictionary, side: int) -> void:
	var group := Node3D.new()
	group.name = "WestArcade" if side < 0 else "EastArcade"
	var x_front := COURT_EDGE * float(side)      # -22 west, +22 east
	var run := COURT * 2.0 - 2.0                 # 42: from z -21 to 21

	# platform + steps (steps on the courtyard side of the platform)
	var platform_x := x_front + 2.42 * float(side)
	var platform := _box_node(Vector3(4.15, PLATFORM_H, run), "marble",
		Vector3(platform_x, PLATFORM_H * 0.5, 0), Vector3.ZERO, "Platform")
	group.add_child(platform)
	_add_box_collision(ctx, platform.position, Vector3(4.15, PLATFORM_H, run))
	for step: Array in [[0.35, 0.183, -0.175], [0.35, 0.367, 0.175]]:
		var step_w: float = step[0]
		var step_h: float = step[1]
		var step_x: float = step[2]
		group.add_child(_box_node(Vector3(step_w, step_h, run), "sandstone",
			Vector3(x_front + step_x * float(side), step_h * 0.5, 0),
			Vector3.ZERO, "Step"))
	# walkable ramp collision over the steps
	var ramp_angle := rad_to_deg(atan2(PLATFORM_H, 1.35))
	_add_box_collision(ctx, Vector3(x_front + 0.2 * float(side), PLATFORM_H * 0.5 + 0.02, 0),
		Vector3(1.7, 0.1, run), Vector3(0, 0, ramp_angle * float(side)))

	# solid back wall (carries the patterned panel)
	var back_wall := _box_node(Vector3(1.0, ARCADE_TOP + 0.6, run), "sandstone",
		Vector3(x_front + 5.0 * float(side), (ARCADE_TOP + 0.6) * 0.5, 0),
		Vector3.ZERO, "BackWall")
	group.add_child(back_wall)
	_add_box_collision(ctx, back_wall.position, Vector3(1.0, ARCADE_TOP + 0.6, run))

	# arched elevation: 7 bays, thickness extends outward
	var arches: Array = []
	for i in BAY_COUNT:
		arches.append({
			"x": -16.5 + float(i) * BAY, "half": 2.3,
			"spring": 4.8, "pointiness": 0.55, "kind": ArchGenerator.Kind.POINTED,
		})
	var wall_height := ARCADE_TOP - PLATFORM_H
	var elevation := ArchGenerator.wall_with_arches(run, wall_height, arches, 0.9)
	group.add_child(_mesh_node(elevation, "sandstone",
		Vector3(x_front + 0.9 * float(side), PLATFORM_H, 0),
		Vector3(0, 90.0 * float(side), 0), "ArcadeElevation"))
	# collision: end piers + shared piers + lintel band above the openings
	for i in BAY_COUNT + 1:
		var z := -19.25 + float(i) * BAY
		var is_end := i == 0 or i == BAY_COUNT
		var pier_width := 2.6 if is_end else 0.9
		_add_box_collision(ctx, Vector3(x_front + 0.45 * float(side), PLATFORM_H + wall_height * 0.5, z),
			Vector3(0.9, wall_height, pier_width))
	_add_box_collision(ctx, Vector3(x_front + 0.45 * float(side), PLATFORM_H + 5.9, 0),
		Vector3(0.9, 2.3, run))

	# columns on the platform
	var column_mesh := ColumnGenerator.column_mesh(4.8, 0.42, 20)
	for i in 8:
		var z := -19.25 + float(i) * BAY
		var column := _mesh_node(column_mesh, "sandstone",
			Vector3(x_front + 1.3 * float(side), PLATFORM_H, z), Vector3.ZERO, "Column")
		group.add_child(column)
		_add_cylinder_collision(ctx, Vector3(x_front + 1.3 * float(side), PLATFORM_H + 2.6, z), 0.55, 5.2)
		_add_cylinder_proxy(ctx, "column", Vector3(x_front + 1.3 * float(side), PLATFORM_H + 2.6, z),
			0.8, 5.2, column)

	# roof, gold trim, crenellations
	var roof_x := x_front + 2.9 * float(side)
	group.add_child(_box_node(Vector3(6.6, 0.35, run), "sandstone_dark",
		Vector3(roof_x, ARCADE_TOP + 0.175, 0), Vector3.ZERO, "Roof"))
	group.add_child(_box_node(Vector3(0.22, 0.14, run), "gold",
		Vector3(x_front - 0.42 * float(side), ARCADE_TOP + 0.35, 0), Vector3.ZERO, "RoofTrim"))
	var cren_mesh := MeshBuilder.build_box(Vector3(0.3, 0.42, 0.3))
	var cren_mat := MaterialLibrary.get_material("sandstone")
	group.add_child(MeshBuilder.multimesh_instance(cren_mesh, cren_mat,
		DecorationGenerator.crenellation_transforms(
			Vector3(x_front - 0.3 * float(side), 0, -COURT + 0.6),
			Vector3(x_front - 0.3 * float(side), 0, COURT - 0.6), 0.95,
			Vector3(0.3, 0.42, 0.3), ARCADE_TOP + 0.35), "CrenellationsFront"))
	group.add_child(MeshBuilder.multimesh_instance(cren_mesh, cren_mat,
		DecorationGenerator.crenellation_transforms(
			Vector3(x_front + 5.6 * float(side), 0, -COURT + 0.6),
			Vector3(x_front + 5.6 * float(side), 0, COURT - 0.6), 0.95,
			Vector3(0.3, 0.42, 0.3), ARCADE_TOP + 0.35), "CrenellationsBack"))

	# hanging lanterns (every other bay) + night light positions
	for i in [0, 2, 4, 6]:
		var z := -16.5 + float(i) * BAY
		var lantern := DecorationGenerator.lantern_node()
		lantern.position = Vector3(x_front + 2.4 * float(side), ARCADE_TOP, z)
		group.add_child(lantern)
		ctx["lights"].append(Vector3(x_front + 2.4 * float(side), ARCADE_TOP - 0.75, z))

	# patterned wall panel on the back wall's inner face
	var panel_id := "arcade_panel_west" if side < 0 else "arcade_panel_east"
	var panel_config: PatternConfig = PatternLibrary.get_panel_config(panel_id)
	var panel := PatternPanel.new()
	panel.name = "ArcadePanel"
	panel.setup(panel_id, Vector2(6.0, 3.7), panel_config)
	panel.position = Vector3(x_front + 4.47 * float(side), 3.6, 0)
	panel.rotation_degrees.y = -90.0 * float(side)
	group.add_child(panel)
	ctx["panels"].append(panel)

	# clickable regions: the roofline (= the arcade) and the panel
	_add_proxy(ctx, "arcade_west" if side < 0 else "arcade_east",
		Vector3(roof_x, ARCADE_TOP + 0.2, 0), Vector3(6.6, 0.6, run), group)
	_add_proxy(ctx, panel_id, Vector3(x_front + 4.7 * float(side), 3.6, 0),
		Vector3(0.8, 3.9, 6.2), panel)

	ctx["root"].add_child(group)
	ctx["focus_points"]["arcade_west" if side < 0 else "arcade_east"] = {
		"point": Vector3(x_front + 3.2 * float(side), 4.5, 0), "radius": 20.0}


# --- Prayer hall -------------------------------------------------------------

static func _build_hall(ctx: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "PrayerHall"
	var centre_z := -15.0
	var wall_h := 10.0
	var base_y := 0.9

	# terrace + steps
	var terrace := _box_node(Vector3(24, 0.9, 16.6), "marble", Vector3(0, 0.45, -14.7),
		Vector3.ZERO, "Terrace")
	group.add_child(terrace)
	_add_box_collision(ctx, terrace.position, Vector3(24, 0.9, 16.6))
	for i in 3:
		var step_h := 0.9 - 0.3 * float(i)
		group.add_child(_box_node(Vector3(10, step_h, 0.32), "marble",
			Vector3(0, step_h * 0.5, -6.4 + 0.16 + 0.32 * float(i)), Vector3.ZERO, "Step"))
	var ramp_angle := rad_to_deg(atan2(0.9, 1.5))
	_add_box_collision(ctx, Vector3(0, 0.47, -6.0), Vector3(10, 0.1, 1.7), Vector3(ramp_angle, 0, 0))

	# --- south (courtyard) wall with the great iwan arch ---------------------
	var front := ArchGenerator.wall_with_arches(18.0, wall_h, [{
		"x": 0.0, "half": 4.0, "spring": 4.2, "pointiness": 0.45, "kind": ArchGenerator.Kind.POINTED,
	}], 0.9)
	var front_node := _mesh_node(front, "ivory_stone", Vector3(0, base_y, -9.45), Vector3.ZERO, "FrontWall")
	group.add_child(front_node)
	group.add_child(_mesh_node(ArchGenerator.band_mesh(
		ArchGenerator.curve(ArchGenerator.Kind.POINTED, 4.0, 4.2, 0.45, 30), 0.42, 0.18, -0.05),
		"gold", Vector3(0, base_y, -8.62)))
	_add_box_collision(ctx, Vector3(-6.5, base_y + wall_h * 0.5, -9.0), Vector3(5.0, wall_h, 0.9))
	_add_box_collision(ctx, Vector3(6.5, base_y + wall_h * 0.5, -9.0), Vector3(5.0, wall_h, 0.9))
	_add_box_collision(ctx, Vector3(0, base_y + 6.8, -9.0), Vector3(8.0, 3.4, 0.9))

	# --- north (qibla) wall with the mihrab niche ----------------------------
	var back := ArchGenerator.wall_with_arches(18.0, wall_h, [{
		"x": 0.0, "half": 2.2, "spring": 3.6, "pointiness": 0.5, "kind": ArchGenerator.Kind.POINTED,
	}], 0.9)
	var back_node := _mesh_node(back, "ivory_stone", Vector3(0, base_y, -21.0), Vector3.ZERO, "QiblaWall")
	group.add_child(back_node)
	group.add_child(_mesh_node(ArchGenerator.band_mesh(
		ArchGenerator.curve(ArchGenerator.Kind.POINTED, 2.2, 3.6, 0.5, 24), 0.3, 0.14, -0.05),
		"gold", Vector3(0, base_y, -20.18)))
	group.add_child(_box_node(Vector3(4.6, 6.0, 0.16), "dark_wood", Vector3(0, base_y + 3.0, -20.05)))
	_add_box_collision(ctx, Vector3(0, base_y + wall_h * 0.5, -20.55), Vector3(18, wall_h, 0.9))

	# --- east / west walls with side arches ----------------------------------
	for side: float in [-1.0, 1.0]:
		var wall := ArchGenerator.wall_with_arches(12.0, wall_h, [{
			"x": 0.0, "half": 2.5, "spring": 4.2, "pointiness": 0.5, "kind": ArchGenerator.Kind.POINTED,
		}], 0.9)
		group.add_child(_mesh_node(wall, "ivory_stone", Vector3(side * 9.0, base_y, centre_z),
			Vector3(0, 90.0 * side, 0), "SideWall"))
		_add_box_collision(ctx, Vector3(side * 9.45, base_y + wall_h * 0.5, centre_z), Vector3(0.9, wall_h, 3.0))
		_add_box_collision(ctx, Vector3(side * 9.45, base_y + wall_h * 0.5, centre_z - 4.6), Vector3(0.9, wall_h, 1.8))
		_add_box_collision(ctx, Vector3(side * 9.45, base_y + wall_h * 0.5, centre_z + 4.6), Vector3(0.9, wall_h, 1.8))
		_add_box_collision(ctx, Vector3(side * 9.45, base_y + 6.9, centre_z), Vector3(0.9, 3.2, 5.0))

	# cornice (also the interior ceiling)
	group.add_child(_box_node(Vector3(20.4, 0.6, 13.2), "ivory_stone", Vector3(0, 11.2, -14.85),
		Vector3.ZERO, "Cornice"))

	# drum + arcature
	var drum_y := 11.5
	var drum_radius := 7.9
	var drum_h := 3.2
	var drum := _mesh_node(DomeGenerator.drum_mesh(drum_radius, drum_h, 16), "ivory_stone",
		Vector3(0, drum_y, centre_z), Vector3.ZERO, "Drum")
	group.add_child(drum)
	var inner_mat := MaterialLibrary.get_material("ivory_stone").duplicate() as StandardMaterial3D
	inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var drum_inner := _mesh_node(DomeGenerator.drum_mesh(drum_radius, drum_h, 16), "ivory_stone",
		Vector3(0, drum_y, centre_z), Vector3.ZERO, "DrumInterior")
	drum_inner.material_override = inner_mat
	drum_inner.scale = Vector3(0.97, 1.0, 0.97)
	group.add_child(drum_inner)
	var face_width := 2.0 * drum_radius * sin(PI / 16.0)
	var arcature := ArchGenerator.frame_mesh(face_width * 0.34, 1.2, 2.5, 0.28, 0.55,
		ArchGenerator.Kind.POINTED, 0.22, 18)
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var pos := MathUtils.polar_to_cart(drum_radius - 0.02, angle)
		group.add_child(_mesh_node(arcature, "sandstone",
			Vector3(pos.x, drum_y + 0.25, centre_z + pos.y),
			Vector3(0, 90.0 - rad_to_deg(angle), 0), "Arcature"))

	# dome + ribs + finial + interior shell
	var dome_y := drum_y + drum_h
	var dome_radius := 7.6
	var dome_h := 8.2
	var dome := _mesh_node(DomeGenerator.dome_mesh(dome_radius, dome_h, DomeGenerator.Style.ONION, 48),
		"ivory_stone", Vector3(0, dome_y, centre_z), Vector3.ZERO, "Dome")
	group.add_child(dome)
	group.add_child(_mesh_node(DomeGenerator.ribs_mesh(dome_radius, dome_h, DomeGenerator.Style.ONION,
		16, 0.34, 0.10), "sandstone_dark", Vector3(0, dome_y, centre_z), Vector3.ZERO, "DomeRibs"))
	var interior := DomeGenerator.dome_interior_node(dome_radius, dome_h, DomeGenerator.Style.ONION, 48)
	interior.position = Vector3(0, dome_y, centre_z)
	interior.name = "DomeInterior"
	group.add_child(interior)
	group.add_child(_mesh_node(DomeGenerator.finial_mesh(2.6, 0.75), "gold",
		Vector3(0, dome_y + dome_h - 0.05, centre_z), Vector3.ZERO, "Finial"))

	# interior: floor medallion + chandelier
	var hall_config: PatternConfig = PatternLibrary.get_panel_config("hall_panel")
	var hall_panel := PatternPanel.new()
	hall_panel.name = "HallMedallion"
	hall_panel.setup("hall_panel", Vector2(10, 10), hall_config)
	hall_panel.rotation_degrees.x = -90
	hall_panel.position = Vector3(0, 0.95, centre_z)
	group.add_child(hall_panel)
	ctx["panels"].append(hall_panel)

	var chandelier := Node3D.new()
	chandelier.name = "Chandelier"
	chandelier.add_child(_mesh_node(MeshBuilder.revolve(PackedVector2Array([
		Vector2(1.3, 0.0), Vector2(1.5, -0.2), Vector2(1.5, -0.45), Vector2(1.25, -0.6)]),
		16, false, false, false), "bronze", Vector3(0, 6.4, centre_z)))
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var pos := MathUtils.polar_to_cart(1.4, angle)
		chandelier.add_child(_mesh_node(MeshBuilder.revolve(PackedVector2Array([
			Vector2(0.09, 5.1), Vector2(0.13, 4.95)]), 6, false, true, true),
			"lantern_glow", Vector3(pos.x, 0, centre_z + pos.y)))
	group.add_child(chandelier)
	ctx["lights"].append(Vector3(0, 5.6, centre_z))

	# interactive proxies
	_add_proxy(ctx, "hall", Vector3(0, 5.9, centre_z), Vector3(20, 10.2, 13.2), group)
	_add_proxy(ctx, "iwan", Vector3(0, 4.5, -8.6), Vector3(9.0, 8.0, 2.0), front_node)
	_add_proxy(ctx, "drum", Vector3(0, drum_y + drum_h * 0.5, centre_z), Vector3(15.6, 3.4, 15.6), drum)
	_add_proxy(ctx, "dome", Vector3(0, dome_y + dome_h * 0.45, centre_z), Vector3(16.4, 8.6, 16.4), dome)
	_add_proxy(ctx, "plinth", Vector3(0, 0.5, -14.7), Vector3(24, 1.0, 16.6), terrace)
	_add_proxy(ctx, "hall_panel", Vector3(0, 1.3, centre_z), Vector3(10.2, 0.8, 10.2), hall_panel)
	ctx["focus_points"]["dome"] = {"point": Vector3(0, dome_y + 3.0, centre_z), "radius": 16.0}
	ctx["focus_points"]["hall"] = {"point": Vector3(0, 5.0, centre_z), "radius": 20.0}
	ctx["root"].add_child(group)


# --- North courtyard walls (between the hall and the arcades) ---------------

static func _build_north_walls(ctx: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "NorthWalls"
	var wall_h := 6.5
	var cren_mesh := MeshBuilder.build_box(Vector3(0.3, 0.42, 0.3))
	var cren_mat := MaterialLibrary.get_material("sandstone")
	var arch_mesh := ArchGenerator.frame_mesh(1.0, 2.6, 3.8, 0.3, 0.5,
		ArchGenerator.Kind.POINTED, 0.16, 16)
	for side: float in [-1.0, 1.0]:
		var centre_x := side * 17.0
		var wall := _box_node(Vector3(10.0, wall_h, 1.0), "sandstone",
			Vector3(centre_x, wall_h * 0.5, -21.5), Vector3.ZERO, "NorthWall")
		group.add_child(wall)
		_add_box_collision(ctx, Vector3(centre_x, wall_h * 0.5, -21.5), Vector3(10.0, wall_h, 1.0))
		for i in 2:
			group.add_child(_mesh_node(arch_mesh, "sandstone",
				Vector3(centre_x + side * (i * 3.4 - 1.7), 0.35, -21.0)))
		group.add_child(_box_node(Vector3(10.4, 0.4, 1.3), "ivory_stone",
			Vector3(centre_x, wall_h + 0.2, -21.5)))
		group.add_child(MeshBuilder.multimesh_instance(cren_mesh, cren_mat,
			DecorationGenerator.crenellation_transforms(
				Vector3(centre_x - 4.7, 0, -21.5), Vector3(centre_x + 4.7, 0, -21.5), 0.95,
				Vector3(0.3, 0.42, 0.3), wall_h + 0.4), "NorthCrenellations"))
		_add_proxy(ctx, "ground", Vector3(centre_x, wall_h * 0.5, -21.5), Vector3(10.0, wall_h, 1.2), wall)
	ctx["root"].add_child(group)


# --- Portal + forecourt ------------------------------------------------------

static func _door_stud_mesh() -> ArrayMesh:
	var star := MathUtils.star_vertices(8, 0.16, 0.07)
	return MeshBuilder.build_slab_mesh([star], 0.0, 0.05)


static func _build_portal(ctx: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "Portal"
	var portal_h := 15.0

	# portal block pierced by the gate arch (front face at z = 22, faces the courtyard)
	var portal := ArchGenerator.wall_with_arches(16.0, portal_h, [{
		"x": 0.0, "half": 3.25, "spring": 6.5, "pointiness": 0.62, "kind": ArchGenerator.Kind.POINTED,
	}], 2.2)
	var portal_node := _mesh_node(portal, "ivory_stone", Vector3(0, 0, 22.0), Vector3.ZERO, "PortalBlock")
	group.add_child(portal_node)
	group.add_child(_mesh_node(ArchGenerator.band_mesh(
		ArchGenerator.curve(ArchGenerator.Kind.POINTED, 3.25, 6.5, 0.62, 30), 0.4, 0.2, -0.06),
		"gold", Vector3(0, 0, 21.94)))
	_add_box_collision(ctx, Vector3(-4.6, portal_h * 0.5, 23.1), Vector3(6.8, portal_h, 2.2))
	_add_box_collision(ctx, Vector3(4.6, portal_h * 0.5, 23.1), Vector3(6.8, portal_h, 2.2))
	_add_box_collision(ctx, Vector3(0, 11.0, 23.1), Vector3(6.5, 8.0, 2.2))

	# flanking towers with onion caps
	for side: float in [-1.0, 1.0]:
		var tower := _box_node(Vector3(2.6, 16.0, 2.6), "sandstone",
			Vector3(side * 6.7, 8.0, 23.9), Vector3.ZERO, "Tower")
		group.add_child(tower)
		_add_box_collision(ctx, Vector3(side * 6.7, 8.0, 23.9), Vector3(2.6, 16.0, 2.6))
		group.add_child(_mesh_node(DomeGenerator.dome_mesh(1.75, 1.9, DomeGenerator.Style.ONION, 20),
			"sandstone", Vector3(side * 6.7, 16.0, 23.9), Vector3.ZERO, "TowerCap"))
		group.add_child(_mesh_node(DomeGenerator.finial_mesh(1.1, 0.3), "gold",
			Vector3(side * 6.7, 17.85, 23.9), Vector3.ZERO, "TowerFinial"))
		_add_proxy(ctx, "gate", Vector3(side * 6.7, 9.0, 23.9), Vector3(2.8, 18.0, 2.8), tower)
	var cren_mesh := MeshBuilder.build_box(Vector3(0.3, 0.42, 0.3))
	var cren_mat := MaterialLibrary.get_material("sandstone")
	var tower_cren: Array = []
	for side: float in [-1.0, 1.0]:
		for i in 4:
			var angle := TAU * float(i) / 4.0 + PI / 4.0
			var pos := MathUtils.polar_to_cart(1.5, angle)
			tower_cren.append(Transform3D(Basis(), Vector3(side * 6.7 + pos.x, 16.2, 23.9 + pos.y)))
	group.add_child(MeshBuilder.multimesh_instance(cren_mesh, cren_mat, tower_cren, "TowerCrenellations"))

	# open wooden doors with gold studs
	var stud_mesh := _door_stud_mesh()
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 3.1, 2.8, 23.0)
		pivot.rotation_degrees.y = side * 78.0
		var leaf := _box_node(Vector3(3.0, 5.6, 0.14), "dark_wood",
			Vector3(-side * 1.5, 0, 0), Vector3.ZERO, "DoorLeaf")
		pivot.add_child(leaf)
		for r in 3:
			for c in 2:
				leaf.add_child(_mesh_node(stud_mesh, "gold",
					Vector3(-side * (0.7 + 0.8 * float(c)), -1.6 + 1.6 * float(r), 0.1)))
		group.add_child(pivot)

	# pattern panel above the arch (facing the courtyard)
	var gate_config: PatternConfig = PatternLibrary.get_panel_config("gate_panel")
	var gate_panel := PatternPanel.new()
	gate_panel.name = "GatePanel"
	gate_panel.setup("gate_panel", Vector2(6.0, 3.2), gate_config)
	gate_panel.position = Vector3(0, 13.2, 21.95)
	gate_panel.rotation_degrees.y = 180.0
	group.add_child(gate_panel)
	ctx["panels"].append(gate_panel)
	_add_proxy(ctx, "gate_panel", Vector3(0, 13.2, 21.7), Vector3(6.3, 3.5, 0.8), gate_panel)

	# side walls with blind-arch arcature + crenellations
	for side: float in [-1.0, 1.0]:
		var wall := _box_node(Vector3(13.0, 10.0, 1.0), "sandstone",
			Vector3(side * 14.5, 5.0, 22.5), Vector3.ZERO, "SideWall")
		group.add_child(wall)
		_add_box_collision(ctx, Vector3(side * 14.5, 5.0, 22.5), Vector3(13.0, 10.0, 1.0))
		var arc_mesh := ArchGenerator.frame_mesh(1.1, 3.2, 4.6, 0.35, 0.5,
			ArchGenerator.Kind.POINTED, 0.16, 16)
		for i in 3:
			var x := side * (10.5 + 3.6 * float(i))
			group.add_child(_mesh_node(arc_mesh, "sandstone", Vector3(x, 0.4, 21.95)))
		group.add_child(_box_node(Vector3(13.4, 0.4, 1.3), "ivory_stone", Vector3(side * 14.5, 10.2, 22.5)))
		group.add_child(MeshBuilder.multimesh_instance(cren_mesh, cren_mat,
			DecorationGenerator.crenellation_transforms(
				Vector3(side * 8.4, 0, 22.5), Vector3(side * 20.6, 0, 22.5), 0.95,
				Vector3(0.3, 0.42, 0.3), 10.4), "SideCrenellations"))
		var lantern := DecorationGenerator.lantern_node()
		lantern.position = Vector3(side * 5.2, 7.4, 21.6)
		group.add_child(lantern)
		ctx["lights"].append(Vector3(side * 5.2, 6.7, 21.6))

	ctx["root"].add_child(group)
	ctx["focus_points"]["gate"] = {"point": Vector3(0, 6.0, 22.0), "radius": 18.0}


static func _build_forecourt(ctx: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "Forecourt"
	ctx["root"].add_child(group)

	group.add_child(_box_node(Vector3(32, 0.05, 17), "marble_polished",
		Vector3(0, 0.025, 32.5), Vector3.ZERO, "ForecourtSlab"))
	var cren_mesh := MeshBuilder.build_box(Vector3(0.3, 0.42, 0.3))
	var cren_mat := MaterialLibrary.get_material("sandstone")
	for side: float in [-1.0, 1.0]:
		var wall := _box_node(Vector3(0.9, 4.0, 16.0), "sandstone",
			Vector3(side * 16.0, 2.0, 32.5), Vector3.ZERO, "ForecourtWall")
		group.add_child(wall)
		_add_box_collision(ctx, Vector3(side * 16.0, 2.0, 32.5), Vector3(0.9, 4.0, 16.0))
		group.add_child(MeshBuilder.multimesh_instance(cren_mesh, cren_mat,
			DecorationGenerator.crenellation_transforms(
				Vector3(side * 16.0, 0, 24.6), Vector3(side * 16.0, 0, 40.4), 0.95,
				Vector3(0.3, 0.42, 0.3), 3.95), "ForecourtCrenellations"))
	var end_wall := _box_node(Vector3(32.0, 4.0, 0.9), "sandstone",
		Vector3(0, 2.0, 40.5), Vector3.ZERO, "ForecourtEnd")
	group.add_child(end_wall)
	_add_box_collision(ctx, Vector3(0, 2.0, 40.5), Vector3(32.0, 4.0, 0.9))
	group.add_child(MeshBuilder.multimesh_instance(cren_mesh, cren_mat,
		DecorationGenerator.crenellation_transforms(
			Vector3(-15.5, 0, 40.5), Vector3(15.5, 0, 40.5), 0.95,
			Vector3(0.3, 0.42, 0.3), 3.95), "EndCrenellations"))

	for side: float in [-1.0, 1.0]:
		var lantern_post := _box_node(Vector3(0.6, 4.2, 0.6), "sandstone",
			Vector3(side * 8.0, 2.1, 37.0), Vector3.ZERO, "LanternPost")
		group.add_child(lantern_post)
		_add_box_collision(ctx, Vector3(side * 8.0, 2.1, 37.0), Vector3(0.6, 4.2, 0.6))
		var lantern := DecorationGenerator.lantern_node(0.3)
		lantern.position = Vector3(side * 8.0, 4.6, 37.0)
		group.add_child(lantern)
		ctx["lights"].append(Vector3(side * 8.0, 3.9, 37.0))
		_add_proxy(ctx, "forecourt", Vector3(side * 10.0, 2.0, 32.5), Vector3(12.0, 4.4, 16.0), group)
	_add_proxy(ctx, "forecourt", Vector3(0, 2.0, 40.4), Vector3(32.0, 4.4, 0.9), end_wall)
	ctx["focus_points"]["forecourt"] = {"point": Vector3(0, 2.0, 32.0), "radius": 20.0}


# --- Minarets ----------------------------------------------------------------

static func _build_minarets(ctx: Dictionary) -> void:
	var positions: Array = [
		{"pos": Vector3(-13.4, 0.0, -7.6), "h": 26.0},
		{"pos": Vector3(13.4, 0.0, -7.6), "h": 26.0},
		{"pos": Vector3(-11.5, 0.0, 19.8), "h": 23.0},
		{"pos": Vector3(11.5, 0.0, 19.8), "h": 23.0},
	]
	for entry: Dictionary in positions:
		var pos: Vector3 = entry["pos"]
		var h: float = entry["h"]
		var minaret := MinaretGenerator.build(h)
		minaret.position = pos
		ctx["root"].add_child(minaret)
		_add_cylinder_collision(ctx, pos + Vector3(0, h * 0.5, 0), h * 0.085, h)
		_add_cylinder_proxy(ctx, "minaret", pos + Vector3(0, h * 0.5, 0), h * 0.09, h, minaret)
		ctx["lights"].append(pos + Vector3(0, h * 0.855, 0))
	ctx["focus_points"]["minaret"] = {"point": Vector3(13.4, 12.0, -7.6), "radius": 18.0}
