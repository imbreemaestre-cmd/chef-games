extends Node2D
## Sunberry Hollow - 2D top-down culinary adventure (first playable slice).
##
## Owns the forest (tiles + props), the ingredient inventory, the cooking odds
## and the flow between exploring, cooking and battling. Battle and cooking
## rules live in Data; this script only decides what the player is allowed to do.

const TILE := 32
const MAP_W := 44
const MAP_H := 28

const START_TILE := Vector2i(5, 22)
const CAMPFIRE_TILE := Vector2i(14, 15)
const TART_TILE := Vector2i(38, 9)

const PATH_POINTS := [
	Vector2i(4, 23), Vector2i(8, 21), Vector2i(12, 18), Vector2i(16, 17),
	Vector2i(21, 15), Vector2i(26, 13), Vector2i(31, 11), Vector2i(36, 10),
	Vector2i(39, 9),
]

const BUSH_TILES := [
	Vector2i(10, 14), Vector2i(8, 17), Vector2i(12, 12),
	Vector2i(17, 14), Vector2i(19, 19), Vector2i(11, 19),
]

const ROCK_TILES := [
	Vector2i(7, 12), Vector2i(20, 20), Vector2i(24, 9), Vector2i(30, 16),
	Vector2i(34, 7), Vector2i(14, 22), Vector2i(40, 13), Vector2i(5, 18),
]

const MAX_PARTY := 3

# --- progression state --------------------------------------------------
var berries := 0
var party: Array[String] = []
var mastered: Array[String] = []
var proficiency: Dictionary = {"simmer": 0.0, "roast": 0.0}
var chef_xp := 0
var chef_level := 1

var battle_active := false

var _encounter: Node = null
var _companion: Node2D = null
var _current_target: Node = null
var _greeted := false

@onready var world: Node2D = $World
@onready var ground: TileMapLayer = $World/Ground
@onready var player: CharacterBody2D = $World/Player
@onready var hud: CanvasLayer = $HUD
@onready var battle: CanvasLayer = $Battle


func _ready() -> void:
	_paint_ground()
	_build_props()
	player.global_position = _tile_center(START_TILE)
	hud.cook_requested.connect(_on_cook_requested)
	battle.battle_finished.connect(_on_battle_finished)
	for id: String in Data.RECIPES.keys():
		if bool(Data.recipe(id).get("scroll", false)):
			mastered.append(id)
	_refresh_hud()
	hud.toast("Gather 3 sunberries, then cook at the campfire.", 4.0)


# --- world --------------------------------------------------------------

func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x) + 0.5, float(tile.y) + 0.5) * float(TILE)


func _path_cells() -> Dictionary:
	var cells := {}
	for i in range(PATH_POINTS.size() - 1):
		var a: Vector2i = PATH_POINTS[i]
		var b: Vector2i = PATH_POINTS[i + 1]
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in range(steps + 1):
			var t := float(s) / float(maxi(1, steps))
			var cx := int(round(lerpf(float(a.x), float(b.x), t)))
			var cy := int(round(lerpf(float(a.y), float(b.y), t)))
			cells[Vector2i(cx, cy)] = true
			cells[Vector2i(cx + 1, cy)] = true
	return cells


func _cells_near(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if absi(dx) + absi(dy) <= radius:
				var cell := Vector2i(center.x + dx, center.y + dy)
				if cell.x >= 0 and cell.y >= 0 and cell.x < MAP_W and cell.y < MAP_H:
					out.append(cell)
	return out


func _paint_ground() -> void:
	ground.tile_set = Art.tileset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for y in range(MAP_H):
		for x in range(MAP_W):
			var r := rng.randf()
			var tile := 0
			if r < 0.14:
				tile = 1
			elif r < 0.22:
				tile = 2
			elif r < 0.30:
				tile = 3
			ground.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))
	for cell: Vector2i in _path_cells().keys():
		ground.set_cell(cell, 0, Vector2i(4 if rng.randf() < 0.72 else 5, 0))
	for cell: Vector2i in _cells_near(CAMPFIRE_TILE, 2):
		ground.set_cell(cell, 0, Vector2i(4, 0))
	for cell: Vector2i in _cells_near(TART_TILE, 2):
		ground.set_cell(cell, 0, Vector2i(6, 0))


