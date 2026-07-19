# Dev helper: runs a scene briefly and saves a screenshot.
#   godot4 --path . --script res://tools/screenshot_game.gd -- /path/out.png \
#       [res://scene.tscn] [debug] [zoom:2.5] [center:10,10]
extends SceneTree

var frame_count := 0
var out_path := "screenshot.png"
var scene_path := "res://scenes/game/game.tscn"
var zoom_override := 0.0
var center_cell := Vector2i(-1, -1)
var reveal_all := false
var scene: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	if args.size() > 1 and args[1].begins_with("res://"):
		scene_path = args[1]
	for a in args:
		if a == "debug":
			TerrainGenerator.use_debug_terrain = true
		elif a == "reveal":
			reveal_all = true
		elif a.begins_with("locale:"):
			TranslationServer.set_locale(a.substr(7))
		elif a.begins_with("zoom:"):
			zoom_override = float(a.substr(5))
		elif a.begins_with("center:"):
			var parts := a.substr(7).split(",")
			center_cell = Vector2i(int(parts[0]), int(parts[1]))
	process_frame.connect(_on_frame)
	call_deferred("_setup")


func _setup() -> void:
	scene = load(scene_path).instantiate()
	root.add_child(scene)


func _on_frame() -> void:
	frame_count += 1
	if frame_count == 10 and scene != null and scene.has_node("Camera"):
		if reveal_all and scene.has_node("Fog"):
			scene.get_node("Fog").reveal(Vector2i(scene.map_w / 2, scene.map_h / 2), 999)
		var camera: Camera2D = scene.get_node("Camera")
		if zoom_override > 0.0:
			camera.zoom = Vector2(zoom_override, zoom_override)
		if center_cell.x >= 0:
			camera.position = scene.cell_to_world(center_cell)
	if frame_count == 90:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out_path)
		print("Screenshot saved to ", out_path)
		quit()
