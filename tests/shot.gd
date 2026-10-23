extends Node
## Opens the game in a real window, builds a small dungeon, and saves day and night screenshots
## to build/. Run with:  godot --path . res://tests/shot.tscn

const MainScene := preload("res://scenes/main.tscn")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var main := MainScene.instantiate()
	add_child(main)
	await _frames(3)
	main._choose("vampire")
	Game.gold = 400
	Game.hours = 6
	Game.build(7, "crypt")
	Game.recruit("spawn")
	Game.dig(6)
	Game.build(6, "barracks")
	Game.recruit("goblin")
	Game.dig(8)
	Game.build(8, "library" if Game.mk == "lich" else "torture")
	Game.sel = 7
	await _frames(30)
	_save("res://build/shot_day.png")
	Game.bosses = 1
	Game.hours = 6
	Game.build(2, "stairs")
	Game.dig(2 + Game.FLOOR_SLOTS + 5)
	Game.sel = 2 + Game.FLOOR_SLOTS
	main._show_floor(1)
	main.refresh()
	await _frames(30)
	_save("res://build/shot_floor2.png")
	main._show_floor(0)
	await main.start_night()
	await _frames(60)
	_save("res://build/shot_night.png")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)
