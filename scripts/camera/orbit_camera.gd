class_name OrbitCamera
extends Node3D
## Orbit camera rig: rotates around a target point, zooms and pans.
## Input is fed by the world screen so selection clicks and camera drags can
## be told apart in one place.

var target := Vector3(0, 5, 0)
var yaw := 0.55
var pitch := 0.42     ## positive = camera above the target, looking down
var distance := 58.0
var min_distance := 3.0
var max_distance := 140.0

var camera: Camera3D = null
var _focus_tween: Tween = null


func setup() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 55.0
	camera.near = 0.1
	camera.far = 600.0
	add_child(camera)
	update_transform()


func set_current(on: bool) -> void:
	if camera != null:
		camera.current = on


func orbit_by(relative: Vector2) -> void:
	yaw -= relative.x * AppState.orbit_sensitivity
	var dy := relative.y * AppState.orbit_sensitivity
	pitch += -dy if AppState.orbit_invert_y else dy
	pitch = clampf(pitch, -1.45, 1.28)
	update_transform()


func pan_by(relative: Vector2) -> void:
	if camera == null:
		return
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var scale := distance * 0.0014
	target -= right * relative.x * scale
	target -= up * relative.y * scale
	update_transform()


func zoom_by(factor: float) -> void:
	distance = clampf(distance * factor, min_distance, max_distance)
	update_transform()


func update_transform() -> void:
	if camera == null:
		return
	var dir := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw))
	camera.position = target + dir * distance
	if camera.position.distance_to(target) > 0.05:
		camera.look_at(target, Vector3.UP)


func focus_on(point: Vector3, radius: float, duration: float = 0.6) -> void:
	var start_target := target
	var start_distance := distance
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	var end_distance := clampf(radius / maxf(tan(deg_to_rad(camera.fov * 0.5)), 0.05) * 1.25,
		min_distance, max_distance)
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_focus_tween.tween_method(func(t: float) -> void:
		target = start_target.lerp(point, t)
		distance = lerpf(start_distance, end_distance, t)
		update_transform(), 0.0, 1.0, duration)
