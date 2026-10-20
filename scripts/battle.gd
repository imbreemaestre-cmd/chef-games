extends CanvasLayer
## Turn-based 2D battle screen. Both battlers are the literal dishes
## (Berry Compote vs Blackberry Tart): no monsters, no renames.

signal battle_finished(result: String, reward: Dictionary)

const Fonts := preload("res://starter/ui-fonts/fonts.gd")

const INK := Color(0.24, 0.16, 0.11)
const PAPER := Color(0.98, 0.94, 0.84)
const TRIM := Color(0.45, 0.29, 0.18)
const HONEY := Color(0.99, 0.80, 0.44)

var ally: Dictionary = {}
var enemy: Dictionary = {}
var busy := false
var over := false
var result_kind := ""
var reward: Dictionary = {}

var root: Control
var enemy_sprite: TextureRect
var ally_sprite: TextureRect
var enemy_name_label: Label
var enemy_bar: ProgressBar
var enemy_hp_label: Label
var ally_name_label: Label
var ally_bar: ProgressBar
var ally_hp_label: Label
var log_label: Label
var buttons: Array[Button] = []
var result_panel: PanelContainer
var result_title: Label
var result_sub: Label
var continue_button: Button


func _ready() -> void:
	layer = 20
	_build()
	root.visible = false


func _style(bg: Color, border: Color, radius: int = 8, pad: int = 8) -> StyleBoxFlat:
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
	b.custom_minimum_size = Vector2(132, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Fonts.sans(800))
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_stylebox_override("normal", _style(HONEY, TRIM, 6))
	b.add_theme_stylebox_override("hover", _style(HONEY.lightened(0.18), TRIM, 6))
	b.add_theme_stylebox_override("pressed", _style(HONEY.darkened(0.12), TRIM, 6))
	b.add_theme_stylebox_override("disabled", _style(PAPER.darkened(0.12), TRIM.lightened(0.35), 6))
	return b


func _sprite_rect(texture: Texture2D, center: Vector2, box: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = texture
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = box
	tr.position = center - box * 0.5
	return tr


func _card(pos: Vector2, width: float, title_color: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.13, 0.10, 0.09, 0.88), TRIM.lerp(PAPER, 0.25), 7))
	root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	panel.add_child(col)

	var name_label := Fonts.label("", 12, title_color, Fonts.display(700))
	col.add_child(name_label)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 11)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.add_theme_stylebox_override("background", _bar_bg())
	bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.47, 0.80, 0.38)))
	col.add_child(bar)

	var hp := Fonts.label("", 9, Color(0.94, 0.90, 0.82), Fonts.sans(700))
	col.add_child(hp)
	return {"name": name_label, "bar": bar, "hp": hp}


func _bar_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.06, 0.05, 0.95)
	s.set_corner_radius_all(4)
	return s


func _bar_fill(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(4)
	return s


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.11, 0.09, 0.13, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	# warm horizon bands so the arena does not read as a flat void
	var sky_band := ColorRect.new()
	sky_band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sky_band.offset_bottom = 168
	sky_band.color = Color(0.20, 0.16, 0.22, 1.0)
	sky_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky_band)

	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	glow.offset_top = 120
	glow.offset_bottom = 176
	glow.color = Color(0.32, 0.24, 0.24, 1.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)

	var arena := TextureRect.new()
	arena.texture = Art.arena()
	arena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena.stretch_mode = TextureRect.STRETCH_SCALE
	arena.size = Vector2(520, 130)
	arena.position = Vector2(60, 208)
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arena)

	enemy_sprite = _sprite_rect(Art.blackberry_tart(), Vector2(464, 158), Vector2(128, 106))
	root.add_child(enemy_sprite)

	ally_sprite = _sprite_rect(Art.berry_compote(), Vector2(176, 226), Vector2(118, 98))
	root.add_child(ally_sprite)

	var ally_card := _card(Vector2(14, 12), 262, Color(0.80, 0.95, 0.72))
	ally_name_label = ally_card["name"]
	ally_bar = ally_card["bar"]
	ally_hp_label = ally_card["hp"]

	var enemy_card := _card(Vector2(364, 12), 262, Color(1.0, 0.86, 0.72))
	enemy_name_label = enemy_card["name"]
	enemy_bar = enemy_card["bar"]
	enemy_hp_label = enemy_card["hp"]
	enemy_bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.88, 0.42, 0.35)))

	log_label = Fonts.label("", 12, Color(1, 0.97, 0.90), Fonts.sans(700), 4)
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	log_label.offset_top = -100
	log_label.offset_bottom = -66
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(log_label)

	var actions := HBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	actions.offset_top = -58
	actions.offset_bottom = -12
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 6)
	root.add_child(actions)

	for i in range(4):
		var b := _button("")
		b.pressed.connect(_on_action.bind(i))
		actions.add_child(b)
		buttons.append(b)

	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -190
	result_panel.offset_right = 190
	result_panel.offset_top = -86
	result_panel.offset_bottom = 86
	result_panel.add_theme_stylebox_override("panel", _style(Color(0.14, 0.10, 0.08, 0.97), HONEY, 10, 14))
	root.add_child(result_panel)

	var rcol := VBoxContainer.new()
	rcol.alignment = BoxContainer.ALIGNMENT_CENTER
	rcol.add_theme_constant_override("separation", 8)
	result_panel.add_child(rcol)

	result_title = Fonts.label("", 26, Color(1, 0.94, 0.78), Fonts.display(700))
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rcol.add_child(result_title)

	result_sub = Fonts.label("", 11, Color(0.97, 0.92, 0.84), Fonts.sans(700))
	result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_sub.custom_minimum_size = Vector2(330, 0)
	rcol.add_child(result_sub)

	continue_button = _button("Continue")
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(_on_continue)
	rcol.add_child(continue_button)

	result_panel.visible = false


