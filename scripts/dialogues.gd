class_name Dialogues
extends RefCounted
## Dialogue for Sunberry Hollow as data.
##
## A dialogue is a dictionary of nodes. Each node is:
##   lines   Array of {who, text, fx?}   -- `who` is a portrait id ("mira", "you")
##   next    id of the node that follows the lines (optional)
##   choices Array of choice dictionaries (optional; takes priority over `next`)
##   set     flag set when the node is entered
##   end     true when the conversation closes after this node
##
## A choice is:
##   text        button label
##   next        node id to continue to
##   if          {flag, not_flag, berries, party} requirement to show it
##   give        {ingredient_id: count}
##   give_tools  [tool_id, ...]
##   teach       recipe id added to the player's knowledge
##   flag        flag set when chosen
##   battle      food id: starts a practice battle
##   end         close the conversation
##
## The runtime that walks this data lives in dialogue_box.gd. Nothing here
## knows about movement, cooking or the scene tree.

const MIRA := {
	"start": "wake",
	"wake": {
		"set": "met_mira",
		"lines": [
			{"who": "mira", "text": "Oh, you're awake! I was beginning to think you'd sleep through breakfast."},
			{"who": "you", "text": "Where am I?"},
			{"who": "mira", "text": "Sunberry Hollow. You must be new to these parts. Are you a chef?"},
			{"who": "you", "text": "I'm learning."},
			{"who": "mira", "text": "Good. The world could use more cooks who are willing to learn."},
			{"who": "you", "text": "Why's that?"},
			{"who": "mira", "text": "Because around here, a good meal doesn't just fill your stomach. Sometimes, it gets up and walks away.", "fx": "tart_excited"},
			{"who": "you", "text": "...Did that tart just move?", "fx": "tart_wobble"},
			{"who": "mira", "text": "Of course. I baked her this morning. Her name is Bluebell, and she has opinions."},
			{"who": "mira", "text": "Now, why don't you gather three of those red berries? We can make something of them."},
		],
		"next": "quest_start",
	},
	"quest_start": {
		"lines": [
			{"who": "mira", "text": "There's a good patch of them just south of here. Three should do."},
			{"who": "you", "text": "What kind of berries are they?"},
			{"who": "mira", "text": "You tell me. A cook who tastes before they trust is a cook who learns."},
		],
		"end": true,
	},

	# --- the player has gathered berries and comes back -------------------
	"berries_return": {
		"lines": [
			{"who": "mira", "text": "Three berries! Not bad. Do you know what kind they are?"},
			{"who": "you", "text": "They're... berries."},
			{"who": "mira", "text": "An astonishing observation. Culinary school is going to love you."},
			{"who": "mira", "text": "Keep them. You'll want something to cook with. And here - take a little something from my pack."},
		],
		"next": "gift_choice",
	},
	"gift_choice": {
		"lines": [
			{"who": "mira", "text": "Only one, mind. A travelling chef counts her supplies."},
		],
		"choices": [
			{
				"text": "Sugar Cube and an Orange",
				"next": "got_ingredients",
				"give": {"sugar": 1, "orange": 1},
				"flag": "gift_ingredients",
			},
			{
				"text": "Bowl and Spoon",
				"next": "got_tools",
				"give_tools": ["bowl", "spoon"],
				"flag": "gift_tools",
			},
		],
	},
	"got_ingredients": {
		"set": "gift_given",
		"lines": [
			{"who": "mira", "text": "Sugar and an orange. Sugar sweetens, orange brightens. Put them with those berries and you have a compote."},
			{"who": "you", "text": "A compote."},
			{"who": "mira", "text": "Simmered, glossy, and - if you do it right - alive enough to have an opinion."},
		],
		"next": "cook_hint",
	},
	"got_tools": {
		"set": "gift_given",
		"lines": [
			{"who": "mira", "text": "A bowl and a spoon. Boring, you're thinking. Boring is reusable."},
			{"who": "mira", "text": "You'll never lose them, and you'll never have to buy them again. My sugar, on the other hand, gets eaten."},
		],
		"next": "cook_hint",
	},
	"cook_hint": {
		"lines": [
			{"who": "mira", "text": "The campfire behind you will do for a kitchen. Two ways to start, both fair."},
			{"who": "mira", "text": "Simmer three berries with sugar and orange for a compote. Or hold two over the flame and roast them hot."},
			{"who": "mira", "text": "Or keep one berry back and see what it does when it stands on its own. Ingredients have minds here."},
			{"who": "mira", "text": "Come back when you've cooked something and I'll show you what a friendly match looks like."},
		],
		"end": true,
	},

	# --- conversation after the gift --------------------------------------
	"check_in": {
		"lines": [
			{"who": "mira", "text": "How's the cooking going? Don't answer that if the answer is smoke."},
		],
		"choices": [
			{"text": "Let's cook something.", "next": "cook_hint"},
			{"text": "About that tart...", "next": "about_tart"},
			{"text": "Just passing through.", "end": true},
		],
	},
	"about_tart": {
		"lines": [
			{"who": "mira", "text": "Baked this morning, and she's been bouncing ever since. Fresh pastry is like that."},
			{"who": "mira", "text": "A dish that's made well enough to matter will get up and move. A careless one just sits there."},
			{"who": "mira", "text": "That's the whole trade, really. Not levels. Care."},
		],
		"next": "check_in",
	},

	# --- optional practice battle ----------------------------------------
	"offer_battle": {
		"lines": [
			{"who": "mira", "text": "Look at that! Your first dish is alive. Now, shall we see what it can do?"},
		],
		"choices": [
			{"text": "Let's battle!", "battle": "blueberry_tart", "flag": "practice_done"},
			{"text": "I'd like to explore first.", "next": "explore_first"},
			{"text": "Why would food fight other food?", "next": "why_fight"},
		],
	},
	"explore_first": {
		"lines": [
			{"who": "mira", "text": "Wise. The forest's kinder before noon. Come back when you want to see Bluebell move."},
		],
		"end": true,
	},
	"why_fight": {
		"lines": [
			{"who": "you", "text": "Why would food fight other food?"},
			{"who": "mira", "text": "Not to hurt each other. To find out what they're made of."},
			{"who": "mira", "text": "Chefs put their dishes against each other in friendly matches. The food learns. And so do the cooks."},
			{"who": "mira", "text": "Nobody here is eaten. That would be rude, and besides, they'd fight back."},
		],
		"next": "offer_battle",
	},
	"after_battle": {
		"lines": [
			{"who": "mira", "text": "There. Bluebell's had her exercise, and your dish learned something it couldn't learn in a pot."},
			{"who": "mira", "text": "Keep practising. The better you cook, the stronger they start."},
		],
		"end": true,
	},
	"reminder": {
		"lines": [
			{"who": "mira", "text": "Berries, remember? Red ones, low bushes, south of the clearing. Three will do."},
			{"who": "you", "text": "Red. Round. Got it."},
			{"who": "mira", "text": "That's the spirit."},
		],
		"end": true,
	},
}


## Pick the node Halee (Mira) should open with, from the player's flags.
static func mira_start_for(state: Dictionary) -> String:
	var flags: Dictionary = state.get("flags", {})
	var berries_held := int(state.get("berries", 0))
	var party_size := int(state.get("party_size", 0))
	if not bool(flags.get("met_mira", false)):
		return "wake"
	if bool(flags.get("practice_done", false)) and party_size > 0:
		return "after_battle"
	if not bool(flags.get("gift_given", false)):
		if berries_held >= 3:
			return "berries_return"
		return "reminder"
	if party_size > 0 and not bool(flags.get("practice_done", false)):
		return "offer_battle"
	if party_size == 0:
		return "cook_hint"
	return "check_in"
