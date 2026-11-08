class_name Battle
extends Node
## One night's fight on the dungeon board: units, turn order, spells, traps and hero AI.
## The board reads this node to draw; main listens for `finished`.

signal changed
signal finished(won: bool)
signal focus(p: Vector2i)

class Unit:
	var id := 0
	var side := ""          # "p" for the player's side, "h" for heroes
	var kind := ""
	var uname := ""
	var d := {}
	var pos := Vector2i.ZERO
	var draw_pos := Vector2.ZERO
	var hp := 0
	var max_hp := 0
	var move := 0
	var atk := 0
	var rng := 1
	var armor := 0
	var moved := false
	var acted := false
	var cds := {}
	var slow := 0
	var root := 0
	var stun := 0
	var conf := 0
	var flash := 0.0
	var lunge := Vector2.ZERO
	var lunge_t := 0.0
	var thrall := false
	var flee := false
	var stole := 0
	var escaped := false
	var mid := -1
	var dazed := false      # lost in a level 2 Maze of Bones: no attack this turn
	var hex := 0            # turns left under the Dark Lord's Hex
	var shield := 0         # damage a Dark Ward will still soak
	var taunt: Unit = null  # Challenged: must go for this unit on its next turn
	var rally := false      # Rallied by the Squire this turn

var units: Array = []
var mon: Unit
var squire: Unit = null    # the Dark Lord's partner, when the monster is a duo
var corpses := {}
var sel: Unit = null
var mode := ""
var busy := false
var over := false
var turn := 1
var loot := 0
var kills := 0
var stolen := 0
var escaped := 0
var smashed := 0     # furniture broken tonight
var decor_hp := {}   # Vector2i -> HP left on furniture heroes have started smashing
var reach := {}
var threat := {}
var revived := false
var used := {}
var queue := []
## Trap tiles that have already fired tonight. Every trap fires once a night and re-arms at dawn.
var sprung := {}
var fx := []        # {kind, a, b, col, t, max, r}
var texts := []     # {p, s, col, t}
var parts := []     # {p, v, col, t}
var shake := 0.0
var tip_text := ""

var TRAP := Unit.new()


func _init() -> void:
	TRAP.kind = "trap"
	TRAP.uname = "Trap"
	TRAP.d = {"name": "trap"}


func wait(t: float) -> void:
	if Game.fast or not is_inside_tree():
		return
	await get_tree().create_timer(t / Settings.battle_speed).timeout


func say(msg: String, warn := false) -> void:
	Game.tip(msg, warn)


# ---------------------------------------------------------------- setup

func mk_unit(side: String, kind: String, p: Vector2i) -> Unit:
	var u := Unit.new()
	var is_mon := kind == "monster"
	var is_sq := kind == "squire"
	var D: Dictionary = Game.M if is_mon else (Game.M.partner if is_sq else Data.UNITS[kind])
	u.id = Game.next_id()
	u.side = side
	u.kind = kind
	u.d = D
	u.uname = Game.M.name if is_mon else D.name if is_sq else (_hero_name(kind) if side == "h" else D.name)
	u.pos = p
	u.draw_pos = Vector2(p)
	u.move = D.move
	u.atk = D.atk
	u.rng = D.rng
	u.armor = D.get("armor", 0)
	if is_mon:
		u.hp = Game.mhp
		u.max_hp = Game.mmax
	elif is_sq:
		u.hp = Game.shp
		u.max_hp = Game.smax
	elif side == "h":
		u.max_hp = maxi(1, roundi(D.hp * Game.hero_hp_mult(Game.day) * Game.veteran_hp(Game.day) * (1.25 if Game.has_mod("zealous") else 1.0)
			* (1.0 - Data.scry_shaken(Game.lvl("scrying")))))
		u.hp = u.max_hp
		u.atk += Game.hero_atk_bonus(Game.day) + (1 if Game.has_mod("hardened") else 0) + (1 if Game.is_company(Game.day) else 0)
	else:
		u.max_hp = D.hp + Game.b.get("minion_hp", 0)
		if D.get("undead", false) and Game.mk == "necro":
			var f := Game.lvl("boneforge")
			u.max_hp += f * 2
			u.atk += f
		u.hp = u.max_hp
	units.append(u)
	return u

## A name for a new hero that nobody else in tonight's raid already has, while any are left.
func _hero_name(kind: String) -> String:
	var taken := units.map(func(o): return o.uname)
	var free: Array = Data.NAMES[kind].filter(func(n): return not n in taken)
	return free.pick_random() if free.size() > 0 else Data.NAMES[kind].pick_random()


func start() -> void:
	Game.clear_modes()
	queue = Game.party.duplicate()
	mon = mk_unit("p", "monster", Game.monster_start())
	if Game.duo():
		squire = mk_unit("p", "squire", Game.squire_start())
		if "squire" in Game.down:
			squire.hp = 0
		if "lord" in Game.down:
			mon.hp = 0
	for m in Game.minions:
		var u := mk_unit("p", m.kind, m.post)
		u.mid = m.mid
	admit(3)
	if Game.is_company(Game.day):
		Game.add_log("Night %d: %s, %d seasoned adventurers, stand at your gate." % [Game.day, Game.company_name(Game.party), Game.party.size()], "bad")
	else:
		Game.add_log("Night %d: %d heroes gather at your gate." % [Game.day, Game.party.size()], "bad")
	start_player_turn(true)


func admit(n: int) -> void:
	var F := Game.field([Game.entrance])
	var spots := []
	for k in F:
		if F[k] <= 2:
			spots.append(k)
	spots.sort_custom(func(a, c): return F[a] < F[c])
	var c := 0
	for p in spots:
		if c >= n or queue.is_empty():
			break
		if unit_at(p):
			continue
		mk_unit("h", queue.pop_front(), p)
		burst(p, Data.col("#e4a648"), 6)
		c += 1
	if c > 0:
		Game.add_log("%d hero%s push through the gate.%s" % [c, "es" if c > 1 else "", (" %d still waiting outside." % queue.size()) if queue.size() > 0 else ""])


