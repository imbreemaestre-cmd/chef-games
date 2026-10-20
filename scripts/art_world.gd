class_name ArtWorld
extends RefCounted
## Environment art for Sunberry Hollow.
##
## Terrain tiles, organic dirt trails, layered birch trees, undergrowth and the
## campsite props. Everything is drawn procedurally into images once, cached,
## and then handed out as nearest-neighbour textures. Original artwork only -
## no external sheets, nothing copied from another game.
##
## The trail is deliberately NOT painted as square dirt tiles: it is a run of
## irregular 64x52 dirt patches with chewed alpha silhouettes and a grass
## fringe, so no straight tile edge is ever visible on a path.

const TILE := 32
const TREE_W := 72
const TREE_H := 100

# --- grass family --------------------------------------------------------
const GRASS_DEEP := Color(0.20, 0.35, 0.19)
const GRASS_BASE := Color(0.29, 0.48, 0.24)
const GRASS_WARM := Color(0.35, 0.53, 0.25)
const GRASS_LIGHT := Color(0.41, 0.61, 0.29)
const GRASS_TIP := Color(0.52, 0.72, 0.36)
const GRASS_PALE := Color(0.60, 0.78, 0.42)
const MOSS := Color(0.33, 0.47, 0.21)
const MOSS_LIGHT := Color(0.45, 0.60, 0.28)

# --- soil and stone ------------------------------------------------------
const DIRT := Color(0.55, 0.42, 0.28)
const DIRT_DARK := Color(0.44, 0.33, 0.21)
const DIRT_LIGHT := Color(0.66, 0.53, 0.35)
const DIRT_PALE := Color(0.73, 0.61, 0.42)
const STONE := Color(0.58, 0.57, 0.54)
const STONE_DARK := Color(0.42, 0.41, 0.39)
const STONE_LIGHT := Color(0.72, 0.71, 0.67)

# --- bark and canopy -----------------------------------------------------
const BIRCH := Color(0.90, 0.88, 0.82)
const BIRCH_MARK := Color(0.42, 0.39, 0.35)
const BARK := Color(0.40, 0.28, 0.19)
const BARK_DARK := Color(0.29, 0.20, 0.14)
const LEAF_DEEP := Color(0.17, 0.31, 0.17)
const LEAF_DARK := Color(0.23, 0.40, 0.20)
const LEAF := Color(0.31, 0.51, 0.25)
const LEAF_LIGHT := Color(0.42, 0.62, 0.29)
const LEAF_PALE := Color(0.53, 0.72, 0.35)

# --- small things --------------------------------------------------------
const FLOWER_PINK := Color(0.94, 0.58, 0.70)
const FLOWER_WHITE := Color(0.95, 0.96, 0.92)
const FLOWER_YELLOW := Color(0.98, 0.83, 0.40)
const BERRY := Color(0.64, 0.14, 0.26)
const BERRY_LIGHT := Color(0.90, 0.40, 0.50)
const LEAF_FALL := Color(0.70, 0.47, 0.20)
const LEAF_FALL_2 := Color(0.84, 0.62, 0.26)
const MUSHROOM_CAP := Color(0.86, 0.52, 0.38)
const MUSHROOM_STEM := Color(0.92, 0.88, 0.76)

# --- wood, iron, cloth ---------------------------------------------------
const WOOD := Color(0.52, 0.35, 0.21)
const WOOD_DARK := Color(0.36, 0.24, 0.14)
const WOOD_LIGHT := Color(0.66, 0.47, 0.28)
const IRON := Color(0.31, 0.31, 0.33)
const IRON_LIGHT := Color(0.48, 0.48, 0.50)
const CLOTH := Color(0.80, 0.74, 0.58)
const CLOTH_DARK := Color(0.63, 0.56, 0.41)
const CHAR := Color(0.22, 0.17, 0.14)

static var _cache := {}


# --- drawing helpers -----------------------------------------------------

