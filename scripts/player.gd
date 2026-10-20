extends CharacterBody2D
## Top-down chef controller: four-direction walking, Shift to run, no jumping.
## The rig is a generated AnimatedSprite2D sheet (down/up/left/right, idle + walk).

const SPEED := 74.0
const RUN_SPEED := 116.0
const ACCEL := 900.0
const FRICTION := 1100.0

var control_enabled := true
var facing := 0  # 0 down, 1 up, 2 right, 3 left

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interact_area: Area2D = $InteractArea


func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = Art.chef_frames()
	sprite.play(&"down_idle")
	facing = 0


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if control_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	if input.length() > 0.1:
		var speed := RUN_SPEED if Input.is_action_pressed("sprint") else SPEED
		velocity = velocity.move_toward(input.normalized() * speed, ACCEL * delta)
		_update_facing(input)
		_animate(input.length() > 0.1, speed)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		_animate(false, SPEED)

	move_and_slide()


func _update_facing(input: Vector2) -> void:
	if absf(input.x) > absf(input.y):
		facing = 2 if input.x > 0.0 else 3
	else:
		facing = 0 if input.y > 0.0 else 1


func _animate(moving: bool, speed: float) -> void:
	var dirs := ["down", "up", "right", "left"]
	var base: String = dirs[facing]
	if moving:
		var anim := StringName(base + "_walk")
		if sprite.animation != anim:
			sprite.play(anim)
		sprite.speed_scale = clampf(speed / SPEED, 0.85, 1.7)
	else:
		var anim := StringName(base + "_idle")
		if sprite.animation != anim:
			sprite.play(anim)
		sprite.speed_scale = 1.0


## Closest interactable Area2D inside the reach circle, or null.
func nearest_interactable() -> Node:
	var best: Node = null
	var best_dist := INF
	for area: Area2D in interact_area.get_overlapping_areas():
		if not area.is_in_group("interactable"):
			continue
		if area.has_method("is_available") and not area.is_available():
			continue
		var d := global_position.distance_squared_to(area.global_position)
		if d < best_dist:
			best_dist = d
			best = area
	return best


func stop() -> void:
	control_enabled = false
	velocity = Vector2.ZERO
	sprite.speed_scale = 1.0


func start() -> void:
	control_enabled = true
