extends Node2D
## Builds the parcel: paints the multi-level isometric terrain, scatters
## trees, and spawns a small team of campers that follow action plans.

const GEN_W := 48
const GEN_H := 48
const TREE_CHANCE := 0.55
const LEVEL_PIXEL_OFFSET := 16
## Max distance (world px) from a click to a camper for it to count as a hit.
const CAMPER_SELECT_RADIUS := 20.0
## Fog of war: cells within this distance of a camper become discovered.
const REVEAL_RADIUS := 6
# Ramps are y-sorted inside the terrain layer they rise to, so the upper
# tile behind them (whose skirt they cover) draws first while upper tiles
# in front of them draw over their side faces. The sort row (relative to
# the ramp cell's map row) depends on where the upper tile sits: +x/+y
# ramps have it one row further (+16), -x/-y ramps one row back (-16).
const RAMP_SORT_FRONT := 24.0 # +x / +y ramps: after the upper tile's row
const RAMP_SORT_BACK := 0.0 # -x / -y ramps: before the next screen row

## Tree species scattered on forest tiles: pine, beech, oak, plane, linden.
const TREE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/tree.png"),
	preload("res://assets/sprites/beech.png"),
	preload("res://assets/sprites/oak.png"),
	preload("res://assets/sprites/plane.png"),
	preload("res://assets/sprites/linden.png"),
]
const LOG_TEXTURE := preload("res://assets/sprites/log.png")
const ROCK_TEXTURE := preload("res://assets/sprites/rock.png")
const RAMPS_TEXTURE := preload("res://assets/tiles/ramps.png")
const CAMPER_SCENE := preload("res://scenes/game/camper.tscn")
const WeatherScript := preload("res://scenes/game/weather.gd")

const DEER_COUNT := 7
const BEAVER_COUNT := 4
const BIRD_COUNT := 5

const PORTRAIT_ZOFIA := preload("res://assets/portraits/zofia.png")
const PORTRAIT_FERN := preload("res://assets/portraits/fern.png")
const PORTRAIT_NOOR := preload("res://assets/portraits/noor.png")
const PORTRAIT_BAPTISTE := preload("res://assets/portraits/baptiste.png")
const PORTRAIT_MIGUEL := preload("res://assets/portraits/miguel.png")
const PORTRAIT_ABDULA := preload("res://assets/portraits/abdula.png")

## Campers picked from CHARACTERS for each parcel.
const TEAM_SIZE := 4

## Roles handed out as each camper's 1-2 attributes at spawn time.
const ROLES: Array[String] = [
	"Photographer", "Botanist", "Tracker", "Ornithologist",
	"Activist", "Hydrologist", "Journalist",
]

const CHARACTERS := [
	{"name": "Zofia", "color": Color(1.0, 0.62, 0.62), "portrait": PORTRAIT_ZOFIA},
	{"name": "Fern", "color": Color(0.82, 0.72, 1.0), "portrait": PORTRAIT_FERN},
	{"name": "Noor", "color": Color(1.0, 0.9, 0.58), "portrait": PORTRAIT_NOOR},
	{"name": "Baptiste", "color": Color(0.62, 0.8, 1.0), "portrait": PORTRAIT_BAPTISTE},
	{"name": "Miguel", "color": Color(0.65, 0.85, 0.55), "portrait": PORTRAIT_MIGUEL},
	{"name": "Abdula", "color": Color(0.9, 0.68, 0.45), "portrait": PORTRAIT_ABDULA},
]

