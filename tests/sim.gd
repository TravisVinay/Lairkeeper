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
	_expand_test()
	_mods_test()
	await _rooms_test()
	_duo_test()
	_shaman_test()
	_warlock_test()
	_party_test()
	await _decor_test()
	await _ai_test()
	Game.meta.rooms = Data.ROOMS.keys()   # the scripted runs may use every room
	await _ui_smoke()
	for i in 5:
		await _tutorial_test()
	await _grow_test()
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
	Game.sel = 4
	Game.build(4, "graveyard")
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
	if Game.allowed("build:3:workshop") or Game.allowed("night"):
		errors.append("the welcome step allowed off-script actions")
	Game.build(3, "workshop")
	if Game.slots[3].state != "rock":
		errors.append("an off-script build went through")
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


## What a sensible player does with a free tutorial day: lay spikes.
func _spend_free_day() -> void:
	Game.trap_mode = "spikes"
	for p in [Vector2i(6, 1), Vector2i(8, 1), Vector2i(6, 3), Vector2i(8, 3), Vector2i(7, 4)]:
		if Game.gold >= Game.trap_cost("spikes") and Game.traps.size() < Game.trap_cap():
			Game.place_trap(p)
	Game.trap_mode = ""


## Grows the dungeon to 5x5, puts the throne in the far corner, and checks that heroes walk to it.
func _grow_test() -> void:
	Game.new_run("vampire")
	Game.gold = 2000
	Game.hours = 99
	var errors := []
	if Data.ROOMS.has("stairs"): errors.append("stairs are still a room")
	Game.bosses = 4
	for side in ["s", "e", "s", "e"]:
		Game.expand(side)
	Game.build(4, "barracks")                     # the new top-right corner touches no chamber
	if Game.slots[4].state != "rock": errors.append("built into rock that touches no chamber")
	if Game.SW != 5 or Game.SH != 5: errors.append("expected 5x5, got %dx%d" % [Game.SW, Game.SH])
	# rooms from the old throne room (now chamber 11) round to the bottom-right corner, built one
	# beside the last; the corner itself is dug out by building and tearing down a larder
	var path := {12: "treasury", 13: "workshop", 18: "torture", 23: "armory"}
	for si in path:
		Game.build(si, path[si])
	var corner := Game.SW * Game.SH - 1
	Game.build(corner, "larder")
	Game.demolish(corner)
	var h0 := Game.hours
	Game.move_lair(corner)
	if Game.slot_idx("lair") != corner: errors.append("throne did not move to the corner")
	if Game.hours != h0: errors.append("moving the throne took %d hours" % (h0 - Game.hours))
	if not Game.field([Game.entrance]).has(Game.monster_start()): errors.append("entrance cannot reach the throne")
	var b := Battle.new()
	add_child(b)
	b.finished.connect(_on_finished)
	_done = false
	b.start()
	var closest := 999
	var rounds := 0
	while not _done and rounds < 60:
		rounds += 1
		await b.enemy_turn()
		for h in b.alive("h"):
			closest = mini(closest, Game.man(h.pos, Game.monster_start()))
	if closest > 2: errors.append("heroes never reached the throne (closest %d)" % closest)
	print("GROW: %s (heroes got within %d of the throne in %d rounds)" % ["ok" if errors.is_empty() else "FAIL " + "; ".join(errors), closest, rounds])
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