# ---------------------------------------------------------------- queries

func alive(side: String) -> Array:
	return units.filter(func(u): return u.hp > 0 and u.side == side)

func unit_at(p: Vector2i) -> Unit:
	for u in units:
		if u.hp > 0 and u.pos == p:
			return u
	return null

func empty_tile(p: Vector2i) -> bool:
	return Game.is_open(p) and unit_at(p) == null

## The monster and, for a duo, the Squire: the units the run is lost without.
func is_mon(u: Unit) -> bool:
	return u.kind == "monster" or u.kind == "squire"

func mons_alive() -> Array:
	return units.filter(func(u): return u.hp > 0 and is_mon(u))

## The monster unit to select or follow first: the Dark Lord, or his Squire if he is down.
func lead() -> Unit:
	var a := mons_alive()
	return a[0] if a.size() > 0 else mon

## The Dark Lord and his Squire are bonded while they stand close together.
func bonded() -> bool:
	if squire == null or mon.hp <= 0 or squire.hp <= 0:
		return false
	return Game.man(mon.pos, squire.pos) <= Data.oath_range(Game.lvl("oathstone"))

func move_of(u: Unit) -> int:
	if u.root > 0:
		return 0
	var m: int = u.move + (Game.b.move if is_mon(u) else 0) + (1 if u.rally else 0)
	if u.side == "h" and Game.type_at(u.pos) == "cistern":
		m = maxi(1, m - Game.lvl("cistern"))
	if u.slow > 0:
		m = mini(m, 1)
	return m

func atk_of(u: Unit) -> int:
	var bond := 1 if bonded() and is_mon(u) else 0
	if u.kind == "monster":
		return u.atk + Game.b.atk + Game.lvl("bloodpool") * 2 + Game.lvl("brainjars") * 2 + Game.lvl("sanctum") + bond
	if u.kind == "squire":
		return u.atk + Game.b.atk + bond
	if u.side == "p":
		return u.atk + Game.b.minion + Game.lvl("armory") + (2 if u.rally else 0) + (Data.amp_dmg(Game.lvl("amplifier")) if u.thrall else 0) \
			+ (maxi(0, Game.lvl("coven") - 1) if u.kind == "warlock" else 0)
	return maxi(1, u.atk - (2 if u.hex > 0 else 0))

func spell_dmg(base: int) -> int:
	return base + Game.b.spell + Game.lvl("library") * 2 + Data.well_dmg(Game.lvl("manawell"))

func cd_of(sp: Dictionary) -> int:
	var c: int = sp.cd - Game.b.cd - Game.lvl("manawell")
	if sp.id == "raise" and Game.lvl("soulcage") > 0: c -= 1
	if sp.id == "dominate" and Game.lvl("amplifier") > 0: c -= 1
	if bonded() and caster_of(sp) == mon: c -= 1
	return maxi(1, c)

## Rogues and Sappers see traps and walk around them; with Sharp Eyes every hero does.
func spots_traps(u: Unit) -> bool:
	return u.side == "h" and (u.d.get("sense", false) or Game.has_mod("sharp"))

func is_unholy(u: Unit) -> bool:
	if is_mon(u):
		return Game.mk in ["vampire", "lich", "necro"]
	return u.d.get("undead", false)

func reach_of(u: Unit, avoid := false) -> Dictionary:
	var R := {u.pos: {"d": 0, "prev": null, "occ": false}}
	var q := [u.pos]
	var i := 0
	var m := move_of(u)
	var at := {}   # who stands where, looked up once instead of per tile
	for o in units:
		if o.hp > 0:
			at[o.pos] = o
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		var cur: Dictionary = R[c]
		if cur.d >= m:
			continue
		for n in Game.steps(c):
			if R.has(n):
				continue
			var o = at.get(n)
			if o and o.side != u.side:
				continue
			if avoid and armed(n):
				continue
			R[n] = {"d": cur.d + 1, "prev": c, "occ": false}
			q.append(n)
	for k in R:
		if k != u.pos and at.has(k):
			R[k].occ = true
	return R

func path_to(R: Dictionary, k: Vector2i) -> Array:
	var p := []
	var c = k
	while c != null and R[c].prev != null:
		p.push_front(c)
		c = R[c].prev
	return p

func targets_for(u: Unit) -> Array:
	if u.acted:
		return []
	return alive("h").filter(func(h): return Game.in_range(u.pos, h.pos, u.rng))

func threat_of(u: Unit) -> Dictionary:
	var T := {}
	var R := reach_of(u, spots_traps(u))
	for v in R:
		if R[v].occ:
			continue
		for dy in range(-u.rng, u.rng + 1):
			for dx in range(-u.rng, u.rng + 1):
				var p: Vector2i = v + Vector2i(dx, dy)
				if absi(dx) + absi(dy) <= u.rng and Game.is_floor(p) and not T.has(p) and Game.los(v, p):
					T[p] = true
	return T


# ---------------------------------------------------------------- movement and traps

func walk(u: Unit, path: Array) -> void:
	for st in path:
		var from := u.pos
		u.pos = st
		await wait(0.085)
		if u.side == "h" and await spring_trap(u):
			return
		# heroes who wander into the Maze of Bones lose their way and stop
		if u.side == "h" and Game.type_at(st) == "maze" and Game.type_at(from) != "maze":
			text(st, "lost!", Data.col("#e8dcc0"))
			u.dazed = Game.lvl("maze") >= 2
			var md := Data.maze_dmg(Game.lvl("maze"))
			if md > 0:
				hurt(u, md, TRAP, true)
			return

## A trap on this tile that hasn't fired yet tonight.
func armed(p: Vector2i) -> bool:
	return Game.traps.has(p) and not sprung.has(p)

