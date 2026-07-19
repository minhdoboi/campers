extends Control
## Top-right card badge showing how many evidence cards the team has found.
## Click toggles a list of collected cards.

@onready var badge: Button = %CardBadge
@onready var count_label: Label = %CardCount
@onready var popup: PanelContainer = %CardsPopup
@onready var title: Label = %CardsTitle
@onready var close_button: Button = %CardsCloseButton
@onready var list_box: VBoxContainer = %CardList


func _ready() -> void:
	badge.pressed.connect(_toggle_popup)
	close_button.pressed.connect(popup.hide)
	title.text = tr("Cards")
	refresh([])


func refresh(cards: Array) -> void:
	count_label.text = str(cards.size())
	badge.tooltip_text = tr("%d cards found") % cards.size()
	for child in list_box.get_children():
		child.queue_free()
	if cards.is_empty():
		var hint := Label.new()
		hint.text = tr("No cards yet — inspect the parcel")
		hint.add_theme_color_override("font_color", Color(0.85, 0.9, 0.82, 0.5))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(220, 0)
		list_box.add_child(hint)
	else:
		for card in cards:
			list_box.add_child(_make_card_row(card))
	if popup.visible and cards.is_empty():
		pass # keep open so the empty hint is readable


func _toggle_popup() -> void:
	popup.visible = not popup.visible


func _make_card_row(card: Dictionary) -> Control:
	var loc := DiscoverableCards.localize(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := Label.new()
	icon.text = loc.icon
	icon.add_theme_font_size_override("font_size", 22)
	row.add_child(icon)
	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 2)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = loc.name
	text_col.add_child(name_label)
	if not loc.detail.is_empty():
		var detail := Label.new()
		detail.text = loc.detail
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(240, 0)
		detail.add_theme_font_size_override("font_size", 11)
		detail.add_theme_color_override("font_color", Color(0.85, 0.9, 0.82, 0.65))
		text_col.add_child(detail)
	row.add_child(text_col)
	return row
