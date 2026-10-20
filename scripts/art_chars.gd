class_name ArtChars
extends RefCounted
## Overworld character sprites at 32x48, drawn in the reference chef style:
## rounded human silhouette, one-pixel dark outline, oversized toque, red
## neckerchief, double-breasted coat and a dark work apron.
##
## Every character is built from the same body so they read as one art
## direction, and differ only through the style dictionary (colours, hair,
## headwear, apron). Frames are generated once and cached.
##
## Convention: the sprite canvas is 32x48 and the feet stand at y=45, so a node
## whose origin is on the ground draws it with BASE_OFFSET.

const W := 32
const H := 48
const BASE_Y := 45
## Offset that puts the soles on the node origin: -(45 - 48/2).
const BASE_OFFSET := Vector2(0, -21)

# --- palette -------------------------------------------------------------

const OUTLINE := Color(0.17, 0.12, 0.11)
const SKIN := Color(0.95, 0.75, 0.58)
const SKIN_SHADE := Color(0.83, 0.60, 0.44)
const SKIN_BLUSH := Color(0.90, 0.55, 0.44)
const FRECKLE := Color(0.72, 0.45, 0.33)
const EYE := Color(0.16, 0.11, 0.10)
const MOUTH := Color(0.62, 0.30, 0.27)

# the player: white-blue chef coat, dark apron, red neckerchief, auburn hair
const COAT := Color(0.93, 0.95, 0.97)
const COAT_SHADE := Color(0.76, 0.81, 0.87)
const COAT_LINE := Color(0.62, 0.68, 0.75)
const BUTTON := Color(0.24, 0.28, 0.36)
const APRON_DARK := Color(0.30, 0.22, 0.19)
const APRON_DARK_SHADE := Color(0.22, 0.16, 0.14)
const APRON_TIE := Color(0.88, 0.86, 0.82)
const NECKERCHIEF := Color(0.80, 0.22, 0.20)
const NECKERCHIEF_SHADE := Color(0.62, 0.15, 0.15)
const TOQUE := Color(0.99, 0.99, 0.97)
const TOQUE_SHADE := Color(0.84, 0.85, 0.87)
const TOQUE_LINE := Color(0.72, 0.74, 0.77)
const TROUSER := Color(0.23, 0.20, 0.21)
const TROUSER_SHADE := Color(0.17, 0.15, 0.16)
const SHOE := Color(0.14, 0.12, 0.13)
const SHOE_SHINE := Color(0.34, 0.31, 0.32)
const HAIR := Color(0.50, 0.24, 0.14)
const HAIR_LIGHT := Color(0.66, 0.35, 0.20)
const HAIR_DARK := Color(0.37, 0.17, 0.10)

# Mira: warm sage apron over a cream dress, dark auburn hair
const MIRA_DRESS := Color(0.95, 0.90, 0.78)
const MIRA_DRESS_SHADE := Color(0.82, 0.76, 0.63)
const MIRA_APRON := Color(0.42, 0.56, 0.36)
const MIRA_APRON_SHADE := Color(0.32, 0.44, 0.28)
const MIRA_HAIR := Color(0.36, 0.19, 0.13)
const MIRA_HAIR_LIGHT := Color(0.52, 0.29, 0.19)

# the legendary chef: black suit, deep red cravat, silver hair
const SUIT := Color(0.16, 0.15, 0.19)
const SUIT_SHADE := Color(0.11, 0.10, 0.14)
const SUIT_LINE := Color(0.26, 0.25, 0.31)
const SUIT_SHIRT := Color(0.90, 0.90, 0.93)
const SILVER := Color(0.83, 0.84, 0.87)
const SILVER_LIGHT := Color(0.94, 0.95, 0.97)
const SILVER_DARK := Color(0.60, 0.62, 0.68)
const CRAVAT := Color(0.44, 0.09, 0.13)
const GOLD := Color(0.87, 0.73, 0.38)

const WOOD := Color(0.56, 0.38, 0.23)
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
	_ellipse(img, cx, cy, rx, 2, Color(0.06, 0.10, 0.06, 0.14))
	_ellipse(img, cx, cy, rx - 2, 1, Color(0.06, 0.10, 0.06, 0.20))


