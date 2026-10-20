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


## One atlas with 12 tiles; returns a TileSet ready for a TileMapLayer.
## 0-2 grass, 3 flowers, 4-5 path, 6 clearing, 7 dense grass,
## 8 moss, 9 fallen leaves, 10 grassy path edge, 11 pebbles.
static func tileset() -> TileSet:
	if _cache.has("tileset"):
		return _cache["tileset"]
	var img := _img(TILE * 12, TILE)
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
	_moss_tile(img, 8, rng)
	_leaves_tile(img, 9, rng)
	_edge_tile(img, 10, rng)
	_pebble_tile(img, 11, rng)

	var set := TileSet.new()
	set.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = _tex(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in range(12):
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
		"blueberry_tart":
			return blueberry_tart()
		"roasted_berries":
			return roasted_berries()
		"unknown_berry":
			return unknown_berry()
		"sugar_cube":
			return sugar_cube()
		"orange":
			return orange()
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


# --- extra palette ------------------------------------------------------
const MOSS := Color(0.36, 0.50, 0.24)
const MOSS_LIGHT := Color(0.50, 0.64, 0.33)
const LEAF_FALL := Color(0.68, 0.47, 0.22)
const LEAF_FALL_2 := Color(0.80, 0.60, 0.28)
const SUGAR_WHITE := Color(0.99, 0.98, 0.94)
const ORANGE_FRUIT := Color(0.96, 0.60, 0.16)
const ORANGE_DARK := Color(0.82, 0.44, 0.10)
const BLUEBERRY := Color(0.32, 0.36, 0.64)
const BLUEBERRY_DARK := Color(0.19, 0.22, 0.42)
const MIRA_APRON := Color(0.31, 0.56, 0.44)
const MIRA_APRON_DARK := Color(0.23, 0.43, 0.34)
const MIRA_DRESS := Color(0.95, 0.87, 0.70)
const MIRA_HAIR := Color(0.30, 0.19, 0.15)
const CHARCOAL := Color(0.26, 0.19, 0.15)


# --- extra ground tiles -------------------------------------------------

static func _moss_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_rect(img, ox, 0, TILE, TILE, GRASS.lerp(GRASS_DARK, 0.28))
	_speckle(img, ox, rng, 28, GRASS_DARK)
	_speckle(img, ox, rng, 16, GRASS_LIGHT)
	for i in range(5):
		var cx := rng.randi_range(6, TILE - 6)
		var cy := rng.randi_range(6, TILE - 6)
		_ellipse(img, ox + cx, cy, rng.randi_range(3, 5), rng.randi_range(2, 3), MOSS)
		_px(img, ox + cx - 1, cy - 1, MOSS_LIGHT)
		_px(img, ox + cx + 2, cy, MOSS_LIGHT)


static func _leaves_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_rect(img, ox, 0, TILE, TILE, GRASS.lerp(GRASS_DARK, 0.1))
	_speckle(img, ox, rng, 26, GRASS_DARK)
	for i in range(7):
		var lx := rng.randi_range(4, TILE - 5)
		var ly := rng.randi_range(4, TILE - 5)
		var c: Color = LEAF_FALL if i % 2 == 0 else LEAF_FALL_2
		_ellipse(img, ox + lx, ly, 2, 1, c)
		_px(img, ox + lx - 1, ly - 1, c.lerp(Color.WHITE, 0.2))
		_px(img, ox + lx + 1, ly + 1, c.darkened(0.2))


static func _edge_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_rect(img, ox, 0, TILE, TILE, GRASS)
	_speckle(img, ox, rng, 26, GRASS_DARK)
	_speckle(img, ox, rng, 20, GRASS_LIGHT)
	for i in range(10):
		var px := rng.randi_range(0, TILE - 1)
		var py := TILE - 1 - rng.randi_range(0, 9)
		_px(img, ox + px, py, DIRT)
		if rng.randf() < 0.4:
			_px(img, ox + px, py - 1, DIRT_DARK)
	for i in range(3):
		_tuft(img, ox, rng.randi_range(4, TILE - 5), rng.randi_range(8, TILE - 6), TUFT)


static func _pebble_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_rect(img, ox, 0, TILE, TILE, GRASS.lerp(GRASS_LIGHT, 0.08))
	_speckle(img, ox, rng, 24, GRASS_DARK)
	for i in range(4):
		var sx := rng.randi_range(5, TILE - 7)
		var sy := rng.randi_range(6, TILE - 6)
		_ellipse(img, ox + sx, sy, 3, 2, STONE)
		_px(img, ox + sx, sy - 1, STONE_LIGHT)
		_px(img, ox + sx + 2, sy + 1, STONE_DARK)
	for i in range(2):
		_tuft(img, ox, rng.randi_range(4, TILE - 5), rng.randi_range(12, TILE - 3), TUFT)


# --- richer scenery -----------------------------------------------------

## One of three richly layered trees: roots, moss, a leaning canopy.
static func tree_variant(variant: int) -> Texture2D:
	var key := "tree_v%d" % variant
	if _cache.has(key):
		return _cache[key]
	var img := _img(56, 84)
	var v := variant % 3
	var lean: int = [-2, 1, 3][v]
	_shadow(img, 28, 80, 19, 4)
	# roots
	_line(img, 25, 73, 17, 79, BARK_DARK)
	_line(img, 25, 73, 21, 80, BARK)
	_line(img, 31, 73, 39, 79, BARK_DARK)
	_line(img, 31, 73, 35, 80, BARK)
	# trunk
	_rect(img, 25, 34, 7, 40, BARK)
	_rect(img, 25, 34, 2, 40, BARK_DARK)
	_rect(img, 31, 34, 1, 40, BARK_DARK)
	for y in range(38, 70, 6):
		_rect(img, 27, y, 3, 2, MIRA_HAIR)
		_px(img, 29, y + 2, MIRA_HAIR)
	# branches
	_line(img, 26, 42, 17 + lean, 35, BARK)
	_line(img, 31, 47, 41 - lean, 40, BARK)
	_line(img, 27, 39, 12 + lean, 32, BARK_DARK)
	# moss at the base
	_ellipse(img, 22, 76, 7, 2, MOSS)
	_ellipse(img, 36, 77, 5, 2, MOSS)
	# layered canopy
	var cx := 28 + lean
	_ellipse(img, cx, 24, 22, 15, LEAF_DARK)
	_ellipse(img, cx - 12, 26, 12, 10, LEAF_DARK)
	_ellipse(img, cx + 13, 27, 11, 9, LEAF_DARK)
	_ellipse(img, cx - 10, 23, 11, 9, LEAF)
	_ellipse(img, cx + 11, 24, 10, 8, LEAF)
	_ellipse(img, cx, 19, 15, 11, LEAF)
	_ellipse(img, cx - 6, 16, 9, 7, LEAF_LIGHT)
	_ellipse(img, cx + 8, 20, 8, 6, LEAF_LIGHT)
	_ellipse(img, cx + 1, 13, 7, 5, LEAF_LIGHT.lerp(Color.WHITE, 0.22))
	# individual leaf clumps for texture
	for p in [Vector2i(-16, 20), Vector2i(-7, 12), Vector2i(4, 10), Vector2i(14, 16), Vector2i(19, 26), Vector2i(-18, 29)]:
		_px(img, cx + p.x, p.y, LEAF_LIGHT)
		_px(img, cx + p.x + 1, p.y + 1, LEAF_DARK)
	# a few autumn leaves catching the light
	if v != 1:
		_px(img, cx - 4, 15, LEAF_FALL_2)
		_px(img, cx + 9, 22, LEAF_FALL)
		_px(img, cx - 13, 27, LEAF_FALL)
	var t := _tex(img)
	_cache[key] = t
	return t


static func shadow() -> Texture2D:
	if _cache.has("shadow"):
		return _cache["shadow"]
	var img := _img(44, 18)
	_ellipse(img, 22, 9, 21, 8, Color(0.06, 0.09, 0.06, 0.10))
	_ellipse(img, 22, 9, 15, 6, Color(0.06, 0.09, 0.06, 0.12))
	_ellipse(img, 22, 9, 9, 4, Color(0.06, 0.09, 0.06, 0.14))
	var t := _tex(img)
	_cache["shadow"] = t
	return t


static func glow() -> Texture2D:
	if _cache.has("glow"):
		return _cache["glow"]
	var img := _img(96, 96)
	for y in range(96):
		for x in range(96):
			var dx := (float(x) - 47.5) / 47.5
			var dy := (float(y) - 47.5) / 47.5
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 0.66, 0.32, a * 0.42))
	var t := _tex(img)
	_cache["glow"] = t
	return t


