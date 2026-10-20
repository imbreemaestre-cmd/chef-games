class_name Data
extends RefCounted
## Content database for Sunberry Hollow: ingredients, tools, equipment,
## recipes, foods and battle moves. Everything the cooking and battle systems
## need is data here, so new dishes are added without touching gameplay code.

# --- flavour triangle ---------------------------------------------------
# Documented rule: sweet > savoury > fresh > sweet.
# 1.25x damage when strong against the defender, 0.8x when weak.
# "hot" is a neutral flavour used by roasted dishes: it neither resists nor
# counters the triangle yet, so roasting is a safe, steady opening choice.
const FLAVOUR_STRONG := {
	"sweet": "savoury",
	"savoury": "fresh",
	"fresh": "sweet",
}

# The starting berries stay a mystery: only `secret` records what they are.
const INGREDIENTS := {
	"sunberry": {
		"name": "??? Berry",
		"flavour": "sweet",
		"quality": 1.0,
		"desc": "It's red. It's round. You're reasonably certain it's a berry.",
		"secret": "Hawthorn Berry",
	},
	"sugar": {
		"name": "Sugar Cube",
		"flavour": "sweet",
		"quality": 1.0,
		"desc": "A hard white cube that dissolves into almost anything.",
	},
	"orange": {
		"name": "Orange",
		"flavour": "fresh",
		"quality": 1.1,
		"desc": "Bright, juicy and slightly too big for one hand.",
	},
}

# Reusable tools are separate from ingredients: tools are never consumed.
const TOOLS := {
	"bowl": {
		"name": "Bowl",
		"desc": "A plain ceramic mixing bowl. Reusable.",
	},
	"spoon": {
		"name": "Spoon",
		"desc": "A wooden spoon worn smooth by stirring. Reusable.",
	},
}

# --- cooking equipment --------------------------------------------------
# A station only needs the method; access vs ownership is tracked separately.
const EQUIPMENT := {
	"campfire": {
		"name": "Campfire",
		"methods": ["simmer", "roast"],
		"desc": "An open flame with a flat stone beside it. Good for simmering and roasting.",
	},
	"stove": {
		"name": "Stove",
		"methods": ["simmer", "fry", "boil"],
		"desc": "A kitchen range for frying and boiling.",
	},
	"oven": {
		"name": "Oven",
		"methods": ["bake", "roast"],
		"desc": "Dry, even heat for baking and roasting.",
	},
	"deep_fryer": {
		"name": "Deep Fryer",
		"methods": ["fry"],
		"desc": "A basket of hot oil. Anything can become crispy.",
	},
}

const METHOD_LABEL := {
	"simmer": "Simmering",
	"roast": "Roasting",
	"bake": "Baking",
	"fry": "Frying",
	"boil": "Boiling",
	"steam": "Steaming",
	"grill": "Grilling",
}

# --- recipes ------------------------------------------------------------
# `scroll` marks a recipe the player starts with mastered (100% success).
# Everything else can still be attempted: knowledge raises the odds, a
# scroll is the only guarantee.
const RECIPES := {
	"berry_compote": {
		"name": "Berry Compote",
		"result": "berry_compote",
		"ingredients": {"sunberry": 3, "sugar": 1, "orange": 1},
		"methods": ["simmer"],
		"difficulty": 1,
		"scroll": false,
		"hint": "Berries, sugar and a squeeze of orange, simmered until glossy.",
	},
	"roasted_berries": {
		"name": "Roasted Berries",
		"result": "roasted_berries",
		"ingredients": {"sunberry": 2},
		"methods": ["roast"],
		"difficulty": 0,
		"scroll": false,
		"hint": "Two berries held over the flame until their skins blister. Hot type.",
	},
}