## Wrap every opaque pixel in a one pixel dark edge, the way the reference
## sprite is inked. Grows outward only, so the body itself is unchanged.
static func _outline(img: Image, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(h):
		for x in range(w):
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in dirs:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if src.get_pixel(nx, ny).a > 0.0:
					img.set_pixel(x, y, color)
					break


# --- animation timing ----------------------------------------------------

static func _frame_count(anim: String) -> int:
	match anim:
		"walk", "run":
			return 4
		"idle", "talk", "cook", "react":
			return 2
	return 1


static func _anim_speed(anim: String) -> float:
	match anim:
		"walk":
			return 8.0
		"run":
			return 12.0
		"idle":
			return 2.2
		"talk":
			return 3.6
		"cook":
			return 3.0
		"react":
			return 5.0
	return 4.0


## Body offsets for one frame, shared by every character so they move alike.
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
			bob = int([0, -1, 0, -1][f])
			stride = int([2, 0, -2, 0][f])
			lift_a = int([0, 1, 0, 0][f])
			lift_b = int([0, 0, 0, 1][f])
			arm = int([-2, 0, 2, 0][f])
		"run":
			bob = int([-1, -2, -1, -2][f])
			stride = int([3, 0, -3, 0][f])
			lift_a = int([1, 3, 1, 0][f])
			lift_b = int([0, 0, 1, 3][f])
			arm = int([-4, 0, 4, 0][f])
			lean = 1
		"idle":
			bob = int([0, -1][frame % 2])
		"talk":
			bob = int([0, -1][frame % 2])
		"cook":
			bob = 0
		"react":
			bob = int([-2, -1][frame % 2])
			lean = -1
	return {
		"bob": bob, "stride": stride, "lift_a": lift_a,
		"lift_b": lift_b, "arm": arm, "lean": lean,
	}


# --- shared body ---------------------------------------------------------

## One frame of the shared figure. cell: 0 down, 1 up, 2 right (3 mirrors it).
static func _draw(img: Image, st: Dictionary, cell: int, anim: String, frame: int) -> void:
	var p := _pose(anim, frame)
	var bob: int = p["bob"]
	var stride: int = p["stride"]
	var lift_a: int = p["lift_a"]
	var lift_b: int = p["lift_b"]
	var arm: int = p["arm"]
	var lean: int = p["lean"]

	var side := cell == 2 or cell == 3
	var back := cell == 1
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
	var hair: Color = st["hair"]
	var hair_light: Color = st["hair_light"]
	var hair_dark: Color = st["hair_dark"]
	var apron: Color = st["apron"]
	var apron_shade: Color = st["apron_shade"]

	var hem_y := 41
	var hip_y := 32 + bob
	var shoulder_y := 21 + bob + lean
	var head_cy := 14 + bob + lean

	_shadow(img, cx, 44, sw + 2)

	# --- legs: two separately drawn limbs, always readable ----------
	if side:
		var back_leg := cx - 3 - stride
		_rect(img, back_leg, hip_y, 4, hem_y - hip_y - lift_b, legs_shade)
		_rect(img, back_leg - 1, hem_y - lift_b, 6, 3, shoes.darkened(0.1))
		var front_leg := cx - 1 + stride
		_rect(img, front_leg, hip_y, 4, hem_y - hip_y - lift_a, legs)
		_rect(img, front_leg - 1, hem_y - lift_a, 6, 3, shoes)
		_px(img, front_leg + 1, hem_y - lift_a, Color(0.32, 0.29, 0.30))
	else:
		var lx := cx - 4
		var rx := cx + 1
		_rect(img, lx, hip_y, 3, hem_y - hip_y - lift_a, legs)
		_rect(img, rx, hip_y, 3, hem_y - hip_y - lift_b, legs_shade)
		_rect(img, lx - 1, hem_y - lift_a, 5, 3, shoes)
		_rect(img, rx - 1, hem_y - lift_b, 5, 3, shoes)
		_px(img, lx, hem_y - lift_a, SHOE_SHINE)
		_px(img, rx, hem_y - lift_b, Color(0.24, 0.22, 0.23))

	# --- coat ---------------------------------------------------------
	if side:
		var tx := cx - 5
		_rect(img, tx, shoulder_y, 9, 12, top)
		_rect(img, tx, shoulder_y, 9, 1, top.lightened(0.16))
		_rect(img, tx + 7, shoulder_y + 1, 2, 11, top_shade)
		_rect(img, tx, shoulder_y + 9, 8, 4, top)
		_rect(img, tx, shoulder_y + 12, 8, 1, top_line)
	else:
		var w := sw * 2
		# shoulders are rounded, not a straight bar
		_rect(img, cx - sw + 1, shoulder_y, w - 2, 2, top)
		_rect(img, cx - sw, shoulder_y + 2, w, 8, top)
		_rect(img, cx - sw + 1, shoulder_y + 10, w - 2, 2, top)
		_rect(img, cx - sw, shoulder_y, w, 1, top.lightened(0.18))
		_rect(img, cx + sw - 2, shoulder_y + 1, 2, 10, top_shade)
		_rect(img, cx - sw, shoulder_y + 1, 1, 10, top_shade)
		if not back:
			# double-breasted front: centre seam and two button columns
			_rect(img, cx - 1, shoulder_y + 3, 1, 8, top_line)
			for i in range(3):
				var by := shoulder_y + 3 + i * 3
				_px(img, cx - 3, by, BUTTON)
				_px(img, cx + 1, by, BUTTON)
		else:
			_rect(img, cx - 1, shoulder_y + 1, 1, 10, top_shade)

	# --- apron --------------------------------------------------------
	if apron.a > 0.0:
		if side:
			_rect(img, cx - 4, shoulder_y + 8, 8, 12, apron)
			_rect(img, cx + 2, shoulder_y + 8, 2, 12, apron_shade)
			_rect(img, cx - 4, shoulder_y + 8, 8, 1, apron.lightened(0.10))
		else:
			_rect(img, cx - 5, shoulder_y + 9, 10, 11, apron)
			_rect(img, cx - 5, shoulder_y + 9, 10, 1, apron.lightened(0.12))
			_rect(img, cx + 3, shoulder_y + 10, 2, 10, apron_shade)
			if not back:
				# waist tie and a small pocket
				_rect(img, cx - 5, shoulder_y + 13, 10, 1, apron_shade)
				_rect(img, cx - 2, shoulder_y + 15, 4, 3, apron_shade)
				_px(img, cx - 1, shoulder_y + 15, apron.lightened(0.10))
			else:
				# bow at the back of the waist
				_rect(img, cx - 4, shoulder_y + 9, 8, 1, st["tie"])
				_ellipse(img, cx - 2, shoulder_y + 11, 2, 2, st["tie"])
				_ellipse(img, cx + 2, shoulder_y + 11, 2, 2, st["tie"])

	# --- neck and collar ---------------------------------------------
	if not back:
		_rect(img, cx - 2, head_cy + 5, 4, 3, skin_shade)
		var neckerchief: Color = st["neckerchief"]
		if neckerchief.a > 0.0:
			_rect(img, cx - 4, head_cy + 6, 8, 2, neckerchief)
			_rect(img, cx - 1, head_cy + 6, 2, 4, neckerchief)
			_rect(img, cx - 3, head_cy + 6, 6, 1, neckerchief.lightened(0.22))
			_px(img, cx - 1, head_cy + 9, neckerchief.darkened(0.18))
		var collar: Color = st["collar"]
		if collar.a > 0.0:
			_px(img, cx - 4, head_cy + 5, collar)
			_px(img, cx + 3, head_cy + 5, collar)
	else:
		_rect(img, cx - 2, head_cy + 5, 4, 2, st["collar"] if st["collar"].a > 0.0 else top_shade)

	# --- head ---------------------------------------------------------
	if back:
		_ellipse(img, cx, head_cy, 6, 6, hair)
		_ellipse(img, cx, head_cy - 1, 5, 5, hair_light)
		_ellipse(img, cx, head_cy + 3, 5, 3, hair_dark)
	else:
		# hair behind the face
		_ellipse(img, cx, head_cy, 7, 6, hair)
		if side:
			_ellipse(img, cx + 1, head_cy + 1, 5, 5, skin)
			_ellipse(img, cx, head_cy + 3, 3, 3, skin_shade)
			# profile: brow, eye, nose, mouth
			_px(img, cx + 3, head_cy - 1, hair_dark)
			_rect(img, cx + 3, head_cy + 1, 2, 2, EYE)
			_px(img, cx + 3, head_cy + 1, Color(1, 1, 1, 0.9))
			_px(img, cx + 6, head_cy + 2, skin_shade)
			_px(img, cx + 6, head_cy + 3, skin_shade)
			_rect(img, cx + 3, head_cy + 4, 2, 1, MOUTH)
			_px(img, cx + 3, head_cy + 3, SKIN_BLUSH)
		else:
			_ellipse(img, cx, head_cy + 1, 5, 5, skin)
			_ellipse(img, cx, head_cy + 4, 4, 2, skin_shade)
			# cheeks
			_px(img, cx - 4, head_cy + 3, SKIN_BLUSH)
			_px(img, cx + 4, head_cy + 3, SKIN_BLUSH)
			var eyes: String = st["eyes"]
			if eyes == "narrow":
				_rect(img, cx - 4, head_cy + 1, 3, 1, EYE)
				_rect(img, cx + 2, head_cy + 1, 3, 1, EYE)
				_rect(img, cx - 4, head_cy, 3, 1, hair_dark)
				_rect(img, cx + 2, head_cy, 3, 1, hair_dark)
			else:
				_rect(img, cx - 4, head_cy + 1, 2, 2, EYE)
				_rect(img, cx + 3, head_cy + 1, 2, 2, EYE)
				_px(img, cx - 4, head_cy + 1, Color(1, 1, 1, 0.92))
				_px(img, cx + 3, head_cy + 1, Color(1, 1, 1, 0.92))
				_px(img, cx - 5, head_cy, hair_dark)
				_px(img, cx + 4, head_cy, hair_dark)
			if anim == "react":
				_rect(img, cx - 1, head_cy + 4, 3, 2, Color(0.50, 0.22, 0.21))
			else:
				_rect(img, cx - 1, head_cy + 4, 3, 1, MOUTH)
				_px(img, cx - 2, head_cy + 4, MOUTH.darkened(0.15))
			if bool(st["freckles"]):
				_px(img, cx - 4, head_cy + 2, FRECKLE)
				_px(img, cx + 4, head_cy + 2, FRECKLE)
				_px(img, cx - 3, head_cy + 3, FRECKLE)

	# --- hair silhouette ---------------------------------------------
	var hair_style: String = st["hair_style"]
	if not back:
		if hair_style == "locks":
			# long side locks past the shoulders, like the reference
			_rect(img, cx - 7, head_cy - 2, 2, 12, hair)
			_rect(img, cx + 6, head_cy - 2, 2, 12, hair)
			_rect(img, cx - 7, head_cy - 2, 1, 10, hair_light)
			_ellipse(img, cx, head_cy - 3, 7, 3, hair)
			_rect(img, cx - 5, head_cy - 5, 10, 2, hair)
			_px(img, cx - 3, head_cy - 5, hair_light)
			_px(img, cx + 2, head_cy - 5, hair_light)
			if side:
				_rect(img, cx - 6, head_cy - 1, 2, 8, hair_dark)
		elif hair_style == "bun":
			_ellipse(img, cx - 7, head_cy - 1, 3, 3, hair)
			_ellipse(img, cx + 7, head_cy - 1, 3, 3, hair)
			_rect(img, cx - 6, head_cy - 3, 12, 2, hair)
			_px(img, cx - 7, head_cy - 2, hair_light)
			_rect(img, cx - 7, head_cy + 1, 2, 7, hair_dark)
		elif hair_style == "swept":
			_rect(img, cx - 7, head_cy - 4, 14, 2, hair)
			_rect(img, cx - 7, head_cy - 2, 2, 6, hair_dark)
			_rect(img, cx + 5, head_cy - 2, 2, 7, hair_dark)
			_rect(img, cx - 5, head_cy - 3, 8, 1, hair_light)
			_px(img, cx + 5, head_cy - 4, hair_light)
	else:
		_ellipse(img, cx, head_cy - 1, 6, 4, hair_light)
		_rect(img, cx - 6, head_cy + 1, 2, 8, hair_dark)
		_rect(img, cx + 5, head_cy + 1, 2, 8, hair_dark)

	# --- headwear -----------------------------------------------------
	var hat_style: String = st["hat_style"]
	var hat: Color = st["hat_color"]
	if hat_style == "toque":
		# broad band, then the big mushroom puff
		_rect(img, cx - 6, head_cy - 6, 12, 3, TOQUE_SHADE)
		_rect(img, cx - 6, head_cy - 6, 12, 1, TOQUE_LINE)
		_ellipse(img, cx - 5, head_cy - 7, 4, 3, hat)
		_ellipse(img, cx + 5, head_cy - 7, 4, 3, hat)
		_ellipse(img, cx, head_cy - 8, 7, 4, hat)
		_ellipse(img, cx - 1, head_cy - 9, 5, 2, Color(1, 1, 1, 1))
		_px(img, cx - 7, head_cy - 6, TOQUE_SHADE)
		_px(img, cx + 6, head_cy - 6, TOQUE_SHADE)
	elif hat_style == "scarf":
		_ellipse(img, cx, head_cy - 6, 7, 3, hat)
		_rect(img, cx - 6, head_cy - 5, 12, 2, hat)
		_rect(img, cx - 6, head_cy - 5, 12, 1, hat.lightened(0.18))
		_rect(img, cx + 5, head_cy - 4, 2, 5, hat.darkened(0.15))
	elif hat_style == "slick":
		# no hat: the legendary chef's swept silver hair is the silhouette
		_px(img, cx - 6, head_cy - 3, SILVER_LIGHT)
		_px(img, cx + 5, head_cy - 3, SILVER_LIGHT)

	# --- arms ---------------------------------------------------------
	var hand_y := shoulder_y + 10
	if anim == "react":
		var up := frame % 2
		if side:
			_rect(img, cx + 2, shoulder_y - 4 - up, 3, 8, sleeve)
			_rect(img, cx + 2, shoulder_y - 7 - up, 3, 3, skin)
		else:
			_rect(img, cx - sw - 2, shoulder_y - 4 - up, 3, 9, sleeve)
			_rect(img, cx + sw - 1, shoulder_y - 4 + up - 1, 3, 9, sleeve_shade)
			_rect(img, cx - sw - 2, shoulder_y - 7 - up, 3, 3, skin)
			_rect(img, cx + sw - 1, shoulder_y - 7 + up - 1, 3, 3, skin_shade)
	elif anim == "cook":
		if side:
			_rect(img, cx + 2, shoulder_y + 4, 5, 3, sleeve)
			_rect(img, cx + 6, shoulder_y + 3, 3, 3, skin)
			var spoon_y := shoulder_y + 2 - (frame % 2)
			_rect(img, cx + 8, spoon_y, 5, 1, WOOD)
			_ellipse(img, cx + 13, spoon_y, 2, 1, WOOD.lightened(0.2))
		else:
			var stir := frame % 2
			_rect(img, cx - sw - 2, shoulder_y + 2, 3, 8, sleeve)
			_rect(img, cx + sw - 1, shoulder_y + 2, 3, 8, sleeve_shade)
			_rect(img, cx - sw - 2, hand_y - 1, 3, 3, skin)
			_rect(img, cx + sw - 1, hand_y - 1, 3, 3, skin_shade)
			_rect(img, cx - 2 + stir, hand_y + 1, 5, 1, WOOD)
			_px(img, cx - 3 + stir, hand_y + 1, WOOD.lightened(0.25))
	elif anim == "talk":
		if side:
			_rect(img, cx + 1, shoulder_y + 2, 3, 6, sleeve)
			_rect(img, cx + 2, shoulder_y + 7, 3, 3, skin)
		else:
			var lift := frame % 2
			_rect(img, cx - sw - 2, shoulder_y + 2, 3, 8, sleeve)
			_rect(img, cx - sw - 2, hand_y - 1, 3, 3, skin)
			_rect(img, cx + sw - 1, shoulder_y + 1, 3, 5, sleeve_shade)
			_rect(img, cx + sw - 2, shoulder_y - 2 - lift, 3, 4, skin)
	else:
		if side:
			_rect(img, cx + 1 + arm, shoulder_y + 2, 3, 8, sleeve)
			_rect(img, cx + 1 + arm, hand_y - 1, 3, 3, skin)
			_rect(img, cx - 4 - arm, shoulder_y + 2, 2, 7, sleeve_shade)
		else:
			var swing_a := int(floor(float(arm) * 0.5))
			var swing_b := int(ceil(float(arm) * 0.5))
			_rect(img, cx - sw - 2, shoulder_y + 2 - swing_a, 3, 8, sleeve)
			_rect(img, cx + sw - 1, shoulder_y + 2 + swing_b, 3, 8, sleeve_shade)
			_rect(img, cx - sw - 2, hand_y - 1 - swing_a, 3, 3, skin)
			_rect(img, cx + sw - 1, hand_y - 1 + swing_b, 3, 3, skin_shade)


# --- styles --------------------------------------------------------------

static func _style(kind: String) -> Dictionary:
	match kind:
		"mira":
			return {
				"sw": 7,
				"top": MIRA_DRESS, "top_shade": MIRA_DRESS_SHADE, "top_line": MIRA_DRESS_SHADE,
				"sleeve": MIRA_DRESS, "sleeve_shade": MIRA_DRESS_SHADE,
				"legs": SKIN, "legs_shade": SKIN_SHADE,
				"shoes": Color(0.30, 0.19, 0.15), "shoes_shade": Color(0.22, 0.13, 0.10),
				"skin": SKIN, "skin_shade": SKIN_SHADE,
				"hair": MIRA_HAIR, "hair_light": MIRA_HAIR_LIGHT, "hair_dark": Color(0.24, 0.12, 0.08),
				"hair_style": "bun",
				"hat_style": "scarf", "hat_color": MIRA_APRON,
				"apron": MIRA_APRON, "apron_shade": MIRA_APRON_SHADE,
				"tie": MIRA_DRESS, "collar": MIRA_DRESS_SHADE, "neckerchief": MIRA_APRON_SHADE,
				"eyes": "soft", "freckles": true,
			}
		"legendary":
			return {
				"sw": 8,
				"top": SUIT, "top_shade": SUIT_SHADE, "top_line": SUIT_LINE,
				"sleeve": SUIT, "sleeve_shade": SUIT_SHADE,
				"legs": SUIT_SHADE, "legs_shade": Color(0.08, 0.07, 0.10),
				"shoes": Color(0.09, 0.08, 0.10), "shoes_shade": Color(0.06, 0.05, 0.07),
				"skin": SKIN, "skin_shade": SKIN_SHADE,
				"hair": SILVER, "hair_light": SILVER_LIGHT, "hair_dark": SILVER_DARK,
				"hair_style": "swept",
				"hat_style": "slick", "hat_color": NONE,
				"apron": NONE, "apron_shade": NONE,
				"tie": GOLD, "collar": SUIT_SHIRT, "neckerchief": CRAVAT,
				"eyes": "narrow", "freckles": false,
			}
		_:
			return {
				"sw": 8,
				"top": COAT, "top_shade": COAT_SHADE, "top_line": COAT_LINE,
				"sleeve": COAT, "sleeve_shade": COAT_SHADE,
				"legs": TROUSER, "legs_shade": TROUSER_SHADE,
				"shoes": SHOE, "shoes_shade": Color(0.09, 0.08, 0.09),
				"skin": SKIN, "skin_shade": SKIN_SHADE,
				"hair": HAIR, "hair_light": HAIR_LIGHT, "hair_dark": HAIR_DARK,
				"hair_style": "locks",
				"hat_style": "toque", "hat_color": TOQUE,
				"apron": APRON_DARK, "apron_shade": APRON_DARK_SHADE,
				"tie": APRON_TIE, "collar": COAT_LINE, "neckerchief": NECKERCHIEF,
				"eyes": "round", "freckles": true,
			}


# --- frames --------------------------------------------------------------

## One cached frame. cell: 0 down, 1 up, 2 right, 3 left.
static func frame_texture(kind: String, cell: int, anim: String, frame: int) -> Texture2D:
	var key := "%s_%d_%s_%d" % [kind, cell, anim, frame]
	if _cache.has(key):
		return _cache[key]
	var st := _style(kind)
	var img := _img(W, H)
	_draw(img, st, cell, anim, frame)
	_outline(img, OUTLINE)
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

## 64x64 dialogue portrait: a head-and-shoulders bust lit by a warm kitchen,
## following the reference painting's framing.
static func portrait(kind: String) -> Texture2D:
	var key := "portrait3_%s" % kind
	if _cache.has(key):
		return _cache[key]
	var img := _img(64, 64)
	var st := _style("mira" if kind == "mira" else ("legendary" if kind == "legendary" else "player"))
	var skin: Color = st["skin"]
	var skin_shade: Color = st["skin_shade"]
	var hair: Color = st["hair"]
	var hair_light: Color = st["hair_light"]
	var hair_dark: Color = st["hair_dark"]
	var top: Color = st["top"]
	var top_shade: Color = st["top_shade"]
	var is_you := kind == "you" or kind == "player"
	var cx := 32

	# warm backdrop glow
	for y in range(64):
		for x in range(64):
			var dx := (float(x) - 32.0) / 32.0
			var dy := (float(y) - 30.0) / 34.0
			var d := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.34, 0.24, 0.20, 0.20 + d * 0.22))

	# shoulders and coat
	_ellipse(img, cx, 62, 26, 14, top)
	_rect(img, 8, 48, 48, 16, top)
	_rect(img, 8, 48, 48, 1, top.lightened(0.18))
	_rect(img, 46, 49, 10, 15, top_shade)
	_rect(img, 8, 49, 3, 15, top_shade)
	# collar V and buttons
	if kind == "legendary":
		_rect(img, 24, 47, 16, 17, SUIT_SHIRT)
		_rect(img, 27, 49, 10, 15, CRAVAT)
		_rect(img, 31, 51, 3, 11, CRAVAT.darkened(0.28))
		_rect(img, 22, 46, 3, 8, SUIT_LINE)
		_rect(img, 39, 46, 3, 8, SUIT_LINE)
	else:
		_rect(img, 26, 47, 12, 17, top.lightened(0.06))
		for i in range(3):
			_px(img, 30, 51 + i * 4, BUTTON)
			_px(img, 34, 51 + i * 4, BUTTON)
	# neck
	_rect(img, 28, 42, 8, 8, skin_shade)

	# head
	_ellipse(img, cx, 30, 15, 16, hair)
	_ellipse(img, cx, 32, 13, 14, skin)
	_ellipse(img, cx, 40, 11, 6, skin_shade)
	_ellipse(img, cx, 28, 13, 12, skin)
	# ears
	_ellipse(img, 18, 32, 2, 4, skin_shade)
	_ellipse(img, 46, 32, 2, 4, skin_shade)

	# hair
	if kind == "legendary":
		_ellipse(img, cx, 19, 16, 10, hair)
		_rect(img, 16, 16, 4, 14, hair_dark)
		_rect(img, 44, 16, 4, 12, hair_dark)
		_rect(img, 20, 13, 24, 4, hair_light)
		_ellipse(img, cx, 14, 12, 6, hair)
		_px(img, 24, 12, SILVER_LIGHT)
		_px(img, 40, 12, SILVER_LIGHT)
	elif kind == "mira":
		_ellipse(img, cx, 20, 16, 12, hair)
		_rect(img, 15, 20, 5, 16, hair_dark)
		_rect(img, 44, 20, 5, 13, hair_dark)
		_ellipse(img, 16, 15, 6, 6, hair)
		_ellipse(img, 48, 15, 6, 6, hair)
		_ellipse(img, cx, 16, 12, 7, hair_light)
	else:
		# auburn hair with a loose side sweep, as in the reference
		_ellipse(img, cx, 19, 17, 12, hair)
		_ellipse(img, cx - 2, 15, 13, 8, hair_light)
		_rect(img, 14, 20, 5, 20, hair)
		_rect(img, 45, 20, 5, 17, hair)
		_rect(img, 14, 22, 2, 16, hair_dark)
		_rect(img, 48, 22, 2, 13, hair_dark)
		# stray curls
		_px(img, 13, 38, hair)
		_px(img, 49, 35, hair)
		_px(img, 12, 34, hair_light)
		_ellipse(img, cx - 8, 21, 4, 5, hair_light)

	# brows and eyes
	if kind == "legendary":
		_rect(img, 21, 29, 8, 2, hair_dark)
		_rect(img, 35, 29, 8, 2, hair_dark)
		_rect(img, 22, 32, 6, 2, EYE)
		_rect(img, 36, 32, 6, 2, EYE)
		_px(img, 23, 32, Color(1, 1, 1, 0.75))
	else:
		_rect(img, 21, 27, 8, 1, hair_dark.darkened(0.1))
		_rect(img, 35, 27, 8, 1, hair_dark.darkened(0.1))
		_ellipse(img, 24, 32, 3, 4, Color(0.98, 0.97, 0.95))
		_ellipse(img, 40, 32, 3, 4, Color(0.98, 0.97, 0.95))
		_rect(img, 23, 31, 3, 4, EYE)
		_rect(img, 39, 31, 3, 4, EYE)
		_px(img, 23, 31, Color(1, 1, 1, 0.95))
		_px(img, 39, 31, Color(1, 1, 1, 0.95))
		_px(img, 24, 34, skin_shade)
		_px(img, 40, 34, skin_shade)

	# nose
	_px(img, cx, 35, skin_shade)
	_rect(img, cx - 1, 36, 3, 1, skin_shade)

	# mouth and character
	if kind == "legendary":
		_rect(img, 27, 40, 10, 1, Color(0.46, 0.26, 0.26))
		_px(img, 26, 39, skin_shade)
		_px(img, 37, 39, skin_shade)
	elif kind == "mira":
		_rect(img, 27, 39, 10, 2, MOUTH)
		_rect(img, 29, 41, 6, 1, Color(0.88, 0.56, 0.53))
		for p in [Vector2i(21, 37), Vector2i(43, 37), Vector2i(23, 38), Vector2i(41, 38)]:
			_px(img, p.x, p.y, FRECKLE)
	else:
		_rect(img, 28, 39, 8, 2, MOUTH)
		_rect(img, 30, 41, 4, 1, Color(0.88, 0.56, 0.53))
		_px(img, 20, 37, FRECKLE)
		_px(img, 22, 38, FRECKLE)
		_px(img, 44, 37, FRECKLE)
		_px(img, 42, 38, FRECKLE)
		_px(img, 20, 35, SKIN_BLUSH)
		_px(img, 44, 35, SKIN_BLUSH)

	# headwear
	if kind == "legendary":
		_rect(img, 20, 46, 8, 1, GOLD)
		_px(img, 42, 50, GOLD)
	elif kind == "mira":
		_ellipse(img, cx, 11, 18, 7, MIRA_APRON)
		_rect(img, 12, 15, 40, 3, MIRA_APRON)
		_rect(img, 12, 15, 40, 1, MIRA_APRON.lightened(0.2))
	else:
		var hat := TOQUE
		_rect(img, 16, 13, 32, 4, TOQUE_SHADE)
		_rect(img, 16, 13, 32, 1, TOQUE_LINE)
		_ellipse(img, 22, 9, 9, 6, hat)
		_ellipse(img, 42, 9, 9, 6, hat)
		_ellipse(img, cx, 7, 16, 8, hat)
		_ellipse(img, cx - 2, 4, 11, 4, Color(1, 1, 1, 1))

	# neckerchief for the player, at the collar
	if is_you:
		_rect(img, 26, 45, 12, 3, NECKERCHIEF)
		_rect(img, 30, 47, 4, 6, NECKERCHIEF)
		_rect(img, 28, 45, 8, 1, NECKERCHIEF.lightened(0.22))
		_px(img, 31, 52, NECKERCHIEF_SHADE)

	var t := _tex(img)
	_cache[key] = t
	return t