func spring_trap(u: Unit) -> bool:
	var k := u.pos
	if not armed(k):
		return false
	var t: String = Game.traps[k]
	sprung[k] = true
	if t == "spikes":
		text(k, "spikes!", Data.col("#e8dcc0"))
		hurt(u, Game.trap_dmg("spikes"), TRAP)
		return u.hp <= 0
	if t == "snare":
		text(k, "snared!", Data.col("#e0c080"))
		u.root = 1
		hurt(u, Game.trap_dmg("snare"), TRAP)
		return true
	ring(k, Data.col("#ff7a3a"), 1.6)
	burst(k, Data.col("#ffb050"), 26)
	shake = 0.25
	Game.add_log("A blast rune erupts.")
	for h in alive("h"):
		if absi(h.pos.x - k.x) <= 1 and absi(h.pos.y - k.y) <= 1:
			hurt(h, Game.trap_dmg("rune"), TRAP)
	await wait(0.18)
	return u.hp <= 0


# ---------------------------------------------------------------- player turn

func start_player_turn(first := false) -> void:
	for u in alive("p"):
		u.moved = false
		u.acted = false
		if not first:
			for k in u.cds:
				if u.cds[k] > 0:
					u.cds[k] -= 1
	busy = false
	mode = ""
	for u in units:
		u.rally = false
	if not first:
		_shaman_mend()
	select(lead())
	if first:
		say("The first heroes are through the gate. Move, attack, or wait for them to come to you.")
	elif queue.size() > 0:
		say("Your turn. %d more heroes are waiting at the gate." % queue.size())
	else:
		say("Your turn.")
	changed.emit()

## Spirit Lodge: every living shaman heals your units within 2 tiles, itself included.
func _shaman_mend() -> void:
	var amt := Data.shaman_mend(Game.lvl("lodge"))
	for s in alive("p"):
		if s.kind != "shaman":
			continue
		var any := false
		for u in alive("p"):
			if Game.man(s.pos, u.pos) <= 2 and u.hp < u.max_hp:
				var h := mini(amt, u.max_hp - u.hp)
				u.hp += h
				text(u.pos, "+%d" % h, Data.col("#9be27a"))
				any = true
		if any:
			ring(s.pos, Data.col("#b8c85a"), 2.0)

func select(u: Unit) -> void:
	sel = u
	mode = ""
	reach = reach_of(u) if u and not u.moved and not u.acted else {}
	if u:
		focus.emit(u.pos)
	changed.emit()

func handle_click(p: Vector2i) -> void:
	if not Game.in_b(p) or busy or over:
		return
	if mode != "":
		await cast_spell(spell(mode), p)
		return
	var u := unit_at(p)
	var s := sel
	if s and u and u.side == "h":
		if s.acted:
			say("%s has already acted this turn." % s.uname, true)
			return
		if not Game.in_range(s.pos, u.pos, s.rng):
			if Game.man(s.pos, u.pos) > s.rng:
				say("Out of range. %s reaches %d tile%s." % [s.uname, s.rng, "s" if s.rng > 1 else ""], true)
			else:
				say("Something is in the way.", true)
			return
		busy = true
		s.acted = true
		s.moved = true
		reach = {}
		await attack(s, u)
		busy = false
		after_action()
		return
	if u and u.side == "p":
		select(u)
		if u.acted and u.moved:
			say("%s is done for this turn." % u.uname)
		return
	if s and reach.has(p) and not reach[p].occ and reach[p].d > 0:
		var R := reach
		busy = true
		reach = {}
		await walk(s, path_to(R, p))
		s.moved = true
		busy = false
		focus.emit(s.pos)
		# the unit stays selected until it attacks or you finish it, so a stray click can't end it
		after_action()
		return
	# a click on nothing useful keeps the current unit selected instead of dropping it
	if s and not (s.moved and s.acted):
		say("%s is still selected. Click a blue tile, a hero ringed in red, or Finish this unit (F)." % s.uname)

## Ends one unit's turn without it doing anything more.
func finish_unit(u: Unit) -> void:
	if busy or over or u == null:
		return
	u.moved = true
	u.acted = true
	after_action()

## Your minions (and thralls) that can still move or attack this turn. The monster and the
## Squire are left to the player.
func idle_minions() -> Array:
	return alive("p").filter(func(u): return not is_mon(u) and not (u.moved and u.acted))

## The "AI moves" button: every minion that hasn't finished acts on its own, then the heroes go.
## Each one attacks the weakest hero it can hit; if none is in reach it steps to where it can hit
## one, or else walks as far toward the nearest hero as it can.
func auto_minions() -> void:
	if busy or over:
		return
	busy = true
	sel = null
	reach = {}
	mode = ""
	changed.emit()
	for u in idle_minions():
		if u.hp <= 0:
			continue
		if not u.moved:
			var dest := _auto_spot(u)
			if dest != u.pos:
				var R := reach_of(u)
				focus.emit(u.pos)
				await walk(u, path_to(R, dest))
			u.moved = true
		if not u.acted:
			var t := _weakest(targets_for(u))
			if t != null:
				await attack(u, t)
			u.acted = true
		if check_end():
			return
	busy = false
	await enemy_turn()

## The hero in the list with the least HP left, or null.
func _weakest(hs: Array) -> Unit:
	var best: Unit = null
	for h in hs:
		if best == null or h.hp < best.hp:
			best = h
	return best

## Where a minion should walk this turn: the closest tile it can attack from (favoring weak
## targets), or else the reachable tile nearest a hero on foot. Its own tile if nothing is better.
func _auto_spot(u: Unit) -> Vector2i:
	var hs := alive("h")
	if hs.is_empty():
		return u.pos
	var R := reach_of(u)
	var best := u.pos
	var best_score := INF
	for k in R:
		if R[k].occ:
			continue
		var weakest := 1 << 20
		for h in hs:
			if Game.in_range(k, h.pos, u.rng):
				weakest = mini(weakest, h.hp)
		if weakest < (1 << 20):
			var sc: float = weakest * 100 + R[k].d
			if sc < best_score:
				best_score = sc
				best = k
	if best_score < INF:
		return best
	# nobody in reach this turn: close in on the nearest hero
	var F := Game.field(hs.map(func(h): return h.pos))
	var best_d: int = F.get(u.pos, 1 << 20)
	for k in R:
		if R[k].occ:
			continue
		var d: int = F.get(k, 1 << 20)
		if d < best_d or (d == best_d and R[k].d < R[best].d):
			best_d = d
			best = k
	return best

