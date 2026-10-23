extends Node
## Run state, dungeon geometry and every day-phase action. Autoloaded as `Game`.

signal changed
signal logged
signal tipped(text: String, warn: bool)

const SW := 5
const SH := 4
const RS := 5
const BW := SW * RS
const BH := SH * RS
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const META_PATH := "user://meta.json"

var meta := {"souls": 0, "hoard": 0, "best": 0}
## Skips animation waits. The headless tests turn this on.
var fast := false

var mk := ""
var M := {}
var day := 1
var hours := 3
var gold := 0
var mhp := 0
var mmax := 0
var souls := 0
var kills := 0
var logs := []
var taken := []
var b := {}
var slots := []
var traps := {}      # Vector2i -> trap type
var minions := []    # {mid, kind, home, post, free}
var obj := {}        # Vector2i -> {kind, block}
var entrance := Vector2i(12, 0)
var party := []
var sel := -1
var sel_minion = null
var trap_mode := ""
var ent_mode := false
var _uid := 0


func _ready() -> void:
	load_meta()


func next_id() -> int:
	_uid += 1
	return _uid


# ---------------------------------------------------------------- meta progression

func load_meta() -> void:
	if not FileAccess.file_exists(META_PATH):
		return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for k in d:
			meta[k] = int(d[k])


func save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))


# ---------------------------------------------------------------- run setup

func new_run(key: String) -> void:
	mk = key
	M = Data.MONSTERS[key]
	day = 1
	hours = 3
	gold = 70 + meta.hoard * 20
	mhp = M.hp
	mmax = M.hp
	souls = 0
	kills = 0
	logs = []
	taken = []
	b = {"atk": 0, "spell": 0, "move": 0, "minion": 0, "feast": 0, "cd": 0, "greed": 0.0, "trap": 0, "hours": 0}
	slots = []
	for i in SW * SH:
		slots.append({"state": "rock"})
	traps = {}
	minions = []
	entrance = Vector2i(2 * RS + 2, 0)
	slots[2] = {"state": "dug"}
	slots[7] = {"state": "dug"}
	slots[12] = {"state": "built", "type": "lair", "lvl": 1}
	rebuild_objs()
	sel = 12
	sel_minion = null
	trap_mode = ""
	ent_mode = false
	party = make_party(1)
	add_log("%s has claimed a damp cave. The village has noticed." % M.name, "info")
	changed.emit()


func make_party(d: int) -> Array:
	var size: int = mini(9, 3 + int(d * 0.6))
	var pool := ["peasant", "peasant", "peasant"]
	if d >= 2: pool += ["rogue", "archer"]
	if d >= 3: pool += ["knight", "sapper"]
	if d >= 4: pool += ["cleric"]
	if d >= 6: pool += ["mage", "barbarian", "knight"]
	if d >= 8: pool = pool.slice(3)
	var list := []
	for i in size:
		list.append(pool.pick_random())
	if d % 5 == 0: list[0] = "paladin"
	if d % 10 == 0 and list.size() > 1: list[1] = "paladin"
	return list


func lvl(t: String) -> int:
	for s in slots:
		if s.get("type", "") == t:
			return s.lvl
	return 0


# ---------------------------------------------------------------- geometry

