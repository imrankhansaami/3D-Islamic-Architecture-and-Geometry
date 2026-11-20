class_name NoorTheme
extends RefCounted
## Builds the whole application UI theme in code (no external theme asset).
##
## Visual identity: deep navy panels, emerald interactive elements, muted gold
## accents and warm ivory text — a restrained, elegant "heritage" look.
## Icons (slider grabbers, checkmarks, arrows) are generated procedurally as
## small images so the project stays self-contained.

const BG_DEEP := Color(0.043, 0.078, 0.114)       # #0B141D
const BG_PANEL := Color(0.067, 0.118, 0.169)      # #111E2B
const BG_PANEL_HI := Color(0.086, 0.157, 0.227)   # #16283A
const EMERALD := Color(0.078, 0.561, 0.427)       # #148F6D
const EMERALD_DARK := Color(0.059, 0.420, 0.322)  # #0F6B52
const GOLD := Color(0.788, 0.635, 0.153)          # #C9A227
const GOLD_LIGHT := Color(0.890, 0.773, 0.404)    # #E3C567
const IVORY := Color(0.949, 0.925, 0.863)         # #F2ECDC
const MUTED := Color(0.624, 0.690, 0.749)         # #9FB0BF
const SAND := Color(0.847, 0.765, 0.604)          # #D8C39A
const DANGER := Color(0.780, 0.310, 0.260)


static func gold_border(alpha: float = 0.28) -> Color:
	return Color(GOLD.r, GOLD.g, GOLD.b, alpha)


static func emerald_border(alpha: float = 0.35) -> Color:
	return Color(EMERALD.r, EMERALD.g, EMERALD.b, alpha)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 15

	_setup_boxes(theme)
	_setup_panels(theme)
	_setup_buttons(theme)
	_setup_labels(theme)
	_setup_sliders(theme)
	_setup_inputs(theme)
	_setup_misc(theme)
	return theme


# --- StyleBox helpers --------------------------------------------------------