func after_action() -> void:
	if check_end():
		return
	var s := sel
	if s and s.hp > 0 and s.side == "p" and not (s.moved and s.acted):
		select(s)
	else:
		var nxt: Unit = null
		for u in alive("p"):
			if not u.acted:
				nxt = u
				break
		select(nxt)
		if nxt == null:
			say("Everyone has acted. End your turn.")

func check_end() -> bool:
	if over:
		return true
	if mons_alive().is_empty():
		over = true
		_finish(false)
		return true
	if alive("h").is_empty() and queue.is_empty():
		over = true
		_finish(true)
		return true
	return false

func _finish(won: bool) -> void:
	await wait(0.6)
	finished.emit(won)


# ---------------------------------------------------------------- spells

func spell(id: String) -> Dictionary:
	for sp in all_specials():
		if sp.id == id:
			return sp
	return {}

## Every spell this run's monster side has: the monster's, plus the Squire's for a duo.
func all_specials() -> Array:
	return Game.M.specials + (Game.M.partner.specials if Game.duo() else [])

## The spells a unit casts. Minions have none.
func specials_of(u: Unit) -> Array:
	if u == null:
		return []
	if u.kind == "monster":
		return Game.M.specials
	if u.kind == "squire":
		return Game.M.partner.specials
	return []

func caster_of(sp: Dictionary) -> Unit:
	return squire if squire != null and sp in Game.M.partner.specials else mon

func spell_tiles(sp: Dictionary) -> Array:
	var m := caster_of(sp)
	var o := []
	var r: int = sp.get("range", 0)
	match sp.kind:
		"enemy":
			for h in alive("h"):
				if Game.in_range(m.pos, h.pos, r) and not (sp.id == "dominate" and h.d.get("boss", false) and Game.lvl("amplifier") < 2):
					o.append(h.pos)
		"ally":
			for u in alive("p"):
				if u != m and u.kind != "monster" and Game.in_range(m.pos, u.pos, r):
					o.append(u.pos)
		"adj":
			for dv in Game.DIRS:
				var p: Vector2i = m.pos + dv
				if Game.can_step(m.pos, p) and empty_tile(p):
					o.append(p)
		"corpse":
			for k in corpses:
				if Game.man(k, m.pos) <= r and empty_tile(k):
					o.append(k)
		_:
			for y in range(maxi(0, m.pos.y - r), mini(Game.BH - 1, m.pos.y + r) + 1):
				for x in range(maxi(0, m.pos.x - r), mini(Game.BW - 1, m.pos.x + r) + 1):
					var p := Vector2i(x, y)
					if Game.man(p, m.pos) > r or not Game.is_open(p):
						continue
					if sp.kind == "area" or sp.get("any", false):
						o.append(p)
					elif empty_tile(p) and not (sp.get("notrap", false) and Game.traps.has(p)):
						o.append(p)
	return o

func can_cast(sp: Dictionary) -> bool:
	var c := caster_of(sp)
	return not busy and c != null and c.hp > 0 and not c.acted and c.cds.get(sp.id, 0) <= 0

func arm_spell(id: String) -> void:
	var sp := spell(id)
	if not can_cast(sp):
		return
	if mode == id:
		mode = ""
		changed.emit()
		return
	var c := caster_of(sp)
	select(c)
	if sp.kind == "self":
		await cast_spell(sp, c.pos)
		return
	if spell_tiles(sp).is_empty():
		say("No valid target for %s right now." % sp.name, true)
		return
	mode = id
	reach = {}
	say("%s: click a highlighted tile. Pick the spell again to cancel." % sp.name)
	changed.emit()

func cast_spell(sp: Dictionary, p: Vector2i) -> void:
	var m := caster_of(sp)
	if sp.kind != "self" and not (p in spell_tiles(sp)):
		say("Pick one of the highlighted tiles.", true)
		return
	busy = true
	mode = ""
	reach = {}
	m.cds[sp.id] = cd_of(sp)
	if not sp.get("free", false):
		m.acted = true
		m.moved = true
	await _spell_effect(sp.id, m, p)
	await wait(0.18)
	busy = false
	if sp.get("free", false):
		m.moved = true
	after_action()

