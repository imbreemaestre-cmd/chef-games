extends Area2D
## A sunberry bush. E gathers one berry, the bush shakes bare, then regrows.

@export var regrow_time := 12.0

var available := true
var _rest_scale := Vector2.ONE

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("interactable")
	sprite.texture = Art.bush(true)
	sprite.offset = Vector2(0, -16)
	_rest_scale = sprite.scale


func is_available() -> bool:
	return available


func prompt_text() -> String:
	if not available:
		return "This bush needs time to grow back"
	return "E   Gather sunberries"


func interact(game: Node) -> void:
	if not available:
		return
	available = false
	sprite.texture = Art.bush(false)
	_shake()
	game.gather_berries(1, global_position)
	get_tree().create_timer(regrow_time).timeout.connect(_regrow)


func _shake() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.15, 0.82), 0.08)
	tw.tween_property(sprite, "scale", Vector2(0.86, 1.06), 0.10)
	tw.tween_property(sprite, "scale", _rest_scale, 0.12)


func _regrow() -> void:
	if not is_inside_tree():
		return
	available = true
	sprite.texture = Art.bush(true)
	sprite.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", _rest_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
