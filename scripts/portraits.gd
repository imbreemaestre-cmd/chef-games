class_name Portraits
extends RefCounted
## Illustrated dialogue portraits.
##
## Overworld sprites stay pixel art (ArtChars). This module is the other half of
## the art direction: painterly, soft-shaded bust portraits used only inside the
## dialogue box.
##
## Files are looked up at res://assets/portraits/<who>/<expression>.png. When a
## file is missing the module degrades honestly instead of crashing: it tries the
## character's neutral expression, then any expression that exists, and finally
## the procedural pixel portrait so a conversation can always be shown.
##
## Adding a character later means adding one entry to EXPRESSIONS and one folder
## of images. Nothing else in the game needs to change.

const DIR := "res://assets/portraits"

## Canonical expression sets, per character.
const EXPRESSIONS := {
	"mira": ["neutral", "smiling", "amused", "worried", "sad", "determined"],
	"you": ["neutral", "confused", "embarrassed", "excited", "angry", "determined"],
	"legendary": ["neutral", "unimpressed", "cold_smile", "irritated", "reflective", "intense"],
}

const NAMES := {
	"mira": "Chef Mira",
	"you": "You",
	"player": "You",
	"legendary": "The Sunbury Chef",
	"narrator": "",
}

## Name-plate tint per speaker. Warm for Mira, forest-green for the player,
## cold slate for the legendary chef.
const ACCENTS := {
	"mira": Color(0.63, 0.28, 0.16),
	"you": Color(0.24, 0.42, 0.30),
	"player": Color(0.24, 0.42, 0.30),
	"legendary": Color(0.20, 0.22, 0.30),
	"narrator": Color(0.42, 0.34, 0.26),
}

## Which side of the screen a speaker stands on when a line does not say.
const SIDES := {
	"mira": "left",
	"legendary": "left",
	"you": "right",
	"player": "right",
	"narrator": "left",
}

## Loose spellings that may appear in dialogue data.
const ALIASES := {
	"smile": "smiling",
	"happy": "smiling",
	"laugh": "amused",
	"laughing": "amused",
	"concerned": "worried",
	"afraid": "worried",
	"crying": "sad",
	"cry": "sad",
	"upset": "sad",
	"angry": "angry",
	"mad": "angry",
	"embarrassed": "embarrassed",
	"shy": "embarrassed",
	"confused": "confused",
	"unsure": "confused",
	"excited": "excited",
	"eager": "excited",
	"serious": "determined",
	"cold": "cold_smile",
	"smug": "cold_smile",
	"annoyed": "irritated",
	"irritated": "irritated",
	"thoughtful": "reflective",
	"melancholy": "reflective",
	"intense": "intense",
	"bored": "unimpressed",
	"flat": "unimpressed",
}

static var _cache := {}


# --- identity ------------------------------------------------------------

## Normalise an id used in dialogue data to a portrait folder name.
static func character(who: String) -> String:
	var id := who.strip_edges().to_lower()
	if id == "player":
		return "you"
	if EXPRESSIONS.has(id):
		return id
	if id == "" or id == "narrator":
		return "narrator"
	return id


static func display_name(who: String) -> String:
	var id := character(who)
	if NAMES.has(id):
		return String(NAMES[id])
	return who.capitalize()


static func accent(who: String) -> Color:
	var id := character(who)
	return ACCENTS.get(id, Color(0.45, 0.29, 0.18))


static func default_side(who: String) -> String:
	return String(SIDES.get(character(who), "left"))


## True for lines that are spoken by nobody (scene description, narration).
static func is_narration(who: String) -> bool:
	var id := who.strip_edges().to_lower()
	return id == "" or id == "narrator" or id == "none"


# --- expressions ---------------------------------------------------------

## Snap an expression name onto this character's canonical set.
static func canonical(who: String, expr: String) -> String:
	var id := character(who)
	var list: Array = EXPRESSIONS.get(id, ["neutral"])
	var want := expr.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if ALIASES.has(want):
		want = String(ALIASES[want])
	if list.has(want):
		return want
	return "neutral"


static func path_for(who: String, expr: String) -> String:
	return "%s/%s/%s.png" % [DIR, character(who), canonical(who, expr)]


## True when at least one illustrated file exists for this character.
static func has_illustration(who: String) -> bool:
	var id := character(who)
	var list: Array = EXPRESSIONS.get(id, [])
	for expr: String in list:
		if ResourceLoader.exists("%s/%s/%s.png" % [DIR, id, expr]):
			return true
	return false


## True when this exact expression is illustrated on disk.
static func has_expression(who: String, expr: String) -> bool:
	return ResourceLoader.exists(path_for(who, expr))


# --- textures ------------------------------------------------------------

## Illustrated portrait for (who, expression). Never returns null.
static func texture(who: String, expr: String) -> Texture2D:
	var key := "%s_%s" % [character(who), canonical(who, expr)]
	if _cache.has(key):
		return _cache[key]

	var tex := _load_illustrated(who, expr)
	if tex == null:
		tex = ArtChars.portrait(character(who))
	_cache[key] = tex
	return tex


static func is_illustrated(who: String, expr: String) -> bool:
	return ResourceLoader.exists(path_for(who, expr))


static func _load_illustrated(who: String, expr: String) -> Texture2D:
	var id := character(who)
	# 1. the requested expression
	var path := path_for(who, expr)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# 2. that character's neutral line
	var neutral_path := "%s/%s/neutral.png" % [DIR, id]
	if ResourceLoader.exists(neutral_path):
		return load(neutral_path) as Texture2D
	# 3. anything else that exists for this character
	var list: Array = EXPRESSIONS.get(id, [])
	for other: String in list:
		var p := "%s/%s/%s.png" % [DIR, id, other]
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null