@onready var layers: Array = [$Terrain/Level0, $Terrain/Level1, $Terrain/Level2]
@onready var entities: Node2D = $Entities
@onready var birds: Node2D = $Birds
@onready var weather: WeatherScript = $Weather
@onready var waypoint_markers: Node2D = $WaypointMarkers
@onready var debug_overlay: Node2D = $DebugOverlay
@onready var fog: FogOfWar = $Fog
@onready var camera: Camera2D = $Camera
@onready var hud: PanelContainer = $UI/HUD
@onready var pause_banner: Label = $UI/PauseBanner
@onready var selected_portrait: PanelContainer = $UI/SelectedPortrait
@onready var selected_portrait_texture: TextureRect = %SelectedPortraitTexture
@onready var selected_portrait_name: Label = %SelectedPortraitName
@onready var selected_portrait_roles: Label = %SelectedPortraitRoles
@onready var selected_portrait_emotion: Label = %SelectedPortraitEmotion
@onready var selected_energy_bar: ProgressBar = %SelectedEnergyBar
@onready var selected_morale_bar: ProgressBar = %SelectedMoraleBar
@onready var inventory_button: Button = %InventoryButton
@onready var inventory_popup: PanelContainer = $UI/InventoryPopup

var map_w := 0
var map_h := 0
var tiles: Array = []
var levels: Array = []
var tree_cells := {}
## Prop sprites (trees, logs, rocks) by cell, hidden until fog of war
## discovers the cell.
var prop_sprites := {}
var walkable_cells: Array[Vector2i] = []
var campers: Array = []
## Ground animals (deer, beavers); a camper close to one gets scared.
var animals: Array = []
var astar := AStar2D.new()
var rng := RandomNumberGenerator.new()
var ramp_textures: Array[AtlasTexture] = []
var selected_camper: Node2D = null
## While paused, campers freeze but selection, waypoints, and the HUD stay
## interactive, so plans can be edited calmly.
var paused := false


func _ready() -> void:
	rng.randomize()
	for d in TerrainGenerator.RAMP_DIRS.size():
		var tex := AtlasTexture.new()
		tex.atlas = RAMPS_TEXTURE
		tex.region = Rect2(d * 64, 0, 64, 64)
		ramp_textures.append(tex)
	_style_stat_bar(selected_energy_bar, Color(0.35, 0.62, 1.0), tr("Energy"))
	_style_stat_bar(selected_morale_bar, Color(0.92, 0.3, 0.3), tr("Morale"))
	hud.focus_requested.connect(_on_focus_requested)
	hud.selection_changed.connect(_on_camper_selected)
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	fog.cells_revealed.connect(_on_cells_revealed)
	camera.clicked.connect(_on_world_clicked)
	camera.shift_clicked.connect(_on_world_shift_clicked)
	regenerate()


## Colors one of the vertical stat bars beside the selected camper's portrait.
func _style_stat_bar(bar: ProgressBar, fill_color: Color, tip: String) -> void:
	bar.tooltip_text = tip
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)


## The selected camper's stats and emotion change continuously without a
## signal, so the portrait panel is polled every frame.
func _process(_delta: float) -> void:
	if not selected_portrait.visible or not is_instance_valid(selected_camper):
		return
	selected_energy_bar.value = selected_camper.energy
	selected_morale_bar.value = selected_camper.morale
	var icon: String = Camper.EMOTION_ICONS[selected_camper.emotion]
	if selected_portrait_emotion.text != icon:
		selected_portrait_emotion.text = icon
		selected_portrait_emotion.tooltip_text = tr(Camper.EMOTION_NAMES[selected_camper.emotion])