static func panel_style(bg: Color, border: Color, radius: int = 8,
		margin: int = 14, border_width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


static func flat_style(bg: Color, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	return sb


# --- Theme sections ----------------------------------------------------------

static func _setup_boxes(theme: Theme) -> void:
	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("h_separation", "GridContainer", 10)
	theme.set_constant("v_separation", "GridContainer", 10)
	theme.set_constant("margin_left", "MarginContainer", 16)
	theme.set_constant("margin_right", "MarginContainer", 16)
	theme.set_constant("margin_top", "MarginContainer", 12)
	theme.set_constant("margin_bottom", "MarginContainer", 12)


static func _setup_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", panel_style(BG_PANEL, gold_border(0.22), 10, 16))
	var plain := panel_style(BG_DEEP, gold_border(0.12), 10, 14)
	theme.set_stylebox("panel", "Panel", plain)
	theme.set_stylebox("panel", "TooltipPanel", panel_style(BG_PANEL_HI, gold_border(0.35), 6, 10))
	theme.set_color("font_color", "TooltipLabel", IVORY)
	theme.set_font_size("font_size", "TooltipLabel", 13)
	var line := StyleBoxLine.new()
	line.color = gold_border(0.30)
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_stylebox("separator", "VSeparator", line)


static func _setup_buttons(theme: Theme) -> void:
	var normal := panel_style(BG_PANEL_HI, gold_border(0.30), 7, 12, 1)
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	var hover := panel_style(Color(EMERALD_DARK.r, EMERALD_DARK.g, EMERALD_DARK.b, 0.85), EMERALD, 7, 12, 1)
	hover.content_margin_top = 9
	hover.content_margin_bottom = 9
	var pressed := panel_style(EMERALD_DARK, GOLD, 7, 12, 1)
	pressed.content_margin_top = 9
	pressed.content_margin_bottom = 9
	var disabled := panel_style(Color(BG_PANEL_HI.r, BG_PANEL_HI.g, BG_PANEL_HI.b, 0.5),
		gold_border(0.12), 7, 12, 1)
	disabled.content_margin_top = 9
	disabled.content_margin_bottom = 9
	var focus := panel_style(Color(0, 0, 0, 0), GOLD_LIGHT, 7, 12, 1)

	for t: String in ["Button", "OptionButton", "CheckButton", "ColorPickerButton"]:
		theme.set_stylebox("normal", t, normal)
		theme.set_stylebox("hover", t, hover)
		theme.set_stylebox("pressed", t, pressed)
		theme.set_stylebox("disabled", t, disabled)
		theme.set_stylebox("focus", t, focus)
		theme.set_color("font_color", t, IVORY)
		theme.set_color("font_hover_color", t, GOLD_LIGHT)
		theme.set_color("font_pressed_color", t, IVORY)
		theme.set_color("font_disabled_color", t, Color(MUTED.r, MUTED.g, MUTED.b, 0.55))
		theme.set_color("font_focus_color", t, IVORY)
		theme.set_font_size("font_size", t, 15)
	theme.set_icon("arrow", "OptionButton", _arrow_icon(14, GOLD))
	theme.set_constant("arrow_margin", "OptionButton", 6)

	# Primary (call-to-action) button variation, used sparingly.
	theme.set_type_variation("PrimaryButton", "Button")
	var p_normal := panel_style(EMERALD_DARK, GOLD_LIGHT, 7, 12, 1)
	p_normal.content_margin_top = 10
	p_normal.content_margin_bottom = 10
	var p_hover := panel_style(EMERALD, GOLD_LIGHT, 7, 12, 1)
	p_hover.content_margin_top = 10
	p_hover.content_margin_bottom = 10
	var p_pressed := panel_style(Color(0.043, 0.298, 0.227), GOLD_LIGHT, 7, 12, 1)
	p_pressed.content_margin_top = 10
	p_pressed.content_margin_bottom = 10
	theme.set_stylebox("normal", "PrimaryButton", p_normal)
	theme.set_stylebox("hover", "PrimaryButton", p_hover)
	theme.set_stylebox("pressed", "PrimaryButton", p_pressed)
	theme.set_stylebox("disabled", "PrimaryButton", disabled)
	theme.set_stylebox("focus", "PrimaryButton", focus)
	theme.set_color("font_color", "PrimaryButton", IVORY)
	theme.set_color("font_hover_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_pressed_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_disabled_color", "PrimaryButton", Color(MUTED.r, MUTED.g, MUTED.b, 0.55))
	theme.set_color("font_focus_color", "PrimaryButton", IVORY)
	theme.set_font_size("font_size", "PrimaryButton", 15)

	# Danger variation for destructive actions.
	theme.set_type_variation("DangerButton", "Button")
	var d_normal := panel_style(Color(0.32, 0.13, 0.11), Color(DANGER.r, DANGER.g, DANGER.b, 0.6), 7, 12, 1)
	d_normal.content_margin_top = 9
	d_normal.content_margin_bottom = 9
	theme.set_stylebox("normal", "DangerButton", d_normal)
	theme.set_color("font_color", "DangerButton", Color(0.95, 0.82, 0.78))
	theme.set_font_size("font_size", "DangerButton", 15)

	# Small square icon button variation for toolbars.
	theme.set_type_variation("ToolButton", "Button")
	var t_normal := panel_style(Color(BG_PANEL_HI.r, BG_PANEL_HI.g, BG_PANEL_HI.b, 0.8), gold_border(0.25), 6, 8)
	t_normal.content_margin_top = 6
	t_normal.content_margin_bottom = 6
	t_normal.content_margin_left = 10
	t_normal.content_margin_right = 10
	theme.set_stylebox("normal", "ToolButton", t_normal)
	theme.set_stylebox("hover", "ToolButton", hover)
	theme.set_stylebox("pressed", "ToolButton", pressed)
	theme.set_stylebox("focus", "ToolButton", focus)
	theme.set_color("font_color", "ToolButton", IVORY)
	theme.set_font_size("font_size", "ToolButton", 13)

	# Sidebar navigation button variation (learning topics, presets).
	theme.set_type_variation("NavButton", "Button")
	var n_normal := panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 10)
	var n_hover := panel_style(Color(BG_PANEL_HI.r, BG_PANEL_HI.g, BG_PANEL_HI.b, 0.7), Color(0, 0, 0, 0), 6, 10)
	var n_pressed := panel_style(Color(EMERALD_DARK.r, EMERALD_DARK.g, EMERALD_DARK.b, 0.55), GOLD, 6, 10, 1)
	theme.set_stylebox("normal", "NavButton", n_normal)
	theme.set_stylebox("hover", "NavButton", n_hover)
	theme.set_stylebox("pressed", "NavButton", n_pressed)
	theme.set_stylebox("focus", "NavButton", n_hover)
	theme.set_stylebox("disabled", "NavButton", n_normal)
	theme.set_color("font_color", "NavButton", IVORY)
	theme.set_color("font_hover_color", "NavButton", GOLD_LIGHT)
	theme.set_font_size("font_size", "NavButton", 14)


static func _setup_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", IVORY)
	theme.set_font_size("font_size", "Label", 15)


static func _setup_sliders(theme: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.05, 0.08, 0.9)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.border_color = gold_border(0.15)
	track.set_border_width_all(1)
	var filled := StyleBoxFlat.new()
	filled.bg_color = EMERALD
	filled.set_corner_radius_all(3)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	for t: String in ["HSlider", "VSlider"]:
		theme.set_stylebox("slider", t, track)
		theme.set_stylebox("grabber_area", t, filled)
		theme.set_stylebox("grabber_area_highlight", t, filled)
		theme.set_icon("grabber", t, _circle_icon(16, GOLD, GOLD_LIGHT))
		theme.set_icon("grabber_highlight", t, _circle_icon(18, GOLD_LIGHT, Color.WHITE))
		theme.set_icon("grabber_disabled", t, _circle_icon(16, Color(0.4, 0.4, 0.4), Color(0.5, 0.5, 0.5)))


static func _setup_inputs(theme: Theme) -> void:
	var normal := panel_style(Color(0.02, 0.05, 0.08, 0.85), gold_border(0.25), 6, 8)
	var focus := panel_style(Color(0.02, 0.05, 0.08, 0.95), GOLD, 6, 8)
	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_stylebox("read_only", "LineEdit", panel_style(Color(0, 0, 0, 0.3), gold_border(0.1), 6, 8))
	theme.set_color("font_color", "LineEdit", IVORY)
	theme.set_color("font_placeholder_color", "LineEdit", Color(MUTED.r, MUTED.g, MUTED.b, 0.6))
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", emerald_border(0.4))
	theme.set_font_size("font_size", "LineEdit", 14)


static func _setup_misc(theme: Theme) -> void:
	for t: String in ["VScrollBar", "HScrollBar"]:
		var scroll := StyleBoxFlat.new()
		scroll.bg_color = Color(0.02, 0.05, 0.08, 0.6)
		scroll.set_corner_radius_all(4)
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
		grabber.set_corner_radius_all(4)
		var grabber_hi := StyleBoxFlat.new()
		grabber_hi.bg_color = Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.75)
		grabber_hi.set_corner_radius_all(4)
		theme.set_stylebox("scroll", t, scroll)
		theme.set_stylebox("scroll_focus", t, scroll)
		theme.set_stylebox("grabber", t, grabber)
		theme.set_stylebox("grabber_highlight", t, grabber_hi)
		theme.set_stylebox("grabber_pressed", t, grabber_hi)
	# CheckButton icons
	for t: String in ["CheckButton", "CheckBox"]:
		theme.set_icon("checked", t, _check_icon(20, true))
		theme.set_icon("unchecked", t, _check_icon(20, false))
		theme.set_icon("checked_disabled", t, _check_icon(20, true, true))
		theme.set_icon("unchecked_disabled", t, _check_icon(20, false, true))
	theme.set_color("font_color", "CheckButton", IVORY)
	theme.set_color("font_hover_color", "CheckButton", GOLD_LIGHT)


