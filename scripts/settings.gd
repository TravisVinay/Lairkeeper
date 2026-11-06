extends Node
## Player settings, saved to user://settings.cfg and applied at startup. Autoloaded as `Settings`.

signal changed

const PATH := "user://settings.cfg"
const UI_SCALES := [[0.85, "Small"], [1.0, "Normal"], [1.15, "Large"], [1.3, "Huge"]]
const SPEEDS := [[0.75, "Slow"], [1.0, "Normal"], [1.6, "Fast"], [2.5, "Very fast"]]

var fullscreen := false
var ui_scale := 1.0
## Multiplies how fast fight animations play. Battle.wait() divides by it.
var battle_speed := 1.0


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		fullscreen = cf.get_value("display", "fullscreen", false)
		ui_scale = cf.get_value("display", "ui_scale", 1.0)
		battle_speed = cf.get_value("game", "battle_speed", 1.0)
	apply()


func save() -> void:
	if Game.fast or Game.no_save:
		return
	var cf := ConfigFile.new()
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("display", "ui_scale", ui_scale)
	cf.set_value("game", "battle_speed", battle_speed)
	cf.save(PATH)


func apply() -> void:
	if can_fullscreen():
		var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		if fullscreen != full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().root.content_scale_factor = ui_scale
	changed.emit()


## Change one setting, apply it and save.
func set_value(key: String, value) -> void:
	set(key, value)
	apply()
	save()


## Phones and browsers own the window, so fullscreen and quitting are left to them.
func can_fullscreen() -> bool:
	return not (OS.has_feature("mobile") or OS.has_feature("web")) and DisplayServer.get_name() != "headless"

func can_quit() -> bool:
	return not (OS.has_feature("ios") or OS.has_feature("web"))
