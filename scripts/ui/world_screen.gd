extends Node3D
## Architecture Explorer — the interactive 3D environment.
##
## Owns the generated architecture, both camera systems (orbit + first
## person), the interaction raycasts (hover + selection), the information
## panel, time-of-day lighting and the pattern-panel update loop.
##
## The whole environment is built by ArchitectureGenerator when the screen is
## created and kept alive across navigation, so patterns applied in the
## laboratory appear here without regenerating the architecture.

signal screen_requested(id: String)
signal toast_requested(text: String)

const TIME_PRESETS: Array = [
	{  # Dawn
		"sky_top": Color(0.30, 0.42, 0.62), "sky_horizon": Color(0.95, 0.66, 0.48),
		"ground": Color(0.35, 0.28, 0.24), "sun_color": Color(1.0, 0.74, 0.55),
		"sun_energy": 1.0, "sun_elevation": 9.0, "sun_yaw": -65.0,
		"ambient": 0.38, "fog": 0.0026, "lanterns": false,
	},
	{  # Morning
		"sky_top": Color(0.32, 0.52, 0.80), "sky_horizon": Color(0.78, 0.86, 0.94),
		"ground": Color(0.42, 0.36, 0.30), "sun_color": Color(1.0, 0.94, 0.82),
		"sun_energy": 1.25, "sun_elevation": 32.0, "sun_yaw": -55.0,
		"ambient": 0.5, "fog": 0.0016, "lanterns": false,
	},
	{  # Noon
		"sky_top": Color(0.25, 0.47, 0.82), "sky_horizon": Color(0.80, 0.88, 0.96),
		"ground": Color(0.45, 0.38, 0.31), "sun_color": Color(1.0, 0.98, 0.94),
		"sun_energy": 1.32, "sun_elevation": 68.0, "sun_yaw": -30.0,
		"ambient": 0.52, "fog": 0.001, "lanterns": false,
	},
	{  # Afternoon
		"sky_top": Color(0.28, 0.47, 0.78), "sky_horizon": Color(0.86, 0.84, 0.80),
		"ground": Color(0.44, 0.37, 0.30), "sun_color": Color(1.0, 0.90, 0.72),
		"sun_energy": 1.3, "sun_elevation": 38.0, "sun_yaw": 42.0,
		"ambient": 0.5, "fog": 0.0016, "lanterns": false,
	},
	{  # Dusk
		"sky_top": Color(0.22, 0.26, 0.48), "sky_horizon": Color(0.98, 0.54, 0.30),
		"ground": Color(0.30, 0.24, 0.22), "sun_color": Color(1.0, 0.58, 0.32),
		"sun_energy": 0.95, "sun_elevation": 7.0, "sun_yaw": 62.0,
		"ambient": 0.3, "fog": 0.003, "lanterns": true,
	},
	{  # Night
		"sky_top": Color(0.02, 0.03, 0.08), "sky_horizon": Color(0.06, 0.09, 0.16),
		"ground": Color(0.02, 0.03, 0.05), "sun_color": Color(0.62, 0.72, 0.98),
		"sun_energy": 0.35, "sun_elevation": 55.0, "sun_yaw": 25.0,
		"ambient": 0.13, "fog": 0.0034, "lanterns": true,
	},
]

var _time_index := 0
var _orbit: OrbitCamera
var _player: FirstPersonController
var _environment: WorldEnvironment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _lanterns: Array[OmniLight3D] = []
var _proxies: Array[InteractiveObject] = []
var _panel_nodes: Dictionary = {}
var _focus_points: Dictionary = {}
var _mode := "orbit"
var _fp_spawned := false
var _press_position := Vector2.ZERO
var _orbiting := false
var _panning := false
var _hovered: InteractiveObject = null
var _mouse_captured := false

# UI
var _info_panel: InfoPanel
var _help_overlay: Control
var _crosshair: Control
var _camera_button: Button
var _time_button: Button
var _fps_label: Label
var _views_option: OptionButton
var _hint_label: Label


func _ready() -> void:
	_build_environment()
	_generate_architecture()
	_build_cameras()
	_build_ui()

	AppState.lighting_preset_changed.connect(_apply_lighting)
	AppState.quality_changed.connect(_on_quality_changed)
	PatternLibrary.panel_changed.connect(_on_panel_changed)

	_time_index = AppState.time_of_day
	_apply_lighting(AppState.time_of_day)
	_apply_quality()
	_set_mode("orbit")

	if not DevCapture.cam_preset.is_empty():
		_focus_preset(DevCapture.cam_preset)
	if not DevCapture.dev_mode.is_empty():
		_set_mode(DevCapture.dev_mode)
	if not DevCapture.dev_select.is_empty():
		dev_select(DevCapture.dev_select)


