class_name ArtChars
extends RefCounted
## Overworld character sprites at 32x48: human proportions, not chibi.
##
## All three characters share one skeleton (head, neck, shoulders, tapered
## torso, hips, two separated legs, two arms) and differ only by a style
## dictionary, so they read as one art direction. Frames are generated once
## and cached.
##
## Convention: the sprite is 32x48 and the character's feet stand at y=46, so
## a node whose origin is on the ground draws it with BASE_OFFSET.

const W := 32
const H := 48
const BASE_Y := 46
## Offset that puts the feet on the node origin: -(46 - 48/2).
const BASE_OFFSET := Vector2(0, -22)

# --- palette -------------------------------------------------------------

const SKIN := Color(0.96, 0.80, 0.66)
const SKIN_SHADE := Color(0.86, 0.64, 0.50)
const EYE := Color(0.20, 0.15, 0.13)
const MOUTH := Color(0.66, 0.38, 0.32)

const COAT := Color(0.97, 0.96, 0.92)
const COAT_SHADE := Color(0.84, 0.83, 0.79)
const COAT_LINE := Color(0.72, 0.71, 0.68)
const HAT := Color(1.0, 1.0, 0.98)
const HAT_SHADE := Color(0.86, 0.86, 0.83)
const SCARF := Color(0.79, 0.27, 0.24)
const PANTS := Color(0.25, 0.32, 0.44)
const PANTS_SHADE := Color(0.19, 0.25, 0.35)
const BOOTS := Color(0.38, 0.24, 0.16)
const BOOTS_SHADE := Color(0.28, 0.17, 0.11)
const HAIR := Color(0.42, 0.27, 0.19)
const HAIR_LIGHT := Color(0.55, 0.37, 0.26)

const DRESS := Color(0.94, 0.87, 0.71)
const DRESS_SHADE := Color(0.80, 0.73, 0.58)
const APRON := Color(0.29, 0.55, 0.43)
const APRON_SHADE := Color(0.21, 0.42, 0.33)
const MIRA_HAIR := Color(0.31, 0.19, 0.15)
const MIRA_HAIR_LIGHT := Color(0.44, 0.29, 0.22)

const SUIT := Color(0.17, 0.16, 0.20)
const SUIT_SHADE := Color(0.12, 0.11, 0.15)
const SUIT_LINE := Color(0.27, 0.26, 0.32)
const SUIT_SLACK := Color(0.14, 0.13, 0.17)
const SILVER := Color(0.80, 0.80, 0.83)
const SILVER_DARK := Color(0.60, 0.61, 0.66)
const CRAVAT := Color(0.52, 0.11, 0.15)
const GOLD := Color(0.87, 0.73, 0.38)
const WOOD := Color(0.55, 0.37, 0.22)
const NONE := Color(0, 0, 0, 0)

static var _cache := {}


# --- drawing helpers -----------------------------------------------------