func _on_focus_requested(camper: Node2D) -> void:
	if is_instance_valid(camper):
		create_tween().tween_property(camera, "position", camper.position, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_camper_selected(camper: Node2D) -> void:
	if is_instance_valid(selected_camper) \
			and selected_camper.actions_changed.is_connected(_refresh_waypoint_markers):
		selected_camper.actions_changed.disconnect(_refresh_waypoint_markers)
	selected_camper = camper
	if is_instance_valid(camper):
		camper.actions_changed.connect(_refresh_waypoint_markers)
	_refresh_waypoint_markers()
	if not is_instance_valid(camper):
		selected_portrait.hide()
		inventory_popup.hide()
		return
	selected_portrait.show()
	selected_portrait_texture.texture = camper.portrait
	selected_portrait_name.text = camper.display_name
	selected_portrait_name.add_theme_color_override("font_color", camper.modulate)
	var role_names: Array[String] = []
	for role in camper.roles:
		role_names.append(tr(role))
	selected_portrait_roles.text = ", ".join(role_names)
	if inventory_popup.visible:
		inventory_popup.show_camper(camper)


func _on_inventory_button_pressed() -> void:
	if is_instance_valid(selected_camper):
		inventory_popup.show_camper(selected_camper)


func _on_world_clicked(world_position: Vector2) -> void:
	var closest: Node2D = null
	var closest_dist := CAMPER_SELECT_RADIUS
	for camper in campers:
		if not is_instance_valid(camper):
			continue
		var dist: float = camper.position.distance_to(world_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = camper
	if closest != null:
		hud.select_camper(closest)


## Shift+click queues a waypoint for the selected camper.
func _on_world_shift_clicked(world_position: Vector2) -> void:
	if not is_instance_valid(selected_camper):
		return
	var cell := world_to_cell(world_position)
	if cell.x >= 0 and is_walkable(cell) and fog.is_discovered(cell):
		selected_camper.add_waypoint(cell)


## Diamond markers (with their order number) over the selected camper's
## pending waypoints.
func _refresh_waypoint_markers() -> void:
	for child in waypoint_markers.get_children():
		child.queue_free()
	if not is_instance_valid(selected_camper):
		return
	var number := 0
	for action in selected_camper.actions:
		if action.type != "walk":
			continue
		number += 1
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([
			Vector2(0, -5), Vector2(8, 0), Vector2(0, 5), Vector2(-8, 0),
		])
		marker.color = Color(selected_camper.modulate, 0.8)
		marker.position = cell_to_world(action.target)
		waypoint_markers.add_child(marker)
		var label := Label.new()
		label.text = str(number)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 2)
		label.custom_minimum_size = Vector2(24, 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = marker.position - Vector2(12, 19)
		waypoint_markers.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				paused = not paused
				pause_banner.visible = paused
			KEY_R:
				regenerate()
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/splash/splash.tscn")


func regenerate() -> void:
	for layer in layers:
		layer.clear()
		for child in layer.get_children():
			child.queue_free()
	tree_cells.clear()
	prop_sprites.clear()
	campers.clear()
	animals.clear()
	selected_camper = null
	inventory_popup.hide()
	for child in entities.get_children():
		child.queue_free()
	for child in birds.get_children():
		child.queue_free()
	for child in waypoint_markers.get_children():
		child.queue_free()
	for child in debug_overlay.get_children():
		child.queue_free()

	var data: Dictionary
	if TerrainGenerator.use_debug_terrain:
		data = TerrainGenerator.debug_terrain()
	else:
		data = TerrainGenerator.generate(GEN_W, GEN_H, rng.randi())
	tiles = data.tiles
	levels = data.levels
	map_h = tiles.size()
	map_w = tiles[0].size()
	weather.setup(
		self,
		data.get("weather", TerrainGenerator.WEATHER_CLEAR),
		data.get("weather_seed", 0),
	)
	fog.setup(self)
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			var tile: int = tiles[y][x]
			if TerrainGenerator.is_ramp(tile):
				# Grass base in the tilemap for the skirt; the slope itself
				# is a sprite y-sorted inside the upper level's layer.
				var lvl: int = levels[y][x]
				layers[lvl].set_cell(cell, 0, Vector2i(TerrainGenerator.TILE_GRASS, 0))
				var upper_layer: TileMapLayer = layers[mini(lvl + 1, layers.size() - 1)]
				var frame := tile - TerrainGenerator.TILE_RAMP_FIRST
				var sort_y := RAMP_SORT_FRONT if frame == 0 or frame == 3 else RAMP_SORT_BACK
				var ramp := Sprite2D.new()
				ramp.texture = ramp_textures[frame]
				# In-layer position picks the sort row; offset restores the
				# on-screen position to the cell center.
				ramp.position = cell_to_world(cell) - upper_layer.position + Vector2(0, sort_y - 16.0)
				ramp.offset = Vector2(0, 16.0 - sort_y)
				upper_layer.add_child(ramp)
			else:
				layers[levels[y][x]].set_cell(cell, 0, Vector2i(tile, 0))

	_scatter_trees()
	_scatter_props()
	_build_navigation()
	_spawn_campers()
	_spawn_animals()
	hud.setup(campers)
	# Start on the camp: with fog of war the map center may be undiscovered.
	if campers.is_empty():
		camera.position = cell_to_world(Vector2i(int(map_w / 2.0), int(map_h / 2.0)))
	else:
		camera.position = campers[0].position
	if TerrainGenerator.use_debug_terrain:
		camera.zoom = Vector2(1.5, 1.5)
		_build_debug_overlay()


## Coordinate labels over every land cell so specific tiles can be named.
func _build_debug_overlay() -> void:
	for y in map_h:
		for x in map_w:
			if tiles[y][x] == TerrainGenerator.TILE_DEEP_WATER:
				continue
			var label := Label.new()
			label.text = "%d,%d" % [x, y]
			label.add_theme_font_size_override("font_size", 7)
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
			label.add_theme_constant_override("outline_size", 2)
			label.custom_minimum_size = Vector2(32, 12)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.position = cell_to_world(Vector2i(x, y)) - Vector2(16, 6)
			debug_overlay.add_child(label)
			# Precise cell anchor: a dot exactly at cell_to_world.
			var dot := ColorRect.new()
			dot.color = Color(1, 0, 1, 0.9)
			dot.size = Vector2(2, 2)
			dot.position = cell_to_world(Vector2i(x, y)) - Vector2(1, 1)
			debug_overlay.add_child(dot)


func _scatter_trees() -> void:
	for y in map_h:
		for x in map_w:
			if tiles[y][x] == TerrainGenerator.TILE_FOREST and rng.randf() < TREE_CHANCE:
				var cell := Vector2i(x, y)
				tree_cells[cell] = true
				var tree := Sprite2D.new()
				tree.texture = TREE_TEXTURES[rng.randi() % TREE_TEXTURES.size()]
				tree.offset = Vector2(0, -20)
				tree.position = cell_to_world(cell) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-3, 3))
				tree.scale = Vector2.ONE * rng.randf_range(0.8, 1.15)
				tree.visible = fog.is_discovered(cell)
				entities.add_child(tree)
				prop_sprites[cell] = tree


