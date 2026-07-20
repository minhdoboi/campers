extends PanelContainer
## Bottom panel: one row per camper, with their energy (blue) and morale
## (red) bars, and their action timeline next to their name (current
## action highlighted, each chip removable). The selected camper's chips have
## a brighter background. The menu button at the right of each name shows the
## camper's mode and, when pressed, switches their mode (roam, inspect) or
## queues specific tasks.

## Emitted when a camper's name is double-clicked; the game centers on them.
signal focus_requested(camper: Node2D)
## Emitted whenever the selected camper changes, so the game can show their
## portrait in the top-left corner.
signal selection_changed(camper: Node2D)

const MAX_CHIPS := 7
## Popup ids: modes at MODE_ID_BASE + Camper.Mode, tasks at TASK_ID_BASE + index.
const MODE_ID_BASE := 10
const TASK_ID_BASE := 100

var campers: Array = []
var selected_index := -1

var _button_group := ButtonGroup.new()
var _buttons: Array[Button] = []
var _mode_buttons: Array[MenuButton] = []
var _action_boxes: Array[HBoxContainer] = []
var _energy_bars: Array[ProgressBar] = []
var _morale_bars: Array[ProgressBar] = []
## Chip styles indexed by [selected][is_current_action].
var _chip_styles: Array = []

@onready var rows_box: VBoxContainer = %Rows


func _ready() -> void:
	_chip_styles = [
		[_make_chip_style(Color(1, 1, 1, 0.04)), _make_chip_style(Color(0.45, 0.62, 0.4, 0.25))],
		[_make_chip_style(Color(1, 1, 1, 0.14)), _make_chip_style(Color(0.45, 0.62, 0.4, 0.6))],
	]


func _make_chip_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8.0)
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func setup(new_campers: Array) -> void:
	campers = new_campers
	selected_index = -1
	_buttons.clear()
	_mode_buttons.clear()
	_action_boxes.clear()
	_energy_bars.clear()
	_morale_bars.clear()
	for child in rows_box.get_children():
		child.queue_free()
	for i in campers.size():
		var camper = campers[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		rows_box.add_child(row)
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_group = _button_group
		button.text = camper.display_name
		button.icon = camper.portrait
		button.custom_minimum_size = Vector2(150, 0)
		button.add_theme_constant_override("icon_max_width", 18)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", camper.modulate)
		button.add_theme_color_override("font_pressed_color", camper.modulate)
		button.add_theme_color_override("font_hover_color", camper.modulate.lightened(0.2))
		button.pressed.connect(_select.bind(i))
		button.gui_input.connect(_on_person_gui_input.bind(i))
		row.add_child(button)
		_buttons.append(button)
		row.add_child(_make_status_box())
		row.add_child(_make_mode_button(i))
		var actions_box := HBoxContainer.new()
		actions_box.add_theme_constant_override("separation", 8)
		actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(actions_box)
		_action_boxes.append(actions_box)
		camper.actions_changed.connect(_on_camper_actions_changed.bind(i))
		_refresh_row(i)
	if not campers.is_empty():
		_buttons[0].button_pressed = true
		_select(0)


## Stats change continuously without a signal, so the bars are polled every
## frame.
func _process(_delta: float) -> void:
	for i in mini(campers.size(), _energy_bars.size()):
		var camper := _camper_at(i)
		if camper == null:
			continue
		_energy_bars[i].value = camper.energy
		_morale_bars[i].value = camper.morale


## The energy (blue) and morale (red) bars for one camper.
func _make_status_box() -> VBoxContainer:
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 3)
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var energy_bar := _make_stat_bar(Color(0.35, 0.62, 1.0), tr("Energy"))
	bars.add_child(energy_bar)
	_energy_bars.append(energy_bar)
	var morale_bar := _make_stat_bar(Color(0.92, 0.3, 0.3), tr("Morale"))
	bars.add_child(morale_bar)
	_morale_bars.append(morale_bar)
	return bars


