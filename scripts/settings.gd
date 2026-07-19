class_name UserSettings
extends Node
## Autoload: applies persisted user settings (language) at startup, before
## the first scene loads, and saves changes made from the splash screen.

const SETTINGS_PATH := "user://settings.cfg"


func _enter_tree() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		TranslationServer.set_locale(config.get_value("general", "locale", "en"))


static func save_locale(locale: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("general", "locale", locale)
	config.save(SETTINGS_PATH)
