extends Node
## Run state, dungeon geometry and every day-phase action. Autoloaded as `Game`.

signal changed
signal logged
signal tipped(text: String, warn: bool)

## The dungeon is one grid of 5x5 chambers. It starts 3x3 and grows a row or column at a time
## (see expand()).
const RS := 5
const START_SIDE := 3
## No side of the dungeon grows past this many chambers.
const MAX_SIDE := 7
## Gold per chamber an expansion adds.
const EXPAND_GOLD := 10
## Which way each expansion side grows.
const SIDES := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "w": Vector2i(-1, 0), "e": Vector2i(1, 0)}
var SW := START_SIDE          # chambers across
var SH := START_SIDE          # chambers down
var BW := SW * RS             # tile columns
var BH := SH * RS             # tile rows
## Nights between boss nights; Restless Crusade makes it 4. See boss_every().
const BOSS_EVERY := 5
## A dark boon is earned every this many nights survived (not tied to Restless Crusade).
const BOON_EVERY := 5
## Surviving this night wins the run.
const WIN_NIGHT := 50
## Rooms top out at this level.
const MAX_LVL := 3
## Dread modifiers unlock once a run has survived this many nights (that is, reached night 5).
const MODS_UNLOCK_BEST := 4
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Meta progress (souls, unlocks, records). Playtest builds keep their own files; see _ready().
var meta_path := "user://meta.json"
## Where the run in progress is saved. Tests point it elsewhere.
var run_path := "user://run.save"
## Everything a run needs to resume. Layout and furniture are rebuilt from slots.
const RUN_KEYS := ["mk", "day", "hours", "gold", "mhp", "mmax", "souls", "kills", "logs", "taken", "b",
	"slots", "traps", "minions", "entrance", "party", "_uid", "tut", "mods", "future", "shp", "smax", "down", "SW", "SH", "bosses"]

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
var entrance := Vector2i(SW / 2 * RS + 2, 0)
## Boss nights survived. Each one earns one expansion of the dungeon.
var bosses := 0
var party := []
var future := []     # the raiders of the next nights, so the Scrying Pool can show them
var sel := -1
var sel_minion = null
var trap_mode := ""
var ent_mode := false
## "minions" or "furniture" while the player is rearranging the dungeon, else "".
var arrange := ""
var decor_pick = null     # tile of the furniture piece picked up, or null
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
	# the Stitching Room was removed when minions became free; give back what it cost
	if "stitching" in meta.rooms:
		meta.rooms.erase("stitching")
		meta.souls += 35
		save_meta()


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
	# a run saved on a different layout (several floors, or the old 5x4 grid) can't be resumed
	var sl = d.get("slots", [])
	var per := int(d.get("SW", START_SIDE)) * int(d.get("SH", START_SIDE))
	if not sl is Array or int(d.get("floors", 1)) != 1 or sl.size() != per:
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
	shp = 0
	smax = 0
	down = []
	bosses = 0
	SW = START_SIDE
	SH = START_SIDE
	for k in RUN_KEYS:
		if d.has(k):
			set(k, d[k])
	_set_dims(SW, SH)
	M = Data.MONSTERS[mk]
	for i in slots.size():
		if not Data.ROOMS.has(slots[i].get("type", "lair")):
			slots[i] = {"state": "dug"}   # a room type that no longer exists
	sel = slot_idx("lair")
	clear_modes()
	rebuild_objs()
	fill_rooms()
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
	_set_dims(START_SIDE, START_SIDE)
	bosses = 0
	slots = []
	for i in SW * SH:
		slots.append({"state": "rock"})
	traps = {}
	minions = []
	# the gate in the middle of the top edge, a hall below it, and the lair at the bottom
	var mid := SW / 2
	entrance = Vector2i(mid * RS + 2, 0)
	slots[mid] = {"state": "dug"}
	slots[mid + SW] = {"state": "dug"}
	slots[mid + 2 * SW] = {"state": "built", "type": "lair", "lvl": 1}
	rebuild_objs()
	sel = mid + 2 * SW
	clear_modes()
	tut = -1
	party = make_party(1)
	future = [make_party(2), make_party(3)]
	add_log("%s has claimed a damp cave. The village has noticed. Hold it for %d nights." % [M.name, WIN_NIGHT], "info")
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


