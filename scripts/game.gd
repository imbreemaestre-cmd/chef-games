extends Node2D
## Sunberry Hollow - 2D top-down culinary adventure.
##
## Owns the forest (tiles, props, ambient effects), the player's inventory and
## tools, quest flags, cooking odds, saving, and the flow between exploring,
## talking, cooking and battling. Rules live in Data; dialogue lives in
## Dialogues. This script decides what the player is allowed to do.

const SaveFile := preload("res://scripts/saving.gd")

const TILE := 32
const MAP_W := 44
const MAP_H := 28

const START_TILE := Vector2i(12, 18)
const CAMPFIRE_TILE := Vector2i(15, 17)

const PATH_POINTS := [
	Vector2i(18, 18), Vector2i(22, 19), Vector2i(26, 17), Vector2i(31, 15),
	Vector2i(35, 12), Vector2i(39, 10),
]

const BUSH_TILES := [
	Vector2i(9, 20), Vector2i(11, 22), Vector2i(14, 22),
	Vector2i(7, 16), Vector2i(12, 14), Vector2i(20, 21),
]

const ROCK_TILES := [
	Vector2i(7, 13), Vector2i(22, 20), Vector2i(10, 12), Vector2i(25, 16),
	Vector2i(30, 20), Vector2i(34, 8),
]

const MAX_PARTY := 3

# --- progression state --------------------------------------------------
var inventory: Dictionary = {"sunberry": 0, "sugar": 0, "orange": 0}
var tools: Array[String] = []
var party: Array[String] = []
var flags: Dictionary = {}
var quest := "intro"
var known: Array[String] = []
var mastered: Array[String] = []
var proficiency: Dictionary = {"simmer": 0.0, "roast": 0.0}
var chef_xp := 0
var chef_level := 1
var text_speed := 1

var battle_active := false
var dialogue_open := false

var _mira: Node = null
var _companion: Node2D = null
var _current_target: Node = null
var _sway: Array = []
var _glow: Sprite2D = null
var _t := 0.0
var _pending_open := false
var _battle_food := ""

@onready var world: Node2D = $World
@onready var ground: TileMapLayer = $World/Ground
@onready var decor: Node2D = $World/Decor
@onready var player: CharacterBody2D = $World/Player
@onready var mira: Node = $World/Mira
@onready var hud: CanvasLayer = $HUD
@onready var battle: CanvasLayer = $Battle
@onready var dialogue: CanvasLayer = $Dialogue


func _ready() -> void:
	_mira = mira
	_paint_ground()
	_build_decor()
	_build_props()
	_build_ambience()

	hud.cook_requested.connect(_on_cook_requested)
	hud.save_requested.connect(_save_game)
	hud.text_speed_changed.connect(_on_text_speed_changed)
	battle.battle_finished.connect(_on_battle_finished)
	dialogue.finished.connect(_on_dialogue_finished)

	for id: String in Data.RECIPES.keys():
		if bool(Data.recipe(id).get("scroll", false)) and not mastered.has(id):
			mastered.append(id)

	var loaded := _load_game()
	if not loaded:
		player.global_position = _tile_center(START_TILE)
		quest = "intro"
	else:
		player.global_position = player.global_position.clamp(
			Vector2(20, 20),
			Vector2(float(MAP_W * TILE) - 20, float(MAP_H * TILE) - 20)
		)

	dialogue.set_speed_index(text_speed)
	_refresh_hud()

	# The opening line arrives on its own, once, and can be skipped with Esc.
	if not loaded and not bool(flags.get("met_mira", false)):
		_pending_open = true
		get_tree().create_timer(0.9).timeout.connect(_open_wake_dialogue)


func _open_wake_dialogue() -> void:
	if _pending_open and not dialogue_open:
		_pending_open = false
		talk_to_mira(_mira)


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


