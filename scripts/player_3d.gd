extends CharacterBody3D
## Third-person chef controller: camera-relative movement, mouse orbit, jump.
## The visible body is the rigged shelf character (Chef) which animates itself
## from this body's velocity through character_anim.gd.

@export var walk_speed := 4.6
@export var run_speed := 7.4
@export var jump_velocity := 5.4
@export var gravity := 16.0
@export var mouse_sensitivity := 0.0026
@export var min_pitch := -1.0
@export var max_pitch := 0.30

var control_enabled := true

@onready var yaw_node: Node3D = $CameraYaw
@onready var pitch_node: Node3D = $CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var chef: Node3D = $Chef


func _ready() -> void:
	add_to_group("player")
	spring_arm.add_excluded_object(self)
	pitch_node.rotation.x = -0.30
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw_node.rotation.y -= motion.relative.x * mouse_sensitivity
		pitch_node.rotation.x = clampf(pitch_node.rotation.x - motion.relative.y * mouse_sensitivity, min_pitch, max_pitch)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if control_enabled:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var basis := yaw_node.global_transform.basis
		var dir := basis.x * input.x + basis.z * input.y
		dir.y = 0.0
		dir = dir.normalized()
		var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
		var target := dir * speed
		velocity.x = move_toward(velocity.x, target.x, speed * 14.0 * delta)
		velocity.z = move_toward(velocity.z, target.z, speed * 14.0 * delta)
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
	else:
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)

	move_and_slide()


## Plays a one-shot clip on the visible character (pickup, cast, cheer, ...).
func play_action(action: String) -> void:
	if chef != null and chef.has_method("play_action"):
		chef.play_action(action)


## Freezes movement and hands the mouse back to the UI (battle screen).
func enter_ui_mode() -> void:
	control_enabled = false
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Returns to gameplay and recaptures the mouse.
func enter_play_mode() -> void:
	control_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