## Hero HP multiplier for night d. Paced for a 50-night run: about x2.4 by night 15, x5 by 30, x10 by 50.
static func hero_hp_mult(d: int) -> float:
	var n := d - 1
	return 1.0 + 0.07 * n + 0.0025 * n * n

## Flat attack bonus heroes get on night d: none through night 5, then +1 every 3 nights
## (+15 by night 50).
static func hero_atk_bonus(d: int) -> int:
	return maxi(0, d - 5) / 3

## From this night on the village mob is gone: raids are small adventuring companies of veterans.
const PARTY_NIGHT := 15
## Veterans carry this much more HP (and +1 attack) than the mob heroes of the same night.
const VETERAN_HP := 1.6

static func is_company(d: int) -> bool:
	return d >= PARTY_NIGHT

static func party_size(d: int) -> int:
	if is_company(d):
		return 5 if d < 20 else 6
	return mini(9, 3 + int(d * 0.45) + maxi(0, d - 12) / 4)

## Extra HP multiplier for veterans of an adventuring company.
static func veteran_hp(d: int) -> float:
	return VETERAN_HP if is_company(d) else 1.0

## Gold a veteran drops is scaled up with its HP, so smaller parties pay the same.
static func veteran_gold(d: int, base: int) -> int:
	return roundi(base * veteran_hp(d))

const COMPANY_NAMES := ["The Silver Lances", "The Ashen Oath", "The Gilded Hand", "The Wolves of Varn",
	"The Last Lantern", "The Crimson Vow", "The Order of the Thorn", "The Free Blades", "The Dawnbreakers",
	"The Iron Pilgrims", "The Grey Company", "The Sworn of Saint Odile"]

## A stable name for an adventuring company, read off its members so saves need no extra field.
static func company_name(list: Array) -> String:
	return COMPANY_NAMES[absi(hash(",".join(list))) % COMPANY_NAMES.size()]

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

## A company has a shape: someone to hold the line, a healer, a ranged hitter and a specialist,
## filled out with whoever else signed on. Front-liners walk through the gate first.
static func make_company(d: int) -> Array:
	var list: Array = [["knight", "barbarian"].pick_random(), ["rogue", "sapper"].pick_random(),
		["archer", "mage"].pick_random(), "cleric"]
	while list.size() < party_size(d):
		var k := pick_hero(d)
		if k == "cleric" and "cleric" in list:
			continue   # one healer per company keeps fights from dragging
		list.insert(1, k)
	return list

func make_party(d: int) -> Array:
	var size: int = party_size(d)
	var list := []
	if is_company(d):
		list = make_company(d)
	else:
		for i in size:
			list.append(pick_hero(d))
	if is_boss_night(d): list[0] = "paladin"
	if is_boss_night(d) and d % (boss_every() * 2) == 0 and list.size() > 1: list[1] = "paladin"
	if has_mod("crowded"): list.append(pick_hero(d))
	return list


## Level of a room type in the dungeon (0 if it isn't built).
func lvl(t: String) -> int:
	var best := 0
	for s in slots:
		if s.get("type", "") == t:
			best = maxi(best, s.lvl)
	return best

func type_count(t: String) -> int:
	var n := 0
	for sl in slots:
		if sl.get("type", "") == t:
			n += 1
	return n


# ---------------------------------------------------------------- geometry

func _set_dims(w: int, h: int) -> void:
	SW = w
	SH = h
	BW = w * RS
	BH = h * RS

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

## The outer edge of the dungeon, the only place the surface entrance can go.
func on_border(p: Vector2i) -> bool:
	return in_b(p) and (p.x == 0 or p.y == 0 or p.x == BW - 1 or p.y == BH - 1)

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

## Tiles a unit standing on p can walk to in one step.
## The returned array is shared with the cache: read it, never change it.
func steps(p: Vector2i, thru := false) -> Array:
	var cache: Dictionary = _nav[1 if thru else 0]
	var hit = cache.get(p)
	if hit != null:
		return hit
	var o := _steps(p, thru)
	cache[p] = o
	return o

