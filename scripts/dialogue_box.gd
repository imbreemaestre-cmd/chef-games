extends CanvasLayer
## Runtime + UI for data-driven dialogue.
##
## The graph lives in Dialogues (data). This node walks it: reveals lines with a
## typewriter, offers choices that satisfy their conditions, and asks the host
## (the game) to apply rewards, flags and battles. No dialogue text is hardcoded
## here, so any future NPC can reuse this box by handing it another graph.

signal finished

const Fonts := preload("res://starter/ui-fonts/fonts.gd")

const INK := Color(0.24, 0.16, 0.11)
const PAPER := Color(0.99, 0.96, 0.88)
const PAPER_DARK := Color(0.93, 0.88, 0.76)
const TRIM := Color(0.45, 0.29, 0.18)
const HONEY := Color(0.99, 0.80, 0.44)

## Characters per second for the reveal (index 0 slow, 1 normal, 2 fast).
const SPEED_CHARS := [22.0, 42.0, 78.0]

var host: Node
var graph: Dictionary = {}
var open := false

var _node_id := ""
var _lines: Array = []
var _line_index := 0
var _typing := false
var _chars := 0.0
var _blink := 0.0
var _speed_index := 1

var root: Control
var panel: PanelContainer
var portrait: TextureRect
var name_label: Label
var body: Label
var arrow: Label
var choices_box: VBoxContainer
var hint_label: Label
var player: AudioStreamPlayer


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	root.visible = false
	player = AudioStreamPlayer.new()
	player.volume_db = -12.0
	add_child(player)


# --- styling ------------------------------------------------------------

func _style(bg: Color, border: Color, radius: int = 8, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad - 2
	s.content_margin_bottom = pad - 2
	return s


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", Fonts.sans(700))
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_stylebox_override("normal", _style(PAPER_DARK, TRIM.lerp(PAPER, 0.45), 5, 8))
	b.add_theme_stylebox_override("hover", _style(HONEY, TRIM, 5, 8))
	b.add_theme_stylebox_override("pressed", _style(HONEY.darkened(0.15), TRIM, 5, 8))
	b.add_theme_stylebox_override("focus", _style(HONEY, TRIM, 5, 8))
	return b


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# choice list floats above the box so the portrait stays visible
	choices_box = VBoxContainer.new()
	choices_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	choices_box.offset_left = 24
	choices_box.offset_top = -196
	choices_box.offset_right = 400
	choices_box.offset_bottom = -108
	choices_box.add_theme_constant_override("separation", 4)
	choices_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(choices_box)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = -104
	panel.offset_bottom = -10
	panel.add_theme_stylebox_override("panel", _style(PAPER, TRIM, 9, 10))
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(64, 64)
	frame.add_theme_stylebox_override("panel", _style(Color(0.86, 0.80, 0.66), TRIM.lerp(PAPER, 0.4), 6, 3))
	row.add_child(frame)

	portrait = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	name_label = Fonts.label("", 11, TRIM, Fonts.display(700))
	col.add_child(name_label)

	body = Fonts.label("", 11, INK, Fonts.sans(600))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(0, 46)
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	col.add_child(body)

	arrow = Fonts.label("\u25BC", 10, TRIM, Fonts.sans(800))
	arrow.position = Vector2(548, 76)
	panel.add_child(arrow)

	hint_label = Fonts.label("E next   1-3 choose   Esc close", 8, TRIM.lerp(PAPER, 0.35), Fonts.sans(600))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_label.offset_left = -200
	hint_label.offset_top = -16
	hint_label.offset_right = -8
	hint_label.offset_bottom = -2
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(hint_label)


# --- public API ---------------------------------------------------------

func set_speed_index(index: int) -> void:
	_speed_index = clampi(index, 0, SPEED_CHARS.size() - 1)


func is_open() -> bool:
	return open


## Entry point used by the game controller: (graph, start_id, game).
func start(dialogue_graph: Dictionary, start_id: String, game: Node) -> void:
	begin(game, dialogue_graph, start_id)


## Walk a graph from `start_id`. `game` receives add_item(), add_tool(),
## teach_recipe(), set_flag(), start_practice_battle() and play_fx() calls.
func begin(game: Node, dialogue_graph: Dictionary, start_id: String) -> void:
	host = game
	graph = dialogue_graph
	open = true
	root.visible = true
	_start_node(start_id)


func _start_node(node_id: String) -> void:
	var node: Dictionary = graph.get(node_id, {})
	if node.is_empty():
		_finish()
		return
	_node_id = node_id
	if node.has("set") and host != null:
		host.set_flag(String(node["set"]))
	_lines = node.get("lines", [])
	_line_index = 0
	_clear_choices()
	if _lines.is_empty():
		_after_lines(node)
		return
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_line_index]
	var who := String(line.get("who", "mira"))
	name_label.text = "Chef Mira" if who == "mira" else "You"
	portrait.texture = Art.portrait(who)
	body.text = String(line.get("text", ""))
	body.visible_characters = 0
	_chars = 0.0
	_typing = true
	arrow.visible = false
	if line.has("fx") and host != null:
		host.play_fx(String(line["fx"]))


