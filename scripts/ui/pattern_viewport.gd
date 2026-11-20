class_name PatternViewport
extends SubViewportContainer
## Reusable 3D preview for generated patterns.
##
## Owns a dedicated World3D (a SubViewport with its own environment and
## lights), an orbit camera driven by mouse drag/pinch-free controls, an
## optional backdrop medallion, autorotation, wireframe mode, PNG capture of
## the current view and a transparent flat PNG export of a pattern.

@export var autorotate_speed := 0.5

var _yaw := 0.62
var _pitch := 0.35    ## positive = camera above the model
var _distance := 8.0
var _target := Vector3.ZERO
var _dragging := false
var _panning := false
var _autorotate := false
var _autorotate_mode := "sway"
var _base_yaw := 0.62
var _time := 0.0
var _backdrop_visible := true
var _backdrop_radius := 1.0
var _pending_preset := ""

@onready var _sub: SubViewport = $SubViewport
@onready var _environment: WorldEnvironment = $SubViewport/WorldEnvironment
@onready var _key_light: DirectionalLight3D = $SubViewport/KeyLight
@onready var _fill_light: DirectionalLight3D = $SubViewport/FillLight
@onready var _camera: Camera3D = $SubViewport/Camera3D
@onready var _model_root: Node3D = $SubViewport/ModelRoot

var _backdrop: Node3D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.msaa_3d = AppState.quality_int("msaa")
	_camera.current = true
	if AppState.quality_changed.is_connected(_on_quality_changed) == false:
		AppState.quality_changed.connect(_on_quality_changed)
	_build_environment("studio")
	_build_backdrop()
	_update_camera()
	if not _pending_preset.is_empty():
		_build_environment(_pending_preset)


func _on_quality_changed(_key: String) -> void:
	_sub.msaa_3d = AppState.quality_int("msaa")
	_refresh_environment_quality()


# --- Model management --------------------------------------------------------

func clear_model() -> void:
	for child in _model_root.get_children():
		child.queue_free()
		_model_root.remove_child(child)


func add_model_node(node: Node3D) -> void:
	_model_root.add_child(node)


func model_root() -> Node3D:
	return _model_root


# --- Camera control ----------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_dragging = true
					_panning = mb.shift_pressed
				else:
					_dragging = false
					_panning = false
			MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
				_dragging = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom(1.0 / AppState.orbit_zoom_step)
					accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom(AppState.orbit_zoom_step)
					accept_event()
			MOUSE_BUTTON_RIGHT:
				if mb.pressed and mb.double_click:
					frame_content()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		if _panning:
			_pan(mm.relative)
		else:
			_yaw -= mm.relative.x * AppState.orbit_sensitivity
			var dy := mm.relative.y * AppState.orbit_sensitivity
			_pitch += -dy if AppState.orbit_invert_y else dy
			_pitch = clampf(_pitch, -1.45, 1.45)
		_update_camera()


func _zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, 0.4, 220.0)
	_update_camera()


func _pan(relative: Vector2) -> void:
	var right := _camera.global_transform.basis.x
	var up := _camera.global_transform.basis.y
	var scale := _distance * 0.0016
	_target -= right * relative.x * scale
	_target += up * relative.y * scale


func _update_camera() -> void:
	var dir := Vector3(
		cos(_pitch) * sin(_yaw),
		sin(_pitch),
		cos(_pitch) * cos(_yaw))
	_camera.position = _target + dir * _distance
	if _camera.position.distance_to(_target) > 0.001:
		_camera.look_at(_target, Vector3.UP)


func _process(delta: float) -> void:
	if _autorotate:
		_time += delta
		if _autorotate_mode == "spin":
			_yaw += delta * autorotate_speed
		else:
			# gentle sway around the hero angle — keeps a flat pattern readable
			_yaw = _base_yaw + sin(_time * autorotate_speed * 0.55) * 0.30
		_update_camera()


func set_autorotate(enabled: bool, speed: float = -1.0, mode: String = "sway") -> void:
	_autorotate = enabled
	_autorotate_mode = mode
	if speed > 0.0:
		autorotate_speed = speed
	_base_yaw = _yaw
	_time = 0.0


## Directly sets the orbit pose (used for a controlled hero view).
func set_orbit(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, -1.45, 1.45)
	_base_yaw = _yaw
	_update_camera()


## Shifts the projection so the model can sit off-centre (menu composition).
func set_screen_offset(h: float, v: float) -> void:
	_camera.h_offset = h
	_camera.v_offset = v