## Tiles: 0-2 grass, 3 flowers, 4-5 path, 6 clearing, 7 dense grass,
## 8 moss, 9 fallen leaves, 10 grassy path edge, 11 pebbles.
func _paint_ground() -> void:
	ground.tile_set = Art.tileset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for y in range(MAP_H):
		for x in range(MAP_W):
			var r := rng.randf()
			var tile := 0
			if r < 0.13:
				tile = 1
			elif r < 0.21:
				tile = 2
			elif r < 0.27:
				tile = 3
			elif r < 0.31:
				tile = 7
			ground.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))

	var path := _path_cells()
	for cell: Vector2i in path.keys():
		ground.set_cell(cell, 0, Vector2i(4 if rng.randf() < 0.7 else 5, 0))

	# grassy edge where the path meets the meadow
	for cell: Vector2i in path.keys():
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var nb := cell + d
			if path.has(nb):
				continue
			if rng.randf() < 0.55 and not ground.get_cell_source_id(nb) == -1:
				ground.set_cell(nb, 0, Vector2i(10, 0))

	for cell: Vector2i in _cells_near(CAMPFIRE_TILE, 3):
		ground.set_cell(cell, 0, Vector2i(6 if rng.randf() < 0.55 else 4, 0))

	# moss creeps in around the tree line and the rocks
	for tile: Vector2i in ROCK_TILES:
		for cell: Vector2i in _cells_near(tile, 2):
			if rng.randf() < 0.5:
				ground.set_cell(cell, 0, Vector2i(8, 0))
	for tile: Vector2i in BUSH_TILES:
		for cell: Vector2i in _cells_near(tile, 1):
			if rng.randf() < 0.35:
				ground.set_cell(cell, 0, Vector2i(9, 0))


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091
	for y in range(MAP_H):
		for x in range(MAP_W):
			var cell := Vector2i(x, y)
			if _is_keepout(cell, _path_cells()):
				continue
			var roll := rng.randf()
			if roll > 0.42:
				continue
			var pos := _tile_center(cell) + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0))
			var spr := Sprite2D.new()
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = pos
			if roll < 0.12:
				spr.texture = Art.flower_decal(rng.randi_range(0, 2))
			elif roll < 0.24:
				spr.texture = Art.grass_decal()
			elif roll < 0.31:
				spr.texture = Art.moss_decal()
			elif roll < 0.37:
				spr.texture = Art.leaves_decal()
			else:
				spr.texture = Art.stones_decal()
			spr.modulate.a = 0.85
			decor.add_child(spr)


func _build_props() -> void:
	var path := _path_cells()
	for tile: Vector2i in BUSH_TILES:
		_spawn_bush(tile)
	for tile: Vector2i in ROCK_TILES:
		_spawn_rock(tile)
	_spawn_campfire(CAMPFIRE_TILE)
	_spawn_trees(path)


func _is_keepout(cell: Vector2i, path: Dictionary) -> bool:
	if path.has(cell):
		return true
	for p: Vector2i in [CAMPFIRE_TILE, Vector2i(18, 17), Vector2i(18, 18), Vector2i(16, 18), START_TILE]:
		if absi(cell.x - p.x) <= 2 and absi(cell.y - p.y) <= 2:
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
			var chance := 0.68 if edge else 0.045
			if rng.randf() >= chance:
				continue
			_spawn_tree(_tile_center(cell) + Vector2(0, 10), rng.randi_range(0, 3))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					taken[Vector2i(x + dx, y + dy)] = true


func _nearest_texture(node: Sprite2D) -> void:
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _spawn_tree(pos: Vector2, variant: int) -> void:
	var body := StaticBody2D.new()
	body.global_position = pos

	var shadow := Sprite2D.new()
	shadow.texture = Art.shadow()
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.position = Vector2(0, -4)
	shadow.scale = Vector2(1.6, 1.5)
	shadow.z_index = -1
	decor.add_child(shadow)
	shadow.global_position = pos + Vector2(4, 0)

	var sprite := Sprite2D.new()
	sprite.texture = Art.tree_variant(variant)
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

	_sway.append({"node": sprite, "phase": randf() * TAU, "amount": 0.012 + randf() * 0.008})