# --- World construction ------------------------------------------------------

func _build_environment() -> void:
	_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_curve = 0.2
	_sky_material.ground_curve = 0.05
	sky.sky_material = _sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	GodotCompat.try_set(env, "fog_enabled", true)
	GodotCompat.try_set(env, "fog_light_color", Color(0.75, 0.79, 0.86))
	GodotCompat.try_set(env, "fog_density", 0.0016)
	_environment.environment = env
	add_child(_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 140.0
	GodotCompat.try_set(_sun, "directional_shadow_blend_splits", true)
	add_child(_sun)


func _generate_architecture() -> void:
	var ctx := ArchitectureGenerator.generate()
	add_child(ctx["root"])

	# collision world
	var collision_body := StaticBody3D.new()
	collision_body.name = "Collision"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0
	for entry: Dictionary in ctx["collision"]:
		var collider := CollisionShape3D.new()
		if String(entry.get("shape", "box")) == "cylinder":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = float(entry["radius"])
			cylinder.height = float(entry["height"])
			collider.shape = cylinder
		else:
			var box := BoxShape3D.new()
			box.size = entry["size"]
			collider.shape = box
		collider.position = entry["position"]
		collider.rotation_degrees = entry.get("rotation_deg", Vector3.ZERO)
		collision_body.add_child(collider)
	add_child(collision_body)

	# interactive proxies
	for entry: Dictionary in ctx["proxies"]:
		var shape: Shape3D
		if String(entry.get("shape", "box")) == "cylinder":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = float(entry["radius"])
			cylinder.height = float(entry["height"])
			shape = cylinder
		else:
			var box := BoxShape3D.new()
			box.size = entry["size"]
			shape = box
		var transform := Transform3D(Basis.from_euler(Vector3(
			deg_to_rad(entry.get("rotation_deg", Vector3.ZERO).x),
			deg_to_rad(entry.get("rotation_deg", Vector3.ZERO).y),
			deg_to_rad(entry.get("rotation_deg", Vector3.ZERO).z))), entry["position"])
		var proxy := InteractiveObject.make(String(entry["info_id"]), shape, transform, entry["highlight"])
		add_child(proxy)
		_proxies.append(proxy)

	# lantern point lights (enabled by the time-of-day preset)
	for position: Vector3 in ctx["lights"]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.28)
		light.light_energy = 2.4
		light.omni_range = 12.0
		light.shadow_enabled = false
		light.position = position
		add_child(light)
		_lanterns.append(light)

	# pattern panels
	for panel: Node in ctx["panels"]:
		var p := panel as PatternPanel
		_panel_nodes[p.panel_id] = p
	_focus_points = ctx["focus_points"]
	_focus_points["overview"] = {"point": Vector3(0, 5, 1), "radius": 44.0}
	_focus_points["fountain"] = _focus_points.get("fountain", {"point": Vector3(0, 2, 0), "radius": 6.0})


func _build_cameras() -> void:
	_orbit = OrbitCamera.new()
	_orbit.name = "OrbitCamera"
	add_child(_orbit)
	_orbit.setup()

	_player = FirstPersonController.new()
	_player.name = "Player"
	_player.position = Vector3(0, 0.1, 18.0)
	add_child(_player)
	_player.setup()
	_player.set_look(0.0, -0.05)


# --- Lighting ----------------------------------------------------------------

func _apply_lighting(preset_index: int) -> void:
	_time_index = clampi(preset_index, 0, TIME_PRESETS.size() - 1)
	var preset: Dictionary = TIME_PRESETS[_time_index]
	_sky_material.sky_top_color = preset["sky_top"]
	_sky_material.sky_horizon_color = preset["sky_horizon"]
	_sky_material.ground_bottom_color = preset["ground"]
	_sky_material.ground_horizon_color = preset["sky_horizon"]
	_sun.rotation_degrees = Vector3(-float(preset["sun_elevation"]), float(preset["sun_yaw"]), 0.0)
	_sun.light_color = preset["sun_color"]
	_sun.light_energy = preset["sun_energy"]
	var env := _environment.environment
	env.ambient_light_energy = preset["ambient"]
	GodotCompat.try_set(env, "fog_density", preset["fog"])
	GodotCompat.try_set(env, "fog_light_color", preset["sky_horizon"].lerp(preset["sky_top"], 0.4))
	for light in _lanterns:
		light.visible = bool(preset["lanterns"])
	if _time_button != null:
		_time_button.text = AppState.TIME_PRESET_NAMES[_time_index]