static func _img(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
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


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		_px(img, x, y, c)
		if x == x1 and y == y1:
			break
		var e2 := err * 2
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


## Layered soft shadow, used under trees, props and characters.
static func _shadow(img: Image, cx: int, cy: int, rx: int, ry: int) -> void:
	_ellipse(img, cx, cy, rx, ry, Color(0.05, 0.09, 0.05, 0.10))
	_ellipse(img, cx, cy, int(rx * 0.72), int(ry * 0.72), Color(0.05, 0.09, 0.05, 0.12))
	_ellipse(img, cx, cy, int(rx * 0.42), int(ry * 0.42), Color(0.05, 0.09, 0.05, 0.14))


static func _blades(img: Image, ox: int, rng: RandomNumberGenerator, count: int, base_y: int, color: Color, max_len: int = 4) -> void:
	for i in range(count):
		var x := ox + rng.randi_range(1, TILE - 2)
		var y := base_y + rng.randi_range(-3, 2)
		var h := rng.randi_range(2, maxi(2, max_len))
		var lean := 0
		if rng.randf() < 0.45:
			lean = 1 if rng.randf() < 0.5 else -1
		for k in range(h):
			var bend := 0
			if k > h / 2:
				bend = lean
			_px(img, x + bend, y - k, color)


# --- ground tiles --------------------------------------------------------

static func _grass_tile(img: Image, index: int, rng: RandomNumberGenerator, base: Color, dark: Color, light: Color, detail: int) -> void:
	var ox := index * TILE
	_rect(img, ox, 0, TILE, TILE, base)
	# broad tonal blotches so a run of tiles never reads as one flat colour
	for i in range(3):
		_ellipse(img, ox + rng.randi_range(5, 26), rng.randi_range(5, 26),
			rng.randi_range(4, 8), rng.randi_range(3, 6), dark)
	for i in range(3):
		_ellipse(img, ox + rng.randi_range(5, 26), rng.randi_range(5, 26),
			rng.randi_range(3, 6), rng.randi_range(2, 5), light)
	# fine speckle for grain
	for i in range(28):
		_px(img, ox + rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), dark)
	for i in range(20):
		_px(img, ox + rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), light)
	# individual blades
	_blades(img, ox, rng, detail * 5, 28, GRASS_TIP, 4)
	_blades(img, ox, rng, detail * 2, 18, GRASS_PALE, 3)


static func _flowers_tile(img: Image, index: int, rng: RandomNumberGenerator, colors: Array) -> void:
	var ox := index * TILE
	_grass_tile(img, index, rng, GRASS_BASE.lerp(GRASS_LIGHT, 0.12), GRASS_BASE, GRASS_LIGHT, 2)
	for i in range(rng.randi_range(4, 6)):
		var fx := ox + rng.randi_range(4, TILE - 5)
		var fy := rng.randi_range(7, TILE - 6)
		var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
		_px(img, fx, fy + 1, LEAF_DARK)
		_px(img, fx, fy + 2, LEAF_DARK)
		_px(img, fx, fy, c)
		_px(img, fx - 1, fy, c)
		_px(img, fx + 1, fy, c)
		_px(img, fx, fy - 1, c)
		_px(img, fx, fy, c.lerp(Color.WHITE, 0.35))


static func _fern_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_grass_tile(img, index, rng, GRASS_DEEP.lerp(GRASS_BASE, 0.5), GRASS_DEEP, GRASS_BASE, 1)
	for i in range(3):
		var cx := ox + rng.randi_range(8, 24)
		var cy := rng.randi_range(16, 24)
		var reach := rng.randi_range(5, 8)
		for k in range(reach):
			var lift := k / 2
			_px(img, cx - k, cy - lift, LEAF_DARK)
			_px(img, cx + k, cy - lift, LEAF_DARK)
			if k % 2 == 0:
				_px(img, cx - k, cy - lift - 1, LEAF)
				_px(img, cx + k, cy - lift - 1, LEAF)
		_px(img, cx, cy - reach / 2, LEAF_LIGHT)


