extends Control
## Main — root scene and screen manager.
##
## Owns the application theme, swaps between the six screens with a short
## cross-fade, keeps the 3D architecture world alive while other screens are
## open (so applied patterns survive navigation), and provides global
## conveniences (screenshot key, toast messages).
##
## Screens communicate by emitting `screen_requested(id)` and
## `toast_requested(text)`.

const SCREEN_PATHS := {
	"menu": "res://scenes/screens/main_menu.tscn",
	"world": "res://scenes/screens/world_screen.tscn",
	"lab": "res://scenes/screens/lab_screen.tscn",
	"studio": "res://scenes/screens/studio_screen.tscn",
	"learning": "res://scenes/screens/learning_screen.tscn",
	"settings": "res://scenes/screens/settings_screen.tscn",
}

const VERSION := "v1.0"

var _holder: Control
var _fade: ColorRect
var _toast_panel: PanelContainer
var _toast_label: Label
var _current_id := ""
var _current: Node = null
var _world_cache: Node = null
var _transitioning := false
var _toast_tween: Tween


func _ready() -> void:
	name = "Main"
	theme = NoorTheme.build()
	# The root must not swallow clicks: screens, the 3D world and the fade
	# overlay handle what they need themselves.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_holder = Control.new()
	_holder.name = "ScreenHolder"
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(NoorTheme.BG_DEEP.r, NoorTheme.BG_DEEP.g, NoorTheme.BG_DEEP.b, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fade)

	_build_toast()

	var start := "menu"
	if not DevCapture.requested_screen.is_empty():
		if SCREEN_PATHS.has(DevCapture.requested_screen):
			start = DevCapture.requested_screen
		else:
			push_warning("Main: unknown --screen=%s, opening menu" % DevCapture.requested_screen)
	open_screen(start, true)


# --- Screen management -------------------------------------------------------

func open_screen(id: String, immediate: bool = false) -> void:
	if _transitioning:
		return
	if id == _current_id and not immediate:
		return
	if not SCREEN_PATHS.has(id):
		push_warning("Main: unknown screen '%s'" % id)
		return
	_transitioning = true
	if immediate:
		_fade.color.a = 1.0
	else:
		await _fade_to(1.0, 0.16)
	_swap_screen(id)
	if immediate:
		_fade.color.a = 0.0
		_set_fade_blocking(false)
	else:
		await _fade_to(0.0, 0.2)
	_transitioning = false


func _swap_screen(id: String) -> void:
	if _current != null:
		if _current_id == "world":
			# keep the world alive so applied patterns and camera state persist
			if _current.has_method("on_hidden"):
				_current.call("on_hidden")
			_current.visible = false
			_current.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			_holder.remove_child(_current)
			_current.queue_free()
	_current = null

	if id == "world":
		if _world_cache == null:
			_world_cache = _instantiate(SCREEN_PATHS["world"])
			if _world_cache != null:
				_holder.add_child(_world_cache)
				_connect_screen(_world_cache)
		_current = _world_cache
		if _current != null:
			_current.visible = true
			_current.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		var screen := _instantiate(SCREEN_PATHS[id])
		if screen != null:
			_holder.add_child(screen)
			_connect_screen(screen)
		_current = screen

	_current_id = id
	if _current != null and _current.has_method("on_shown"):
		_current.call("on_shown")


func current_screen_id() -> String:
	return _current_id


func _instantiate(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_error("Main: missing screen scene %s" % path)
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	return scene.instantiate()


func _connect_screen(screen: Node) -> void:
	if screen.has_signal("screen_requested"):
		screen.connect("screen_requested", Callable(self, "open_screen"))
	if screen.has_signal("toast_requested"):
		screen.connect("toast_requested", Callable(self, "show_toast"))


func _fade_to(alpha: float, duration: float) -> void:
	# Block clicks while the fade is on screen, release them when it is clear,
	# otherwise the invisible overlay would swallow every UI click.
	_set_fade_blocking(true)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished
	_set_fade_blocking(alpha > 0.01)


func _set_fade_blocking(blocking: bool) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE


# --- Toast -------------------------------------------------------------------

func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "Toast"
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 1.0
	_toast_panel.anchor_bottom = 1.0
	_toast_panel.offset_left = -320
	_toast_panel.offset_right = 320
	_toast_panel.offset_top = -78
	_toast_panel.offset_bottom = -24
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_panel.add_child(_toast_label)
	add_child(_toast_panel)


func show_toast(text: String, seconds: float = 3.0) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func() -> void: _toast_panel.visible = false)


# --- Global input ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("noor_screenshot"):
		_save_screenshot()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _current_id != "world" and _current_id != "menu":
			open_screen("menu")
			get_viewport().set_input_as_handled()


func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var viewport := get_viewport()
	if viewport == null or viewport.get_texture() == null:
		return
	var img := viewport.get_texture().get_image()
	if img == null:
		show_toast("Screenshot failed (no rendered frame).")
		return
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://screenshots/noor_%s.png" % stamp
	var err := img.save_png(path)
	if err == OK:
		print("[NOOR] screenshot saved: %s" % ProjectSettings.globalize_path(path))
		show_toast("Screenshot saved to %s" % ProjectSettings.globalize_path(path))
	else:
		show_toast("Screenshot could not be saved (error %d)." % err)
