extends Node
## The guided tutorial: a Vampire Lord run whose first five nights follow set steps. Each step
## shows in a coach panel at the top of the side column, can point at a chamber on the map,
## limits which actions are allowed (through Game.gate) and moves on when its condition comes
## true. After the fifth night the run carries on as a normal run.
##
## A step is a Dictionary:
##   title, text   what the coach panel says
##   night         true for steps that happen during a fight (resuming a save rewinds past them)
##   slot          chamber to pulse on the map
##   sel           chamber to select when the step starts
##   allow         actions allowed during the step (see Game.allowed); "*" allows everything
##   need          gold the step needs; a stash tops the player up. "dig" means the dig cost
##   party         index into PARTIES: tonight's raiders, set when the step starts
##   next          button label; the player presses it to move on
##   done          Callable that returns true when the step is complete
##   act           what the step asks for, done in code. Only the headless test uses it.

const PARTIES := [
	["peasant", "peasant", "peasant"],
	["peasant", "peasant", "peasant", "archer"],
	["peasant", "peasant", "rogue", "archer"],
	["peasant", "knight", "archer"],
	["paladin", "peasant"],
]

var ui              # main.gd
var steps: Array = []
var coach: PanelContainer
var _box: VBoxContainer
var _goblins := 0     # goblins when the current step began


func build(main_ui) -> void:
	ui = main_ui
	steps = _make_steps()
	coach = PanelContainer.new()
	coach.add_theme_stylebox_override("panel", ui._box("#2c2232", "#e4a648", 8, 14, 2))
	coach.visible = false
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	coach.add_child(_box)


func active() -> bool:
	return Game.tut >= 0 and Game.tut < steps.size()

func step() -> Dictionary:
	return steps[Game.tut] if active() else {}


## Starts or picks up the tutorial at Game.tut. Runs are saved by day, so a save made during
## a fight's steps rewinds to that day's nightfall step.
func resume() -> void:
	if not active():
		stop()
		return
	while Game.tut > 0 and steps[Game.tut].get("night", false):
		Game.tut -= 1
	Game.gate = _allows
	_enter()

## Hides the tutorial without ending it; the saved run keeps its step.
func stop() -> void:
	Game.gate = Callable()
	ui.board.hint_slot = -1
	coach.visible = false

## Ends the tutorial for good. The run goes on as a normal run.
func finish() -> void:
	Game.tut = -1
	Game.meta.tutorial_done = 1
	Game.save_meta()
	stop()
	Game.changed.emit()

func advance() -> void:
	Game.tut += 1
	if Game.tut >= steps.size():
		finish()
	else:
		_enter()

func skip() -> void:
	ui.menus.confirm("Skip the tutorial?", "You keep playing this run, with no more steps or limits.", "Skip it", finish)


func _enter() -> void:
	var s := step()
	Game.trap_mode = ""
	Game.ent_mode = false
	Game.sel_minion = null
	if s.has("party"):
		Game.party = PARTIES[s.party].duplicate()
	if s.has("need"):
		var need: int = Game.dig_cost() if str(s.need) == "dig" else s.need
		if Game.gold < need:
			Game.add_log("Your servants dig up a forgotten stash: +%d gold." % (need - Game.gold), "info")
			Game.gold = need
	if s.has("sel"):
		Game.sel = s.sel
	_goblins = Game.count_of("goblin")
	ui.board.hint_slot = s.get("slot", -1)
	_render()
	ui.side.scroll_vertical = 0
	Game.changed.emit()

func _allows(act: String) -> bool:
	for p in step().get("allow", []):
		if p == "*" or p == act:
			return true
	return false

