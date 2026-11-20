extends Node
## DevCapture — developer helper for automated testing and screenshots
## (autoload singleton).
##
## Recognised command line arguments (pass them after "--"):
##   --selftest                 run the geometry/self tests, print a report, quit
##   --screen=lab               open a screen directly (menu/world/lab/studio/learning/settings)
##   --capture=C:/path/shot.png save one screenshot after N frames, then quit
##   --capture-after=90         frames to wait before the capture (default 90)
##   --cam=dome                 world camera preset for the capture
##
## Examples:
##   godot --headless -- --selftest
##   godot -- --screen=world --cam=overview --capture=C:/tmp/noor_world.png

var requested_screen: String = ""
var capture_path: String = ""
var capture_after: int = 90
var cam_preset: String = ""
var time_preset: int = -1
var dev_mode: String = ""
var dev_select: String = ""
var dev_lab_export: bool = false
var dev_ui_test: bool = false
var selftest: bool = false
var flat_export_dir: String = ""

var _frames: int = 0
var _capture_started: bool = false
var _selftest_started: bool = false
var _flat_export_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			requested_screen = arg.trim_prefix("--screen=")
		elif arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-after="):
			capture_after = maxi(1, int(arg.trim_prefix("--capture-after=")))
		elif arg.begins_with("--cam="):
			cam_preset = arg.trim_prefix("--cam=")
		elif arg.begins_with("--time="):
			time_preset = int(arg.trim_prefix("--time="))
		elif arg.begins_with("--dev-mode="):
			dev_mode = arg.trim_prefix("--dev-mode=")
		elif arg.begins_with("--dev-select="):
			dev_select = arg.trim_prefix("--dev-select=")
		elif arg == "--dev-lab-export":
			dev_lab_export = true
		elif arg == "--dev-uitest":
			dev_ui_test = true
		elif arg.begins_with("--flat-export="):
			flat_export_dir = arg.trim_prefix("--flat-export=")
		elif arg == "--selftest":
			selftest = true
	if time_preset >= 0:
		AppState.time_of_day = clampi(time_preset, 0, AppState.TIME_PRESET_NAMES.size() - 1)


func _process(_delta: float) -> void:
	_frames += 1

	if selftest and not _selftest_started:
		_selftest_started = true
		_run_selftest()
		return

	if not flat_export_dir.is_empty() and not _flat_export_started and _frames > 3:
		_flat_export_started = true
		_run_flat_exports()
		return

	if dev_lab_export and _frames == 90:
		_run_lab_export()
		return

	if dev_ui_test and _frames == 40:
		_run_ui_test()
		return

	if capture_path.is_empty() or _capture_started:
		return
	if _frames >= capture_after:
		_capture_started = true
		_do_capture()


