extends Node
## Opens the game in a real window, builds a small dungeon, and saves day and night screenshots
## to build/. Run with:  godot --path . res://tests/shot.tscn

const MainScene := preload("res://scenes/main.tscn")


func _ready() -> void:
	Game.no_save = true                   # this scene never writes the player's saves
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var main := MainScene.instantiate()
	add_child(main)
	await _frames(10)
	_save("res://build/shot_title.png")
	main.menus.open_catalog(main.menus.show_title)
	await _frames(10)
	_save("res://build/shot_catalog.png")
	var mons = Game.meta.get("mons", {}).duplicate(true)
	Game.meta.mons = {"lich": {"lvl": 6, "picks": {"2": 1, "4": 0, "6": 1}, "load": ["nova", "chain", "siphon"]}}
	main.menus.open_monsters(main.menus.show_title, "lich")
	await _frames(10)
	_save("res://build/shot_monsters.png")
	Game.meta.mons = mons
	main.menus.open_settings(main.menus.show_title)
	await _frames(10)
	_save("res://build/shot_settings.png")
	main.show_start()
	await _frames(10)
	_save("res://build/shot_start.png")
	Game.meta.rooms = Data.ROOMS.keys()
	await _frames(3)
	main._choose("vampire")
	Game.gold = 400
	Game.hours = 6
	Game.build(4, "crypt")
	Game.build(3, "barracks")
	Game.build(5, "library" if Game.mk == "lich" else "torture")
	Game.sel = 4
	await _frames(30)
	_save("res://build/shot_day.png")
	Game.sel = 1                          # the empty gate hall: the build list, by category
	main.refresh()
	await _frames(10)
	_save("res://build/shot_build.png")
	main.build_cat = "traps"
	main.refresh()
	await _frames(10)
	_save("res://build/shot_build_traps.png")
	main.build_cat = ""
	Game.sel_minion = null
	Game.toggle_arrange("furniture")
	for k in Game.obj:
		if Game.decor_movable(k) and Game.slot_of(k) == 4:
			Game.day_click(k)
			break
	await _frames(10)
	_save("res://build/shot_arrange.png")
	Game.clear_modes()
	main.menus.open_pause()
	await _frames(10)
	_save("res://build/shot_pause.png")
	main.menus.pause_ov.visible = false
	# the patron's gift after night 1, then the trader's stall
	main._show_pick({"kills": 3, "loot": 12, "stolen": 0, "lost": 0})
	await _frames(10)
	_save("res://build/shot_gift.png")
	main.pick_ov.visible = false
	for it in ["fang", "boots", "axe", "chain", "shortbow", "runeblade", "spiked", "heart", "fireball", "warding"]:
		Game.add_item(it)
	Game.equip(Game.minions[0], Game.stash.find("shortbow"))
	main.set_tab("armory")
	Game.trader = {}
	Game._roll_trader()
	Game.trader.stock[1].sold = true
	main.open_trader()
	await _frames(10)
	_save("res://build/shot_trader.png")
	main.close_trader()
	await _frames(10)
	_save("res://build/shot_day_trader.png")
	Game.trader = {}
	main.refresh()
	await _frames(5)
	main.set_tab("armory")
	await _frames(10)
	_save("res://build/shot_armory.png")
	main.set_tab("minions")
	await _frames(10)
	_save("res://build/shot_minions.png")
	main._pick_minion(Game.minions[0])
	await _frames(10)
	_save("res://build/shot_arm_minion.png")
	main.set_tab("rooms")
	await _frames(40)
	_save("res://build/shot_rooms_tab.png")
	main.mon_btn.pressed.emit()
	await _frames(20)
	_save("res://build/shot_monster_tab.png")
	main.menu_btn.pressed.emit()
	await _frames(20)
	_save("res://build/shot_menu_tab.png")
	main.set_tab("rooms")
	await main.start_night()
	await _frames(60)
	_save("res://build/shot_night.png")
	var hero = main.battle.alive("h")[0]
	main.board.look_at_tile(hero.pos)
	main._on_tile_clicked(hero.pos)
	await _frames(40)
	_save("res://build/shot_night_hero.png")
	await _tutorial_shots(main)
	await _duo_shots(main)
	get_tree().quit()


## The Dark Lord and his Squire: a night with the bond, and a day with a fallen partner.
func _duo_shots(main) -> void:
	main.battle.busy = false
	await main.quit_to_menu()
	main.show_start()
	await _frames(10)
	_save("res://build/shot_start_duo.png")
	main._choose("darklord", false)
	Game.gold = 400
	Game.hours = 6
	Game.build(4, "sanctum")
	Game.down = ["squire"]
	Game.souls = 9
	main.refresh()
	await _frames(20)
	_save("res://build/shot_duo_fallen.png")
	Game.down = []
	main.menus.open_stats(Callable())
	await _frames(10)
	_save("res://build/shot_stats.png")
	main.menus.go_back()
	await main.start_night()
	await _frames(40)
	_save("res://build/shot_duo_night.png")


## The tutorial: the title screen a new player sees, a day step and the first night step.
func _tutorial_shots(main) -> void:
	main.hud.inspect = null
	main.battle.busy = false
	await main.quit_to_menu()
	Game.meta.best = 0
	Game.meta.tutorial_done = 0
	main.menus.show_title()
	await _frames(10)
	_save("res://build/shot_title_new.png")
	main.start_tutorial()
	main.tutorial.advance()                 # past the welcome, to "Build a barracks"
	await _frames(30)
	_save("res://build/shot_tut_day.png")
	var t = main.tutorial
	while not t.step().has("allow") or not "night" in t.step().allow:
		if t.step().has("act"):
			t.step().act.call()
		elif t.step().has("next"):
			t.advance()
		await _frames(2)
	await main.start_night()
	await _frames(40)
	_save("res://build/shot_tut_night.png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)
