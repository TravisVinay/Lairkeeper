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
## The patron offers a gift after night 1, then every this many nights (8, 15, 22...).
const GIFT_EVERY := 7
## The wandering trader visits every this many days (day 3, 6, 9...).
const TRADER_EVERY := 3
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
	"slots", "traps", "minions", "entrance", "party", "_uid", "tut", "mods", "future", "shp", "smax", "down", "SW", "SH", "bosses", "seen", "kit",
	"gifts", "trader", "gear", "stash", "scrolls"]

## Souls once spent unlocking rooms, by room. Rooms are free now: the souls are refunded on load.
const ROOM_REFUNDS := {
	"stitching": 35, "guardpost": 30, "houndyard": 40, "ogrepen": 55, "belfry": 45, "ossuary": 40, "boneforge": 40, "spikehall": 25,
	"whetstone": 30, "netloft": 25, "powderroom": 40, "bonepit": 20, "furnace": 30, "icecave": 30, "mudpit": 20, "rustroom": 40,
	"darkhall": 35, "rookery": 25, "pitofteeth": 55, "gallery": 35, "shieldwall": 30, "bulwark": 30, "bloodaltar": 35, "chapel": 40,
	"traininpit": 30, "infirmary": 30, "wardens": 40, "ghoulpit": 45, "goldvault": 30, "tithehall": 35, "kitchen": 20, "pantry": 25,
	"soullantern": 40, "frostvault": 45, "parlor": 40, "plaguepit": 45, "dreampool": 40, "nervegarden": 45, "banner": 40, "pulpit": 45,
	"kennel": 30, "lodge": 30, "armory": 25, "cistern": 25, "torture": 35, "collapse": 40, "trainingyard": 35, "oathstone": 45,
	"maze": 30, "shrine": 35, "scrying": 40, "ogreden": 40, "manawell": 40, "phylactery": 55, "bloodpool": 35, "coffin": 30,
	"soulcage": 45, "brainjars": 35, "amplifier": 50, "clockwork": 35, "runes": 45, "spikefoundry": 35, "snarewarren": 30, "runekiln": 45,
	"trapvault": 45, "trapstudy": 50, "mistchamber": 30, "acidvats": 35, "gibbet": 20, "gauntlet": 35, "echohall": 30, "warroom": 35,
	"bastion": 40, "heart": 35, "feasthall": 40, "bonearmorer": 55, "stables": 50, "hotsprings": 35, "scriptorium": 30, "drillyard": 35,
	"smithy": 45, "messhall": 20, "countinghouse": 25, "trophyhall": 40, "charnel": 40, "toothvault": 45,
}

var meta := {"souls": 0, "hoard": 0, "best": 0, "rooms": [], "mons": {}}
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
var minions := []    # {mid, kind, home, post, free, gear: {weapon, armor, relic}}
var obj := {}        # Vector2i -> {kind, block}
var entrance := Vector2i(SW / 2 * RS + 2, 0)
## Boss nights survived. Each one earns one expansion of the dungeon.
var bosses := 0
## Room types built at some point this run, so each counts once per run in meta.room_stats.
var seen := []
## The perks and spell loadout this run started with: {"perks": [ids], "load": [spell ids]}.
var kit := {}
var gifts := []      # ids of the patron gifts taken this run
var trader := {}     # {"day", "stock": [{"id", "sold"}], "haggles"} while the trader is in
var gear := {}       # "monster" / "squire" -> {"weapon", "armor", "relic"} ids
var stash := []      # weapons, armor and relics in the armory, not carried by anyone
var scrolls := []    # {"id", "ch"}: scrolls on your spell bar and the charges they have left
## Every perk, gift and relic effect of this run, summed by key. See perk().
var bonus := {}
var party := []
var future := []     # the raiders of the next nights, so the Scrying Pool can show them
var sel := -1
var sel_minion = null
var trap_mode := ""
var ent_mode := false
## "minions", "furniture" or "traps" while the player is rearranging the dungeon, else "".
var arrange := ""
var decor_pick = null     # tile of the furniture piece picked up, or null
var trap_pick = null      # tile of the trap picked up while arranging traps, or null
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
			meta[k] = d[k] if d[k] is Array or d[k] is Dictionary else int(d[k])
	# rooms no longer cost souls: give back everything ever spent unlocking them
	var refund := 0
	for t in meta.get("rooms", []):
		refund += ROOM_REFUNDS.get(t, 0)
	meta.rooms = []
	if refund > 0:
		meta.souls += refund
		save_meta()


