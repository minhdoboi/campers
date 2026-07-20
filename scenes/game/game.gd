extends Node2D
## Builds the parcel: paints the multi-level isometric terrain, scatters
## trees, and spawns a small team of campers that follow action plans.

const GEN_W := 48
const GEN_H := 48
const TREE_CHANCE := 0.55
const LEVEL_PIXEL_OFFSET := 16
## Max distance (world px) from a click to a camper for it to count as a hit.
const CAMPER_SELECT_RADIUS := 20.0
## World-space offset of the selection arrow tip above a camper's feet.
const SELECTION_ARROW_OFFSET := Vector2(0, -32)
## Max distance (world px) from the cursor to a cliff edge to show/click its arrow.
const EDGE_ACTION_HIT_RADIUS := 16.0
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
const BARRIER_TEXTURE := preload("res://assets/sprites/barrier.png")
const BIRD_TEXTURE := preload("res://assets/sprites/bird.png")
const BEAVER_TEXTURE := preload("res://assets/sprites/beaver.png")
const TRAP_TEXTURE := preload("res://assets/sprites/trap.png")
const RAMPS_TEXTURE := preload("res://assets/tiles/ramps.png")
const CAMPER_SCENE := preload("res://scenes/game/camper.tscn")
const WeatherScript := preload("res://scenes/game/weather.gd")
## Chance a scattered log hides a "forbidden cut" evidence card.
const FORBIDDEN_CUT_CHANCE := 0.28
## Chance each neighbour of a log gets a bird-nest remnant (ornithologist only).
const NEST_AROUND_LOG_CHANCE := 0.22
## How many animal traps to hide near barriers / trees.
const TRAP_FIND_MIN := 2
const TRAP_FIND_MAX := 4
## Discarded fishing line on banks / walkable cells next to water.
const FISHING_LINE_FIND_MIN := 1
const FISHING_LINE_FIND_MAX := 3
## Leftover food scraps on open grass / forest.
const LEFTOVER_FOOD_FIND_MIN := 1
const LEFTOVER_FOOD_FIND_MAX := 3
## How many visible berry patches to scatter for foraging.
const BERRY_FIND_MIN := 10
const BERRY_FIND_MAX := 18
## How many botanist plant finds to hide on grass / forest.
const PLANT_FIND_MIN := 8
const PLANT_FIND_MAX := 14
## How many ornithologist bird sightings to hide on tree cells.
const BIRD_TREE_FIND_MIN := 6
const BIRD_TREE_FIND_MAX := 12
## World-px radius: ornithologist can ID a flying bird that passes this close.
const BIRD_SIGHTING_RADIUS := 90.0
## Chance a ground animal carries a hidden "wounded animal" card.
const WOUNDED_ANIMAL_CHANCE := 0.4
## Chebyshev radius: inspect finds cards on the camper's cell and neighbours.
const INSPECT_FIND_RADIUS := 1

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
@onready var edge_action_markers: Node2D = $EdgeActionMarkers
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
@onready var cards_tray: Control = $UI/CardsTray
@onready var journal_log: Control = $UI/JournalLog

