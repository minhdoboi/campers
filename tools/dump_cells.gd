# Dev check: prints tile/level data and painted tilemap cells around a cell.
#   godot4 --headless --path . --script res://tools/dump_cells.gd
extends SceneTree

var frame_count := 0
var scene: Node


func _init() -> void:
	TerrainGenerator.use_debug_terrain = true
	process_frame.connect(_on_frame)
	call_deferred("_setup")


func _setup() -> void:
	scene = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(scene)


func _on_frame() -> void:
	frame_count += 1
	if frame_count < 5:
		return
	var layers: Array = scene.layers
	for y in range(8, 13):
		for x in range(7, 12):
			var cell := Vector2i(x, y)
			var tile: int = scene.tiles[y][x]
			var lvl: int = scene.levels[y][x]
			var painted := []
			for li in 3:
				var atlas: Vector2i = layers[li].get_cell_atlas_coords(cell)
				if atlas != Vector2i(-1, -1):
					painted.append("L%d=%s" % [li, atlas])
			print("cell(%d,%d) tile=%d lvl=%d painted:%s world=%s" % [x, y, tile, lvl, ",".join(PackedStringArray(painted)), scene.cell_to_world(cell)])
	for li in 3:
		for child in layers[li].get_children():
			print("layer%d child at %s offset=%s" % [li, child.position, child.offset])
	quit()
