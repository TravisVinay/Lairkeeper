extends Node
## Headless smoke test. Builds the real UI, opens a night, checks a three-floor dungeon, then
## plays scripted runs with every monster and prints how far each got. Run with:
##   godot --headless --path . res://tests/sim.tscn

const MainScene := preload("res://scenes/main.tscn")

var _done := false
var _won := false


func _ready() -> void:
	Game.fast = true                       # no animation waits, and never write the real save
	Game.meta = {"souls": 0, "hoard": 0, "best": 0, "rooms": []}
	_unlock_test()
	_save_test()
	_mods_test()
	await _rooms_test()
	_duo_test()
	Game.meta.rooms = Data.ROOMS.keys()   # the scripted runs may use every room
	await _ui_smoke()
	for i in 5:
		await _tutorial_test()
	await _floor_test()
	for k in Data.MONSTERS:
		for i in 2:
			await _play(k)
	_check_layouts()
	print("SIM DONE")
	get_tree().quit()


func _ui_smoke() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	for i in 3:
		await get_tree().process_frame
	main._choose("necro")
	await get_tree().process_frame
	Game.sel = 7
	Game.build(7, "graveyard")
	Game.recruit("skeleton")
	main.refresh()
	await get_tree().process_frame
	await main.start_night()
	for i in 5:
		await get_tree().process_frame
	var pop_self: bool = main.hud.popup.visible
	var hero = main.battle.alive("h")[0]
	main._on_tile_clicked(hero.pos)
	await get_tree().process_frame
	var pop_hero: bool = main.hud.popup.visible and main.hud.inspect == hero
	print("UI smoke: board %s, units %d, side panel hidden %s, pop-up on monster %s, pop-up on hero %s" % [
		main.board.size, main.battle.units.size(), not main.side.visible, pop_self, pop_hero])
	main.queue_free()
	await get_tree().process_frame


## Plays the tutorial through the real UI: does each day step's action, lets the sim's player
## fight each night, picks boons, and checks the tutorial ends after night 5 with a normal run.
func _tutorial_test() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.start_tutorial()
	var tut = main.tutorial
	var errors := []
	Game.gold = 999
	if Game.allowed("dig:6") or Game.allowed("night"):
		errors.append("the welcome step allowed off-script actions")
	Game.dig(6)
	if Game.slots[6].state != "rock":
		errors.append("an off-script dig went through")
	var nights := 0
	var lost := 0
	var guard := 0
	while tut.active() and guard < 400:
		guard += 1
		var st: Dictionary = tut.step()
		var at: int = Game.tut
		if st.has("next"):
			tut.advance()
		elif st.get("night", false):
			if main.pick_ov.visible:
				await main._pick(Game.boon_choices()[0])
			elif main.battle != null and not main.battle.over:
				var b: Battle = main.battle
				b.finished.connect(_on_finished)
				_done = false
				var rounds := 0
				var used := {}
				while not _done and rounds < 80:
					rounds += 1
					await _player_turn(b, rounds, used)
					if _done:
						break
					await b.enemy_turn()
				if not _won:
					lost = Game.day
					break
				nights += 1
		elif st.has("act"):
			st.act.call()
		elif "night" in st.get("allow", []) or "*" in st.get("allow", []):
			if "*" in st.get("allow", []):
				_spend_free_day()
			await main.start_night()
		for f in 3:
			await get_tree().process_frame
		if Game.tut == at and not st.get("night", false):
			errors.append("step '%s' did not complete" % st.title)
			break
	var finished: bool = not tut.active() and Game.day == 6 and Game.gate.is_valid() == false
	if not finished and lost == 0 and errors.is_empty():
		errors.append("stopped at '%s' on day %d" % [tut.step().get("title", "?"), Game.day])
	var verdict := "ok" if finished and errors.is_empty() else ("FAIL " + "; ".join(errors) if errors.size() > 0 else "the sim player lost night %d" % lost)
	print("TUTORIAL: %s (won %d of 5 nights)" % [verdict, nights])
	Game.gate = Callable()
	main.queue_free()
	await get_tree().process_frame