func _steps(p: Vector2i, thru: bool) -> Array:
	var o := []
	for d in DIRS:
		var n: Vector2i = p + d
		if can_step_thru(p, n) if thru else can_step(p, n):
			o.append(n)
	return o

func slot_neighbors(si: int) -> Array:
	var s := slot_xy(si)
	var o := []
	if s.x > 0: o.append(si - 1)
	if s.x < SW - 1: o.append(si + 1)
	if s.y > 0: o.append(si - SW)
	if s.y < SH - 1: o.append(si + SW)
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

## Bumped whenever furniture is rebuilt, so the board knows to redraw its cached map.
var map_ver := 0
## Each tile's walkable neighbours, [normal, through breakable furniture]. Pathfinding asks for
## these thousands of times a turn, so they are worked out once and cleared when the map changes.
var _nav := [{}, {}]

func rebuild_objs() -> void:
	map_ver += 1
	_nav = [{}, {}]
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
	for k in traps.keys():
		if not is_open(k):
			gold += trap_cost(traps[k]) / 2
			traps.erase(k)


# ---------------------------------------------------------------- day actions

## Whether the tutorial lets this action happen right now. Actions look like "build:6:barracks",
## "build:7:barracks", "upgrade:12", "trap", "entrance", "lair", "demolish", "night".
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

## Rock beside one of your chambers: a room can be built straight into it.
func can_open(si: int) -> bool:
	if slots[si].state != "rock":
		return false
	for n in slot_neighbors(si):
		if slots[n].state != "rock":
			return true
	return false

## Whether a room can go in this chamber: an empty one, or rock next to your dungeon.
func open_spot(si: int) -> bool:
	return slots[si].state == "dug" or can_open(si)

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
	fill_rooms()
	fix_posts()
	changed.emit()

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

## Each room type can be built once.
func can_build(t: String, si: int) -> bool:
	var R: Dictionary = Data.ROOMS[t]
	if R.get("fixed", false) or (R.has("owner") and R.owner != mk) or not is_unlocked(t):
		return false
	return type_count(t) == 0

func build(si: int, t: String) -> void:
	if not open_spot(si) or not can_build(t, si) or not guard("build:%d:%s" % [si, t]) or not spend(Data.ROOMS[t].cost[0]):
		return
	slots[si] = {"state": "built", "type": t, "lvl": 1}
	if t == "coffin":
		mmax += 8
		mhp += 8
	if t == "trainingyard":
		smax += 4
		shp += 4
	add_log("You build a %s." % Data.ROOMS[t].name)
	_layout_changed()

func upgrade(si: int) -> void:
	var s: Dictionary = slots[si]
	var R: Dictionary = Data.ROOMS[s.type]
	if s.lvl >= MAX_LVL:
		tip("The %s is already at its highest level." % R.name, true)
		return
	if not guard("upgrade:%d" % si) or not spend(Data.room_cost(s.type, s.lvl)):
		return
	s.lvl += 1
	var moved_in := fill_rooms()
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
	add_log("Your %s grows to level %d.%s" % [R.name, s.lvl,
		(" %d more %s move in." % [moved_in, Data.UNITS[R.recruit].name.to_lower()]) if moved_in > 0 else ""])
	changed.emit()

func demolish(si: int) -> void:
	var s: Dictionary = slots[si]
	if Data.ROOMS[s.type].get("fixed", false) or not guard("demolish"):
		return
	if not spend(0):
		return
	# the room's own minions leave with it
	minions = minions.filter(func(m): return m.home != si or m.free)
	add_log("You tear down the %s." % Data.ROOMS[s.type].name)
	if s.type == "coffin":
		mmax -= 8 * s.lvl
		mhp = mini(mhp, mmax)
	if s.type == "trainingyard":
		smax -= 4 * s.lvl
		shp = mini(shp, smax)
	slots[si] = {"state": "dug"}
	_layout_changed()

func move_lair(si: int) -> void:
	# moving the throne is always free: no hours, no gold
	if slots[si].state != "dug" or not guard("lair"):
		return
	var old := slot_idx("lair")
	var o: Dictionary = slots[old]
	slots[old] = {"state": "dug"}
	slots[si] = o
	sel = si
	add_log("You drag your throne to a new chamber.")
	_layout_changed()