func save_meta() -> void:
	if fast or no_save:
		return   # tests must never touch the player's save
	var f := FileAccess.open(meta_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))


## Wipes souls, unlocks and any run in progress.
func reset_meta() -> void:
	meta = {"souls": 0, "hoard": 0, "best": 0, "rooms": [], "mons": {}}
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
	seen = []
	kit = {}
	gifts = []
	trader = {}
	gear = {}
	stash = []
	scrolls = []
	SW = START_SIDE
	SH = START_SIDE
	for k in RUN_KEYS:
		if d.has(k):
			set(k, d[k])
	_set_dims(SW, SH)
	M = _kit_monster()
	_recalc()
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

## base_kit starts with no perks and the starting spells (the tutorial uses it).
func new_run(key: String, with_mods := [], base_kit := false) -> void:
	mk = key
	kit = {"perks": [], "load": []} if base_kit else {"perks": perks_of(key), "load": loadout(key, "") + loadout(key, "squire")}
	M = _kit_monster()
	gifts = []
	trader = {}
	gear = {}
	stash = []
	scrolls = []
	_recalc()
	mods = with_mods.duplicate()
	day = 1
	gold = 70 + meta.hoard * 20
	mmax = maxi(1, (roundi(M.hp * 0.75) if has_mod("glass") else M.hp) + perk("mon_hp"))
	mhp = mmax
	smax = 0
	if duo():
		smax = (roundi(M.partner.hp * 0.75) if has_mod("glass") else M.partner.hp) + perk("sq_hp")
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
	seen = []
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
	return soul_mult_of(mods) + perk("soul_pct") / 100.0

func boss_every() -> int:
	return 4 if has_mod("crusade") else BOSS_EVERY

func is_boss_night(d: int) -> bool:
	return d % boss_every() == 0

func day_hours() -> int:
	return (2 if has_mod("short") else 3) + (b.hours if b.has("hours") else 0)

## Gold a hero drops when killed, after Greed and Lean Coffers.
## Heroes drop KILL_GOLD of their listed gold (a little less than they used to).
const KILL_GOLD := 0.8
## Gold the frightened villagers leave every dawn (half with Lean Coffers).
const TRIBUTE := 8

func kill_gold(base: int) -> int:
	var g := maxi(1, roundi(base * KILL_GOLD * (1 + b.greed)))
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
	for i in perk("extra_hero"):
		list.append(pick_hero(d))
	return list


## The total of one room effect across the dungeon, plus the same effect from the run's perks: each built room with that key in its "fx"
## adds its value times its level. Rooms built from shared effects use this (see Data.ROOMS).
func fx(key: String) -> int:
	var n := 0
	for s in slots:
		var t: String = s.get("type", "")
		if t != "":
			n += Data.ROOMS[t].get("fx", {}).get(key, 0) * s.lvl
	return n + perk(key)

## A room effect that only counts inside one room: the room tile p is in.
func room_fx(p: Vector2i, key: String) -> int:
	if not in_b(p):
		return 0
	var s: Dictionary = slots[slot_of(p)]
	var t: String = s.get("type", "")
	return Data.ROOMS[t].get("fx", {}).get(key, 0) * s.lvl if t != "" else 0

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
		tip("No hours left today. Let night fall." if hours <= 0 else "That takes %d hours, and you have %d left today." % [h, hours], true)
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
	_trim_traps()
	fix_posts()
	changed.emit()

## Every room is open from the first run (rooms used to be unlocked with souls).
func is_unlocked(_t: String) -> bool:
	return true

## Each room type can be built once.
func can_build(t: String, si: int) -> bool:
	var R: Dictionary = Data.ROOMS[t]
	if R.get("fixed", false) or (R.has("owner") and R.owner != mk):
		return false
	return type_count(t) == 0

# ---------------------------------------------------------------- monster levels
# Souls level a monster up between runs (see Data.LEVEL_TRACK). Saved in meta.mons:
# {key: {"lvl": int, "picks": {"2": 0 or 1, ...}, "load": [spell ids]}}.

