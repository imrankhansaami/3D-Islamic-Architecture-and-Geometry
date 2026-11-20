extends Control
## Settings — graphics quality, time-of-day lighting, controls, about.
##
## Every control here has an immediate effect: graphics options apply to the
## world and all preview viewports, the lighting preset re-lights the
## architecture explorer at once, and control preferences are read live by
## both camera controllers.

signal screen_requested(id: String)
signal toast_requested(text: String)

const TIME_DESCRIPTIONS: PackedStringArray = [
	"Low warm sun from the east, soft shadows — first light over the courtyard.",
	"Clear morning light, crisp shadows falling to the west.",
	"High white sun directly overhead, shortest shadows of the day.",
	"Warm afternoon light raking across the arcades.",
	"Deep orange sun near the horizon, long shadows, lanterns begin to glow.",
	"Moonlight and emerald sky; courtyard lanterns carry the scene.",
]

var _sun_swatch: ColorRect
var _time_info: Label


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := OrnamentalBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.line_color = Color(0.788, 0.635, 0.153, 0.05)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)

	var header := HBoxContainer.new()
	var title := UIHelpers.title("Settings")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := UIHelpers.button("Back to Menu", true, "Return to the main menu.")
	back.pressed.connect(func() -> void: screen_requested.emit("menu"))
	header.add_child(back)
	column.add_child(header)

	# --- Graphics -------------------------------------------------------------
	column.add_child(UIHelpers.section("Graphics Quality"))
	var graphics := HBoxContainer.new()
	graphics.add_theme_constant_override("separation", 18)
	column.add_child(graphics)

	var g_left := VBoxContainer.new()
	g_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics.add_child(g_left)
	g_left.add_child(_quality_check("Shadows", "shadows", "Directional shadows from the sun and key lights."))
	g_left.add_child(_quality_check("Ambient Occlusion", "ssao",
		"Screen-space ambient occlusion darkens creases between surfaces."))
	g_left.add_child(_quality_check("Glow / Bloom", "glow",
		"Soft bloom around bright highlights (lanterns at night)."))

	var g_right := VBoxContainer.new()
	g_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics.add_child(g_right)
	g_right.add_child(_quality_check("Screen-space Reflections", "reflections",
		"Reflections on polished surfaces (Forward+ renderer)."))
	var msaa_row := UIHelpers.dropdown_row("Anti-aliasing (MSAA)", AppState.MSAA_NAMES,
		AppState.quality_int("msaa"), "Multisample anti-aliasing for 3D edges.")
	var msaa_option: OptionButton = msaa_row["option"]
	msaa_option.item_selected.connect(func(i: int) -> void:
		AppState.set_quality("msaa", i)
		toast_requested.emit("Anti-aliasing set to %s." % AppState.MSAA_NAMES[i]))
	g_right.add_child(msaa_row["row"])
	var vsync_row := UIHelpers.check_row("VSync", DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED,
		"Vertical synchronisation (reduces tearing, caps the frame rate).")
	vsync_row["check"].toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))
	g_right.add_child(vsync_row["row"])

	var info := UIHelpers.muted("Rendering device: %s  ·  Godot %s  ·  renderer: %s" % [
		RenderingServer.get_video_adapter_name(),
		Engine.get_version_info()["string"],
		RenderingServer.get_current_rendering_method()], 12)
	column.add_child(info)

	# --- Lighting -------------------------------------------------------------
	column.add_child(UIHelpers.section("Time-of-Day Lighting"))
	var light_row := HBoxContainer.new()
	light_row.add_theme_constant_override("separation", 18)
	column.add_child(light_row)
	var time_box := VBoxContainer.new()
	time_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	light_row.add_child(time_box)
	var time_dropdown := UIHelpers.dropdown_row("Preset", AppState.TIME_PRESET_NAMES, AppState.time_of_day,
		"Re-lights the Architecture Explorer immediately.")
	var time_option: OptionButton = time_dropdown["option"]
	time_option.item_selected.connect(func(i: int) -> void:
		AppState.set_time_of_day(i)
		_update_time_info())
	time_box.add_child(time_dropdown["row"])
	_time_info = UIHelpers.wrapped("", 13, NoorTheme.MUTED)
	time_box.add_child(_time_info)

	var swatch_box := VBoxContainer.new()
	swatch_box.add_child(UIHelpers.label("Sun colour", 13, NoorTheme.MUTED))
	_sun_swatch = ColorRect.new()
	_sun_swatch.custom_minimum_size = Vector2(90, 34)
	_sun_swatch.color = Color(1, 0.9, 0.75)
	swatch_box.add_child(_sun_swatch)
	light_row.add_child(swatch_box)
	_update_time_info()
	AppState.lighting_preset_changed.connect(func(_p: int) -> void: _update_time_info())

	# --- Controls -------------------------------------------------------------
	column.add_child(UIHelpers.section("Controls — First Person"))
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 18)
	column.add_child(controls)
	var c_left := VBoxContainer.new()
	c_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(c_left)
	c_left.add_child(_control_slider("Walk speed", 1.5, 9.0, 0.1, AppState.fp_walk_speed,
		func(v: float) -> void: AppState.fp_walk_speed = v, "units/s"))
	c_left.add_child(_control_slider("Run multiplier", 1.2, 3.0, 0.05, AppState.fp_run_multiplier,
		func(v: float) -> void: AppState.fp_run_multiplier = v, "×"))
	c_left.add_child(_control_slider("Jump velocity", 2.5, 8.0, 0.1, AppState.fp_jump_velocity,
		func(v: float) -> void: AppState.fp_jump_velocity = v, "units/s"))
	var c_right := VBoxContainer.new()
	c_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(c_right)
	c_right.add_child(_control_slider("Mouse sensitivity", 0.0008, 0.008, 0.0002, AppState.fp_mouse_sensitivity,
		func(v: float) -> void: AppState.fp_mouse_sensitivity = v, "", 4))
	var invert_row := UIHelpers.check_row("Invert vertical look", AppState.fp_invert_y, "")
	invert_row["check"].toggled.connect(func(on: bool) -> void:
		AppState.fp_invert_y = on
		AppState.notify_controls_changed())
	c_right.add_child(invert_row["row"])
	c_right.add_child(_control_slider("Orbit sensitivity", 0.001, 0.012, 0.0005, AppState.orbit_sensitivity,
		func(v: float) -> void: AppState.orbit_sensitivity = v, "", 4))

	# --- About ----------------------------------------------------------------
	column.add_child(UIHelpers.section("About"))
	column.add_child(UIHelpers.wrapped(
		"NOOR — Procedural Islamic Geometry & Heritage Architecture\n"
		+ "CSE 400 final-year computer graphics project · Sylhet International University\n\n"
		+ "Every pattern and architectural element in this application is generated at runtime by the project's own geometry engine — no pre-made 3D models are used. "
		+ "The geometry, mesh generation, materials, lighting, cameras and UI all live in this Godot project's scripts.", 13, NoorTheme.MUTED))
	var defaults := UIHelpers.button("Restore Defaults", false,
		"Restore all graphics and control options to their initial values.")
	defaults.pressed.connect(func() -> void:
		AppState.restore_quality_defaults()
		AppState.restore_control_defaults()
		AppState.set_time_of_day(AppState.TimeOfDay.AFTERNOON)
		toast_requested.emit("Settings restored to defaults.")
		_build_ui_refresh())
	column.add_child(defaults)