# --- setup --------------------------------------------------------------

func start(enemy_id: String, ally_id: String, headline: String) -> void:
	enemy = _make_battler(enemy_id)
	ally = _make_battler(ally_id)
	busy = false
	over = false
	result_kind = ""
	reward = {}
	result_panel.visible = false
	enemy_sprite.texture = Art.food_texture(enemy_id)
	ally_sprite.texture = Art.food_texture(ally_id)
	enemy_sprite.modulate = Color.WHITE
	ally_sprite.modulate = Color.WHITE
	enemy_sprite.position = Vector2(400, 105)
	ally_sprite.position = Vector2(117, 177)
	root.visible = true
	_layout_buttons()
	_refresh()
	_log(headline)
	_set_busy(false)


func _make_battler(id: String) -> Dictionary:
	var f := Data.food(id)
	var moves: Array = []
	for move_id: String in f.get("moves", []):
		var m := Data.move(move_id)
		moves.append({"id": move_id, "uses": int(m.get("uses", 0))})
	return {
		"id": id,
		"name": String(f.get("name", id)),
		"flavour": String(f.get("flavour", "savoury")),
		"quality": String(f.get("quality", "Standard")),
		"max_hp": int(f.get("hp", 30)),
		"hp": int(f.get("hp", 30)),
		"atk": int(f.get("atk", 7)),
		"def": int(f.get("def", 5)),
		"spd": int(f.get("spd", 6)),
		"level": 1,
		"xp": 0,
		"moves": moves,
		"guard": false,
	}


func _layout_buttons() -> void:
	var moves: Array = ally.get("moves", [])
	for i in range(buttons.size()):
		var b := buttons[i]
		if i < 3 and i < moves.size():
			var entry: Dictionary = moves[i]
			var m := Data.move(String(entry.get("id", "")))
			var label := String(m.get("name", "Move"))
			if int(entry.get("uses", 0)) > 0:
				label += " (%d)" % int(entry["uses"])
			b.text = label
			b.visible = true
		elif i == 3:
			b.text = "Run"
			b.visible = true
		else:
			b.visible = false


func _refresh() -> void:
	enemy_name_label.text = "%s   Lv %d  -  %s" % [String(enemy.get("name", "?")), int(enemy.get("level", 1)), String(enemy.get("quality", ""))]
	enemy_bar.value = 100.0 * float(enemy.get("hp", 0)) / float(maxi(1, int(enemy.get("max_hp", 1))))
	enemy_hp_label.text = "%d / %d HP   %s" % [int(enemy.get("hp", 0)), int(enemy.get("max_hp", 1)), String(enemy.get("flavour", "")).capitalize()]

	ally_name_label.text = "%s   Lv %d  -  %s" % [String(ally.get("name", "?")), int(ally.get("level", 1)), String(ally.get("quality", ""))]
	ally_bar.value = 100.0 * float(ally.get("hp", 0)) / float(maxi(1, int(ally.get("max_hp", 1))))
	ally_hp_label.text = "%d / %d HP   %s" % [int(ally.get("hp", 0)), int(ally.get("max_hp", 1)), String(ally.get("flavour", "")).capitalize()]