func _mon_rec(k: String) -> Dictionary:
	if not meta.has("mons") or not meta.mons is Dictionary:
		meta.mons = {}
	if not meta.mons.has(k):
		meta.mons[k] = {"lvl": 1, "picks": {}, "load": []}
	return meta.mons[k]

## The dev switch in Settings treats every monster as fully levelled.
func mon_lvl(k: String) -> int:
	if Settings.dev_unlock_all and not fast:
		return Data.MON_MAX_LVL
	return int(_mon_rec(k).get("lvl", 1))

func level_cost(k: String) -> int:
	return Data.mon_level_cost(mon_lvl(k))

func can_level(k: String) -> bool:
	return mon_lvl(k) < Data.MON_MAX_LVL and meta.souls >= level_cost(k)

func level_up(k: String) -> bool:
	if not can_level(k):
		return false
	meta.souls -= level_cost(k)
	var r := _mon_rec(k)
	r.lvl = mon_lvl(k) + 1
	# a new spell joins the loadout if there's a free slot for it
	for sp in Data.SPELL_POOL.get(k, []):
		if int(sp.lvl) == r.lvl:
			var who: String = sp.get("who", "")
			if loadout(k, who).size() < load_slots(k):
				r.load = loadout(k, "") + loadout(k, "squire") + [sp.id]
	save_meta()
	return true

## Perk picked at a perk level: 0 or 1, or -1 while the level isn't reached. Defaults to the first.
func perk_pick(k: String, at: int) -> int:
	if mon_lvl(k) < at:
		return -1
	return int(_mon_rec(k).get("picks", {}).get(str(at), 0))

func set_perk(k: String, at: int, i: int) -> void:
	var r := _mon_rec(k)
	if not r.has("picks") or not r.picks is Dictionary:
		r.picks = {}
	r.picks[str(at)] = i
	save_meta()

## Perk ids a monster has picked, in level order.
func perks_of(k: String) -> Array:
	var o := []
	for i in Data.PERK_LEVELS.size():
		var p := perk_pick(k, Data.PERK_LEVELS[i])
		if p >= 0:
			o.append(Data.PERKS[k][i][p].id)
	return o

## Spells a unit carries into a run: 2, or 3 from level 5. Per unit for the duo.
func load_slots(k: String) -> int:
	return 3 if mon_lvl(k) >= 5 else 2

## Spells this monster (or its Squire) has learned so far.
func known_spells(k: String, who := "") -> Array:
	var o := []
	for sp in Data.spells_of(k, who):
		if int(sp.get("lvl", 1)) <= mon_lvl(k):
			o.append(sp)
	return o

## Spell ids picked for a unit, kept to what it knows and has slots for, starting spells
## filling any empty slots.
func loadout(k: String, who := "") -> Array:
	var known := []
	for sp in known_spells(k, who):
		known.append(sp.id)
	var o := []
	for id in _mon_rec(k).get("load", []):
		if id in known and not id in o and o.size() < load_slots(k):
			o.append(id)
	for id in known:
		if o.size() >= load_slots(k) or o.size() >= known.size():
			break
		if not id in o:
			o.append(id)
	return o

## Bring a spell along. The loadout is always full, so it takes the place of the oldest pick.
func equip_spell(k: String, who: String, id: String) -> void:
	var mine := loadout(k, who)
	if id in mine:
		return
	if mine.size() >= load_slots(k):
		mine.pop_front()
	mine.append(id)
	_mon_rec(k).load = mine + loadout(k, "squire" if who == "" else "")
	save_meta()


# ---------------------------------------------------------------- the run's kit
# The perks and spells picked when a run starts. Saved with the run, so changing them on the
# monster screen only affects the next run.

## Total of one effect from this run's perks, patron gifts and carried relics.
func perk(key: String) -> int:
	return bonus.get(key, 0)

## Re-sums bonus. Call whenever the kit, gifts or carried relics change.
func _recalc() -> void:
	bonus = {}
	var srcs := []
	for id in kit.get("perks", []):
		srcs.append(Data.perk_by_id(id))
	for id in gifts:
		srcs.append(Data.gift_by_id(id))
	for id in carried_relics():
		srcs.append(Data.relic_by_id(id))
	for o in srcs:
		var f: Dictionary = o.get("fx", {})
		for k in f:
			bonus[k] = bonus.get(k, 0) + int(f[k])