var map_w := 0
var map_h := 0
var tiles: Array = []
var levels: Array = []
var tree_cells := {}
## Prop sprites (trees, logs, rocks, barriers) by cell, hidden until fog of
## war discovers the cell.
var prop_sprites := {}
## Cells blocked by roadside metal guardrails.
var barrier_cells := {}
## Hidden evidence: cell -> {kind, collected, sprite}.
var hidden_finds := {}
## Team-wide evidence cards found by any camper this parcel.
var collected_cards: Array[Dictionary] = []
## Append-only journal of notable events (berry finds, etc.) with map cells.
var journal_entries: Array[Dictionary] = []
var walkable_cells: Array[Vector2i] = []
var campers: Array = []
## Ground animals (deer, beavers); a camper close to one gets scared.
var animals: Array = []
var astar := AStar2D.new()
var rng := RandomNumberGenerator.new()
var ramp_textures: Array[AtlasTexture] = []
## Cached procedural texture for berry patch markers.
var _berry_texture: Texture2D = null
var selected_camper: Node2D = null
## White ▼ outline that tracks the selected camper (not a child, so it stays untinted).
var _selection_arrow: Line2D
## Extra Y offset during the selection-change bump animation.
var _selection_arrow_bump := 0.0
var _selection_arrow_tween: Tween
## Brief diamond flash when a journal entry with a map cell is clicked.
var _tile_highlight: Node2D
var _tile_highlight_tween: Tween
## Hit targets for cliff climb/descend arrows: {pos, target, cost, going_up}.
var _edge_action_hits: Array[Dictionary] = []
## Last plan cell used to rebuild edge hits (refresh when it changes).
var _edge_actions_plan_cell := Vector2i(-999, -999)
## Whole-number energy when edge hits were last rebuilt (affordability).
var _edge_actions_energy_key := -1
## Index into _edge_action_hits of the hovered edge, or -1 when none.
var _hovered_edge_index := -1
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
	_selection_arrow = Line2D.new()
	_selection_arrow.points = PackedVector2Array([
		Vector2(-3, -1.5), Vector2(0, 2.5), Vector2(3, -1.5),
	])
	_selection_arrow.width = 1.0
	_selection_arrow.default_color = Color(1, 1, 1, 0.95)
	_selection_arrow.joint_mode = Line2D.LINE_JOINT_SHARP
	_selection_arrow.begin_cap_mode = Line2D.LINE_CAP_NONE
	_selection_arrow.end_cap_mode = Line2D.LINE_CAP_NONE
	_selection_arrow.visible = false
	_selection_arrow.z_index = 20
	add_child(_selection_arrow)
	_style_stat_bar(selected_energy_bar, Color(0.35, 0.62, 1.0), tr("Energy"))
	_style_stat_bar(selected_morale_bar, Color(0.92, 0.3, 0.3), tr("Morale"))
	hud.focus_requested.connect(_on_focus_requested)
	hud.selection_changed.connect(_on_camper_selected)
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	journal_log.focus_requested.connect(_on_journal_focus_requested)
	journal_log.solve_requested.connect(_on_journal_solve_requested)
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
	if is_instance_valid(selected_camper):
		_selection_arrow.visible = true
		_selection_arrow.position = selected_camper.position + SELECTION_ARROW_OFFSET \
			+ Vector2(0, _selection_arrow_bump)
		var energy_key := int(selected_camper.energy)
		if selected_camper.plan_cell() != _edge_actions_plan_cell \
				or energy_key != _edge_actions_energy_key:
			_refresh_edge_actions()
		_update_edge_action_display(get_global_mouse_position())
	else:
		_selection_arrow.visible = false
		if _hovered_edge_index >= 0 or not edge_action_markers.get_children().is_empty():
			_clear_edge_action_arrows()
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
		_focus_world(camper.position)


func _on_journal_focus_requested(cell: Vector2i) -> void:
	_focus_world(cell_to_world(cell))
	_highlight_tile(cell)