func _spell_effect(id: String, m: Unit, p: Vector2i) -> void:
	match id:
		"nova":
			ring(m.pos, Data.col("#a8d8ff"), 2.4)
			for h in alive("h"):
				if Game.man(m.pos, h.pos) <= 2 and Game.los(m.pos, h.pos):
					hurt(h, spell_dmg(4), m, true)
					h.slow = 1
			burst(m.pos, Data.col("#cfeaff"), 24)
		"chain":
			var cur := unit_at(p)
			var prev := m.pos
			var hit := {}
			var dmg := spell_dmg(6)
			for i in 3:
				if cur == null:
					break
				line(prev, cur.pos, Data.col("#bfe0ff"), true)
				hit[cur] = true
				hurt(cur, dmg, m, true)
				await wait(0.14)
				prev = cur.pos
				var nxt: Unit = null
				for h in alive("h"):
					if not hit.has(h) and Game.in_range(prev, h.pos, 2) and (nxt == null or Game.man(h.pos, prev) < Game.man(nxt.pos, prev)):
						nxt = h
				cur = nxt
				dmg = maxi(2, dmg - 1)
		"bats":
			burst(m.pos, Data.col("#2a1420"), 18)
			m.pos = p
			m.draw_pos = Vector2(p)
			burst(p, Data.col("#2a1420"), 18)
			focus.emit(p)
			Game.add_log("You scatter into bats and reform.")
		"mesmer":
			var h := unit_at(p)
			h.stun = 1
			line(m.pos, p, Data.col("#ff6080"), true)
			text(p, "mesmerized", Data.col("#ff9ab0"))
			Game.add_log("%s stares into your eyes and forgets to move." % h.uname)
		"raise":
			var s1 := mk_unit("p", "skeleton", p)
			s1.acted = true
			burst(p, Data.col("#e8dcc0"), 14)
			var extra := Data.soul_skeletons(Game.lvl("soulcage")) - 1
			for dv in Game.DIRS:
				if extra <= 0:
					break
				var q: Vector2i = m.pos + dv
				if Game.can_step(m.pos, q) and empty_tile(q):
					var s2 := mk_unit("p", "skeleton", q)
					s2.acted = true
					burst(q, Data.col("#e8dcc0"), 14)
					extra -= 1
			Game.add_log("The dead claw their way out of the floor.")
		"ghoul":
			corpses.erase(p)
			var g := mk_unit("p", "ghoul", p)
			g.acted = true
			g.moved = true
			burst(p, Data.col("#6fd3a0"), 18)
			Game.add_log("A fallen hero rises as your ghoul.")
		"dominate":
			var h := unit_at(p)
			h.side = "p"
			h.thrall = true
			h.moved = true
			h.acted = true
			h.root = 0
			h.stun = 0
			h.conf = 0
			h.flee = false
			line(m.pos, p, Data.col("#c77dff"), true)
			burst(p, Data.col("#c77dff"), 18)
			if h.stole > 0:
				Game.gold += h.stole
				stolen -= h.stole
				h.stole = 0
			_reward(h)
			text(p, "enthralled", Data.col("#e0b0ff"))
			Game.add_log("%s the %s now serves you." % [h.uname, h.d.name], "kill")
		"scream":
			ring(p, Data.col("#c77dff"), 1.6)
			for h in alive("h"):
				if absi(h.pos.x - p.x) <= 1 and absi(h.pos.y - p.y) <= 1:
					h.conf = 1
					hurt(h, 2 + Game.b.spell, m, true)
					text(h.pos, "confused", Data.col("#e0b0ff"))
			burst(p, Data.col("#c77dff"), 20)
		"lure":
			var F := Game.field([p])
			ring(p, Data.col("#ffd070"), 1.4)
			burst(p, Data.col("#ffd070"), 16)
			Game.add_log("Gold glitters. The heroes cannot help themselves.")
			var hs := alive("h")
			hs.sort_custom(func(a, c): return F.get(a.pos, 99) < F.get(c.pos, 99))
			for h in hs:
				for s in 2:
					if h.hp <= 0:
						break
					var cur: int = F.get(h.pos, 99)
					var nx = null
					for q in Game.steps(h.pos):
						if empty_tile(q) and F.get(q, 99) < cur:
							nx = q
							break
					if nx == null:
						break
					await walk(h, [nx])
					if h.root > 0:
						break
		"hex":
			var h := unit_at(p)
			h.hex = 2
			if Game.lvl("sanctum") >= 3:
				h.slow = 1
			line(m.pos, p, Data.col("#7d8cff"), true)
			text(p, "hexed", Data.col("#a8b4ff"))
		"ward":
			var u := unit_at(p)
			u.shield = 6
			ring(p, Data.col("#7d8cff"), 1.0)
			text(p, "warded", Data.col("#a8b4ff"))
		"challenge":
			var r: int = 3 if Game.lvl("trainingyard") >= 2 else 2
			ring(m.pos, Data.col("#a8aec8"), float(r) + 0.5)
			for h in alive("h"):
				if Game.man(h.pos, m.pos) <= r:
					h.taunt = m
					text(h.pos, "challenged", Data.col("#d0d4e8"))
			Game.add_log("%s bangs his blade on his shield. Come and get me." % m.uname)
		"rally":
			ring(m.pos, Data.col("#e4a648"), 3.5)
			for u in alive("p"):
				if not is_mon(u) and Game.man(u.pos, m.pos) <= 3:
					u.rally = true
					text(u.pos, "rallied", Data.col("#ffd070"))
		"snap":
			Game.traps[p] = "spikes"
			burst(p, Data.col("#e8dcc0"), 10)
			text(p, "click", Data.col("#e8dcc0"))

func collapse() -> void:
	var si := Game.slot_idx("collapse")
	if si < 0 or busy or used.has("collapse"):
		return
	used.collapse = true
	busy = true
	var l := Game.lvl("collapse")
	focus.emit(Game.slot_xy(si) * Game.RS + Vector2i(2, 2))
	for t in Game.slot_tiles(si):
		if randf() < 0.6:
			burst(t, Data.col("#8a7f90"), 4)
	shake = 0.45
	Game.add_log("The ceiling of the Collapsing Hall comes down.", "info")
	for u in units.duplicate():
		if u.hp > 0 and Game.slot_of(u.pos) == si:
			hurt(u, 8 + (l - 1) * 4, TRAP, true)
	await wait(0.3)
	busy = false
	after_action()


# ---------------------------------------------------------------- combat

func _reward(h: Unit) -> void:
	var g := Game.kill_gold(Game.veteran_gold(Game.day, h.d.gold))
	loot += g
	kills += 1
	Game.kills += 1
	Game.souls += 6 if h.d.get("boss", false) else 1
	text(h.pos + Vector2i(0, -1), "+%dg" % g, Data.col("#e4a648"))