## Sprinkles fallen logs and boulders over cells that have no tree yet.
func _scatter_props() -> void:
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			if prop_sprites.has(cell):
				continue
			var tile: int = tiles[y][x]
			var texture: Texture2D = null
			match tile:
				TerrainGenerator.TILE_GRASS:
					if rng.randf() < 0.015:
						texture = ROCK_TEXTURE
					elif rng.randf() < 0.012:
						texture = LOG_TEXTURE
				TerrainGenerator.TILE_FOREST:
					if rng.randf() < 0.03:
						texture = LOG_TEXTURE
				TerrainGenerator.TILE_SAND:
					if rng.randf() < 0.03:
						texture = ROCK_TEXTURE
				TerrainGenerator.TILE_ROCK:
					if rng.randf() < 0.12:
						texture = ROCK_TEXTURE
			if texture == null:
				continue
			var prop := Sprite2D.new()
			prop.texture = texture
			prop.offset = Vector2(0, -4)
			prop.position = cell_to_world(cell) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-3, 3))
			prop.visible = fog.is_discovered(cell)
			entities.add_child(prop)
			prop_sprites[cell] = prop


func _build_navigation() -> void:
	astar.clear()
	walkable_cells.clear()
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			if is_walkable(cell):
				walkable_cells.append(cell)
				astar.add_point(_cell_id(cell), Vector2(cell))
	var link_dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1),
	]
	for cell in walkable_cells:
		for dir in link_dirs:
			var next := cell + dir
			if not is_walkable(next):
				continue
			var ok := _can_step_diagonal(cell, next) if dir.x != 0 and dir.y != 0 \
					else _can_step(cell, next)
			if ok:
				astar.connect_points(_cell_id(cell), _cell_id(next))


