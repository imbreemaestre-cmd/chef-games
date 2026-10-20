extends CanvasLayer
## Overworld HUD at the 640x360 design resolution: berry counter, party line,
## interaction prompt, toasts, the campfire cooking panel and the Escape menu.

signal cook_requested(recipe_id: String)
signal menu_toggled(open: bool)
signal save_requested
signal text_speed_changed(index: int)

const Fonts := preload("res://starter/ui-fonts/fonts.gd")

const INK := Color(0.24, 0.16, 0.11)
const PAPER := Color(0.98, 0.94, 0.84)
const PAPER_DARK := Color(0.90, 0.84, 0.71)
const TRIM := Color(0.45, 0.29, 0.18)
const HONEY := Color(0.99, 0.80, 0.44)
const MINT := Color(0.60, 0.82, 0.55)

const SPEED_NAMES := ["Slow", "Normal", "Fast"]

var berry_icon: TextureRect
var berry_label: Label
var party_label: Label
var quest_panel: PanelContainer
var quest_label: Label
var speed_button: Button
var _speed_index := 1
var prompt_label: Label
var toast_label: Label
var hint_label: Label

var cooking_root: Control
var cooking_list: VBoxContainer
var cooking_title: Label
var cooking_sub: Label

var menu_root: Control
var stats_label: Label

var _toast_tween: Tween


func _ready() -> void:
	layer = 10
	_build()


func _style(bg: Color, border: Color, radius: int = 6, pad: int = 8) -> StyleBoxFlat:
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
	b.add_theme_font_override("font", Fonts.sans(800))
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_stylebox_override("normal", _style(HONEY, TRIM, 5, 8))
	b.add_theme_stylebox_override("hover", _style(HONEY.lightened(0.18), TRIM, 5, 8))
	b.add_theme_stylebox_override("pressed", _style(HONEY.darkened(0.12), TRIM, 5, 8))
	b.add_theme_stylebox_override("disabled", _style(PAPER_DARK, TRIM.lightened(0.3), 5, 8))
	return b


func _build() -> void:
	# berry counter
	var counter := PanelContainer.new()
	counter.position = Vector2(8, 8)
	counter.add_theme_stylebox_override("panel", _style(PAPER, TRIM))
	add_child(counter)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	counter.add_child(row)

	berry_icon = TextureRect.new()
	berry_icon.texture = Art.berry_icon()
	berry_icon.custom_minimum_size = Vector2(16, 16)
	berry_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	berry_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	berry_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	berry_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(berry_icon)

	berry_label = Fonts.label("0", 14, INK, Fonts.sans(800))
	berry_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(berry_label)

	party_label = Fonts.label("Party: empty", 11, Color(1, 0.97, 0.90), Fonts.sans(700), 4)
	party_label.position = Vector2(10, 40)
	add_child(party_label)

	# objective banner across the top, kept clear of the berry counter
	quest_panel = PanelContainer.new()
	quest_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	quest_panel.offset_left = 96
	quest_panel.offset_right = -96
	quest_panel.offset_top = 8
	quest_panel.add_theme_stylebox_override("panel", _style(Color(0.20, 0.15, 0.10, 0.78), HONEY, 8, 8))
	quest_panel.visible = false
	add_child(quest_panel)

	quest_label = Fonts.label("", 10, HONEY.lerp(Color.WHITE, 0.35), Fonts.sans(700))
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_panel.add_child(quest_label)

	prompt_label = Fonts.label("", 12, Color(1, 0.98, 0.92), Fonts.sans(800), 5)
	prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_label.offset_top = -34
	prompt_label.offset_bottom = -12
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	add_child(prompt_label)

	toast_label = Fonts.label("", 13, Color(1, 0.98, 0.90), Fonts.sans(800), 5)
	toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 64
	toast_label.offset_bottom = 92
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.visible = false
	add_child(toast_label)

	hint_label = Fonts.label("WASD move   Shift run   E interact   Esc menu", 9, Color(1, 0.97, 0.90, 0.75), Fonts.sans(700), 3)
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_label.offset_left = -250
	hint_label.offset_top = -18
	hint_label.offset_bottom = -4
	hint_label.offset_right = -8
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint_label)

	_build_cooking()
	_build_menu()