## Chambers an expansion on this side adds: one for every chamber along that side, so a 3x3
## grows to 3x4 for 3 chambers, and a 3x4 grows to 4x4 for 4 more on its long side.
func expand_size(side: String) -> int:
	return SW if SIDES[side].y != 0 else SH

func expand_cost(side: String) -> int:
	return EXPAND_GOLD * expand_size(side)

## Why the dungeon can't grow this way, or "" if it can.
func expand_block(side: String) -> String:
	var across: int = SH if SIDES[side].y != 0 else SW
	if across >= MAX_SIDE:
		return "Your dungeon can't grow past %d chambers that way." % MAX_SIDE
	if expands_left() <= 0:
		return "Beat a boss to earn an expansion. The next boss comes on night %d." % next_boss_night()
	return ""

## Expansions done so far: every row or column added to the starting 3x3.
func expands_used() -> int:
	return SW + SH - 2 * START_SIDE

## Expansions earned by beating bosses and not spent yet.
func expands_left() -> int:
	return maxi(0, bosses - expands_used())

## The first boss night from today on.
func next_boss_night() -> int:
	return ceili(day / float(boss_every())) * boss_every()

## Whether the surface entrance sits on this outer edge of the dungeon.
func entrance_on(side: String) -> bool:
	match side:
		"n": return entrance.y == 0
		"s": return entrance.y == BH - 1
		"w": return entrance.x == 0
	return entrance.x == BW - 1

## Adds a strip of solid rock along one side of the dungeon. Rooms can
## then be built into it as usual. Growing past the entrance tunnels it out to the new edge.
func expand(side: String) -> void:
	var why := expand_block(side)
	if why != "":
		tip(why, true)
		return
	if not guard("expand") or not spend(expand_cost(side)):
		return
	var d: Vector2i = SIDES[side]
	var ent_out := entrance_on(side)
	var ow := SW
	var nw := SW + absi(d.x)
	var nh := SH + absi(d.y)
	var off := Vector2i(1 if side == "w" else 0, 1 if side == "n" else 0)   # chambers the old grid shifts by
	var ns := []
	for i in nw * nh:
		ns.append({"state": "rock"})
	var remap := {}
	for si in slots.size():
		var c := Vector2i(si % ow, si / ow) + off
		var n := c.y * nw + c.x
		ns[n] = slots[si]
		remap[si] = n
	var move := func(p: Vector2i) -> Vector2i:
		return p + off * RS
	slots = ns
	_set_dims(nw, nh)
	var nt := {}
	for k in traps:
		nt[move.call(k)] = traps[k]
	traps = nt
	for m in minions:
		m.post = move.call(m.post)
		if m.home >= 0:
			m.home = remap.get(m.home, m.home)
	if sel >= 0:
		sel = remap.get(sel, sel)
	entrance = move.call(entrance)
	if ent_out:
		# the gate moves out to the new edge, with a tunnel chamber behind it
		entrance += d * RS
		var es := slot_of(entrance)
		if slots[es].state == "rock":
			slots[es] = {"state": "dug"}
	add_log("Your servants push the dungeon %s: %d new chambers of rock to build into." % [
		{"n": "north", "s": "south", "w": "west", "e": "east"}[side], expand_size(side)], "info")
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

## Traps fire once a night, so each hit is a big one.
func trap_dmg(t: String) -> int:
	var cw: int = lvl("clockwork") * 4 + b.trap
	match t:
		"spikes": return 8 + 4 * maxi(1, lvl("workshop")) + cw
		"snare": return 6 + cw
	return Data.rune_dmg(lvl("runes")) + cw

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

## Minions a recruit room can house.
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

