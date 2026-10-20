class_name Data
extends RefCounted
## Content database for Sunberry Hollow: ingredients, equipment, recipes,
## foods and battle moves. Everything the cooking and battle systems need is
## data here, so new dishes are added without touching gameplay code.

# --- flavour triangle ---------------------------------------------------
# Documented rule: sweet > savoury > fresh > sweet.
# 1.25x damage when strong against the defender, 0.8x when weak.
const FLAVOUR_STRONG := {
	"sweet": "savoury",
	"savoury": "fresh",
	"fresh": "sweet",
}

const INGREDIENTS := {
	"sunberry": {
		"name": "Sunberry",
		"flavour": "sweet",
		"quality": 1.0,
		"desc": "A warm red forest berry that sweetens any dish.",
	},
}

# --- cooking equipment --------------------------------------------------
# A station only needs the method; access vs ownership is tracked separately.
const EQUIPMENT := {
	"campfire": {
		"name": "Campfire",
		"methods": ["simmer", "roast"],
		"desc": "An open flame. Good for simmering and roasting.",
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
# `scroll` marks a recipe the player starts with mastered (tutorial scroll).
const RECIPES := {
	"berry_compote": {
		"name": "Berry Compote",
		"result": "berry_compote",
		"ingredients": {"sunberry": 3},
		"methods": ["simmer", "roast"],
		"difficulty": 1,
		"scroll": true,
		"hint": "Sunberries collapse into a glossy compote over any open flame.",
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
		"blurb": "A glossy bowl of stewed sunberries, still bubbling gently.",
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


static func equipment(id: String) -> Dictionary:
	return EQUIPMENT.get(id, {})


static func recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})


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


## Recipes the given station can attempt, cheapest requirement first.
static func recipes_for(method_list: Array) -> Array:
	var out: Array = []
	for id: String in RECIPES.keys():
		var r: Dictionary = RECIPES[id]
		for m: String in r.get("methods", []):
			if method_list.has(m) and not out.has(id):
				out.append(id)
	return out