func has_perk(id: String) -> bool:
	return id in kit.get("perks", [])

## This run's monster: the data entry with its spells swapped for the loadout.
func _kit_monster() -> Dictionary:
	var m: Dictionary = Data.MONSTERS[mk].duplicate(true)
	var load: Array = kit.get("load", [])
	if load.is_empty():
		return m
	m.specials = _pick_spells(Data.spells_of(mk, ""), load)
	if m.has("partner"):
		m.partner.specials = _pick_spells(Data.spells_of(mk, "squire"), load)
	return m

func _pick_spells(all: Array, ids: Array) -> Array:
	var o := []
	for sp in all:
		if sp.id in ids:
			o.append(sp)
	return o if not o.is_empty() else [all[0]]

func build(si: int, t: String) -> void:
	if not open_spot(si) or not can_build(t, si) or not guard("build:%d:%s" % [si, t]) or not spend(Data.ROOMS[t].cost[0]):
		return
	slots[si] = {"state": "built", "type": t, "lvl": 1}
	_hp_fx(t, 1)
	_note_built(t)
	if t == "coffin":
		mmax += 8
		mhp += 8
	if t == "trainingyard":
		smax += 4
		shp += 4
	add_log("You build a %s." % Data.ROOMS[t].name)
	_layout_changed()

## Rooms with "mon_hp" raise your max HP by their value for each level gained (or lose it).
func _hp_fx(t: String, levels: int) -> void:
	var v: int = Data.ROOMS[t].get("fx", {}).get("mon_hp", 0) * levels
	if v == 0:
		return
	mmax += v
	mhp = clampi(mhp + v, 1, mmax) if v > 0 else mini(mhp, mmax)

## Room usage across all runs, for deciding which rooms earn their place: for each room type,
## [runs it was built in, nights it stood through]. Kept in meta.room_stats.
func _note_built(t: String) -> void:
	if t in seen:
		return
	seen.append(t)
	var rs: Dictionary = meta.get("room_stats", {})
	var e: Array = rs.get(t, [0, 0])
	rs[t] = [int(e[0]) + 1, int(e[1])]
	meta.room_stats = rs

func _note_nights() -> void:
	var rs: Dictionary = meta.get("room_stats", {})
	for s in slots:
		var t: String = s.get("type", "")
		if t != "" and t != "lair":
			var e: Array = rs.get(t, [1, 0])
			rs[t] = [int(e[0]), int(e[1]) + 1]
	meta.room_stats = rs
	save_meta()

func upgrade(si: int) -> void:
	var s: Dictionary = slots[si]
	var R: Dictionary = Data.ROOMS[s.type]
	if s.lvl >= MAX_LVL:
		tip("The %s is already at its highest level." % R.name, true)
		return
	# an upgrade takes as many hours as the level it reaches: 2 for level 2, 3 for level 3
	if not guard("upgrade:%d" % si) or not spend(Data.room_cost(s.type, s.lvl), upgrade_hours(si)):
		return
	s.lvl += 1
	_hp_fx(s.type, 1)
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

## Hours to raise a room one level: the level it reaches.
func upgrade_hours(si: int) -> int:
	return int(slots[si].get("lvl", 0)) + 1

func demolish(si: int) -> void:
	var s: Dictionary = slots[si]
	if Data.ROOMS[s.type].get("fixed", false) or not guard("demolish"):
		return
	if not spend(0):
		return
	# the room's own minions leave with it, and leave their weapons behind
	for m in minions:
		if m.home == si and not m.free:
			for k in m.get("gear", {}):
				if m.gear[k] != "":
					stash.append(m.gear[k])
	minions = minions.filter(func(m): return m.home != si or m.free)
	_recalc()
	add_log("You tear down the %s." % Data.ROOMS[s.type].name)
	_hp_fx(s.type, -s.lvl)
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