## Spirit Lodge (a soul unlock) and shamans, the level cap, recruit placement and boon timing.
func _shaman_test() -> void:
	var errors := []
	Game.new_run("vampire")
	Game.gold = 9999
	Game.hours = 99
	if Game.is_unlocked("lodge"): errors.append("Spirit Lodge open without souls")
	Game.meta.souls = 30
	if not Game.unlock_room("lodge") or Game.meta.souls != 0: errors.append("could not unlock the Spirit Lodge for 30 souls")
	var g_build := Game.gold
	Game.build(5, "lodge")
	if Game.slots[5].get("type", "") != "lodge": errors.append("could not build the Spirit Lodge")
	# the room comes with its minions for free
	if Game.count_of("shaman") != 1: errors.append("the lodge came with %d shamans" % Game.count_of("shaman"))
	if g_build - Game.gold != Data.ROOMS.lodge.cost[0]: errors.append("building the lodge cost %d" % (g_build - Game.gold))
	if Game.slot_of(Game.minions[0].post) != 5: errors.append("the shaman isn't posted in its lodge")
	# rooms stop at level 3, and each level's new minions move in at once
	for i in 5:
		Game.upgrade(5)
	if Game.slots[5].lvl != Game.MAX_LVL: errors.append("lodge ended at level %d" % Game.slots[5].lvl)
	if Game.cap_of("shaman") != 3 or Game.count_of("shaman") != 3: errors.append("level 3 lodge houses %d of %d" % [Game.count_of("shaman"), Game.cap_of("shaman")])
	# dead minions come back free at dawn
	Game.minions.pop_back()
	Game.minions.pop_back()
	var g_dawn := Game.gold
	Game.dawn({})
	if Game.count_of("shaman") != 3: errors.append("dawn left %d shamans" % Game.count_of("shaman"))
	if Game.gold != g_dawn + 10: errors.append("replacing shamans cost %d" % (g_dawn + 10 - Game.gold))
	for t in Data.ROOMS:
		if Data.ROOMS[t].cost.size() != Game.MAX_LVL: errors.append("%s lists %d prices" % [t, Data.ROOMS[t].cost.size()])
	# shamans heal your units within 2 tiles at the start of your turn
	var b := Battle.new()
	add_child(b)
	b.mon = b.mk_unit("p", "monster", Game.monster_start())
	var sh = b.mk_unit("p", "shaman", Game.monster_start() + Vector2i(1, 0))
	var far = b.mk_unit("p", "goblin", Game.monster_start() + Vector2i(0, 3))
	b.mon.hp -= 20
	far.hp -= 4
	var hp0: int = b.mon.hp
	b._shaman_mend()
	if b.mon.hp - hp0 != Data.shaman_mend(3): errors.append("monster healed %d, want %d" % [b.mon.hp - hp0, Data.shaman_mend(3)])
	if far.hp != far.max_hp - 4: errors.append("healed a unit 3 tiles away")
	if sh.hp != sh.max_hp: errors.append("shaman hurt itself")
	b.queue_free()
	# tearing the room down sends its minions away
	Game.hours = 99
	Game.demolish(5)
	if Game.count_of("shaman") != 0: errors.append("%d shamans stayed after the lodge came down" % Game.count_of("shaman"))
	# boons come every fifth night
	if Game.boon_due(4) or not Game.boon_due(5) or Game.boon_due(6) or not Game.boon_due(10): errors.append("boon nights wrong")
	Game.day = 5
	if Game.next_boon_night() != 5: errors.append("day 5 says next boon on night %d" % Game.next_boon_night())
	Game.day = 6
	if Game.next_boon_night() != 10: errors.append("day 6 says next boon on night %d" % Game.next_boon_night())
	Game.meta.rooms = []
	print("SHAMAN: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))


## Furniture: wall off the lair, carry a piece to another room, heroes smash through, then repair it.
func _decor_test() -> void:
	var errors := []
	Game.new_run("vampire")
	Game.gold = 999
	Game.hours = 99
	Game.build(4, "barracks")   # the hall between the gate hall and the lair
	Game.minions[0].post = Vector2i(7, 6)   # a guard post furniture can't be set on
	Game.minions[1].post = Vector2i(9, 7)   # the barracks' second goblin, out of the way
	Game.sel_minion = null
	Game.toggle_arrange("furniture")
	# three bunks into the doorway down to the lair (room-local y 4, x 1..3)
	Game.day_click(Vector2i(5, 5))
	if Game.decor_pick != Vector2i(5, 5): errors.append("could not pick up a bunk")
	Game.day_click(Vector2i(6, 9))
	Game.day_click(Vector2i(9, 5))
	Game.day_click(Vector2i(7, 6))   # the goblin's post: refused
	if Game.decor_pick != Vector2i(9, 5) or Game.obj.has(Vector2i(7, 6)): errors.append("set a bunk down on a guard post")
	Game.day_click(Vector2i(7, 9))
	Game.day_click(Vector2i(6, 6))
	Game.day_click(Vector2i(8, 9))
	for t in [Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9)]:
		if not Game.blocked(t): errors.append("doorway tile %s not blocked" % t)
	if Game.obj.has(Vector2i(5, 5)): errors.append("bunk left a copy behind")
	if Game.field([Vector2i(7, 7)]).has(Game.monster_start()): errors.append("the lair is still reachable")
	# carry a bunk out of the barracks into a different room
	Game.build(3, "larder")
	var dest := Vector2i(-1, -1)
	for t in Game.slot_tiles(3):
		if Game.decor_spot_ok(t):
			dest = t
			break
	var n4 := Game.room_objs(4).size()
	var n3 := Game.room_objs(3).size()
	Game.day_click(Vector2i(8, 6))
	Game.day_click(dest)
	if Game.room_objs(4).size() != n4 - 1 or Game.room_objs(3).size() != n3 + 1 or Game.obj.get(dest, {}).get("si", -1) != 3:
		errors.append("bunk did not move into the larder")
	Game.toggle_arrange("furniture")   # Done
	if Game.arrange != "": errors.append("Done did not end arranging")
	# minions mode: pick a goblin up and post it, and stay in the mode for the next one
	Game.toggle_arrange("minions")
	Game.day_click(Game.minions[0].post)
	Game.day_click(Vector2i(6, 7))
	if Game.minions[0].post != Vector2i(6, 7) or Game.arrange != "minions": errors.append("minions mode: post %s, mode '%s'" % [Game.minions[0].post, Game.arrange])
	Game.clear_modes()
	# a walled-off barbarian hacks through a bunk
	var b := Battle.new()
	add_child(b)
	b.mon = b.mk_unit("p", "monster", Game.monster_start())
	var h = b.mk_unit("h", "barbarian", Vector2i(7, 7))
	var turns := 0
	while Game.broken_count(4) == 0 and turns < 8 and h.hp > 0:
		turns += 1
		await b.hero_turn(h)
	if Game.broken_count(4) != 1: errors.append("%d pieces smashed after %d turns" % [Game.broken_count(4), turns])
	if not Game.field([h.pos]).has(Game.monster_start()): errors.append("no way through after smashing")
	b.queue_free()
	var g0 := Game.gold
	Game.repair_room(4)
	if Game.broken_count(4) != 0 or g0 - Game.gold != Data.DECOR_REPAIR: errors.append("repair: %d broken, paid %d" % [Game.broken_count(4), g0 - Game.gold])
	if Game.field([Vector2i(7, 7)]).has(Game.monster_start()): errors.append("repaired wall lets heroes through")
	print("DECOR: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))
	# a sapper next to two traps spends its turn taking apart just one of them
	var serr := []
	var b2 := Battle.new()
	add_child(b2)
	b2.mon = b2.mk_unit("p", "monster", Game.monster_start())
	var sp = b2.mk_unit("h", "sapper", Vector2i(7, 3))
	Game.traps = {Vector2i(6, 3): "spikes", Vector2i(8, 3): "spikes"}
	await b2.hero_turn(sp)
	if Game.traps.size() != 1: serr.append("%d traps left after one sapper turn" % Game.traps.size())
	if sp.pos != Vector2i(7, 3): serr.append("the sapper also moved")
	await b2.hero_turn(sp)
	if Game.traps.size() != 0: serr.append("second trap still there")
	Game.traps = {}
	b2.queue_free()
	print("SAPPER: ", "ok" if serr.is_empty() else "BAD " + "; ".join(serr))
	await _trap_test()


## Every trap fires once a night, hits hard, and re-arms the next night. Wary heroes walk
## straight over one that has already gone off.
func _trap_test() -> void:
	var errors := []
	Game.new_run("vampire")
	Game.gold = 999
	Game.hours = 99
	Game.build(3, "workshop")
	if Game.trap_dmg("spikes") != 12: errors.append("level 1 spikes deal %d" % Game.trap_dmg("spikes"))
	var k := Vector2i(7, 7)
	Game.traps = {k: "spikes"}
	var b := Battle.new()
	add_child(b)
	b.mon = b.mk_unit("p", "monster", Game.monster_start())
	var h1 = b.mk_unit("h", "barbarian", Vector2i(7, 6))
	var h2 = b.mk_unit("h", "barbarian", Vector2i(7, 8))
	await b.walk(h1, [k])
	if h1.hp != h1.max_hp - 12: errors.append("first hero took %d" % (h1.max_hp - h1.hp))
	h1.pos = Vector2i(6, 6)
	await b.walk(h2, [k])
	if h2.hp != h2.max_hp: errors.append("the sprung trap hit a second hero for %d" % (h2.max_hp - h2.hp))
	if not Game.traps.has(k): errors.append("the trap was used up")
	var rogue = b.mk_unit("h", "rogue", Vector2i(7, 6))
	h2.pos = Vector2i(8, 8)
	if not b.reach_of(rogue, true).has(k): errors.append("a rogue still steps around a sprung trap")
	b.queue_free()
	# the next night it's armed again
	var b2 := Battle.new()
	add_child(b2)
	b2.mon = b2.mk_unit("p", "monster", Game.monster_start())
	var h3 = b2.mk_unit("h", "barbarian", Vector2i(7, 6))
	await b2.walk(h3, [k])
	if h3.hp != h3.max_hp - 12: errors.append("next night the trap did %d" % (h3.max_hp - h3.hp))
	# snares and blast runes aren't used up either
	for t in ["snare", "rune"]:
		Game.traps = {k: t}
		b2.sprung = {}
		var h4 = b2.mk_unit("h", "barbarian", Vector2i(7, 6))
		h3.pos = Vector2i(9, 9)
		await b2.walk(h4, [k])
		if h4.hp >= h4.max_hp: errors.append("the %s did nothing" % t)
		if Game.traps.get(k, "") != t: errors.append("the %s was used up" % t)
		h4.hp = 0
	b2.queue_free()
	Game.traps = {}
	print("TRAPS: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))


## Raiders: peasants and archers only through night 5, new types phase in after, peasants fade out.
func _party_test() -> void:
	var errors := []
	Game.new_run("vampire")
	var seen := {}
	for d in range(1, 21):
		seen[d] = {}
		for i in 200:
			for k in Game.make_party(d):
				seen[d][k] = true
	for d in range(1, 6):
		for k in seen[d]:
			if not k in ["peasant", "archer", "paladin"]: errors.append("a %s on night %d" % [k, d])
	if seen[1].keys() != ["peasant"]: errors.append("night 1 heroes: %s" % [seen[1].keys()])
	if not seen[5].has("paladin"): errors.append("no Paladin on night 5")
	if seen[6].has("knight") or not seen[6].has("rogue"): errors.append("night 6 heroes: %s" % [seen[6].keys()])
	if seen[13].has("peasant") or seen[20].has("peasant"): errors.append("peasants still raiding late")
	if not seen[11].has("barbarian"): errors.append("no barbarian by night 11")
	if Game.hero_atk_bonus(5) != 0: errors.append("heroes hit harder by night 5")
	# from night 15 raids are adventuring companies: small, one healer, a front-liner leading
	for d in [15, 19, 20, 24]:
		for i in 50:
			var p: Array = Game.make_party(d)
			if p.size() != Game.party_size(d) or p.size() > 6: errors.append("company of %d on night %d" % [p.size(), d])
			if p.count("cleric") != 1: errors.append("company with %d clerics" % p.count("cleric"))
			if not p[0] in ["knight", "barbarian", "paladin"]: errors.append("company led by a %s" % p[0])
	if Game.party_size(14) < 9 or Game.party_size(15) != 5: errors.append("company sizes %d/%d" % [Game.party_size(14), Game.party_size(15)])
	print("PARTY: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))


## Warlock Coven: a starter room that hires warlocks whose bolts ignore armor.
func _warlock_test() -> void:
	var errors := []
	Game.new_run("vampire")
	Game.gold = 9999
	Game.hours = 99
	if not Game.is_unlocked("coven"): errors.append("Warlock Coven needs souls")
	Game.build(5, "coven")
	if Game.count_of("warlock") != 1: errors.append("the coven came with %d warlocks" % Game.count_of("warlock"))
	var b := Battle.new()
	add_child(b)
	b.mon = b.mk_unit("p", "monster", Game.monster_start())
	var w = b.mk_unit("p", "warlock", Game.monster_start() + Vector2i(1, 0))
	var g = b.mk_unit("p", "goblin", Game.monster_start() + Vector2i(-1, 0))
	var k = b.mk_unit("h", "knight", Game.monster_start() + Vector2i(1, 2))
	var hp0: int = k.hp
	await b.attack(w, k)
	if hp0 - k.hp != b.atk_of(w): errors.append("warlock bolt did %d to a knight, want %d" % [hp0 - k.hp, b.atk_of(w)])
	hp0 = k.hp
	await b.attack(g, k)
	if hp0 - k.hp != b.atk_of(g) - 1: errors.append("knight armor stopped nothing from a goblin")
	var a1: int = b.atk_of(w)
	Game.upgrade(5)
	if b.atk_of(w) != a1 + 1: errors.append("level 2 coven did not add damage")
	b.queue_free()
	print("WARLOCK: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))


## Checks the rule of each room added in the second rooms batch.
func _rooms_test() -> void:
	var errors := []
	var rooms: Array = Game.meta.rooms
	Game.meta.rooms = Data.ROOMS.keys()
	Game.new_run("vampire")
	Game.gold = 999
	Game.hours = 99
	Game.build(4, "maze")
	var g_rock := Game.gold
	Game.build(3, "barracks")   # straight into rock: just the room's price
	if g_rock - Game.gold != Data.ROOMS.barracks.cost[0]: errors.append("building into rock cost %d" % (g_rock - Game.gold))
	Game.build(6, "ogreden")
	Game.build(8, "scrying")
	if Game.count_of("ogre") != 1: errors.append("Ogre Den: %d ogres" % Game.count_of("ogre"))
	if Data.ROOMS.has("stitching"): errors.append("the Stitching Room is still a room")
	var want_next: Array = Game.future[0]
	Game.dawn({})
	# Scrying Pool: tomorrow's party is the one it showed, and two more nights are lined up
	if Game.party != want_next or Game.future.size() != 2: errors.append("Scrying Pool: party %s, %d ahead" % [Game.party, Game.future.size()])
	# Maze of Bones: a hero walking in from the gate hall stops on the first maze tile
	var b := Battle.new()
	add_child(b)
	b.mon = b.mk_unit("p", "monster", Game.monster_start())
	var h = b.mk_unit("h", "peasant", Vector2i(7, 4))
	await b.walk(h, [Vector2i(7, 5), Vector2i(7, 6), Vector2i(7, 7)])
	if h.pos != Vector2i(7, 5): errors.append("Maze of Bones: hero walked on to %s" % h.pos)
	# Shrine of Desecration: a paladin inside loses its holy bonus against a vampire
	Game.build(0, "shrine")
	var pal = b.mk_unit("h", "paladin", Vector2i(2, 2))
	var hp0: int = b.mon.hp
	b.hurt(b.mon, 6, pal)
	var in_shrine: int = hp0 - b.mon.hp
	pal.pos = Vector2i(7, 4)
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
	var h = b.mk_unit("h", "peasant", Vector2i(7, 1))
	if h.max_hp != roundi(9 * 1.25): errors.append("Zealous Village: %d HP" % h.max_hp)
	if h.atk != 3: errors.append("Hardened Raiders: %d damage" % h.atk)
	if not b.spots_traps(h): errors.append("Sharp Eyes: peasant ignores traps")
	b.free()
	Game.gold = 999
	Game.hours = 9
	Game.build(4, "larder")
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
	# surviving night 50 wins: the night counts as survived and the victory bonus is banked
	Game.day = Game.WIN_NIGHT
	Game.souls = 0
	var wins0: int = Game.meta.get("wins", 0)
	var won_souls := Game.end_run(true)
	if won_souls != Game.WIN_NIGHT * 2 + Game.WIN_SOULS: errors.append("a won run banked %d souls" % won_souls)
	if Game.meta.get("wins", 0) != wins0 + 1 or Game.meta.best < Game.WIN_NIGHT: errors.append("win not recorded")
	Game.meta.wins = wins0
	Game.meta.best = best
	print("MODS: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))


## Saves a run mid-day to a scratch file, scrambles the state, loads it back and compares.
func _save_test() -> void:
	Game.run_path = "user://sim_run.save"
	Game.fast = false                      # saving is off in fast mode; the path above is a scratch file
	Game.new_run("mimic")
	Game.gold = 500
	Game.build(3, "snareden")
	Game.trap_mode = "snare"
	Game.place_trap(Vector2i(2, 7))
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


## Expanding adds a row or column of rock to every floor (as many chambers as that side is long),
## keeps rooms, traps and posts in place, pushes the entrance out when it grows past it,
## and survives a save. Moving the throne is free.
func _expand_test() -> void:
	var errors := []
	Game.new_run("vampire")
	Game.gold = 1000
	Game.hours = 99
	Game.build(4, "barracks")
	Game.trap_mode = "spikes"
	var had: Array = Game.meta.rooms
	Game.meta.rooms = Data.ROOMS.keys()
	Game.build(5, "workshop")
	Game.place_trap(Vector2i(7, 2))
	Game.trap_mode = ""
	var post: Vector2i = Game.minions[0].post
	var g0 := Game.gold
	Game.expand("e")
	if Game.SW != 3: errors.append("expanded without beating a boss")
	Game.day = 5
	Game.dawn({})
	if Game.bosses != 1 or Game.expands_left() != 1: errors.append("a boss night gave %d expansions" % Game.expands_left())
	Game.hours = 99
	g0 = Game.gold
	Game.expand("e")
	if Game.expands_left() != 0 or Game.expand_block("n") == "": errors.append("one boss gave more than one expansion")
	Game.bosses = 99
	if Game.SW != 4 or Game.SH != 3 or Game.gold != g0 - 30: errors.append("east: %dx%d, paid %d" % [Game.SW, Game.SH, g0 - Game.gold])
	if Game.entrance != Vector2i(7, 0): errors.append("east moved the entrance to %s" % Game.entrance)
	if Game.slot_idx("lair") != 9 or Game.slot_idx("workshop") != 6: errors.append("east lost the layout")
	g0 = Game.gold
	Game.expand("n")                           # past the entrance: 4 chambers, gate moves out
	if Game.SH != 4 or Game.gold != g0 - 40: errors.append("north: %dx%d, paid %d" % [Game.SW, Game.SH, g0 - Game.gold])
	if Game.entrance != Vector2i(7, 0) or Game.slots[1].state != "dug": errors.append("north: entrance at %s" % Game.entrance)
	if Game.slot_idx("lair") != 13 or Game.slot_idx("workshop") != 10: errors.append("north lost the layout")
	if Game.traps.get(Vector2i(7, 7), "") != "spikes": errors.append("trap did not move: %s" % [Game.traps])
	if Game.minions[0].post != post + Vector2i(0, 5) or Game.minions[0].home != Game.slot_idx("barracks"): errors.append("minion did not move")
	if not Game.field([Game.entrance]).has(Game.monster_start()): errors.append("heroes can't reach the throne")
	Game.expand("w")
	if Game.entrance != Vector2i(12, 0): errors.append("west: entrance at %s" % Game.entrance)
	while Game.expand_block("e") == "":
		Game.expand("e")
	if Game.SW != Game.MAX_SIDE: errors.append("stopped at width %d" % Game.SW)
	var w := Game.SW
	Game.expand("w")
	if Game.SW != w: errors.append("grew past the cap")
	Game.hours = 0
	g0 = Game.gold
	var dug := -1
	for i in Game.slots.size():
		if Game.slots[i].state == "dug" and i != Game.slot_of(Game.entrance):
			dug = i
	Game.move_lair(dug)
	if Game.slot_idx("lair") != dug or Game.gold != g0: errors.append("throne move was not free")
	# save and load the bigger dungeon
	Game.run_path = "user://sim_run.save"
	Game.fast = false
	Game.save_run()
	var want := [Game.SW, Game.SH, Game.slots.duplicate(true), Game.entrance, Game.traps.duplicate()]
	Game.new_run("lich")
	if not Game.load_run() or [Game.SW, Game.SH, Game.slots, Game.entrance, Game.traps] != want or Game.BW != Game.SW * Game.RS:
		errors.append("save lost the expansion")
	Game.clear_run()
	Game.fast = true
	Game.run_path = "user://run.save"
	Game.meta.rooms = had
	Game.new_run("vampire")
	if Game.SW != 3 or Game.SH != 3: errors.append("new run kept the old size")
	print("EXPAND: ", "ok" if errors.is_empty() else "BAD " + "; ".join(errors))


## "AI moves": minions step toward (or attack) heroes, the monster stays put, and the turn ends.
## Then a whole night is played with only that button.
func _ai_test() -> void:
	var errors := []
	Game.new_run("vampire")
	Game.gold = 500
	Game.build(4, "barracks")
	Game.upgrade(4)                            # comes with 4 goblins
	var b := Battle.new()
	add_child(b)
	b.finished.connect(_on_finished)
	_done = false
	b.start()
	var mins := b.idle_minions()
	if mins.size() != 4: errors.append("%d idle minions, expected 4" % mins.size())
	var F := Game.field(b.alive("h").map(func(h): return h.pos))
	for u in mins:
		var dest := b._auto_spot(u)
		if F.get(dest, 999) > F.get(u.pos, 999): errors.append("a goblin chose to back away")
	var start: Vector2i = b.mon.pos
	await b.auto_minions()
	if b.turn != 2: errors.append("turn did not end (turn %d)" % b.turn)
	if b.mon.pos != start: errors.append("the monster was moved")
	var rounds := 1
	while not _done and rounds < 60:
		rounds += 1
		await b.auto_minions()
	if not _done: errors.append("night still going after %d AI turns" % rounds)
	b.queue_free()
	print("AI MOVES: %s (night ended after %d turns)" % ["ok" if errors.is_empty() else "BAD " + "; ".join(errors), rounds])


func _unlock_test() -> void:
	Game.new_run("lich")
	var errors := []
	if Game.can_build("armory", 4): errors.append("armory buildable while locked")
	if not Game.can_build("treasury", 4): errors.append("treasury (starter) not buildable")
	if not Game.can_build("library", 4): errors.append("lich starter room not buildable")
	if Game.can_build("manawell", 4): errors.append("mana well buildable while locked")
	if Game.unlock_room("armory"): errors.append("unlocked a room with no souls")
	Game.meta.souls = 100
	if not Game.unlock_room("armory") or not Game.can_build("armory", 4): errors.append("could not unlock and build the armory")
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


func _build_day() -> void:
	var order := []
	for t in Data.ROOMS:
		if Data.ROOMS[t].get("owner", "") == Game.mk:
			order.append(t)
	order += ["barracks", "workshop", "treasury", "torture", "larder", "armory", "collapse", "cistern", "kennel"]
	# grow south (away from the gate) once every chamber in reach holds a room
	var room := false
	for i in Game.slots.size():
		if Game.slots[i].state == "dug" or Game.can_open(i) and i >= Game.SW:
			room = true
	if not room and Game.expand_block("s") == "" and Game.gold >= Game.expand_cost("s") + 40:
		Game.expand("s")
	for pass_i in 5:
		if Game.hours <= 0:
			break
		# empty chambers first, then rock beside the dungeon (keeping the gate row clear)
		var spots := []
		for i in Game.slots.size():
			if Game.slots[i].state == "dug":
				spots.append(i)
		for i in Game.slots.size():
			if Game.can_open(i) and i >= Game.SW:
				spots.append(i)
		var built := false
		for si in spots:
			for t in order:
				if Game.can_build(t, si) and Game.gold >= Data.ROOMS[t].cost[0]:
					Game.build(si, t)
					built = true
					break
			if built:
				break
		if not built:
			break
	for t in ["rune", "snare", "spikes"]:
		if Game.trap_unlocked(t):
			Game.trap_mode = t
			for i in 60:
				if Game.traps.size() >= Game.trap_cap() or Game.gold < 15:
					break
				var p := Vector2i(randi() % Game.BW, Game.RS + randi() % (Game.BH - Game.RS))
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
		line += " n%d ok(hp %d%s)" % [Game.day, hp, ", %dx%d" % [Game.SW, Game.SH] if Game.SW * Game.SH > 9 else ""]
		b.queue_free()
		Game.dawn(Game.boon_choices()[0])
	print("%s:%s  spells %s" % [mk, line, used])