# --- Procedurally generated icons -------------------------------------------

static func _make_image(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _circle_icon(size: int, fill: Color, border: Color) -> ImageTexture:
	var img := _make_image(size)
	var centre := size * 0.5
	var r := centre - 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5 - centre, float(y) + 0.5 - centre).length()
			if d <= r - 1.5:
				img.set_pixel(x, y, fill)
			elif d <= r:
				img.set_pixel(x, y, border)
	return ImageTexture.create_from_image(img)


static func _arrow_icon(size: int, color: Color) -> ImageTexture:
	var img := _make_image(size)
	var w := float(size)
	# Downward triangle
	for y in size:
		var t := float(y) / w
		var half := (0.5 - t * 0.4) * w
		for x in size:
			var dx := absf(float(x) + 0.5 - w * 0.5)
			if dx <= half and t > 0.2 and t < 0.8:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func _check_icon(size: int, checked: bool, disabled: bool = false) -> ImageTexture:
	var img := _make_image(size)
	var half := size * 0.5 - 1.5
	var radius := 4.0
	var bg := BG_PANEL_HI if not checked else EMERALD_DARK
	var border := gold_border(0.35) if not checked else GOLD
	if disabled:
		bg = Color(bg.r, bg.g, bg.b, 0.4)
		border = Color(border.r, border.g, border.b, 0.4)
	var centre := size * 0.5
	for y in size:
		for x in size:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - Vector2(centre, centre)
			var q := Vector2(absf(p.x), absf(p.y)) - Vector2(half - radius, half - radius)
			var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			if outside <= -1.6:
				img.set_pixel(x, y, bg)
			elif outside <= 0.2:
				img.set_pixel(x, y, border)
	if checked:
		var check_color := GOLD_LIGHT if not disabled else Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.4)
		var a := Vector2(size * 0.26, size * 0.54)
		var b := Vector2(size * 0.44, size * 0.72)
		var c := Vector2(size * 0.76, size * 0.30)
		for y in size:
			for x in size:
				var p := Vector2(float(x) + 0.5, float(y) + 0.5)
				if _dist_to_segment(p, a, b) <= 2.0 or _dist_to_segment(p, b, c) <= 2.0:
					img.set_pixel(x, y, check_color)
	return ImageTexture.create_from_image(img)


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 1e-9:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
