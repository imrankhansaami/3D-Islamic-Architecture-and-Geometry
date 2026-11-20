class_name UIHelpers
extends RefCounted
## Factory helpers for the application's control panels.
##
## Every screen builds its panels from these helpers so spacing, typography and
## behaviour stay consistent (and there is exactly one place to adjust them).


static func label(text: String, size: int = 15, color: Color = NoorTheme.IVORY) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func title(text: String) -> Label:
	var node := label(text, 26, NoorTheme.GOLD_LIGHT)
	return node


static func heading(text: String) -> Label:
	var node := label(text.to_upper(), 12, NoorTheme.GOLD)
	node.add_theme_constant_override("line_spacing", 1)
	return node


static func muted(text: String, size: int = 13) -> Label:
	return label(text, size, NoorTheme.MUTED)


static func wrapped(text: String, size: int = 14, color: Color = NoorTheme.IVORY) -> Label:
	var node := label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## Small monospaced-feeling formula block.
static func formula(text: String) -> Label:
	var node := label(text, 13, NoorTheme.SAND)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func section(text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := heading(text)
	box.add_child(head)
	var line := HSeparator.new()
	box.add_child(line)
	return box


static func spacer(height: float = 8.0) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	return node


static func button(text: String, primary: bool = false, tooltip: String = "") -> Button:
	var node := Button.new()
	node.text = text
	if primary:
		node.theme_type_variation = &"PrimaryButton"
	if not tooltip.is_empty():
		node.tooltip_text = tooltip
	return node


## Slider row with a live numeric readout, e.g. "Rotation   45.0°".
## Returns {"row": Control, "slider": HSlider, "value_label": Label}.
static func slider_row(label_text: String, min_value: float, max_value: float,
		step: float, value: float, tooltip: String = "",
		decimals: int = 1, suffix: String = "") -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	var name_label := label(label_text, 13, NoorTheme.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var value_label := label(_format_value(value, decimals, suffix), 13, NoorTheme.GOLD_LIGHT)
	head.add_child(value_label)
	box.add_child(head)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 18)
	if not tooltip.is_empty():
		slider.tooltip_text = tooltip
		name_label.tooltip_text = tooltip
	box.add_child(slider)
	box.set_meta("decimals", decimals)
	box.set_meta("suffix", suffix)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = _format_value(v, decimals, suffix))

	return {"row": box, "slider": slider, "value_label": value_label}


static func _format_value(value: float, decimals: int, suffix: String) -> String:
	var text := ("%." + str(decimals) + "f") % value
	if decimals <= 0:
		text = str(roundi(value))
	return text + suffix


## Dropdown row. Returns {"row": Control, "option": OptionButton}.
static func dropdown_row(label_text: String, items: PackedStringArray,
		selected: int, tooltip: String = "") -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	if not label_text.is_empty():
		var name_label := label(label_text, 13, NoorTheme.MUTED)
		if not tooltip.is_empty():
			name_label.tooltip_text = tooltip
		box.add_child(name_label)
	var option := OptionButton.new()
	for i in items.size():
		option.add_item(items[i], i)
	option.selected = clampi(selected, 0, maxi(items.size() - 1, 0))
	if not tooltip.is_empty():
		option.tooltip_text = tooltip
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(option)
	return {"row": box, "option": option}


## Check row. Returns {"row": Control, "check": CheckButton}.
static func check_row(label_text: String, pressed: bool, tooltip: String = "") -> Dictionary:
	var check := CheckButton.new()
	check.text = label_text
	check.button_pressed = pressed
	if not tooltip.is_empty():
		check.tooltip_text = tooltip
	return {"row": check, "check": check}


## Colour picker row. Returns {"row": Control, "picker": ColorPickerButton}.
static func color_row(label_text: String, color: Color, tooltip: String = "") -> Dictionary:
	var box := HBoxContainer.new()
	var name_label := label(label_text, 13, NoorTheme.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		name_label.tooltip_text = tooltip
	box.add_child(name_label)
	var picker := ColorPickerButton.new()
	picker.color = color
	picker.custom_minimum_size = Vector2(74, 26)
	picker.edit_alpha = false
	if not tooltip.is_empty():
		picker.tooltip_text = tooltip
	box.add_child(picker)
	return {"row": box, "picker": picker}


## Scrolling container that fills its parent, wrapping [param content].
static func scroll_wrap(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if content.get_parent() != null:
		content.get_parent().remove_child(content)
	scroll.add_child(content)
	return scroll


## Panel with a vertical stack inside; returns {"panel": PanelContainer, "vbox": VBoxContainer}.
static func panel_stack(min_width: float = 0.0) -> Dictionary:
	var panel := PanelContainer.new()
	if min_width > 0.0:
		panel.custom_minimum_size = Vector2(min_width, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	return {"panel": panel, "vbox": vbox}
