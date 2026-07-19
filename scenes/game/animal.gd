class_name Animal
extends Sprite2D
## Ambient wildlife. Deer wander grass and forest, beavers waddle along the
## river banks, birds fly freely above the parcel flapping between random
## points. All of them hide while the cell under them is still fogged.

enum Species { DEER, BEAVER, BIRD }

const DEER_TEXTURE := preload("res://assets/sprites/deer.png")
const BEAVER_TEXTURE := preload("res://assets/sprites/beaver.png")
const BIRD_TEXTURE := preload("res://assets/sprites/bird.png")

## Per-species tuning: walk speed, idle pause range, wander radius.
const SPECS := {
	Species.DEER: {"speed": 26.0, "idle_min": 1.0, "idle_max": 4.0, "radius": 6},
	Species.BEAVER: {"speed": 13.0, "idle_min": 1.5, "idle_max": 5.0, "radius": 4},
	Species.BIRD: {"speed": 55.0, "idle_min": 0.0, "idle_max": 0.0, "radius": 0},
}

const BIRD_FLY_HEIGHT := 26.0
const BIRD_FLAP_PERIOD := 0.22

var game: Node2D
var species: Species = Species.DEER
var cell: Vector2i

var _path: Array = []
var _idle := 0.0
var _fly_target := Vector2.ZERO
var _flap := 0.0


func setup(game_node: Node2D, start_cell: Vector2i, animal_species: Species) -> void:
	game = game_node
	species = animal_species
	cell = start_cell
	match species:
		Species.DEER:
			texture = DEER_TEXTURE
			offset = Vector2(0, -8)
			position = game.cell_to_world(cell)
		Species.BEAVER:
			texture = BEAVER_TEXTURE
			offset = Vector2(0, -4)
			position = game.cell_to_world(cell)
		Species.BIRD:
			texture = BIRD_TEXTURE
			hframes = 2
			position = game.cell_to_world(cell) + Vector2(0, -BIRD_FLY_HEIGHT)
			_pick_fly_target()


func _process(delta: float) -> void:
	if game == null:
		return
	_update_visibility()
	if game.paused:
		return
	if species == Species.BIRD:
		_process_bird(delta)
	else:
		_process_ground(delta)


func _update_visibility() -> void:
	if species != Species.BIRD:
		visible = game.fog.is_discovered(cell)
		return
	# world_to_cell returns (-1, -1) for points on cliff skirts, which made
	# birds blink out whenever their flight path crossed a level edge. An
	# approximate base-layer lookup (ignoring elevation) never fails, and a
	# cell or two of error is imperceptible for a fog check.
	var ground := position + Vector2(0, BIRD_FLY_HEIGHT)
	var approx: Vector2i = game.layers[0].local_to_map(ground)
	approx = approx.clamp(Vector2i.ZERO, Vector2i(game.map_w - 1, game.map_h - 1))
	visible = game.fog.is_discovered(approx)


func _process_ground(delta: float) -> void:
	if _idle > 0.0:
		_idle -= delta
		return
	if _path.is_empty():
		_choose_destination()
		if _path.is_empty():
			_rest()
			return
	var target: Vector2 = game.cell_to_world(_path[0])
	if absf(target.x - position.x) > 0.5:
		flip_h = target.x < position.x
	position = position.move_toward(target, SPECS[species].speed * delta)
	if position.distance_to(target) < 0.5:
		cell = _path.pop_front()
		if _path.is_empty():
			_rest()


func _process_bird(delta: float) -> void:
	_flap += delta
	frame = 0 if fmod(_flap, BIRD_FLAP_PERIOD) < BIRD_FLAP_PERIOD * 0.5 else 1
	position = position.move_toward(_fly_target, SPECS[species].speed * delta)
	if position.distance_to(_fly_target) < 2.0:
		_pick_fly_target()


func _rest() -> void:
	_idle = randf_range(SPECS[species].idle_min, SPECS[species].idle_max)


func _choose_destination() -> void:
	for attempt in 8:
		var candidate: Vector2i = game.random_cell_near(cell, SPECS[species].radius)
		if candidate == cell or not _cell_suits(candidate):
			continue
		var path: Array = game.find_path(cell, candidate)
		if not path.is_empty():
			_path = path
			return


func _cell_suits(target: Vector2i) -> bool:
	var tile: int = game.tiles[target.y][target.x]
	match species:
		Species.DEER:
			return tile == TerrainGenerator.TILE_GRASS or tile == TerrainGenerator.TILE_FOREST
		Species.BEAVER:
			return game.is_near_water(target)
		_:
			return true


func _pick_fly_target() -> void:
	var target_cell := Vector2i(randi_range(0, game.map_w - 1), randi_range(0, game.map_h - 1))
	_fly_target = game.cell_to_world(target_cell) + Vector2(0, -BIRD_FLY_HEIGHT)
	flip_h = _fly_target.x < position.x
