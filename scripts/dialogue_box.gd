extends CanvasLayer
## Runtime + UI for data-driven dialogue.
##
## The graph lives in Dialogues (data). This node walks it: reveals lines with a
## typewriter, offers choices that satisfy their conditions, and asks the host
## (the game) to apply rewards, flags and battles. No dialogue text is hardcoded
## here, so any future NPC can reuse this box by handing it another graph.
##
## Presentation: one large illustrated portrait stands beside the text, on the
## left or the right depending on who is speaking. Portraits slide and fade in,
## swap expressions mid-conversation, breathe gently, and hide for narration.

signal finished

const Fonts := preload("res://starter/ui-fonts/fonts.gd")

const INK := Color(0.24, 0.16, 0.11)
const INK_SOFT := Color(0.35, 0.26, 0.19)
const PAPER := Color(0.99, 0.96, 0.88)
const PAPER_DARK := Color(0.93, 0.88, 0.76)
const TRIM := Color(0.45, 0.29, 0.18)
const TRIM_LIGHT := Color(0.78, 0.64, 0.41)
const HONEY := Color(0.99, 0.80, 0.44)
const FRAME_BG := Color(0.14, 0.11, 0.09)

## Characters per second for the reveal (index 0 slow, 1 normal, 2 fast).
const SPEED_CHARS := [22.0, 42.0, 78.0]

## Layout, in the project's 640x360 base resolution.
const SCREEN_W := 640.0
const MARGIN := 14.0
const PANEL_TOP := -126.0
const PANEL_BOTTOM := -12.0
## 3:4 to match the generated art exactly, so nothing is cropped.
const FRAME_W := 150.0
const FRAME_H := 200.0
## The card stands tall and overlaps the panel's top edge by a few pixels.
const FRAME_BOTTOM := -84.0
const FRAME_X := 22.0
const FRAME_SLIDE := 28.0

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

var _speaker := ""
var _expression := ""
var _side := ""

var root: Control
var panel: PanelContainer
var portrait_frame: Panel
var portrait_rect: TextureRect
var portrait_border: Panel
var name_plate: PanelContainer
var name_label: Label
var body: Label
var arrow: Label
var choices_box: VBoxContainer
var hint_label: Label
var player: AudioStreamPlayer
var _bob: Tween
var _slide: Tween


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


## The main story panel: generous left padding leaves room for the portrait.
func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.border_color = TRIM
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.content_margin_left = 176
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0.12, 0.07, 0.03, 0.34)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 3)
	return s


func _frame_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FRAME_BG
	s.border_color = TRIM
	s.set_border_width_all(3)
	s.set_corner_radius_all(9)
	s.shadow_color = Color(0.12, 0.07, 0.03, 0.38)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


## Drawn over the portrait so the frame edge is never hidden by the image.
func _frame_border_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = TRIM_LIGHT
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	s.draw_center = false
	s.expand_margin_left = -3
	s.expand_margin_right = -3
	s.expand_margin_top = -3
	s.expand_margin_bottom = -3
	return s


