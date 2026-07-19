class_name TerrainGenerator
## Generates an island-shaped parcel of terrain with up to 3 elevation
## levels, plus ramp tiles that connect adjacent levels.

const TILE_DEEP_WATER := 0
const TILE_WATER := 1
const TILE_SAND := 2
const TILE_GRASS := 3
const TILE_FOREST := 4
const TILE_ROCK := 5
# Directional ramps: each one rises toward a single neighbor and only
# connects the two levels along that direction.
const TILE_RAMP_FIRST := 6 # +x, then -x, -y, +y (matches RAMP_DIRS)

## Direction to the higher neighbor for tile TILE_RAMP_FIRST + i.
## Order matches the frames in assets/tiles/ramps.png.
const RAMP_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]

const MAX_LEVEL := 2
const RAMP_CHANCE := 0.75

## Parcel sky conditions rolled during generation. Cloudy and rainy both get
## drifting cloud shadows; rainy also spawns rain particles.
const WEATHER_CLEAR := 0
const WEATHER_CLOUDY := 1
const WEATHER_RAINY := 2

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## When true, the game scene builds the fixed debug parcel instead of a
## generated one. Set from the splash screen's Debug button.
static var use_debug_terrain := false


static func is_ramp(tile: int) -> bool:
	return tile >= TILE_RAMP_FIRST


static func ramp_dir(tile: int) -> Vector2i:
	return RAMP_DIRS[tile - TILE_RAMP_FIRST]


## Returns {"tiles", "levels", "weather", "weather_seed"}. tiles/levels are
## Arrays of PackedInt32Array indexed as grid[y][x].
static func generate(width: int, height: int, seed_value: int) -> Dictionary:
	var height_noise := FastNoiseLite.new()
	height_noise.seed = seed_value
	height_noise.frequency = 0.06
	height_noise.fractal_octaves = 4

	var moisture_noise := FastNoiseLite.new()
	moisture_noise.seed = seed_value + 1000
	moisture_noise.frequency = 0.08

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 2000

	var tiles: Array = []
	var levels: Array = []
	var moisture_sum := 0.0
	var moisture_count := 0
	for y in height:
		var tile_row := PackedInt32Array()
		var level_row := PackedInt32Array()
		for x in width:
			# Open land parcel: no radial falloff, water comes from carved
			# rivers (plus the occasional low-lying pond).
			var elevation := height_noise.get_noise_2d(x, y) * 0.7 + 0.28
			var moisture := moisture_noise.get_noise_2d(x, y)
			moisture_sum += moisture
			moisture_count += 1

			var tile: int
			var level := 0
			if elevation < -0.25:
				tile = TILE_WATER
			elif elevation < -0.16:
				tile = TILE_SAND
			else:
				if elevation > 0.62:
					tile = TILE_ROCK
				elif moisture > 0.12:
					tile = TILE_FOREST
				else:
					tile = TILE_GRASS
				# Quantize land elevation into 3 levels.
				if elevation > 0.45:
					level = 2
				elif elevation > 0.22:
					level = 1
			tile_row.append(tile)
			level_row.append(level)
		tiles.append(tile_row)
		levels.append(level_row)

	_carve_rivers(tiles, levels, width, height, rng)
	_smooth_levels(levels, width, height)
	_place_ramps(tiles, levels, width, height, rng)
	var avg_moisture := moisture_sum / float(moisture_count)
	return {
		"tiles": tiles,
		"levels": levels,
		"weather": _roll_weather(rng, avg_moisture),
		"weather_seed": seed_value + 3000,
	}


## Clear / cloudy / rainy, biased toward wetter skies on moist parcels.
static func _roll_weather(rng: RandomNumberGenerator, avg_moisture: float) -> int:
	# avg_moisture is roughly in [-1, 1]; shift rain/cloud chances up when wet.
	var wet := clampf(avg_moisture * 0.5 + 0.5, 0.0, 1.0)
	var rain_chance := 0.12 + wet * 0.18
	var cloud_chance := 0.28 + wet * 0.12
	var roll := rng.randf()
	if roll < rain_chance:
		return WEATHER_RAINY
	if roll < rain_chance + cloud_chance:
		return WEATHER_CLOUDY
	return WEATHER_CLEAR