## What a sensible player does with a free tutorial day: fill the minion rooms, then lay spikes.
func _spend_free_day() -> void:
	for k in ["spawn", "goblin"]:
		while Game.count_of(k) < Game.cap_of(k) and Game.gold >= Data.UNITS[k].cost:
			Game.recruit(k)
	Game.trap_mode = "spikes"
	for p in [Vector2i(11, 1), Vector2i(13, 1), Vector2i(11, 3), Vector2i(13, 3), Vector2i(12, 4)]:
		if Game.gold >= Game.trap_cost("spikes") and Game.traps.size() < Game.trap_cap():
			Game.place_trap(p)
	Game.trap_mode = ""


## Builds three floors, puts the lair on the bottom one, and checks that heroes walk down to it.
func _floor_test() -> void:
	Game.new_run("vampire")
	Game.gold = 2000
	Game.hours = 99
	Game.bosses = 0
	var blocked := Game.stairs_block(7) != ""
	Game.bosses = 2
	Game.build(7, "stairs")                       # floor 1 -> floor 2, arrives in slot 27
	var arrive2 := 7 + Game.FLOOR_SLOTS
	Game.dig(arrive2 + 1)
	Game.build(arrive2 + 1, "stairs")             # floor 2 -> floor 3, arrives in slot 48
	var arrive3 := arrive2 + 1 + Game.FLOOR_SLOTS
	Game.move_lair(arrive3)
	Game.upgrade(7)
	var reach := Game.field([Game.entrance]).has(Game.monster_start())
	var errors := []
	if not blocked: errors.append("stairs were buildable before any boss night")
	if Game.floors != 3: errors.append("expected 3 floors, got %d" % Game.floors)
	if Game.links.size() != 4: errors.append("expected 4 stair links, got %d" % Game.links.size())
	if Game.floor_of(Game.monster_start()) != 2: errors.append("lair is not on floor 3")
	if not reach: errors.append("entrance cannot reach the lair")
	if Game.stairs_block(arrive2) == "": errors.append("a second staircase on floor 2 was allowed")
	var b := Battle.new()
	add_child(b)
	b.finished.connect(_on_finished)
	_done = false
	b.start()
	var deepest := 0
	var rounds := 0
	while not _done and rounds < 60:
		rounds += 1
		await b.enemy_turn()
		for h in b.alive("h"):
			deepest = maxi(deepest, Game.floor_of(h.pos))
	if deepest < 2: errors.append("heroes never reached floor 3 (deepest %d)" % (deepest + 1))
	print("FLOORS: %s (heroes reached floor %d in %d rounds)" % ["ok" if errors.is_empty() else "FAIL " + "; ".join(errors), deepest + 1, rounds])
	b.queue_free()