func _quality_check(label_text: String, key: String, tooltip: String) -> Control:
	var row := UIHelpers.check_row(label_text, AppState.quality_bool(key), tooltip)
	row["check"].toggled.connect(func(on: bool) -> void:
		AppState.set_quality(key, on)
		toast_requested.emit("%s %s." % [label_text, "enabled" if on else "disabled"]))
	return row["row"]


func _control_slider(label_text: String, min_v: float, max_v: float, step: float,
		value: float, setter: Callable, suffix: String = "", decimals: int = 2) -> Control:
	var row := UIHelpers.slider_row(label_text, min_v, max_v, step, value, "", decimals, suffix)
	var slider: HSlider = row["slider"]
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		AppState.notify_controls_changed())
	return row["row"]


func _update_time_info() -> void:
	var index := clampi(AppState.time_of_day, 0, TIME_DESCRIPTIONS.size() - 1)
	if _time_info != null:
		_time_info.text = TIME_DESCRIPTIONS[index]
	if _sun_swatch != null:
		_sun_swatch.color = _sun_colour(index)


func _sun_colour(index: int) -> Color:
	match index:
		0: return Color(1.0, 0.72, 0.52)     # dawn
		1: return Color(1.0, 0.92, 0.78)     # morning
		2: return Color(1.0, 0.98, 0.92)     # noon
		3: return Color(1.0, 0.88, 0.66)     # afternoon
		4: return Color(1.0, 0.62, 0.34)     # dusk
		_: return Color(0.62, 0.72, 0.95)    # moonlight
	return Color.WHITE


func _build_ui_refresh() -> void:
	for child in get_children():
		child.queue_free()
	call_deferred("_build_ui")


func on_shown() -> void:
	_update_time_info()