## Carves 1-2 meandering rivers across the parcel: a deep-water channel with
## shallow water beside it and sandy banks, all forced to level 0 (smoothing
## then steps the surrounding terrain down toward the valley). Every several
## rows the river is interrupted by a two-row sand ford so the two sides
## stay reachable on foot.
static func _carve_rivers(tiles: Array, levels: Array, width: int, height: int, rng: RandomNumberGenerator) -> void:
	var count := 2 if rng.randf() < 0.65 else 1
	for i in count:
		var vertical := rng.randf() < 0.5
		var length := height if vertical else width
		var span := width if vertical else height
		var meander := FastNoiseLite.new()
		meander.seed = rng.randi()
		meander.frequency = 0.15
		var pos := rng.randf_range(span * 0.25, span * 0.75)
		var ford_in := rng.randi_range(7, 12)
		for t in length:
			pos = clampf(pos + meander.get_noise_1d(float(t)) * 1.3, 2.0, span - 3.0)
			var c := int(pos)
			ford_in -= 1
			var is_ford := ford_in <= 0
			if ford_in <= -1:
				ford_in = rng.randi_range(7, 12)
			for o in range(-2, 3):
				var cell := Vector2i(c + o, t) if vertical else Vector2i(t, c + o)
				if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
					continue
				levels[cell.y][cell.x] = 0
				var current: int = tiles[cell.y][cell.x]
				if absi(o) == 2:
					# Banks: sand, unless already water (river junctions).
					if current != TILE_WATER and current != TILE_DEEP_WATER:
						tiles[cell.y][cell.x] = TILE_SAND
				elif is_ford:
					tiles[cell.y][cell.x] = TILE_SAND
				elif o == 0:
					tiles[cell.y][cell.x] = TILE_DEEP_WATER
				else:
					tiles[cell.y][cell.x] = TILE_WATER


## Clamp neighboring level differences to 1 so cliffs are never taller
## than one skirt and every step can be bridged by a single ramp.
static func _smooth_levels(levels: Array, width: int, height: int) -> void:
	var changed := true
	while changed:
		changed = false
		for y in height:
			for x in width:
				var min_neighbor := MAX_LEVEL
				for dir in DIRS:
					var nx := x + dir.x
					var ny := y + dir.y
					if nx >= 0 and ny >= 0 and nx < width and ny < height:
						min_neighbor = mini(min_neighbor, levels[ny][nx])
				if levels[y][x] > min_neighbor + 1:
					levels[y][x] = min_neighbor + 1
					changed = true


## Turn some walkable cells into directional ramps, following these rules:
## - a ramp never touches another ramp (8-neighborhood);
## - along the ramp's axis, the tile it rises toward is exactly one level
##   higher and standable, and the tile behind it is walkable ground at the
##   ramp's own (lower) level, so the ramp is entered low and exited high;
## - both tiles beside the ramp (perpendicular to its axis) are at the
##   ramp's own level, so the only level change around a ramp is the one
##   it bridges — its lower side never hangs over a further drop.
static func _place_ramps(tiles: Array, levels: Array, width: int, height: int, rng: RandomNumberGenerator) -> void:
	for y in height:
		for x in width:
			var tile: int = tiles[y][x]
			if tile != TILE_GRASS and tile != TILE_FOREST and tile != TILE_SAND:
				continue
			if _has_adjacent_ramp(tiles, x, y, width, height):
				continue
			var level: int = levels[y][x]
			var candidates: Array[int] = []
			for i in RAMP_DIRS.size():
				var d := RAMP_DIRS[i]
				var ux := x + d.x
				var uy := y + d.y
				var lx := x - d.x
				var ly := y - d.y
				if ux < 0 or uy < 0 or ux >= width or uy >= height:
					continue
				if lx < 0 or ly < 0 or lx >= width or ly >= height:
					continue
				var upper_tile: int = tiles[uy][ux]
				var lower_tile: int = tiles[ly][lx]
				if levels[uy][ux] != level + 1:
					continue
				if upper_tile != TILE_GRASS and upper_tile != TILE_FOREST:
					continue
				if levels[ly][lx] != level:
					continue
				if lower_tile != TILE_GRASS and lower_tile != TILE_FOREST and lower_tile != TILE_SAND:
					continue
				var perp := Vector2i(d.y, d.x)
				var sides_flat := true
				for side in [perp, -perp]:
					var sx: int = x + side.x
					var sy: int = y + side.y
					if sx < 0 or sy < 0 or sx >= width or sy >= height or levels[sy][sx] != level:
						sides_flat = false
						break
				if not sides_flat:
					continue
				candidates.append(i)
			if not candidates.is_empty() and rng.randf() < RAMP_CHANCE:
				tiles[y][x] = TILE_RAMP_FIRST + candidates[rng.randi() % candidates.size()]


