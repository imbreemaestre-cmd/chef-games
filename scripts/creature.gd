extends Node2D
## The cooked dish that follows the chef around the forest: it hops, bobs and
## squashes as it trails behind, so the food reads as alive but still food.

@export var follow_distance := 26.0
@export var hop_speed := 95.0

var target: Node2D
var food_id := "berry_compote"

var sprite: Sprite2D
var _t := 0.0
var _settled := true


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Art.food_texture(food_id)
	sprite.scale = Vector2(0.5, 0.5)
	sprite.offset = Vector2(0, -10)
	add_child(sprite)
	sprite.scale = Vector2(0.05, 0.05)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func setup(owner_node: Node2D, id: String) -> void:
	target = owner_node
	food_id = id


func _process(delta: float) -> void:
	if target == null:
		return
	var to := target.global_position - global_position
	var dist := to.length()
	if dist > follow_distance:
		var step := minf(hop_speed, dist - follow_distance + 40.0) * delta
		global_position += to.normalized() * step
		_t += delta * 9.0
		position.y = -absf(sin(_t)) * 3.0
		_settled = false
	elif not _settled:
		_t = 0.0
		position.y = 0.0
		_settled = true
	if sprite != null:
		var squash := 1.0 + sin(_t * 2.0) * 0.04
		sprite.scale = Vector2(0.5 / squash, 0.5 * squash)