# --- battle moves -------------------------------------------------------
const MOVES := {
	"berry_splash": {
		"name": "Berry Splash",
		"power": 6,
		"kind": "attack",
		"flavour": "sweet",
		"uses": 0,
		"text": "%s flicks a spray of hot berry juice!",
	},
	"compote_burst": {
		"name": "Compote Burst",
		"power": 12,
		"kind": "attack",
		"flavour": "sweet",
		"uses": 2,
		"text": "%s bubbles over and bursts in a wave of compote!",
	},
	"simmer_guard": {
		"name": "Simmer Guard",
		"power": 0,
		"kind": "guard",
		"flavour": "sweet",
		"uses": 0,
		"text": "%s settles low and thickens its skin.",
	},
	"roast_toss": {
		"name": "Scorch Toss",
		"power": 8,
		"kind": "attack",
		"flavour": "hot",
		"uses": 0,
		"text": "%s flicks a blistering berry at its rival!",
	},
	"smoulder_wrap": {
		"name": "Smoulder Wrap",
		"power": 0,
		"kind": "guard",
		"flavour": "hot",
		"uses": 0,
		"text": "%s pulls its charred skin tight and smoulders quietly.",
	},
	"pip_pelt": {
		"name": "Pip Pelt",
		"power": 5,
		"kind": "attack",
		"flavour": "fresh",
		"uses": 0,
		"text": "%s spits a volley of hard little pips!",
	},
	"raw_guard": {
		"name": "Skin Guard",
		"power": 0,
		"kind": "guard",
		"flavour": "fresh",
		"uses": 0,
		"text": "%s tightens its shiny skin.",
	},
	"sugar_dust": {
		"name": "Sugar Dust",
		"power": 5,
		"kind": "attack",
		"flavour": "sweet",
		"uses": 0,
		"text": "%s scatters a choking cloud of sugar!",
	},
	"crystal_guard": {
		"name": "Crystal Guard",
		"power": 0,
		"kind": "guard",
		"flavour": "sweet",
		"uses": 0,
		"text": "%s hardens into a stubborn little crystal.",
	},
	"citrus_squirt": {
		"name": "Citrus Squirt",
		"power": 6,
		"kind": "attack",
		"flavour": "fresh",
		"uses": 0,
		"text": "%s fires a stinging jet of juice!",
	},
	"zest_guard": {
		"name": "Zest Guard",
		"power": 0,
		"kind": "guard",
		"flavour": "fresh",
		"uses": 0,
		"text": "%s thickens its peel and braces.",
	},
	"tart_toss": {
		"name": "Tart Toss",
		"power": 6,
		"kind": "attack",
		"flavour": "sweet",
		"uses": 0,
		"text": "%s flings a wedge of pastry!",
	},
	"crumble_blast": {
		"name": "Crumble Blast",
		"power": 11,
		"kind": "attack",
		"flavour": "sweet",
		"uses": 2,
		"text": "%s shatters its crust edge into a crumb storm!",
	},
	"pastry_guard": {
		"name": "Pastry Guard",
		"power": 0,
		"kind": "guard",
		"flavour": "sweet",
		"uses": 0,
		"text": "%s folds its crust over itself.",
	},
}