func _apply_quality() -> void:
	var env := _environment.environment
	GodotCompat.try_set(env, "ssao_enabled", AppState.quality_bool("ssao"))
	if AppState.quality_bool("ssao"):
		GodotCompat.try_set(env, "ssao_radius", 1.4)
		GodotCompat.try_set(env, "ssao_intensity", 1.6)
	GodotCompat.try_set(env, "glow_enabled", AppState.quality_bool("glow"))
	GodotCompat.try_set(env, "ssr_enabled", AppState.quality_bool("reflections"))
	if AppState.quality_bool("reflections"):
		GodotCompat.try_set(env, "ssr_max_steps", 32)
		GodotCompat.try_set(env, "ssr_fade_in", 2.0)
	_sun.shadow_enabled = AppState.quality_bool("shadows")
	var viewport := get_viewport()
	if viewport != null:
		viewport.msaa_3d = AppState.quality_int("msaa")


func _on_quality_changed(_key: String) -> void:
	_apply_quality()


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	# top bar
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 8
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(bar)
	var bar_box := HBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 8)
	bar.add_child(bar_box)

	var menu_button := UIHelpers.button("Menu", false, "Back to the main menu.")
	menu_button.theme_type_variation = &"ToolButton"
	menu_button.pressed.connect(func() -> void: screen_requested.emit("menu"))
	bar_box.add_child(menu_button)
	var title := UIHelpers.label("Architecture Explorer", 17, NoorTheme.GOLD_LIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_box.add_child(title)

	_camera_button = UIHelpers.button("Camera: Orbit  (C)", false, "Toggle between the orbit camera and walking in first person.")
	_camera_button.theme_type_variation = &"ToolButton"
	_camera_button.pressed.connect(func() -> void: _set_mode("first_person" if _mode == "orbit" else "orbit"))
	bar_box.add_child(_camera_button)

	var views := PackedStringArray(["Jump to…", "Overview", "Courtyard & Fountain", "Dome & Hall", "Entrance Portal", "Floor Medallion", "Minarets", "Arcade"])
	var views_row := UIHelpers.dropdown_row("", views, 0, "Focus the orbit camera on a landmark.")
	_views_option = views_row["option"]
	_views_option.item_selected.connect(func(index: int) -> void:
		var keys := ["", "overview", "fountain", "dome", "gate", "medallion", "minaret", "arcade_west"]
		if index > 0 and index < keys.size():
			_focus_preset(keys[index])
		_views_option.selected = 0)
	bar_box.add_child(views_row["row"])

	_time_button = UIHelpers.button(AppState.time_preset_name(), false, "Cycle the time of day (T).")
	_time_button.theme_type_variation = &"ToolButton"
	_time_button.pressed.connect(func() -> void: AppState.cycle_time_of_day())
	bar_box.add_child(_time_button)

	var help_button := UIHelpers.button("?", false, "Controls help (H).")
	help_button.theme_type_variation = &"ToolButton"
	help_button.pressed.connect(_toggle_help)
	bar_box.add_child(help_button)

	_fps_label = UIHelpers.muted("", 12)
	bar_box.add_child(_fps_label)

	# info panel (right side)
	_info_panel = InfoPanel.new()
	_info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_panel.anchor_bottom = 1.0
	_info_panel.offset_left = -400
	_info_panel.offset_right = -10
	_info_panel.offset_top = 62
	_info_panel.offset_bottom = -12
	_info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_info_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_info_panel.closed.connect(func() -> void: _clear_selection())
	_info_panel.focus_requested.connect(_on_focus_requested)
	_info_panel.edit_pattern_requested.connect(_on_edit_pattern)
	layer.add_child(_info_panel)

	# hint
	_hint_label = UIHelpers.muted("Drag to orbit · right-drag to pan · wheel to zoom · click objects for information", 12)
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -30
	_hint_label.offset_bottom = -8
	_hint_label.offset_left = 16
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	layer.add_child(_hint_label)

	# crosshair (first person)
	_crosshair = _make_crosshair()
	layer.add_child(_crosshair)

	# help overlay
	_help_overlay = _make_help_overlay()
	layer.add_child(_help_overlay)


func _make_crosshair() -> Control:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.visible = false
	var label := Label.new()
	label.text = "✛"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 4)
	centre.add_child(label)
	return centre