func _log(text: String) -> void:
	log_label.text = text


func _set_busy(state: bool) -> void:
	busy = state
	var moves: Array = ally.get("moves", [])
	for i in range(buttons.size()):
		if i < 3 and i < moves.size():
			var entry: Dictionary = moves[i]
			buttons[i].disabled = state or over or (int(entry.get("uses", 0)) == 0 and int(Data.move(String(entry.get("id", ""))).get("uses", 0)) > 0)
		else:
			buttons[i].disabled = state or over


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _roll() -> int:
	return randi_range(-1, 2)


# --- actions ------------------------------------------------------------

func _on_action(index: int) -> void:
	if busy or over:
		return
	if index == 3:
		await _try_run()
		return
	var moves: Array = ally.get("moves", [])
	if index >= moves.size():
		return
	var entry: Dictionary = moves[index]
	var m := Data.move(String(entry.get("id", "")))
	if int(Data.move(String(entry.get("id", ""))).get("uses", 0)) > 0 and int(entry.get("uses", 0)) <= 0:
		return
	_set_busy(true)
	await _use_move(m, entry)


func _use_move(m: Dictionary, entry: Dictionary) -> void:
	var kind := String(m.get("kind", "attack"))
	if kind == "guard":
		ally["guard"] = true
		_log(String(m.get("text", "%s guards.")) % String(ally.get("name", "?")))
		_bounce(ally_sprite, 0.06)
		await _wait(0.55)
		await _enemy_turn()
		return

	var limit := int(m.get("uses", 0))
	if limit > 0:
		entry["uses"] = maxi(0, int(entry.get("uses", 0)) - 1)
	var dmg := Data.damage(int(m.get("power", 5)), int(ally.get("atk", 7)), int(enemy.get("def", 5)), String(m.get("flavour", "savoury")), String(enemy.get("flavour", "savoury")), _roll())
	if bool(enemy.get("guard", false)):
		dmg = maxi(1, int(round(float(dmg) * 0.5)))
		enemy["guard"] = false
	enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - dmg)
	_log(String(m.get("text", "%s attacks!")) % String(ally.get("name", "?")))
	_popup("-%d" % dmg, enemy_sprite.position + Vector2(52, 8), Color(1.0, 0.85, 0.55))
	_recoil(enemy_sprite)
	_flash(enemy_sprite)
	_refresh()
	await _wait(0.75)
	if int(enemy.get("hp", 0)) <= 0:
		_win()
		return
	await _enemy_turn()


func _enemy_turn() -> void:
	if over:
		return
	var moves: Array = enemy.get("moves", [])
	var choice: Dictionary = {}
	var guard_chance := 0.12
	if int(enemy.get("hp", 0)) < int(enemy.get("max_hp", 1)) * 0.35:
		guard_chance = 0.3
	if randf() < guard_chance:
		for e: Dictionary in moves:
			if String(Data.move(String(e.get("id", ""))).get("kind", "")) == "guard":
				choice = e
				break
	if choice.is_empty():
		var usable: Array = []
		for e: Dictionary in moves:
			var m := Data.move(String(e.get("id", "")))
			if String(m.get("kind", "")) == "guard":
				continue
			var limit := int(m.get("uses", 0))
			if limit > 0 and int(e.get("uses", 0)) <= 0:
				continue
			usable.append(e)
		if usable.is_empty():
			usable = moves
		if not usable.is_empty():
			choice = usable[randi_range(0, usable.size() - 1)]

	if choice.is_empty():
		_set_busy(false)
		return

	var m := Data.move(String(choice.get("id", "")))
	if String(m.get("kind", "attack")) == "guard":
		enemy["guard"] = true
		_log(String(m.get("text", "%s guards.")) % String(enemy.get("name", "?")))
		_bounce(enemy_sprite, 0.05)
		await _wait(0.6)
		_log("What will %s do?" % String(ally.get("name", "?")))
		_set_busy(false)
		_layout_buttons()
		return

	var limit := int(m.get("uses", 0))
	if limit > 0:
		choice["uses"] = maxi(0, int(choice.get("uses", 0)) - 1)
	var dmg := Data.damage(int(m.get("power", 5)), int(enemy.get("atk", 6)), int(ally.get("def", 5)), String(m.get("flavour", "savoury")), String(ally.get("flavour", "savoury")), _roll())
	if bool(ally.get("guard", false)):
		dmg = maxi(1, int(round(float(dmg) * 0.5)))
		ally["guard"] = false
	ally["hp"] = maxi(0, int(ally.get("hp", 0)) - dmg)
	_log(String(m.get("text", "%s attacks!")) % String(enemy.get("name", "?")))
	_popup("-%d" % dmg, ally_sprite.position + Vector2(46, 6), Color(1.0, 0.75, 0.7))
	_recoil(ally_sprite)
	_flash(ally_sprite)
	_refresh()
	await _wait(0.8)
	if int(ally.get("hp", 0)) <= 0:
		_lose()
		return
	_layout_buttons()
	_set_busy(false)
	_log("What will %s do?" % String(ally.get("name", "?")))


