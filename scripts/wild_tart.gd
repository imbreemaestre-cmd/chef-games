extends Area2D
## A wild dish blocking the trail. E starts a turn-based battle.
## The tart is a literal Blackberry Tart, not a creature: it bobs and wobbles.

@export var food_id := "blackberry_tart"

var defeated := false

@onready var sprite: Sprite2D = $Sprite
@onready var ring: Sprite2D = $Ring

var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	sprite.texture = Art.food_texture(food_id)
	sprite.offset = Vector2(0, -20)
	ring.texture = Art.ring()
	ring.position = Vector2(0, -2)


func is_available() -> bool:
	return not defeated


func prompt_text() -> String:
	return "E   Challenge the %s" % Data.food_name(food_id)


func interact(game: Node) -> void:
	game.start_battle(food_id, self)


func _process(delta: float) -> void:
	_t += delta
	if defeated:
		return
	sprite.position.y = -1.0 + sin(_t * 3.2) * 1.6
	var squash := 1.0 + sin(_t * 3.2 + PI * 0.5) * 0.035
	sprite.scale = Vector2(1.0 / squash, squash)
	ring.modulate.a = 0.45 + sin(_t * 2.4) * 0.25


func mark_defeated() -> void:
	defeated = true
	ring.visible = false
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.3, 0.1), 0.25)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.2)