func _make_stat_bar(fill_color: Color, tip: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(64, 5)
	bar.tooltip_text = tip
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## The per-camper status button: shows the camper's current mode, and its menu
## switches the mode or queues tasks for that camper.
func _make_mode_button(index: int) -> MenuButton:
	var menu := MenuButton.new()
	menu.flat = false
	menu.focus_mode = Control.FOCUS_NONE
	menu.custom_minimum_size = Vector2(130, 0)
	menu.text = tr(Camper.MODE_NAMES[campers[index].mode])
	var popup := menu.get_popup()
	popup.add_separator(tr("Mode"))
	for m: int in Camper.MODE_NAMES:
		if m == Camper.Mode.AUTONOMOUS:
			continue # entered automatically when morale is low
		popup.add_radio_check_item(tr(Camper.MODE_NAMES[m]), MODE_ID_BASE + m)
	popup.add_separator(tr("Add action"))
	for i in Camper.TASKS.size():
		popup.add_item(tr(Camper.TASKS[i][0]), TASK_ID_BASE + i)
	popup.id_pressed.connect(_on_menu_id_pressed.bind(index))
	popup.about_to_popup.connect(_on_menu_about_to_popup.bind(index))
	_mode_buttons.append(menu)
	return menu


## Selects the given camper in the list, e.g. when clicked in the world.
func select_camper(camper: Node2D) -> void:
	var index := campers.find(camper)
	if index == -1:
		return
	_buttons[index].button_pressed = true
	_select(index)


func _camper_at(index: int) -> Camper:
	if index < 0 or index >= campers.size():
		return null
	var camper = campers[index]
	return camper if is_instance_valid(camper) else null


func _on_person_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_select(index)
		var camper = campers[index]
		if is_instance_valid(camper):
			focus_requested.emit(camper)


func _on_camper_actions_changed(index: int) -> void:
	var camper := _camper_at(index)
	if camper != null and index < _mode_buttons.size():
		_mode_buttons[index].text = tr(Camper.MODE_NAMES[camper.mode])
	_refresh_row(index)


func _on_menu_about_to_popup(index: int) -> void:
	if index < _buttons.size():
		_buttons[index].button_pressed = true
	_select(index)
	var camper := _camper_at(index)
	var popup := _mode_buttons[index].get_popup()
	for m: int in Camper.MODE_NAMES:
		if m == Camper.Mode.AUTONOMOUS:
			continue
		var idx := popup.get_item_index(MODE_ID_BASE + m)
		popup.set_item_checked(idx, camper != null and camper.mode == m)


func _on_menu_id_pressed(id: int, index: int) -> void:
	var camper := _camper_at(index)
	if camper == null:
		return
	if id >= TASK_ID_BASE:
		var task: Array = Camper.TASKS[id - TASK_ID_BASE]
		camper.add_task(task[0], task[1], task[2])
	elif id >= MODE_ID_BASE:
		camper.set_mode((id - MODE_ID_BASE) as Camper.Mode)
		_mode_buttons[index].text = tr(Camper.MODE_NAMES[camper.mode])


func _select(index: int) -> void:
	var previous := selected_index
	selected_index = index
	if previous != index:
		_refresh_row(previous)
	_refresh_row(index)
	var camper := _camper_at(index)
	if camper != null:
		selection_changed.emit(camper)


func _refresh_row(index: int) -> void:
	if index < 0 or index >= _action_boxes.size():
		return
	var box := _action_boxes[index]
	for child in box.get_children():
		child.queue_free()
	var camper := _camper_at(index)
	if camper == null:
		return
	var selected := index == selected_index
	if camper.actions.is_empty():
		var hint := Label.new()
		hint.text = tr("No actions — click the map to move") if selected \
				else tr("No actions")
		hint.add_theme_color_override("font_color",
				Color(0.85, 0.9, 0.82, 0.5 if selected else 0.25))
		box.add_child(hint)
		return
	for i in camper.actions.size():
		if i >= MAX_CHIPS:
			var more := Label.new()
			more.text = "…"
			box.add_child(more)
			break
		box.add_child(_make_chip(camper.actions[i], index, i, selected))


func _make_chip(action: Dictionary, camper_index: int, action_index: int,
		selected: bool) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel",
			_chip_styles[int(selected)][int(action_index == 0)])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	var label := Label.new()
	label.text = ("▶ " if action_index == 0 else "") + tr(action.label)
	if not selected:
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	row.add_child(label)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 10)
	close.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	close.pressed.connect(_on_remove_action.bind(camper_index, action_index))
	row.add_child(close)
	return chip


func _on_remove_action(camper_index: int, action_index: int) -> void:
	var camper := _camper_at(camper_index)
	if camper != null:
		camper.remove_action(action_index)
