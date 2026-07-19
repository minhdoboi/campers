# Generates the placeholder pixel-art assets (tile atlas + sprites).
# Run with:
#   godot4 --headless --path . --script res://tools/gen_assets.gd
extends SceneTree

const TILE_W := 64
const TILE_H := 32

var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 20260719
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/tiles"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites"))
	_make_tiles()
	_make_ramps()
	_make_tree()
	_make_deciduous_trees()
	_make_camper()
	_make_portraits()
	_make_deer()
	_make_beaver()
	_make_bird()
	_make_log()
	_make_rock()
	_make_barrier()
	print("Assets generated.")
	quit()


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])


# --- Tile atlas: one row of 64x48 isometric block tiles ------------------
# Top 32px is the diamond, bottom 16px is a cliff "skirt" shown when the
# tile sits above a lower elevation level.
# 0 deep water, 1 water, 2 sand, 3 grass, 4 forest floor, 5 rock,
# 6 road along grid X, 7 road along grid Y
# (ramps live in a separate ramps.png, drawn as sprites over a grass base)

const TILE_TEX_H := 48
const SKIRT_H := 16
const TILE_ROAD_X_INDEX := 6
const TILE_ROAD_Y_INDEX := 7

func _make_tiles() -> void:
	var bases: Array[Color] = [
		Color("1d5c7a"), # deep water
		Color("3f8daa"), # shallow water
		Color("d9c38a"), # sand
		Color("7fb069"), # grass
		Color("4e7e44"), # forest floor
		Color("8d8d85"), # rock
		Color("4a4a4e"), # asphalt road along +x
		Color("4a4a4e"), # asphalt road along +y
	]
	var img := Image.create(TILE_W * bases.size(), TILE_TEX_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in bases.size():
		_draw_diamond(img, i * TILE_W, bases[i], i)
		if i >= 2: # land tiles get a cliff skirt; water is always level 0
			_draw_skirt(img, i * TILE_W)
	_save(img, "res://assets/tiles/tiles.png")


func _draw_diamond(img: Image, ox: int, base: Color, tile_index: int) -> void:
	var cx := TILE_W / 2.0
	var cy := TILE_H / 2.0
	for y in TILE_H:
		var dy: float = absf((y + 0.5) - cy) / cy
		var half_w: float = (1.0 - dy) * cx
		var x_start := int(ceil(cx - half_w))
		var x_end := int(floor(cx + half_w))
		for x in range(x_start, x_end):
			var c := base
			# Subtle vertical light: top of the diamond slightly brighter.
			c = c.lightened((1.0 - float(y) / TILE_H) * 0.08)
			# Speckle noise for texture.
			var r := rng.randf()
			if r < 0.10:
				c = c.darkened(0.07)
			elif r < 0.20:
				c = c.lightened(0.07)
			# Gentle wave stripes on the water tiles.
			if tile_index <= 1 and (y + tile_index * 2) % 6 == 0 and rng.randf() < 0.6:
				c = c.lightened(0.10)
			# Asphalt: dashed line follows the isometric travel axis.
			if tile_index == TILE_ROAD_X_INDEX or tile_index == TILE_ROAD_Y_INDEX:
				c = _road_pixel(c, float(x) - cx, float(y) - cy, tile_index == TILE_ROAD_X_INDEX, r)
			# Darken the diamond rim so tiles read individually.
			var on_edge: bool = x <= x_start or x >= x_end - 1 or y == 0 or y == TILE_H - 1
			if on_edge:
				c = c.darkened(0.18)
			img.set_pixel(ox + x, y, c)


## Road markings in diamond space. Grid +x travels along the SE iso diagonal
## (dx ≈ 2·dy); grid +y along the SW diagonal (dx ≈ -2·dy).
func _road_pixel(base: Color, dx: float, dy: float, along_x: bool, noise: float) -> Color:
	var across: float
	var along: float
	if along_x:
		across = absf(dx - 2.0 * dy)
		along = dx + 2.0 * dy
	else:
		across = absf(dx + 2.0 * dy)
		along = -dx + 2.0 * dy
	var c := base
	if across < 1.8 and posmod(int(along + 40.0), 10) < 5:
		c = Color("e8d66a") # dashed yellow center line
	elif across > 14.0:
		c = c.lightened(0.14) # pale shoulder edge
	elif noise < 0.08:
		c = c.darkened(0.12)
	return c


func _draw_skirt(img: Image, ox: int) -> void:
	var dirt := Color("7a5c3d")
	var cx := TILE_W / 2.0
	for x in TILE_W:
		var dx: float = absf((x + 0.5) - cx) / cx
		var y_edge := int(TILE_H - (TILE_H / 2.0) * dx)
		for y in range(y_edge, y_edge + SKIRT_H):
			if y >= TILE_TEX_H:
				break
			var c := dirt
			# Two faces: light from the left.
			if x < cx:
				c = c.lightened(0.10)
			else:
				c = c.darkened(0.06)
			# Darken toward the bottom of the cliff.
			c = c.darkened(float(y - y_edge) / SKIRT_H * 0.28)
			if rng.randf() < 0.12:
				c = c.darkened(0.10)
			img.set_pixel(ox + x, y, c)


# --- Ramp sprites: 4 directional slopes, 64x64 each ----------------------
# Frame order matches TerrainGenerator.RAMP_DIRS:
# 0 rises toward +x, 1 toward -x, 2 toward -y, 3 toward +y.
# Each frame has a 16px headroom so raised edges fit; the flat diamond sits
# at rows 16..48, so the texture center coincides with the cell center.

const RAMP_TEX := 64
const RAMP_PAD := 16

func _make_ramps() -> void:
	var img := Image.create(RAMP_TEX * 4, RAMP_TEX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for d in 4:
		_draw_ramp(img, d * RAMP_TEX, d)
	_save(img, "res://assets/tiles/ramps.png")


func _draw_ramp(img: Image, ox: int, dir_index: int) -> void:
	var base := Color("b8a878")
	var col_bottom := PackedInt32Array()
	col_bottom.resize(RAMP_TEX)
	col_bottom.fill(-1)
	# Sample the tilted plane over the cell in grid coordinates (u, v).
	# Screen x = 32 + 32(u - v); screen y = pad + 16u + 16v - 16 * lift(u, v),
	# where lift goes from 0 on the downhill edge to 1 on the uphill edge.
	var steps := 160
	for ui in steps + 1:
		var u := float(ui) / steps
		for vi in steps + 1:
			var v := float(vi) / steps
			var w: float # uphill coordinate, 1.0 at the raised edge
			var sy: float
			match dir_index:
				0: # up toward +x
					w = u
					sy = RAMP_PAD + 16.0 * v
				1: # up toward -x
					w = 1.0 - u
					sy = RAMP_PAD - 16.0 + 32.0 * u + 16.0 * v
				2: # up toward -y
					w = 1.0 - v
					sy = RAMP_PAD - 16.0 + 16.0 * u + 32.0 * v
				_: # up toward +y
					w = v
					sy = RAMP_PAD + 16.0 * u
			var sx := 32.0 + 32.0 * (u - v)
			var x := int(sx)
			var y := int(sy)
			if x < 0 or x >= RAMP_TEX or y < 0 or y >= RAMP_TEX:
				continue
			var c := base.lightened(w * 0.10)
			# Step bands across the slope so it reads as stairs.
			if int(w * 7.0) % 2 == 0:
				c = c.lightened(0.08)
			else:
				c = c.darkened(0.07)
			if u < 0.04 or v < 0.04 or u > 0.96 or v > 0.96:
				c = c.darkened(0.15)
			img.set_pixel(ox + x, y, c)
			col_bottom[x] = maxi(col_bottom[x], y)
	# Fill the side face between the slope and the flat diamond outline.
	# Ramps rising toward +x / +y abut the upper tile on one screen half —
	# the higher neighbor's diamond occupies that area, so filling it would
	# paint dirt over the upper level. Only fill the free-standing half.
	var fill_from := 0
	var fill_to := RAMP_TEX
	match dir_index:
		0: # up toward +x: raised edge abuts the upper tile on the right
			fill_to = 32
		3: # up toward +y: raised edge abuts the upper tile on the left
			fill_from = 32
	var dirt := Color("7a5c3d")
	for x in range(fill_from, fill_to):
		if col_bottom[x] < 0:
			continue
		var dx: float = absf((x + 0.5) - 32.0) / 32.0
		var y_edge := int(RAMP_PAD + 32.0 - 16.0 * dx)
		for y in range(col_bottom[x] + 1, y_edge + 1):
			if y >= RAMP_TEX:
				break
			var c := dirt.lightened(0.10) if x < 32 else dirt.darkened(0.06)
			if rng.randf() < 0.12:
				c = c.darkened(0.10)
			img.set_pixel(ox + x, y, c)
	# Note: no fill beyond the raised edge — the sliver between the raised
	# edge and the flat diamond outline is exactly where the upper
	# neighbor's surface sits, and it must stay transparent.


# --- Tree sprite: simple pine, 32x48 ------------------------------------

func _make_tree() -> void:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var trunk := Color("6b4a2f")
	for y in range(36, 47):
		for x in range(14, 18):
			var c := trunk if x < 17 else trunk.darkened(0.2)
			img.set_pixel(x, y, c)
	var foliage := Color("3a6b35")
	# Three stacked triangles, widest at the bottom.
	var tiers := [[2, 16, 9.0], [12, 27, 12.0], [22, 39, 15.0]]
	for tier in tiers:
		var top: int = tier[0]
		var bottom: int = tier[1]
		var max_half: float = tier[2]
		for y in range(top, bottom):
			var t := float(y - top) / float(bottom - top)
			var half := t * max_half
			for x in range(int(ceil(16 - half)), int(floor(16 + half)) + 1):
				var c := foliage
				if x < 16 - half * 0.4:
					c = c.lightened(0.12) # light from the left
				if rng.randf() < 0.12:
					c = c.darkened(0.12)
				img.set_pixel(x, y, c)
	_save(img, "res://assets/sprites/tree.png")


# --- Deciduous trees: beech, oak, plane, linden, 32x48 each ---------------
# All share the same construction — a trunk plus a canopy of overlapping
# foliage blobs — and differ in silhouette, bark and leaf color:
# beech: slender smooth gray trunk, tall oval crown
# oak: thick dark trunk, broad irregular lobed crown
# plane: mottled patchy bark, wide spreading crown
# linden: neat heart-shaped crown, wide at the bottom, yellow-green

func _make_deciduous_trees() -> void:
	_make_deciduous("res://assets/sprites/beech.png", Color("8f857a"), 3, 30, false,
		Color("5e8b4a"), [
			[16, 15, 11, 12], [12, 22, 8, 7], [21, 21, 8, 7],
		])
	_make_deciduous("res://assets/sprites/oak.png", Color("5c4228"), 5, 28, false,
		Color("3f6b2f"), [
			[16, 11, 9, 7], [10, 17, 8, 7], [22, 17, 8, 7], [16, 21, 11, 7],
		])
	_make_deciduous("res://assets/sprites/plane.png", Color("b0a284"), 4, 26, true,
		Color("6b9552"), [
			[16, 14, 13, 10], [9, 20, 7, 6], [23, 20, 7, 6],
		])
	_make_deciduous("res://assets/sprites/linden.png", Color("6b4a2f"), 4, 32, false,
		Color("7ba33f"), [
			[16, 10, 7, 6], [16, 17, 10, 8], [16, 24, 12, 7],
		])


## Blobs are canopy ellipses as [center_x, center_y, radius_x, radius_y].
func _make_deciduous(path: String, trunk_color: Color, trunk_w: int, trunk_top: int,
		mottled_bark: bool, foliage: Color, blobs: Array) -> void:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x0 := 16 - int(trunk_w / 2.0)
	for y in range(trunk_top, 47):
		for x in range(x0, x0 + trunk_w):
			var c := trunk_color if x < x0 + trunk_w - 1 else trunk_color.darkened(0.2)
			# Plane trees shed bark in pale patches.
			if mottled_bark and rng.randf() < 0.25:
				c = c.lightened(0.22)
			img.set_pixel(x, y, c)
	for blob in blobs:
		var bcx: float = blob[0]
		var bcy: float = blob[1]
		var brx: float = blob[2]
		var bry: float = blob[3]
		for y in range(maxi(int(bcy - bry), 0), mini(int(bcy + bry) + 1, 48)):
			for x in range(maxi(int(bcx - brx), 0), mini(int(bcx + brx) + 1, 32)):
				if Vector2((x - bcx) / brx, (y - bcy) / bry).length() <= 1.0:
					var c := foliage
					if x < bcx - brx * 0.3:
						c = c.lightened(0.12) # light from the left
					elif y > bcy + bry * 0.4:
						c = c.darkened(0.1)
					var r := rng.randf()
					if r < 0.15:
						c = c.darkened(0.12)
					elif r < 0.25:
						c = c.lightened(0.08)
					img.set_pixel(x, y, c)
	_save(img, path)


# --- Camper sprite: tiny person, 14x22 ----------------------------------

func _make_camper() -> void:
	var img := Image.create(14, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color("e8b48a")
	var shirt := Color("e8e4d8") # near-white so per-camper modulate tints it
	var pants := Color("4a4a55")
	# Head.
	for y in range(1, 8):
		for x in range(4, 10):
			if Vector2(x - 6.5, y - 4).length() <= 3.2:
				img.set_pixel(x, y, skin)
	# Body / shirt.
	for y in range(8, 16):
		for x in range(3, 11):
			img.set_pixel(x, y, shirt if x > 3 and x < 10 else shirt.darkened(0.15))
	# Legs.
	for y in range(16, 21):
		for x in [4, 5, 8, 9]:
			img.set_pixel(x, y, pants)
	_save(img, "res://assets/sprites/camper.png")


# --- Wildlife sprites, drawn facing right (flip_h turns them around) ------

func _make_deer() -> void:
	var img := Image.create(24, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var coat := Color("9a6b42")
	var dark := coat.darkened(0.3)
	# Body: horizontal ellipse.
	for y in range(6, 13):
		for x in range(4, 17):
			if Vector2((x - 10.0) / 6.5, (y - 9.5) / 3.4).length() <= 1.0:
				var c := coat.lightened(0.1) if y <= 8 else coat
				if rng.randf() < 0.08:
					c = c.darkened(0.08)
				img.set_pixel(x, y, c)
	# White rump patch and short tail.
	for y in range(7, 10):
		img.set_pixel(4, y, Color("e8e0d0"))
	# Legs.
	for leg_x in [6, 8, 13, 15]:
		for y in range(12, 18):
			img.set_pixel(leg_x, y, dark)
	# Neck rising to the right, then the head.
	for y in range(2, 8):
		for x in range(15, 18):
			if x - 15 >= (y - 7) / -3 or y > 4:
				img.set_pixel(x, y, coat)
	for y in range(1, 5):
		for x in range(16, 21):
			img.set_pixel(x, y, coat.lightened(0.05))
	img.set_pixel(21, 3, dark) # muzzle
	img.set_pixel(19, 2, Color("221a12")) # eye
	# Antlers.
	for y in range(0, 2):
		img.set_pixel(16, y, dark)
		img.set_pixel(19, y, dark)
	img.set_pixel(15, 0, dark)
	img.set_pixel(20, 0, dark)
	_save(img, "res://assets/sprites/deer.png")


func _make_beaver() -> void:
	var img := Image.create(16, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fur := Color("5c3d26")
	var tail := Color("4a4038")
	# Flat paddle tail on the left.
	for y in range(5, 8):
		for x in range(0, 4):
			img.set_pixel(x, y, tail if (x + y) % 2 == 0 else tail.darkened(0.12))
	# Round body.
	for y in range(2, 9):
		for x in range(3, 13):
			if Vector2((x - 8.0) / 5.0, (y - 5.5) / 3.4).length() <= 1.0:
				var c := fur.lightened(0.08) if y <= 4 else fur
				if rng.randf() < 0.1:
					c = c.darkened(0.1)
				img.set_pixel(x, y, c)
	# Head bump on the right.
	for y in range(3, 8):
		for x in range(11, 15):
			if Vector2((x - 12.0) / 2.6, (y - 5.0) / 2.4).length() <= 1.0:
				img.set_pixel(x, y, fur.lightened(0.05))
	img.set_pixel(12, 3, fur.darkened(0.2)) # ear
	img.set_pixel(13, 4, Color("1c1410")) # eye
	img.set_pixel(15, 5, Color("2a1d12")) # nose
	img.set_pixel(14, 7, Color("e8dfc8")) # front teeth
	_save(img, "res://assets/sprites/beaver.png")


# Two 12x10 frames side by side: wings raised, wings lowered.
func _make_bird() -> void:
	var img := Image.create(24, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color("4a5a78")
	for f in 2:
		var ox := f * 12
		# Tail feathers, body, head.
		for y in range(5, 7):
			for x in range(1, 4):
				img.set_pixel(ox + x, y, body.darkened(0.15))
		for y in range(4, 8):
			for x in range(3, 9):
				if Vector2((x - 5.5) / 3.2, (y - 5.5) / 2.2).length() <= 1.0:
					img.set_pixel(ox + x, y, body)
		for y in range(2, 6):
			for x in range(7, 11):
				if Vector2((x - 8.5) / 2.2, (y - 3.5) / 2.0).length() <= 1.0:
					img.set_pixel(ox + x, y, body.lightened(0.08))
		img.set_pixel(ox + 11, 3, Color("d98a2b")) # beak
		img.set_pixel(ox + 9, 3, Color("14100d")) # eye
		# Wing: raised on frame 0, folded low on frame 1.
		if f == 0:
			for i in 4:
				img.set_pixel(ox + 5 - i, 3 - i if 3 - i >= 0 else 0, body.darkened(0.2))
				img.set_pixel(ox + 6 - i, 3 - i if 3 - i >= 0 else 0, body.darkened(0.25))
		else:
			for i in 3:
				img.set_pixel(ox + 4 + i, 6, body.darkened(0.2))
				img.set_pixel(ox + 4 + i, 7, body.darkened(0.25))
	_save(img, "res://assets/sprites/bird.png")


# --- Prop sprites: fallen log and boulder ---------------------------------

func _make_log() -> void:
	var img := Image.create(22, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bark := Color("6b4a2f")
	for y in range(2, 9):
		for x in range(3, 21):
			var c := bark
			if y <= 3:
				c = c.lightened(0.12)
			elif y >= 7:
				c = c.darkened(0.15)
			if y == 5 and rng.randf() < 0.5:
				c = c.darkened(0.1) # bark groove
			img.set_pixel(x, y, c)
	# Cut end cap with a growth ring.
	var cap := Color("c9a86b")
	for y in range(2, 9):
		for x in range(1, 5):
			if Vector2((x - 3.0) / 2.2, (y - 5.0) / 3.4).length() <= 1.0:
				var ring := Vector2((x - 3.0) / 2.2, (y - 5.0) / 3.4).length()
				img.set_pixel(x, y, cap.darkened(0.25) if ring > 0.55 and ring < 0.8 else cap)
	_save(img, "res://assets/sprites/log.png")


func _make_rock() -> void:
	var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone := Color("8d8d85")
	for y in range(1, 12):
		for x in range(1, 15):
			if Vector2((x - 8.0) / 7.0, (y - 7.0) / 4.6).length() <= 1.0:
				var c := stone
				if x + y < 12:
					c = c.lightened(0.14) # light from upper-left
				elif x + y > 19:
					c = c.darkened(0.16)
				if rng.randf() < 0.1:
					c = c.darkened(0.12)
				img.set_pixel(x, y, c)
	# A crack.
	for i in 4:
		img.set_pixel(6 + i, 4 + i, stone.darkened(0.3))
	_save(img, "res://assets/sprites/rock.png")


# Metal roadside guardrail (silver rails on dark posts).
func _make_barrier() -> void:
	var img := Image.create(22, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var post := Color("3a3a3e")
	var rail := Color("b8bcc2")
	# Three posts.
	for post_x in [2, 10, 18]:
		for y in range(5, 15):
			img.set_pixel(post_x, y, post)
			img.set_pixel(post_x + 1, y, post.lightened(0.12))
	# W-beam style double rail.
	for x in range(1, 21):
		img.set_pixel(x, 5, rail.lightened(0.1))
		img.set_pixel(x, 6, rail)
		img.set_pixel(x, 7, rail.darkened(0.15))
		img.set_pixel(x, 9, rail.lightened(0.05))
		img.set_pixel(x, 10, rail.darkened(0.08))
		img.set_pixel(x, 11, rail.darkened(0.22))
	_save(img, "res://assets/sprites/barrier.png")


# --- Character portraits: 32bit retro-RPG busts, one per named camper -----
# Head + shoulders, 48x56. The head is turned a few degrees off-center (one
# ear and a nose bump showing on opposite sides) while both eyes stay on the
# centerline looking straight out, the classic JRPG-portrait trick for a
# face that reads as watching the viewer even though it's turned. A wide-
# brim field hat, weathered jacket and neckerchief mark them as dressed for
# living outdoors; the neckerchief carries the camper's own identity color.

const PORTRAIT_W := 48
const PORTRAIT_H := 56

func _make_portraits() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/portraits"))
	# "accent" mirrors CAMPER data in game.gd so the neckerchief matches the
	# camper's name-label color.
	var characters := [
		{"name": "zofia", "gender": "female", "skin": Color("e8b48a"), "hair": Color("3b2417"), "hat": Color("8a6d3f"), "accent": Color(1.0, 0.62, 0.62)},
		{"name": "fern", "gender": "female", "skin": Color("f2c9a0"), "hair": Color("caa24a"), "hat": Color("6b7a4d"), "accent": Color(0.82, 0.72, 1.0)},
		{"name": "noor", "gender": "female", "skin": Color("8a5a34"), "hair": Color("14100d"), "hat": Color("5c4a3d"), "accent": Color(1.0, 0.9, 0.58)},
		{"name": "baptiste", "gender": "male", "skin": Color("e8b48a"), "hair": Color("6b4a2f"), "hat": Color("7a6a4f"), "accent": Color(0.62, 0.8, 1.0)},
		{"name": "miguel", "gender": "male", "skin": Color("c68642"), "hair": Color("1c1712"), "hat": Color("5f7a52"), "accent": Color(0.65, 0.85, 0.55)},
		{"name": "abdula", "gender": "male", "skin": Color("8a5a34"), "hair": Color("241a12"), "hat": Color("6e5641"), "accent": Color(0.9, 0.68, 0.45)},
	]
	for c in characters:
		_draw_portrait("res://assets/portraits/%s.png" % c.name, c.gender, c.skin, c.hair, c.hat, c.accent)


func _portrait_px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < PORTRAIT_W and y >= 0 and y < PORTRAIT_H:
		img.set_pixel(x, y, c)


func _draw_portrait(path: String, gender: String, skin: Color, hair: Color,
		hat_color: Color, accent: Color) -> void:
	var img := Image.create(PORTRAIT_W, PORTRAIT_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := PORTRAIT_W / 2.0
	var jacket := Color("6b6355") # weathered field jacket
	var turn := 3 # px the nose/near features shift right, simulating a head turn
	var head_center := Vector2(cx - 1.0, 23.0)
	var head_r := 11.0

	# Jacket / shoulders.
	for y in range(34, PORTRAIT_H):
		var t := float(y - 34) / float(PORTRAIT_H - 34)
		var half_w: float = lerp(12.0, 21.0, t)
		for x in range(int(cx - half_w), int(cx + half_w) + 1):
			var c := jacket
			if x < cx - half_w * 0.5:
				c = c.lightened(0.08)
			elif x > cx + half_w * 0.6:
				c = c.darkened(0.12)
			_portrait_px(img, x, y, c)
	# Raised collar wedges either side of the neck.
	for y in range(30, 38):
		for x in range(int(cx - 11), int(cx + 11) + 1):
			var dx: float = absf(x - cx)
			if dx > 4.0 and dx < 4.0 + (y - 30) * 0.9:
				_portrait_px(img, x, y, jacket.darkened(0.22))
	# Neckerchief in the camper's identity color.
	for y in range(31, 38):
		var half: float = maxf(0.0, (38 - y) * 0.8)
		for x in range(int(cx - half), int(cx + half) + 1):
			_portrait_px(img, x, y, accent)
	# Neck.
	for y in range(27, 32):
		for x in range(int(cx - 4), int(cx + 4)):
			_portrait_px(img, x, y, skin.darkened(0.08))

	# Head: a plain rounded silhouette, shaded darker on the far side so it
	# reads as turned without deforming the outline (a sideways nose bump
	# just looks like a growth at this resolution).
	for y in range(int(head_center.y - head_r), int(head_center.y + head_r) + 1):
		for x in range(int(head_center.x - head_r), int(head_center.x + head_r) + 1):
			if Vector2(x, y).distance_to(head_center) <= head_r:
				var c := skin
				c = c.lightened(0.07) if x < head_center.x else c.darkened(0.06)
				_portrait_px(img, x, y, c)
	# One visible ear on the near (light) side; the far ear is hidden by the turn.
	var ear_x := int(head_center.x - head_r + 1)
	for y in range(int(head_center.y - 2), int(head_center.y + 3)):
		_portrait_px(img, ear_x, y, skin.darkened(0.1))

	# Hair wisps below the hatline; longer at the temples/nape for female.
	if gender == "female":
		for y in range(17, 33):
			for side in [-1, 1]:
				var x := int(head_center.x + side * (head_r + 1))
				if side < 0 or y < 26:
					_portrait_px(img, x, y, hair)
	else:
		for y in range(17, 20):
			for x in range(int(head_center.x - head_r), int(head_center.x + head_r) + 1):
				if Vector2(x, y).distance_to(head_center) <= head_r + 1:
					_portrait_px(img, x, y, hair.darkened(0.1))

	# Eyebrows + eyes: both stay on the centerline, looking straight at the
	# viewer, while their spacing narrows on the far side to sell the turn.
	var eye_y := int(head_center.y - 1)
	var far_x := int(head_center.x - 3)
	var near_x := int(head_center.x + 3 + turn / 2.0)
	for ex in [far_x, near_x]:
		_portrait_px(img, ex - 1, eye_y - 2, Color("2a2018"))
		_portrait_px(img, ex, eye_y - 2, Color("2a2018"))
		_portrait_px(img, ex, eye_y, Color("2a2018"))
	# Nose: a soft shadow down the centerline, nudged toward the turn.
	var nose_x := int(head_center.x + 1 + turn / 3.0)
	_portrait_px(img, nose_x, eye_y + 2, skin.darkened(0.18))
	_portrait_px(img, nose_x, eye_y + 3, skin.darkened(0.22))
	# Mouth.
	_portrait_px(img, int(head_center.x - 1 + turn / 2.0), int(head_center.y + 5), skin.darkened(0.3))
	_portrait_px(img, int(head_center.x + turn / 2.0), int(head_center.y + 5), skin.darkened(0.3))

	# Wide-brim field hat: flattened brim ellipse plus a domed crown.
	var brim_cy := head_center.y - 6.0
	var brim_rx := head_r + 4.0
	var brim_ry := 3.0
	for y in range(int(brim_cy - brim_ry), int(brim_cy + brim_ry) + 1):
		for x in range(int(head_center.x - brim_rx - 1), int(head_center.x + brim_rx + turn + 1)):
			var ndx := (x - head_center.x) / brim_rx
			var ndy := (y - brim_cy) / brim_ry
			if ndx * ndx + ndy * ndy <= 1.0:
				var c := hat_color
				c = c.lightened(0.08) if x < head_center.x else c.darkened(0.1)
				if y > brim_cy:
					c = c.darkened(0.15)
				_portrait_px(img, x, y, c)
	var crown_r := head_r - 1.0
	var crown_cy := head_center.y - 10.0
	for y in range(int(crown_cy - crown_r * 0.6), int(crown_cy + crown_r * 0.6) + 1):
		for x in range(int(head_center.x - crown_r), int(head_center.x + crown_r) + 1):
			if Vector2(x, y).distance_to(Vector2(head_center.x, crown_cy)) <= crown_r * 0.75:
				var c := hat_color.lightened(0.05) if x < head_center.x else hat_color.darkened(0.05)
				_portrait_px(img, x, y, c)
	# Brim shadow line across the forehead just below the hat.
	var shadow_y := int(brim_cy + brim_ry)
	for x in range(int(head_center.x - head_r + 2), int(head_center.x + head_r + turn - 1)):
		if img.get_pixel(clampi(x, 0, PORTRAIT_W - 1), clampi(shadow_y, 0, PORTRAIT_H - 1)).a > 0:
			_portrait_px(img, x, shadow_y, skin.darkened(0.15))

	_save(img, path)