## Every recruit room comes with its minions, free: as many as it houses at its level. Any that
## died are replaced the same way at dawn. Returns how many moved in.
func fill_rooms() -> int:
	var added := 0
	for si in slots.size():
		var t: String = slots[si].get("type", "")
		if t == "" or not Data.ROOMS[t].has("recruit"):
			continue
		var want: int = Data.ROOMS[t].cap * slots[si].lvl
		var have := 0
		for m in minions:
			if m.home == si and not m.free:
				have += 1
		while have < want and add_minion(Data.ROOMS[t].recruit):
			have += 1
			added += 1
	return added

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
	if arrange == "furniture":
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
	if arrange == "minions":
		tip("Click one of your minions to pick it up.", true)
		return
	sel = slot_of(p)
	changed.emit()


# ---------------------------------------------------------------- furniture

## A blocking piece of room furniture that heroes can smash.
func breakable(p: Vector2i) -> bool:
	return obj.has(p) and obj[p].block and obj[p].has("si") and not obj[p].kind in Data.FIXED_DECOR

## Leaves every map-click mode: traps, the entrance, arranging, a minion in hand.
func clear_modes() -> void:
	trap_mode = ""
	ent_mode = false
	arrange = ""
	decor_pick = null
	sel_minion = null

## A piece of furniture, in any built room, that can be picked up.
func decor_movable(p: Vector2i) -> bool:
	return arrange == "furniture" and obj.has(p) and obj[p].has("si") and not obj[p].broken \
		and not obj[p].kind in Data.FIXED_DECOR

## An empty tile in any built room where a piece can be set down.
func decor_spot_ok(p: Vector2i) -> bool:
	return arrange == "furniture" and in_b(p) and slots[slot_of(p)].state == "built" and not obj.has(p) \
		and not traps.has(p) and p != entrance and p != monster_start() and not (duo() and p == squire_start()) \
		and minion_at(p) == null

## Turns "minions" or "furniture" arranging on, or off if it was already on.
func toggle_arrange(mode: String) -> void:
	var was := arrange
	clear_modes()
	if was == mode:
		changed.emit()
		return
	if mode == "furniture" and not guard("decor"):
		changed.emit()
		return
	arrange = mode
	if mode == "furniture":
		tip("Click any piece of furniture to pick it up, then an empty tile in any room to set it down.")
	else:
		tip("Click a minion, then an open tile for its new guard post.")
	changed.emit()

func decor_click(p: Vector2i) -> void:
	if not in_b(p):
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
			tip("Furniture goes on empty floor in a built room: not on traps, guard posts, the throne or the entrance.", true)
	else:
		tip("Click a piece of furniture to pick it up.", true)
	changed.emit()

## Moves a piece to tile `to`, carrying it into another room if need be.
func move_decor(from: Vector2i, to: Vector2i) -> void:
	var o: Dictionary = obj[from]
	var e: Array = room_objs(o.si)[o.i]
	var dest := slot_of(to)
	if dest != o.si:
		room_objs(o.si).remove_at(o.i)
		room_objs(dest).append(e)
	var base := slot_xy(dest) * RS
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
		"jagged": b.trap += 10
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
		add_log("The boss is dead. The earth trembles: you can expand your dungeon by one row or column.", "info")
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
	var back := fill_rooms()
	if back > 0:
		add_log("%d new minion%s move into your rooms to replace the fallen." % [back, "s" if back > 1 else ""], "info")
	add_log("Dawn of day %d. Terrified villagers leave %d gold at the cave mouth.%s%s" % [day, tribute,
		(" Treasury: +%d gold." % tg) if tg > 0 else "", (" Larder: +%d HP." % heal) if heal > 0 else ""], "info")
	changed.emit()

## Keep enough upcoming raiding parties rolled for the Scrying Pool to show.
func _fill_future() -> void:
	while future.size() < maxi(2, lvl("scrying")):
		future.append(make_party(day + future.size() + 1))

## Souls a won run banks on top of the usual tally, before Dread.
const WIN_SOULS := 100

func end_run(won := false) -> int:
	var survived := day if won else day - 1
	var earned := roundi((souls + day * 2 + (WIN_SOULS if won else 0)) * soul_mult())
	meta.souls += earned
	meta.best = maxi(meta.best, survived)
	if won:
		meta.wins = meta.get("wins", 0) + 1
	if not mods.is_empty():
		meta.best_dread = maxi(meta.get("best_dread", 0), survived)
	save_meta()
	clear_run()
	return earned