func _make_help_overlay() -> Control:
	var overlay := CenterContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	var stack := UIHelpers.panel_stack(480)
	var panel: PanelContainer = stack["panel"]
	var vbox: VBoxContainer = stack["vbox"]
	panel.add_child(UIHelpers.scroll_wrap(vbox))
	vbox.add_child(UIHelpers.title("Controls"))
	vbox.add_child(UIHelpers.section("Architecture Explorer"))
	vbox.add_child(UIHelpers.wrapped(
		"Orbit camera\n"
		+ "  · Drag with the left mouse button — orbit\n"
		+ "  · Drag with the right mouse button / middle button — pan\n"
		+ "  · Mouse wheel — zoom · Double-click the right button — frame object\n"
		+ "  · Click an object — information panel\n\n"
		+ "First person (press C)\n"
		+ "  · W A S D — walk · Shift — run · Space — jump\n"
		+ "  · Mouse — look · Left click — inspect what the crosshair points at\n"
		+ "  · Escape — release the mouse cursor\n\n"
		+ "General\n"
		+ "  · C — switch camera · T — cycle time of day\n"
		+ "  · H — this help · F12 — screenshot\n"
		+ "  · Escape — close panels / back", 14))
	var close := UIHelpers.button("Close", true, "")
	close.pressed.connect(_toggle_help)
	vbox.add_child(close)
	overlay.add_child(panel)
	return overlay


func _toggle_help() -> void:
	_help_overlay.visible = not _help_overlay.visible


# --- Camera modes ------------------------------------------------------------

func _set_mode(mode: String) -> void:
	_mode = mode
	if mode == "first_person":
		if not _fp_spawned:
			_player.global_position = Vector3(0, 0.1, 18.0)
			_player.set_look(0.0, -0.05)
			_fp_spawned = true
		_orbit.set_current(false)
		_player.set_active(true)
		_set_mouse_captured(true)
	else:
		_orbit.target = _player.global_position + Vector3(0, 1.2, 0)
		_orbit.update_transform()
		_player.set_active(false)
		_orbit.set_current(true)
		_set_mouse_captured(false)
	if _camera_button != null:
		_camera_button.text = "Camera: %s  (C)" % ("First Person" if mode == "first_person" else "Orbit")
	if _crosshair != null:
		_crosshair.visible = mode == "first_person"
	if _hint_label != null:
		_hint_label.text = ("W A S D walk · Shift run · Space jump · Esc releases the mouse · C returns to orbit"
			if mode == "first_person"
			else "Drag to orbit · right-drag to pan · wheel to zoom · click objects for information · C walks the courtyard")


func _set_mouse_captured(on: bool) -> void:
	_mouse_captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _on_focus_requested(point: Vector3, radius: float) -> void:
	if _mode != "orbit":
		_set_mode("orbit")
	_orbit.focus_on(point, radius)


func _focus_preset(key: String) -> void:
	var entry: Dictionary = _focus_points.get(key, {})
	if entry.is_empty():
		return
	if _mode != "orbit":
		_set_mode("orbit")
	_orbit.focus_on(entry["point"], entry["radius"])


func _on_edit_pattern(panel_id: String) -> void:
	var config: PatternConfig = PatternLibrary.get_panel_config(panel_id)
	if config == null:
		return
	PatternLibrary.set_active_panel(panel_id)
	PatternLibrary.lab_config.copy_from(config)
	PatternLibrary.lab_config.pattern_type = config.pattern_type
	screen_requested.emit("lab")


# --- Interaction -------------------------------------------------------------

func _active_camera() -> Camera3D:
	if _mode == "first_person" and _player != null:
		return _player.camera
	return _orbit.camera


func _raycast(screen_position: Vector2) -> Dictionary:
	var camera := _active_camera()
	if camera == null:
		return {}
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 600.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	var space := get_world_3d().direct_space_state
	return space.intersect_ray(query)


func _select_at(screen_position: Vector2) -> void:
	var hit := _raycast(screen_position)
	if hit.is_empty():
		_clear_selection()
		return
	var proxy := hit.get("collider") as InteractiveObject
	if proxy == null:
		_clear_selection()
		return
	_show_proxy_info(proxy, hit["position"])