## Slots for one trap type, from the room that makes it (and any room that adds more).
## Spike Workshop: 3/5/7 spikes. Snare Den: 2/3/4 snares. Rune Chamber: 1/2/3 runes.
func trap_slots(t: String) -> int:
	match t:
		"spikes":
			var w := lvl("workshop")
			return (1 + 2 * w if w > 0 else 0) + fx("spike_slots")
		"snare":
			var s := lvl("snareden")
			return (1 + s if s > 0 else 0) + fx("snare_slots")
	return lvl("runes") + fx("rune_slots")

## Wildcard slots take any trap type. The Mimic starts with 5.
func wild_slots() -> int:
	return (5 if mk == "mimic" else 0) + fx("wild_slots")

func trap_count(t: String) -> int:
	var n := 0
	for k in traps:
		if traps[k] == t:
			n += 1
	return n

## Wildcard slots in use: every trap past its own type's slots takes one.
func wild_used() -> int:
	var n := 0
	for t in Data.TRAPS:
		n += maxi(0, trap_count(t) - trap_slots(t))
	return n

func can_place(t: String) -> bool:
	return trap_count(t) < trap_slots(t) or wild_used() < wild_slots()

func trap_unlocked(t: String) -> bool:
	return trap_slots(t) > 0 or wild_slots() > 0

## Every trap slot, of every type plus wildcards.
func trap_cap() -> int:
	var c := wild_slots()
	for t in Data.TRAPS:
		c += trap_slots(t)
	return c

## After a trap room comes down, pull up the traps that no longer have a slot (half refunded).
func _trim_traps() -> void:
	while wild_used() > wild_slots():
		for t in Data.TRAPS:
			if trap_count(t) > trap_slots(t):
				for k in traps.keys():
					if traps[k] == t:
						gold += trap_cost(t) / 2
						traps.erase(k)
						break
				break

## Most gold the Mimic's Coin Shot can spend.
func coin_cap() -> int:
	return 20 + fx("coin_cap")

## Traps fire once a night, so each hit is a big one.
func trap_dmg(t: String) -> int:
	var cw: int = lvl("clockwork") * 4 + b.trap + fx("trap_dmg")
	match t:
		"spikes": return 8 + 4 * maxi(1, lvl("workshop")) + cw + fx("spike_dmg")
		"snare": return 6 + cw + fx("snare_dmg")
	return Data.rune_dmg(lvl("runes")) + cw + fx("rune_dmg")

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
	if not can_place(trap_mode):
		var nm: String = Data.TRAPS[trap_mode].name.to_lower()
		tip("No free %s slots. Build or upgrade the room that makes them%s." % [nm, " (your wildcard slots are full too)" if wild_slots() > 0 else ""], true)
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
	if arrange == "traps":
		trap_click(p)
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
	trap_pick = null
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

## Turns "minions", "furniture" or "traps" arranging on, or off if it was already on.
func toggle_arrange(mode: String) -> void:
	var was := arrange
	clear_modes()
	if was == mode:
		changed.emit()
		return
	if (mode == "furniture" and not guard("decor")) or (mode == "traps" and not guard("trap")):
		changed.emit()
		return
	arrange = mode
	if mode == "furniture":
		tip("Click any piece of furniture to pick it up, then an empty tile in any room to set it down.")
	elif mode == "traps":
		tip("Click a trap to pick it up, then an open tile to set it down. Free, no hours.")
	else:
		tip("Click a minion, then an open tile for its new guard post.")
	changed.emit()

## An open tile a trap can be moved to: not furniture, the entrance or another trap.
func trap_spot_ok(p: Vector2i) -> bool:
	return arrange == "traps" and is_open(p) and p != entrance and not traps.has(p)

## Arranging traps: pick one up, then set it down somewhere else, for free.
func trap_click(p: Vector2i) -> void:
	if traps.has(p):
		trap_pick = null if trap_pick == p else p
	elif trap_pick != null:
		if trap_spot_ok(p):
			traps[p] = traps[trap_pick]
			traps.erase(trap_pick)
			trap_pick = null
		else:
			tip("Traps go on open floor, not on furniture or the entrance.", true)
	else:
		tip("Click one of your traps to pick it up.", true)
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

## Mason's Mortar: every smashed piece is mended, free.
func _mend_all() -> void:
	for si in slots.size():
		if broken_count(si) > 0:
			for e in room_objs(si):
				e[4] = false
	_layout_changed()


# ---------------------------------------------------------------- patron gifts and dawn

