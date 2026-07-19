class_name Weather
extends Node2D
## Drifting cloud shadows over the parcel, with optional rain. Weather type
## comes from TerrainGenerator; clear parcels leave this node idle.

## Soft multiply-style darkening for cloud patches.
const SHADOW_COLOR := Color(0.08, 0.1, 0.14, 1.0)
## Half-extents of each cell's shadow diamond (matches FogOfWar padding).
const HALF_W := 33.0
const HALF_H := 17.0
## World units the cloud field drifts per second.
const DRIFT_SPEED := Vector2(14.0, 6.0)

var game: Node2D
var weather_type: int = TerrainGenerator.WEATHER_CLEAR
var _noise: FastNoiseLite
var _scroll := Vector2.ZERO
var _rain: CPUParticles2D
var _atmosphere: CanvasModulate


func setup(game_node: Node2D, weather: int, seed_value: int) -> void:
	game = game_node
	weather_type = weather
	_scroll = Vector2.ZERO
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.045
	_noise.fractal_octaves = 3
	_ensure_atmosphere()
	_ensure_rain()
	var cloudy := weather_type != TerrainGenerator.WEATHER_CLEAR
	var rainy := weather_type == TerrainGenerator.WEATHER_RAINY
	visible = cloudy
	if rainy:
		_atmosphere.color = Color(0.78, 0.82, 0.9)
	elif cloudy:
		_atmosphere.color = Color(0.9, 0.92, 0.95)
	else:
		_atmosphere.color = Color.WHITE
	_atmosphere.visible = cloudy
	_rain.emitting = rainy
	_rain.visible = rainy
	queue_redraw()


func _process(delta: float) -> void:
	if weather_type == TerrainGenerator.WEATHER_CLEAR or game == null:
		return
	_scroll += DRIFT_SPEED * delta
	if _rain != null and _rain.emitting and game.camera != null:
		var cam: Camera2D = game.camera
		_rain.global_position = cam.global_position
		var half: Vector2 = get_viewport_rect().size / cam.zoom * 0.55
		_rain.emission_rect_extents = half
	queue_redraw()


func _draw() -> void:
	if game == null or weather_type == TerrainGenerator.WEATHER_CLEAR or _noise == null:
		return
	# Rainy parcels get denser, darker cloud cover.
	var threshold := 0.05 if weather_type == TerrainGenerator.WEATHER_RAINY else 0.18
	var max_alpha := 0.42 if weather_type == TerrainGenerator.WEATHER_RAINY else 0.32
	var scroll_x := _scroll.x * 0.03
	var scroll_y := _scroll.y * 0.03
	for y in game.map_h:
		for x in game.map_w:
			var n := _noise.get_noise_2d(float(x) + scroll_x, float(y) + scroll_y)
			if n < threshold:
				continue
			var t := (n - threshold) / (1.0 - threshold)
			var alpha := t * t * max_alpha
			var center: Vector2 = game.cell_to_world(Vector2i(x, y))
			var color := Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, alpha)
			draw_polygon(PackedVector2Array([
				center + Vector2(-HALF_W, 0),
				center + Vector2(0, -HALF_H),
				center + Vector2(HALF_W, 0),
				center + Vector2(0, HALF_H),
			]), [color])


func _ensure_atmosphere() -> void:
	if _atmosphere != null:
		return
	_atmosphere = CanvasModulate.new()
	_atmosphere.name = "Atmosphere"
	add_child(_atmosphere)


func _ensure_rain() -> void:
	if _rain != null:
		return
	_rain = CPUParticles2D.new()
	_rain.name = "Rain"
	_rain.amount = 500
	_rain.lifetime = 0.55
	_rain.preprocess = 0.5
	_rain.explosiveness = 0.0
	_rain.randomness = 0.35
	_rain.lifetime_randomness = 0.25
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(700, 420)
	_rain.direction = Vector2(0.2, 1.0)
	_rain.spread = 6.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 280.0
	_rain.initial_velocity_max = 480.0
	_rain.scale_amount_min = 0.6
	_rain.scale_amount_max = 1.3
	_rain.texture = _make_rain_texture()
	_rain.color = Color(0.75, 0.8, 0.9, 0.55)
	add_child(_rain)


func _make_rain_texture() -> Texture2D:
	var img := Image.create(2, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		var a := 0.15 + 0.85 * (1.0 - float(y) / 9.0)
		img.set_pixel(0, y, Color(1, 1, 1, a))
		img.set_pixel(1, y, Color(1, 1, 1, a * 0.45))
	return ImageTexture.create_from_image(img)