static func smoke() -> Texture2D:
	if _cache.has("smoke"):
		return _cache["smoke"]
	var img := _img(20, 20)
	for y in range(20):
		for x in range(20):
			var dx := (float(x) - 9.5) / 9.5
			var dy := (float(y) - 9.5) / 9.5
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.86, 0.84, 0.80, a * 0.55))
	var t := _tex(img)
	_cache["smoke"] = t
	return t


static func ember() -> Texture2D:
	if _cache.has("ember"):
		return _cache["ember"]
	var img := _img(4, 4)
	_rect(img, 1, 1, 2, 2, FIRE_YELLOW)
	_px(img, 1, 1, Color(1, 1, 1, 1))
	var t := _tex(img)
	_cache["ember"] = t
	return t


static func leaf() -> Texture2D:
	if _cache.has("leaf"):
		return _cache["leaf"]
	var img := _img(7, 5)
	_ellipse(img, 3, 2, 3, 2, LEAF_FALL)
	_px(img, 3, 2, LEAF_FALL.darkened(0.25))
	_px(img, 6, 2, LEAF_FALL_2)
	var t := _tex(img)
	_cache["leaf"] = t
	return t


static func flower_decal(kind: int) -> Texture2D:
	var key := "flower_decal_%d" % kind
	if _cache.has(key):
		return _cache[key]
	var img := _img(14, 12)
	_line(img, 7, 11, 7, 6, LEAF_DARK)
	_line(img, 7, 9, 4, 7, LEAF_DARK)
	_line(img, 7, 9, 10, 7, LEAF_DARK)
	var colors := [FLOWER_PINK, FLOWER_YELLOW, Color(0.90, 0.93, 0.98)]
	var c: Color = colors[kind % 3]
	_ellipse(img, 7, 4, 2, 2, c)
	_px(img, 6, 3, c.lerp(Color.WHITE, 0.45))
	_px(img, 3, 6, c)
	_px(img, 10, 6, c)
	var t := _tex(img)
	_cache[key] = t
	return t