## Whether surviving night d earns a patron gift: night 1, then every GIFT_EVERY nights.
func gift_due(d: int) -> bool:
	return not has_mod("godless") and d >= 1 and (d - 1) % GIFT_EVERY == 0 and d < WIN_NIGHT

## The next gift night: tonight or later by day, and always a later night on the
## after-battle screen (which only asks when tonight wasn't one).
func next_gift_night() -> int:
	return 1 if day <= 1 else ceili((day - 1) / float(GIFT_EVERY)) * GIFT_EVERY + 1

func gift_ok(id: String) -> bool:
	if id in gifts:
		return false
	match id:
		"rituals": return b.cd < 1
		"owl": return b.hours < 2
		"bloodpact": return mmax > 25
	return true

func apply_gift(id: String) -> void:
	var G := Data.gift_by_id(id)
	if G.is_empty():
		return
	gifts.append(id)
	taken.append(G.name)
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
		"bloodpact":
			b.atk += 7
			mmax -= 15
			mhp = mini(mhp, mmax)
		"cursed": b.greed += 0.5
		"blessed": add_item(random_item("weapon", 3, 3))
		"tome":
			_recalc()   # the extra charge counts for these two
			add_item(random_item("scroll", 2))
			add_item(random_item("scroll", 2))
		"warband":
			for m in minions:
				if item_of(m, "weapon") == "":
					_slots(m).weapon = random_item("weapon", 1, 1)
	_recalc()

## Up to three gifts the patron offers, none taken before.
func gift_choices() -> Array:
	var avail := []
	for o in Data.GIFTS:
		if gift_ok(o.id):
			avail.append(o)
	avail.shuffle()
	return avail.slice(0, 3)

func dawn(gift: Dictionary) -> void:
	_note_nights()
	if is_boss_night(day):
		bosses += 1
		add_log("The boss is dead. The earth trembles: you can expand your dungeon by one row or column.", "info")
	day += 1
	if not gift.is_empty():
		apply_gift(gift.id)
	var interest := mini(25, gold * perk("interest") / 100)
	var tg := Data.treasury_gold(lvl("treasury")) + fx("dawn_gold")
	var heal := Data.larder_heal(lvl("larder")) + fx("dawn_heal")
	var tribute := TRIBUTE / 2 if has_mod("lean") else TRIBUTE
	if has_mod("norest"):
		heal = 0
	gold += tg + tribute + interest
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
	if interest > 0:
		add_log("Your hoard grows by %d gold." % interest, "info")
	for e in [["forge", "gear", "forges"], ["scribes", "scroll", "scribes"]]:
		var l := lvl(e[0])
		if l > 0 and day % maxi(1, 4 - l) == 0:
			var it := random_item(e[1] if e[1] == "scroll" else ["weapon", "armor"].pick_random(), l)
			add_item(it)
			add_log("Your %s %s a %s." % [Data.ROOMS[e[0]].name, e[2], Data.ware_by_id(it).name], "info")
	if trader_due(day):
		trader = {}
		_roll_trader()
		add_log("A wandering trader has set up a stall at your gate. Gone by nightfall.", "info")
	changed.emit()

## Keep enough upcoming raiding parties rolled for the Scrying Pool to show.
func _fill_future() -> void:
	while future.size() < maxi(2, lvl("scrying")):
		future.append(make_party(day + future.size() + 1))

# ---------------------------------------------------------------- the wandering trader
# Visits every TRADER_EVERY days (not during the tutorial) and leaves at nightfall. Sells relics,
# kept for the run, and wares, used at once.

const TRADER_RELICS := 3
const TRADER_WARES := 2
## Gold to roll a new stock; each haggle the same visit costs HAGGLE_STEP more.
const HAGGLE_GOLD := 10
const HAGGLE_STEP := 5

func trader_due(d: int) -> bool:
	return tut < 0 and d % TRADER_EVERY == 0 and d <= WIN_NIGHT

## Whether the trader is at the gate today.
func trader_here() -> bool:
	return int(trader.get("day", -1)) == day and not trader.get("stock", []).is_empty()

func next_trader_day() -> int:
	var d := day + 1
	while d % TRADER_EVERY != 0:
		d += 1
	return d

