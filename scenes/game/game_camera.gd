extends Camera2D
## Pan with WASD/arrow keys, left- or middle-mouse drag, zoom with the mouse
## wheel. A left click that ends without dragging is forwarded via `clicked`
## so the game can select whatever is under the cursor.

signal clicked(world_position: Vector2)
signal shift_clicked(world_position: Vector2)

const PAN_SPEED := 500.0
const ZOOM_STEP := 1.1
const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0
## Screen-space movement past which a left-button hold counts as a drag
## rather than a click.
const DRAG_THRESHOLD := 6.0

var _left_dragging := false
var _drag_moved := false
var _press_screen_pos := Vector2.ZERO


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED * delta / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(ZOOM_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(1.0 / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_left_dragging = true
				_drag_moved = false
				_press_screen_pos = event.position
			elif _left_dragging:
				_left_dragging = false
				if not _drag_moved:
					if event.shift_pressed:
						shift_clicked.emit(get_global_mouse_position())
					else:
						clicked.emit(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			position -= event.relative / zoom.x
		elif _left_dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not _drag_moved and event.position.distance_to(_press_screen_pos) > DRAG_THRESHOLD:
				_drag_moved = true
			if _drag_moved:
				position -= event.relative / zoom.x


func _apply_zoom(factor: float) -> void:
	var z: float = clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
