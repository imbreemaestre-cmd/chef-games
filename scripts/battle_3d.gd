extends CanvasLayer
## Turn-based battle screen: creature cards, HP bars, action buttons and a log line.

signal battle_won(reward_berries: int)
signal battle_lost
signal battle_fled

const Fonts := preload("res://starter/ui-fonts/fonts.gd")
const ICON_ALLY := "res://starter/ui-icons/food/berry_jam.png"
const ICON_ENEMY := "res://starter/ui-icons/crop/blueberry.png"

var ally_name := "Sunberry Sprout"
var ally_max := 34
var ally_hp := 34
var ally_atk := 7
var enemy_name := "Wild Bramble"
var enemy_max := 30
var enemy_hp := 30
var enemy_atk := 6
var bombs := 2
var guarding := false
var busy := false
var over := false
var result_kind := ""

var root: Control
var top_label: Label
var log_label: Label
var enemy_card: PanelContainer
var ally_card: PanelContainer
var enemy_bar: ProgressBar
var ally_bar: ProgressBar
var enemy_hp_text: Label
var ally_hp_text: Label
var bomb_button: Button
var attack_button: Button
var guard_button: Button
var run_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_sub: Label
var continue_button: Button


func _ready() -> void:
	layer = 5
	_build()
	root.visible = false


func _grain(bg: Color, border: Color, radius := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _button_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(14)
	s.border_color = Color(0.35, 0.2, 0.1, 0.6)
	s.set_border_width_all(2)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _bar_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.07, 0.05, 0.9)
	s.set_corner_radius_all(9)
	return s


func _bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(9)
	return s


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(168, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Fonts.sans(800))
	b.add_theme_font_size_override("font_size", 20)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color(0.13, 0.08, 0.05))
	b.add_theme_stylebox_override("normal", _button_style(Color(0.99, 0.80, 0.44)))
	b.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.89, 0.60)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.89, 0.68, 0.33)))
	b.add_theme_stylebox_override("disabled", _button_style(Color(0.52, 0.46, 0.40)))
	return b