func _spawn_campers() -> void:
	var spawn_cells: Array[Vector2i] = []
	for cell in walkable_cells:
		if tiles[cell.y][cell.x] == TerrainGenerator.TILE_GRASS:
			spawn_cells.append(cell)
	if spawn_cells.is_empty():
		spawn_cells = walkable_cells.duplicate()
	if spawn_cells.is_empty():
		return
	# Cluster the group around one random camp spot.
	var camp: Vector2i = spawn_cells[rng.randi() % spawn_cells.size()]
	spawn_cells.sort_custom(func(a, b):
		return (a - camp).length_squared() < (b - camp).length_squared())
	var team := _pick_team(TEAM_SIZE)
	for i in mini(team.size(), spawn_cells.size()):
		var data: Dictionary = team[i]
		var camper := CAMPER_SCENE.instantiate()
		entities.add_child(camper)
		camper.setup(self, spawn_cells[i], data.name, data.color, data.portrait, _random_roles())
		campers.append(camper)
		fog.reveal(spawn_cells[i], REVEAL_RADIUS)


func _spawn_animals() -> void:
	var deer_cells: Array[Vector2i] = []
	var bank_cells: Array[Vector2i] = []
	for cell in walkable_cells:
		var tile: int = tiles[cell.y][cell.x]
		if tile == TerrainGenerator.TILE_GRASS or tile == TerrainGenerator.TILE_FOREST:
			deer_cells.append(cell)
		if is_near_water(cell):
			bank_cells.append(cell)
	for i in DEER_COUNT:
		if deer_cells.is_empty():
			break
		_spawn_animal(deer_cells[rng.randi() % deer_cells.size()], Animal.Species.DEER, entities)
	for i in BEAVER_COUNT:
		if bank_cells.is_empty():
			break
		_spawn_animal(bank_cells[rng.randi() % bank_cells.size()], Animal.Species.BEAVER, entities)
	for i in BIRD_COUNT:
		if walkable_cells.is_empty():
			break
		_spawn_animal(walkable_cells[rng.randi() % walkable_cells.size()], Animal.Species.BIRD, birds)


func _spawn_animal(cell: Vector2i, species: Animal.Species, parent: Node2D) -> void:
	var animal := Animal.new()
	parent.add_child(animal)
	animal.setup(self, cell, species)
	if species != Animal.Species.BIRD:
		animals.append(animal)


## Picks `count` distinct characters at random from the full roster.
func _pick_team(count: int) -> Array:
	var pool := CHARACTERS.duplicate()
	var picked: Array = []
	for i in mini(count, pool.size()):
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


## Picks 1-2 distinct roles at random for a newly spawned camper.
func _random_roles() -> Array[String]:
	var pool := ROLES.duplicate()
	var count := 1 if rng.randf() < 0.5 else 2
	var picked: Array[String] = []
	for i in count:
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


