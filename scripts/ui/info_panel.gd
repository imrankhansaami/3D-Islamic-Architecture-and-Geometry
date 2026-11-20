class_name InfoPanel
extends PanelContainer
## Contextual information panel for a selected architectural object.
##
## Shows the object's name, description, geometric construction, the
## mathematics behind it, a live preview of any linked pattern, and offers
## to focus the camera or open the pattern in the laboratory.

signal closed
signal focus_requested(point: Vector3, radius: float)
signal edit_pattern_requested(panel_id: String)

var _title: Label
var _body: RichTextLabel
var _preview_holder: PanelContainer
var _preview: PatternViewport = null
var _focus_button: Button
var _edit_button: Button
var _pattern_id := ""
var _focus_point := Vector3.ZERO
var _focus_radius := 5.0


func _ready() -> void:
	custom_minimum_size = Vector2(360, 0)
	visible = false
	_build()


func _build() -> void:
	var frame := MarginContainer.new()
	frame.add_theme_constant_override("margin_left", 14)
	frame.add_theme_constant_override("margin_right", 14)
	frame.add_theme_constant_override("margin_top", 12)
	frame.add_theme_constant_override("margin_bottom", 12)
	add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	frame.add_child(column)

	var header := HBoxContainer.new()
	_title = UIHelpers.label("", 19, NoorTheme.GOLD_LIGHT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := UIHelpers.button("×", false, "Close (Esc)")
	close.theme_type_variation = &"ToolButton"
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)
	column.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 14)
	_body.add_theme_font_size_override("bold_font_size", 14)
	_body.add_theme_color_override("default_color", NoorTheme.IVORY)
	content.add_child(_body)

	_preview_holder = PanelContainer.new()
	_preview_holder.visible = false
	_preview_holder.custom_minimum_size = Vector2(0, 210)
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 2)
	preview_margin.add_theme_constant_override("margin_right", 2)
	preview_margin.add_theme_constant_override("margin_top", 2)
	preview_margin.add_theme_constant_override("margin_bottom", 2)
	_preview_holder.add_child(preview_margin)
	content.add_child(_preview_holder)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	_focus_button = UIHelpers.button("Focus", true, "Move the orbit camera to this object.")
	_focus_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_focus_button.pressed.connect(func() -> void: focus_requested.emit(_focus_point, _focus_radius))
	buttons.add_child(_focus_button)
	_edit_button = UIHelpers.button("Edit Pattern", false, "Open this object's pattern in the Geometry Laboratory.")
	_edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_button.pressed.connect(func() -> void: edit_pattern_requested.emit(_pattern_id))
	buttons.add_child(_edit_button)
	column.add_child(buttons)


func show_info(info: Dictionary, focus_point: Vector3, focus_radius: float) -> void:
	_title.text = String(info.get("name", "Object"))
	_focus_point = focus_point
	_focus_radius = focus_radius
	var text := "[color=#%s]%s[/color]\n\n" % [NoorTheme.SAND.to_html(false), String(info.get("description", ""))]
	var construction := String(info.get("construction", ""))
	if not construction.is_empty():
		text += "[b][color=#%s]Construction[/color][/b]\n%s\n\n" % [NoorTheme.GOLD_LIGHT.to_html(false), construction]
	var math := String(info.get("math", ""))
	if not math.is_empty():
		text += "[b][color=#%s]Mathematics[/color][/b]\n[color=#%s]%s[/color]" % [
			NoorTheme.GOLD_LIGHT.to_html(false), NoorTheme.SAND.to_html(false), math]
	_body.text = text

	_pattern_id = String(info.get("pattern_id", ""))
	_edit_button.visible = not _pattern_id.is_empty()
	_update_preview()
	visible = true


func _update_preview() -> void:
	if _pattern_id.is_empty():
		_preview_holder.visible = false
		return
	var config: PatternConfig = PatternLibrary.get_panel_config(_pattern_id)
	if config == null:
		_preview_holder.visible = false
		return
	if _preview == null:
		_preview = preload("res://scenes/geometry/pattern_viewport.tscn").instantiate()
		var parent := _preview_holder.get_child(0) as Control
		_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(_preview)
		_preview.set_environment_preset("studio")
		_preview.set_autorotate(true, 0.4, "sway")
	_preview.clear_model()
	var geo := PatternEngine.generate(config)
	var layers := MeshBuilder.build_pattern_layers(geo, config)
	var colors := [config.color_fill, config.color_accent, config.color_line]
	var roles := ["fill", "accent", "line"]
	for i in layers.size():
		var mesh: ArrayMesh = layers[i]
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = MaterialLibrary.pattern_material(colors[i], roles[i])
		_preview.add_model_node(mi)
	_preview.set_backdrop_radius(config.outer_radius * 1.3)
	_preview.frame_content(1.3)
	_preview_holder.visible = true


## Called by the world screen when the linked panel's pattern changes.
func refresh_preview() -> void:
	if visible and not _pattern_id.is_empty():
		_update_preview()