func hurt(t: Unit, amt: int, src: Unit, magic := false) -> void:
	if t.hp <= 0:
		return
	var a := amt
	if src and src.d.get("holy", false) and is_unholy(t) and Game.type_at(src.pos) != "shrine":
		a += 3
	if t.hex > 0:
		a += 2 + Game.lvl("sanctum")
	var home := 1 if is_mon(t) and Game.type_at(t.pos) == "lair" else 0
	a = maxi(1, a - (0 if magic else t.armor) - home)
	if t.shield > 0:
		var soak := mini(t.shield, a)
		t.shield -= soak
		a -= soak
		text(t.pos + Vector2i(0, -1), "warded", Data.col("#a8b4ff"))
		if a <= 0:
			changed.emit()
			return
	t.hp -= a
	# Oath Stone level 2: a blow to one of the bonded pair heals the other
	if is_mon(t) and Game.lvl("oathstone") >= 2 and bonded():
		var other: Unit = squire if t == mon else mon
		other.hp = mini(other.max_hp, other.hp + Data.oath_heal(Game.lvl("oathstone")))
	t.flash = 0.15
	text(t.pos, "-%d" % a, Data.col("#ffd0c0") if t.side == "h" else Data.col("#ff7d8f"))
	if src and src.hp > 0 and t.side != src.side and ((src.kind == "monster" and Game.mk == "vampire") or src.d.get("leech", false)):
		var l := ceili(a / 3.0)
		src.hp = mini(src.max_hp, src.hp + l)
		text(src.pos, "+%d" % l, Data.col("#ff6080"))
	if t.hp > 0:
		changed.emit()
		return
	t.hp = 0
	if t.kind == "monster" and Game.lvl("phylactery") > 0 and not revived:
		revived = true
		t.hp = Data.phylactery_hp(Game.lvl("phylactery"))
		var si := Game.slot_idx("phylactery")
		var spots := [Game.slot_xy(si) * Game.RS + Vector2i(2, 2)] + Game.slot_tiles(si)
		for q in spots:
			if empty_tile(q):
				t.pos = q
				t.draw_pos = Vector2(q)
				focus.emit(q)
				break
		burst(t.pos, Data.col("#d6c8ff"), 30)
		text(t.pos, "reforms!", Data.col("#d6c8ff"))
		Game.add_log("Your phylactery flares. You reform from dust.", "info")
		changed.emit()
		return
	burst(t.pos, Data.col(t.d.get("col", "#88aa66")) if t.side == "h" else Data.col("#88aa66"), 16)
	if t.side == "h":
		_reward(t)
		corpses[t.pos] = true
		if t.stole > 0:
			Game.gold += t.stole
			stolen -= t.stole
			text(t.pos + Vector2i(0, 1), "+%dg back" % t.stole, Data.col("#e4a648"))
		var by := "your traps"
		if src == null or src == TRAP: by = "your traps"
		elif src.kind == "monster": by = "you"
		elif src.kind == "squire": by = "your Squire"
		elif src.side == "h": by = "a confused ally"
		else: by = "your " + ("thrall" if src.thrall else src.d.name.to_lower())
		Game.add_log("%s the %s was slain by %s." % [t.uname, t.d.name, by], "kill")
		if src and is_mon(src) and Game.b.feast > 0:
			src.hp = mini(src.max_hp, src.hp + Game.b.feast)
			text(src.pos, "+%d" % Game.b.feast, Data.col("#9be27a"))
		Platform.on_hero_slain(t.kind)
	elif is_mon(t) and mons_alive().size() > 0:
		Game.add_log("%s falls! %s fights on alone." % [t.uname, mons_alive()[0].uname], "bad")
	elif is_mon(t):
		Game.add_log("You fall.", "bad")
	else:
		Game.add_log("Your %s is cut down. It will not come back." % (("thrall " + t.uname) if t.thrall else t.d.name.to_lower()), "bad")
	changed.emit()

func attack(a: Unit, t: Unit) -> void:
	var c := Data.col(Game.M.col) if a.kind == "monster" else Data.col(Game.M.partner.col) if a.kind == "squire" else (Data.col("#c77dff") if a.d.get("magic", false) else Data.col("#d8f0a0") if a.side == "p" else (Data.col("#ff9a40") if a.d.get("splash", false) else Color.WHITE))
	line(a.pos, t.pos, c, a.rng > 1)
	a.lunge = Vector2(t.pos - a.pos) * 0.25
	a.lunge_t = 0.15
	await wait(0.11)
	var dmg := atk_of(a)
	# Doombolt and warlock bolts ignore armor
	hurt(t, dmg, a, (a.kind == "monster" and Game.mk == "darklord") or a.d.get("magic", false))
	if a.d.get("splash", false):
		ring(t.pos, Data.col("#ff9a40"), 1.2)
		for o in units.duplicate():
			if o != t and o.hp > 0 and o.side != a.side and Game.man(o.pos, t.pos) == 1:
				hurt(o, ceili(dmg / 2.0), a)
	await wait(0.16)


# ---------------------------------------------------------------- hero turn

func enemy_turn() -> void:
	if busy or over:
		return
	busy = true
	sel = null
	reach = {}
	mode = ""
	say("")
	changed.emit()
	var Fm := Game.field(mons_alive().map(func(u): return u.pos))
	var heroes := alive("h")
	heroes.sort_custom(func(a, c): return Fm.get(a.pos, 99) < Fm.get(c.pos, 99))
	for h in heroes:
		if h.hp <= 0 or h.side != "h":
			continue
		focus.emit(h.pos)
		await hero_act(h)
		if check_end():
			return
		await wait(0.06)
	for h in alive("h"):
		if h.slow > 0: h.slow -= 1
		if h.conf > 0: h.conf -= 1
		if h.hex > 0: h.hex -= 1
	if queue.size() > 0:
		admit(2)
	turn += 1
	start_player_turn()

func hero_act(h: Unit) -> void:
	# a snare sprung during this turn holds the hero through its next one
	var rooted := h.root > 0
	await hero_turn(h)
	if rooted:
		h.root = 0

