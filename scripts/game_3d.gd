extends Node3D
## Culinary-combat slice: gather sunberries, cook a living creature, battle the Wild Bramble.

const SPROUT := preload("res://scenes/sunberry_sprout.tscn")
const RECIPE_COST := 3
const FORAGE_RANGE := 3.1
const COOK_RANGE := 3.8
const CHALLENGE_RANGE := 3.4

var berries := 0
var cooked := false
var in_battle := false
var creature: Node3D
var near_bush: Node3D
var near_cook := false
var near_enemy := false
var _prompt_cache := ""

@onready var player: CharacterBody3D = $Player
@onready var hud = $HUD
@onready var battle = $Battle
@onready var campfire: Node3D = $Camp/Campfire
@onready var enemy: Node3D = $WildBramble


func _ready() -> void:
	hud.set_berries(berries)
	hud.set_companion("")
	hud.show_title("Sunberry Hollow", "Gather 3 sunberries, cook a friend at the campfire, then win its first battle.")
	battle.battle_won.connect(_on_battle_won)
	battle.battle_lost.connect(_on_battle_lost)
	battle.battle_fled.connect(_on_battle_fled)


func _process(_delta: float) -> void:
	if in_battle:
		return

	var here := player.global_position
	near_bush = _nearest_bush(here)
	near_cook = here.distance_to(campfire.global_position) < COOK_RANGE
	near_enemy = cooked and is_instance_valid(enemy) and here.distance_to(enemy.global_position) < CHALLENGE_RANGE

	_set_prompt(_prompt_text())

	if Input.is_action_just_pressed("interact"):
		if near_enemy:
			_start_battle()
		elif near_cook:
			_cook()
		elif near_bush != null:
			_gather(near_bush)


func _prompt_text() -> String:
	if near_enemy:
		return "E  -  Challenge the Wild Bramble"
	if near_cook:
		if cooked:
			return "E  -  Cook another Sunberry Sprout (3 berries)"
		if berries >= RECIPE_COST:
			return "E  -  Cook a Sunberry Sprout (3 berries)"
		return "Campfire  -  bring 3 sunberries to cook (%d/%d)" % [berries, RECIPE_COST]
	if near_bush != null:
		return "E  -  Gather Sunberries"
	if not cooked:
		return "Find the berry bushes, then cook at the campfire"
	return ""


func _set_prompt(text: String) -> void:
	if text == _prompt_cache:
		return
	_prompt_cache = text
	hud.show_prompt(text)


func _nearest_bush(here: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist := FORAGE_RANGE
	for node in get_tree().get_nodes_in_group("forage"):
		var bush := node as Node3D
		if bush == null or not bush.has_method("can_gather") or not bush.can_gather():
			continue
		var d := here.distance_to(bush.global_position)
		if d < best_dist:
			best_dist = d
			best = bush
	return best


func _gather(bush: Node3D) -> void:
	bush.gather()
	berries += 1
	hud.set_berries(berries)
	player.play_action("pickup")
	_sparkle(bush.global_position + Vector3.UP * 1.2, Color(1.0, 0.42, 0.52))
	if berries >= RECIPE_COST and not cooked:
		hud.toast("Three sunberries! Take them to the campfire.")


func _cook() -> void:
	if cooked:
		return
	if berries < RECIPE_COST:
		hud.toast("You need %d sunberries to cook." % RECIPE_COST)
		return
	berries -= RECIPE_COST
	hud.set_berries(berries)
	player.play_action("cast")
	_sparkle(campfire.global_position + Vector3.UP * 1.4, Color(1.0, 0.74, 0.30))

	var sprout := SPROUT.instantiate()
	add_child(sprout)
	sprout.global_position = campfire.global_position + Vector3(1.4, 0.0, 1.1)
	sprout.setup(player)
	creature = sprout
	cooked = true
	hud.set_companion("Sunberry Sprout  -  Lv 1")
	hud.toast("Sunberry Sprout is born! It is hungry for a battle.")


func _start_battle() -> void:
	if in_battle or not cooked:
		return
	in_battle = true
	player.enter_ui_mode()
	_set_prompt("")
	battle.start(
		"Wild Bramble", 30, 6,
		"Sunberry Sprout", 34, 7,
		"A WILD BRAMBLE BLOCKS THE TRAIL!"
	)


func _on_battle_won(reward: int) -> void:
	in_battle = false
	berries += reward
	hud.set_berries(berries)
	hud.set_companion("Sunberry Sprout  -  Lv 2  -  +12 XP")
	hud.toast("Victory! The Wild Bramble scatters %d sunberries." % reward)
	if is_instance_valid(enemy):
		_sparkle(enemy.global_position + Vector3.UP, Color(1.0, 0.86, 0.36))
		var tw := create_tween()
		tw.tween_property(enemy, "scale", Vector3.ZERO, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(enemy.queue_free)
	player.enter_play_mode()


func _on_battle_lost() -> void:
	in_battle = false
	hud.toast("Your sprout fainted. The forest carries you back to camp.")
	var camp := campfire.global_position + Vector3(2.6, 0.2, 2.6)
	player.global_position = camp
	player.velocity = Vector3.ZERO
	player.enter_play_mode()


func _on_battle_fled() -> void:
	in_battle = false
	hud.toast("You slipped away from the Wild Bramble.")
	if is_instance_valid(enemy):
		var away := player.global_position - enemy.global_position
		away.y = 0.0
		player.global_position += away.normalized() * 2.5
	player.enter_play_mode()


func _sparkle(at: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.75
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.09
	p.color = color

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.mesh = mesh

	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)
