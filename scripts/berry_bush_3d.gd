extends Node3D
## A forageable sunberry bush. Gathering shrinks the bush and it regrows after a while.

@export var regrow_time := 10.0

var _available := true
var _base_scale := Vector3.ONE

@onready var _model: Node3D = $Model


func _ready() -> void:
	add_to_group("forage")
	_base_scale = _model.scale


func can_gather() -> bool:
	return _available


func gather() -> void:
	if not _available:
		return
	_available = false
	var tw := create_tween()
	tw.tween_property(_model, "scale", _base_scale * 0.22, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	get_tree().create_timer(regrow_time).timeout.connect(_regrow)


func _regrow() -> void:
	if not is_inside_tree():
		return
	_available = true
	var tw := create_tween()
	tw.tween_property(_model, "scale", _base_scale, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