## Developer tool: drives the real UI with synthesized mouse clicks and key
## presses to prove that every screen is reachable and every panel responds.
## Usage:  godot --path . -- --dev-uitest
func _run_ui_test() -> void:
	print("[DevCapture] ============ UI CLICK TEST ============")
	var main := get_tree().current_scene
	var failures := 0
	var checks := 0

	await _wait(0.6)
	if _screen_id(main) != "menu":
		failures += 1
		print("[ui] FAIL: expected to start on the menu, got '%s'" % _screen_id(main))
	else:
		print("[ui] ok: started on the menu")

	var plan: Array = [
		["Explore Architecture", "world"],
		["Geometry Laboratory", "lab"],
		["3D Transformation Studio", "studio"],
		["Mathematics & Learning", "learning"],
		["Settings", "settings"],
	]
	for entry: Array in plan:
		var label: String = entry[0]
		var expected_screen: String = entry[1]
		checks += 1
		if not await _click_button(main, label):
			failures += 1
			continue
		await _wait(0.9)
		if _screen_id(main) != expected_screen:
			failures += 1
			print("[ui] FAIL: '%s' did not open the %s screen (now '%s')" % [label, expected_screen, _screen_id(main)])
		else:
			print("[ui] ok: '%s' opened the %s screen" % [label, expected_screen])

		# navigate back: the world screen uses its Menu button (Escape is
		# reserved for closing panels there); every other screen takes Escape
		if expected_screen == "world":
			await _click_button(main, "Menu")
		else:
			await _press_escape_key()
		await _wait(0.9)
		checks += 1
		if _screen_id(main) != "menu":
			failures += 1
			print("[ui] FAIL: could not return to the menu from %s (now '%s')" % [expected_screen, _screen_id(main)])
		else:
			print("[ui] ok: returned to the menu from %s" % expected_screen)

	var deep_failures := await _run_deep_ui_test(main)
	failures += deep_failures
	checks += 8
	print("[DevCapture] UI CLICK TEST: %d checks, %d failure(s)" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## Deeper flows: world panel open/close, camera toggle, lab <-> studio loop.
## Returns the number of failures.
func _run_deep_ui_test(main: Node) -> int:
	var failures := 0

	# --- world: click the centre of the view to open an information panel ---
	await _click_button(main, "Explore Architecture")
	await _wait(1.0)
	await _click_screen_centre()
	await _wait(0.5)
	if not _info_panel_visible(main):
		failures += 1
		print("[ui] FAIL: clicking the world did not open an information panel")
	else:
		print("[ui] ok: clicking an object opened its information panel")
	# close it again
	await _press_escape_key()
	await _wait(0.4)
	if _info_panel_visible(main):
		failures += 1
		print("[ui] FAIL: Escape did not close the information panel")
	else:
		print("[ui] ok: Escape closed the information panel")

	# --- world: camera toggle (C) must switch to first person and back ---
	await _press_key(KEY_C)
	await _wait(0.4)
	var fp_on := _camera_mode_is_first_person(main)
	await _press_key(KEY_C)
	await _wait(0.4)
	var fp_off := not _camera_mode_is_first_person(main)
	if fp_on and fp_off:
		print("[ui] ok: C toggles first person and back")
	else:
		failures += 1
		print("[ui] FAIL: camera toggle (first=%s, back=%s)" % [str(fp_on), str(fp_off)])

	# --- world: dragging with the left button must orbit the camera ---
	var world := _find_screen(main, "dev_debug_state")
	if world != null:
		var before: Dictionary = world.call("dev_debug_state")
		await _drag_mouse(Vector2(640, 360), Vector2(240, 120))
		await _wait(0.3)
		var after: Dictionary = world.call("dev_debug_state")
		if absf(float(after["yaw"]) - float(before["yaw"])) > 0.01 \
				or absf(float(after["pitch"]) - float(before["pitch"])) > 0.01:
			print("[ui] ok: dragging orbits the camera (yaw %.2f -> %.2f)" % [
				float(before["yaw"]), float(after["yaw"])])
		else:
			failures += 1
			print("[ui] FAIL: dragging did not orbit the camera")
		# wheel must zoom
		before = world.call("dev_debug_state")
		await _scroll_mouse(Vector2(640, 360), -3)
		await _wait(0.3)
		after = world.call("dev_debug_state")
		if absf(float(after["distance"]) - float(before["distance"])) > 0.05:
			print("[ui] ok: mouse wheel zooms (%.1f -> %.1f)" % [
				float(before["distance"]), float(after["distance"])])
		else:
			failures += 1
			print("[ui] FAIL: mouse wheel did not zoom")
	else:
		failures += 1
		print("[ui] FAIL: world screen debug state not reachable")

	# --- back to menu, then lab -> studio -> lab -> menu ---
	await _click_button(main, "Menu")
	await _wait(0.9)
	await _click_button(main, "Geometry Laboratory")
	await _wait(1.0)
	if await _click_button(main, "Send to 3D Studio"):
		await _wait(1.0)
		if _screen_id(main) != "studio":
			failures += 1
			print("[ui] FAIL: 'Send to 3D Studio' did not open the studio")
		else:
			print("[ui] ok: 'Send to 3D Studio' opened the studio")
		if await _click_button(main, "Open Geometry Laboratory"):
			await _wait(1.0)
			if _screen_id(main) != "lab":
				failures += 1
				print("[ui] FAIL: studio -> laboratory navigation")
			else:
				print("[ui] ok: studio -> laboratory navigation")
	await _press_escape_key()
	await _wait(0.9)
	if _screen_id(main) != "menu":
		failures += 1
		print("[ui] FAIL: final return to the menu failed ('%s')" % _screen_id(main))
	else:
		print("[ui] ok: returned to the menu after the deep flow")

	return failures


func _click_screen_centre() -> void:
	var viewport_size := get_tree().root.get_visible_rect().size
	var centre := viewport_size * 0.5
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = centre
	down.global_position = centre
	get_tree().root.push_input(down)
	await _wait(0.06)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = centre
	up.global_position = centre
	get_tree().root.push_input(up)
	await _wait(0.1)


## Synthesizes a left-button drag from `from` to `to`.
func _drag_mouse(from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	down.global_position = from
	get_tree().root.push_input(down)
	await _wait(0.06)
	var steps := 6
	for i in steps:
		var t := float(i + 1) / float(steps)
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, t)
		motion.global_position = motion.position
		motion.relative = (to - from) / float(steps)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_tree().root.push_input(motion)
		await _wait(0.03)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	up.global_position = to
	get_tree().root.push_input(up)
	await _wait(0.1)


## Synthesizes mouse-wheel notches (negative = scroll down / zoom out).
func _scroll_mouse(at: Vector2, notches: int) -> void:
	for i in absi(notches):
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if notches < 0 else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = at
		wheel.global_position = at
		get_tree().root.push_input(wheel)
		await _wait(0.05)


func _press_key(keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	get_tree().root.push_input(down)
	await _wait(0.06)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	get_tree().root.push_input(up)
	await _wait(0.1)


func _info_panel_visible(main: Node) -> bool:
	var panel := _find_screen(main, "show_info")
	return panel != null and panel.visible


func _camera_mode_is_first_person(main: Node) -> bool:
	var button := _find_button(main, "Camera: First Person  (C)")
	return button != null


## Clicks the centre of the first visible Button with the given text.
func _click_button(root: Node, text: String) -> bool:
	var button := _find_button(root, text)
	if button == null:
		print("[ui] FAIL: button '%s' not found" % text)
		return false
	# scroll the button into view if it lives in a scrolling panel
	var scroll := _find_scroll_parent(button)
	if scroll != null:
		scroll.ensure_control_visible(button)
		await _wait(0.25)
	var centre := button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = centre
	down.global_position = centre
	get_tree().root.push_input(down)
	await _wait(0.08)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = centre
	up.global_position = centre
	get_tree().root.push_input(up)
	await _wait(0.12)
	return true


func _press_escape_key() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_ESCAPE
	down.physical_keycode = KEY_ESCAPE
	down.pressed = true
	get_tree().root.push_input(down)
	await _wait(0.08)
	var up := InputEventKey.new()
	up.keycode = KEY_ESCAPE
	up.physical_keycode = KEY_ESCAPE
	up.pressed = false
	get_tree().root.push_input(up)
	await _wait(0.12)


func _find_button(node: Node, text: String) -> Button:
	if node is Button:
		var button := node as Button
		if button.text == text and button.is_visible_in_tree() and not button.disabled:
			return button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _find_scroll_parent(node: Node) -> ScrollContainer:
	var current := node.get_parent()
	while current != null:
		if current is ScrollContainer:
			return current as ScrollContainer
		current = current.get_parent()
	return null


func _screen_id(main: Node) -> String:
	if main != null and main.has_method("current_screen_id"):
		return String(main.call("current_screen_id"))
	return "?"


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _run_lab_export() -> void:
	var main := get_tree().current_scene
	var lab := _find_screen(main, "_on_export_view_png")
	if lab == null:
		print("[DevCapture] lab screen not open; use --screen=lab")
		get_tree().quit(1)
		return
	print("[DevCapture] lab export test: view PNG")
	lab.call("_on_export_view_png")
	await get_tree().create_timer(0.8).timeout
	print("[DevCapture] lab export test: flat PNG")
	lab.call("_on_export_flat_png")
	await get_tree().create_timer(1.4).timeout
	var dir := DirAccess.open("user://exports")
	var count := 0
	if dir != null:
		count = dir.get_files().size()
	print("[DevCapture] exports directory now contains %d files" % count)
	print("[DevCapture] lab export test done")
	get_tree().quit(0 if count > 0 else 1)


func _find_screen(node: Node, method: String) -> Node:
	if node.has_method(method):
		return node
	for child in node.get_children():
		var found := _find_screen(child, method)
		if found != null:
			return found
	return null

func _run_flat_exports() -> void:
	DirAccess.make_dir_recursive_absolute(flat_export_dir)
	print("[DevCapture] flat exports -> %s" % flat_export_dir)
	for type in PatternConfig.TYPE_NAMES.size():
		var config: PatternConfig = PatternLibrary.make_preset(type)
		var geo := PatternEngine.generate(config)
		var name := "flat_%02d_%s.png" % [type, PatternConfig.TYPE_NAMES[type].to_lower().replace(" ", "_").replace("—", "").replace("(", "").replace(")", "").replace("/", "")]
		var path := "%s/%s" % [flat_export_dir, name]
		var saved := await PatternViewport.export_flat(get_tree(), config, geo, 640, path)
		print("[DevCapture]   %s -> %s" % [PatternConfig.TYPE_NAMES[type], "OK" if not saved.is_empty() else "FAILED"])
	await get_tree().process_frame
	get_tree().quit(0)


func _run_selftest() -> void:
	print("[DevCapture] running self tests (headless = %s)" % str(DisplayServer.get_name() == "headless"))
	var failures: int = NoorSelfTest.run_all()
	if failures == 0:
		print("[DevCapture] SELFTEST: ALL PASSED")
	else:
		print("[DevCapture] SELFTEST: %d FAILURE(S)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _do_capture() -> void:
	await RenderingServer.frame_post_draw
	var root := get_viewport()
	var img: Image = null
	if root != null:
		var texture := root.get_texture()
		if texture != null:
			img = texture.get_image()
	if img == null:
		print("[DevCapture] capture failed: no rendered image (headless mode?)")
	else:
		var err := img.save_png(capture_path)
		if err == OK:
			print("[DevCapture] saved %s (%dx%d)" % [capture_path, img.get_width(), img.get_height()])
		else:
			print("[DevCapture] save_png failed for %s (err %d)" % [capture_path, err])
	await get_tree().process_frame
	get_tree().quit(0)
