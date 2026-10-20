extends Node2D
## Ambient wildlife: a rabbit or a songbird that potters about the clearing,
## pauses to sit or peck, and startles away when the player comes close.
##
## It owns no game state and cannot be interacted with, so it never competes
## with berries, the campfire or Chef Mira.

@export var kind := "rabbit"

const HOME_RANGE := 54.0
const WORLD_MIN := Vector2(24, 40)
const WORLD_MAX := Vector2(1384, 872)

var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _speed := 34.0
var _pause := 0.0
var _t := 0.0
var _flee := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("critter")
	z_as_relative = false
	_home = global_position
	if kind == "bird":
		_speed = 26.0
		sprite.sprite_frames = ArtWorld.bird_frames()
		sprite.offset = Vector2(0, -6)
		sprite.play(&"peck")
	else:
		_speed = 34.0
		sprite.sprite_frames = ArtWorld.rabbit_frames()
		sprite.offset = Vector2(0, -8)
		sprite.play(&"hop")
	_pick_target()


func _process(delta: float) -> void:
	_t += delta
	_flee = maxf(0.0, _flee - delta)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var away := global_position - player.global_position
		var dist := away.length()
		if dist < 44.0 and dist > 0.001:
			_flee = 1.0
			_target = global_position + away.normalized() * 74.0
			_clamp_target()
			_pause = 0.0

	if _pause > 0.0:
		_pause -= delta
		_bob(0.0)
		return

	var to := _target - global_position
	if to.length() < 5.0:
		_pick_target()
		_bob(0.0)
		return

	var stride := _speed * (1.9 if _flee > 0.0 else 1.0)
	global_position += to.normalized() * stride * delta
	if absf(to.x) > 0.01:
		sprite.flip_h = to.x < 0.0
	if kind == "bird":
		sprite.speed_scale = 1.6 if _flee > 0.0 else 1.0
	else:
		sprite.speed_scale = 2.2 if _flee > 0.0 else 1.0
	_bob(1.0)


## Small vertical lift so the hop reads even when the sprite is moving slowly.
func _bob(amount: float) -> void:
	var heel := 2.0 if kind != "bird" else 1.0
	sprite.position.y = -absf(sin(_t * 7.0)) * heel * amount


func _pick_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(10.0, HOME_RANGE)
	_target = _home + Vector2(cos(angle), sin(angle) * 0.7) * dist
	_clamp_target()
	_pause = randf_range(0.5, 2.2)


func _clamp_target() -> void:
	_target.x = clampf(_target.x, WORLD_MIN.x, WORLD_MAX.x)
	_target.y = clampf(_target.y, WORLD_MIN.y, WORLD_MAX.y)