# --- foods: the battlers are the literal dishes -------------------------
const FOODS := {
	"berry_compote": {
		"name": "Berry Compote",
		"flavour": "sweet",
		"method": "simmer",
		"hp": 34,
		"atk": 8,
		"def": 6,
		"spd": 7,
		"quality": "Standard",
		"moves": ["berry_splash", "compote_burst", "simmer_guard"],
		"blurb": "A glossy bowl of stewed berries, still bubbling gently.",
	},
	"roasted_berries": {
		"name": "Roasted Berries",
		"flavour": "hot",
		"method": "roast",
		"hp": 28,
		"atk": 8,
		"def": 5,
		"spd": 8,
		"quality": "Standard",
		"moves": ["roast_toss", "berry_splash", "smoulder_wrap"],
		"blurb": "Blistered berries on a hot stone. They steam when they move.",
	},
	"unknown_berry": {
		"name": "??? Berry",
		"flavour": "fresh",
		"method": "raw",
		"hp": 24,
		"atk": 6,
		"def": 4,
		"spd": 9,
		"quality": "Standard",
		"moves": ["pip_pelt", "berry_splash", "raw_guard"],
		"blurb": "One red berry, standing on its own. Nobody trained it.",
	},
	"sugar_cube": {
		"name": "Sugar Cube",
		"flavour": "sweet",
		"method": "raw",
		"hp": 20,
		"atk": 5,
		"def": 7,
		"spd": 4,
		"quality": "Standard",
		"moves": ["sugar_dust", "crystal_guard"],
		"blurb": "A hard white cube that hums faintly when prodded.",
	},
	"orange": {
		"name": "Orange",
		"flavour": "fresh",
		"method": "raw",
		"hp": 26,
		"atk": 7,
		"def": 5,
		"spd": 6,
		"quality": "Standard",
		"moves": ["citrus_squirt", "zest_guard"],
		"blurb": "A whole orange, rolling on its own and leaking a little juice.",
	},
	"blueberry_tart": {
		"name": "Blueberry Tart",
		"flavour": "sweet",
		"method": "bake",
		"hp": 26,
		"atk": 6,
		"def": 4,
		"spd": 5,
		"quality": "Standard",
		"moves": ["tart_toss", "crumble_blast", "pastry_guard"],
		"blurb": "Mira's own bake. Blueberries still glisten under the lattice.",
	},
	"blackberry_tart": {
		"name": "Blackberry Tart",
		"flavour": "sweet",
		"method": "bake",
		"hp": 32,
		"atk": 7,
		"def": 5,
		"spd": 6,
		"quality": "Standard",
		"moves": ["tart_toss", "crumble_blast", "pastry_guard"],
		"blurb": "A lattice tart left to cool on a windowsill. It did not stay put.",
	},
}

const QUALITY_ORDER := ["Poor", "Standard", "Excellent", "Masterwork"]


static func ingredient(id: String) -> Dictionary:
	return INGREDIENTS.get(id, {})


static func ingredient_name(id: String) -> String:
	return String(INGREDIENTS.get(id, {}).get("name", id))


static func tool(id: String) -> Dictionary:
	return TOOLS.get(id, {})


static func tool_name(id: String) -> String:
	return String(TOOLS.get(id, {}).get("name", id))


static func equipment(id: String) -> Dictionary:
	return EQUIPMENT.get(id, {})


static func recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})


static func recipe_name(id: String) -> String:
	return String(RECIPES.get(id, {}).get("name", id))


static func food(id: String) -> Dictionary:
	return FOODS.get(id, {})


static func food_name(id: String) -> String:
	return String(FOODS.get(id, {}).get("name", id))


static func move(id: String) -> Dictionary:
	return MOVES.get(id, {})


static func method_label(id: String) -> String:
	return String(METHOD_LABEL.get(id, id.capitalize()))


## Damage multiplier for an attacking flavour against a defending flavour.
static func effectiveness(attack_flavour: String, defend_flavour: String) -> float:
	if String(FLAVOUR_STRONG.get(attack_flavour, "")) == defend_flavour:
		return 1.25
	if String(FLAVOUR_STRONG.get(defend_flavour, "")) == attack_flavour:
		return 0.8
	return 1.0


## Core damage formula. Declared here so the UI can preview it and the battle
## system has exactly one implementation.
static func damage(power: int, attack: int, defence: int, atk_flavour: String, def_flavour: String, roll: int) -> int:
	var raw := float(power) + float(attack) * 0.65 - float(defence) * 0.45
	raw *= effectiveness(atk_flavour, def_flavour)
	raw += float(roll)
	return maxi(1, int(round(raw)))


## Recipes the given station can attempt.
static func recipes_for(method_list: Array) -> Array:
	var out: Array = []
	for id: String in RECIPES.keys():
		var r: Dictionary = RECIPES[id]
		for m: String in r.get("methods", []):
			if method_list.has(m) and not out.has(id):
				out.append(id)
	return out
