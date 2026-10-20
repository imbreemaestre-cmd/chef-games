extends Node3D
## The living food creature: pops out of the pot, then hops after the player.

@export var follow_distance := 2.4
@export var hop_speed := 6.5

var target: Node3D
var _t := 0.0
var _settled := false


func setup(player: Node3D) -> void:
	target = player


func _ready() -> void:
	_pop_out()


func _pop_out() -> void:
	var start := scale
	scale = start * 0.05
	var tw := create_tween()
	tw.tween_property(self, "scale", start, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if target == null:
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var moving := dist > follow_distance
	if moving:
		var step := minf(hop_speed, dist - follow_distance + 1.5) * delta
		global_position += to.normalized() * step
		_t += delta * 10.0
		position.y = absf(sin(_t)) * 0.30
		rotation.y = atan2(-to.x, -to.z)
		_settled = false
	elif not _settled:
		_t = 0.0
		position.y = 0.0
		_settled = true
