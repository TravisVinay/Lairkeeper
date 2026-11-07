extends Node
## Run state, dungeon geometry and every day-phase action. Autoloaded as `Game`.

signal changed
signal logged
signal tipped(text: String, warn: bool)

const SW := 5
const SH := 4
const RS := 5
const BW := SW * RS
const BH := SH * RS          # tile rows per floor
const FLOOR_SLOTS := SW * SH
## Nights between boss nights; Restless Crusade makes it 4. See boss_every().
const BOSS_EVERY := 5
## A dark boon is earned every this many nights survived (not tied to Restless Crusade).
const BOON_EVERY := 5
## Dread modifiers unlock once a run has survived this many nights (that is, reached night 5).
const MODS_UNLOCK_BEST := 4
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Meta progress (souls, unlocks, records). Playtest builds keep their own files; see _ready().
var meta_path := "user://meta.json"
## Where the run in progress is saved. Tests point it elsewhere.
var run_path := "user://run.save"
## Everything a run needs to resume. Layout, furniture and stairs are rebuilt from slots.
const RUN_KEYS := ["mk", "day", "hours", "gold", "mhp", "mmax", "souls", "kills", "logs", "taken", "b",
	"slots", "traps", "minions", "entrance", "floors", "bosses", "party", "_uid", "tut", "mods", "future", "fallen", "shp", "smax", "down"]

var meta := {"souls": 0, "hoard": 0, "best": 0, "rooms": []}
## The Dread modifiers this run was started with (ids from Data.MODS).
var mods := []
## Skips animation waits and saving. The headless tests turn this on.
var fast := false
## Keeps animations but never writes saves. The screenshot scene turns this on.
var no_save := false

var mk := ""
var M := {}
var day := 1
var hours := 3
var gold := 0
var mhp := 0
var mmax := 0
## The Dark Lord's Squire: his HP between nights. Only used when the monster has a partner.
var shp := 0
var smax := 0
## Duo members who fell and have not been bought back yet: "lord" and/or "squire".
var down := []
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
## Floors are stacked in one coordinate space: floor f covers tile rows f*BH to f*BH+BH-1.
## Floor 0 is the ground floor with the surface entrance; higher indexes are higher up the tower.
var floors := 1
var bosses := 0              # boss nights survived; each one allows one more floor
var links := {}              # Vector2i -> Vector2i, the stairs between floors
var stairs_shut := 0         # turns left with every staircase collapsed
var party := []
var future := []     # the raiders of the next nights, so the Scrying Pool can show them
var fallen := []     # kinds of the minions that died last night, for the Stitching Room
var sel := -1
var sel_minion = null
var trap_mode := ""
var ent_mode := false
var decor_room := -1      # room whose furniture is being rearranged, or -1
var decor_pick = null     # tile of the piece picked up in that room
var _uid := 0
## The tutorial step this run is on, or -1 for a normal run. Saved with the run.
var tut := -1
## Set by the tutorial: decides whether an action like "build:7:barracks" may happen now.
## Empty means everything is allowed.
var gate := Callable()


func _ready() -> void:
	# exports tagged "playtest" (the Windows preset) save apart from the editor, so a playtest
	# copy always starts fresh with 0 souls, even on the developer's own machine
	if OS.has_feature("playtest"):
		meta_path = "user://playtest_meta.json"
		run_path = "user://playtest_run.save"
	load_meta()


func next_id() -> int:
	_uid += 1
	return _uid


# ---------------------------------------------------------------- meta progression

func load_meta() -> void:
	if not FileAccess.file_exists(meta_path):
		return
	var f := FileAccess.open(meta_path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for k in d:
			meta[k] = d[k] if d[k] is Array else int(d[k])


func save_meta() -> void:
	if fast or no_save:
		return   # tests must never touch the player's save
	var f := FileAccess.open(meta_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))


## Wipes souls, unlocks and any run in progress.
func reset_meta() -> void:
	meta = {"souls": 0, "hoard": 0, "best": 0, "rooms": []}
	save_meta()
	clear_run()