func _roll_trader() -> void:
	var rel := []
	for r in Data.RELICS:
		if not owns(r.id):
			rel.append(r.id)
	rel.shuffle()
	var wares := []
	for w in Data.WARES:
		wares.append(w.id)
	wares.shuffle()
	var stock := []
	var top := 3 if day >= 20 else 2
	var arms := [random_item("weapon", top), random_item("armor", top), random_item("scroll", top)]
	for id in rel.slice(0, TRADER_RELICS + perk("trader_slots")) + arms + wares.slice(0, TRADER_WARES):
		stock.append({"id": id, "sold": false})
	trader = {"day": day, "stock": stock, "haggles": int(trader.get("haggles", 0))}

## Price of a relic or ware today: a little dearer each night, less any discounts.
func ware_price(id: String) -> int:
	var c: float = Data.ware_by_id(id).get("cost", 0) * (1.0 + 0.015 * (day - 1))
	return maxi(1, roundi(c * (1.0 - minf(0.6, perk("trader_disc") / 100.0))))

func haggle_cost() -> int:
	return HAGGLE_GOLD + HAGGLE_STEP * int(trader.get("haggles", 0))

## Rolls a fresh stock for gold.
func haggle() -> bool:
	if not trader_here() or gold < haggle_cost():
		return false
	gold -= haggle_cost()
	trader.haggles = int(trader.get("haggles", 0)) + 1
	_roll_trader()
	changed.emit()
	return true

func is_relic(id: String) -> bool:
	return Data.slot_of(id) == "relic"

func can_buy(i: int) -> bool:
	if not trader_here() or i < 0 or i >= trader.stock.size():
		return false
	var e: Dictionary = trader.stock[i]
	return not e.sold and gold >= ware_price(e.id) and ware_useful(e.id)

## Wares that would do nothing right now can't be bought.
func ware_useful(id: String) -> bool:
	match id:
		"draught": return mhp < mmax or shp < smax
		"mortar":
			for si in slots.size():
				if broken_count(si) > 0:
					return true
			return false
	return true

func buy(i: int) -> bool:
	if not can_buy(i):
		return false
	var e: Dictionary = trader.stock[i]
	var id: String = e.id
	gold -= ware_price(id)
	e.sold = true
	var nm: String = Data.ware_by_id(id).name
	if is_relic(id) or is_item(id):
		add_item(id)
	else:
		match id:
			"draught":
				mhp = mini(mmax, mhp + 30)
				shp = mini(smax, shp + 30)
			"ale": hours += 1
			"elixir":
				mmax += 8
				mhp += 8
				if duo():
					smax += 8
					shp += 8
			"sellsword": add_minion("ogre", true)
			"souljar": souls += 8
			"mortar": _mend_all()
	add_log("You buy the %s from the wandering trader." % nm, "info")
	changed.emit()
	return true

# ---------------------------------------------------------------- weapons and scrolls
# Weapons sit in the armory (stash) until you hand one to your monster, Squire or a minion.
# Scrolls go straight onto the spell bar with a few charges. Heroes drop both; the trader sells
# them; the War Forge and Scriptorium make them; some patron gifts grant them.

## Scrolls you can carry at once. Any more are sold on for half their price.
const SCROLL_CAP := 4

## Weapons, armor and scrolls (relics are their own thing at the trader).
func is_item(id: String) -> bool:
	return Data.slot_of(id) in ["weapon", "armor", "scroll"]

const GEAR_SLOTS := ["weapon", "armor", "relic"]

## A random id of a kind ("weapon", "armor", "scroll") of tier lo to hi, rarer tiers less likely.
func random_item(kind: String, hi: int, lo := 1) -> String:
	var pool := []
	var src: Array = {"weapon": Data.WEAPONS, "armor": Data.ARMOR, "scroll": Data.SCROLLS}.get(kind, [])
	for it in src:
		var t := int(it.tier)
		if t >= lo and t <= hi:
			for n in 4 - t:   # common things turn up more
				pool.append(it.id)
	return pool.pick_random() if not pool.is_empty() else ""

## Gold an item sells for: a third of its price.
func scrap_value(id: String) -> int:
	return maxi(1, int(Data.ware_by_id(id).get("cost", 0)) / 3)

