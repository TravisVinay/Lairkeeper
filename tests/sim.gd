extends Node
## Headless smoke test. Builds the real UI, opens a night, checks a three-floor dungeon, then
## plays scripted runs with every monster and prints how far each got. Run with:
##   godot --headless --path . res://tests/sim.tscn

const MainScene := preload("res://scenes/main.tscn")

var _done := false
var _won := false


func _ready() -> void:
	await _ui_smoke()
	Game.fast = true
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
	print("UI smoke: board %s, units %d" % [main.board.size, main.battle.units.size()])
	main.queue_free()
	await get_tree().process_frame


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
	for sp in Game.M.specials:
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
		await b.cast_spell(sp, b.mon.pos if sp.kind == "self" else tiles[0])
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
