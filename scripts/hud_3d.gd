extends CanvasLayer
## HUD: sunberry counter, companion status, interaction prompt, toasts and title card.

const Fonts := preload("res://starter/ui-fonts/fonts.gd")
const ICON_BERRY := "res://starter/ui-icons/crop/blueberry.png"

var berry_label: Label
var companion_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_label: Label
var title_main: Label
var title_sub: Label

var _toast_tween: Tween
var _title_tween: Tween


func _ready() -> void:
	layer = 2
	_build()
	show_prompt("")


func _grain(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.content_margin_left = 16
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Sunberry counter, top left.
	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _grain(Color(0.17, 0.11, 0.07, 0.88), Color(0.99, 0.79, 0.42, 0.6)))
	stats.position = Vector2(24, 22)
	root.add_child(stats)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	stats.add_child(row)

	var icon := TextureRect.new()
	icon.texture = load(ICON_BERRY)
	icon.custom_minimum_size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(Fonts.label("SUNBERRIES", 12, Color(0.99, 0.86, 0.60), Fonts.sans(800, 2), 3))
	berry_label = Fonts.label("0", 30, Color.WHITE, Fonts.display(700))
	col.add_child(berry_label)

	companion_label = Fonts.label("", 16, Color(0.97, 0.91, 0.78), Fonts.sans(700), 4)
	companion_label.position = Vector2(28, 104)
	root.add_child(companion_label)

	# Interaction prompt, bottom centre.
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -108
	bottom.offset_bottom = -40
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)

	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", _grain(Color(0.11, 0.08, 0.06, 0.92), Color(0.99, 0.79, 0.42, 0.5)))
	bottom.add_child(prompt_panel)
	prompt_label = Fonts.label("", 22, Color.WHITE, Fonts.sans(800), 5)
	prompt_panel.add_child(prompt_label)

	# Controls hint, bottom right.
	var hint := Fonts.label("WASD move   Shift run   Space jump   E interact   Esc cursor", 14, Color(1, 1, 1, 0.62), Fonts.sans(700), 4)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -520
	hint.offset_top = -34
	hint.offset_right = -24
	hint.offset_bottom = -10
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)

	# Title card.
	var title_box := VBoxContainer.new()
	title_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_box.offset_top = 132
	title_box.offset_bottom = 300
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_box)

	title_main = Fonts.label("", 58, Color(1, 0.96, 0.86), Fonts.display(700, 0, 144), 10)
	title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title_main)
	title_sub = Fonts.label("", 20, Color(1, 0.92, 0.74), Fonts.sans(700), 6)
	title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title_sub)

	# Toast, middle of screen.
	toast_label = Fonts.label("", 25, Color(1, 0.97, 0.9), Fonts.display(700), 7)
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.offset_left = -460
	toast_label.offset_right = 460
	toast_label.offset_top = 132
	toast_label.offset_bottom = 186
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)


func set_berries(count: int) -> void:
	berry_label.text = str(count)


func set_companion(text: String) -> void:
	companion_label.text = text


func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_panel.visible = text != ""


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.7)


func show_title(main_text: String, sub_text: String) -> void:
	title_main.text = main_text
	title_sub.text = sub_text
	title_main.modulate.a = 1.0
	title_sub.modulate.a = 1.0
	if _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()
	_title_tween = create_tween()
	_title_tween.tween_interval(3.4)
	_title_tween.tween_property(title_main, "modulate:a", 0.0, 1.0)
	_title_tween.parallel().tween_property(title_sub, "modulate:a", 0.0, 1.0)
