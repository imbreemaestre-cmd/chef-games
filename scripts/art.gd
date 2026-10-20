class_name Art
extends RefCounted
## Runtime pixel art for Sunberry Hollow.
##
## Every sprite in the 2D build is painted here into an Image at load time and
## cached, so the project ships no binary art yet: no import step, no filtering
## guesswork. Sizes are authored for a 640x360 viewport with 32 px tiles.
##
## Replacing a builder with a real .png later is a one-line change (return a
## loaded Texture2D instead of the painted one) and no gameplay code moves.

# --- palette -------------------------------------------------------------
const GRASS := Color(0.31, 0.54, 0.24)
const GRASS_DARK := Color(0.25, 0.45, 0.19)
const GRASS_LIGHT := Color(0.40, 0.65, 0.29)
const TUFT := Color(0.52, 0.76, 0.36)
const DIRT := Color(0.62, 0.48, 0.32)
const DIRT_DARK := Color(0.51, 0.39, 0.26)
const DIRT_LIGHT := Color(0.72, 0.58, 0.40)

const LEAF := Color(0.38, 0.63, 0.28)
const LEAF_LIGHT := Color(0.50, 0.75, 0.35)
const LEAF_DARK := Color(0.27, 0.48, 0.22)
const BARK := Color(0.92, 0.89, 0.83)
const BARK_DARK := Color(0.73, 0.69, 0.62)
const STONE := Color(0.60, 0.59, 0.56)
const STONE_DARK := Color(0.45, 0.44, 0.42)
const STONE_LIGHT := Color(0.74, 0.73, 0.69)

const BERRY := Color(0.66, 0.13, 0.25)
const BERRY_LIGHT := Color(0.91, 0.41, 0.50)
const BOWL := Color(0.55, 0.36, 0.24)
const BOWL_RIM := Color(0.78, 0.55, 0.35)
const CRUST := Color(0.79, 0.60, 0.37)
const CRUST_DARK := Color(0.62, 0.45, 0.27)
const TART_FILL := Color(0.25, 0.15, 0.33)
const TART_BERRY := Color(0.62, 0.42, 0.66)

const FIRE_RED := Color(1.0, 0.35, 0.15)
const FIRE_ORANGE := Color(1.0, 0.60, 0.22)
const FIRE_YELLOW := Color(1.0, 0.82, 0.33)
const LOG := Color(0.42, 0.27, 0.17)
const LOG_DARK := Color(0.31, 0.20, 0.13)

const SKIN := Color(0.95, 0.78, 0.62)
const SKIN_DARK := Color(0.85, 0.65, 0.49)
const HAT := Color(0.98, 0.97, 0.93)
const HAT_DARK := Color(0.86, 0.83, 0.76)
const COAT := Color(0.95, 0.93, 0.87)
const COAT_DARK := Color(0.82, 0.78, 0.71)
const SCARF := Color(0.81, 0.29, 0.25)
const PANTS := Color(0.24, 0.33, 0.45)
const BOOTS := Color(0.36, 0.23, 0.15)
const HAIR := Color(0.42, 0.27, 0.20)
const EYE := Color(0.23, 0.16, 0.13)

const FLOWER_PINK := Color(0.95, 0.56, 0.69)
const FLOWER_YELLOW := Color(0.98, 0.82, 0.38)

const TILE := 32
const CHEF_W := 24
const CHEF_H := 32

static var _cache: Dictionary = {}


# --- low level canvas helpers -------------------------------------------

static func _img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(maxi(0, y), mini(img.get_height(), y + h)):
		for px in range(maxi(0, x), mini(img.get_width(), x + w)):
			img.set_pixel(px, py, c)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for py in range(cy - ry, cy + ry + 1):
		var dy := float(py - cy) / float(ry)
		var span := int(round(float(rx) * sqrt(maxf(0.0, 1.0 - dy * dy))))
		for px in range(cx - span, cx + span + 1):
			_px(img, px, py, c)


static func _ring(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	var steps := maxi(24, int(float(rx + ry) * 3.0))
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		_px(img, cx + int(round(cos(a) * float(rx))), cy + int(round(sin(a) * float(ry))), c)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in range(steps + 1):
		var t := float(i) / float(maxi(1, steps))
		_px(img, int(round(lerpf(float(x0), float(x1), t))), int(round(lerpf(float(y0), float(y1), t))), c)


static func _shadow(img: Image, cx: int, cy: int, rx: int, ry: int) -> void:
	_ellipse(img, cx, cy, rx, ry, Color(0.06, 0.10, 0.06, 0.22))


# --- ground tiles -------------------------------------------------------

static func _speckle(img: Image, ox: int, rng: RandomNumberGenerator, count: int, c: Color) -> void:
	for i in range(count):
		_px(img, ox + rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), c)