func set_view(preset: String) -> void:
	match preset:
		"front":
			_yaw = 0.0
			_pitch = 0.06
		"top":
			_yaw = 0.0
			_pitch = 1.4
		"side":
			_yaw = PI * 0.5
			_pitch = 0.12
		"iso":
			_yaw = 0.62
			_pitch = 0.42
		_:
			pass
	_update_camera()


## Frames the current model in view.
func frame_content(margin: float = 1.22) -> void:
	var aabb := content_aabb()
	var radius := 1.0
	if aabb.size.length() > 0.001:
		_target = aabb.get_center()
		radius = aabb.size.length() * 0.5
	else:
		_target = Vector3.ZERO
	if _backdrop_visible:
		radius = maxf(radius, _backdrop_radius)
	var half_fov := deg_to_rad(_camera.fov * 0.5)
	_distance = clampf(radius / maxf(tan(half_fov), 0.05) * margin, 0.6, 220.0)
	if OS.is_debug_build() and "--pv-debug" in OS.get_cmdline_user_args():
		print("[PatternViewport] frame_content: aabb=%s radius=%.3f dist=%.3f viewport_size=%s" % [str(aabb), radius, _distance, str(_sub.size)])
	if _backdrop_visible:
		_backdrop.scale = Vector3.ONE * _backdrop_radius
		_backdrop.position = Vector3(_target.x, _target.y, 0.0) - Vector3(0, 0, 0.01)
	_update_camera()


## Combined world-space AABB of every mesh under ModelRoot.
func content_aabb() -> AABB:
	var result := AABB()
	var found := false
	var stack: Array[Node] = [_model_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				var world_aabb := _transform_aabb(mi.mesh.get_aabb(), mi.global_transform)
				result = world_aabb if not found else result.merge(world_aabb)
				found = true
		for child in node.get_children():
			stack.append(child)
	if not found:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return result


static func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	for i in 8:
		var corner := aabb.position + Vector3(
			aabb.size.x * float(i & 1),
			aabb.size.y * float((i >> 1) & 1),
			aabb.size.z * float((i >> 2) & 1))
		var p := xform * corner
		if first:
			result = AABB(p, Vector3.ZERO)
			first = false
		else:
			result = result.expand(p)
	return result


# --- Appearance --------------------------------------------------------------

func set_environment_preset(preset: String) -> void:
	if _environment == null:
		_pending_preset = preset
		return
	_build_environment(preset)


func _build_environment(preset: String) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var key_color := Color(1.0, 0.96, 0.88)
	var fill_color := Color(0.65, 0.78, 0.95)
	var key_energy := 1.35
	var fill_energy := 0.4
	var key_angles := Vector3(-42.0, 38.0, 0.0)
	match preset:
		"gallery":
			env.background_color = Color(0.82, 0.81, 0.77)
			env.ambient_light_color = Color(0.9, 0.9, 0.92)
			env.ambient_light_energy = 0.9
			key_energy = 1.0
			fill_energy = 0.5
			key_color = Color(1.0, 0.99, 0.96)
		"night_gold":
			env.background_color = Color(0.016, 0.028, 0.045)
			env.ambient_light_color = Color(0.36, 0.42, 0.58)
			env.ambient_light_energy = 0.62
			key_color = Color(1.0, 0.85, 0.56)
			key_energy = 1.9
			fill_energy = 0.28
			key_angles = Vector3(-34.0, 30.0, 0.0)
		_:
			env.background_color = Color(0.031, 0.055, 0.082)
			env.ambient_light_color = Color(0.62, 0.68, 0.82)
			env.ambient_light_energy = 0.62
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.environment = env
	_refresh_environment_quality()

	_key_light.rotation_degrees = key_angles
	_key_light.light_color = key_color
	_key_light.light_energy = key_energy
	_key_light.shadow_enabled = AppState.quality_bool("shadows")
	_fill_light.rotation_degrees = Vector3(-18.0, -125.0, 0.0)
	_fill_light.light_color = fill_color
	_fill_light.light_energy = fill_energy
	_fill_light.shadow_enabled = false


func _refresh_environment_quality() -> void:
	var env := _environment.environment
	if env == null:
		return
	GodotCompat.try_set(env, "glow_enabled", AppState.quality_bool("glow"))
	GodotCompat.try_set(env, "ssao_enabled", AppState.quality_bool("ssao"))
	if AppState.quality_bool("ssao"):
		GodotCompat.try_set(env, "ssao_radius", 0.8)
		GodotCompat.try_set(env, "ssao_intensity", 1.4)
	if _key_light != null:
		_key_light.shadow_enabled = AppState.quality_bool("shadows")


func set_wireframe(enabled: bool) -> void:
	GodotCompat.try_set(_sub, "debug_draw",
		Viewport.DEBUG_DRAW_WIREFRAME if enabled else Viewport.DEBUG_DRAW_DISABLED)


func set_backdrop_visible(visible_now: bool) -> void:
	_backdrop_visible = visible_now
	if _backdrop != null:
		_backdrop.visible = visible_now


func set_backdrop_radius(radius: float) -> void:
	_backdrop_radius = maxf(radius, 0.05)


func _build_backdrop() -> void:
	_backdrop = Node3D.new()
	_backdrop.name = "Backdrop"
	_sub.add_child(_backdrop)
	# dark disc behind the pattern (a framed-artwork look)
	var disc := MeshBuilder.build_slab_mesh(
		[MathUtils.polygon_vertices(64, 1.0)], -0.075, 0.02, 0.0)
	var disc_node := MeshInstance3D.new()
	disc_node.mesh = disc
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.055, 0.085, 0.115)
	disc_mat.roughness = 0.8
	disc_node.material_override = disc_mat
	_backdrop.add_child(disc_node)
	# gold rim
	var rim := MeshBuilder.build_ribbon_mesh(
		_ring_segments(1.0, 96), PackedFloat32Array(), 0.012, -0.05, 0.006, false)
	var rim_node := MeshInstance3D.new()
	rim_node.mesh = rim
	rim_node.material_override = MaterialLibrary.pattern_material(NoorTheme.GOLD, "line")
	_backdrop.add_child(rim_node)
	var rim2 := MeshBuilder.build_ribbon_mesh(
		_ring_segments(0.94, 96), PackedFloat32Array(), 0.004, -0.05, 0.004, false)
	var rim2_node := MeshInstance3D.new()
	rim2_node.mesh = rim2
	var rim2_mat := StandardMaterial3D.new()
	rim2_mat.albedo_color = Color(0.55, 0.45, 0.18)
	rim2_mat.metallic = 0.7
	rim2_mat.roughness = 0.4
	rim2_node.material_override = rim2_mat
	_backdrop.add_child(rim2_node)