func _render() -> void:
	ui.clear(_box)
	var s := step()
	_box.add_child(ui.lbl("TUTORIAL · %s %d" % ["NIGHT" if ui.night else "DAY", Game.day], 12, "#e4a648"))
	_box.add_child(ui.title(s.title, "#ede3cd", 22))
	_box.add_child(ui.lbl(s.text, 15, "#ede3cd"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	if s.has("next"):
		var nb := Button.new()
		nb.text = s.next
		nb.theme_type_variation = "PrimaryButton"
		nb.pressed.connect(advance)
		row.add_child(nb)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var sk := Button.new()
	sk.text = "Skip tutorial"
	sk.theme_type_variation = "GhostButton"
	sk.add_theme_font_size_override("font_size", 13)
	sk.pressed.connect(skip)
	row.add_child(sk)


func _process(_dt: float) -> void:
	if not active() or not ui.in_run:
		return
	# the coach rides at the top of whichever side column is showing
	var parent: Container = ui.hud.dock if ui.night else ui.day_column
	if coach.get_parent() != parent:
		if coach.get_parent():
			coach.get_parent().remove_child(coach)
		parent.add_child(coach)
		parent.move_child(coach, 0)
		_render()
	coach.visible = true
	# several steps can come true at once, e.g. a quick win skips the rest of a night's coaching
	var n := 0
	while active() and _complete(step()) and n < 10:
		n += 1
		advance()

func _complete(s: Dictionary) -> bool:
	if s.get("night", false) and not s.get("boon", false) and (_won_night() or not ui.night):
		return true
	return s.has("done") and s.done.call()


# ---------------------------------------------------------------- the five nights

func _b() -> Battle:
	return ui.battle

func _fighting() -> bool:
	return ui.night and ui.battle != null

func _won_night() -> bool:
	return ui.pick_ov.visible

func _dawned(day: int) -> Callable:
	return func(): return not ui.night and Game.day == day

func _built(si: int, t: String) -> Callable:
	return func(): return Game.slots[si].get("type", "") == t

func _dug(si: int) -> Callable:
	return func(): return Game.slots[si].state != "rock"

func _nightfall(text: String) -> Dictionary:
	return {"title": "Let night fall", "text": text, "allow": ["night"],
		"done": func(): return ui.night}

func _boon(day: int) -> Dictionary:
	return {"title": "Choose a dark boon", "night": true, "boon": true,
		"text": "Every night you survive earns a boon. It lasts for the rest of the run.",
		"done": _dawned(day)}

func _lay_spikes() -> void:
	Game.trap_mode = "spikes"
	Game.place_trap(Vector2i(11, 2))
	Game.place_trap(Vector2i(13, 2))
	Game.trap_mode = ""

func _set_snare() -> void:
	Game.trap_mode = "snare"
	Game.place_trap(Vector2i(12, 7))
	Game.trap_mode = ""

func _make_steps() -> Array:
	return [
		# ---- day 1: a barracks, a goblin and room to grow
		{"title": "Welcome, Vampire Lord", "slot": 12, "party": 0, "next": "Let's begin",
			"text": "This is your lair, deep under the village. Heroes break in through the glowing gate at the top and fight their way down to your throne. For the next five nights this tutorial tells you what to build. After that, the run is yours."},
		{"title": "Build a barracks", "slot": 7, "allow": ["build:7:barracks"], "need": 25,
			"text": "Click the empty chamber just above your lair, then choose Goblin Barracks in the panel. Every build takes 1 of your 3 daily hours, plus gold.",
			"done": _built(7, "barracks"), "act": func(): Game.build(7, "barracks")},
		{"title": "Recruit a goblin", "slot": 7, "sel": 7, "allow": ["recruit:goblin"], "need": 15,
			"text": "With the barracks selected, click Recruit goblin. Minions cost gold but no time, and fight beside you every night. If they die, they stay dead.",
			"done": func(): return Game.count_of("goblin") >= 1, "act": func(): Game.recruit("goblin")},
		{"title": "Post your goblin", "slot": 2,
			"text": "Click your goblin on the map, then click a tile in the top chamber. That's where it stands guard when the heroes arrive.",
			"done": func(): return Game.minions.any(func(m): return Game.slot_of(m.post) == 2),
			"act": func(): Game.minions[0].post = Vector2i(12, 3)},
		{"title": "Dig deeper", "slot": 6, "allow": ["dig:6"], "need": "dig",
			"text": "Click the rock to the left of the barracks and dig it out. More chambers make a longer, deadlier road to your throne. Each dig costs a little more than the last.",
			"done": _dug(6), "act": func(): Game.dig(6)},
		{"title": "Dig once more", "slot": 8, "allow": ["dig:8"], "need": "dig",
			"text": "Spend your last hour digging out the rock to the right of the barracks.",
			"done": _dug(8), "act": func(): Game.dig(8)},
		_nightfall("You're out of hours. Press Let night fall below the map. Three peasants are coming."),

		# ---- night 1: moving, ending the turn, reading heroes, attacking
		{"title": "Your turn", "night": true,
			"text": "Your Vampire Lord is selected. Blue tiles show where it can move: click one. Your goblin is a unit too, so click it to give it orders. The heroes have only just come through the gate.",
			"done": func(): return _fighting() and (_b().mon.moved or _b().turn >= 2)},
		{"title": "End your turn", "night": true,
			"text": "When your units are done, press End turn (E). The heroes then move toward you, and it's your turn again.",
			"done": func(): return _fighting() and _b().turn >= 2},
		{"title": "Read the heroes", "night": true,
			"text": "Click a hero to see its health and, in red, every tile it can hit next turn. Stay out of the red to stay safe, or step in to bait it.",
			"done": func(): return _fighting() and (ui.hud.inspect != null or _b().turn >= 4)},
		{"title": "Attack", "night": true,
			"text": "A hero ringed in red is in reach of your selected unit: click it to attack. Your claws drink a third of the damage they deal back as health. Kill every hero to win the night.",
			"done": _won_night},
		_boon(2),

		# ---- day 2: traps and upgrades
		{"title": "Dawn", "party": 1, "next": "Next",
			"text": "Every dawn brings 3 fresh hours, and the frightened villagers leave 10 gold at the cave mouth. Heroes you kill drop gold too. Tonight an archer joins the peasants."},
		{"title": "Build a Trap Workshop", "slot": 6, "allow": ["build:6:workshop"], "need": 25,
			"text": "Click the chamber left of the barracks and build a Trap Workshop. It lets you lay traps, and traps stay put for the whole run.",
			"done": _built(6, "workshop"), "act": func(): Game.build(6, "workshop")},
		{"title": "Lay spike traps", "slot": 2, "allow": ["trap"], "need": 20,
			"text": "In the Traps panel, pick Spike trap, then click two open tiles in the top chamber where the heroes come in. Spikes hurt every hero that steps on them. Traps cost gold but no time.",
			"done": func(): return Game.traps.size() >= 2,
			"act": _lay_spikes},
		{"title": "Upgrade your lair", "slot": 12, "allow": ["upgrade:12"], "need": 40,
			"text": "Click your lair and upgrade it. Upgrades make a room stronger: a level 2 lair gives you 6 more max HP.",
			"done": func(): return Game.lvl("lair") >= 2, "act": func(): Game.upgrade(12)},
		{"title": "Make room for tomorrow", "slot": 11, "allow": ["dig:11"], "need": "dig",
			"text": "Dig out the rock to the left of your lair. You'll build something special there tomorrow.",
			"done": _dug(11), "act": func(): Game.dig(11)},
		_nightfall("Press Let night fall. Archers shoot from 4 tiles away, but walls and furniture block their arrows."),

		# ---- night 2
		{"title": "Mind the archer", "night": true,
			"text": "Watch the heroes walk over your spikes. Keep out of the archer's line of fire, and close in from behind a wall or a corner.",
			"done": _won_night},
		_boon(3),

		# ---- day 3: signature room, more minions, healing
		{"title": "Your own rooms", "slot": 11, "party": 2, "allow": ["build:11:crypt"], "need": 35,
			"text": "Each monster has signature rooms only it can build. Click the chamber left of your lair and build a Crypt of Brides. It houses vampire spawn, minions that drink blood like you.",
			"done": _built(11, "crypt"), "act": func(): Game.build(11, "crypt")},
		{"title": "Recruit vampire spawn", "slot": 11, "sel": 11, "allow": ["recruit:spawn"], "need": 30,
			"text": "With the crypt selected, recruit a vampire spawn.",
			"done": func(): return Game.count_of("spawn") >= 1, "act": func(): Game.recruit("spawn")},
		{"title": "Build a Larder", "slot": 8, "allow": ["build:8:larder"], "need": 20,
			"text": "Click the chamber right of the barracks and build a Larder. It heals you every dawn, so you start each night stronger.",
			"done": _built(8, "larder"), "act": func(): Game.build(8, "larder")},
		{"title": "Grow the barracks", "slot": 7, "sel": 7, "allow": ["upgrade:7"], "need": 40,
			"text": "Click the Goblin Barracks and upgrade it. Level 2 houses 4 goblins.",
			"done": func(): return Game.lvl("barracks") >= 2, "act": func(): Game.upgrade(7)},
		{"title": "One more goblin", "slot": 7, "sel": 7, "allow": ["recruit:goblin"], "need": 15,
			"text": "Recruit another goblin. Minions that died in earlier nights are gone for good, so keep your ranks filled.",
			"done": func(): return Game.count_of("goblin") > _goblins, "act": func(): Game.recruit("goblin")},
		_nightfall("A rogue comes tonight. Rogues spot traps and step around them, so your minions will have to catch it."),

		# ---- night 3: spells
		{"title": "Mesmerize", "night": true,
			"text": "Your Vampire Lord knows two spells. Press 2 for Mesmerize, then click a hero within 3 tiles: it loses its next turn. Spells take a few turns to recharge.",
			"done": func(): return _won_night() or (_fighting() and (_b().mon.cds.get("mesmer", 0) > 0 or _b().turn >= 6))},
		{"title": "Bat Form", "night": true,
			"text": "Press 1 for Bat Form to fly to any empty tile within 5, even past walls. It doesn't use up your attack, so fly in and strike in the same turn.",
			"done": func(): return _won_night() or (_fighting() and (_b().mon.cds.get("bats", 0) > 0 or _b().turn >= 8))},
		{"title": "Finish them", "night": true, "text": "Kill every hero to win the night.", "done": _won_night},
		_boon(4),

		# ---- day 4: snares, then a free choice
		{"title": "Snares", "slot": 6, "party": 3, "allow": ["upgrade:6"], "need": 40,
			"text": "Upgrade the Trap Workshop. Level 2 unlocks snares and room for more traps.",
			"done": func(): return Game.lvl("workshop") >= 2, "act": func(): Game.upgrade(6)},
		{"title": "Set a snare", "slot": 7, "allow": ["trap"], "need": 8,
			"text": "Pick Snare in the Traps panel and place one in the chamber above your lair. A snare holds a hero in place for a turn, so your minions can gang up on it.",
			"done": func(): return Game.traps.values().has("snare"),
			"act": _set_snare},
		{"title": "Your choice", "allow": ["*"],
			"text": "You have 2 hours left. Spend them however you like: dig, build, upgrade or recruit. Then let night fall. A knight is coming, and its armor blocks 1 damage from every hit.",
			"done": func(): return ui.night},

		# ---- night 4
		{"title": "Crack the knight", "night": true,
			"text": "Armor takes 1 off every hit, so your claws hurt the knight far more than goblin jabs do. Let your minions hold it while you strike.",
			"done": _won_night},
		_boon(5),

		# ---- day 5: the boss
		{"title": "Boss night", "party": 4, "next": "Next",
			"text": "Every fifth night a boss leads the raid. Tonight it's a Paladin: lots of health, 2 armor, and holy, so it hits vampires for 3 extra damage. Beat it and you can build Stairs Up to raise a new floor."},
		{"title": "Prepare", "allow": ["*"], "need": 120,
			"text": "Today is yours, and your servants have found extra gold for it. A Paladin beats you in a straight fight, so fill your crypt and barracks with minions and line the halls with traps. Let night fall when you're ready.",
			"done": func(): return ui.night},

		# ---- night 5
		{"title": "Fight the Paladin", "night": true,
			"text": "Mesmerize works on bosses too. Let traps and minions wear the Paladin down, and don't trade blows when you're low.",
			"done": _won_night},
		_boon(6),

		{"title": "Tutorial complete", "next": "Finish",
			"text": "You know the basics. This run is yours now, so keep going as long as you can. After a boss night, empty chambers can hold Stairs Up. Between runs, spend souls in the Room catalog to unlock new rooms."},
	]