static func _tuft(img: Image, ox: int, x: int, y: int, c: Color) -> void:
	_px(img, ox + x, y, c)
	_px(img, ox + x - 1, y - 1, c)
	_px(img, ox + x + 1, y - 1, c)
	_px(img, ox + x - 2, y - 2, c)
	_px(img, ox + x + 2, y - 2, c)


static func _grass_tile(img: Image, index: int, variant: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	var base := GRASS
	if variant == 1:
		base = GRASS.lerp(GRASS_LIGHT, 0.16)
	elif variant == 2:
		base = GRASS.lerp(GRASS_DARK, 0.18)
	_rect(img, ox, 0, TILE, TILE, base)
	_speckle(img, ox, rng, 34, GRASS_DARK if variant != 2 else GRASS)
	_speckle(img, ox, rng, 22, GRASS_LIGHT)
	for i in range(rng.randi_range(2, 4)):
		_tuft(img, ox, rng.randi_range(4, TILE - 5), rng.randi_range(10, TILE - 3), TUFT)


static func _flower_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_rect(img, ox, 0, TILE, TILE, GRASS.lerp(GRASS_LIGHT, 0.1))
	_speckle(img, ox, rng, 30, GRASS_DARK)
	var colors := [FLOWER_PINK, FLOWER_YELLOW, Color(0.92, 0.95, 0.98)]
	for i in range(rng.randi_range(4, 6)):
		var fx := rng.randi_range(3, TILE - 4)
		var fy := rng.randi_range(6, TILE - 4)
		var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
		_px(img, ox + fx, fy, c)
		_px(img, ox + fx - 1, fy, c)
		_px(img, ox + fx + 1, fy, c)
		_px(img, ox + fx, fy - 1, c)
		_px(img, ox + fx, fy + 1, Color(0.85, 0.90, 0.55))
	for i in range(2):
		_tuft(img, ox, rng.randi_range(4, TILE - 5), rng.randi_range(12, TILE - 3), TUFT)


static func _path_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_rect(img, ox, 0, TILE, TILE, DIRT)
	_speckle(img, ox, rng, 42, DIRT_DARK)
	_speckle(img, ox, rng, 30, DIRT_LIGHT)
	for i in range(rng.randi_range(2, 4)):
		var sx := rng.randi_range(4, TILE - 6)
		var sy := rng.randi_range(4, TILE - 6)
		_ellipse(img, ox + sx, sy, 2, 1, STONE)
		_px(img, ox + sx - 1, sy - 1, STONE_LIGHT)


static func _stone_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_rect(img, ox, 0, TILE, TILE, GRASS.lerp(GRASS_DARK, 0.25))
	_speckle(img, ox, rng, 24, DIRT_DARK)
	for i in range(6):
		var sx := rng.randi_range(3, TILE - 5)
		var sy := rng.randi_range(3, TILE - 5)
		_ellipse(img, ox + sx, sy, 3, 2, STONE)
		_px(img, ox + sx, sy - 1, STONE_LIGHT)


## One atlas with 8 tiles; returns a TileSet ready for a TileMapLayer.
static func tileset() -> TileSet:
	if _cache.has("tileset"):
		return _cache["tileset"]
	var img := _img(TILE * 8, TILE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	_grass_tile(img, 0, 0, rng)
	_grass_tile(img, 1, 1, rng)
	_grass_tile(img, 2, 2, rng)
	_flower_tile(img, 3, rng)
	_path_tile(img, 4, rng)
	_path_tile(img, 5, rng)
	_stone_tile(img, 6, rng)
	_grass_tile(img, 7, 1, rng)

	var set := TileSet.new()
	set.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = _tex(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in range(8):
		src.create_tile(Vector2i(i, 0))
	set.add_source(src, 0)
	_cache["tileset"] = set
	return set


# --- world props --------------------------------------------------------

static func tree() -> Texture2D:
	if _cache.has("tree"):
		return _cache["tree"]
	var img := _img(48, 72)
	_shadow(img, 24, 69, 15, 3)
	# trunk
	_rect(img, 21, 30, 6, 38, BARK)
	_rect(img, 21, 30, 1, 38, BARK_DARK)
	_rect(img, 26, 30, 1, 38, BARK_DARK)
	for y in range(33, 66, 7):
		_rect(img, 22, y, 3, 2, HAIR)
		_px(img, 25, y + 2, HAIR)
	# low branch
	_line(img, 22, 38, 16, 33, BARK)
	_line(img, 26, 44, 33, 40, BARK)
	# canopy: dark underside, mid mass, light top
	_ellipse(img, 24, 20, 20, 14, LEAF_DARK)
	_ellipse(img, 14, 22, 11, 9, LEAF)
	_ellipse(img, 34, 23, 11, 9, LEAF)
	_ellipse(img, 24, 15, 14, 10, LEAF)
	_ellipse(img, 18, 13, 8, 6, LEAF_LIGHT)
	_ellipse(img, 30, 17, 7, 5, LEAF_LIGHT)
	_ellipse(img, 24, 11, 6, 4, LEAF_LIGHT.lerp(Color.WHITE, 0.18))
	var t := _tex(img)
	_cache["tree"] = t
	return t


static func rock() -> Texture2D:
	if _cache.has("rock"):
		return _cache["rock"]
	var img := _img(24, 18)
	_shadow(img, 12, 16, 9, 2)
	_ellipse(img, 12, 10, 9, 7, STONE)
	_ellipse(img, 9, 8, 5, 4, STONE_LIGHT)
	_rect(img, 4, 13, 16, 2, STONE_DARK)
	var t := _tex(img)
	_cache["rock"] = t
	return t


static func bush(ripe: bool = true) -> Texture2D:
	var key := "bush_ripe" if ripe else "bush_empty"
	if _cache.has(key):
		return _cache[key]
	var img := _img(32, 32)
	_shadow(img, 16, 30, 11, 2)
	_ellipse(img, 16, 23, 12, 8, LEAF_DARK)
	_ellipse(img, 9, 21, 8, 7, LEAF)
	_ellipse(img, 23, 21, 8, 7, LEAF)
	_ellipse(img, 16, 17, 9, 7, LEAF)
	_ellipse(img, 12, 16, 5, 4, LEAF_LIGHT)
	_ellipse(img, 21, 19, 4, 3, LEAF_LIGHT)
	if ripe:
		for p in [Vector2i(9, 19), Vector2i(14, 22), Vector2i(19, 17), Vector2i(23, 22), Vector2i(16, 25), Vector2i(12, 25)]:
			_ellipse(img, p.x, p.y, 2, 2, BERRY)
			_px(img, p.x - 1, p.y - 1, BERRY_LIGHT)
	var t := _tex(img)
	_cache[key] = t
	return t


static func campfire(frame: int) -> Texture2D:
	var key := "fire_%d" % frame
	if _cache.has(key):
		return _cache[key]
	var img := _img(32, 32)
	_shadow(img, 16, 29, 13, 3)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var sx := 16 + int(round(cos(a) * 12.0))
		var sy := 25 + int(round(sin(a) * 5.0))
		_ellipse(img, sx, sy, 2, 1, STONE if i % 2 == 0 else STONE_DARK)
	_rect(img, 7, 24, 18, 3, LOG_DARK)
	_rect(img, 9, 22, 14, 2, LOG)
	_line(img, 10, 26, 21, 21, LOG)
	_line(img, 21, 26, 10, 21, LOG_DARK)
	var flick := 0.72 + 0.28 * sin(float(frame) * TAU / 3.0)
	var h := int(round(13.0 * flick))
	_ellipse(img, 16, 20 - h / 3, 6, maxi(3, h / 2), FIRE_RED)
	_ellipse(img, 16, 20 - h / 3, 4, maxi(2, h / 2 - 2), FIRE_ORANGE)
	_ellipse(img, 16, 21 - h / 3, 2, maxi(1, h / 3), FIRE_YELLOW)
	for i in range(3):
		var ey := 12 - i * 2 - (0 if (frame + i) % 2 == 0 else 1)
		_px(img, 14 + i * 2, ey, FIRE_YELLOW)
	var t := _tex(img)
	_cache[key] = t
	return t


static func campfire_frames() -> SpriteFrames:
	if _cache.has("fire_frames"):
		return _cache["fire_frames"]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"burn")
	frames.set_animation_speed(&"burn", 7.0)
	frames.set_animation_loop(&"burn", true)
	for i in range(3):
		frames.add_frame(&"burn", campfire(i))
	_cache["fire_frames"] = frames
	return frames


static func sparkle() -> Texture2D:
	if _cache.has("sparkle"):
		return _cache["sparkle"]
	var img := _img(9, 9)
	_rect(img, 4, 0, 1, 9, Color(1, 1, 1, 0.9))
	_rect(img, 0, 4, 9, 1, Color(1, 1, 1, 0.9))
	_ellipse(img, 4, 4, 2, 2, Color(1, 0.95, 0.7, 1))
	_px(img, 4, 4, Color(1, 1, 1, 1))
	var t := _tex(img)
	_cache["sparkle"] = t
	return t


static func ring() -> Texture2D:
	if _cache.has("ring"):
		return _cache["ring"]
	var img := _img(36, 20)
	_ring(img, 18, 10, 16, 8, Color(0.95, 0.42, 0.36, 0.85))
	_ring(img, 18, 10, 14, 7, Color(1.0, 0.70, 0.45, 0.5))
	var t := _tex(img)
	_cache["ring"] = t
	return t


static func berry_icon() -> Texture2D:
	if _cache.has("berry_icon"):
		return _cache["berry_icon"]
	var img := _img(14, 14)
	_ellipse(img, 7, 9, 5, 4, BERRY)
	_ellipse(img, 5, 8, 2, 1, BERRY_LIGHT)
	_line(img, 7, 5, 9, 2, LEAF_DARK)
	_ellipse(img, 9, 3, 2, 1, LEAF)
	var t := _tex(img)
	_cache["berry_icon"] = t
	return t


# --- the chef -----------------------------------------------------------

static func chef(cell: int, frame: int) -> Texture2D:
	var key := "chef_%d_%d" % [cell, frame]
	if _cache.has(key):
		return _cache[key]
	var img := _img(CHEF_W, CHEF_H)
	var steps := [0, -1, 0, 1]
	var lean: int = steps[frame % 4]
	var bob := -1 if frame % 2 == 1 else 0
	var side := cell == 2 or cell == 3
	var back := cell == 1
	var cx := 12
	var head_y := 15 + bob

	_shadow(img, cx, 31, 7, 2)

	# legs and boots
	_rect(img, cx - 5, 27 + bob, 4, 4, PANTS)
	_rect(img, cx + 1, 27 + bob, 4, 4, PANTS)
	_rect(img, cx - 5 + lean, 30, 5, 2, BOOTS)
	_rect(img, cx + 1 - lean, 30, 5, 2, BOOTS)

	# jacket
	_rect(img, cx - 7, 19 + bob, 14, 9, COAT)
	_rect(img, cx + 5, 19 + bob, 2, 9, COAT_DARK)
	_rect(img, cx - 7, 19 + bob, 14, 1, COAT_DARK)
	if not back:
		_rect(img, cx - 2, 22 + bob, 1, 5, COAT_DARK)
		_px(img, cx - 3, 23 + bob, HAT_DARK)
		_px(img, cx - 3, 26 + bob, HAT_DARK)
	else:
		_rect(img, cx - 2, 19 + bob, 3, 9, COAT_DARK)

	# scarf collar
	_rect(img, cx - 7, 18 + bob, 14, 2, SCARF)
	_rect(img, cx - 7, 18 + bob, 14, 1, SCARF.lerp(Color.WHITE, 0.25))
	_px(img, cx + 5, 20 + bob, SCARF)

	# arms
	if side:
		_rect(img, cx + 4, 20 + bob, 3, 7, COAT_DARK)
		_rect(img, cx + 4, 26 + bob, 3, 2, SKIN)
		_rect(img, cx - 6, 20 + bob, 2, 6, COAT)
	else:
		_rect(img, cx - 9, 20 + bob + lean, 3, 7, COAT)
		_rect(img, cx + 6, 20 + bob - lean, 3, 7, COAT)
		_rect(img, cx - 9, 26 + bob + lean, 3, 2, SKIN)
		_rect(img, cx + 6, 26 + bob - lean, 3, 2, SKIN)

	# head
	if side:
		_ellipse(img, cx - 1, head_y, 5, 5, HAIR)
		_ellipse(img, cx + 2, head_y + 1, 4, 4, SKIN)
		_px(img, cx + 4, head_y, EYE)
		_px(img, cx + 4, head_y + 2, SKIN_DARK)
	else:
		_ellipse(img, cx, head_y, 5, 5, HAIR)
		_ellipse(img, cx, head_y + 1, 5, 4, SKIN)
		_rect(img, cx - 5, head_y - 3, 10, 2, HAIR)
		if not back:
			_px(img, cx - 2, head_y, EYE)
			_px(img, cx + 2, head_y, EYE)
			_px(img, cx - 1, head_y + 1, SKIN_DARK)
			_px(img, cx + 1, head_y + 1, SKIN_DARK)

	# toque
	_rect(img, cx - 6, 8 + bob, 12, 2, HAT_DARK)
	_ellipse(img, cx, 5 + bob, 7, 4, HAT)
	_ellipse(img, cx, 4 + bob, 5, 3, HAT.lerp(Color.WHITE, 0.5))
	_rect(img, cx - 7, 7 + bob, 14, 1, HAT_DARK)

	if cell == 3:
		img.flip_x()
	var t := _tex(img)
	_cache[key] = t
	return t


## 4 directions x (idle + 4 frame walk).
static func chef_frames() -> SpriteFrames:
	if _cache.has("chef_frames"):
		return _cache["chef_frames"]
	var dirs := ["down", "up", "right", "left"]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for cell in range(4):
		var idle_name := StringName(dirs[cell] + "_idle")
		var walk_name := StringName(dirs[cell] + "_walk")
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 4.0)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(idle_name, chef(cell, 0))
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, 8.0)
		frames.set_animation_loop(walk_name, true)
		for f in range(4):
			frames.add_frame(walk_name, chef(cell, f))
	_cache["chef_frames"] = frames
	return frames