func _build_cooking() -> void:
	cooking_root = Control.new()
	cooking_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooking_root.visible = false
	add_child(cooking_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.06, 0.04, 0.03, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	cooking_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -104
	panel.offset_bottom = 104
	panel.add_theme_stylebox_override("panel", _style(PAPER, TRIM, 10, 14))
	cooking_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	panel.add_child(col)

	cooking_title = Fonts.label("", 17, INK, Fonts.display(700))
	col.add_child(cooking_title)

	cooking_sub = Fonts.label("", 10, INK.lerp(PAPER, 0.25), Fonts.sans(700))
	col.add_child(cooking_sub)

	var line := ColorRect.new()
	line.color = TRIM.lerp(PAPER, 0.55)
	line.custom_minimum_size = Vector2(0, 2)
	col.add_child(line)

	cooking_list = VBoxContainer.new()
	cooking_list.add_theme_constant_override("separation", 6)
	cooking_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cooking_list)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(footer)
	var close := _button("Close")
	close.pressed.connect(close_cooking)
	footer.add_child(close)


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.visible = false
	add_child(menu_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -124
	panel.offset_bottom = 124
	panel.add_theme_stylebox_override("panel", _style(PAPER, TRIM, 10, 14))
	menu_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var title := Fonts.label("Sunberry Hollow", 19, INK, Fonts.display(700))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	stats_label = Fonts.label("", 10, INK, Fonts.sans(700))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(stats_label)

	var line := ColorRect.new()
	line.color = TRIM.lerp(PAPER, 0.55)
	line.custom_minimum_size = Vector2(0, 2)
	col.add_child(line)

	var controls := Fonts.label("WASD / arrows  walk\nShift  run\nE  gather, cook, battle\nEsc  close this menu", 10, INK.lerp(PAPER, 0.18), Fonts.sans(600))
	col.add_child(controls)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)

	speed_button = _button("Text: %s" % SPEED_NAMES[_speed_index])
	speed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_button.pressed.connect(_cycle_speed)
	buttons.add_child(speed_button)

	var save_button := _button("Save")
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(func() -> void: save_requested.emit())
	buttons.add_child(save_button)

	var resume := _button("Back to the forest")
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.pressed.connect(close_menu)
	buttons.add_child(resume)


# --- runtime updates ----------------------------------------------------

func set_berries(n: int) -> void:
	berry_label.text = "%d" % n


func set_party(text: String) -> void:
	party_label.text = text


func set_quest(text: String) -> void:
	var clean := text.strip_edges()
	quest_label.text = clean
	quest_panel.visible = not clean.is_empty()


func set_speed_index(index: int) -> void:
	_speed_index = clampi(index, 0, 2)
	if speed_button != null:
		speed_button.text = "Text: %s" % SPEED_NAMES[_speed_index]


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % 3
	speed_button.text = "Text: %s" % SPEED_NAMES[_speed_index]
	text_speed_changed.emit(_speed_index)


func show_prompt(text: String) -> void:
	var clean := text.strip_edges()
	prompt_label.visible = clean != ""
	if prompt_label.visible:
		prompt_label.text = clean


func hide_prompt() -> void:
	prompt_label.visible = false


func toast(text: String, seconds := 2.4) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.45)
	_toast_tween.tween_callback(_hide_toast)


func _hide_toast() -> void:
	toast_label.visible = false


# --- cooking panel ------------------------------------------------------

func open_cooking(station_title: String, method_text: String, entries: Array) -> void:
	cooking_title.text = station_title
	cooking_sub.text = method_text
	for child in cooking_list.get_children():
		child.queue_free()
	if entries.is_empty():
		var empty := Fonts.label("Nothing here can be cooked yet.", 11, INK, Fonts.sans(700))
		cooking_list.add_child(empty)
	for entry: Dictionary in entries:
		cooking_list.add_child(_recipe_row(entry))
	cooking_root.visible = true


func _recipe_row(entry: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _style(PAPER_DARK, TRIM.lerp(PAPER, 0.4), 6, 8))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)

	col.add_child(Fonts.label(String(entry.get("name", "?")), 13, INK, Fonts.display(700)))
	col.add_child(Fonts.label(String(entry.get("requirement", "")), 9, INK.lerp(PAPER, 0.2), Fonts.sans(700)))
	col.add_child(Fonts.label(String(entry.get("note", "")), 9, INK.lerp(PAPER, 0.35), Fonts.sans(600)))

	var chance := Fonts.label(String(entry.get("chance", "")), 11, Color(0.30, 0.45, 0.22), Fonts.sans(800))
	chance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(chance)

	var cook := _button("Cook")
	cook.disabled = not bool(entry.get("can_cook", false))
	var id := String(entry.get("id", ""))
	cook.pressed.connect(func() -> void: cook_requested.emit(id))
	row.add_child(cook)
	return box


func close_cooking() -> void:
	cooking_root.visible = false


# --- menu ---------------------------------------------------------------

func open_menu(stats: String) -> void:
	stats_label.text = stats
	menu_root.visible = true
	menu_toggled.emit(true)


func close_menu() -> void:
	if not menu_root.visible:
		return
	menu_root.visible = false
	menu_toggled.emit(false)


func is_menu_open() -> bool:
	return menu_root.visible


func is_cooking_open() -> bool:
	return cooking_root.visible


func is_modal_open() -> bool:
	return menu_root.visible or cooking_root.visible