func hero_turn(h: Unit) -> void:
	var D := h.d
	if Game.type_at(h.pos) == "torture":
		text(h.pos, "tortured", Data.col("#ff8090"))
		hurt(h, 2 + Game.lvl("torture"), TRAP, true)
		if h.hp <= 0:
			return
	if Game.type_at(h.pos) == "shrine" and D.get("holy", false):
		text(h.pos, "desecrated", Data.col("#b08ad0"))
		hurt(h, Game.lvl("shrine"), TRAP, true)
		if h.hp <= 0:
			return
	var drown := Data.cistern_drown(Game.lvl("cistern"))
	if Game.type_at(h.pos) == "cistern" and drown > 0:
		text(h.pos, "drowning", Data.col("#7fc0ff"))
		hurt(h, drown, TRAP, true)
		if h.hp <= 0:
			return
	if h.stun > 0:
		h.stun -= 1
		text(h.pos, "...", Data.col("#ff9ab0"))
		await wait(0.18)
		return
	if h.conf > 0:
		var foe: Unit = null
		for o in alive("h"):
			if o != h and (foe == null or Game.man(h.pos, o.pos) < Game.man(h.pos, foe.pos)):
				foe = o
		if foe:
			text(h.pos, "?!", Data.col("#e0b0ff"))
			await approach(h, Game.field([foe.pos]), foe, h.rng)
			if h.hp <= 0:
				return
			if Game.in_range(h.pos, foe.pos, h.rng):
				await attack(h, foe)
			return
	# sappers spend their whole turn taking apart one trap next to them
	if D.get("disarm", false) and await _disarm(h):
		return
	# clerics can't heal anyone inside the Shrine of Desecration, or while standing in it
	if D.get("heal", 0) > 0 and Game.type_at(h.pos) != "shrine":
		var hurt_ally: Unit = null
		for o in alive("h"):
			if o != h and o.hp < o.max_hp and Game.type_at(o.pos) != "shrine" and (hurt_ally == null or float(o.hp) / o.max_hp < float(hurt_ally.hp) / hurt_ally.max_hp):
				hurt_ally = o
		if hurt_ally and Game.man(h.pos, hurt_ally.pos) <= move_of(h) + 3:
			await approach(h, Game.field([hurt_ally.pos]), hurt_ally, 3)
			if h.hp <= 0:
				return
			if Game.in_range(h.pos, hurt_ally.pos, 3):
				var amt := mini(D.heal, hurt_ally.max_hp - hurt_ally.hp)
				hurt_ally.hp += amt
				text(hurt_ally.pos, "+%d" % amt, Data.col("#9be27a"))
				ring(h.pos, Data.col("#f4ecd0"), 1.0)
				Game.add_log("%s heals %s." % [h.uname, hurt_ally.uname])
				await wait(0.22)
				return
	# thieves rob the treasury, then run for the gate
	var tsi := Game.slot_idx("treasury")
	if D.get("thief", false) and not h.flee and tsi >= 0:
		var tiles := Game.slot_tiles(tsi).filter(func(t): return Game.is_open(t))
		await approach(h, Game.field(tiles), null, 0)
		if h.hp <= 0:
			return
		if Game.slot_of(h.pos) == tsi:
			var amt := mini(Game.gold, 10 + Game.lvl("treasury") * 8)
			Game.gold -= amt
			h.stole = amt
			stolen += amt
			h.flee = true
			text(h.pos, "-%dg" % amt, Data.col("#e4a648"))
			Game.add_log("%s stuffs %d gold into a sack and runs." % [h.uname, amt], "bad")
		await strike_nearby(h)
		return
	if h.flee:
		await approach(h, Game.field([Game.entrance]), null, 0)
		if h.hp <= 0:
			return
		if h.pos == Game.entrance:
			h.hp = 0
			h.escaped = true
			escaped += 1
			Game.add_log("%s escapes with %d of your gold." % [h.uname, h.stole], "bad")
			text(h.pos, "escaped", Data.col("#ff9a8a"))
		return
	var ps := alive("p")
	if ps.is_empty():
		return
	var Fh := Game.field([h.pos])
	# walled off from all of your units: shoot anything in sight, or smash a way through
	var open_to := ps.filter(func(u): return Fh.has(u.pos))
	if open_to.is_empty():
		for p in ps:
			if Game.in_range(h.pos, p.pos, h.rng):
				await attack(h, p)
				return
		await smash_way(h, Fh, ps)
		return
	ps = open_to
	var target: Unit
	var taunt: Unit = h.taunt
	h.taunt = null
	if taunt != null and taunt.hp > 0 and Fh.has(taunt.pos):
		target = taunt
	elif D.get("sense", false) and not D.get("disarm", false):
		ps.sort_custom(func(a, c): return a.hp < c.hp or (a.hp == c.hp and Fh.get(a.pos, 99) < Fh.get(c.pos, 99)))
		target = ps[0]
	elif Game.mk == "mimic" and Fh.has(mon.pos):
		target = mon
	else:
		ps.sort_custom(func(a, c): return _closer(a, c, Fh))
		target = ps[0]
	await approach(h, Game.field([target.pos]), target, h.rng)
	if h.hp <= 0:
		return
	if h.dazed:
		h.dazed = false
		return
	var t: Unit = target if Game.in_range(h.pos, target.pos, h.rng) else null
	if t == null:
		for p in alive("p"):
			if Game.in_range(h.pos, p.pos, h.rng):
				t = p
				break
	if t:
		await attack(h, t)
		if t.kind == "monster":
			Game.mhp = t.hp
		elif t.kind == "squire":
			Game.shp = t.hp

## A hero with no path to any of your units heads for the piece of furniture whose loss opens
## the shortest way to you, and hits it if it gets there this turn.
func smash_way(h: Unit, Fh: Dictionary, ps: Array) -> void:
	var Ft := Game.field(ps.map(func(u): return u.pos), true)
	var best = null
	var stand = null
	var bs := 1 << 30
	for k in Game.obj:
		if not Game.breakable(k) or not Ft.has(k):
			continue
		for d in Game.DIRS:
			var s: Vector2i = k + d
			if Fh.has(s) and not Game.wall_between(s, k) and Fh[s] + Ft[k] < bs:
				bs = Fh[s] + Ft[k]
				best = k
				stand = s
	if best == null:
		return
	if Game.man(h.pos, best) != 1 or Game.wall_between(h.pos, best):
		await approach(h, Game.field([stand]), null, 0)
		if h.hp <= 0:
			return
	if h.dazed:
		h.dazed = false
		return
	if Game.man(h.pos, best) == 1 and not Game.wall_between(h.pos, best):
		await smash(h, best)