func _show_proxy_info(proxy: InteractiveObject, hit_position: Vector3) -> void:
	var data := proxy.info()
	var radius := 6.0
	var point: Vector3 = hit_position + Vector3(0, 1.5, 0)
	# object-specific focus hints
	match proxy.info_id:
		"dome", "drum", "hall":
			var entry: Dictionary = _focus_points.get("dome", {})
			point = entry.get("point", point)
			radius = entry.get("radius", 16.0)
		"minaret":
			point = hit_position
			radius = 16.0
		"fountain", "water":
			radius = 6.0
		"floor_medallion":
			radius = 12.0
		"gate", "gate_panel":
			radius = 15.0
	_info_panel.show_info(data, point, radius)


## Developer helper: opens one object's information panel directly.
func dev_select(info_id: String) -> void:
	for proxy in _proxies:
		if proxy.info_id == info_id:
			_show_proxy_info(proxy, proxy.global_position)
			return


## Developer helper: camera state for the automated UI test.
func dev_debug_state() -> Dictionary:
	return {
		"mode": _mode,
		"yaw": _orbit.yaw if _orbit != null else 0.0,
		"pitch": _orbit.pitch if _orbit != null else 0.0,
		"distance": _orbit.distance if _orbit != null else 0.0,
	}


func _clear_selection() -> void:
	_info_panel.visible = false
	if _hovered != null:
		_hovered.set_highlighted(false)
		_hovered = null


func _on_panel_changed(panel_id: String) -> void:
	if not _panel_nodes.has(panel_id):
		return
	var panel: PatternPanel = _panel_nodes[panel_id]
	panel.rebuild(PatternLibrary.get_panel_config(panel_id))
	if _info_panel != null and _info_panel.visible:
		_info_panel.refresh_preview()


func _update_hover() -> void:
	if _mouse_captured or _info_panel == null:
		return
	if _info_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return
	var hit := _raycast(get_viewport().get_mouse_position())
	var proxy := hit.get("collider") as InteractiveObject
	if proxy == _hovered:
		return
	if _hovered != null:
		_hovered.set_highlighted(false)
	_hovered = proxy
	if _hovered != null:
		_hovered.set_highlighted(true)


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _mouse_captured:
			_player.look_by(motion.relative)
		elif _orbiting:
			_orbit.orbit_by(motion.relative)
		elif _panning:
			_orbit.pan_by(motion.relative)
		return

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					if _mouse_captured:
						# inspect what the crosshair points at
						var centre := get_viewport().get_visible_rect().size * 0.5
						_select_at(centre)
					else:
						_press_position = button.position
						_orbiting = not button.shift_pressed
						_panning = button.shift_pressed
				else:
					if not _mouse_captured and _orbiting:
						if button.position.distance_to(_press_position) < 6.0:
							_select_at(button.position)
					_orbiting = false
					_panning = false
			MOUSE_BUTTON_RIGHT:
				if button.pressed:
					if button.double_click:
						var hit := _raycast(button.position)
						if not hit.is_empty():
							_on_focus_requested(hit["position"], 9.0)
					else:
						_panning = true
						_orbiting = false
				else:
					_panning = false
			MOUSE_BUTTON_MIDDLE:
				_panning = button.pressed
				_orbiting = false if not button.pressed else _orbiting
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_orbit.zoom_by(1.0 / AppState.orbit_zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_orbit.zoom_by(AppState.orbit_zoom_step)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("noor_toggle_camera"):
			_set_mode("first_person" if _mode == "orbit" else "orbit")
			get_viewport().set_input_as_handled()
		elif event.is_action("noor_time"):
			AppState.cycle_time_of_day()
			get_viewport().set_input_as_handled()
		elif event.is_action("noor_help"):
			_toggle_help()
			get_viewport().set_input_as_handled()
		elif event.is_action("ui_cancel"):
			if _mouse_captured:
				_set_mouse_captured(false)
			elif _info_panel.visible:
				_clear_selection()
			elif _help_overlay.visible:
				_toggle_help()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_hover()
	if _fps_label != null:
		_fps_label.text = "%d fps" % Engine.get_frames_per_second()


# --- Screen lifecycle --------------------------------------------------------

func on_shown() -> void:
	_apply_lighting(AppState.time_of_day)
	_apply_quality()
	if _mode == "first_person":
		_player.set_active(true)
		_set_mouse_captured(true)
	else:
		_player.set_active(false)
		_orbit.set_current(true)


func on_hidden() -> void:
	# stop rendering this World3D while another screen is on top
	_player.set_active(false)
	_orbit.set_current(false)
	_set_mouse_captured(false)