static func grass_decal() -> Texture2D:
	if _cache.has("grass_decal"):
		return _cache["grass_decal"]
	var img := _img(16, 11)
	for p in [Vector2i(3, 10), Vector2i(6, 10), Vector2i(9, 10), Vector2i(12, 10)]:
		_line(img, p.x, p.y, p.x - 1, p.y - 4, TUFT)
		_line(img, p.x, p.y, p.x + 2, p.y - 3, GRASS_LIGHT)
	var t := _tex(img)
	_cache["grass_decal"] = t
	return t


static func moss_decal() -> Texture2D:
	if _cache.has("moss_decal"):
		return _cache["moss_decal"]
	var img := _img(28, 14)
	_ellipse(img, 14, 8, 12, 5, MOSS)
	_ellipse(img, 9, 6, 5, 3, MOSS_LIGHT)
	_ellipse(img, 19, 9, 6, 3, MOSS.darkened(0.12))
	for i in range(7):
		_px(img, 5 + i * 3, 5 + (i % 3), MOSS_LIGHT)
	var t := _tex(img)
	_cache["moss_decal"] = t
	return t


static func leaves_decal() -> Texture2D:
	if _cache.has("leaves_decal"):
		return _cache["leaves_decal"]
	var img := _img(30, 16)
	for p in [Vector2i(6, 9), Vector2i(12, 6), Vector2i(17, 11), Vector2i(23, 7), Vector2i(20, 13)]:
		var c: Color = LEAF_FALL if (p.x + p.y) % 2 == 0 else LEAF_FALL_2
		_ellipse(img, p.x, p.y, 3, 2, c)
		_px(img, p.x - 1, p.y - 1, c.lerp(Color.WHITE, 0.22))
		_px(img, p.x + 2, p.y + 1, c.darkened(0.18))
	var t := _tex(img)
	_cache["leaves_decal"] = t
	return t