static func _litter_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_grass_tile(img, index, rng, GRASS_BASE.lerp(GRASS_WARM, 0.4), GRASS_DEEP, GRASS_LIGHT, 1)
	for i in range(rng.randi_range(4, 7)):
		var lx := ox + rng.randi_range(3, TILE - 4)
		var ly := rng.randi_range(4, TILE - 4)
		var c: Color = LEAF_FALL if rng.randf() < 0.55 else LEAF_FALL_2
		_ellipse(img, lx, ly, 3, 2, c)
		_px(img, lx - 1, ly - 1, c.lerp(Color.WHITE, 0.25))
		_px(img, lx + 2, ly + 1, c.darkened(0.22))


static func _pebble_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_grass_tile(img, index, rng, GRASS_BASE.lerp(GRASS_DEEP, 0.25), GRASS_DEEP, GRASS_LIGHT, 1)
	for i in range(rng.randi_range(4, 7)):
		var sx := ox + rng.randi_range(4, TILE - 5)
		var sy := rng.randi_range(5, TILE - 5)
		_ellipse(img, sx, sy, rng.randi_range(2, 3), rng.randi_range(1, 2), STONE)
		_px(img, sx - 1, sy - 1, STONE_LIGHT)
		_px(img, sx + 1, sy + 1, STONE_DARK)


static func _mushroom_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_grass_tile(img, index, rng, GRASS_DEEP.lerp(GRASS_BASE, 0.45), GRASS_DEEP, GRASS_BASE, 2)
	for i in range(rng.randi_range(2, 4)):
		var mx := ox + rng.randi_range(6, TILE - 7)
		var my := rng.randi_range(18, 27)
		_rect(img, mx, my, 2, 3, MUSHROOM_STEM)
		_ellipse(img, mx, my - 1, 3, 2, MUSHROOM_CAP)
		_px(img, mx - 1, my - 2, MUSHROOM_CAP.lerp(Color.WHITE, 0.4))
		_px(img, mx, my + 3, Color(0.15, 0.12, 0.10, 0.35))


static func _worn_tile(img: Image, index: int, rng: RandomNumberGenerator) -> void:
	var ox := index * TILE
	_grass_tile(img, index, rng, GRASS_BASE, GRASS_DEEP, GRASS_LIGHT, 1)
	for i in range(22):
		var x := ox + rng.randi_range(3, TILE - 4)
		var y := rng.randi_range(6, TILE - 4)
		_ellipse(img, x, y, 2, 1, DIRT.darkened(0.05))
	for i in range(8):
		_px(img, ox + rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), DIRT_LIGHT)


