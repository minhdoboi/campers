class_name FogOfWar
extends Node2D
## Hides the parcel until campers walk near: undiscovered cells are covered
## by opaque fog prisms (the tile-top diamond extended downward over the
## cliff skirt). Cells stay discovered once revealed.

signal cells_revealed(cells: Array[Vector2i])

const FOG_COLOR := Color(0.05, 0.06, 0.09)
## Half-extents of the tile-top diamond, padded 1px to avoid hairline seams
## between adjacent fog cells.
const HALF_W := 33.0
const HALF_H := 17.0
## How far below the diamond the fog extends, covering the cliff skirts of
## raised cells so no gap shows above a lower fogged neighbour.
const SKIRT_DEPTH := 48.0

var game: Node2D
var _discovered: Array = [] # Array[PackedByteArray], indexed [y][x]


func setup(game_node: Node2D) -> void:
	game = game_node
	_discovered.clear()
	for y in game.map_h:
		var row := PackedByteArray()
		row.resize(game.map_w)
		_discovered.append(row)
	queue_redraw()


func is_discovered(cell: Vector2i) -> bool:
	if _discovered.is_empty():
		return true
	if cell.x < 0 or cell.y < 0 or cell.x >= game.map_w or cell.y >= game.map_h:
		return false
	return _discovered[cell.y][cell.x] == 1


## Marks every cell within `radius` (Euclidean) of `center` as discovered.
func reveal(center: Vector2i, radius: int) -> void:
	if _discovered.is_empty():
		return
	var newly: Array[Vector2i] = []
	for y in range(maxi(center.y - radius, 0), mini(center.y + radius + 1, game.map_h)):
		for x in range(maxi(center.x - radius, 0), mini(center.x + radius + 1, game.map_w)):
			if _discovered[y][x] == 1:
				continue
			var offset := Vector2i(x, y) - center
			if offset.length_squared() <= radius * radius:
				_discovered[y][x] = 1
				newly.append(Vector2i(x, y))
	if not newly.is_empty():
		cells_revealed.emit(newly)
		queue_redraw()


func _draw() -> void:
	if game == null or _discovered.is_empty():
		return
	for y in game.map_h:
		for x in game.map_w:
			if _discovered[y][x] == 1:
				continue
			var center: Vector2 = game.cell_to_world(Vector2i(x, y))
			draw_polygon(PackedVector2Array([
				center + Vector2(-HALF_W, 0),
				center + Vector2(0, -HALF_H),
				center + Vector2(HALF_W, 0),
				center + Vector2(HALF_W, SKIRT_DEPTH),
				center + Vector2(0, SKIRT_DEPTH + HALF_H),
				center + Vector2(-HALF_W, SKIRT_DEPTH),
			]), [FOG_COLOR])