static func stones_decal() -> Texture2D:
	if _cache.has("stones_decal"):
		return _cache["stones_decal"]
	var img := _img(20, 12)
	_ellipse(img, 6, 8, 4, 3, STONE)
	_px(img, 5, 6, STONE_LIGHT)
	_ellipse(img, 14, 9, 3, 2, STONE_DARK)
	_px(img, 13, 8, STONE)
	var t := _tex(img)
	_cache["stones_decal"] = t
	return t


# --- Chef Mira ----------------------------------------------------------

## 24x32 villager sprite. pose 0 = normal, pose 1 = raised hand (talking gesture).
static func mira(cell: int, frame: int, pose: int = 0) -> Texture2D:
	var key := "mira_%d_%d_%d" % [cell, frame, pose]
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

	# boots
	_rect(img, cx - 5, 28 + bob, 4, 3, CHARCOAL)
	_rect(img, cx + 1, 28 + bob, 4, 3, CHARCOAL)
	_rect(img, cx - 5 + lean, 30, 5, 1, BOOTS)
	_rect(img, cx + 1 - lean, 30, 5, 1, BOOTS)

	# long dress
	_rect(img, cx - 6, 20 + bob, 12, 9, MIRA_DRESS)
	_rect(img, cx - 7, 27 + bob, 14, 2, MIRA_DRESS.darkened(0.14))
	_rect(img, cx + 5, 20 + bob, 1, 9, MIRA_DRESS.darkened(0.2))

	# apron
	if not back:
		_rect(img, cx - 4, 21 + bob, 8, 7, MIRA_APRON)
		_rect(img, cx - 4, 21 + bob, 8, 1, MIRA_APRON_DARK)
		_rect(img, cx - 1, 22 + bob, 2, 3, MIRA_APRON_DARK)
	# apron straps over the shoulders
	_rect(img, cx - 4, 19 + bob, 2, 2, MIRA_APRON_DARK)
	_rect(img, cx + 2, 19 + bob, 2, 2, MIRA_APRON_DARK)

	# neckerchief
	_rect(img, cx - 5, 18 + bob, 10, 2, MIRA_APRON)

	# arms
	if pose == 1 and not back:
		_rect(img, cx + 5, 15 + bob, 3, 7, MIRA_DRESS)
		_rect(img, cx + 6, 13 + bob, 3, 2, SKIN)
		_rect(img, cx - 8, 21 + bob, 3, 6, MIRA_DRESS)
		_rect(img, cx - 8, 26 + bob, 3, 2, SKIN)
	elif side:
		_rect(img, cx + 4, 21 + bob, 3, 6, MIRA_DRESS)
		_rect(img, cx + 4, 26 + bob, 3, 2, SKIN)
		_rect(img, cx - 6, 21 + bob, 2, 5, MIRA_DRESS.darkened(0.1))
	else:
		_rect(img, cx - 8, 21 + bob + lean, 3, 6, MIRA_DRESS)
		_rect(img, cx + 5, 21 + bob - lean, 3, 6, MIRA_DRESS)
		_rect(img, cx - 8, 26 + bob + lean, 3, 2, SKIN)
		_rect(img, cx + 5, 26 + bob - lean, 3, 2, SKIN)

	# head
	if side:
		_ellipse(img, cx - 1, head_y, 5, 5, MIRA_HAIR)
		_ellipse(img, cx + 2, head_y + 1, 4, 4, SKIN)
		_px(img, cx + 4, head_y, EYE)
		_px(img, cx + 4, head_y + 2, SKIN_DARK)
	else:
		_ellipse(img, cx, head_y, 5, 5, MIRA_HAIR)
		_ellipse(img, cx, head_y + 1, 5, 4, SKIN)
		_rect(img, cx - 5, head_y - 3, 10, 2, MIRA_HAIR)
		if not back:
			_px(img, cx - 2, head_y, EYE)
			_px(img, cx + 2, head_y, EYE)
			_px(img, cx - 1, head_y + 1, SKIN_DARK)
			_px(img, cx + 1, head_y + 1, SKIN_DARK)
			_px(img, cx - 3, head_y + 2, Color(0.94, 0.63, 0.55, 0.7))
			_px(img, cx + 3, head_y + 2, Color(0.94, 0.63, 0.55, 0.7))

	# hair bun at the back
	_ellipse(img, cx - 4, head_y - 3, 3, 3, MIRA_HAIR)
	_px(img, cx - 5, head_y - 4, MIRA_HAIR.lerp(Color.WHITE, 0.2))

	# green headscarf instead of a toque
	_rect(img, cx - 6, 8 + bob, 12, 3, MIRA_APRON)
	_rect(img, cx - 6, 8 + bob, 12, 1, MIRA_APRON.lightened(0.25))
	_ellipse(img, cx, 6 + bob, 6, 3, MIRA_APRON)
	_px(img, cx - 7, 10 + bob, MIRA_APRON_DARK)
	_px(img, cx + 6, 10 + bob, MIRA_APRON_DARK)

	if cell == 3:
		img.flip_x()
	var t := _tex(img)
	_cache[key] = t
	return t