# Fixed parcel for debugging rendering: a level-1 plateau with a level-2
# top, ramps in all four directions at both cliffs, rock and forest tiles.
# Legend: . deep water, "," water, s sand, g/G/H grass L0/L1/L2,
# f/F forest L0/L1, r rock L2, > < ^ v ramps rising toward +x/-x/-y/+y.
const DEBUG_MAP: Array[String] = [
	"......................",
	"......................",
	",,,,,,,,,,,,,,,,,,,,,,",
	",ssssssssssssssssssss,",
	",sggggggggggggggggggs,",
	",sggggggggvgggggggggs,",
	",sggggGGGGGGGGGGggggs,",
	",sggggGGGGGGGGGGggggs,",
	",sggg>GGGGvGGGGGggggs,",
	",sggggGGGHHHHGGGggggs,",
	",sggggGG>HrrHGGG<gggs,",
	",sggggGGGHHHH<GGggggs,",
	",sggggGGGHHHHGGGggggs,",
	",sggggGGGGG^GGGGggggs,",
	",sggggGFFFGGGGGGggggs,",
	",sggggGGGGGGGGGGggggs,",
	",sggggggggg^ggggggggs,",
	",sggfffgggggggggggggs,",
	",ssssssssssssssssssss,",
	",,,,,,,,,,,,,,,,,,,,,,",
	"......................",
	"......................",
]


## Builds the fixed DEBUG_MAP parcel. Same return shape as generate().
static func debug_terrain() -> Dictionary:
	var legend := {
		".": [TILE_DEEP_WATER, 0],
		",": [TILE_WATER, 0],
		"s": [TILE_SAND, 0],
		"g": [TILE_GRASS, 0],
		"G": [TILE_GRASS, 1],
		"H": [TILE_GRASS, 2],
		"f": [TILE_FOREST, 0],
		"F": [TILE_FOREST, 1],
		"r": [TILE_ROCK, 2],
		">": [TILE_RAMP_FIRST, -1],
		"<": [TILE_RAMP_FIRST + 1, -1],
		"^": [TILE_RAMP_FIRST + 2, -1],
		"v": [TILE_RAMP_FIRST + 3, -1],
	}
	var tiles: Array = []
	var levels: Array = []
	for row_string in DEBUG_MAP:
		var tile_row := PackedInt32Array()
		var level_row := PackedInt32Array()
		for c in row_string:
			var entry: Array = legend[c]
			tile_row.append(entry[0])
			level_row.append(entry[1])
		tiles.append(tile_row)
		levels.append(level_row)
	# Ramp levels: one below the tile they rise toward.
	for y in tiles.size():
		for x in tiles[y].size():
			if levels[y][x] == -1:
				var d := ramp_dir(tiles[y][x])
				levels[y][x] = int(levels[y + d.y][x + d.x]) - 1
	# Fixed cloudy sky so cloud shadows are visible while debugging layout.
	return {
		"tiles": tiles,
		"levels": levels,
		"weather": WEATHER_CLOUDY,
		"weather_seed": 1,
	}


static func _has_adjacent_ramp(tiles: Array, x: int, y: int, width: int, height: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and ny >= 0 and nx < width and ny < height and is_ramp(tiles[ny][nx]):
				return true
	return false
