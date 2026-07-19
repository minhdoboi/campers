extends Control


func _ready() -> void:
	%EnglishButton.pressed.connect(_on_language_chosen.bind("en"))
	%FrenchButton.pressed.connect(_on_language_chosen.bind("fr"))
	_sync_language_buttons()
	%StartButton.grab_focus()


func _on_language_chosen(locale: String) -> void:
	TranslationServer.set_locale(locale)
	_sync_language_buttons()
	UserSettings.save_locale(locale)


func _sync_language_buttons() -> void:
	var french := TranslationServer.get_locale().begins_with("fr")
	%FrenchButton.set_pressed_no_signal(french)
	%EnglishButton.set_pressed_no_signal(not french)


func _on_start_button_pressed() -> void:
	TerrainGenerator.use_debug_terrain = false
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_debug_button_pressed() -> void:
	TerrainGenerator.use_debug_terrain = true
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