## 4 directions, idle + walk, plus a two frame talking gesture per direction.
static func mira_frames() -> SpriteFrames:
	if _cache.has("mira_frames"):
		return _cache["mira_frames"]
	var dirs := ["down", "up", "right", "left"]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for cell in range(4):
		var idle_name := StringName(dirs[cell] + "_idle")
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 3.0)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(idle_name, mira(cell, 0))
		frames.add_frame(idle_name, mira(cell, 1))

		var walk_name := StringName(dirs[cell] + "_walk")
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, 7.0)
		frames.set_animation_loop(walk_name, true)
		for f in range(4):
			frames.add_frame(walk_name, mira(cell, f))

		var talk_name := StringName(dirs[cell] + "_talk")
		frames.add_animation(talk_name)
		frames.set_animation_speed(talk_name, 4.0)
		frames.set_animation_loop(talk_name, true)
		frames.add_frame(talk_name, mira(cell, 0, 1))
		frames.add_frame(talk_name, mira(cell, 2, 0))
	_cache["mira_frames"] = frames
	return frames


# --- portraits ----------------------------------------------------------

## 48x48 dialogue bust for the player ("chef") or Chef Mira.
static func portrait(kind: String) -> Texture2D:
	var key := "portrait_%s" % kind
	if _cache.has(key):
		return _cache[key]
	var img := _img(48, 48)
	var mira_look := kind == "mira"

	# shoulders
	var coat: Color = MIRA_APRON if mira_look else COAT
	var coat_dark: Color = MIRA_APRON_DARK if mira_look else COAT_DARK
	_rect(img, 6, 37, 36, 11, coat)
	_rect(img, 6, 37, 36, 2, coat_dark)
	_rect(img, 21, 36, 6, 6, SKIN_DARK)

	# head
	_ellipse(img, 24, 24, 13, 13, SKIN)
	_ellipse(img, 24, 27, 12, 9, SKIN)
	_px(img, 17, 25, SKIN_DARK)
	_px(img, 30, 25, SKIN_DARK)

	# hair
	var hair: Color = MIRA_HAIR if mira_look else HAIR
	_ellipse(img, 24, 16, 13, 9, hair)
	_rect(img, 11, 17, 4, 10, hair)
	_rect(img, 33, 17, 4, 10, hair)

	# eyes and smile
	_rect(img, 18, 23, 2, 2, EYE)
	_rect(img, 28, 23, 2, 2, EYE)
	_px(img, 19, 22, Color(1, 1, 1, 0.8))
	_px(img, 29, 22, Color(1, 1, 1, 0.8))
	_rect(img, 22, 29, 5, 1, Color(0.55, 0.28, 0.22))
	_px(img, 21, 28, Color(0.55, 0.28, 0.22))
	_px(img, 27, 28, Color(0.55, 0.28, 0.22))

	if mira_look:
		# headscarf and bun
		_rect(img, 10, 11, 28, 4, MIRA_APRON)
		_rect(img, 10, 11, 28, 1, MIRA_APRON.lightened(0.28))
		_ellipse(img, 24, 8, 15, 5, MIRA_APRON)
		_ellipse(img, 38, 15, 5, 5, MIRA_HAIR)
		# freckles
		for p in [Vector2i(17, 27), Vector2i(31, 27), Vector2i(19, 28), Vector2i(29, 28)]:
			_px(img, p.x, p.y, Color(0.70, 0.45, 0.34))
	else:
		# toque
		_rect(img, 11, 12, 26, 4, HAT_DARK)
		_ellipse(img, 24, 8, 14, 7, HAT)
		_ellipse(img, 24, 6, 10, 5, HAT.lerp(Color.WHITE, 0.5))
		# scarf
		_rect(img, 14, 35, 20, 3, SCARF)

	var t := _tex(img)
	_cache[key] = t
	return t


