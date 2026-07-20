extends Control
## Top-right journal badge. Click toggles a scrollable log of events; each
## entry stores a map cell and centers the camera there when clicked.
## Solve marks untreated evidence with role actions (star + list on the right).

signal focus_requested(cell: Vector2i)
signal solve_requested

@onready var badge: Button = %JournalBadge
@onready var count_label: Label = %JournalCount
@onready var popup: PanelContainer = %JournalPopup
@onready var title: Label = %JournalTitle
@onready var close_button: Button = %JournalCloseButton
@onready var list_box: VBoxContainer = %JournalList
@onready var solve_button: Button = %JournalSolveButton


func _ready() -> void:
	badge.pressed.connect(_toggle_popup)
	close_button.pressed.connect(popup.hide)
	solve_button.pressed.connect(_on_solve_pressed)
	title.text = tr("Journal")
	solve_button.text = tr("Solve")
	refresh([])


func refresh(entries: Array, solvable_count: int = -1) -> void:
	count_label.text = str(entries.size())
	badge.tooltip_text = tr("%d journal entries") % entries.size()
	for child in list_box.get_children():
		child.queue_free()
	var untreated := solvable_count if solvable_count >= 0 else _count_untreated(entries)
	solve_button.disabled = untreated <= 0
	solve_button.tooltip_text = (
		tr("%d untreated events") % untreated if untreated > 0
		else tr("No untreated events")
	)
	if entries.is_empty():
		var hint := Label.new()
		hint.text = tr("No journal entries yet")
		hint.add_theme_color_override("font_color", Color(0.85, 0.9, 0.82, 0.5))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(220, 0)
		list_box.add_child(hint)
	else:
		# Newest first.
		for i in range(entries.size() - 1, -1, -1):
			list_box.add_child(_make_entry_row(entries[i]))


func _count_untreated(entries: Array) -> int:
	var n := 0
	for entry in entries:
		if entry.get("treated", false):
			continue
		var kind: String = str(entry.get("kind", ""))
		if DiscoverableCards.is_solvable(kind):
			n += 1
	return n


func _toggle_popup() -> void:
	popup.visible = not popup.visible


func _on_solve_pressed() -> void:
	solve_requested.emit()


func _make_entry_row(entry: Dictionary) -> Control:
	var cell: Vector2i = entry.cell
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var left := Button.new()
	left.focus_mode = Control.FOCUS_NONE
	left.alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(200, 0)
	var star := "⭐ " if entry.get("starred", false) else ""
	if entry.get("treated", false) and not entry.get("starred", false):
		star = "✓ "
	left.text = "%s%s  %s\n(%d, %d)" % [
		star,
		str(entry.get("icon", "📝")),
		_entry_text(entry),
		cell.x,
		cell.y,
	]
	if entry.get("treated", false):
		left.modulate = Color(0.85, 0.95, 0.8, 0.9)
	left.tooltip_text = tr("Click to center on location")
	left.pressed.connect(_on_entry_pressed.bind(cell))
	row.add_child(left)

	var actions: Array = entry.get("actions", [])
	if not actions.is_empty():
		var actions_col := VBoxContainer.new()
		actions_col.add_theme_constant_override("separation", 2)
		actions_col.custom_minimum_size = Vector2(160, 0)
		actions_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for action in actions:
			var label := Label.new()
			label.text = _action_text(action)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size = Vector2(150, 0)
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 0.95))
			actions_col.add_child(label)
		row.add_child(actions_col)

	return row


func _entry_text(entry: Dictionary) -> String:
	var msgid: String = str(entry.get("msgid", entry.get("text", "")))
	var who: String = str(entry.get("camper", ""))
	if msgid.find("%s") >= 0 and not who.is_empty():
		return tr(msgid) % who
	return tr(msgid)


func _action_text(action: Dictionary) -> String:
	var msgid: String = str(action.get("msgid", ""))
	var who: String = str(action.get("camper", ""))
	if msgid.find("%s") >= 0 and not who.is_empty():
		return tr(msgid) % who
	return tr(msgid)


func _on_entry_pressed(cell: Vector2i) -> void:
	focus_requested.emit(cell)