## Puts a found or bought item away: scrolls on the bar, gear in the armory. Gear goes straight
## onto your monster if that slot of its is empty.
func add_item(id: String) -> void:
	if id == "":
		return
	var sc := Data.scroll_by_id(id)
	if sc.is_empty():
		stash.append(id)
		var slot := Data.slot_of(id)
		if slot != "" and item_of("monster", slot) == "" and not ("lord" in down):
			equip("monster", stash.size() - 1)
		return
	if scrolls.size() >= SCROLL_CAP:
		var g := maxi(1, int(sc.cost) / 2)
		gold += g
		add_log("You can carry no more scrolls: the %s sells for %d gold." % [sc.name, g], "info")
		return
	scrolls.append({"id": id, "ch": int(sc.charges) + perk("scroll_charges")})

## The slot dictionary of who: "monster", "squire" or a minion dictionary.
func _slots(who) -> Dictionary:
	if who is Dictionary:
		if not who.get("gear") is Dictionary:
			who.gear = {}
		return who.gear
	if not gear.get(who) is Dictionary:
		gear[who] = {}
	return gear[who]

## The id who carries in a slot ("weapon", "armor" or "relic"), or "".
func item_of(who, slot: String) -> String:
	return str(_slots(who).get(slot, ""))

## Every relic someone carries. Each works for the whole lair.
func carried_relics() -> Array:
	var o := []
	for who in ["monster", "squire"]:
		var r := item_of(who, "relic")
		if r != "":
			o.append(r)
	for m in minions:
		var r := item_of(m, "relic")
		if r != "":
			o.append(r)
	return o

## Whether you have this item anywhere: carried or in the armory.
func owns(id: String) -> bool:
	return id in stash or id in carried_relics() or _carried_anywhere(id)

func _carried_anywhere(id: String) -> bool:
	for who in ["monster", "squire"]:
		if id in _slots(who).values():
			return true
	for m in minions:
		if id in _slots(m).values():
			return true
	return false

## Hands item i of the armory to who, in its slot. Whatever was there goes back to the armory.
func equip(who, i: int) -> void:
	if i < 0 or i >= stash.size():
		return
	var id: String = stash[i]
	var slot := Data.slot_of(id)
	if not slot in GEAR_SLOTS:
		return
	stash.remove_at(i)
	var old := item_of(who, slot)
	if old != "":
		stash.append(old)
	_slots(who)[slot] = id
	_recalc()
	changed.emit()

func unequip(who, slot: String) -> void:
	var old := item_of(who, slot)
	if old == "":
		return
	stash.append(old)
	_slots(who).erase(slot)
	_recalc()
	changed.emit()

## Sells item i of the armory.
func scrap(i: int) -> void:
	if i < 0 or i >= stash.size():
		return
	var id: String = stash[i]
	stash.remove_at(i)
	gold += scrap_value(id)
	add_log("You sell the %s for %d gold." % [Data.ware_by_id(id).name, scrap_value(id)])
	changed.emit()

## Armory indices of one kind of item, for the sorted lists.
func stash_of(slot: String) -> Array:
	var o := []
	for i in stash.size():
		if Data.slot_of(stash[i]) == slot:
			o.append(i)
	return o

func drop_scroll(i: int) -> void:
	if i >= 0 and i < scrolls.size():
		scrolls.remove_at(i)
		changed.emit()

## The chance in 100 that a slain hero drops gear. Bosses always do.
func drop_chance(hero: Dictionary) -> int:
	if hero.get("boss", false):
		return 100
	return 8 + (6 if is_company(day) else 0) + fx("drop_pct")

## What a slain hero drops: casters favor scrolls, archers bows, bosses the best.
func hero_drop(kind: String) -> String:
	var boss: bool = Data.UNITS[kind].get("boss", false)
	var hi := 3 if boss or day >= 25 else (2 if day >= 8 else 1)
	var lo := 2 if boss else 1
	if kind in ["mage", "cleric"] and randi() % 100 < 70:
		return random_item("scroll", hi, lo)
	if kind == "archer" and randi() % 2 == 0:
		return "longbow" if hi >= 2 else "shortbow"
	if kind == "paladin" and randi() % 3 == 0:
		return "oathblade"
	var r := randi() % 100
	return random_item("scroll" if r < 20 else ("armor" if r < 55 else "weapon"), hi, lo)

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