## 13 tiles in one row: 0-5 grass tones, 6-7 wildflowers, 8 ferns, 9 leaf
## litter, 10 pebbles, 11 mushrooms, 12 worn grass under the trail.
static func tileset() -> TileSet:
	if _cache.has("tileset"):
		return _cache["tileset"]
	var img := _img(TILE * 13, TILE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	_grass_tile(img, 0, rng, GRASS_BASE, GRASS_DEEP, GRASS_LIGHT, 3)
	_grass_tile(img, 1, rng, GRASS_WARM, GRASS_BASE, GRASS_TIP, 3)
	_grass_tile(img, 2, rng, GRASS_DEEP.lerp(GRASS_BASE, 0.4), GRASS_DEEP, GRASS_BASE, 2)
	_grass_tile(img, 3, rng, Color(0.17, 0.29, 0.17), Color(0.13, 0.23, 0.14), Color(0.24, 0.38, 0.20), 1)
	_grass_tile(img, 4, rng, GRASS_WARM.lerp(GRASS_LIGHT, 0.35), GRASS_BASE, GRASS_PALE, 3)
	_grass_tile(img, 5, rng, MOSS, MOSS.darkened(0.18), MOSS_LIGHT, 2)
	_flowers_tile(img, 6, rng, [FLOWER_PINK, FLOWER_WHITE])
	_flowers_tile(img, 7, rng, [FLOWER_YELLOW, FLOWER_WHITE])
	_fern_tile(img, 8, rng)
	_litter_tile(img, 9, rng)
	_pebble_tile(img, 10, rng)
	_mushroom_tile(img, 11, rng)
	_worn_tile(img, 12, rng)

	var set := TileSet.new()
	set.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = _tex(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in range(13):
		src.create_tile(Vector2i(i, 0))
	set.add_source(src, 0)
	_cache["tileset"] = set
	return set


# --- organic trail -------------------------------------------------------

## An irregular patch of trodden dirt with a chewed edge and a grass fringe.
## Place these along a path at 32px spacing and they merge into one trail.
static func dirt_patch(variant: int) -> Texture2D:
	var key := "dirt_patch_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var img := _img(64, 52)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5100 + variant * 37
	var cx := 32
	var cy := 26

	# body: a union of jittered ellipses rather than one clean oval
	for i in range(30):
		var a := TAU * float(i) / 30.0
		var jitter := rng.randf_range(0.70, 1.0)
		var ex := cx + int(round(cos(a) * 26.0 * jitter))
		var ey := cy + int(round(sin(a) * 16.0 * jitter))
		_ellipse(img, ex, ey, rng.randi_range(7, 11), rng.randi_range(5, 8), DIRT)
	_ellipse(img, cx, cy, 24, 14, DIRT)
	# worn, paler middle where feet fall
	_ellipse(img, cx + rng.randi_range(-3, 3), cy - 2, 17, 9, DIRT_LIGHT)
	for i in range(70):
		var x := rng.randi_range(9, 54)
		var y := rng.randi_range(11, 41)
		_px(img, x, y, DIRT_DARK if rng.randf() < 0.5 else DIRT_PALE)
	# pebbles pressed into the soil
	for i in range(rng.randi_range(3, 6)):
		var sx := rng.randi_range(14, 48)
		var sy := rng.randi_range(16, 36)
		_ellipse(img, sx, sy, rng.randi_range(2, 3), rng.randi_range(1, 2), STONE)
		_px(img, sx - 1, sy - 1, STONE_LIGHT)
	# boot prints down the middle
	for i in range(2):
		var bx := cx - 6 + i * 12
		var by := cy + rng.randi_range(-2, 2)
		_ellipse(img, bx, by, 2, 3, DIRT_DARK)
	# chew the silhouette so no tile edge shows
	for i in range(520):
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.92, 1.06)
		var px := cx + int(round(cos(ang) * 30.0 * rad))
		var py := cy + int(round(sin(ang) * 19.0 * rad))
		_px(img, px, py, Color(0, 0, 0, 0))
	# grass reclaiming the rim
	for i in range(26):
		var ang2 := rng.randf() * TAU
		var bx2 := cx + int(round(cos(ang2) * rng.randf_range(24.0, 30.0)))
		var by2 := cy + int(round(sin(ang2) * rng.randf_range(13.0, 19.0)))
		var h := rng.randi_range(2, 4)
		for k in range(h):
			_px(img, bx2, by2 - k, GRASS_TIP if k < h - 1 else GRASS_PALE)

	var t := _tex(img)
	_cache[key] = t
	return t


# --- trees and undergrowth ----------------------------------------------

## Five birch variants, 72x100, trunk base at (36, 96).
static func tree(variant: int) -> Texture2D:
	var v := variant % 5
	var key := "tree_%d" % v
	if _cache.has(key):
		return _cache[key]
	var img := _img(TREE_W, TREE_H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3300 + v * 91
	var cx := 36
	var base := 96
	var lean: int = [-2, 1, 3, 0, -1][v]
	var trunk_w: int = [6, 5, 7, 5, 6][v]

	_shadow(img, cx, base, 20, 5)

	# roots splaying into the grass
	_line(img, cx - 2, base - 8, cx - 9, base - 1, BARK_DARK)
	_line(img, cx + 2, base - 8, cx + 10, base - 2, BARK_DARK)
	_line(img, cx - 1, base - 6, cx - 5, base, BARK)
	_line(img, cx + 1, base - 6, cx + 6, base - 1, BARK)

	# trunk: birch white with dark lenticels
	var tx: int = cx - trunk_w / 2 + lean
	_rect(img, tx, base - 58, trunk_w, 58, BIRCH)
	_rect(img, tx, base - 58, 1, 58, BIRCH.lerp(Color.BLACK, 0.18))
	_rect(img, tx + trunk_w - 1, base - 58, 1, 58, BIRCH.lerp(Color.BLACK, 0.24))
	for i in range(9):
		var my := base - 56 + i * 6 + rng.randi_range(0, 2)
		var mw := rng.randi_range(1, maxi(1, trunk_w - 2))
		_rect(img, tx + rng.randi_range(1, maxi(1, trunk_w - 1 - mw)), my, mw, 1, BIRCH_MARK)
	# bark shadow where the canopy blocks light
	_rect(img, tx, base - 34, trunk_w, 2, BIRCH.lerp(BARK, 0.25))

	# branches reaching into the canopy
	_line(img, cx, base - 48, cx - 15 + lean, base - 62, BIRCH)
	_line(img, cx, base - 40, cx + 16 - lean, base - 58, BIRCH)
	_line(img, cx - 15 + lean, base - 62, cx - 21, base - 68, BIRCH_MARK)
	_line(img, cx + 16 - lean, base - 58, cx + 24, base - 66, BIRCH_MARK)

	# canopy: dark underside, then mid mass, then sunlit crown
	var cy := 30 - v % 2 * 2
	_ellipse(img, cx + lean, cy + 10, 26, 16, LEAF_DEEP)
	_ellipse(img, cx - 16 + lean, cy + 12, 14, 11, LEAF_DEEP)
	_ellipse(img, cx + 17 + lean, cy + 13, 13, 10, LEAF_DEEP)

	_ellipse(img, cx - 13 + lean, cy + 6, 15, 12, LEAF_DARK)
	_ellipse(img, cx + 14 + lean, cy + 7, 14, 11, LEAF_DARK)
	_ellipse(img, cx + lean, cy + 2, 20, 14, LEAF_DARK)

	_ellipse(img, cx - 10 + lean, cy - 1, 12, 9, LEAF)
	_ellipse(img, cx + 11 + lean, cy + 1, 11, 8, LEAF)
	_ellipse(img, cx + lean, cy - 5, 15, 10, LEAF)

	_ellipse(img, cx - 6 + lean, cy - 8, 8, 6, LEAF_LIGHT)
	_ellipse(img, cx + 8 + lean, cy - 5, 7, 5, LEAF_LIGHT)
	_ellipse(img, cx + lean, cy - 12, 9, 6, LEAF_LIGHT)

	# clumps of individual leaves on top for texture
	for i in range(22):
		var lx: int = cx + rng.randi_range(-22, 22) + lean
		var ly := cy + rng.randi_range(-14, 12)
		var c: Color = LEAF_PALE if rng.randf() < 0.45 else LEAF_LIGHT
		_px(img, lx, ly, c)
		if rng.randf() < 0.4:
			_px(img, lx + 1, ly, c.darkened(0.12))
	# a few turning leaves
	for i in range(4):
		_px(img, cx + rng.randi_range(-18, 18) + lean, cy + rng.randi_range(-8, 8), LEAF_FALL_2)

	var t := _tex(img)
	_cache[key] = t
	return t


## A stump for the clearing edge.
static func stump() -> Texture2D:
	if _cache.has("stump"):
		return _cache["stump"]
	var img := _img(34, 30)
	_shadow(img, 17, 27, 12, 3)
	_rect(img, 8, 14, 18, 12, BARK_DARK)
	_rect(img, 9, 14, 3, 12, BARK)
	_ellipse(img, 17, 13, 9, 4, BIRCH)
	_ellipse(img, 17, 13, 6, 3, BIRCH.lerp(BARK, 0.18))
	_ellipse(img, 17, 13, 3, 1, BIRCH.lerp(BARK, 0.35))
	_ellipse(img, 12, 26, 5, 2, MOSS)
	_px(img, 14, 24, MOSS_LIGHT)
	var t := _tex(img)
	_cache["stump"] = t
	return t


## Small undergrowth clump: ferns, sorrel, low shrubs.
## variant 0 fern, 1 leafy shrub, 2 tall grass tuft.
static func undergrowth(variant: int) -> Texture2D:
	var v := variant % 3
	var key := "undergrowth_%d" % v
	if _cache.has(key):
		return _cache[key]
	var img := _img(30, 24)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8800 + v * 53
	_shadow(img, 15, 21, 11, 3)
	if v == 0:
		for i in range(4):
			var cx := 7 + i * 5 + rng.randi_range(-1, 1)
			var reach := rng.randi_range(5, 8)
			for k in range(reach):
				_px(img, cx - k, 19 - k / 2, LEAF_DARK)
				_px(img, cx + k, 19 - k / 2, LEAF_DARK)
				if k % 2 == 0:
					_px(img, cx - k, 18 - k / 2, LEAF)
					_px(img, cx + k, 18 - k / 2, LEAF)
	elif v == 1:
		_ellipse(img, 15, 15, 11, 8, LEAF_DARK)
		_ellipse(img, 9, 13, 7, 6, LEAF)
		_ellipse(img, 21, 14, 7, 6, LEAF)
		_ellipse(img, 15, 11, 8, 6, LEAF_LIGHT)
		for i in range(6):
			_px(img, rng.randi_range(6, 24), rng.randi_range(8, 18), LEAF_PALE)
	else:
		for i in range(9):
			var gx := rng.randi_range(3, 26)
			var gh := rng.randi_range(6, 12)
			for k in range(gh):
				_px(img, gx + (k / 6), 20 - k, GRASS_TIP if k < gh - 1 else GRASS_PALE)
	var t := _tex(img)
	_cache[key] = t
	return t


# --- campsite props ------------------------------------------------------

## A split log laid on its side for sitting.
static func log_seat() -> Texture2D:
	if _cache.has("log_seat"):
		return _cache["log_seat"]
	var img := _img(46, 24)
	_shadow(img, 23, 21, 18, 3)
	_rect(img, 5, 9, 36, 10, WOOD)
	_rect(img, 5, 9, 36, 2, WOOD_LIGHT)
	_rect(img, 5, 17, 36, 2, WOOD_DARK)
	_ellipse(img, 6, 14, 4, 5, WOOD_LIGHT)
	_ellipse(img, 6, 14, 2, 3, WOOD_DARK)
	_ellipse(img, 40, 14, 4, 5, WOOD_LIGHT)
	_ellipse(img, 40, 14, 2, 3, WOOD_DARK)
	# grain
	for i in range(7):
		_line(img, 10 + i * 4, 12, 13 + i * 4, 12, WOOD_DARK)
	_ellipse(img, 30, 9, 4, 1, MOSS)
	var t := _tex(img)
	_cache["log_seat"] = t
	return t


## Iron pot hanging from a tripod over the fire.
static func camp_pot() -> Texture2D:
	if _cache.has("camp_pot"):
		return _cache["camp_pot"]
	var img := _img(30, 34)
	_shadow(img, 15, 31, 11, 3)
	# tripod
	_line(img, 3, 32, 15, 4, WOOD_DARK)
	_line(img, 27, 32, 15, 4, WOOD_DARK)
	_line(img, 15, 4, 15, 10, WOOD)
	# pot
	_ellipse(img, 15, 20, 9, 8, IRON)
	_ellipse(img, 15, 19, 9, 3, IRON_LIGHT)
	_rect(img, 6, 18, 18, 2, IRON_LIGHT)
	_ellipse(img, 15, 19, 7, 5, CHAR)
	_px(img, 12, 17, Color(0.95, 0.85, 0.55))
	_px(img, 18, 18, Color(0.95, 0.85, 0.55))
	_line(img, 15, 10, 15, 13, IRON)
	var t := _tex(img)
	_cache["camp_pot"] = t
	return t


## Small folding work table with a board and two bowls.
static func camp_table() -> Texture2D:
	if _cache.has("camp_table"):
		return _cache["camp_table"]
	var img := _img(48, 34)
	_shadow(img, 24, 31, 18, 3)
	_line(img, 8, 18, 6, 32, WOOD_DARK)
	_line(img, 40, 18, 42, 32, WOOD_DARK)
	_line(img, 24, 18, 24, 32, WOOD_DARK)
	_rect(img, 4, 13, 40, 6, WOOD)
	_rect(img, 4, 13, 40, 2, WOOD_LIGHT)
	_rect(img, 4, 18, 40, 1, WOOD_DARK)
	# chopping board
	_rect(img, 8, 10, 16, 3, WOOD_LIGHT)
	_px(img, 10, 10, WOOD_DARK)
	_px(img, 20, 10, WOOD_DARK)
	# two bowls
	_ellipse(img, 31, 11, 5, 3, CLOTH)
	_ellipse(img, 31, 10, 4, 2, CLOTH_DARK)
	_ellipse(img, 41, 12, 3, 2, CLOTH)
	# a knife
	_line(img, 30, 9, 38, 7, IRON_LIGHT)
	_line(img, 38, 7, 40, 8, WOOD_DARK)
	var t := _tex(img)
	_cache["camp_table"] = t
	return t


## Supply crate.
static func crate() -> Texture2D:
	if _cache.has("crate"):
		return _cache["crate"]
	var img := _img(30, 28)
	_shadow(img, 15, 25, 12, 3)
	_rect(img, 5, 8, 20, 17, WOOD)
	_rect(img, 5, 8, 20, 2, WOOD_LIGHT)
	_rect(img, 5, 8, 2, 17, WOOD_LIGHT)
	_rect(img, 5, 23, 20, 2, WOOD_DARK)
	_line(img, 7, 10, 23, 22, WOOD_DARK)
	_line(img, 23, 10, 7, 22, WOOD_DARK)
	for i in range(4):
		_px(img, 9 + i * 4, 9, WOOD_LIGHT)
	var t := _tex(img)
	_cache["crate"] = t
	return t


## Wicker basket of foraged berries.
static func basket() -> Texture2D:
	if _cache.has("basket"):
		return _cache["basket"]
	var img := _img(28, 24)
	_shadow(img, 14, 21, 11, 3)
	_ellipse(img, 14, 16, 10, 6, WOOD_LIGHT)
	_rect(img, 4, 12, 20, 5, WOOD)
	_rect(img, 4, 12, 20, 2, WOOD_LIGHT)
	for i in range(5):
		_px(img, 6 + i * 4, 14, WOOD_DARK)
		_px(img, 8 + i * 4, 16, WOOD_DARK)
	# berries spilling out of the top
	for p in [Vector2i(9, 10), Vector2i(13, 9), Vector2i(17, 10), Vector2i(11, 12), Vector2i(19, 12)]:
		_ellipse(img, p.x, p.y, 2, 2, BERRY)
		_px(img, p.x - 1, p.y - 1, BERRY_LIGHT)
	_ellipse(img, 14, 18, 8, 3, WOOD_DARK)
	var t := _tex(img)
	_cache["basket"] = t
	return t


## Rolled travel blanket, the mark of a chef who sleeps outdoors.
static func bedroll() -> Texture2D:
	if _cache.has("bedroll"):
		return _cache["bedroll"]
	var img := _img(40, 22)
	_shadow(img, 20, 19, 16, 3)
	_ellipse(img, 20, 13, 16, 6, CLOTH)
	_ellipse(img, 20, 12, 16, 5, CLOTH.lightened(0.08))
	_ellipse(img, 8, 13, 5, 5, CLOTH_DARK)
	_ellipse(img, 8, 13, 3, 3, CLOTH)
	_ellipse(img, 32, 13, 5, 5, CLOTH_DARK)
	_rect(img, 16, 10, 8, 2, CLOTH_DARK)
	_px(img, 18, 10, Color(0.86, 0.70, 0.36))
	var t := _tex(img)
	_cache["bedroll"] = t
	return t