func _plate_style(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = accent
	s.border_color = accent.darkened(0.35)
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	s.shadow_color = Color(0.12, 0.07, 0.03, 0.22)
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 1)
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
	b.add_theme_stylebox_override("normal", _style(PAPER, TRIM.lerp(PAPER, 0.5), 6, 9))
	b.add_theme_stylebox_override("hover", _style(HONEY, TRIM, 6, 9))
	b.add_theme_stylebox_override("pressed", _style(HONEY.darkened(0.15), TRIM, 6, 9))
	b.add_theme_stylebox_override("focus", _style(HONEY, TRIM, 6, 9))
	return b


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# --- choice list: stacked above the panel, clear of the portrait -----
	choices_box = VBoxContainer.new()
	choices_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	choices_box.offset_left = 196
	choices_box.offset_top = -268
	choices_box.offset_right = 520
	choices_box.offset_bottom = -138
	choices_box.add_theme_constant_override("separation", 4)
	choices_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(choices_box)

	# --- portrait --------------------------------------------------------
	portrait_frame = Panel.new()
	portrait_frame.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	portrait_frame.offset_left = FRAME_X
	portrait_frame.offset_right = FRAME_X + FRAME_W
	portrait_frame.offset_top = FRAME_BOTTOM - FRAME_H
	portrait_frame.offset_bottom = FRAME_BOTTOM
	portrait_frame.clip_contents = true
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", _frame_style())
	portrait_frame.visible = false
	root.add_child(portrait_frame)

	portrait_rect = TextureRect.new()
	portrait_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait_rect)

	portrait_border = Panel.new()
	portrait_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_border.add_theme_stylebox_override("panel", _frame_border_style())
	portrait_frame.add_child(portrait_border)

	# --- text panel ------------------------------------------------------
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = MARGIN
	panel.offset_right = -MARGIN
	panel.offset_top = PANEL_TOP
	panel.offset_bottom = PANEL_BOTTOM
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	col.add_child(name_row)

	name_plate = PanelContainer.new()
	name_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_plate.add_theme_stylebox_override("panel", _plate_style(TRIM))
	name_row.add_child(name_plate)

	name_label = Fonts.label("", 10, PAPER, Fonts.display(700))
	name_plate.add_child(name_label)

	body = Fonts.label("", 11, INK, Fonts.sans(600))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(0, 54)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.add_theme_constant_override("line_spacing", 2)
	col.add_child(body)

	var foot := HBoxContainer.new()
	col.add_child(foot)

	hint_label = Fonts.label("E next   1-3 choose   Esc close", 8, INK_SOFT, Fonts.sans(600))
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(hint_label)

	arrow = Fonts.label("\u25BC", 10, TRIM, Fonts.sans(800))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(arrow)

	# The portrait card is drawn last so it stands in front of the text panel
	# instead of being covered by its opaque background.
	root.move_child(portrait_frame, root.get_child_count() - 1)


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
	_speaker = ""
	_expression = ""
	_side = ""
	portrait_frame.visible = false
	portrait_frame.modulate.a = 1.0
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
	var narration := Portraits.is_narration(who)
	var expr := String(line.get("expr", "neutral"))
	var side := String(line.get("side", Portraits.default_side(who)))

	body.text = String(line.get("text", ""))
	body.visible_characters = 0
	_chars = 0.0
	_typing = true
	arrow.visible = false
	hint_label.text = "E next   Esc close"

	if narration:
		name_plate.visible = false
		_hide_portrait()
	else:
		name_plate.visible = true
		name_plate.add_theme_stylebox_override("panel", _plate_style(Portraits.accent(who)))
		name_label.text = Portraits.display_name(who)
		_show_portrait(who, expr, side)

	if line.has("fx") and host != null:
		host.play_fx(String(line["fx"]))


# --- portrait presentation ---------------------------------------------

func _show_portrait(who: String, expr: String, side: String) -> void:
	var id := Portraits.character(who)
	var expression := Portraits.canonical(who, expr)
	var tex := Portraits.texture(who, expression)

	# illustrated art is smooth, the procedural fallback is pixel art
	portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR \
		if Portraits.is_illustrated(who, expression) else CanvasItem.TEXTURE_FILTER_NEAREST

	var same_speaker := id == _speaker
	var side_changed := side != _side and not _side.is_empty()

	_speaker = id
	_side = side
	var expression_changed := expression != _expression
	_expression = expression

	if same_speaker and not side_changed:
		portrait_frame.visible = true
		if expression_changed:
			_swap_texture(tex)
		return

	portrait_rect.texture = tex
	portrait_frame.visible = true
	_slide_to_side(side)
	_start_bob()


## Fade the current frame out and back in with the new expression.
func _swap_texture(tex: Texture2D) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(portrait_rect, "modulate:a", 0.0, 0.07)
	_slide.tween_callback(func() -> void: portrait_rect.texture = tex)
	_slide.tween_property(portrait_rect, "modulate:a", 1.0, 0.12)


func _slide_to_side(side: String) -> void:
	var target_left := FRAME_X if side == "left" else SCREEN_W - FRAME_X - FRAME_W
	var entry_left := target_left + (-FRAME_SLIDE if side == "left" else FRAME_SLIDE)
	if _slide != null and _slide.is_valid():
		_slide.kill()
	portrait_frame.offset_left = entry_left
	portrait_frame.offset_right = entry_left + FRAME_W
	portrait_frame.modulate.a = 0.0
	portrait_rect.modulate.a = 1.0
	_slide = create_tween().set_parallel(true)
	_slide.tween_property(portrait_frame, "offset_left", target_left, 0.26) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(portrait_frame, "offset_right", target_left + FRAME_W, 0.26) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(portrait_frame, "modulate:a", 1.0, 0.2)


## Very slight breathing so the illustration is not a dead rectangle.
func _start_bob() -> void:
	if _bob != null and _bob.is_valid():
		_bob.kill()
	portrait_rect.offset_top = 0.0
	portrait_rect.offset_bottom = 0.0
	_bob = create_tween().set_loops()
	_bob.tween_property(portrait_rect, "offset_top", 2.0, 1.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(portrait_rect, "offset_top", 0.0, 1.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hide_portrait() -> void:
	if not portrait_frame.visible:
		return
	_speaker = ""
	_expression = ""
	_side = ""
	if _bob != null and _bob.is_valid():
		_bob.kill()
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(portrait_frame, "modulate:a", 0.0, 0.16)
	_slide.tween_callback(func() -> void: portrait_frame.visible = false)


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
	if _bob != null and _bob.is_valid():
		_bob.kill()
	if _slide != null and _slide.is_valid():
		_slide.kill()
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