func in_b(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < BW and p.y < BH

func slot_of(p: Vector2i) -> int:
	return (p.y / RS) * SW + (p.x / RS)

func slot_xy(si: int) -> Vector2i:
	return Vector2i(si % SW, si / SW)

func slot_tiles(si: int) -> Array:
	var o := slot_xy(si) * RS
	var out := []
	for y in RS:
		for x in RS:
			out.append(o + Vector2i(x, y))
	return out

func is_floor(p: Vector2i) -> bool:
	return in_b(p) and slots[slot_of(p)].state != "rock"

func blocked(p: Vector2i) -> bool:
	return obj.has(p) and obj[p].block

func is_open(p: Vector2i) -> bool:
	return is_floor(p) and not blocked(p)

func type_at(p: Vector2i) -> String:
	return slots[slot_of(p)].get("type", "") if in_b(p) else ""

func slot_idx(t: String) -> int:
	for i in slots.size():
		if slots[i].get("type", "") == t:
			return i
	return -1

func on_border(p: Vector2i) -> bool:
	return p.x == 0 or p.y == 0 or p.x == BW - 1 or p.y == BH - 1

func man(a: Vector2i, c: Vector2i) -> int:
	return absi(a.x - c.x) + absi(a.y - c.y)

func wall_between(a: Vector2i, c: Vector2i) -> bool:
	if not is_floor(c):
		return true
	if slot_of(a) == slot_of(c):
		return false
	# doorways are the middle three tiles of each shared wall
	var l: int = (a.y % RS) if a.x != c.x else (a.x % RS)
	return l < 1 or l > 3

func can_step(a: Vector2i, c: Vector2i) -> bool:
	return is_open(a) and is_open(c) and not wall_between(a, c)

func los(a: Vector2i, c: Vector2i) -> bool:
	var n: int = maxi(1, man(a, c) * 3)
	var p := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var q := Vector2i(roundi(lerpf(a.x, c.x, t)), roundi(lerpf(a.y, c.y, t)))
		if q == p:
			continue
		if q.x != p.x and q.y != p.y:
			var c1 := Vector2i(q.x, p.y)
			var c2 := Vector2i(p.x, q.y)
			if not ((can_step(p, c1) and can_step(c1, q)) or (can_step(p, c2) and can_step(c2, q))):
				return false
		elif not can_step(p, q):
			return false
		p = q
	return true

func in_range(a: Vector2i, c: Vector2i, r: int) -> bool:
	return man(a, c) <= r and los(a, c)

## Walking distance from every source tile to every reachable tile.
func field(srcs: Array) -> Dictionary:
	var F := {}
	var q := []
	for s in srcs:
		if not F.has(s):
			F[s] = 0
			q.append(s)
	var i := 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if F.has(n) or not can_step(c, n):
				continue
			F[n] = F[c] + 1
			q.append(n)
	return F

func slot_neighbors(si: int) -> Array:
	var s := slot_xy(si)
	var o := []
	if s.x > 0: o.append(si - 1)
	if s.x < SW - 1: o.append(si + 1)
	if s.y > 0: o.append(si - SW)
	if s.y < SH - 1: o.append(si + SW)
	return o

func rebuild_objs() -> void:
	obj = {}
	for si in slots.size():
		var s: Dictionary = slots[si]
		if s.state == "rock":
			continue
		var objs: Array = Data.ROOMS[s.type].objs if s.state == "built" else Data.EMPTY_OBJS
		var o := slot_xy(si) * RS
		for e in objs:
			obj[o + Vector2i(e[0], e[1])] = {"kind": e[2], "block": e.size() > 3 and e[3] == 1}
	for k in traps.keys():
		if not is_open(k):
			gold += trap_cost(traps[k]) / 2
			traps.erase(k)


# ---------------------------------------------------------------- day actions

func tip(msg: String, warn := false) -> void:
	tipped.emit(msg, warn)

func add_log(msg: String, kind := "") -> void:
	logs.push_front({"msg": msg, "kind": kind})
	if logs.size() > 8:
		logs.resize(8)
	logged.emit()

func diggable(si: int) -> bool:
	if slots[si].state != "rock":
		return false
	for n in slot_neighbors(si):
		if slots[n].state != "rock":
			return true
	return false

func dig_cost() -> int:
	var n := 0
	for s in slots:
		if s.state != "rock":
			n += 1
	return 10 + 5 * n

func spend(g: int, h := 1) -> bool:
	if hours < h:
		tip("No hours left today. Let night fall.", true)
		return false
	if gold < g:
		tip("You need %d gold." % g, true)
		return false
	hours -= h
	gold -= g
	return true

func _layout_changed() -> void:
	rebuild_objs()
	fix_posts()
	changed.emit()

func dig(si: int) -> void:
	if not diggable(si) or not spend(dig_cost()):
		return
	slots[si] = {"state": "dug"}
	add_log("Your servants dig out a new chamber.")
	_layout_changed()

func can_build(t: String) -> bool:
	var R: Dictionary = Data.ROOMS[t]
	return not R.get("fixed", false) and lvl(t) == 0 and (not R.has("owner") or R.owner == mk)

func build(si: int, t: String) -> void:
	if slots[si].state != "dug" or not can_build(t) or not spend(Data.ROOMS[t].cost[0]):
		return
	slots[si] = {"state": "built", "type": t, "lvl": 1}
	if t == "coffin":
		mmax += 8
		mhp += 8
	add_log("You build a %s." % Data.ROOMS[t].name)
	_layout_changed()

func upgrade(si: int) -> void:
	var s: Dictionary = slots[si]
	var R: Dictionary = Data.ROOMS[s.type]
	if s.lvl >= R.cost.size() or not spend(R.cost[s.lvl]):
		return
	s.lvl += 1
	var hp := 6 if s.type == "lair" else (8 if s.type == "coffin" else 0)
	mmax += hp
	mhp += hp
	add_log("Your %s grows to level %d." % [R.name, s.lvl])
	changed.emit()

func demolish(si: int) -> void:
	var s: Dictionary = slots[si]
	if Data.ROOMS[s.type].get("fixed", false):
		return
	for m in minions:
		if m.home == si and not m.free:
			tip("Lose the minions housed here first.", true)
			return
	if not spend(0):
		return
	add_log("You tear down the %s." % Data.ROOMS[s.type].name)
	if s.type == "coffin":
		mmax -= 8 * s.lvl
		mhp = mini(mhp, mmax)
	slots[si] = {"state": "dug"}
	_layout_changed()

func move_lair(si: int) -> void:
	if slots[si].state != "dug" or not spend(0):
		return
	var old := slot_idx("lair")
	var o: Dictionary = slots[old]
	slots[old] = {"state": "dug"}
	slots[si] = o
	sel = si
	add_log("You drag your throne to a new lair.")
	_layout_changed()

func move_entrance(p: Vector2i) -> void:
	if not is_open(p) or not on_border(p):
		tip("The entrance must be an open floor tile on the outer edge of your dungeon.", true)
		return
	if p == entrance:
		ent_mode = false
		changed.emit()
		return
	if not spend(0):
		return
	if traps.has(p):
		gold += trap_cost(traps[p]) / 2
		traps.erase(p)
	entrance = p
	ent_mode = false
	fix_posts()
	add_log("You seal the old cave mouth and break open a new one.")
	changed.emit()


# ---------------------------------------------------------------- traps

func trap_cost(t: String) -> int:
	var c: int = Data.TRAPS[t].cost
	return ceili(c / 2.0) if mk == "mimic" else c

func trap_unlocked(t: String) -> bool:
	var w := lvl("workshop")
	match t:
		"spikes": return w >= 1 or mk == "mimic"
		"snare": return w >= 2 or lvl("snareden") > 0
	return w >= 3 or lvl("runes") > 0

func trap_cap() -> int:
	var w := lvl("workshop")
	var c := (3 + w * 3) if w > 0 else 0
	if mk == "mimic":
		c += 6 + lvl("snareden") * 3 + lvl("runes") * 2
	return c

func trap_dmg(t: String) -> int:
	var cw: int = lvl("clockwork") * 2 + b.trap
	match t:
		"spikes": return 3 + lvl("workshop") + cw
		"snare": return 2 + cw
	return 6 + maxi(1, lvl("runes")) * 3 + cw

func place_trap(p: Vector2i) -> void:
	if traps.has(p):
		gold += trap_cost(traps[p]) / 2
		traps.erase(p)
		changed.emit()
		return
	if not is_open(p):
		tip("Traps go on open floor, not on furniture.", true)
		return
	if p == entrance:
		tip("The heroes would spot a trap right in the doorway.", true)
		return
	if traps.size() >= trap_cap():
		tip("You have room for %d traps. Upgrade your trap rooms for more." % trap_cap(), true)
		return
	var c := trap_cost(trap_mode)
	if gold < c:
		tip("A %s costs %d gold." % [Data.TRAPS[trap_mode].name.to_lower(), c], true)
		return
	gold -= c
	traps[p] = trap_mode
	changed.emit()


# ---------------------------------------------------------------- minions

func recruit_room(kind: String) -> String:
	for t in Data.ROOMS:
		if Data.ROOMS[t].get("recruit", "") == kind:
			return t
	return ""

func cap_of(kind: String) -> int:
	var t := recruit_room(kind)
	return Data.ROOMS[t].cap * lvl(t) if t != "" else 0

func count_of(kind: String) -> int:
	var n := 0
	for m in minions:
		if m.kind == kind and not m.free:
			n += 1
	return n

func monster_start() -> Vector2i:
	return slot_xy(slot_idx("lair")) * RS + Vector2i(2, 1)

func post_ok(p: Vector2i, skip = null) -> bool:
	if not is_open(p) or p == entrance or p == monster_start():
		return false
	for m in minions:
		if m != skip and m.post == p:
			return false
	return true

func free_post_in(si: int):
	var t := []
	for p in slot_tiles(si):
		if post_ok(p):
			t.append(p)
	return t.pick_random() if t.size() > 0 else null

func add_minion(kind: String, free := false) -> bool:
	var home := slot_idx("lair") if free else slot_idx(recruit_room(kind))
	var post = free_post_in(home)
	var i := 0
	while post == null and i < slots.size():
		if slots[i].state != "rock":
			post = free_post_in(i)
		i += 1
	if post == null:
		return false
	minions.append({"mid": next_id(), "kind": kind, "home": home, "post": post, "free": free})
	return true

func recruit(kind: String) -> void:
	if count_of(kind) >= cap_of(kind):
		tip("That room is full. Upgrade it to house more.", true)
		return
	var c: int = Data.UNITS[kind].cost
	if gold < c:
		tip("A %s costs %d gold." % [Data.UNITS[kind].name.to_lower(), c], true)
		return
	if add_minion(kind):
		gold -= c
		add_log("A %s answers your call." % Data.UNITS[kind].name.to_lower())
	changed.emit()

func fix_posts() -> void:
	for m in minions:
		if not post_ok(m.post, m):
			var home: int = m.home if m.home >= 0 and slots[m.home].state != "rock" else slot_idx("lair")
			var p = free_post_in(home)
			if p != null:
				m.post = p

func minion_at(p: Vector2i):
	for m in minions:
		if m.post == p:
			return m
	return null

## A click on the board during the day.
func day_click(p: Vector2i) -> void:
	if not in_b(p):
		return
	if ent_mode:
		move_entrance(p)
		return
	if trap_mode != "":
		place_trap(p)
		return
	if sel_minion != null:
		var m = sel_minion
		sel_minion = null
		if post_ok(p, m):
			m.post = p
			tip("Post moved.")
		else:
			tip("Posts go on open floor, away from the throne and the entrance.", true)
		changed.emit()
		return
	var m2 = minion_at(p)
	if m2 != null:
		sel_minion = m2
		changed.emit()
		return
	sel = slot_of(p)
	changed.emit()


# ---------------------------------------------------------------- boons and dawn

func boon_ok(id: String) -> bool:
	match id:
		"rituals": return b.cd < 1
		"owl": return b.hours < 2
	return true

func apply_boon(id: String) -> void:
	match id:
		"hide":
			mmax += 6
			mhp = mini(mmax, mhp + 6)
		"claws": b.atk += 2
		"surge": b.spell += 2
		"swift": b.move += 1
		"pack": b.minion += 1
		"feast": b.feast += 3
		"rituals": b.cd += 1
		"greed": b.greed += 0.5
		"jagged": b.trap += 3
		"owl": b.hours += 1
		"press": add_minion("goblin", true)

func boon_choices() -> Array:
	var avail := []
	for o in Data.BOONS:
		if boon_ok(o.id):
			avail.append(o)
	avail.shuffle()
	return avail.slice(0, 3)

func dawn(boon: Dictionary) -> void:
	day += 1
	if not boon.is_empty():
		apply_boon(boon.id)
		taken.append(boon.name)
	var tg: int = [0, 12, 20, 30][lvl("treasury")]
	var heal: int = [0, 6, 10, 15][lvl("larder")]
	gold += tg + 10
	mhp = mini(mmax, mhp + heal)
	hours = 3 + b.hours
	party = make_party(day)
	add_log("Dawn of day %d. Terrified villagers leave 10 gold at the cave mouth.%s%s" % [day,
		(" Treasury: +%d gold." % tg) if tg > 0 else "", (" Larder: +%d HP." % heal) if heal > 0 else ""], "info")
	changed.emit()

func end_run() -> int:
	var earned := souls + day * 2
	meta.souls += earned
	meta.best = maxi(meta.best, day - 1)
	save_meta()
	return earned
