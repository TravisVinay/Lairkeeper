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
##   need          gold the step needs; a stash tops the player up
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
	Game.clear_modes()
	if s.has("party"):
		Game.party = PARTIES[s.party].duplicate()
	if s.has("need"):
		var need: int = s.need
		if Game.gold < need:
			Game.add_log("Your servants dig up a forgotten stash: +%d gold." % (need - Game.gold), "info")
			Game.gold = need
	if s.has("sel"):
		Game.sel = s.sel
	ui.board.hint_slot = s.get("slot", -1)
	# show the tab the step is about
	if "trap" in s.get("allow", []):
		ui.tab = "traps"
	elif s.title.begins_with("Post your goblin"):
		ui.tab = "minions"
	elif s.has("slot") or s.has("sel"):
		ui.tab = "rooms"
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

func _nightfall(text: String) -> Dictionary:
	return {"title": "Let night fall", "text": text, "allow": ["night"],
		"done": func(): return ui.night}

func _gift(day: int) -> Dictionary:
	return {"title": "Your patron's gift", "night": true, "boon": true,
		"text": "Night survived. A dark patron is watching you. After your first night, and every seventh night after, it offers you a choice of three gifts: permanent power-ups for the rest of the run. Pick one.",
		"done": _dawned(day)}

func _greet(day: int, text := "Night survived. Press Greet the dawn to start the next day.") -> Dictionary:
	return {"title": "Greet the dawn", "night": true, "boon": true, "text": text, "done": _dawned(day)}

func _lay_spikes() -> void:
	Game.trap_mode = "spikes"
	Game.place_trap(Vector2i(6, 2))
	Game.place_trap(Vector2i(8, 2))
	Game.trap_mode = ""

func _set_snare() -> void:
	Game.trap_mode = "snare"
	Game.place_trap(Vector2i(7, 7))
	Game.trap_mode = ""