# --- battlers: the foods themselves -------------------------------------

static func berry_compote() -> Texture2D:
	if _cache.has("berry_compote"):
		return _cache["berry_compote"]
	var img := _img(48, 40)
	_shadow(img, 24, 34, 18, 4)
	_ellipse(img, 24, 25, 17, 10, BOWL)
	_ellipse(img, 24, 23, 17, 8, BOWL_RIM)
	_ellipse(img, 24, 21, 14, 6, Color(0.42, 0.09, 0.17))
	_ellipse(img, 18, 20, 4, 3, BERRY)
	_ellipse(img, 25, 19, 4, 3, BERRY.lerp(Color.WHITE, 0.08))
	_ellipse(img, 31, 21, 3, 2, BERRY)
	_px(img, 17, 19, BERRY_LIGHT)
	_px(img, 24, 18, BERRY_LIGHT)
	_px(img, 30, 20, BERRY_LIGHT)
	# glossy rim highlight
	for x in range(10, 39):
		_px(img, x, 16, BOWL_RIM.lerp(Color.WHITE, 0.4))
	# steam
	_px(img, 20, 12, Color(1, 1, 1, 0.35))
	_px(img, 21, 10, Color(1, 1, 1, 0.28))
	_px(img, 27, 11, Color(1, 1, 1, 0.30))
	_px(img, 28, 9, Color(1, 1, 1, 0.22))
	var t := _tex(img)
	_cache["berry_compote"] = t
	return t