# ---------------------------------------------------------------- run saving
# The run is saved by day only. Quitting mid-night resumes at dusk of that night.

func has_run() -> bool:
	return FileAccess.file_exists(run_path) and not run_summary().is_empty()

func save_run() -> void:
	if fast or no_save or mk == "":
		return
	var d := {}
	for k in RUN_KEYS:
		d[k] = get(k)
	var f := FileAccess.open(run_path, FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(d))

func _read_run() -> Dictionary:
	if not FileAccess.file_exists(run_path):
		return {}
	var d = str_to_var(FileAccess.get_file_as_string(run_path))
	if not d is Dictionary or not Data.MONSTERS.has(d.get("mk", "")):
		return {}
	return d

## Monster and night of the saved run, for the Continue button. Empty if there is none.
func run_summary() -> Dictionary:
	var d := _read_run()
	return {} if d.is_empty() else {"mk": d.mk, "day": d.get("day", 1)}

func load_run() -> bool:
	var d := _read_run()
	if d.is_empty():
		return false
	mods = []        # keys an older save may lack
	future = []
	fallen = []
	shp = 0
	smax = 0
	down = []
	for k in RUN_KEYS:
		if d.has(k):
			set(k, d[k])
	M = Data.MONSTERS[mk]
	stairs_shut = 0
	sel = slot_idx("lair")
	sel_minion = null
	trap_mode = ""
	ent_mode = false
	decor_room = -1
	decor_pick = null
	rebuild_objs()
	changed.emit()
	logged.emit()
	return true

func clear_run() -> void:
	if not fast and not no_save and FileAccess.file_exists(run_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path))


# ---------------------------------------------------------------- run setup

func new_run(key: String, with_mods := []) -> void:
	mk = key
	M = Data.MONSTERS[key]
	mods = with_mods.duplicate()
	day = 1
	gold = 70 + meta.hoard * 20
	mmax = roundi(M.hp * 0.75) if has_mod("glass") else M.hp
	mhp = mmax
	smax = 0
	if duo():
		smax = roundi(M.partner.hp * 0.75) if has_mod("glass") else M.partner.hp
	shp = smax
	down = []
	souls = 0
	kills = 0
	logs = []
	taken = []
	b = {"atk": 0, "spell": 0, "move": 0, "minion": 0, "feast": 0, "cd": 0, "greed": 0.0, "trap": 0, "hours": 0, "minion_hp": 0}
	hours = day_hours()
	slots = []
	floors = 0
	bosses = 0
	stairs_shut = 0
	_add_floor()
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
	decor_room = -1
	decor_pick = null
	tut = -1
	fallen = []
	party = make_party(1)
	future = [make_party(2), make_party(3)]
	add_log("%s has claimed a damp cave. The village has noticed." % M.name, "info")
	changed.emit()


# ---------------------------------------------------------------- dread modifiers

func has_mod(id: String) -> bool:
	return id in mods

func mods_unlocked() -> bool:
	return meta.best >= MODS_UNLOCK_BEST

## How much the run's banked souls are multiplied by, e.g. 1.35.
static func soul_mult_of(ids: Array) -> float:
	var m := 1.0
	for o in Data.MODS:
		if o.id in ids:
			m += o.bonus
	return m

func soul_mult() -> float:
	return soul_mult_of(mods)

func boss_every() -> int:
	return 4 if has_mod("crusade") else BOSS_EVERY

func is_boss_night(d: int) -> bool:
	return d % boss_every() == 0

func day_hours() -> int:
	return (2 if has_mod("short") else 3) + (b.hours if b.has("hours") else 0)

## Gold a hero drops when killed, after Greed and Lean Coffers.
func kill_gold(base: int) -> int:
	var g := roundi(base * (1 + b.greed))
	return maxi(1, g / 2) if has_mod("lean") else g


## Hero HP multiplier for night d. Gentle early, curving upward so the real ramp lands around nights 15-20.
static func hero_hp_mult(d: int) -> float:
	var n := d - 1
	return 1.0 + 0.07 * n + 0.005 * n * n

