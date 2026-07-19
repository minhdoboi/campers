# Dev check: audits ramp placement rules over many generated parcels.
#   godot4 --headless --path . --script res://tools/test_ramps.gd
extends SceneTree

const TG = preload("res://scripts/terrain_generator.gd")
const W := 48
const H := 48


func _init() -> void:
	var violations := 0
	var ramp_count := 0
	for s in 100:
		var data: Dictionary = TG.generate(W, H, s * 7919 + 13)
		var tiles: Array = data.tiles
		var levels: Array = data.levels
		for y in H:
			for x in W:
				var t: int = tiles[y][x]
				if not TG.is_ramp(t):
					continue
				ramp_count += 1
				var d: Vector2i = TG.ramp_dir(t)
				var lvl: int = levels[y][x]
				var ux := x + d.x
				var uy := y + d.y
				var lx := x - d.x
				var ly := y - d.y
				if ux < 0 or uy < 0 or ux >= W or uy >= H or levels[uy][ux] != lvl + 1:
					print("seed %d: ramp (%d,%d) L%d dir %s upper level %s" % [s, x, y, lvl, d, str(levels[uy][ux]) if uy >= 0 and uy < H and ux >= 0 and ux < W else "OOB"])
					violations += 1
				if lx < 0 or ly < 0 or lx >= W or ly >= H or levels[ly][lx] != lvl:
					print("seed %d: ramp (%d,%d) L%d dir %s LOWER-SIDE level %s (expected %d)" % [s, x, y, lvl, d, str(levels[ly][lx]) if ly >= 0 and ly < H and lx >= 0 and lx < W else "OOB", lvl])
					violations += 1
				var perp := Vector2i(d.y, d.x)
				for side in [perp, -perp]:
					var sx: int = x + side.x
					var sy: int = y + side.y
					if sx < 0 or sy < 0 or sx >= W or sy >= H or levels[sy][sx] != lvl:
						print("seed %d: ramp (%d,%d) L%d dir %s side (%d,%d) not flat" % [s, x, y, lvl, d, sx, sy])
						violations += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < W and ny < H and TG.is_ramp(tiles[ny][nx]):
							print("seed %d: ramp (%d,%d) adjacent to ramp (%d,%d)" % [s, x, y, nx, ny])
							violations += 1
	print("ramps checked: %d, violations: %d" % [ramp_count, violations])
	quit()