func _make_steps() -> Array:
	return [
		# ---- day 1: a barracks and its goblins, and room to grow
		{"title": "Welcome, Vampire Lord", "slot": 7, "party": 0, "next": "Let's begin",
			"text": "This is your throne room, deep under the village. Heroes break in through the glowing gate at the top and fight their way down to your throne. For the next five nights this tutorial tells you what to build. After that, the run is yours."},
		{"title": "Build a barracks", "slot": 4, "allow": ["build:4:barracks"], "need": 25,
			"text": "Click the empty chamber just above your throne room, then choose Goblin Barracks in the panel. Every build takes 1 of your 3 daily hours, plus gold. The barracks comes with two goblins, free.",
			"done": _built(4, "barracks"), "act": func(): Game.build(4, "barracks")},
		{"title": "Post your goblin", "slot": 1,
			"text": "Your goblins fight beside you every night, and if one dies the barracks replaces it at dawn. Click a goblin on the map, then click a tile in the top chamber. That's where it stands guard when the heroes arrive.",
			"done": func(): return Game.minions.any(func(m): return Game.slot_of(m.post) == 1),
			"act": func(): Game.minions[0].post = Vector2i(7, 3)},
		{"title": "Build a Spike Workshop", "slot": 3, "allow": ["build:3:workshop"], "need": 25,
			"text": "Click the rock to the left of the barracks. No digging needed: rooms go straight into the rock next to your dungeon. Build a Spike Workshop there. It lets you lay up to 3 spike traps, and upgrading it lets you lay more. Traps stay put for the whole run and re-arm every night.",
			"done": _built(3, "workshop"), "act": func(): Game.build(3, "workshop")},
		{"title": "Lay spike traps", "slot": 1, "allow": ["trap"], "need": 20,
			"text": "In the Traps panel, pick Spike trap, then click two open tiles in the top chamber where the heroes come in. A spike trap fires once a night, badly hurting the first hero that steps on it. Traps cost gold but no time.",
			"done": func(): return Game.traps.size() >= 2,
			"act": _lay_spikes},
		_nightfall("Press Let night fall below the map. Three peasants are coming. Hours you don't spend are lost at nightfall."),

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
		_gift(2),

		# ---- day 2: traps and upgrades
		{"title": "Dawn", "party": 1, "next": "Next",
			"text": "Every dawn brings 3 fresh hours, and the frightened villagers leave 8 gold at the cave mouth. Heroes you kill drop gold too. Tonight an archer joins the peasants."},
		{"title": "Upgrade your throne room", "slot": 7, "allow": ["upgrade:7"], "need": 40,
			"text": "Click your throne room and upgrade it. Upgrades make a room stronger: a level 2 throne room gives you 6 more max HP. They take longer than building, too: as many hours as the level you raise it to, so 2 hours for level 2.",
			"done": func(): return Game.lvl("lair") >= 2, "act": func(): Game.upgrade(7)},
		{"title": "Build a Larder", "slot": 5, "allow": ["build:5:larder"], "need": 20,
			"text": "Click the rock to the right of the barracks and build a Larder. It heals you every dawn, so you start each night stronger.",
			"done": _built(5, "larder"), "act": func(): Game.build(5, "larder")},
		_nightfall("Press Let night fall. Archers shoot from 4 tiles away, but walls and furniture block their arrows."),

		# ---- night 2
		{"title": "Mind the archer", "night": true,
			"text": "Watch the first heroes walk onto your spikes. Keep out of the archer's line of fire, and close in from behind a wall or a corner.",
			"done": _won_night},
		_greet(3),

		# ---- day 3: signature room, more minions, healing
		{"title": "Your own rooms", "slot": 6, "party": 2, "allow": ["build:6:crypt"], "need": 35,
			"text": "Each monster has signature rooms only it can build. Click the rock left of your throne room and build a Crypt of Brides. It comes with two vampire spawn, minions that drink blood like you.",
			"done": _built(6, "crypt"), "act": func(): Game.build(6, "crypt")},
		{"title": "Grow the barracks", "slot": 4, "sel": 4, "allow": ["upgrade:4"], "need": 40,
			"text": "Click the Goblin Barracks and upgrade it. Level 2 houses 4 goblins, and the two new ones move in at once.",
			"done": func(): return Game.lvl("barracks") >= 2, "act": func(): Game.upgrade(4)},
		_nightfall("A rogue comes tonight. Rogues spot traps and step around them, so your minions will have to catch it."),

		# ---- night 3: spells
		{"title": "Mesmerize", "night": true,
			"text": "Your Vampire Lord knows two spells. Press 2 for Mesmerize, then click a hero within 3 tiles: it loses its next turn. Spells take a few turns to recharge.",
			"done": func(): return _won_night() or (_fighting() and (_b().mon.cds.get("mesmer", 0) > 0 or _b().turn >= 6))},
		{"title": "Bat Form", "night": true,
			"text": "Press 1 for Bat Form to fly to any empty tile within 5, even past walls. It doesn't use up your attack, so fly in and strike in the same turn.",
			"done": func(): return _won_night() or (_fighting() and (_b().mon.cds.get("bats", 0) > 0 or _b().turn >= 8))},
		{"title": "Finish them", "night": true, "text": "Kill every hero to win the night.", "done": _won_night},
		_greet(4),

		# ---- day 4: snares, then a free choice
		{"title": "Snares", "slot": 8, "party": 3, "allow": ["build:8:snareden"], "need": 25,
			"text": "Each kind of trap comes from its own room. Click the rock right of your throne room and build a Snare Den. It lets you lay 2 snares.",
			"done": _built(8, "snareden"), "act": func(): Game.build(8, "snareden")},
		{"title": "Set a snare", "slot": 4, "allow": ["trap"], "need": 8,
			"text": "Pick Snare in the Traps panel and place one in the chamber above your throne room. A snare holds a hero in place for a turn, so your minions can gang up on it.",
			"done": func(): return Game.traps.values().has("snare"),
			"act": _set_snare},
		{"title": "Your choice", "allow": ["*"],
			"text": "You have 2 hours left. Spend them however you like: build or upgrade. Then let night fall. A knight is coming, and its armor blocks 1 damage from every hit.",
			"done": func(): return ui.night},

		# ---- night 4
		{"title": "Crack the knight", "night": true,
			"text": "Armor takes 1 off every hit, so your claws hurt the knight far more than goblin jabs do. Let your minions hold it while you strike.",
			"done": _won_night},
		_greet(5),

		# ---- day 5: the boss
		{"title": "Boss night", "party": 4, "next": "Next",
			"text": "Every fifth night a boss leads the raid. Tonight it's a Paladin: lots of health, 2 armor, and holy, so it hits vampires for 3 extra damage. Beat it and the village will think twice."},
		{"title": "Prepare", "allow": ["*"], "need": 120,
			"text": "Today is yours, and your servants have found extra gold for it. A Paladin beats you in a straight fight, so fill your crypt and barracks with minions and line the halls with traps. Let night fall when you're ready.",
			"done": func(): return ui.night},

		# ---- night 5
		{"title": "Fight the Paladin", "night": true,
			"text": "Mesmerize works on bosses too. Let traps and minions wear the Paladin down, and don't trade blows when you're low.",
			"done": _won_night},
		_greet(6),

		{"title": "Tutorial complete", "next": "Finish",
			"text": "You know the basics. This run is yours now, so keep going as long as you can. When you run out of chambers, expand the dungeon from the Layout panel. Every third day a wandering trader stops at your gate to sell relics and supplies for gold, and your patron sends another gift every seventh night. Between runs, spend souls on the Monsters screen to level up a monster: new perks, new spells and more ways to play it."},
	]