## Flat attack bonus heroes get on night d: none through night 5, then +1 every 3 nights,
## plus an extra +1 every 3 nights past night 12.
static func hero_atk_bonus(d: int) -> int:
	return maxi(0, d - 5) / 3 + maxi(0, d - 12) / 3

static func party_size(d: int) -> int:
	return mini(9, 3 + int(d * 0.45) + maxi(0, d - 12) / 4)

## The first night each hero type can join a raid. Night 1 is all peasants; nights 2-5 add archers
## (plus the boss); after that, one or two new types turn up every night or so.
const HERO_ARRIVALS := {"peasant": 1, "archer": 2, "rogue": 6, "knight": 7, "cleric": 8, "sapper": 8, "mage": 9, "barbarian": 11}

## How likely a hero type is on night d. Peasants fade out by night 13; archers start rare on
## night 2 (about 1 in 8) and grow common; every later type starts rare and becomes common over four nights.
static func hero_weight(k: String, d: int) -> float:
	if d < HERO_ARRIVALS[k]:
		return 0.0
	match k:
		"peasant": return maxf(0.0, 4.0 - 0.35 * (d - 1))
		"archer": return minf(2.0, 0.5 + 0.3 * (d - 2))
	return minf(3.0, 1.0 + 0.5 * (d - HERO_ARRIVALS[k]))

static func pick_hero(d: int) -> String:
	var total := 0.0
	for k in HERO_ARRIVALS:
		total += hero_weight(k, d)
	var r := randf() * total
	for k in HERO_ARRIVALS:
		r -= hero_weight(k, d)
		if r < 0.0:
			return k
	return "archer"

func make_party(d: int) -> Array:
	var size: int = party_size(d)
	var list := []
	for i in size:
		list.append(pick_hero(d))
	if is_boss_night(d): list[0] = "paladin"
	if is_boss_night(d) and d % (boss_every() * 2) == 0 and list.size() > 1: list[1] = "paladin"
	if has_mod("crowded"): list.append(pick_hero(d))
	return list


## Highest level of a room type anywhere in the dungeon. Copies on other floors do not stack.
func lvl(t: String) -> int:
	var best := 0
	for s in slots:
		if s.get("type", "") == t:
			best = maxi(best, s.lvl)
	return best

func rows() -> int:
	return BH * floors

func floor_of(p: Vector2i) -> int:
	return p.y / BH

func floor_of_slot(si: int) -> int:
	return si / FLOOR_SLOTS

func _add_floor() -> void:
	for i in FLOOR_SLOTS:
		slots.append({"state": "rock"})
	floors += 1

func floor_type_count(t: String, f: int) -> int:
	var n := 0
	for i in range(f * FLOOR_SLOTS, (f + 1) * FLOOR_SLOTS):
		if slots[i].get("type", "") == t:
			n += 1
	return n


# ---------------------------------------------------------------- geometry