## True when any of the cell's 8 neighbours (or the cell itself) is water.
func is_near_water(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := cell + Vector2i(dx, dy)
			if n.x < 0 or n.y < 0 or n.x >= map_w or n.y >= map_h:
				continue
			var tile: int = tiles[n.y][n.x]
			if tile == TerrainGenerator.TILE_WATER or tile == TerrainGenerator.TILE_DEEP_WATER:
				return true
	return false


## Called by campers whenever they enter a new cell.
func reveal_around(cell: Vector2i) -> void:
	fog.reveal(cell, REVEAL_RADIUS)


func _on_cells_revealed(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if prop_sprites.has(cell):
			prop_sprites[cell].visible = true


func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
		return false
	var tile: int = tiles[cell.y][cell.x]
	return tile == TerrainGenerator.TILE_SAND \
		or tile == TerrainGenerator.TILE_GRASS \
		or tile == TerrainGenerator.TILE_FOREST \
		or TerrainGenerator.is_ramp(tile)


## Adjacent cells connect when on the same level, or one level apart with
## the lower cell being a ramp that rises toward the higher cell. A ramp
## tile only connects along its own axis (the low side it's entered from
## and the high side it climbs to), never to the flat ground beside it,
## so it can't be crossed or stepped onto sideways.
func _can_step(a: Vector2i, b: Vector2i) -> bool:
	var ramp_cell := a if TerrainGenerator.is_ramp(tiles[a.y][a.x]) else b
	var ramp_tile: int = tiles[ramp_cell.y][ramp_cell.x]
	if TerrainGenerator.is_ramp(ramp_tile):
		var dir := TerrainGenerator.ramp_dir(ramp_tile)
		var step := b - a
		if step != dir and step != -dir:
			return false
	var la := level_at(a)
	var lb := level_at(b)
	if la == lb:
		return true
	if absi(la - lb) != 1:
		return false
	var lower := a if la < lb else b
	var higher := b if la < lb else a
	var lower_tile: int = tiles[lower.y][lower.x]
	return TerrainGenerator.is_ramp(lower_tile) \
		and lower + TerrainGenerator.ramp_dir(lower_tile) == higher


## A diagonal step crosses the corner shared with two orthogonal neighbours.
## It is allowed only on flat ground: both cells and both corner neighbours
## must be walkable, on the same level, and free of ramps, so the camper
## can't clip past water, cliff edges, or slope sprites.
func _can_step_diagonal(a: Vector2i, b: Vector2i) -> bool:
	var corners: Array[Vector2i] = [Vector2i(a.x, b.y), Vector2i(b.x, a.y)]
	for corner in corners:
		if not is_walkable(corner):
			return false
	for cell: Vector2i in corners + [a, b] as Array[Vector2i]:
		if level_at(cell) != level_at(a) or TerrainGenerator.is_ramp(tiles[cell.y][cell.x]):
			return false
	return true


func level_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
		return 0
	return levels[cell.y][cell.x]


func cell_to_world(cell: Vector2i) -> Vector2:
	return layers[0].map_to_local(cell) + Vector2(0, -LEVEL_PIXEL_OFFSET * level_at(cell))


## The map cell under a world position, accounting for the pixel offset of
## raised levels (higher levels checked first, since they draw on top).
## Returns (-1, -1) when the position is outside the map.
func world_to_cell(world: Vector2) -> Vector2i:
	for lvl in range(layers.size() - 1, -1, -1):
		var cell: Vector2i = layers[0].local_to_map(world + Vector2(0, LEVEL_PIXEL_OFFSET * lvl))
		if cell.x >= 0 and cell.y >= 0 and cell.x < map_w and cell.y < map_h \
				and level_at(cell) == lvl:
			return cell
	return Vector2i(-1, -1)


## Path between two cells, excluding the start cell. Empty if unreachable.
func find_path(from: Vector2i, to: Vector2i) -> Array:
	var from_id := _cell_id(from)
	var to_id := _cell_id(to)
	if not astar.has_point(from_id) or not astar.has_point(to_id):
		return []
	var ids := astar.get_id_path(from_id, to_id)
	var path: Array = []
	for i in range(1, ids.size()):
		var id := int(ids[i])
		@warning_ignore("integer_division")
		path.append(Vector2i(id % map_w, id / map_w))
	return path


func random_cell_near(origin: Vector2i, radius: int) -> Vector2i:
	for attempt in 12:
		var cell := origin + Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))
		if cell != origin and is_walkable(cell):
			return cell
	return origin


func _cell_id(cell: Vector2i) -> int:
	return cell.y * map_w + cell.x