func _build_props() -> void:
	var path := _path_cells()
	for tile: Vector2i in BUSH_TILES:
		_spawn_bush(tile)
	for tile: Vector2i in ROCK_TILES:
		_spawn_rock(tile)
	_spawn_campfire(CAMPFIRE_TILE)
	_spawn_tart(TART_TILE)
	_spawn_trees(path)


func _is_keepout(cell: Vector2i, path: Dictionary) -> bool:
	if path.has(cell):
		return true
	for p: Vector2i in [CAMPFIRE_TILE, TART_TILE, START_TILE]:
		if absi(cell.x - p.x) <= 3 and absi(cell.y - p.y) <= 3:
			return true
	for b: Vector2i in BUSH_TILES:
		if absi(cell.x - b.x) <= 2 and absi(cell.y - b.y) <= 2:
			return true
	return false


func _spawn_trees(path: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	var taken := {}
	for y in range(MAP_H):
		for x in range(MAP_W):
			var cell := Vector2i(x, y)
			if taken.has(cell) or _is_keepout(cell, path):
				continue
			var edge := x < 4 or y < 4 or x >= MAP_W - 4 or y >= MAP_H - 4
			var chance := 0.7 if edge else 0.05
			if rng.randf() >= chance:
				continue
			_spawn_tree(_tile_center(cell) + Vector2(0, 10))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					taken[Vector2i(x + dx, y + dy)] = true


func _nearest_texture(node: Sprite2D) -> void:
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _spawn_tree(pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.global_position = pos
	var sprite := Sprite2D.new()
	sprite.texture = Art.tree()
	sprite.offset = Vector2(0, -36)
	_nearest_texture(sprite)
	body.add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	shape.position = Vector2(0, -4)
	body.add_child(shape)
	world.add_child(body)


func _spawn_rock(tile: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.global_position = _tile_center(tile)
	var sprite := Sprite2D.new()
	sprite.texture = Art.rock()
	sprite.offset = Vector2(0, -9)
	_nearest_texture(sprite)
	body.add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	shape.position = Vector2(0, -3)
	body.add_child(shape)
	world.add_child(body)


func _interaction_shape(radius: float) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.position = Vector2(0, -6)
	return shape


func _blocker(radius: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.position = Vector2(0, -4)
	body.add_child(shape)
	return body


func _spawn_bush(tile: Vector2i) -> void:
	var area := Area2D.new()
	area.set_script(load("res://scripts/berry_bush.gd"))
	area.global_position = _tile_center(tile)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = Art.bush(true)
	sprite.offset = Vector2(0, -16)
	_nearest_texture(sprite)
	area.add_child(sprite)
	area.add_child(_interaction_shape(15.0))
	world.add_child(area)


func _spawn_campfire(tile: Vector2i) -> void:
	var area := Area2D.new()
	area.set_script(load("res://scripts/campfire.gd"))
	area.global_position = _tile_center(tile)
	var flame := AnimatedSprite2D.new()
	flame.name = "Flame"
	flame.sprite_frames = Art.campfire_frames()
	flame.offset = Vector2(0, -16)
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flame.play(&"burn")
	area.add_child(flame)
	area.add_child(_interaction_shape(18.0))
	area.add_child(_blocker(9.0))
	world.add_child(area)


func _spawn_tart(tile: Vector2i) -> void:
	var area := Area2D.new()
	area.set_script(load("res://scripts/wild_tart.gd"))
	area.global_position = _tile_center(tile)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = Art.food_texture("blackberry_tart")
	sprite.offset = Vector2(0, -20)
	_nearest_texture(sprite)
	area.add_child(sprite)
	var ring := Sprite2D.new()
	ring.name = "Ring"
	ring.texture = Art.ring()
	ring.position = Vector2(0, -2)
	_nearest_texture(ring)
	area.add_child(ring)
	area.add_child(_interaction_shape(20.0))
	area.add_child(_blocker(10.0))
	world.add_child(area)


# --- per-frame ----------------------------------------------------------

func _process(delta: float) -> void:
	_sync_control()
	if battle_active:
		hud.hide_prompt()
		return
	if hud.is_modal_open():
		hud.hide_prompt()
		return
	_current_target = player.nearest_interactable()
	if _current_target == null:
		hud.hide_prompt()
	else:
		hud.show_prompt(String(_current_target.prompt_text()))
	var margin := 20.0
	player.global_position = player.global_position.clamp(
		Vector2(margin, margin),
		Vector2(float(MAP_W * TILE) - margin, float(MAP_H * TILE) - margin)
	)


func _sync_control() -> void:
	var want: bool = not (battle_active or hud.is_modal_open())
	if player.control_enabled != want:
		if want:
			player.start()
		else:
			player.stop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if hud.is_cooking_open():
			hud.close_cooking()
		elif hud.is_menu_open():
			hud.close_menu()
		else:
			hud.open_menu(_stats_text())
		return
	if event.is_action_pressed("interact"):
		if battle_active or hud.is_modal_open():
			return
		var target: Node = player.nearest_interactable()
		if target != null:
			target.interact(self)


# --- gathering ----------------------------------------------------------

func gather_berries(amount: int, world_pos: Vector2) -> void:
	berries += amount
	_sparkle(world_pos)
	_refresh_hud()
	if not _greeted and berries >= 3:
		_greeted = true
		hud.toast("Three sunberries. The campfire is just north of the clearing.", 3.4)


func _sparkle(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Art.sparkle()
	s.global_position = pos + Vector2(0, -16)
	s.z_index = 4
	_nearest_texture(s)
	world.add_child(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2(2.0, 2.0), 0.45)
	tw.tween_property(s, "position", s.position + Vector2(0, -18), 0.45)
	tw.tween_property(s, "modulate:a", 0.0, 0.45)
	get_tree().create_timer(0.5).timeout.connect(s.queue_free)


# --- cooking ------------------------------------------------------------

func open_cooking(station_id: String) -> void:
	var station := Data.equipment(station_id)
	var methods: Array = Array(station.get("methods", []))
	var recipe_ids := Data.recipes_for(methods)
	var entries: Array = []
	for id: String in recipe_ids:
		var r: Dictionary = Data.recipe(id)
		entries.append({
			"id": id,
			"name": String(r.get("name", id)),
			"requirement": _requirement_text(r),
			"note": String(r.get("hint", "")),
			"chance": _chance_text(id),
			"can_cook": _has_ingredients(r),
		})
	var method_text := "-"
	if not methods.is_empty():
		method_text = Data.method_label(String(methods[0]))
	hud.open_cooking(
		String(station.get("name", station_id)),
		"%s   -   %d recipe%s known" % [method_text, recipe_ids.size(), "" if recipe_ids.size() == 1 else "s"],
		entries
	)


func _requirement_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	var ingredients: Dictionary = r.get("ingredients", {})
	for id: String in ingredients.keys():
		parts.append("%d %s" % [int(ingredients[id]), Data.ingredient_name(id)])
	return "Needs " + ", ".join(parts)


func _has_ingredients(r: Dictionary) -> bool:
	var ingredients: Dictionary = r.get("ingredients", {})
	for id: String in ingredients.keys():
		if id == "sunberry" and berries < int(ingredients[id]):
			return false
	return true


func _consume(r: Dictionary) -> void:
	var ingredients: Dictionary = r.get("ingredients", {})
	for id: String in ingredients.keys():
		if id == "sunberry":
			berries = maxi(0, berries - int(ingredients[id]))


func _is_mastered(recipe_id: String) -> bool:
	return mastered.has(recipe_id)


## Success chance for an unmastered attempt. Scrolls bypass this entirely.
## base 0.55 + proficiency + ingredient quality - difficulty, capped at 0.95.
func _cook_chance(recipe_id: String) -> float:
	var r: Dictionary = Data.recipe(recipe_id)
	if _is_mastered(recipe_id):
		return 1.0
	var methods: Array = Array(r.get("methods", ["simmer"]))
	var method := String(methods[0])
	var prof := float(proficiency.get(method, 0.0))
	var chance := 0.55 + prof * 0.04 + 0.05 - float(r.get("difficulty", 1)) * 0.05
	return clampf(chance, 0.10, 0.95)


func _chance_text(recipe_id: String) -> String:
	if _is_mastered(recipe_id):
		return "100%  scroll"
	return "%d%%" % int(round(_cook_chance(recipe_id) * 100.0))


func _on_cook_requested(recipe_id: String) -> void:
	var r: Dictionary = Data.recipe(recipe_id)
	if r.is_empty():
		return
	if not _has_ingredients(r):
		hud.toast("Not enough ingredients for %s." % String(r.get("name", recipe_id)), 2.5)
		return
	_consume(r)
	var methods: Array = Array(r.get("methods", ["simmer"]))
	var method := String(methods[0])
	var food_id := String(r.get("result", recipe_id))
	var success := _is_mastered(recipe_id) or randf() < _cook_chance(recipe_id)
	if success:
		proficiency[method] = float(proficiency.get(method, 0.0)) + 1.0
		_add_to_party(food_id)
		_spawn_companion(food_id)
		hud.toast("%s is ready! It hops into your party." % String(r.get("name", food_id)), 3.2)
	else:
		# Failure is informative, not punitive: some experience, sometimes an ingredient back.
		proficiency[method] = float(proficiency.get(method, 0.0)) + 0.5
		if randf() < 0.5:
			berries += 1
			hud.toast("The dish collapses, but you salvage a berry. Simmering experience +1.", 3.2)
		else:
			hud.toast("The dish collapses. You learned where it went wrong.", 3.0)
	hud.close_cooking()
	_refresh_hud()


func _add_to_party(food_id: String) -> void:
	if party.size() < MAX_PARTY:
		party.append(food_id)
	else:
		party[0] = food_id


func _spawn_companion(food_id: String) -> void:
	if _companion != null and is_instance_valid(_companion):
		_companion.queue_free()
	var node := Node2D.new()
	node.set_script(load("res://scripts/creature.gd"))
	node.global_position = player.global_position + Vector2(-20, 12)
	world.add_child(node)
	node.setup(player, food_id)
	_companion = node


# --- battle -------------------------------------------------------------

func start_battle(food_id: String, encounter: Node) -> void:
	if party.is_empty():
		hud.toast("You have no dish to fight with. Cook 3 sunberries at the campfire first.", 3.6)
		return
	battle_active = true
	_encounter = encounter
	hud.hide_prompt()
	player.stop()
	battle.start(food_id, party[0], "A wild %s blocks the trail!" % Data.food_name(food_id))


func level_from_xp() -> int:
	return maxi(1, 1 + chef_xp / 40)


func _on_battle_finished(result: String, reward: Dictionary) -> void:
	battle_active = false
	match result:
		"won":
			berries += int(reward.get("berries", 0))
			chef_xp += int(reward.get("xp", 0))
			var new_level := level_from_xp()
			if new_level > chef_level:
				chef_level = new_level
				hud.toast("Chef Level %d! New recipe scrolls will find you." % chef_level, 3.6)
			else:
				hud.toast("%s defeated!  +%d Sunberries, +%d Chef XP" % [
					Data.food_name(String(reward.get("enemy", ""))),
					int(reward.get("berries", 0)),
					int(reward.get("xp", 0)),
				], 3.6)
			if _encounter != null and is_instance_valid(_encounter) and _encounter.has_method("mark_defeated"):
				_encounter.mark_defeated()
		"lost":
			hud.toast("Your dish fainted. The forest carries you back to camp.", 3.6)
			player.global_position = _tile_center(CAMPFIRE_TILE) + Vector2(0, 46)
		_:
			hud.toast("You slipped away through the ferns.", 2.6)
	_encounter = null
	_refresh_hud()


# --- hud ----------------------------------------------------------------

func _refresh_hud() -> void:
	hud.set_berries(berries)
	if party.is_empty():
		hud.set_party("Party: empty  -  cook something to fight with")
	else:
		var names: Array[String] = []
		for id: String in party:
			names.append(Data.food_name(id))
		hud.set_party("Party: " + ", ".join(names))


func _stats_text() -> String:
	var party_text := "empty"
	if not party.is_empty():
		var names: Array[String] = []
		for id: String in party:
			names.append(Data.food_name(id))
		party_text = ", ".join(names)
	return "Chef Level %d    (%d XP)\nSunberries: %d\nDishes: %s\nSimmering practice: %d\nRecipes mastered: %d" % [
		chef_level, chef_xp, berries, party_text,
		int(proficiency.get("simmer", 0.0)), mastered.size(),
	]