## One hero blow against a piece of furniture.
func smash(h: Unit, k: Vector2i) -> void:
	var kind: String = Game.obj[k].kind
	line(h.pos, k, Color.WHITE, false)
	h.lunge = Vector2(k - h.pos) * 0.25
	h.lunge_t = 0.15
	await wait(0.11)
	var dmg := atk_of(h)
	var left: int = decor_hp.get(k, Data.decor_hp(kind)) - dmg
	text(k, "-%d" % dmg, Data.col("#e8dcc0"))
	if left <= 0:
		decor_hp.erase(k)
		Game.break_decor(k)
		smashed += 1
		burst(k, Data.col("#8a7f90"), 16)
		shake = 0.2
		Game.add_log("%s smashes your %s." % [h.uname, Data.decor_name(kind)], "bad")
	else:
		decor_hp[k] = left
	changed.emit()
	await wait(0.16)

## A sapper dismantles one trap in the 3x3 around it, for good. Returns false if none is there.
func _disarm(h: Unit) -> bool:
	var pick = null
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var k: Vector2i = h.pos + Vector2i(dx, dy)
			# armed traps first; a sprung one is still worth wrecking before it re-arms
			if Game.traps.has(k) and (pick == null or (armed(k) and not armed(pick))):
				pick = k
	if pick == null:
		return false
	var t: String = Game.traps[pick]
	Game.traps.erase(pick)
	sprung.erase(pick)
	h.lunge = Vector2(pick - h.pos) * 0.25
	h.lunge_t = 0.15
	text(pick, "disarmed", Data.col("#e0c080"))
	Game.add_log("%s spends the turn prying apart your %s." % [h.uname, Data.TRAPS[t].name.to_lower()], "bad")
	await wait(0.22)
	return true

## Sort order for hero targets: nearest by walking distance, ties go to the monster.
func _closer(a: Unit, c: Unit, F: Dictionary) -> bool:
	var da: int = F.get(a.pos, 99)
	var dc: int = F.get(c.pos, 99)
	return da < dc or (da == dc and is_mon(a) and not is_mon(c))

func strike_nearby(h: Unit) -> void:
	for p in alive("p"):
		if Game.in_range(h.pos, p.pos, h.rng):
			await attack(h, p)
			return

func _best_step(h: Unit, F: Dictionary, target: Unit, r: int, avoid: bool) -> Dictionary:
	var R := reach_of(h, avoid)
	var best = null
	var bs := -INF
	for k in R:
		if R[k].occ:
			continue
		var s: float
		if target and Game.in_range(k, target.pos, r):
			s = 1000 + (Game.man(k, target.pos) * 5 if r > 1 else 0) - R[k].d
		else:
			s = -F.get(k, 999) * 10 - R[k].d
		if s > bs:
			bs = s
			best = k
	return {"R": R, "best": best, "bs": bs}

func approach(h: Unit, F: Dictionary, target: Unit, r: int) -> void:
	var res := _best_step(h, F, target, r, spots_traps(h))
	# trap-wary heroes walk over traps when there is no other way forward
	if spots_traps(h) and res.best == h.pos and res.bs < 1000 and F.get(res.best, 999) > 0:
		res = _best_step(h, F, target, r, false)
	if res.best != null and res.best != h.pos:
		await walk(h, path_to(res.R, res.best))


# ---------------------------------------------------------------- results

## Applies a won night to the run and returns a summary for the boon screen.
func resolve_win() -> Dictionary:
	# a fallen duo member stays down until bought back with souls
	Game.mhp = maxi(1, mon.hp) if mon.hp > 0 or squire == null else 0
	if squire != null:
		Game.shp = squire.hp
		for e in [["lord", mon], ["squire", squire]]:
			if e[1].hp <= 0 and not e[0] in Game.down:
				Game.down.append(e[0])
	Game.gold += loot
	var lost := []
	for m in Game.minions:
		var alive_now := false
		for u in units:
			if u.mid == m.mid and u.hp > 0:
				alive_now = true
		if not alive_now:
			lost.append(m)
	for m in lost:
		Game.minions.erase(m)
	Game.meta.best = maxi(Game.meta.best, Game.day)
	Game.save_meta()
	if smashed > 0:
		Game.add_log("Heroes smashed %d piece%s of furniture. Repair it by day from each room's panel." % [smashed, "s" if smashed > 1 else ""], "bad")
	Game.add_log("Night %d survived. You loot %d gold.%s%s" % [Game.day, loot,
		(" %d minion%s lost." % [lost.size(), "s" if lost.size() > 1 else ""]) if lost.size() > 0 else "",
		(" %d thief escaped." % escaped) if escaped > 0 else ""], "info")
	return {"kills": kills, "loot": loot, "stolen": stolen, "lost": lost.size()}


# ---------------------------------------------------------------- effects

func line(a: Vector2i, c: Vector2i, col: Color, ranged := false) -> void:
	var t := 0.25 if ranged else 0.12
	fx.append({"kind": "line", "a": a, "b": c, "col": col, "t": t, "max": t})

func ring(p: Vector2i, col: Color, r := 1.6) -> void:
	fx.append({"kind": "ring", "a": p, "col": col, "r": r, "t": 0.45, "max": 0.45})

func burst(p: Vector2i, col: Color, n: int) -> void:
	for i in n:
		var ang := randf() * TAU
		var sp := 0.8 + randf() * 2.4
		parts.append({"p": Vector2(p) + Vector2(0.5, 0.5), "v": Vector2(cos(ang), sin(ang)) * sp, "col": col, "t": 0.5 + randf() * 0.4})

func text(p: Vector2i, s: String, col: Color) -> void:
	texts.append({"p": Vector2(p) + Vector2(0.5, 0.2), "s": s, "col": col, "t": 1.0})