static func _ring_segments(radius: float, count: int) -> Array:
	var segments: Array = []
	var pts := MathUtils.polygon_vertices(count, radius)
	for i in count:
		segments.append(PackedVector2Array([pts[i], pts[(i + 1) % count]]))
	return segments


# --- Capture -----------------------------------------------------------------

## Captures the current preview (what the user sees).
func capture_image() -> Image:
	await RenderingServer.frame_post_draw
	var texture := _sub.get_texture()
	if texture == null:
		return null
	return texture.get_image()


## Exports the pattern as a flat, transparent PNG rendered top-down with
## unshaded colours (resolution x resolution pixels).
## Returns the absolute save path, or "" on failure.
func export_flat_png(config: PatternConfig, geo: PatternGeometry,
		resolution: int = 1024, path: String = "") -> String:
	return await export_flat(get_tree(), config, geo, resolution, path)


## Static version so developer tools can export without a preview instance.
static func export_flat(tree: SceneTree, config: PatternConfig, geo: PatternGeometry,
		resolution: int = 1024, path: String = "") -> String:
	if tree == null:
		return ""
	var bounds := geo.bounds
	var extent := maxf(maxf(bounds.size.x, bounds.size.y), 0.1)
	var centre := bounds.get_center()

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(resolution, resolution)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = extent * 1.08
	cam.position = Vector3(centre.x, centre.y, 10.0)
	cam.current = true
	vp.add_child(cam)
	var root := Node3D.new()
	vp.add_child(root)
	var layers := MeshBuilder.build_pattern_layers(geo, config, true)
	var colors := [config.color_fill, config.color_accent, config.color_line]
	for i in layers.size():
		var layer_mesh: ArrayMesh = layers[i]
		if layer_mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = layer_mesh
		mi.material_override = MaterialLibrary.flat_export_material(colors[i])
		root.add_child(mi)
	tree.root.add_child(vp)
	var saved := ""
	# two frames: one to build the viewport, one fully rendered
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture := vp.get_texture()
	if texture != null:
		var img := texture.get_image()
		if img != null:
			if path.is_empty():
				path = default_export_path("pattern")
			var err := img.save_png(path)
			if err == OK:
				saved = path
	vp.queue_free()
	return saved


static func default_export_path(prefix: String) -> String:
	var dir := "user://exports"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	return "%s/noor_%s_%s.png" % [dir, prefix, stamp]