func _make_card(left: float, top: float, right: float, bottom: float, icon_path: String, title: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.anchor_left = left
	panel.anchor_top = top
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	panel.add_theme_stylebox_override("panel", _grain(Color(0.15, 0.10, 0.07, 0.94), Color(0.99, 0.79, 0.42, 0.55)))
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(76, 76)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	var name_label := Fonts.label(title, 25, Color(1, 0.93, 0.79), Fonts.display(700), 5)
	col.add_child(name_label)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 20)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.add_theme_stylebox_override("background", _bar_bg())
	bar.add_theme_stylebox_override("fill", _bar_fill(Color(0.44, 0.83, 0.38)))
	col.add_child(bar)

	var hp_text := Fonts.label("", 15, Color(0.93, 0.89, 0.80), Fonts.sans(700), 3)
	col.add_child(hp_text)

	return {"panel": panel, "bar": bar, "hp": hp_text}


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.03, 0.02, 0.62)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	top_label = Fonts.label("", 32, Color(1, 0.92, 0.74), Fonts.display(700, 0, 144), 8)
	top_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_label.offset_top = 44
	top_label.offset_bottom = 108
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(top_label)

	var enemy := _make_card(0.50, 0.14, 0.96, 0.34, ICON_ENEMY, enemy_name)
	enemy_card = enemy["panel"]
	enemy_bar = enemy["bar"]
	enemy_hp_text = enemy["hp"]

	var ally := _make_card(0.04, 0.64, 0.50, 0.84, ICON_ALLY, ally_name)
	ally_card = ally["panel"]
	ally_bar = ally["bar"]
	ally_hp_text = ally["hp"]

	log_label = Fonts.label("", 22, Color(1, 0.96, 0.88), Fonts.sans(700), 6)
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	log_label.offset_top = -192
	log_label.offset_bottom = -148
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(log_label)

	var actions := HBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	actions.offset_top = -132
	actions.offset_bottom = -48
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	root.add_child(actions)

	attack_button = _button("Tackle")
	bomb_button = _button("Berry Bomb (2)")
	guard_button = _button("Guard")
	run_button = _button("Run")
	for b in [attack_button, bomb_button, guard_button, run_button]:
		actions.add_child(b)
	attack_button.pressed.connect(_on_action.bind("attack"))
	bomb_button.pressed.connect(_on_action.bind("bomb"))
	guard_button.pressed.connect(_on_action.bind("guard"))
	run_button.pressed.connect(_on_action.bind("run"))

	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -330
	result_panel.offset_right = 330
	result_panel.offset_top = -150
	result_panel.offset_bottom = 150
	result_panel.add_theme_stylebox_override("panel", _grain(Color(0.14, 0.09, 0.06, 0.97), Color(1.0, 0.82, 0.45, 0.8), 22))
	root.add_child(result_panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	result_panel.add_child(col)

	result_title = Fonts.label("", 44, Color(1, 0.94, 0.78), Fonts.display(700, 0, 144), 8)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(result_title)

	result_sub = Fonts.label("", 20, Color(0.97, 0.92, 0.84), Fonts.sans(700), 4)
	result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_sub.custom_minimum_size = Vector2(560, 0)
	col.add_child(result_sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	col.add_child(spacer)

	continue_button = _button("Continue")
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(_on_continue)
	col.add_child(continue_button)

	result_panel.visible = false


func start(enemy_label: String, e_max: int, e_atk: int, ally_label: String, a_max: int, a_atk: int, headline: String) -> void:
	enemy_name = enemy_label
	enemy_max = e_max
	enemy_hp = e_max
	enemy_atk = e_atk
	ally_name = ally_label
	ally_max = a_max
	ally_hp = a_max
	ally_atk = a_atk
	bombs = 2
	guarding = false
	busy = false
	over = false
	result_kind = ""
	top_label.text = headline
	result_panel.visible = false
	root.visible = true
	_refresh()
	_log("What will %s do?" % ally_name)
	_set_buttons(true)


func _refresh() -> void:
	enemy_bar.value = 100.0 * float(enemy_hp) / float(maxi(enemy_max, 1))
	ally_bar.value = 100.0 * float(ally_hp) / float(maxi(ally_max, 1))
	enemy_hp_text.text = "%d / %d HP" % [enemy_hp, enemy_max]
	ally_hp_text.text = "%d / %d HP" % [ally_hp, ally_max]
	bomb_button.text = "Berry Bomb (%d)" % bombs
	bomb_button.disabled = bombs <= 0 or busy or over


func _set_buttons(on: bool) -> void:
	attack_button.disabled = not on
	guard_button.disabled = not on
	run_button.disabled = not on
	bomb_button.disabled = (not on) or bombs <= 0


func _log(text: String) -> void:
	log_label.text = text


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _roll(base: int) -> int:
	return randi_range(maxi(1, base - 2), base + 3)


func _bump(card: Control) -> void:
	if card == null:
		return
	var x := card.position.x
	var tw := create_tween()
	tw.tween_property(card, "position:x", x + 14.0, 0.07)
	tw.tween_property(card, "position:x", x - 10.0, 0.08)
	tw.tween_property(card, "position:x", x, 0.07)


func _on_action(action: String) -> void:
	if busy or over:
		return
	busy = true
	_set_buttons(false)

	match action:
		"attack":
			var dmg_hit := _roll(ally_atk)
			enemy_hp = maxi(0, enemy_hp - dmg_hit)
			_log("%s uses Tackle!  %d damage." % [ally_name, dmg_hit])
			_bump(enemy_card)
			_refresh()
			await _wait(0.65)
			if enemy_hp <= 0:
				_win()
				return
			await _enemy_turn()
		"bomb":
			if bombs <= 0:
				_log("No Berry Bombs left!")
				busy = false
				_set_buttons(true)
				return
			bombs -= 1
			var dmg_bomb := _roll(ally_atk + 7)
			enemy_hp = maxi(0, enemy_hp - dmg_bomb)
			_log("%s hurls a Berry Bomb!  %d damage." % [ally_name, dmg_bomb])
			_bump(enemy_card)
			_refresh()
			await _wait(0.65)
			if enemy_hp <= 0:
				_win()
				return
			await _enemy_turn()
		"guard":
			guarding = true
			_log("%s curls up and guards." % ally_name)
			await _wait(0.55)
			await _enemy_turn()
		"run":
			if randf() < 0.5:
				_log("Got away safely!")
				await _wait(0.7)
				_finish("fled")
			else:
				_log("%s blocks the trail!" % enemy_name)
				await _wait(0.55)
				await _enemy_turn()


func _enemy_turn() -> void:
	if over:
		return
	var dmg := _roll(enemy_atk)
	if guarding:
		dmg = maxi(1, int(dmg * 0.5))
		guarding = false
	ally_hp = maxi(0, ally_hp - dmg)
	_log("%s brambles you back!  %d damage." % [enemy_name, dmg])
	_bump(ally_card)
	_refresh()
	await _wait(0.75)
	if ally_hp <= 0:
		_lose()
		return
	busy = false
	_set_buttons(true)
	_log("What will %s do?" % ally_name)


func _win() -> void:
	over = true
	busy = true
	result_kind = "won"
	_set_buttons(false)
	_log("%s is knocked out!" % enemy_name)
	_show_result("VICTORY!", "+2 Sunberries  -  +12 XP\nYour sprout grows a little stronger.", "Continue")


func _lose() -> void:
	over = true
	busy = true
	result_kind = "lost"
	_set_buttons(false)
	_log("%s faints..." % ally_name)
	_show_result("FAINTED", "The forest carries you back to camp.\nTry again with Guard and Berry Bombs.", "Back to camp")


func _show_result(title: String, sub: String, button_text: String) -> void:
	result_title.text = title
	result_sub.text = sub
	continue_button.text = button_text
	result_panel.visible = true


func _on_continue() -> void:
	match result_kind:
		"won":
			_finish("won")
		"lost":
			_finish("lost")
		_:
			_finish("fled")


func _finish(kind: String) -> void:
	root.visible = false
	result_panel.visible = false
	match kind:
		"won":
			battle_won.emit(2)
		"lost":
			battle_lost.emit()
		_:
			battle_fled.emit()
