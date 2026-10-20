extends Area2D
## Chef Mira: the travelling chef at the opening campfire.
##
## She owns the dialogue (res://scripts/dialogues.gd) and the Blueberry Tart she
## baked, which bobs beside her so the player sees living food before anyone
## explains it. This script only animates her and forwards interaction to the
## game controller; no dialogue text lives here.

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var tart: Sprite2D = $Tart
@onready var tart_shadow: Sprite2D = $TartShadow

var _t := 0.0
var _facing := 0
var _excited := 0.0
var _talking := false
var _tart_base := Vector2.ZERO


func _ready() -> void:
	add_to_group("interactable")
	sprite.sprite_frames = Art.mira_frames()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play(&"down_idle")
	tart.texture = Art.food_texture("blueberry_tart")
	tart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tart_shadow.texture = Art.shadow()
	tart_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tart_base = tart.position


func is_available() -> bool:
	return true


func prompt_text() -> String:
	return "E   Talk to Chef Mira"


func interact(game: Node) -> void:
	game.talk_to_mira(self)


## Called by the game while she speaks, so she faces and gestures at the player.
func set_talking(state: bool) -> void:
	_talking = state
	_play(StringName(_dir_name() + ("_talk" if state else "_idle")))


## World reaction for a dialogue line: the tart proves it is alive.
func play_fx(kind: String) -> void:
	match kind:
		"tart_wobble":
			_excited = 1.2
			_hop(9.0)
		"tart_excited":
			_excited = 2.0
			_hop(15.0)
		"tart_hit":
			_excited = 0.6
			_hop(4.0)
		_:
			_excited = 0.8


func _hop(height: float) -> void:
	var tw := create_tween()
	tw.tween_property(tart, "position:y", _tart_base.y - height, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(tart, "position:y", _tart_base.y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _dir_name() -> String:
	match _facing:
		1:
			return "up"
		2:
			return "right"
		3:
			return "left"
	return "down"


func _play(anim: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


func _process(delta: float) -> void:
	_t += delta
	_excited = maxf(0.0, _excited - delta)

	# she turns to look at whoever is nearby
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var to := player.global_position - global_position
		if absf(to.x) > absf(to.y) * 1.2:
			_facing = 2 if to.x > 0.0 else 3
		elif absf(to.y) > 6.0:
			_facing = 0 if to.y > 0.0 else 1
		if not _talking:
			_play(StringName(_dir_name() + "_idle"))

	# the tart is always slightly alive; excitement makes it wobble hard
	var amp := 0.05 + minf(_excited, 2.0) * 0.05
	var speed := 2.6 + minf(_excited, 2.0) * 2.2
	var squash := 1.0 + sin(_t * speed) * amp
	tart.scale = Vector2(0.52 / squash, 0.52 * squash)
	tart.rotation = sin(_t * speed * 0.7) * 0.05 * (1.0 + _excited)
	tart_shadow.scale = Vector2(1.0 - (squash - 1.0) * 0.6, 1.0)