func _focus_world(world_pos: Vector2) -> void:
	create_tween().tween_property(camera, "position", world_pos, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Pulses a diamond over `cell` so a journal location is easy to spot.
func _highlight_tile(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
		return
	_clear_tile_highlight()
	_tile_highlight = Node2D.new()
	_tile_highlight.z_index = 15
	_tile_highlight.position = cell_to_world(cell)
	var diamond := PackedVector2Array([
		Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0),
	])
	var fill := Polygon2D.new()
	fill.polygon = diamond
	fill.color = Color(1.0, 0.95, 0.35, 0.35)
	_tile_highlight.add_child(fill)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0), Vector2(0, -16),
	])
	outline.width = 1.5
	outline.default_color = Color(1.0, 1.0, 0.55, 0.95)
	outline.joint_mode = Line2D.LINE_JOINT_SHARP
	_tile_highlight.add_child(outline)
	_tile_highlight.modulate.a = 0.0
	add_child(_tile_highlight)
	_tile_highlight_tween = create_tween()
	_tile_highlight_tween.tween_property(_tile_highlight, "modulate:a", 1.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tile_highlight_tween.tween_interval(0.85)
	_tile_highlight_tween.tween_property(_tile_highlight, "modulate:a", 0.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tile_highlight_tween.tween_callback(_clear_tile_highlight)


func _clear_tile_highlight() -> void:
	if _tile_highlight_tween != null:
		_tile_highlight_tween.kill()
		_tile_highlight_tween = null
	if is_instance_valid(_tile_highlight):
		_tile_highlight.queue_free()
		_tile_highlight = null


func _on_camper_selected(camper: Node2D) -> void:
	if is_instance_valid(selected_camper) \
			and selected_camper.actions_changed.is_connected(_on_selected_actions_changed):
		selected_camper.actions_changed.disconnect(_on_selected_actions_changed)
	selected_camper = camper
	if is_instance_valid(camper):
		camper.actions_changed.connect(_on_selected_actions_changed)
		_bump_selection_arrow()
	_on_selected_actions_changed()
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


## Quick dip-and-settle on the selection arrow when the focused camper changes.
func _bump_selection_arrow() -> void:
	if _selection_arrow_tween != null:
		_selection_arrow_tween.kill()
	_selection_arrow_bump = 0.0
	_selection_arrow_tween = create_tween()
	_selection_arrow_tween.tween_property(self, "_selection_arrow_bump", 4.0, 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_selection_arrow_tween.tween_property(self, "_selection_arrow_bump", -1.5, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_selection_arrow_tween.tween_property(self, "_selection_arrow_bump", 0.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_selected_actions_changed() -> void:
	_refresh_waypoint_markers()
	_refresh_edge_actions()


func _on_inventory_button_pressed() -> void:
	if is_instance_valid(selected_camper):
		inventory_popup.show_camper(selected_camper)


func _on_world_clicked(world_position: Vector2) -> void:
	if _try_edge_action_click(world_position):
		return
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
		return
	_queue_move_at(world_position)


## Shift+click also queues a waypoint for the selected camper.
func _on_world_shift_clicked(world_position: Vector2) -> void:
	_queue_move_at(world_position)


## Sends the selected camper toward a walkable, discovered cell.
func _queue_move_at(world_position: Vector2) -> void:
	if not is_instance_valid(selected_camper):
		return
	var cell := world_to_cell(world_position)
	if cell.x >= 0 and is_walkable(cell) and fog.is_discovered(cell):
		selected_camper.add_waypoint(cell)


## Diamond markers (with their order number) over the selected camper's
## pending waypoints and cliff climbs.
func _refresh_waypoint_markers() -> void:
	for child in waypoint_markers.get_children():
		child.queue_free()
	if not is_instance_valid(selected_camper):
		return
	var number := 0
	for action in selected_camper.actions:
		if action.type != "walk" and action.type != "climb":
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


## True when climb arrows should stay on the plan cell (last waypoint / climb
## destination) so further climbs can be queued without hunting for edges.
func _edge_actions_pinned() -> bool:
	return is_instance_valid(selected_camper) \
		and selected_camper.plan_cell() != selected_camper.cell


func _update_edge_action_display(world_position: Vector2) -> void:
	var best_index := -1
	var best_dist := EDGE_ACTION_HIT_RADIUS
	for i in _edge_action_hits.size():
		var dist: float = world_position.distance_to(_edge_action_hits[i].pos)
		if dist < best_dist:
			best_dist = dist
			best_index = i
	var pinned := _edge_actions_pinned()
	## Hover-only while standing on the plan cell; pin all arrows on the last
	## waypoint so a climb can be queued ahead of the camper.
	var want_count := _edge_action_hits.size() if pinned else (1 if best_index >= 0 else 0)
	if best_index == _hovered_edge_index \
			and edge_action_markers.get_child_count() == want_count:
		return
	_clear_edge_action_arrows()
	_hovered_edge_index = best_index
	if pinned:
		for i in _edge_action_hits.size():
			_spawn_edge_action_arrow(_edge_action_hits[i], i == best_index)
	elif best_index >= 0:
		_spawn_edge_action_arrow(_edge_action_hits[best_index], true)


func _spawn_edge_action_arrow(hit: Dictionary, highlighted: bool) -> void:
	var affordable: bool = selected_camper.energy >= hit.cost
	var arrow := Label.new()
	arrow.text = "▲" if hit.going_up else "▼"
	arrow.add_theme_font_size_override("font_size", 14)
	var tint: Color
	if affordable:
		tint = Color(0.45, 0.95, 0.55, 0.95) if hit.going_up else Color(0.55, 0.75, 1.0, 0.95)
	else:
		tint = Color(0.55, 0.55, 0.58, 0.75)
	if not highlighted:
		tint.a *= 0.7
	arrow.add_theme_color_override("font_color", tint)
	arrow.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85 if affordable else 0.45))
	arrow.add_theme_constant_override("outline_size", 3)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.custom_minimum_size = Vector2(20, 20)
	arrow.position = hit.pos - Vector2(10, 10)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_action_markers.add_child(arrow)


func _clear_edge_action_arrows() -> void:
	while edge_action_markers.get_child_count() > 0:
		var child := edge_action_markers.get_child(0)
		edge_action_markers.remove_child(child)
		child.free()
	_hovered_edge_index = -1


func _refresh_edge_actions() -> void:
	_clear_edge_action_arrows()
	_edge_action_hits.clear()
	_edge_actions_plan_cell = Vector2i(-999, -999)
	_edge_actions_energy_key = -1
	if not is_instance_valid(selected_camper):
		return
	## Always from the end of the queue (last waypoint / climb), so climbs can
	## be planned after a walk and further walks after a climb.
	var from: Vector2i = selected_camper.plan_cell()
	_edge_actions_plan_cell = from
	_edge_actions_energy_key = int(selected_camper.energy)
	var from_world := cell_to_world(from)
	for dir in TerrainGenerator.DIRS:
		var neighbor: Vector2i = from + dir
		if not can_cliff_climb(from, neighbor):
			continue
		if not fog.is_discovered(neighbor):
			continue
		var going_up: bool = level_at(neighbor) > level_at(from)
		var cost := Camper.ENERGY_CLIMB_UP if going_up else Camper.ENERGY_CLIMB_DOWN
		var neighbor_world := cell_to_world(neighbor)
		var edge_pos := from_world.lerp(neighbor_world, 0.42)
		_edge_action_hits.append({
			"pos": edge_pos,
			"target": neighbor,
			"cost": cost,
			"going_up": going_up,
		})


func _try_edge_action_click(world_position: Vector2) -> bool:
	if not is_instance_valid(selected_camper) or _edge_action_hits.is_empty():
		return false
	var best: Dictionary = {}
	var best_dist := EDGE_ACTION_HIT_RADIUS
	for hit in _edge_action_hits:
		var dist: float = world_position.distance_to(hit.pos)
		if dist < best_dist:
			best_dist = dist
			best = hit
	if best.is_empty():
		return false
	if selected_camper.add_climb(best.target):
		_refresh_edge_actions()
	return true


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
	barrier_cells.clear()
	hidden_finds.clear()
	collected_cards.clear()
	journal_entries.clear()
	campers.clear()
	animals.clear()
	selected_camper = null
	_clear_tile_highlight()
	inventory_popup.hide()
	cards_tray.refresh(collected_cards)
	cards_tray.popup.hide()
	_refresh_journal()
	journal_log.popup.hide()
	for child in entities.get_children():
		child.queue_free()
	for child in birds.get_children():
		child.queue_free()
	for child in waypoint_markers.get_children():
		child.queue_free()
	for child in edge_action_markers.get_children():
		child.queue_free()
	_edge_action_hits.clear()
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
	for cell in data.get("barriers", []):
		barrier_cells[cell] = true
	## Cells reserved for generator-placed finds (skip random trees/rocks).
	var reserved_finds := {}
	for find in data.get("discoverables", []):
		reserved_finds[find.cell] = find.kind
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

	_scatter_trees(reserved_finds)
	_scatter_props(reserved_finds)
	_scatter_barriers()
	for find in data.get("discoverables", []):
		_register_hidden_find(find.cell, find.kind)
	_scatter_nest_finds()
	_scatter_trap_finds()
	_scatter_fishing_line_finds()
	_scatter_leftover_food_finds()
	_scatter_berry_finds()
	_scatter_plant_finds()
	_scatter_bird_tree_finds()
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


func _scatter_trees(reserved_finds: Dictionary = {}) -> void:
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			if barrier_cells.has(cell) or reserved_finds.has(cell):
				continue
			if tiles[y][x] == TerrainGenerator.TILE_FOREST and rng.randf() < TREE_CHANCE:
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
## Some logs hide a "forbidden cut" card until inspected.
func _scatter_props(reserved_finds: Dictionary = {}) -> void:
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			if prop_sprites.has(cell) or barrier_cells.has(cell):
				continue
			# Leave generator roadside carcass cells empty; seed a log when the
			# reserved find is a forbidden cut.
			if reserved_finds.has(cell):
				if reserved_finds[cell] == DiscoverableCards.KIND_FORBIDDEN_CUT:
					var log := Sprite2D.new()
					log.texture = LOG_TEXTURE
					log.offset = Vector2(0, -4)
					log.position = cell_to_world(cell)
					log.visible = fog.is_discovered(cell)
					entities.add_child(log)
					prop_sprites[cell] = log
				continue
			var tile: int = tiles[y][x]
			var texture: Texture2D = null
			var is_log := false
			match tile:
				TerrainGenerator.TILE_GRASS:
					if rng.randf() < 0.015:
						texture = ROCK_TEXTURE
					elif rng.randf() < 0.012:
						texture = LOG_TEXTURE
						is_log = true
				TerrainGenerator.TILE_FOREST:
					if rng.randf() < 0.03:
						texture = LOG_TEXTURE
						is_log = true
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
			if is_log and rng.randf() < FORBIDDEN_CUT_CHANCE:
				_register_hidden_find(cell, DiscoverableCards.KIND_FORBIDDEN_CUT)


## Metal guardrails beside car roads; they block walking on their cell.
func _scatter_barriers() -> void:
	for cell in barrier_cells:
		var barrier := Sprite2D.new()
		barrier.texture = BARRIER_TEXTURE
		barrier.offset = Vector2(0, -8)
		barrier.position = cell_to_world(cell) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-2, 2))
		barrier.visible = fog.is_discovered(cell)
		entities.add_child(barrier)
		prop_sprites[cell] = barrier


## Bird-nest remnants on walkable cells next to fallen logs (ornithologist only).
func _scatter_nest_finds() -> void:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for cell: Vector2i in prop_sprites:
		var prop: Sprite2D = prop_sprites[cell]
		if not is_instance_valid(prop) or prop.texture != LOG_TEXTURE:
			continue
		for d in dirs:
			if rng.randf() >= NEST_AROUND_LOG_CHANCE:
				continue
			var n: Vector2i = cell + d
			if _can_host_find(n):
				_register_hidden_find(n, DiscoverableCards.KIND_BIRD_NEST_REMNANTS)


## Animal traps hidden on walkable ground next to barriers or trees.
func _scatter_trap_finds() -> void:
	var candidates: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	for cell: Vector2i in barrier_cells:
		for d in dirs:
			var n: Vector2i = cell + d
			if _can_host_find(n) and not candidates.has(n):
				candidates.append(n)
	for cell: Vector2i in tree_cells:
		for d in dirs:
			var n: Vector2i = cell + d
			if _can_host_find(n) and not candidates.has(n):
				candidates.append(n)
		if _can_host_find(cell) and not candidates.has(cell):
			candidates.append(cell)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var count := mini(rng.randi_range(TRAP_FIND_MIN, TRAP_FIND_MAX), candidates.size())
	for i in count:
		_register_hidden_find(candidates[i], DiscoverableCards.KIND_ANIMAL_TRAP)


## Discarded fishing line on walkable ground next to rivers and ponds.
func _scatter_fishing_line_finds() -> void:
	var candidates: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			if not _can_host_find(cell):
				continue
			if not is_near_water(cell):
				continue
			candidates.append(cell)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var count := mini(
		rng.randi_range(FISHING_LINE_FIND_MIN, FISHING_LINE_FIND_MAX),
		candidates.size(),
	)
	for i in count:
		_register_hidden_find(candidates[i], DiscoverableCards.KIND_FISHING_LINE)


## Leftover food scraps on open grass / forest — teaches wildlife to expect handouts.
func _scatter_leftover_food_finds() -> void:
	var candidates: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			if prop_sprites.has(cell) or tree_cells.has(cell):
				continue
			if not _can_host_find(cell):
				continue
			var tile: int = tiles[y][x]
			if tile != TerrainGenerator.TILE_GRASS and tile != TerrainGenerator.TILE_FOREST:
				continue
			candidates.append(cell)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var count := mini(
		rng.randi_range(LEFTOVER_FOOD_FIND_MIN, LEFTOVER_FOOD_FIND_MAX),
		candidates.size(),
	)
	for i in count:
		_register_hidden_find(candidates[i], DiscoverableCards.KIND_LEFTOVER_FOOD)


## Ripe berry patches on open grass / forest — visible once fog reveals them.
func _scatter_berry_finds() -> void:
	var candidates: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			if prop_sprites.has(cell) or tree_cells.has(cell):
				continue
			if not _can_host_find(cell):
				continue
			var tile: int = tiles[y][x]
			if tile != TerrainGenerator.TILE_GRASS and tile != TerrainGenerator.TILE_FOREST:
				continue
			candidates.append(cell)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var count := mini(rng.randi_range(BERRY_FIND_MIN, BERRY_FIND_MAX), candidates.size())
	for i in count:
		_register_hidden_find(candidates[i], DiscoverableCards.KIND_BERRIES)


## Common plants on grass / forest — only a Botanist will notice them.
func _scatter_plant_finds() -> void:
	var candidates: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			if prop_sprites.has(cell) or tree_cells.has(cell):
				continue
			if not _can_host_find(cell):
				continue
			var tile: int = tiles[y][x]
			if tile != TerrainGenerator.TILE_GRASS and tile != TerrainGenerator.TILE_FOREST:
				continue
			candidates.append(cell)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var kinds: Array = DiscoverableCards.PLANT_KINDS
	var count := mini(rng.randi_range(PLANT_FIND_MIN, PLANT_FIND_MAX), candidates.size())
	for i in count:
		var kind: String = kinds[rng.randi() % kinds.size()]
		_register_hidden_find(candidates[i], kind)


## Bird species perched in trees — only an Ornithologist will notice them.
func _scatter_bird_tree_finds() -> void:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in tree_cells:
		if hidden_finds.has(cell) or barrier_cells.has(cell):
			continue
		candidates.append(cell)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var count := mini(rng.randi_range(BIRD_TREE_FIND_MIN, BIRD_TREE_FIND_MAX), candidates.size())
	for i in count:
		_register_hidden_find(candidates[i], DiscoverableCards.pick_bird_species(rng))


func _can_host_find(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
		return false
	if barrier_cells.has(cell) or hidden_finds.has(cell):
		return false
	var tile: int = tiles[cell.y][cell.x]
	return tile == TerrainGenerator.TILE_GRASS \
		or tile == TerrainGenerator.TILE_FOREST \
		or tile == TerrainGenerator.TILE_SAND \
		or TerrainGenerator.is_road(tile)


## Registers a hidden evidence card on a cell. Carcasses/traps stay invisible
## until inspected; forbidden-cut uses the log already on the cell.
func _register_hidden_find(cell: Vector2i, kind: String) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
		return
	if hidden_finds.has(cell) or barrier_cells.has(cell):
		return
	var detail := DiscoverableCards.pick_detail(kind, rng)
	var sprite: Sprite2D = null
	# Plant / bird-species finds have no map marker — role specialists notice them.
	if DiscoverableCards.PLANT_KINDS.has(kind) \
			or DiscoverableCards.BIRD_SPECIES_KINDS.has(kind):
		hidden_finds[cell] = {
			"kind": kind, "collected": false, "sprite": null, "detail": detail,
		}
		return
	match kind:
		DiscoverableCards.KIND_DEAD_BIRD:
			sprite = _make_find_sprite(cell, BIRD_TEXTURE, Vector2(0, -2), Color(0.55, 0.5, 0.5))
			sprite.hframes = 2
			sprite.frame = 1
			sprite.rotation_degrees = 90.0
			sprite.scale = Vector2(1.1, 1.1)
		DiscoverableCards.KIND_DEAD_BEAVER:
			sprite = _make_find_sprite(cell, BEAVER_TEXTURE, Vector2(0, -2), Color(0.5, 0.45, 0.45))
			sprite.rotation_degrees = 75.0
		DiscoverableCards.KIND_ANIMAL_TRAP:
			sprite = _make_find_sprite(cell, TRAP_TEXTURE, Vector2(0, -2), Color.WHITE)
		DiscoverableCards.KIND_BIRD_NEST_REMNANTS:
			sprite = _make_find_sprite(cell, BIRD_TEXTURE, Vector2(0, -2), Color(0.7, 0.55, 0.4))
			sprite.hframes = 2
			sprite.frame = 0
			sprite.scale = Vector2(0.7, 0.7)
		DiscoverableCards.KIND_BERRIES:
			var marker := _make_berry_marker(cell)
			hidden_finds[cell] = {
				"kind": kind, "collected": false, "sprite": marker, "detail": detail,
			}
			return
		DiscoverableCards.KIND_FORBIDDEN_CUT:
			if prop_sprites.has(cell):
				sprite = prop_sprites[cell]
			else:
				sprite = _make_find_sprite(cell, LOG_TEXTURE, Vector2(0, -4), Color.WHITE)
				sprite.visible = fog.is_discovered(cell)
				prop_sprites[cell] = sprite
			# Log stays fog-gated; the card itself is still hidden until inspect.
			hidden_finds[cell] = {
				"kind": kind, "collected": false, "sprite": sprite, "detail": detail,
			}
			return
		DiscoverableCards.KIND_DRIED_GROUND:
			# The dried tile is the visual; no extra sprite until inspected.
			hidden_finds[cell] = {
				"kind": kind, "collected": false, "sprite": null, "detail": detail,
			}
			return
		DiscoverableCards.KIND_FISHING_LINE:
			# Monofilament is nearly invisible on the bank until inspected.
			hidden_finds[cell] = {
				"kind": kind, "collected": false, "sprite": null, "detail": detail,
			}
			return
		DiscoverableCards.KIND_LEFTOVER_FOOD:
			# Scraps stay unnoticed until a camper inspects the ground.
			hidden_finds[cell] = {
				"kind": kind, "collected": false, "sprite": null, "detail": detail,
			}
			return
		_:
			return
	sprite.visible = false
	hidden_finds[cell] = {
		"kind": kind, "collected": false, "sprite": sprite, "detail": detail,
	}


func _make_find_sprite(cell: Vector2i, texture: Texture2D, offset: Vector2, modulate: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.offset = offset
	sprite.modulate = modulate
	sprite.position = cell_to_world(cell) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-2, 2))
	entities.add_child(sprite)
	return sprite


## Fog-gated berry bush marker — Sprite2D so it stays on the berry cell
## (Label-under-Node2D can drift onto neighbouring empty tiles).
func _make_berry_marker(cell: Vector2i) -> Node2D:
	var sprite := Sprite2D.new()
	sprite.texture = _berry_marker_texture()
	sprite.centered = true
	sprite.offset = Vector2(0, -6)
	sprite.position = cell_to_world(cell)
	sprite.visible = fog.is_discovered(cell)
	entities.add_child(sprite)
	return sprite


## Tiny procedural 🫐 stand-in shared by every berry patch marker.
func _berry_marker_texture() -> Texture2D:
	if _berry_texture != null:
		return _berry_texture
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var berry := Color("4a3a8a")
	var highlight := Color("7a6aba")
	for y in 10:
		for x in 10:
			var d0 := Vector2(x - 3.5, y - 4.5).length()
			var d1 := Vector2(x - 6.5, y - 5.0).length()
			var d2 := Vector2(x - 5.0, y - 3.0).length()
			if d0 <= 2.4 or d1 <= 2.2 or d2 <= 2.0:
				var c := berry
				if d0 <= 1.0 or d1 <= 0.9 or d2 <= 0.8:
					c = highlight
				img.set_pixel(x, y, c)
	# Stem.
	img.set_pixel(5, 1, Color("2f5a28"))
	img.set_pixel(4, 0, Color("3a6b35"))
	_berry_texture = ImageTexture.create_from_image(img)
	return _berry_texture


## Removes a berry patch from the map after it is picked into inventory.
func _consume_find(cell: Vector2i, remove_sprite: bool = false) -> void:
	if not hidden_finds.has(cell):
		return
	var find: Dictionary = hidden_finds[cell]
	find["collected"] = true
	if remove_sprite:
		var marker = find.get("sprite")
		if is_instance_valid(marker):
			marker.queue_free()
		find["sprite"] = null
	hidden_finds[cell] = find


## Forage a nearby berry patch into inventory.
## Returns {"item": Dictionary, "cell": Vector2i}, or {} if none.
func try_forage_berries(center: Vector2i) -> Dictionary:
	for y in range(center.y - INSPECT_FIND_RADIUS, center.y + INSPECT_FIND_RADIUS + 1):
		for x in range(center.x - INSPECT_FIND_RADIUS, center.x + INSPECT_FIND_RADIUS + 1):
			var cell := Vector2i(x, y)
			if not hidden_finds.has(cell):
				continue
			var find: Dictionary = hidden_finds[cell]
			if find.kind != DiscoverableCards.KIND_BERRIES or find.get("collected", false):
				continue
			var item := DiscoverableCards.make_item(
				DiscoverableCards.KIND_BERRIES, find.get("detail", "")
			)
			_consume_find(cell, true)
			return {"item": item, "cell": cell}
	return {}


## Called when a camper succeeds a find roll: reveals and returns any cards on
## or next to `center` that have not been collected yet — including wounded
## animals standing nearby and (for Ornithologists) flying birds that pass close.
## Role-gated finds (e.g. nest remnants, plants, bird species) are skipped
## unless `finder_roles` includes the required role; those stay hidden.
## Berry patches are forage-only and ignored here.
## Each result is {"item": Dictionary, "cell": Vector2i}.
func try_discover_nearby(center: Vector2i, finder_roles: Array = []) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for y in range(center.y - INSPECT_FIND_RADIUS, center.y + INSPECT_FIND_RADIUS + 1):
		for x in range(center.x - INSPECT_FIND_RADIUS, center.x + INSPECT_FIND_RADIUS + 1):
			var cell := Vector2i(x, y)
			if not hidden_finds.has(cell):
				continue
			var find: Dictionary = hidden_finds[cell]
			if find.get("collected", false):
				continue
			if find.kind == DiscoverableCards.KIND_BERRIES:
				continue
			var need_role := DiscoverableCards.required_role(find.kind)
			if not need_role.is_empty() and not finder_roles.has(need_role):
				continue
			_consume_find(cell, false)
			var sprite = find.get("sprite")
			if is_instance_valid(sprite):
				sprite.visible = true
				if find.kind == DiscoverableCards.KIND_FORBIDDEN_CUT:
					sprite.modulate = Color(1.0, 0.75, 0.55)
			var item := DiscoverableCards.make_item(find.kind, find.get("detail", ""))
			results.append({"item": item, "cell": cell})
			_show_find_toast(cell_to_world(cell), DiscoverableCards.localize(item).name)
	for animal in animals:
		if not is_instance_valid(animal) or not animal.has_wounded_card \
				or animal.wounded_card_collected:
			continue
		var offset: Vector2i = animal.cell - center
		if maxi(absi(offset.x), absi(offset.y)) > INSPECT_FIND_RADIUS:
			continue
		animal.reveal_wound()
		var detail := DiscoverableCards.pick_detail(DiscoverableCards.KIND_WOUNDED_ANIMAL, rng)
		var item := DiscoverableCards.make_item(DiscoverableCards.KIND_WOUNDED_ANIMAL, detail)
		results.append({"item": item, "cell": animal.cell})
		_show_find_toast(animal.position, DiscoverableCards.localize(item).name)
	if finder_roles.has("Ornithologist"):
		var center_pos := cell_to_world(center)
		for child in birds.get_children():
			var bird := child as Animal
			if bird == null or bird.bird_kind.is_empty() or bird.bird_kind_collected:
				continue
			if center_pos.distance_to(bird.position) > BIRD_SIGHTING_RADIUS:
				continue
			bird.mark_bird_identified()
			var bird_cell: Vector2i = layers[0].local_to_map(
				bird.position + Vector2(0, Animal.BIRD_FLY_HEIGHT)
			)
			bird_cell = bird_cell.clamp(Vector2i.ZERO, Vector2i(map_w - 1, map_h - 1))
			var detail := DiscoverableCards.pick_detail(bird.bird_kind, rng)
			var item := DiscoverableCards.make_item(bird.bird_kind, detail)
			results.append({"item": item, "cell": bird_cell})
			_show_find_toast(bird.position, DiscoverableCards.localize(item).name)
	if not results.is_empty():
		var cards: Array[Dictionary] = []
		for result in results:
			cards.append(result.item)
		collect_cards(cards)
	return results


## Adds evidence cards to the team collection and refreshes the corner badge.
func collect_cards(cards: Array[Dictionary]) -> void:
	for card in cards:
		collected_cards.append(card)
	cards_tray.refresh(collected_cards)


## Appends a journal event (msgid + camper + cell) and refreshes the log UI.
func log_journal(entry: Dictionary) -> void:
	if not entry.has("treated"):
		entry["treated"] = false
	if not entry.has("actions"):
		entry["actions"] = []
	journal_entries.append(entry)
	_refresh_journal()


## Logs a discovered card (or berry) as a journal event at `cell`.
## Skips if this kind was already logged for this exact tile.
func log_journal_find(card: Dictionary, finder: String, cell: Vector2i) -> void:
	var kind: String = str(card.get("id", ""))
	for entry in journal_entries:
		if entry.get("kind", "") == kind and entry.get("cell", Vector2i(-1, -1)) == cell:
			return
	var msgid := DiscoverableCards.journal_msgid(kind)
	if msgid.is_empty():
		msgid = "%s found evidence"
	log_journal({
		"icon": card.get("icon", "📝"),
		"msgid": msgid,
		"camper": finder,
		"cell": cell,
		"kind": kind,
		"treated": false,
		"actions": [],
	})


## Maps each role msgid to the first camper on the team who holds it.
func _team_role_holders() -> Dictionary:
	var holders := {}
	for camper in campers:
		if not is_instance_valid(camper):
			continue
		for role in camper.roles:
			if not holders.has(role):
				holders[role] = camper.display_name
	return holders


## How many untreated evidence entries the current team can actually respond to.
func _solvable_untreated_count() -> int:
	var holders := _team_role_holders()
	var n := 0
	for entry in journal_entries:
		if entry.get("treated", false):
			continue
		var kind: String = str(entry.get("kind", ""))
		if not DiscoverableCards.solve_actions_for(kind, holders).is_empty():
			n += 1
	return n


func _refresh_journal() -> void:
	journal_log.refresh(journal_entries, _solvable_untreated_count())


## Solve untreated evidence events: each unique kind gets role actions once;
## every matching entry is marked treated. Actions appear on the newest of each kind.
func solve_journal_events() -> Dictionary:
	var holders := _team_role_holders()
	var kind_actions := {}
	var starred_kinds := {}
	var treated_count := 0
	var action_count := 0
	# Newest first so the starred row sits near the top of the journal list.
	for i in range(journal_entries.size() - 1, -1, -1):
		var entry: Dictionary = journal_entries[i]
		if entry.get("treated", false):
			continue
		var kind: String = str(entry.get("kind", ""))
		if not DiscoverableCards.is_solvable(kind):
			continue
		if not kind_actions.has(kind):
			kind_actions[kind] = DiscoverableCards.solve_actions_for(kind, holders)
		var actions: Array = kind_actions[kind]
		if actions.is_empty():
			continue
		if not starred_kinds.has(kind):
			entry["actions"] = actions.duplicate(true)
			entry["starred"] = true
			starred_kinds[kind] = true
			action_count += actions.size()
		entry["treated"] = true
		treated_count += 1
	_refresh_journal()
	return {"treated": treated_count, "actions": action_count}


func _on_journal_solve_requested() -> void:
	var result := solve_journal_events()
	if result.treated <= 0:
		_show_find_toast(camera.position, tr("No untreated events the team can solve"))
	else:
		_show_find_toast(
			camera.position,
			tr("%d events treated · %d actions") % [result.treated, result.actions],
		)


## Brief floating label over a newly revealed find.
func show_find_toast(world_pos: Vector2, text: String) -> void:
	_show_find_toast(world_pos, text)


## Brief floating label over a newly revealed find.
func _show_find_toast(world_pos: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	label.position = world_pos - Vector2(48, 28)
	label.z_index = 20
	entities.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 18.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.4) \
		.set_delay(0.4)
	tween.tween_callback(label.queue_free)


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
		if rng.randf() < WOUNDED_ANIMAL_CHANCE:
			animal.mark_wounded()


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
		if not hidden_finds.has(cell):
			continue
		var find: Dictionary = hidden_finds[cell]
		if find.kind != DiscoverableCards.KIND_BERRIES or find.collected:
			continue
		var marker = find.get("sprite")
		if is_instance_valid(marker):
			marker.visible = true


func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
		return false
	if barrier_cells.has(cell):
		return false
	var tile: int = tiles[cell.y][cell.x]
	return tile == TerrainGenerator.TILE_SAND \
		or tile == TerrainGenerator.TILE_GRASS \
		or tile == TerrainGenerator.TILE_FOREST \
		or tile == TerrainGenerator.TILE_ROCK \
		or tile == TerrainGenerator.TILE_DRIED_GROUND \
		or TerrainGenerator.is_road(tile) \
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


## Cliff climb: orthogonal neighbour one level up/down that is walkable but
## not already ramp-connected (those use normal walking).
func can_cliff_climb(from: Vector2i, to: Vector2i) -> bool:
	if not is_walkable(from) or not is_walkable(to):
		return false
	var step := to - from
	if absi(step.x) + absi(step.y) != 1:
		return false
	if absi(level_at(from) - level_at(to)) != 1:
		return false
	return not _can_step(from, to)


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