# --- more dishes --------------------------------------------------------

static func blueberry_tart() -> Texture2D:
	if _cache.has("blueberry_tart"):
		return _cache["blueberry_tart"]
	var img := _img(48, 40)
	_shadow(img, 24, 34, 18, 4)
	# crust
	_ellipse(img, 24, 26, 18, 9, CRUST_DARK)
	_ellipse(img, 24, 25, 17, 8, CRUST)
	# deep blue filling
	_ellipse(img, 24, 24, 14, 6, BLUEBERRY_DARK)
	_ellipse(img, 24, 23, 13, 5, Color(0.26, 0.26, 0.46))
	# blueberries
	for p in [Vector2i(17, 21), Vector2i(22, 20), Vector2i(27, 22), Vector2i(31, 20), Vector2i(24, 24)]:
		_ellipse(img, p.x, p.y, 3, 2, BLUEBERRY)
		_px(img, p.x - 1, p.y - 1, BLUEBERRY.lightened(0.35))
		_px(img, p.x + 1, p.y + 1, BLUEBERRY_DARK)
	# crimped edge
	for x in range(7, 42, 3):
		_px(img, x, 29, CRUST)
		_px(img, x + 1, 30, CRUST_DARK)
		_px(img, x - 1, 28, CRUST.lerp(Color.WHITE, 0.18))
	# icing sugar dusting
	for p in [Vector2i(15, 19), Vector2i(21, 18), Vector2i(28, 19), Vector2i(33, 22), Vector2i(19, 23)]:
		_px(img, p.x, p.y, Color(1, 1, 1, 0.55))
	var t := _tex(img)
	_cache["blueberry_tart"] = t
	return t