func in_b(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < BW and p.y < BH * floors

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

## The outer edge of floor 1, the only place the surface entrance can go.
func on_border(p: Vector2i) -> bool:
	return p.y < BH and (p.x == 0 or p.y == 0 or p.x == BW - 1 or p.y == BH - 1)

func man(a: Vector2i, c: Vector2i) -> int:
	return absi(a.x - c.x) + absi(a.y - c.y)

func wall_between(a: Vector2i, c: Vector2i) -> bool:
	if not is_floor(c):
		return true
	if slot_of(a) == slot_of(c):
		return false
	if floor_of(a) != floor_of(c):
		return true
	# doorways are the middle three tiles of each shared wall
	var l: int = (a.y % RS) if a.x != c.x else (a.x % RS)
	return l < 1 or l > 3

func can_step(a: Vector2i, c: Vector2i) -> bool:
	return is_open(a) and is_open(c) and not wall_between(a, c)

## Like can_step, but pretends every breakable piece of furniture is already smashed.
func can_step_thru(a: Vector2i, c: Vector2i) -> bool:
	return _passable(a) and _passable(c) and not wall_between(a, c)

func _passable(p: Vector2i) -> bool:
	return is_floor(p) and (not blocked(p) or breakable(p))

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

## Walking distance from every source tile to every reachable tile. With thru, breakable
## furniture counts as open floor, which is how heroes judge what to smash.
func field(srcs: Array, thru := false) -> Dictionary:
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
		for n in steps(c, thru):
			if F.has(n):
				continue
			F[n] = F[c] + 1
			q.append(n)
	return F

## Tiles a unit standing on p can walk to in one step, including taking the stairs.
func steps(p: Vector2i, thru := false) -> Array:
	var o := []
	for d in DIRS:
		var n: Vector2i = p + d
		if can_step_thru(p, n) if thru else can_step(p, n):
			o.append(n)
	if stairs_shut <= 0 and links.has(p) and (_passable(links[p]) if thru else is_open(links[p])):
		o.append(links[p])
	return o

func is_link(a: Vector2i, c: Vector2i) -> bool:
	return links.get(a, Vector2i(-1, -1)) == c

func slot_neighbors(si: int) -> Array:
	var s := slot_xy(si)
	var row := s.y % SH
	var o := []
	if s.x > 0: o.append(si - 1)
	if s.x < SW - 1: o.append(si + 1)
	if row > 0: o.append(si - SW)
	if row < SH - 1: o.append(si + SW)
	return o

## A built room's own furniture, as [x, y, kind, blocks, broken] in room-local tiles. Copied
## from the room's blueprint the first time it's needed, so each room can move and lose pieces.
func room_objs(si: int) -> Array:
	var s: Dictionary = slots[si]
	if not s.has("objs"):
		var out := []
		for e in Data.ROOMS[s.type].objs:
			out.append([e[0], e[1], e[2], e.size() > 3 and e[3] == 1, false])
		s.objs = out
	return s.objs

func rebuild_objs() -> void:
	obj = {}
	for si in slots.size():
		var s: Dictionary = slots[si]
		if s.state == "rock":
			continue
		var o := slot_xy(si) * RS
		if s.state != "built":
			for e in Data.EMPTY_OBJS:
				obj[o + Vector2i(e[0], e[1])] = {"kind": e[2], "block": false}
			continue
		var objs := room_objs(si)
		for i in objs.size():
			var e: Array = objs[i]
			obj[o + Vector2i(e[0], e[1])] = {"kind": "rubble" if e[4] else e[2], "block": e[3] and not e[4], "si": si, "i": i, "broken": e[4]}
	# stairs: the center of each Stairs Up room links to the center of the same slot one floor up
	links = {}
	for si in slots.size():
		if slots[si].get("type", "") == "stairs" and si + FLOOR_SLOTS < slots.size():
			var top := slot_xy(si) * RS + Vector2i(2, 2)
			var bottom := top + Vector2i(0, BH)
			links[top] = bottom
			links[bottom] = top
			obj[bottom] = {"kind": "stairs_down", "block": false}
	for k in traps.keys():
		if not is_open(k):
			gold += trap_cost(traps[k]) / 2
			traps.erase(k)


# ---------------------------------------------------------------- day actions

## Whether the tutorial lets this action happen right now. Actions look like "dig:6",
## "build:7:barracks", "upgrade:12", "recruit:goblin", "trap", "entrance", "lair", "demolish", "night".
func allowed(act: String) -> bool:
	return not gate.is_valid() or gate.call(act)

func guard(act: String) -> bool:
	if allowed(act):
		return true
	tip("Not yet. Follow the tutorial steps in the panel.", true)
	return false

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
	if not diggable(si) or not guard("dig:%d" % si) or not spend(dig_cost()):
		return
	slots[si] = {"state": "dug"}
	add_log("Your servants dig out a new chamber.")
	_layout_changed()

## Starter rooms are always open; the rest must be unlocked with souls between runs.
func is_unlocked(t: String) -> bool:
	return not Data.ROOMS[t].has("unlock") or t in meta.rooms

func unlock_room(t: String) -> bool:
	var c: int = Data.ROOMS[t].get("unlock", 0)
	if is_unlocked(t) or meta.souls < c:
		return false
	meta.souls -= c
	meta.rooms.append(t)
	save_meta()
	return true

## Rooms this monster could still unlock.
func locked_rooms_for(key: String) -> Array:
	var o := []
	for t in Data.ROOMS:
		var R: Dictionary = Data.ROOMS[t]
		if not is_unlocked(t) and (not R.has("owner") or R.owner == key):
			o.append(t)
	return o

## Each room type can be built once per floor.
func can_build(t: String, si: int) -> bool:
	var R: Dictionary = Data.ROOMS[t]
	if R.get("fixed", false) or (R.has("owner") and R.owner != mk) or not is_unlocked(t):
		return false
	if floor_type_count(t, floor_of_slot(si)) > 0:
		return false
	return t != "stairs" or stairs_block(si) == ""

## Why a Stairs room cannot go in this chamber, or "" if it can.
func stairs_block(si: int) -> String:
	var f := floor_of_slot(si)
	if f < floors - 1:
		return "This floor already has stairs up."
	if floors >= 1 + bosses:
		return "Your lair can't carry another floor yet. Survive a boss night (night %d) to build higher." % ((bosses + 1) * boss_every())
	return ""

func build(si: int, t: String) -> void:
	if slots[si].state != "dug" or not can_build(t, si) or not guard("build:%d:%s" % [si, t]) or not spend(Data.ROOMS[t].cost[0]):
		return
	slots[si] = {"state": "built", "type": t, "lvl": 1}
	if t == "coffin":
		mmax += 8
		mhp += 8
	if t == "trainingyard":
		smax += 4
		shp += 4
	if t == "stairs":
		_add_floor()
		slots[si + FLOOR_SLOTS] = {"state": "dug"}
		add_log("Your servants raise floor %d above the lair." % floors, "info")
	else:
		add_log("You build a %s." % Data.ROOMS[t].name)
	_layout_changed()

func upgrade(si: int) -> void:
	var s: Dictionary = slots[si]
	var R: Dictionary = Data.ROOMS[s.type]
	if not guard("upgrade:%d" % si) or not spend(Data.room_cost(s.type, s.lvl)):
		return
	s.lvl += 1
	if s.type == "scrying":
		_fill_future()
	var hp := 6 if s.type == "lair" else (8 if s.type == "coffin" else 0)
	mmax += hp
	mhp += hp
	# the lair strengthens both of a duo; the Training Yard only the Squire
	var sq := (6 if s.type == "lair" else 0) + (4 if s.type == "trainingyard" else 0)
	if duo() and sq > 0:
		smax += sq
		shp += sq
	add_log("Your %s grows to level %d." % [R.name, s.lvl])
	changed.emit()

func demolish(si: int) -> void:
	var s: Dictionary = slots[si]
	if Data.ROOMS[s.type].get("fixed", false) or not guard("demolish"):
		return
	if s.type == "stairs":
		tip("The floor above stands on these stairs. They cannot come down.", true)
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
	if s.type == "trainingyard":
		smax -= 4 * s.lvl
		shp = mini(shp, smax)
	slots[si] = {"state": "dug"}
	_layout_changed()

## Moving the lair costs 1 hour on the same floor and a whole day to another floor.
func lair_move_hours(si: int) -> int:
	return 1 if floor_of_slot(si) == floor_of_slot(slot_idx("lair")) else 3

func move_lair(si: int) -> void:
	if slots[si].state != "dug" or not guard("lair") or not spend(0, lair_move_hours(si)):
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
	if not guard("entrance") or not spend(0):
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
	if not guard("trap"):
		return
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

## Every recruit room houses its own minions, so copies on different floors add up.
func cap_of(kind: String) -> int:
	var t := recruit_room(kind)
	if t == "":
		return 0
	var c := 0
	for s in slots:
		if s.get("type", "") == t:
			c += Data.ROOMS[t].cap * s.lvl
	return c

func count_of(kind: String) -> int:
	var n := 0
	for m in minions:
		if m.kind == kind and not m.free:
			n += 1
	return n

func monster_start() -> Vector2i:
	return slot_xy(slot_idx("lair")) * RS + Vector2i(2, 1)

## The Squire starts on the rug just below the throne.
func squire_start() -> Vector2i:
	return monster_start() + Vector2i(0, 1)

## True for monsters played as two units (the Dark Lord and his Squire).
func duo() -> bool:
	return M.has("partner")

## Bring a fallen duo member back at full HP for souls from this run, one per night survived.
func buy_back(who: String) -> void:
	if not who in down or souls < day:
		return
	souls -= day
	down.erase(who)
	if who == "lord":
		mhp = mmax
	else:
		shp = smax
	add_log("You pay %d souls. %s rises again." % [day, M.name if who == "lord" else M.partner.name], "info")
	changed.emit()

func post_ok(p: Vector2i, skip = null) -> bool:
	if not is_open(p) or p == entrance or p == monster_start() or (duo() and p == squire_start()):
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
	if not guard("recruit:" + kind):
		return
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
		# hand the new recruit straight to the player to post (the tutorial keeps its scripted flow)
		if not gate.is_valid():
			sel_minion = minions.back()
			trap_mode = ""
			ent_mode = false
			decor_room = -1
			decor_pick = null
			tip("Click an open tile to post your new %s, or press Esc to leave it where it stands." % Data.UNITS[kind].name.to_lower())
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
	if decor_room >= 0:
		decor_click(p)
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


# ---------------------------------------------------------------- furniture

## A blocking piece of room furniture that heroes can smash.
func breakable(p: Vector2i) -> bool:
	return obj.has(p) and obj[p].block and obj[p].has("si") and not obj[p].kind in Data.FIXED_DECOR

## A piece in the room being rearranged that can be picked up.
func decor_movable(p: Vector2i) -> bool:
	return decor_room >= 0 and obj.has(p) and obj[p].get("si", -1) == decor_room and not obj[p].broken \
		and not obj[p].kind in Data.FIXED_DECOR

## An empty tile in the room being rearranged where a piece can be set down.
func decor_spot_ok(p: Vector2i) -> bool:
	return decor_room >= 0 and in_b(p) and slot_of(p) == decor_room and not obj.has(p) and not traps.has(p) \
		and p != entrance and p != monster_start() and not (duo() and p == squire_start()) \
		and minion_at(p) == null and not links.has(p)

func toggle_decor(si: int) -> void:
	if decor_room == si:
		decor_room = -1
		decor_pick = null
		changed.emit()
		return
	if not guard("decor"):
		return
	decor_room = si
	decor_pick = null
	sel_minion = null
	trap_mode = ""
	ent_mode = false
	tip("Click a piece of furniture to pick it up, then an empty tile in the room to set it down.")
	changed.emit()

func decor_click(p: Vector2i) -> void:
	if not in_b(p) or slot_of(p) != decor_room:
		decor_room = -1
		decor_pick = null
		sel = slot_of(p) if in_b(p) else sel
		changed.emit()
		return
	if decor_movable(p):
		decor_pick = null if decor_pick == p else p
	elif obj.has(p) and obj[p].get("broken", false):
		tip("That piece is smashed. Repair this room's furniture first.", true)
	elif decor_pick != null:
		if decor_spot_ok(p):
			move_decor(decor_pick, p)
			decor_pick = null
		else:
			tip("Furniture goes on empty floor in this room: not on traps, guard posts, the throne or the entrance.", true)
	else:
		tip("Click a piece of furniture to pick it up.", true)
	changed.emit()

func move_decor(from: Vector2i, to: Vector2i) -> void:
	var o: Dictionary = obj[from]
	var e: Array = room_objs(o.si)[o.i]
	var base := slot_xy(o.si) * RS
	e[0] = to.x - base.x
	e[1] = to.y - base.y
	_layout_changed()

## Heroes broke a piece: it becomes rubble until repaired.
func break_decor(p: Vector2i) -> void:
	var o: Dictionary = obj[p]
	room_objs(o.si)[o.i][4] = true
	rebuild_objs()

func broken_count(si: int) -> int:
	var n := 0
	if slots[si].state == "built":
		for e in room_objs(si):
			if e[4]:
				n += 1
	return n

func repair_room(si: int) -> void:
	var c := broken_count(si) * Data.DECOR_REPAIR
	if c == 0 or not guard("decor") or not spend(c, 0):
		return
	for e in room_objs(si):
		e[4] = false
	add_log("Your servants rebuild the smashed furniture in the %s." % Data.ROOMS[slots[si].type].name)
	_layout_changed()


# ---------------------------------------------------------------- boons and dawn

## Whether surviving night d earns a dark boon.
func boon_due(d: int) -> bool:
	return not has_mod("godless") and d % BOON_EVERY == 0

## The next boon night: tonight or later by day, and always a later night on the
## after-battle screen (which only asks when tonight wasn't one).
func next_boon_night() -> int:
	return ceili(day / float(BOON_EVERY)) * BOON_EVERY

func boon_ok(id: String) -> bool:
	match id:
		"rituals": return b.cd < 1
		"owl": return b.hours < 2
	return true

func apply_boon(id: String) -> void:
	match id:
		"hide":
			mmax += 20
			mhp = mmax
			if duo():
				smax += 20
				shp = smax
		"claws": b.atk += 5
		"surge": b.spell += 5
		"swift": b.move += 2
		"pack":
			b.minion += 2
			b.minion_hp = b.get("minion_hp", 0) + 5
		"feast": b.feast += 8
		"rituals":
			b.cd += 1
			b.spell += 2
		"greed": b.greed += 1.0
		"jagged": b.trap += 8
		"owl":
			b.hours += 1
			gold += 50
		"press":
			add_minion("ogre", true)
			add_minion("goblin", true)
			add_minion("goblin", true)

func boon_choices() -> Array:
	var avail := []
	for o in Data.BOONS:
		if boon_ok(o.id):
			avail.append(o)
	avail.shuffle()
	return avail.slice(0, 3)

func dawn(boon: Dictionary) -> void:
	if is_boss_night(day):
		bosses += 1
		add_log("The earth trembles after the boss falls. You can dig a staircase to a new floor.", "info")
	day += 1
	if not boon.is_empty():
		apply_boon(boon.id)
		taken.append(boon.name)
	var tg := Data.treasury_gold(lvl("treasury"))
	var heal := Data.larder_heal(lvl("larder"))
	var tribute := 5 if has_mod("lean") else 10
	if has_mod("norest"):
		heal = 0
	gold += tg + tribute
	mhp = mini(mmax, mhp + heal)
	shp = mini(smax, shp + heal)
	hours = day_hours()
	party = future.pop_front() if future.size() > 0 else make_party(day)
	_fill_future()
	_stitch()
	add_log("Dawn of day %d. Terrified villagers leave %d gold at the cave mouth.%s%s" % [day, tribute,
		(" Treasury: +%d gold." % tg) if tg > 0 else "", (" Larder: +%d HP." % heal) if heal > 0 else ""], "info")
	changed.emit()

## Keep enough upcoming raiding parties rolled for the Scrying Pool to show.
func _fill_future() -> void:
	while future.size() < maxi(2, lvl("scrying")):
		future.append(make_party(day + future.size() + 1))

## Stitching Room: brings back minions lost last night for half their cost, if there is room.
func _stitch() -> void:
	var n := lvl("stitching")
	var lost := fallen
	fallen = []
	for kind in lost:
		if n <= 0:
			break
		var c: int = Data.UNITS[kind].cost / 2
		if gold >= c and count_of(kind) < cap_of(kind) and add_minion(kind):
			gold -= c
			n -= 1
			add_log("Your stitchers sew a %s back together for %d gold." % [Data.UNITS[kind].name.to_lower(), c], "info")

func end_run() -> int:
	var earned := roundi((souls + day * 2) * soul_mult())
	meta.souls += earned
	meta.best = maxi(meta.best, day - 1)
	if not mods.is_empty():
		meta.best_dread = maxi(meta.get("best_dread", 0), day - 1)
	save_meta()
	clear_run()
	return earned