func _try_run() -> void:
	_set_busy(true)
	if randf() < 0.55:
		_log("You scoop up %s and slip away." % String(ally.get("name", "?")))
		await _wait(0.7)
		_finish("fled")
	else:
		_log("%s blocks the trail! No escape." % String(enemy.get("name", "?")))
		await _wait(0.6)
		await _enemy_turn()


# --- outcomes -----------------------------------------------------------

func _win() -> void:
	over = true
	result_kind = "won"
	_set_busy(true)
	var old_level := int(ally.get("level", 1))
	ally["xp"] = int(ally.get("xp", 0)) + 12
	var leveled := false
	while int(ally.get("xp", 0)) >= 20:
		ally["xp"] = int(ally.get("xp", 0)) - 20
		ally["level"] = int(ally.get("level", 1)) + 1
		ally["max_hp"] = int(ally.get("max_hp", 30)) + 3
		ally["hp"] = int(ally.get("hp", 1)) + 3
		ally["atk"] = int(ally.get("atk", 7)) + 1
		leveled = true
	reward = {"xp": 12, "berries": 2, "leveled": leveled, "level": int(ally.get("level", 1)), "old_level": old_level}
	_log("%s faints into crumbs!" % String(enemy.get("name", "?")))
	var sub := "+12 XP   +2 Sunberries\n%s grows a little stronger." % String(ally.get("name", "?"))
	if leveled:
		sub = "+12 XP   +2 Sunberries\n%s reached Lv %d!" % [String(ally.get("name", "?")), int(ally.get("level", 1))]
	_show_result("VICTORY", sub, "Continue")
	_refresh()


func _lose() -> void:
	over = true
	result_kind = "lost"
	_set_busy(true)
	reward = {}
	_log("%s runs out of steam..." % String(ally.get("name", "?")))
	_show_result("OUT OF STEAM", "The forest carries you back to camp.\nYour dishes are safe. Try again.", "Back to camp")


func _show_result(title: String, sub: String, button_text: String) -> void:
	result_title.text = title
	result_sub.text = sub
	continue_button.text = button_text
	result_panel.visible = true


func _on_continue() -> void:
	_finish(result_kind)


func _finish(kind: String) -> void:
	over = true
	result_panel.visible = false
	root.visible = false
	battle_finished.emit(kind, reward)


# --- small juice --------------------------------------------------------

func _popup(text: String, pos: Vector2, color: Color) -> void:
	var label := Fonts.label(text, 16, color, Fonts.sans(800), 4)
	label.position = pos
	root.add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", pos.y - 26.0, 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)


func _flash(target: Control) -> void:
	target.modulate = Color(2.0, 1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(target, "modulate", Color.WHITE, 0.22)


func _recoil(target: Control) -> void:
	var home := target.position
	var tw := create_tween()
	tw.tween_property(target, "position", home + Vector2(7, -3), 0.06)
	tw.tween_property(target, "position", home - Vector2(5, 2), 0.07)
	tw.tween_property(target, "position", home, 0.08)


func _bounce(target: Control, amount: float) -> void:
	var home := target.position
	var lift := 6.0 + amount * 100.0
	var tw := create_tween()
	tw.tween_property(target, "position", home + Vector2(0, -lift), 0.12)
	tw.tween_property(target, "position", home, 0.14)
