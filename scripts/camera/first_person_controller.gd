class_name FirstPersonController
extends CharacterBody3D
## First-person walker: WASD + mouse look, Shift to run, Space to jump.
## The world screen captures the mouse and forwards look deltas.

var active := false
var camera: Camera3D = null

var _pitch := 0.0
var _gravity := 22.0


func setup() -> void:
	# collision body
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	shape.shape = capsule
	shape.position = Vector3(0, 0.875, 0)
	add_child(shape)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 1.62, 0)
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 600.0
	add_child(camera)
	collision_layer = 1
	collision_mask = 1


func set_active(on: bool) -> void:
	active = on
	if camera != null:
		camera.current = on
	set_physics_process(on)


func set_look(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = clampf(pitch, -1.35, 1.35)
	if camera != null:
		camera.rotation.x = _pitch


func look_by(relative: Vector2) -> void:
	rotation.y -= relative.x * AppState.fp_mouse_sensitivity
	var dy := relative.y * AppState.fp_mouse_sensitivity
	_pitch += -dy if AppState.fp_invert_y else dy
	_pitch = clampf(_pitch, -1.35, 1.35)
	if camera != null:
		camera.rotation.x = _pitch


func eye_position() -> Vector3:
	return global_position + Vector3(0, 1.62, 0)


func forward_direction() -> Vector3:
	if camera != null:
		return -camera.global_transform.basis.z
	return -global_transform.basis.z


func _physics_process(delta: float) -> void:
	if not active:
		return
	var speed := AppState.fp_walk_speed
	if Input.is_action_pressed("noor_run"):
		speed *= AppState.fp_run_multiplier
	var input := Input.get_vector("noor_left", "noor_right", "noor_forward", "noor_back")
	var direction := (global_transform.basis.x * input.x + global_transform.basis.z * input.y)
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("noor_jump"):
		velocity.y = AppState.fp_jump_velocity
	move_and_slide()