static func _img(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(NONE)
	return img


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if c.a <= 0.0:
		return
	img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	if w <= 0 or h <= 0:
		return
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	var ax := maxi(1, rx)
	var ay := maxi(1, ry)
	for yy in range(cy - ay, cy + ay + 1):
		for xx in range(cx - ax, cx + ax + 1):
			var dx := float(xx - cx) / float(ax)
			var dy := float(yy - cy) / float(ay)
			if dx * dx + dy * dy <= 1.0:
				_px(img, xx, yy, c)


static func _shadow(img: Image, cx: int, cy: int, rx: int) -> void:
	_ellipse(img, cx, cy, rx, 2, Color(0.06, 0.10, 0.06, 0.16))
	_ellipse(img, cx, cy, rx - 2, 1, Color(0.06, 0.10, 0.06, 0.20))


# --- poses ---------------------------------------------------------------

## Frame counts per animation name.
static func _frame_count(anim: String) -> int:
	match anim:
		"walk", "run":
			return 4
		"react":
			return 2
		"idle", "talk", "cook":
			return 2
	return 1


static func _anim_speed(anim: String) -> float:
	match anim:
		"walk":
			return 9.0
		"run":
			return 13.0
		"idle":
			return 2.6
		"talk":
			return 4.0
		"cook":
			return 3.6
		"react":
			return 6.0
	return 4.0


## Body offsets for one animation frame. Kept in one place so every character
## moves the same way.
static func _pose(anim: String, frame: int) -> Dictionary:
	var f := frame % 4
	var bob := 0
	var stride := 0
	var lift_a := 0
	var lift_b := 0
	var arm := 0
	var lean := 0
	match anim:
		"walk":
			var bobs := [0, -1, 0, -1]
			var strides := [2, 0, -2, 0]
			var lifts := [0, 1, 0, 0]
			var lifts_b := [0, 0, 0, 1]
			var arms := [-2, 0, 2, 0]
			bob = int(bobs[f])
			stride = int(strides[f])
			lift_a = int(lifts[f])
			lift_b = int(lifts_b[f])
			arm = int(arms[f])
		"run":
			var bobs := [-1, -2, -1, -2]
			var strides := [3, 0, -3, 0]
			var lifts := [1, 3, 1, 0]
			var lifts_b := [0, 0, 1, 3]
			var arms := [-4, 0, 4, 0]
			bob = int(bobs[f])
			stride = int(strides[f])
			lift_a = int(lifts[f])
			lift_b = int(lifts_b[f])
			arm = int(arms[f])
			lean = 1
		"idle":
			var idle_bob := [0, -1]
			bob = int(idle_bob[frame % 2])
		"talk":
			var talk_bob := [0, -1]
			bob = int(talk_bob[frame % 2])
		"react":
			var react_bob := [-2, -1]
			bob = int(react_bob[frame % 2])
			lean = -1
		"cook":
			var cook_bob := [0, 0]
			bob = int(cook_bob[frame % 2])
	return {
		"bob": bob, "stride": stride, "lift_a": lift_a,
		"lift_b": lift_b, "arm": arm, "lean": lean,
	}


# --- the shared figure ---------------------------------------------------

static func _draw(img: Image, st: Dictionary, cell: int, anim: String, frame: int) -> void:
	var p := _pose(anim, frame)
	var bob: int = p["bob"]
	var stride: int = p["stride"]
	var lift_a: int = p["lift_a"]
	var lift_b: int = p["lift_b"]
	var arm: int = p["arm"]
	var lean: int = p["lean"]

	var side: bool = cell == 2 or cell == 3
	var back: bool = cell == 1
	var cx := 16
	var sw: int = int(st["sw"])
	var skin: Color = st["skin"]
	var skin_shade: Color = st["skin_shade"]
	var top: Color = st["top"]
	var top_shade: Color = st["top_shade"]
	var top_line: Color = st["top_line"]
	var sleeve: Color = st["sleeve"]
	var sleeve_shade: Color = st["sleeve_shade"]
	var legs: Color = st["legs"]
	var legs_shade: Color = st["legs_shade"]
	var shoes: Color = st["shoes"]
	var shoes_shade: Color = st["shoes_shade"]
	var hair: Color = st["hair"]
	var hair_light: Color = st["hair_light"]

	var ground := 45
	var hip_y := 33 + bob
	var shoulder_y := 17 + bob + lean
	var head_cy := 10 + bob + lean

	_shadow(img, cx, ground, sw + 1)

	# --- legs -------------------------------------------------------
	if side:
		var back_x := cx - 3 - stride
		_rect(img, back_x, hip_y, 4, 40 - hip_y - lift_b, legs.darkened(0.16))
		_rect(img, back_x - 1, 40 - lift_b, 5, 4, shoes_shade)
		var front_x := cx - 1 + stride
		_rect(img, front_x, hip_y, 4, 40 - hip_y - lift_a, legs)
		_rect(img, front_x - 1, 40 - lift_a, 5, 4, shoes)
		_px(img, front_x, 40 - lift_a, shoes.lightened(0.22))
	else:
		var lx1 := cx - 5
		var lx2 := cx + 1
		_rect(img, lx1, hip_y, 4, 40 - hip_y - lift_a, legs)
		_rect(img, lx2, hip_y, 4, 40 - hip_y - lift_b, legs_shade)
		_px(img, lx1 + 3, hip_y + 1, legs_shade)
		_rect(img, lx1 - 1, 40 - lift_a, 6, 4, shoes)
		_rect(img, lx2 - 1, 40 - lift_b, 6, 4, shoes_shade)
		_px(img, lx1, 40 - lift_a, shoes.lightened(0.22))
		_px(img, lx2, 40 - lift_b, shoes_shade.lightened(0.12))

	# --- skirt over the thighs --------------------------------------
	if bool(st["skirt"]):
		var skirt_color: Color = st["skirt_color"]
		var skirt_shade: Color = st["skirt_shade"]
		_rect(img, cx - 6, 27 + bob, 12, 8, skirt_color)
		_rect(img, cx - 7, 34 + bob, 14, 2, skirt_shade)
		_rect(img, cx + 4, 27 + bob, 2, 8, skirt_shade)
		_rect(img, cx - 6, 27 + bob, 12, 1, skirt_color.lightened(0.10))

	# --- torso ------------------------------------------------------
	if side:
		var sx := cx - 5
		_rect(img, sx, shoulder_y, 9, 3, top)
		_rect(img, sx, shoulder_y + 3, 9, 9, top)
		_rect(img, sx + 7, shoulder_y, 2, 12, top_shade)
		_rect(img, sx, shoulder_y + 11, 8, 5, top)
		_rect(img, sx, shoulder_y, 9, 1, top_line)
	else:
		var w := sw * 2
		_rect(img, cx - sw, shoulder_y, w, 4, top)
		_rect(img, cx - sw, shoulder_y + 4, w, 7, top)
		_rect(img, cx - sw + 1, shoulder_y + 11, w - 2, 5, top)
		_rect(img, cx + sw - 2, shoulder_y, 2, 16, top_shade)
		_rect(img, cx - sw, shoulder_y, 1, 16, top_line)
		_rect(img, cx - sw, shoulder_y, w, 1, top.lightened(0.12))
		if not back:
			_rect(img, cx - 1, shoulder_y + 3, 2, 12, top_line)

	# --- apron ------------------------------------------------------
	var apron: Color = st["apron"]
	if apron.a > 0.0:
		if side:
			_rect(img, cx - 4, shoulder_y + 5, 8, 10, apron)
			_rect(img, cx + 2, shoulder_y + 5, 2, 10, apron.darkened(0.16))
		else:
			_rect(img, cx - 5, shoulder_y + 5, 10, 11, apron)
			_rect(img, cx - 5, shoulder_y + 5, 10, 1, apron.lightened(0.14))
			_rect(img, cx + 3, shoulder_y + 6, 2, 10, apron.darkened(0.16))
			if not back:
				_rect(img, cx - 5, shoulder_y + 4, 2, 2, apron.darkened(0.18))
				_rect(img, cx + 3, shoulder_y + 4, 2, 2, apron.darkened(0.18))

	# --- buttons / trim --------------------------------------------
	var trim: Color = st["trim"]
	if trim.a > 0.0 and not back:
		for i in range(3):
			_px(img, cx + 2, shoulder_y + 5 + i * 3, trim)
			_px(img, cx + 2, shoulder_y + 6 + i * 3, trim.darkened(0.25))
		_rect(img, cx - sw, shoulder_y + 2, 3, 1, trim)

	# --- neck -------------------------------------------------------
	if not back:
		_rect(img, cx - 2, head_cy + 5, 4, 3, skin_shade)

	# --- head -------------------------------------------------------
	if back:
		_ellipse(img, cx, head_cy, 6, 6, hair)
		_ellipse(img, cx, head_cy - 1, 5, 5, hair_light)
	else:
		_ellipse(img, cx, head_cy, 6, 6, hair)
		if side:
			_ellipse(img, cx + 1, head_cy + 1, 5, 5, skin)
			_px(img, cx + 5, head_cy + 2, skin_shade)
			_rect(img, cx + 3, head_cy + 1, 2, 2, EYE)
			_px(img, cx + 3, head_cy + 1, Color(1, 1, 1, 0.85))
			_px(img, cx + 5, head_cy + 3, skin_shade)
			_rect(img, cx + 3, head_cy + 4, 2, 1, MOUTH)
		else:
			_ellipse(img, cx, head_cy + 1, 5, 5, skin)
			_ellipse(img, cx, head_cy + 4, 3, 2, skin_shade)
			_ellipse(img, cx - 3, head_cy + 3, 1, 1, skin_shade)
			_ellipse(img, cx + 3, head_cy + 3, 1, 1, skin_shade)
			var eye_style: String = st["eyes"]
			if eye_style == "narrow":
				_rect(img, cx - 4, head_cy + 1, 3, 1, EYE)
				_rect(img, cx + 2, head_cy + 1, 3, 1, EYE)
				_rect(img, cx - 4, head_cy, 3, 1, hair.darkened(0.2))
				_rect(img, cx + 2, head_cy, 3, 1, hair.darkened(0.2))
			elif eye_style == "soft":
				_rect(img, cx - 4, head_cy, 2, 2, EYE)
				_rect(img, cx + 2, head_cy, 2, 2, EYE)
				_px(img, cx - 4, head_cy, Color(1, 1, 1, 0.9))
				_px(img, cx + 2, head_cy, Color(1, 1, 1, 0.9))
				_px(img, cx - 5, head_cy + 1, skin_shade)
				_px(img, cx + 5, head_cy + 1, skin_shade)
			else:
				_rect(img, cx - 4, head_cy, 2, 2, EYE)
				_rect(img, cx + 2, head_cy, 2, 2, EYE)
				_px(img, cx - 4, head_cy, Color(1, 1, 1, 0.85))
				_px(img, cx + 2, head_cy, Color(1, 1, 1, 0.85))
			_px(img, cx, head_cy + 2, skin_shade)
			if anim == "react":
				_rect(img, cx - 1, head_cy + 4, 2, 2, Color(0.52, 0.24, 0.22))
			else:
				_rect(img, cx - 1, head_cy + 4, 3, 1, MOUTH)

	# --- hair silhouette -------------------------------------------
	var hair_style: String = st["hair_style"]
	if not back:
		if hair_style == "short":
			_rect(img, cx - 5, head_cy - 3, 10, 2, hair)
			_rect(img, cx - 6, head_cy - 1, 1, 4, hair)
			_rect(img, cx + 5, head_cy - 1, 1, 4, hair)
			_px(img, cx + 2, head_cy - 3, hair_light)
			_px(img, cx - 2, head_cy - 3, hair_light)
		elif hair_style == "bun":
			_ellipse(img, cx - 6, head_cy - 2, 3, 3, hair)
			_ellipse(img, cx + 6, head_cy - 2, 3, 3, hair)
			_rect(img, cx - 5, head_cy - 4, 10, 2, hair)
			_px(img, cx - 6, head_cy - 3, hair_light)
			rect_dummy(img, cx)
		elif hair_style == "swept":
			_rect(img, cx - 6, head_cy - 4, 12, 2, hair)
			_rect(img, cx - 6, head_cy - 2, 2, 5, hair)
			_rect(img, cx + 4, head_cy - 2, 2, 6, hair)
			_rect(img, cx - 4, head_cy - 3, 6, 1, hair_light)
			_px(img, cx + 4, head_cy - 4, hair.lightened(0.15))
			_px(img, cx - 6, head_cy + 1, SILVER_DARK)

	# --- hat --------------------------------------------------------
	var hat_style: String = st["hat_style"]
	var hat_color: Color = st["hat_color"]
	if hat_style == "toque":
		_rect(img, cx - 5, head_cy - 6, 10, 3, hat_color.darkened(0.12))
		_ellipse(img, cx, head_cy - 8, 7, 4, hat_color)
		_ellipse(img, cx, head_cy - 9, 5, 3, hat_color.lightened(0.18))
		_rect(img, cx - 6, head_cy - 6, 1, 3, hat_color.darkened(0.2))
	elif hat_style == "scarf":
		_ellipse(img, cx, head_cy - 5, 7, 4, hat_color)
		_rect(img, cx - 6, head_cy - 3, 12, 2, hat_color)
		_rect(img, cx - 6, head_cy - 3, 12, 1, hat_color.lightened(0.16))
		_rect(img, cx + 5, head_cy - 2, 2, 4, hat_color.darkened(0.14))
		_px(img, cx + 6, head_cy + 1, hat_color.darkened(0.24))

	# --- arms -------------------------------------------------------
	var hand_y := shoulder_y + 11
	if anim == "react":
		if side:
			_rect(img, cx + 2, shoulder_y - 4, 3, 8, sleeve)
			_rect(img, cx + 2, shoulder_y - 7, 3, 4, skin)
		else:
			var ax_l := cx - sw - 2
			var ax_r := cx + sw - 1
			var raise_a := 0
			var raise_b := 0
			if frame % 2 == 0:
				raise_a = 1
			else:
				raise_b = 1
			_rect(img, ax_l, shoulder_y - 4 - raise_a, 3, 9, sleeve)
			_rect(img, ax_r, shoulder_y - 4 - raise_b, 3, 9, sleeve_shade)
			_rect(img, ax_l, shoulder_y - 7 - raise_a, 3, 4, skin)
			_rect(img, ax_r, shoulder_y - 7 - raise_b, 3, 4, skin)
	elif anim == "cook":
		if side:
			_rect(img, cx + 2, shoulder_y + 5, 6, 3, sleeve)
			_rect(img, cx + 7, shoulder_y + 4, 3, 3, skin)
			var spoon_y := shoulder_y + 3 - (frame % 2)
			_rect(img, cx + 9, spoon_y, 5, 1, WOOD)
			_px(img, cx + 13, spoon_y - 1, WOOD.lightened(0.2))
		else:
			var stir := 0
			if frame % 2 == 1:
				stir = 1
			_rect(img, cx - 7, shoulder_y + 5, 4, 6, sleeve)
			_rect(img, cx + 4, shoulder_y + 5, 4, 6, sleeve_shade)
			_rect(img, cx - 5, shoulder_y + 9, 3, 3, skin)
			_rect(img, cx + 2, shoulder_y + 9, 3, 3, skin)
			_rect(img, cx - 2 + stir, shoulder_y + 8, 5, 1, WOOD)
			_px(img, cx - 3 + stir, shoulder_y + 7, WOOD.lightened(0.25))
	elif anim == "talk":
		if side:
			_rect(img, cx + 1, shoulder_y + 2, 3, 7, sleeve)
			_rect(img, cx + 2, shoulder_y + 8, 3, 3, skin)
		else:
			var hand_lift := frame % 2
			_rect(img, cx - sw - 2, shoulder_y + 2, 3, 9, sleeve)
			_rect(img, cx - sw - 2, hand_y, 3, 3, skin)
			_rect(img, cx + sw - 3, shoulder_y + 1, 3, 6, sleeve_shade)
			_rect(img, cx + sw - 4, shoulder_y - 2 - hand_lift, 3, 4, skin)
	else:
		if side:
			_rect(img, cx + 1 + arm, shoulder_y + 2, 3, 9, sleeve)
			_rect(img, cx + 1 + arm, hand_y, 3, 3, skin)
			_rect(img, cx - 4 - arm, shoulder_y + 2, 2, 8, sleeve_shade)
		else:
			var swing_a := int(floor(float(arm) * 0.5))
			var swing_b := int(ceil(float(arm) * 0.5))
			_rect(img, cx - sw - 2, shoulder_y + 2 - swing_a, 3, 9, sleeve)
			_rect(img, cx + sw - 1, shoulder_y + 2 + swing_b, 3, 9, sleeve_shade)
			_rect(img, cx - sw - 2, hand_y - swing_a, 3, 3, skin)
			_rect(img, cx + sw - 1, hand_y + swing_b, 3, 3, skin_shade)


## No-op hook kept so the hair branches stay symmetrical if extended.
static func rect_dummy(_img: Image, _x: int) -> void:
	pass


# --- styles --------------------------------------------------------------

static func _style(kind: String) -> Dictionary:
	match kind:
		"mira":
			return {
				"sw": 9,
				"top": DRESS, "top_shade": DRESS_SHADE, "top_line": DRESS_SHADE,
				"sleeve": DRESS, "sleeve_shade": DRESS_SHADE,
				"legs": SKIN, "legs_shade": SKIN_SHADE,
				"shoes": BOOTS, "shoes_shade": BOOTS_SHADE,
				"skin": SKIN, "skin_shade": SKIN_SHADE,
				"hair": MIRA_HAIR, "hair_light": MIRA_HAIR_LIGHT, "hair_style": "bun",
				"hat_style": "scarf", "hat_color": APRON,
				"accent": APRON, "accent_style": "neckerchief",
				"apron": APRON, "trim": NONE, "eyes": "soft",
				"skirt": true, "skirt_color": DRESS, "skirt_shade": DRESS_SHADE,
			}
		"legendary":
			return {
				"sw": 10,
				"top": SUIT, "top_shade": SUIT_SHADE, "top_line": SUIT_LINE,
				"sleeve": SUIT, "sleeve_shade": SUIT_SHADE,
				"legs": SUIT_SLACK, "legs_shade": SUIT_SHADE,
				"shoes": Color(0.10, 0.09, 0.11), "shoes_shade": Color(0.07, 0.06, 0.08),
				"skin": SKIN, "skin_shade": SKIN_SHADE,
				"hair": SILVER, "hair_light": SILVER.lightened(0.18), "hair_style": "swept",
				"hat_style": "none", "hat_color": NONE,
				"accent": CRAVAT, "accent_style": "cravat",
				"apron": NONE, "trim": GOLD, "eyes": "narrow",
				"skirt": false, "skirt_color": NONE, "skirt_shade": NONE,
			}
		_:
			return {
				"sw": 8,
				"top": COAT, "top_shade": COAT_SHADE, "top_line": COAT_LINE,
				"sleeve": COAT, "sleeve_shade": COAT_SHADE,
				"legs": PANTS, "legs_shade": PANTS_SHADE,
				"shoes": BOOTS, "shoes_shade": BOOTS_SHADE,
				"skin": SKIN, "skin_shade": SKIN_SHADE,
				"hair": HAIR, "hair_light": HAIR_LIGHT, "hair_style": "short",
				"hat_style": "toque", "hat_color": HAT,
				"accent": SCARF, "accent_style": "scarf",
				"apron": NONE, "trim": NONE, "eyes": "round",
				"skirt": false, "skirt_color": NONE, "skirt_shade": NONE,
			}


# --- frames --------------------------------------------------------------

## One cached frame. cell: 0 down, 1 up, 2 right, 3 left.
static func frame_texture(kind: String, cell: int, anim: String, frame: int) -> Texture2D:
	var key := "%s_%d_%s_%d" % [kind, cell, anim, frame]
	if _cache.has(key):
		return _cache[key]
	var img := _img(W, H)
	_draw(img, _style(kind), cell, anim, frame)
	if cell == 3:
		img.flip_x()
	var t := _tex(img)
	_cache[key] = t
	return t


static func _build(kind: String, anims: Array) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var dirs := ["down", "up", "right", "left"]
	for cell in range(4):
		for anim: String in anims:
			var name := StringName(dirs[cell] + "_" + anim)
			frames.add_animation(name)
			frames.set_animation_speed(name, _anim_speed(anim))
			frames.set_animation_loop(name, anim != "react")
			for i in range(_frame_count(anim)):
				frames.add_frame(name, frame_texture(kind, cell, anim, i))
	return frames


static func player_frames() -> SpriteFrames:
	if _cache.has("player_frames"):
		return _cache["player_frames"]
	var f := _build("player", ["idle", "walk", "run", "talk", "cook", "react"])
	_cache["player_frames"] = f
	return f


static func mira_frames() -> SpriteFrames:
	if _cache.has("mira_frames"):
		return _cache["mira_frames"]
	var f := _build("mira", ["idle", "walk", "talk"])
	_cache["mira_frames"] = f
	return f


static func legendary_frames() -> SpriteFrames:
	if _cache.has("legendary_frames"):
		return _cache["legendary_frames"]
	var f := _build("legendary", ["idle", "walk", "talk"])
	_cache["legendary_frames"] = f
	return f


# --- portraits -----------------------------------------------------------

## 48x48 dialogue portrait. kind: "you", "mira" or "legendary".
static func portrait(kind: String) -> Texture2D:
	var key := "portrait2_%s" % kind
	if _cache.has(key):
		return _cache[key]
	var img := _img(48, 48)
	var st := _style("mira" if kind == "mira" else ("legendary" if kind == "legendary" else "player"))
	var skin: Color = st["skin"]
	var skin_shade: Color = st["skin_shade"]
	var hair: Color = st["hair"]
	var hair_light: Color = st["hair_light"]
	var top: Color = st["top"]
	var top_shade: Color = st["top_shade"]
	var cx := 24

	# shoulders
	_rect(img, 5, 36, 38, 12, top)
	_rect(img, 5, 36, 38, 2, top.lightened(0.12))
	_rect(img, 36, 36, 7, 12, top_shade)
	# collar opening
	if kind != "legendary":
		_rect(img, 20, 36, 8, 9, skin_shade)
	else:
		_rect(img, 19, 36, 10, 12, CRAVAT)
		_rect(img, 22, 38, 4, 8, CRAVAT.darkened(0.25))

	# neck
	_rect(img, 20, 32, 8, 6, skin_shade)

	# head
	_ellipse(img, cx, 24, 13, 14, skin)
	_ellipse(img, cx, 30, 10, 6, skin_shade)
	_ellipse(img, cx, 22, 13, 12, skin)
	# ears
	_ellipse(img, 10, 25, 2, 3, skin_shade)
	_ellipse(img, 38, 25, 2, 3, skin_shade)

	# hair mass
	if kind == "legendary":
		_ellipse(img, cx, 15, 14, 10, hair)
		_rect(img, 10, 14, 4, 12, hair)
		_rect(img, 34, 14, 4, 10, hair)
		_rect(img, 14, 10, 20, 3, hair_light)
		_ellipse(img, cx, 11, 11, 6, hair)
	else:
		_ellipse(img, cx, 15, 14, 11, hair)
		_rect(img, 10, 15, 4, 12, hair)
		_rect(img, 34, 15, 4, 9, hair)
		_ellipse(img, cx - 1, 12, 10, 5, hair_light)

	# eyes
	if kind == "legendary":
		_rect(img, 16, 24, 6, 2, EYE)
		_rect(img, 27, 24, 6, 2, EYE)
		_rect(img, 15, 21, 7, 2, hair.darkened(0.25))
		_rect(img, 27, 21, 7, 2, hair.darkened(0.25))
	else:
		_rect(img, 17, 23, 4, 3, EYE)
		_rect(img, 28, 23, 4, 3, EYE)
		_px(img, 17, 23, Color(1, 1, 1, 0.9))
		_px(img, 28, 23, Color(1, 1, 1, 0.9))
		_rect(img, 16, 21, 5, 1, hair.darkened(0.2))
		_rect(img, 28, 21, 5, 1, hair.darkened(0.2))

	# nose and mouth
	_px(img, cx, 28, skin_shade)
	_px(img, cx, 29, skin_shade)
	if kind == "mira":
		_rect(img, 21, 32, 7, 2, MOUTH)
		_rect(img, 22, 33, 5, 1, Color(0.86, 0.55, 0.52))
		for p in [Vector2i(16, 30), Vector2i(32, 30), Vector2i(18, 31), Vector2i(30, 31)]:
			_px(img, p.x, p.y, Color(0.74, 0.48, 0.38))
	elif kind == "legendary":
		_rect(img, 20, 32, 9, 1, Color(0.52, 0.30, 0.28))
		_rect(img, 19, 30, 3, 1, hair.darkened(0.1))
		_rect(img, 28, 30, 3, 1, hair.darkened(0.1))
	else:
		_rect(img, 21, 32, 6, 1, MOUTH)

	# headwear
	if kind == "mira":
		_ellipse(img, cx, 8, 15, 6, APRON)
		_rect(img, 9, 11, 30, 3, APRON)
		_rect(img, 9, 11, 30, 1, APRON.lightened(0.2))
	elif kind == "player" or kind == "you":
		var hat: Color = HAT
		_rect(img, 13, 8, 22, 4, HAT_SHADE)
		_ellipse(img, cx, 5, 15, 7, hat)
		_ellipse(img, cx, 3, 11, 5, hat.lerp(Color.WHITE, 0.5))
	else:
		# legendary: a thin gold chain and collar pin
		_rect(img, 16, 38, 16, 1, GOLD)
		_px(img, 31, 41, GOLD)

	var t := _tex(img)
	_cache[key] = t
	return t
