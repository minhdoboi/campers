extends PanelContainer
## Center-screen popup listing a camper's carried tools, opened from the
## backpack button on their HUD row.

@onready var title: Label = %Title
@onready var items_box: VBoxContainer = %Items
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(hide)


func show_camper(camper: Camper) -> void:
	title.text = tr("%s — inventory") % camper.display_name
	title.add_theme_color_override("font_color", camper.modulate)
	for child in items_box.get_children():
		child.queue_free()
	if camper.inventory.is_empty():
		var hint := Label.new()
		hint.text = "Nothing carried"
		hint.add_theme_color_override("font_color", Color(0.85, 0.9, 0.82, 0.5))
		items_box.add_child(hint)
	else:
		for item in camper.inventory:
			items_box.add_child(_make_item_row(item))
	show()


func _make_item_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := Label.new()
	icon.text = item.icon
	icon.add_theme_font_size_override("font_size", 20)
	row.add_child(icon)
	var label := Label.new()
	label.text = item.name
	row.add_child(label)
	return row