func _advance() -> void:
	if _typing:
		_typing = false
		body.visible_characters = -1
		return
	_blip()
	_line_index += 1
	if _line_index < _lines.size():
		_show_line()
		return
	var node: Dictionary = graph.get(_node_id, {})
	_after_lines(node)


func _after_lines(node: Dictionary) -> void:
	if node.has("choices"):
		_show_choices(node.get("choices", []))
		return
	if node.has("next"):
		_start_node(String(node["next"]))
		return
	_finish()


func _show_choices(choices: Array) -> void:
	_clear_choices()
	var shown := 0
	for choice: Dictionary in choices:
		if not _choice_visible(choice):
			continue
		var b := _button("%d.  %s" % [shown + 1, String(choice.get("text", "?"))])
		b.pressed.connect(_pick.bind(choice))
		choices_box.add_child(b)
		shown += 1
	if shown == 0:
		_finish()
		return
	arrow.visible = false
	hint_label.text = "1-%d choose   Esc close" % shown


func _choice_visible(choice: Dictionary) -> bool:
	var req: Dictionary = choice.get("if", {})
	if req.is_empty():
		return true
	var flags: Dictionary = host.get_flags()
	if req.has("flag") and not bool(flags.get(String(req["flag"]), false)):
		return false
	if req.has("not_flag") and bool(flags.get(String(req["not_flag"]), false)):
		return false
	if req.has("berries") and host.get_berry_count() < int(req["berries"]):
		return false
	if req.has("party") and host.party_size() <= 0:
		return false
	return true


func _pick(choice: Dictionary) -> void:
	if not open:
		return
	player.stream = Sfx.confirm()
	player.play()
	if choice.has("give"):
		var give: Dictionary = choice["give"]
		for id: String in give.keys():
			host.give_item(id, int(give[id]))
	if choice.has("give_tools"):
		for tool_id: String in choice["give_tools"]:
			host.give_tool(tool_id)
	if choice.has("teach"):
		host.teach_recipe(String(choice["teach"]))
	if choice.has("flag"):
		host.set_flag(String(choice["flag"]))
	if choice.has("give") or choice.has("give_tools"):
		if host.has_method("after_gift"):
			host.after_gift()
	if choice.has("battle"):
		var food_id := String(choice["battle"])
		_finish()
		host.start_practice_battle(food_id)
		return
	if bool(choice.get("end", false)):
		_finish()
		return
	_start_node(String(choice.get("next", "")))


func _clear_choices() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()


func _blip() -> void:
	if player == null:
		return
	player.stream = Sfx.talk()
	player.play()


## Public exit used by Escape, and by a choice that ends the conversation.
func close() -> void:
	_finish()


func _finish() -> void:
	if not open:
		return
	open = false
	_typing = false
	root.visible = false
	_clear_choices()
	finished.emit()


# --- frame --------------------------------------------------------------

func _process(delta: float) -> void:
	if not open:
		return
	_blink += delta
	arrow.visible_characters = -1
	if not _typing:
		arrow.visible = true
		arrow.modulate.a = 0.45 + 0.55 * absf(sin(_blink * 3.0))
		return
	var speed: float = SPEED_CHARS[_speed_index]
	_chars += delta * speed
	body.visible_characters = int(_chars)
	if body.visible_characters >= body.text.length():
		_typing = false
		body.visible_characters = -1


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
		return
	if choices_box.get_child_count() > 0:
		if event is InputEventKey and event.pressed and not event.echo:
			var key := (event as InputEventKey).keycode
			var slot := key - KEY_1
			if slot >= 0 and slot < mini(9, choices_box.get_child_count()):
				get_viewport().set_input_as_handled()
				var buttons := choices_box.get_children()
				(buttons[slot] as Button).emit_signal("pressed")
				return
		if event is InputEventMouseButton and event.pressed:
			return
		return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if advance:
		get_viewport().set_input_as_handled()
		_advance()