## The Dark Lord and his Squire: one falling doesn't end the night, both does, and a fallen
## partner can be bought back at dawn for souls equal to the night number.
func _duo_test() -> void:
	var errors := []
	Game.new_run("darklord")
	var b := Battle.new()
	add_child(b)
	b.start()
	if b.squire == null or b.squire.hp != 24 or b.squire.pos != Game.squire_start(): errors.append("no Squire at the start")
	if not b.bonded(): errors.append("not bonded at the start")
	if b.atk_of(b.squire) != 7: errors.append("bonded Squire hits for %d" % b.atk_of(b.squire))
	b.hurt(b.mon, 99, null, true)
	if b.check_end(): errors.append("the night ended when only the Dark Lord fell")
	if b.lead() != b.squire: errors.append("the Squire did not take the lead")
	for h in b.alive("h"):
		h.hp = 0
	b.queue.clear()
	b.over = false
	b.resolve_win()
	if Game.down != ["lord"]: errors.append("fallen list is %s" % [Game.down])
	Game.day = 3
	Game.souls = 2
	Game.buy_back("lord")
	if Game.down.size() != 1: errors.append("bought back without enough souls")
	Game.souls = 5
	Game.buy_back("lord")
	if Game.down.size() != 0 or Game.souls != 2 or Game.mhp != Game.mmax: errors.append("buy-back: down %s, %d souls left" % [Game.down, Game.souls])
	b.queue_free()
	var b2 := Battle.new()
	add_child(b2)
	b2.start()
	b2.hurt(b2.mon, 99, null, true)
	b2.hurt(b2.squire, 99, null, true)
	if not b2.check_end(): errors.append("the night went on with both fallen")
	b2.queue_free()
	print("DUO: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))


## Checks the rule of each room added in the second rooms batch.
func _rooms_test() -> void:
	var errors := []
	var rooms: Array = Game.meta.rooms
	Game.meta.rooms = Data.ROOMS.keys()
	Game.new_run("vampire")
	Game.gold = 999
	Game.hours = 99
	for si in [6, 8, 11, 13, 10]:
		Game.dig(si)
	Game.build(7, "maze")
	Game.build(6, "barracks")
	Game.build(8, "stitching")
	Game.build(11, "ogreden")
	Game.build(13, "scrying")
	Game.recruit("ogre")
	if Game.count_of("ogre") != 1: errors.append("Ogre Den: no ogre")
	# Stitching Room: a goblin lost last night comes back for half price
	Game.fallen = ["goblin"]
	var g0 := Game.gold
	var want_next: Array = Game.future[0]
	Game.dawn({})
	if Game.count_of("goblin") != 1 or g0 + 10 - Game.gold != 7: errors.append("Stitching Room: %d goblins, paid %d" % [Game.count_of("goblin"), g0 + 10 - Game.gold])
	# Scrying Pool: tomorrow's party is the one it showed, and two more nights are lined up
	if Game.party != want_next or Game.future.size() != 2: errors.append("Scrying Pool: party %s, %d ahead" % [Game.party, Game.future.size()])
	# Maze of Bones: a hero walking in from the gate hall stops on the first maze tile
	var b := Battle.new()
	add_child(b)
	b.mon = b.mk_unit("p", "monster", Game.monster_start())
	var h = b.mk_unit("h", "peasant", Vector2i(12, 4))
	await b.walk(h, [Vector2i(12, 5), Vector2i(12, 6), Vector2i(12, 7)])
	if h.pos != Vector2i(12, 5): errors.append("Maze of Bones: hero walked on to %s" % h.pos)
	# Shrine of Desecration: a paladin inside loses its holy bonus against a vampire
	Game.build(10, "shrine")
	var pal = b.mk_unit("h", "paladin", Vector2i(2, 12))
	var hp0: int = b.mon.hp
	b.hurt(b.mon, 6, pal)
	var in_shrine: int = hp0 - b.mon.hp
	pal.pos = Vector2i(12, 4)
	hp0 = b.mon.hp
	b.hurt(b.mon, 6, pal)
	var outside: int = hp0 - b.mon.hp
	if outside - in_shrine != 3: errors.append("Shrine: %d damage inside, %d outside" % [in_shrine, outside])
	b.queue_free()
	Game.meta.rooms = rooms
	print("ROOMS: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))


## Starts a run with every Dread modifier on and checks that each one bites.
func _mods_test() -> void:
	var errors := []
	var all := []
	for o in Data.MODS:
		all.append(o.id)
	var best: int = Game.meta.best
	Game.meta.best = 0
	if Game.mods_unlocked(): errors.append("modifiers unlocked before night 5")
	Game.meta.best = Game.MODS_UNLOCK_BEST
	Game.new_run("vampire", all)
	if Game.hours != 2: errors.append("Short Days: %d hours" % Game.hours)
	if Game.mmax != roundi(38 * 0.75): errors.append("Glass Lair: %d max HP" % Game.mmax)
	if Game.party.size() != 4: errors.append("Crowded Gate: party of %d" % Game.party.size())
	if Game.make_party(4)[0] != "paladin" or Game.make_party(5)[0] == "paladin": errors.append("Restless Crusade: boss not on night 4")
	if Game.kill_gold(10) != 5: errors.append("Lean Coffers: kill gold %d" % Game.kill_gold(10))
	if absf(Game.soul_mult() - 2.85) > 0.001: errors.append("multiplier %.2f" % Game.soul_mult())
	var b := Battle.new()
	var h = b.mk_unit("h", "peasant", Vector2i(12, 1))
	if h.max_hp != roundi(9 * 1.25): errors.append("Zealous Village: %d HP" % h.max_hp)
	if h.atk != 3: errors.append("Hardened Raiders: %d damage" % h.atk)
	if not b.spots_traps(h): errors.append("Sharp Eyes: peasant ignores traps")
	b.free()
	Game.gold = 999
	Game.hours = 9
	Game.build(7, "larder")
	Game.mhp = 10
	var g0 := Game.gold
	Game.dawn({})
	if Game.mhp != 10: errors.append("No Rest: healed to %d" % Game.mhp)
	if Game.gold - g0 != 5: errors.append("Lean Coffers: tribute %d" % (Game.gold - g0))
	if Game.hours != 2: errors.append("Short Days: %d hours after dawn" % Game.hours)
	Game.souls = 10
	Game.day = 2
	var souls0: int = Game.meta.souls
	var earned := Game.end_run()
	if earned != roundi(14 * 2.85) or Game.meta.souls - souls0 != earned: errors.append("banked %d souls" % earned)
	Game.new_run("vampire")
	if Game.mods.size() > 0 or Game.hours != 3 or Game.mmax != 38: errors.append("modifiers leaked into the next run")
	Game.meta.best = best
	print("MODS: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))


## Saves a run mid-day to a scratch file, scrambles the state, loads it back and compares.
func _save_test() -> void:
	Game.run_path = "user://sim_run.save"
	Game.fast = false                      # saving is off in fast mode; the path above is a scratch file
	Game.new_run("mimic")
	Game.gold = 500
	Game.dig(6)
	Game.build(6, "snareden")
	Game.trap_mode = "snare"
	Game.place_trap(Vector2i(7, 7))
	Game.add_minion("goblin", true)
	Game.save_run()
	var want := [Game.gold, Game.hours, Game.slots.duplicate(true), Game.traps.duplicate(), Game.minions.size(), Game.minions[0].post, Game.entrance]
	Game.new_run("lich")
	var ok: bool = Game.has_run() and Game.run_summary().mk == "mimic" and Game.load_run()
	var got := [Game.gold, Game.hours, Game.slots, Game.traps, Game.minions.size(), Game.minions[0].post, Game.entrance]
	ok = ok and Game.mk == "mimic" and Game.M == Data.MONSTERS.mimic and got == want and Game.traps.size() == 1 and Game.obj.size() > 0
	Game.clear_run()
	ok = ok and not Game.has_run()
	Game.fast = true
	Game.run_path = "user://run.save"
	print("SAVE: ", "ok" if ok else "BAD %s vs %s" % [got, want])


func _unlock_test() -> void:
	Game.new_run("lich")
	var errors := []
	if Game.can_build("armory", 7): errors.append("armory buildable while locked")
	if not Game.can_build("treasury", 7): errors.append("treasury (starter) not buildable")
	if not Game.can_build("library", 7): errors.append("lich starter room not buildable")
	if Game.can_build("manawell", 7): errors.append("mana well buildable while locked")
	if Game.unlock_room("armory"): errors.append("unlocked a room with no souls")
	Game.meta.souls = 100
	if not Game.unlock_room("armory") or not Game.can_build("armory", 7): errors.append("could not unlock and build the armory")
	if Game.meta.souls != 100 - Data.ROOMS.armory.unlock: errors.append("unlock did not charge souls")
	print("UNLOCKS: %s" % ("ok" if errors.is_empty() else "FAIL " + "; ".join(errors)))

func _check_layouts() -> void:
	for t in Data.ROOMS:
		for e in Data.ROOMS[t].objs:
			if e.size() > 3 and e[3] == 1 and not (Vector2i(e[0], e[1]) in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 4), Vector2i(4, 4), Vector2i(1, 1), Vector2i(3, 1), Vector2i(1, 3), Vector2i(3, 3)]):
				print("BAD LAYOUT ", t, " ", e)


func _on_finished(won: bool) -> void:
	_done = true
	_won = won


func _first_dug() -> int:
	for i in Game.slots.size():
		if Game.slots[i].state == "dug":
			return i
	return -1


func _build_day() -> void:
	var order := []
	for t in Data.ROOMS:
		if Data.ROOMS[t].get("owner", "") == Game.mk:
			order.append(t)
	order += ["barracks", "workshop", "treasury", "torture", "larder", "armory", "collapse", "cistern", "kennel"]
	# go deeper whenever a boss night allows it, and move the lair down
	for i in Game.slots.size():
		if Game.slots[i].state == "dug" and Game.can_build("stairs", i) and Game.gold >= 80 and Game.hours >= 1:
			Game.build(i, "stairs")
			if Game.hours >= 3:
				Game.move_lair(i + Game.FLOOR_SLOTS)
			break
	for pass_i in 5:
		if Game.hours <= 0:
			break
		var empty := _first_dug()
		var want := ""
		if empty >= 0:
			for t in order:
				if Game.can_build(t, empty) and Game.gold >= Data.ROOMS[t].cost[0]:
					want = t
					break
		if empty >= 0 and want != "":
			Game.build(empty, want)
			continue
		var rock := -1
		for i in Game.slots.size():
			if Game.diggable(i) and i % Game.FLOOR_SLOTS >= Game.SW:
				rock = i
				break
		if empty < 0 and rock >= 0 and Game.gold >= 40:
			Game.dig(rock)
			continue
		break
	for k in Data.UNITS:
		var guard := 0
		while Game.cap_of(k) > Game.count_of(k) and Game.gold >= Data.UNITS[k].get("cost", 999) + 5 and guard < 10:
			Game.recruit(k)
			guard += 1
	for t in ["rune", "snare", "spikes"]:
		if Game.trap_unlocked(t):
			Game.trap_mode = t
			for i in 60:
				if Game.traps.size() >= Game.trap_cap() or Game.gold < 15:
					break
				var p := Vector2i(randi() % Game.BW, Game.RS + randi() % (Game.rows() - Game.RS))
				if Game.is_open(p) and not Game.traps.has(p):
					Game.place_trap(p)
	Game.trap_mode = ""


func _player_turn(b: Battle, rounds: int, used: Dictionary) -> void:
	for sp in b.all_specials():
		if _done or not b.can_cast(sp):
			continue
		var tiles := b.spell_tiles(sp)
		var hs := b.alive("h")
		if sp.kind == "area":
			tiles = tiles.filter(func(p): return hs.any(func(h): return absi(h.pos.x - p.x) <= 1 and absi(h.pos.y - p.y) <= 1))
		if sp.id == "nova" and not hs.any(func(h): return Game.man(h.pos, b.mon.pos) <= 2):
			continue
		if sp.id == "bats":
			tiles = tiles.filter(func(p): return hs.any(func(h): return Game.man(h.pos, p) == 1))
		if sp.id == "lure":
			tiles = tiles.filter(func(p): return Game.traps.has(p))
		if sp.id == "snap" and not hs.any(func(h): return Game.man(h.pos, b.mon.pos) <= 5):
			continue
		if sp.kind != "self" and tiles.is_empty():
			continue
		await b.cast_spell(sp, b.caster_of(sp).pos if sp.kind == "self" else tiles[0])
		used[sp.id] = used.get(sp.id, 0) + 1
	for u in b.alive("p"):
		if _done:
			break
		await b.handle_click(u.pos)
		var tg := b.targets_for(u)
		if tg.is_empty() and b.reach.size() > 0 and (u.kind != "monster" or rounds > 1):
			var best = null
			var bd := 1 << 30
			for k in b.reach:
				if b.reach[k].occ or b.reach[k].d == 0:
					continue
				for h in b.alive("h"):
					if Game.man(k, h.pos) < bd:
						bd = Game.man(k, h.pos)
						best = k
			if best != null:
				await b.handle_click(best)
			tg = b.targets_for(u)
		if tg.size() > 0 and not u.acted:
			await b.handle_click(u.pos)
			await b.handle_click(tg[0].pos)


func _play(mk: String) -> void:
	Game.new_run(mk)
	var used := {}
	var line := ""
	for night in 12:
		_build_day()
		var b := Battle.new()
		add_child(b)
		b.finished.connect(_on_finished)
		_done = false
		b.start()
		var rounds := 0
		while not _done and rounds < 80:
			rounds += 1
			await _player_turn(b, rounds, used)
			if _done:
				break
			await b.enemy_turn()
		var hp := b.mon.hp
		if not _done:
			line += " n%d STALEMATE" % Game.day
			b.queue_free()
			break
		if not _won:
			line += " n%d lost(%d rounds)" % [Game.day, rounds]
			Game.end_run()
			b.queue_free()
			break
		b.resolve_win()
		line += " n%d ok(hp %d%s)" % [Game.day, hp, ", %d floors" % Game.floors if Game.floors > 1 else ""]
		b.queue_free()
		Game.dawn(Game.boon_choices()[0])
	print("%s:%s  spells %s" % [mk, line, used])