static func roasted_berries() -> Texture2D:
	if _cache.has("roasted_berries"):
		return _cache["roasted_berries"]
	var img := _img(40, 34)
	_shadow(img, 20, 29, 14, 3)
	# flat stone serving slab
	_ellipse(img, 20, 24, 15, 7, STONE_DARK)
	_ellipse(img, 20, 23, 14, 6, STONE)
	# blistered berries
	for p in [Vector2i(13, 19), Vector2i(20, 18), Vector2i(26, 20), Vector2i(17, 22), Vector2i(24, 22)]:
		_ellipse(img, p.x, p.y, 3, 3, BERRY.darkened(0.18))
		_px(img, p.x - 1, p.y - 1, BERRY_LIGHT)
		_px(img, p.x, p.y + 2, CHARCOAL)
		_px(img, p.x + 2, p.y - 1, CHARCOAL)
	# char marks and rising heat
	_px(img, 11, 23, CHARCOAL)
	_px(img, 29, 22, CHARCOAL)
	_px(img, 18, 12, Color(1, 1, 1, 0.28))
	_px(img, 19, 10, Color(1, 1, 1, 0.20))
	_px(img, 23, 13, Color(1, 1, 1, 0.24))
	var t := _tex(img)
	_cache["roasted_berries"] = t
	return t


static func unknown_berry() -> Texture2D:
	if _cache.has("unknown_berry"):
		return _cache["unknown_berry"]
	var img := _img(28, 30)
	_shadow(img, 14, 26, 9, 3)
	_ellipse(img, 14, 18, 9, 8, BERRY)
	_ellipse(img, 12, 16, 5, 4, BERRY.lightened(0.12))
	_ellipse(img, 10, 14, 2, 2, BERRY_LIGHT)
	_px(img, 14, 21, Color(0.45, 0.07, 0.14))
	# stalk and leaf
	_line(img, 14, 10, 15, 4, LEAF_DARK)
	_ellipse(img, 18, 5, 3, 2, LEAF)
	_px(img, 17, 4, LEAF_LIGHT)
	var t := _tex(img)
	_cache["unknown_berry"] = t
	return t


static func sugar_cube() -> Texture2D:
	if _cache.has("sugar_cube"):
		return _cache["sugar_cube"]
	var img := _img(26, 26)
	_shadow(img, 13, 23, 8, 2)
	_rect(img, 6, 8, 14, 13, SUGAR_WHITE)
	_rect(img, 6, 8, 14, 2, Color(1, 1, 1, 1))
	_rect(img, 6, 19, 14, 2, SUGAR_WHITE.darkened(0.14))
	_rect(img, 18, 10, 2, 9, SUGAR_WHITE.darkened(0.08))
	# sparkle
	_px(img, 9, 11, Color(1, 1, 1, 0.95))
	_px(img, 8, 12, Color(1, 1, 1, 0.7))
	_px(img, 20, 7, FIRE_YELLOW)
	_px(img, 21, 7, FIRE_YELLOW)
	_px(img, 20, 6, FIRE_YELLOW)
	var t := _tex(img)
	_cache["sugar_cube"] = t
	return t


static func orange() -> Texture2D:
	if _cache.has("orange"):
		return _cache["orange"]
	var img := _img(30, 32)
	_shadow(img, 15, 28, 10, 3)
	_ellipse(img, 15, 18, 10, 10, ORANGE_DARK)
	_ellipse(img, 15, 17, 9, 9, ORANGE_FRUIT)
	_ellipse(img, 12, 14, 4, 3, ORANGE_FRUIT.lightened(0.25))
	# dimples
	for p in [Vector2i(9, 20), Vector2i(17, 21), Vector2i(20, 15), Vector2i(13, 23)]:
		_px(img, p.x, p.y, ORANGE_DARK)
	# leaf
	_line(img, 15, 8, 15, 5, LEAF_DARK)
	_ellipse(img, 19, 5, 4, 2, LEAF)
	_px(img, 20, 4, LEAF_LIGHT)
	var t := _tex(img)
	_cache["orange"] = t
	return t