func _spawn_rock(tile: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.global_position = _tile_center(tile)
	var sprite := Sprite2D.new()
	sprite.texture = Art.rock()
	sprite.offset = Vector2(0, -9)
	_nearest_texture(sprite)
	body.add_child(sprite)
	var shadow := Sprite2D.new()
	shadow.texture = Art.shadow()
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.position = _tile_center(tile) + Vector2(0, -1)
	shadow.scale = Vector2(0.9, 0.7)
	shadow.z_index = -1
	decor.add_child(shadow)
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

	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = Art.glow()
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.position = Vector2(0, -18)
	glow.scale = Vector2(2.4, 2.0)
	glow.z_index = -1
	glow.modulate = Color(1.0, 0.72, 0.38, 0.35)
	area.add_child(glow)
	_glow = glow

	var flame := AnimatedSprite2D.new()
	flame.name = "Flame"
	flame.sprite_frames = Art.campfire_frames()
	flame.offset = Vector2(0, -16)
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flame.play(&"burn")
	area.add_child(flame)

	var smoke := CPUParticles2D.new()
	smoke.name = "Smoke"
	smoke.texture = Art.smoke()
	smoke.amount = 10
	smoke.lifetime = 2.6
	smoke.direction = Vector2(0, -1)
	smoke.spread = 14.0
	smoke.gravity = Vector2(0, -14)
	smoke.initial_velocity_min = 6.0
	smoke.initial_velocity_max = 14.0
	smoke.scale_amount_min = 0.4
	smoke.scale_amount_max = 1.1
	smoke.position = Vector2(0, -26)
	smoke.color = Color(1, 1, 1, 0.35)
	area.add_child(smoke)

	var embers := CPUParticles2D.new()
	embers.name = "Embers"
	embers.texture = Art.ember()
	embers.amount = 8
	embers.lifetime = 1.3
	embers.direction = Vector2(0, -1)
	embers.spread = 26.0
	embers.gravity = Vector2(0, 22)
	embers.initial_velocity_min = 12.0
	embers.initial_velocity_max = 26.0
	embers.scale_amount_min = 0.6
	embers.scale_amount_max = 1.3
	embers.position = Vector2(0, -20)
	area.add_child(embers)

	area.add_child(_interaction_shape(18.0))
	area.add_child(_blocker(9.0))
	world.add_child(area)


func _build_ambience() -> void:
	# a few leaves drifting over the whole clearing
	var leaves := CPUParticles2D.new()
	leaves.name = "DriftingLeaves"
	leaves.texture = Art.leaf()
	leaves.amount = 14
	leaves.lifetime = 9.0
	leaves.preprocess = 4.0
	leaves.direction = Vector2(1, 0.6)
	leaves.spread = 40.0
	leaves.gravity = Vector2(3, 5)
	leaves.initial_velocity_min = 4.0
	leaves.initial_velocity_max = 11.0
	leaves.scale_amount_min = 0.5
	leaves.scale_amount_max = 1.1
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(MAP_W * TILE * 0.5, MAP_H * TILE * 0.5)
	leaves.position = Vector2(MAP_W * TILE * 0.5, MAP_H * TILE * 0.5)
	leaves.z_index = 1
	leaves.modulate = Color(1, 1, 1, 0.8)
	world.add_child(leaves)


# --- per-frame ----------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	for entry: Dictionary in _sway:
		var node := entry["node"] as Node2D
		if node != null and is_instance_valid(node):
			node.rotation = sin(_t * 1.3 + float(entry["phase"])) * float(entry["amount"])
	if _glow != null and is_instance_valid(_glow):
		var flick := 0.94 + sin(_t * 7.0) * 0.04 + sin(_t * 11.3) * 0.03
		_glow.scale = Vector2(2.4, 2.0) * flick

	_sync_control()
	if battle_active or dialogue_open:
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
	var want: bool = not (battle_active or dialogue_open or hud.is_modal_open())
	if player.control_enabled != want:
		if want:
			player.start()
		else:
			player.stop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if dialogue_open:
			dialogue.close()
			return
		if hud.is_cooking_open():
			hud.close_cooking()
		elif hud.is_menu_open():
			hud.close_menu()
		else:
			hud.open_menu(_stats_text())
		return
	if event.is_action_pressed("interact"):
		if battle_active or dialogue_open or hud.is_modal_open():
			return
		var target: Node = player.nearest_interactable()
		if target != null:
			target.interact(self)


# --- gathering ----------------------------------------------------------

func gather_berries(amount: int, world_pos: Vector2) -> void:
	inventory["sunberry"] = int(inventory.get("sunberry", 0)) + amount
	_play_sfx(Sfx.pickup())
	_sparkle(world_pos)
	_refresh_hud()
	_update_quest_from_state()
	_save_game(true)


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


# --- dialogue -----------------------------------------------------------

func talk_to_mira(npc: Node) -> void:
	if battle_active or dialogue_open:
		return
	_mira = npc
	var state := {
		"flags": flags,
		"berries": int(inventory.get("sunberry", 0)),
		"party_size": party.size(),
	}
	var start_id := Dialogues.mira_start_for(state)
	if npc != null and npc.has_method("set_talking"):
		npc.set_talking(true)
	dialogue_open = true
	player.stop()
	hud.hide_prompt()
	dialogue.start(Dialogues.MIRA, start_id, self)


func _on_dialogue_finished() -> void:
	dialogue_open = false
	if _mira != null and is_instance_valid(_mira) and _mira.has_method("set_talking"):
		_mira.set_talking(false)
	_update_quest_from_state()
	_refresh_hud()
	_save_game(true)


# Host API used by the dialogue data (dialogue_box.gd calls these by name).

func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value


func party_size() -> int:
	return party.size()


func give_item(id: String, count: int) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count


func give_tool(id: String) -> void:
	if not tools.has(id):
		tools.append(id)


func get_flags() -> Dictionary:
	return flags


func get_berry_count() -> int:
	return _stock("sunberry")


## Called once a dialogue gift has been handed over: update the HUD and write
## the choice to disk so the one-time offer can never be claimed twice.
func after_gift() -> void:
	_refresh_hud()
	_save_game(true)


func teach_recipe(id: String) -> void:
	if not known.has(id):
		known.append(id)


func play_fx(kind: String) -> void:
	if _mira != null and is_instance_valid(_mira) and _mira.has_method("play_fx"):
		_mira.play_fx(kind)


func start_practice_battle(food_id: String) -> void:
	start_battle(food_id, null, "Chef Mira grins. \"Bluebell, show them what you've got!\"")


# --- cooking ------------------------------------------------------------

func _stock(id: String) -> int:
	return int(inventory.get(id, 0))


func open_cooking(station_id: String) -> void:
	var station := Data.equipment(station_id)
	var methods: Array = Array(station.get("methods", []))
	var recipe_ids := Data.recipes_for(methods)
	var entries: Array = []
	for id: String in recipe_ids:
		var r: Dictionary = Data.recipe(id)
		entries.append({
			"id": "recipe:" + id,
			"name": Data.recipe_name(id),
			"requirement": _requirement_text(r),
			"note": _recipe_note(id, r),
			"chance": _chance_text(id),
			"can_cook": _has_ingredients(r),
		})
	for id: String in Data.INGREDIENTS.keys():
		if _stock(id) <= 0:
			continue
		entries.append({
			"id": "raw:" + id,
			"name": "%s, served as-is" % Data.ingredient_name(id),
			"requirement": "Uses 1 %s and no equipment" % Data.ingredient_name(id),
			"note": "A living single ingredient. Weaker than a dish, but it can still grow.",
			"chance": "100%",
			"can_cook": true,
		})
	var method_text := "-"
	if not methods.is_empty():
		method_text = Data.method_label(String(methods[0]))
	hud.open_cooking(
		String(station.get("name", station_id)),
		"%s   -   %d option%s" % [method_text, entries.size(), "" if entries.size() == 1 else "s"],
		entries
	)


func _requirement_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	var ingredients: Dictionary = r.get("ingredients", {})
	for id: String in ingredients.keys():
		parts.append("%d %s (%d)" % [int(ingredients[id]), Data.ingredient_name(id), _stock(id)])
	return "Needs " + ", ".join(parts)


func _recipe_note(recipe_id: String, r: Dictionary) -> String:
	var note := String(r.get("hint", ""))
	if _is_mastered(recipe_id):
		return note + "  [scroll: guaranteed]"
	if known.has(recipe_id):
		return note + "  [learned]"
	return note + "  [guessing]"


func _has_ingredients(r: Dictionary) -> bool:
	var ingredients: Dictionary = r.get("ingredients", {})
	for id: String in ingredients.keys():
		if _stock(id) < int(ingredients[id]):
			return false
	return true


func _consume(r: Dictionary) -> void:
	var ingredients: Dictionary = r.get("ingredients", {})
	for id: String in ingredients.keys():
		inventory[id] = maxi(0, _stock(id) - int(ingredients[id]))


func _is_mastered(recipe_id: String) -> bool:
	return mastered.has(recipe_id)


## Success chance for an attempt. Scrolls bypass this entirely and are the only
## guaranteed route; knowledge and practice only raise the odds (cap 95%).
func _cook_chance(recipe_id: String) -> float:
	if _is_mastered(recipe_id):
		return 1.0
	var r: Dictionary = Data.recipe(recipe_id)
	var methods: Array = Array(r.get("methods", ["simmer"]))
	var method := String(methods[0])
	var prof := float(proficiency.get(method, 0.0))
	var chance := 0.45 + prof * 0.03 + (0.20 if known.has(recipe_id) else 0.0) - float(r.get("difficulty", 1)) * 0.05
	return clampf(chance, 0.15, 0.95)


func _chance_text(recipe_id: String) -> String:
	if _is_mastered(recipe_id):
		return "100% scroll"
	return "%d%%" % int(round(_cook_chance(recipe_id) * 100.0))


func _on_cook_requested(choice_id: String) -> void:
	if choice_id.begins_with("raw:"):
		_serve_raw(choice_id.substr(4))
		return
	var recipe_id := choice_id.trim_prefix("recipe:")
	var r: Dictionary = Data.recipe(recipe_id)
	if r.is_empty():
		return
	if not _has_ingredients(r):
		hud.toast("Not enough ingredients for %s." % Data.recipe_name(recipe_id), 2.5)
		_play_sfx(Sfx.fail())
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
		_play_sfx(Sfx.confirm())
		hud.toast("%s is ready! It hops into your party." % Data.food_name(food_id), 3.2)
	else:
		# Failure is informative, not punitive: some practice, and part back.
		proficiency[method] = float(proficiency.get(method, 0.0)) + 0.5
		var ingredients: Dictionary = r.get("ingredients", {})
		var recovered := false
		for id: String in ingredients.keys():
			if randf() < 0.5:
				inventory[id] = _stock(id) + 1
				recovered = true
		_play_sfx(Sfx.fail())
		if recovered:
			hud.toast("The dish collapses, but you salvage an ingredient. Practice +1.", 3.4)
		else:
			hud.toast("The dish collapses. You learned where it went wrong.", 3.2)
	hud.close_cooking()
	_update_quest_from_state()
	_refresh_hud()
	_save_game(true)


func _serve_raw(ingredient_id: String) -> void:
	if _stock(ingredient_id) <= 0:
		return
	var food_id := ingredient_id
	if ingredient_id == "sunberry":
		food_id = "unknown_berry"
	inventory[ingredient_id] = _stock(ingredient_id) - 1
	_add_to_party(food_id)
	_spawn_companion(food_id)
	_play_sfx(Sfx.confirm())
	hud.toast("%s comes to life and joins you." % Data.food_name(food_id), 3.0)
	hud.close_cooking()
	_update_quest_from_state()
	_refresh_hud()
	_save_game(true)


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

func start_battle(food_id: String, encounter: Node, headline: String = "") -> void:
	if party.is_empty():
		hud.toast("You have no dish to fight with. Cook something at the campfire first.", 3.6)
		return
	battle_active = true
	_battle_food = food_id
	hud.hide_prompt()
	player.stop()
	var line := headline
	if line == "":
		line = "A wild %s blocks the trail!" % Data.food_name(food_id)
	battle.start(food_id, party[0], line)


func level_from_xp() -> int:
	return maxi(1, 1 + chef_xp / 40)


func _on_battle_finished(result: String, reward: Dictionary) -> void:
	battle_active = false
	match result:
		"won":
			chef_xp += int(reward.get("xp", 0))
			var new_level := level_from_xp()
			if new_level > chef_level:
				chef_level = new_level
				hud.toast("Chef Level %d! New recipe scrolls will find you." % chef_level, 3.6)
			else:
				hud.toast("%s is out of steam!  +%d Chef XP" % [
					Data.food_name(_battle_food),
					int(reward.get("xp", 0)),
				], 3.6)
			flags["practice_done"] = true
		"lost":
			hud.toast("Your dish fainted. Mira walks you back to the fire.", 3.6)
			player.global_position = _tile_center(CAMPFIRE_TILE) + Vector2(-46, 42)
		_:
			hud.toast("You slipped away through the ferns.", 2.6)
	flags["practice_done"] = bool(flags.get("practice_done", false))
	_battle_food = ""
	_update_quest_from_state()
	_refresh_hud()
	_save_game(true)


# --- quest --------------------------------------------------------------

func _update_quest_from_state() -> void:
	var berries := _stock("sunberry")
	if not bool(flags.get("met_mira", false)):
		quest = "intro"
	elif not bool(flags.get("gift_given", false)):
		quest = "berries" if berries < 3 else "cook"
	elif party.is_empty():
		quest = "cook"
	elif not bool(flags.get("practice_done", false)):
		quest = "battle"
	else:
		quest = "done"


func _quest_text() -> String:
	match quest:
		"intro":
			return "Talk to Chef Mira by the campfire."
		"berries":
			return "Gather 3 red berries  (%d/3)" % mini(_stock("sunberry"), 3)
		"cook":
			return "Cook something at the campfire. Roasting works too."
		"battle":
			return "Return to Mira for a friendly practice match."
		_:
			return "Explore Sunberry Hollow. The path leads east."


# --- saving -------------------------------------------------------------

func _state_dict() -> Dictionary:
	return {
		"inventory": inventory.duplicate(true),
		"tools": tools.duplicate(),
		"party": party.duplicate(),
		"flags": flags.duplicate(true),
		"quest": quest,
		"known": known.duplicate(),
		"mastered": mastered.duplicate(),
		"proficiency": proficiency.duplicate(true),
		"chef_xp": chef_xp,
		"chef_level": chef_level,
		"text_speed": text_speed,
		"player": [player.global_position.x, player.global_position.y],
	}


func _save_game(silent := false) -> void:
	if SaveFile.save(_state_dict()):
		if not silent:
			hud.toast("Progress saved.", 1.6)
			_play_sfx(Sfx.confirm())
	else:
		hud.toast("Could not write the save file.", 2.2)


func _load_game() -> bool:
	var state: Dictionary = SaveFile.load_state()
	if state.is_empty():
		return false
	inventory = Dictionary(state.get("inventory", inventory))
	tools = _string_array(state.get("tools", []))
	party = _string_array(state.get("party", []))
	flags = Dictionary(state.get("flags", {}))
	known = _string_array(state.get("known", []))
	mastered = _string_array(state.get("mastered", []))
	proficiency = Dictionary(state.get("proficiency", proficiency))
	chef_xp = int(state.get("chef_xp", 0))
	chef_level = int(state.get("chef_level", 1))
	text_speed = int(state.get("text_speed", 1))
	quest = String(state.get("quest", "intro"))
	var pos: Array = Array(state.get("player", []))
	if pos.size() == 2:
		player.global_position = Vector2(float(pos[0]), float(pos[1]))
	if not party.is_empty():
		_spawn_companion(party[0])
	return true


func _string_array(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for v: Variant in Array(raw):
			out.append(String(v))
	return out


func _on_text_speed_changed(index: int) -> void:
	text_speed = clampi(index, 0, 2)
	dialogue.set_speed_index(text_speed)
	_save_game(true)


func _play_sfx(stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -8.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# --- hud ----------------------------------------------------------------

func _refresh_hud() -> void:
	hud.set_berries(_stock("sunberry"))
	hud.set_quest(_quest_text())
	var lines: Array[String] = []
	if not party.is_empty():
		for id: String in party:
			lines.append(Data.food_name(id))
	if not tools.is_empty():
		var tool_names: Array[String] = []
		for id: String in tools:
			tool_names.append(Data.tool_name(id))
		lines.append("- " + ", ".join(tool_names))
	if lines.is_empty():
		hud.set_party("Party: empty")
	else:
		hud.set_party("\n".join(lines))


func _stats_text() -> String:
	var party_text := "empty"
	if not party.is_empty():
		var names: Array[String] = []
		for id: String in party:
			names.append(Data.food_name(id))
		party_text = ", ".join(names)
	var tool_text := "none"
	if not tools.is_empty():
		var names2: Array[String] = []
		for id: String in tools:
			names2.append(Data.tool_name(id))
		tool_text = ", ".join(names2)
	var stock: Array[String] = []
	for id: String in Data.INGREDIENTS.keys():
		if _stock(id) > 0:
			stock.append("%d %s" % [_stock(id), Data.ingredient_name(id)])
	var stock_text := "nothing"
	if not stock.is_empty():
		stock_text = ", ".join(stock)
	return "Chef Level %d   (%d XP)\n\nPantry: %s\nTools: %s\n\nDishes: %s\n\nSimmering practice: %d   Roasting practice: %d\nRecipes mastered: %d" % [
		chef_level, chef_xp, stock_text, tool_text, party_text,
		int(proficiency.get("simmer", 0.0)), int(proficiency.get("roast", 0.0)), mastered.size(),
	]