static func blackberry_tart() -> Texture2D:
	if _cache.has("blackberry_tart"):
		return _cache["blackberry_tart"]
	var img := _img(48, 40)
	_shadow(img, 24, 34, 18, 4)
	_ellipse(img, 24, 26, 18, 9, CRUST_DARK)
	_ellipse(img, 24, 25, 17, 8, CRUST)
	_ellipse(img, 24, 24, 14, 6, TART_FILL)
	_ellipse(img, 24, 23, 13, 5, TART_FILL.lerp(TART_BERRY, 0.35))
	# lattice
	_line(img, 13, 22, 35, 26, CRUST.lerp(Color.WHITE, 0.15))
	_line(img, 15, 27, 33, 20, CRUST.lerp(Color.WHITE, 0.15))
	# berries
	for p in [Vector2i(18, 21), Vector2i(23, 20), Vector2i(29, 22), Vector2i(21, 25), Vector2i(27, 25)]:
		_ellipse(img, p.x, p.y, 3, 2, TART_FILL.darkened(0.15))
		_px(img, p.x - 1, p.y - 1, TART_BERRY)
	# fluted crust edge
	for x in range(7, 42, 3):
		_px(img, x, 29, CRUST)
		_px(img, x + 1, 30, CRUST_DARK)
	var t := _tex(img)
	_cache["blackberry_tart"] = t
	return t


static func food_texture(food_id: String) -> Texture2D:
	match food_id:
		"berry_compote":
			return berry_compote()
		"blackberry_tart":
			return blackberry_tart()
	return berry_compote()


static func arena() -> Texture2D:
	if _cache.has("arena"):
		return _cache["arena"]
	var img := _img(240, 60)
	_ellipse(img, 120, 30, 118, 26, Color(0.30, 0.36, 0.24))
	_ellipse(img, 120, 26, 112, 20, Color(0.38, 0.45, 0.29))
	_ellipse(img, 120, 22, 100, 14, Color(0.44, 0.52, 0.33))
	for i in range(26):
		_px(img, 20 + i * 8, 20 + (i % 5), Color(0.50, 0.58, 0.36, 0.7))
	var t := _tex(img)
	_cache["arena"] = t
	return t
