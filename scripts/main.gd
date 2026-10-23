extends Control
## Builds the interface and wires the day phase, the night battle and the overlays together.
## Day: board and building panels side by side. Night: board on top, battle panels in a row below.

const BoardScript := preload("res://scripts/board.gd")

var battle: Battle = null
var night := false
var board: Control
var display_font: Font

var body: BoxContainer
var left: VBoxContainer
var side: ScrollContainer
var day_box: VBoxContainer
var night_box: HFlowContainer
var turn_lbl: Label
var main_btn: Button
var zoom_row: HBoxContainer
var tip_lbl: Label
var subtitle: Label
var stat_vals := {}

var room_box: VBoxContainer
var layout_box: VBoxContainer
var trap_box: VBoxContainer
var minion_box: VBoxContainer
var party_box: VBoxContainer
var boon_box: VBoxContainer
var unit_box: VBoxContainer
var power_panel: PanelContainer
var power_box: VBoxContainer
var log_labels: Array = []

var start_ov: Control
var pick_ov: Control
var over_ov: Control
var _hover_hero = null


func _ready() -> void:
	display_font = _make_display_font()
	theme = _make_theme()
	_build()
	Game.changed.connect(refresh)
	Game.logged.connect(render_logs)
	Game.tipped.connect(_on_tip)
	get_viewport().size_changed.connect(apply_layout)
	Game.new_run("vampire")
	show_start()
	apply_layout()


# ---------------------------------------------------------------- theme and widgets

func C(h: String, a := 1.0) -> Color:
	return Data.col(h, a)

func _make_display_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman", "serif"])
	return f

func _box(bg: String, border: String, radius := 6, margin := 10.0, width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C(bg)
	s.border_color = C(border)
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 17
	th.set_stylebox("panel", "PanelContainer", _box("#28212e", "#463a4e", 8, 14))
	th.set_stylebox("normal", "Button", _box("#1a1520", "#463a4e"))
	th.set_stylebox("hover", "Button", _box("#211a28", "#e4a648"))
	th.set_stylebox("pressed", "Button", _box("#241c2e", "#c9a7ff", 6, 10, 2))
	th.set_stylebox("hover_pressed", "Button", _box("#241c2e", "#c9a7ff", 6, 10, 2))
	th.set_stylebox("disabled", "Button", _box("#16121a", "#2e2734"))
	th.set_stylebox("focus", "Button", _box("#00000000", "#e4a648", 6, 10, 2))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		th.set_color(k, "Button", C("#ede3cd"))
	th.set_color("font_disabled_color", "Button", C("#7a6e76"))
	th.set_color("font_color", "Label", C("#ede3cd"))
	th.set_type_variation("PrimaryButton", "Button")
	th.set_stylebox("normal", "PrimaryButton", _box("#c0304c", "#6e1e30", 6, 12))
	th.set_stylebox("hover", "PrimaryButton", _box("#d23a58", "#6e1e30", 6, 12))
	th.set_stylebox("pressed", "PrimaryButton", _box("#a82842", "#6e1e30", 6, 12))
	th.set_stylebox("disabled", "PrimaryButton", _box("#5a2a34", "#3a1a22", 6, 12))
	th.set_color("font_color", "PrimaryButton", C("#fff4ec"))
	th.set_color("font_disabled_color", "PrimaryButton", C("#b0909a"))
	th.set_type_variation("GhostButton", "Button")
	th.set_stylebox("normal", "GhostButton", _box("#352c3c", "#463a4e", 6, 8))
	th.set_stylebox("hover", "GhostButton", _box("#3e3446", "#e4a648", 6, 8))
	return th

func lbl(text: String, sz := 16, col := "#ede3cd", wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", C(col))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func h3(text: String) -> Label:
	return lbl(text.to_upper(), 12, "#a7998f")

func title(text: String, col := "#ede3cd", sz := 26) -> Label:
	var l := lbl(text, sz, col)
	l.add_theme_font_override("font", display_font)
	return l

## A two-line option button: name and cost on top, description below.
func opt(name: String, cost: String, desc: String, cb: Callable, disabled := false, pressed := false) -> Button:
	var b := Button.new()
	b.text = name + ("   ·   " + cost if cost != "" else "") + ("\n" + desc if desc != "" else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = disabled
	b.toggle_mode = pressed
	b.button_pressed = pressed
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	return b

func panel(parent: Container, min_w := 0.0) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = min_w
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	parent.add_child(p)
	return v

func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


# ---------------------------------------------------------------- layout

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = C("#1d1822")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(k, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	var tbox := VBoxContainer.new()
	tbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tbox)
	tbox.add_child(title("Lairkeeper", "#e4a648", 40))
	subtitle = lbl("Dig by day. Feast by night.", 15, "#a7998f")
	tbox.add_child(subtitle)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	header.add_child(stats)
	for e in [["day", "Night", "#ede3cd"], ["hours", "Hours", "#c9a7ff"], ["gold", "Gold", "#e4a648"], ["hp", "Your HP", "#ff7d8f"], ["souls", "Souls", "#ede3cd"]]:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _box("#28212e", "#463a4e", 6, 8))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		p.add_child(v)
		v.add_child(lbl(e[1].to_upper(), 11, "#a7998f", false))
		var val := lbl("0", 20, e[2], false)
		v.add_child(val)
		stat_vals[e[0]] = val
		stats.add_child(p)

	body = BoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 3.0
	body.add_child(left)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box("#0e0b10", "#463a4e", 8, 2))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(frame)
	board = BoardScript.new()
	board.custom_minimum_size = Vector2(320, 240)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.tile_clicked.connect(_on_tile_clicked)
	board.tile_hovered.connect(_on_tile_hovered)
	frame.add_child(board)

	var bbar := HBoxContainer.new()
	bbar.add_theme_constant_override("separation", 8)
	left.add_child(bbar)
	turn_lbl = title("Day 1", "#e4a648", 24)
	turn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bbar.add_child(turn_lbl)
	zoom_row = HBoxContainer.new()
	bbar.add_child(zoom_row)
	for z in [["+", func(): board.zoom_by(1.25)], ["−", func(): board.zoom_by(0.8)], ["Whole map", _toggle_fit]]:
		var zb := Button.new()
		zb.text = z[0]
		zb.theme_type_variation = "GhostButton"
		zb.pressed.connect(z[1])
		zoom_row.add_child(zb)
	main_btn = Button.new()
	main_btn.theme_type_variation = "PrimaryButton"
	main_btn.text = "Let night fall"
	main_btn.pressed.connect(_on_main_btn)
	bbar.add_child(main_btn)
	tip_lbl = lbl("", 15, "#a7998f")
	left.add_child(tip_lbl)

	side = ScrollContainer.new()
	side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(side)
	var side_inner := VBoxContainer.new()
	side_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(side_inner)
	day_box = VBoxContainer.new()
	day_box.add_theme_constant_override("separation", 12)
	day_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_inner.add_child(day_box)
	night_box = HFlowContainer.new()
	night_box.add_theme_constant_override("h_separation", 12)
	night_box.add_theme_constant_override("v_separation", 12)
	night_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_inner.add_child(night_box)

	room_box = panel(day_box)
	layout_box = panel(day_box)
	trap_box = panel(day_box)
	minion_box = panel(day_box)
	party_box = panel(day_box)
	boon_box = panel(day_box)
	var dl := panel(day_box)
	dl.add_child(h3("Chronicle"))
	log_labels.append(_log_label(dl))

	unit_box = panel(night_box, 300)
	power_box = panel(night_box, 300)
	power_panel = power_box.get_parent()
	var how := panel(night_box, 300)
	how.add_child(h3("Controls"))
	how.add_child(lbl("Click one of your units, then a blue tile to move or a hero ringed in red to attack.\nDrag the map or use WASD to look around. Scroll to zoom.\nWalls and furniture block movement and arrows.\nHover a hero to see where it can strike next turn.\nE ends your turn. 1 and 2 cast your spells.", 14, "#a7998f"))
	var nl := panel(night_box, 300)
	nl.add_child(h3("Battle log"))
	log_labels.append(_log_label(nl))

	start_ov = _overlay()
	pick_ov = _overlay()
	over_ov = _overlay()

func _log_label(parent: Container) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", 14)
	parent.add_child(r)
	return r

func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box("#28212e", "#463a4e", 10, 24))
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	o.set_meta("box", v)
	o.set_meta("center", center)
	o.set_meta("card", p)
	add_child(o)
	return o

func apply_layout() -> void:
	var vp := get_viewport_rect().size
	var narrow := vp.x < 1000.0
	for o in [start_ov, pick_ov, over_ov]:
		o.get_meta("card").custom_minimum_size.x = minf(1080.0, vp.x - 40.0)
		o.get_meta("center").custom_minimum_size = vp
	if night:
		body.vertical = true
		side.custom_minimum_size = Vector2(0, 270 if not narrow else 300)
		side.size_flags_vertical = Control.SIZE_FILL
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		body.vertical = narrow
		side.custom_minimum_size = Vector2(0, 320) if narrow else Vector2(360, 0)
		side.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL
	day_box.visible = not night
	night_box.visible = night
	zoom_row.visible = night


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	stat_vals.day.text = str(Game.day)
	stat_vals.hours.text = str(Game.hours)
	stat_vals.gold.text = str(Game.gold)
	stat_vals.hp.text = "%d/%d" % [battle.mon.hp if battle else Game.mhp, Game.mmax]
	stat_vals.souls.text = str(Game.souls)
	if night:
		render_night()
	else:
		turn_lbl.text = "Day %d · %d hour%s left" % [Game.day, Game.hours, "" if Game.hours == 1 else "s"]
		render_room_panel()
		render_layout_panel()
		render_trap_panel()
		render_minion_panel()
		render_party()
	render_logs()

func render_logs() -> void:
	var cols := {"kill": "#ede3cd", "bad": "#ff9a8a", "info": "#c9a7ff", "": "#a7998f"}
	var t := ""
	for l in Game.logs:
		t += "[color=%s]%s[/color]\n" % [cols.get(l.kind, "#a7998f"), l.msg]
	for r in log_labels:
		r.text = t

func _on_tip(msg: String, warn: bool) -> void:
	tip_lbl.text = msg
	tip_lbl.add_theme_color_override("font_color", C("#ff9a8a") if warn else C("#a7998f"))

func render_room_panel() -> void:
	clear(room_box)
	var i := Game.sel
	if i < 0:
		room_box.add_child(h3("Your dungeon"))
		room_box.add_child(title("Pick a chamber"))
		room_box.add_child(lbl("Click any room on the map to dig, build or upgrade.", 15, "#a7998f"))
		return
	var s: Dictionary = Game.slots[i]
	if s.state == "rock":
		room_box.add_child(h3("Selected"))
		room_box.add_child(title("Solid rock"))
		if Game.diggable(i):
			room_box.add_child(lbl("Dig out a new 5x5 chamber. Each one you dig costs a little more.", 15, "#a7998f"))
			room_box.add_child(opt("Dig chamber", "1h · %dg" % Game.dig_cost(), "", func(): Game.dig(i), Game.hours < 1 or Game.gold < Game.dig_cost()))
		else:
			room_box.add_child(lbl("Dig out a chamber next to it first.", 15, "#a7998f"))
	elif s.state == "dug":
		room_box.add_child(h3("Selected"))
		room_box.add_child(title("Empty chamber"))
		room_box.add_child(lbl("Each room can be built once and comes with its own furniture. Some pieces block movement and arrows.", 14, "#a7998f"))
		room_box.add_child(opt("Move your Lair here", "1h", "Where your throne sits and every fight starts.", func(): Game.move_lair(i), Game.hours < 1))
		var sig := []
		var com := []
		for t in Data.ROOMS:
			if Game.can_build(t):
				(sig if Data.ROOMS[t].has("owner") else com).append(t)
		if sig.size() > 0:
			room_box.add_child(lbl(("%s's rooms" % Game.M.name).to_upper(), 12, Game.M.col))
			for t in sig:
				room_box.add_child(_room_opt(i, t))
		if com.size() > 0:
			room_box.add_child(h3("Common rooms"))
			for t in com:
				room_box.add_child(_room_opt(i, t))
	else:
		var R: Dictionary = Data.ROOMS[s.type]
		room_box.add_child(h3("Selected" + (" · level %d" % s.lvl if R.cost.size() > 1 else "")))
		room_box.add_child(title(R.name, Game.M.col if s.type == "lair" else R.col))
		room_box.add_child(lbl(Data.room_eff(s.type, s.lvl), 15))
		if s.lvl < R.cost.size():
			var c: int = R.cost[s.lvl]
			room_box.add_child(opt("Upgrade to level %d" % (s.lvl + 1), "1h · %dg" % c, R.get("next", Data.room_eff(s.type, s.lvl + 1)), func(): Game.upgrade(i), Game.gold < c or Game.hours < 1))
		if R.has("recruit"):
			var k: String = R.recruit
			var U: Dictionary = Data.UNITS[k]
			var n := Game.count_of(k)
			var cap := Game.cap_of(k)
			room_box.add_child(opt("Recruit %s" % U.name.to_lower(), "%dg" % U.cost, "%d of %d housed · %d HP, hits for %d, moves %d" % [n, cap, U.hp, U.atk, U.move],
				func(): Game.recruit(k), n >= cap or Game.gold < U.cost))
		if not R.get("fixed", false):
			room_box.add_child(opt("Tear it down", "1h", "No refund. Leaves an empty chamber.", func(): Game.demolish(i), Game.hours < 1))

func _room_opt(i: int, t: String) -> Button:
	var R: Dictionary = Data.ROOMS[t]
	var c: int = R.cost[0]
	return opt(R.name, "1h · %dg" % c, Data.room_eff(t, 1), func(): Game.build(i, t), Game.gold < c or Game.hours < 1)

func render_layout_panel() -> void:
	clear(layout_box)
	layout_box.add_child(h3("Entrance"))
	layout_box.add_child(lbl("Heroes file in through one gate on the outer edge of your dungeon. Put it right next to your lair to fight at once, or far away to make them walk a gauntlet.", 14, "#a7998f"))
	var on := Game.ent_mode
	layout_box.add_child(opt("Click an edge tile..." if on else "Move the entrance", "1h",
		"Glowing tiles are valid. Press again to cancel." if on else "Any open floor tile on the edge of the map.",
		_toggle_entrance, Game.hours < 1 and not on, on))

func _toggle_entrance() -> void:
	Game.ent_mode = not Game.ent_mode
	Game.trap_mode = ""
	Game.sel_minion = null
	refresh()

func render_trap_panel() -> void:
	clear(trap_box)
	var types := []
	for t in Data.TRAPS:
		if Game.trap_unlocked(t):
			types.append(t)
	if types.is_empty():
		trap_box.add_child(h3("Traps"))
		trap_box.add_child(lbl("Build a Trap Workshop to start laying traps. Traps stay in place for the whole run.", 14, "#a7998f"))
		return
	trap_box.add_child(h3("Traps · %d of %d placed" % [Game.traps.size(), Game.trap_cap()]))
	for t in types:
		var T: Dictionary = Data.TRAPS[t]
		trap_box.add_child(opt(T.name, "%dg · %d dmg" % [Game.trap_cost(t), Game.trap_dmg(t)], T.desc, func(): _toggle_trap(t), false, Game.trap_mode == t))
	trap_box.add_child(lbl("Click open floor to place. Click a trap to remove it for half its cost. Press the trap type again to stop." if Game.trap_mode != "" else "Pick a trap type, then click the map.", 14, "#a7998f"))

func _toggle_trap(t: String) -> void:
	Game.trap_mode = "" if Game.trap_mode == t else t
	Game.sel_minion = null
	Game.ent_mode = false
	refresh()

func render_minion_panel() -> void:
	clear(minion_box)
	if Game.minions.is_empty():
		minion_box.add_child(h3("Minions"))
		minion_box.add_child(lbl("Recruit minions in rooms like the Goblin Barracks. They guard their post every night. If they die, they stay dead.", 14, "#a7998f"))
		return
	var counts := {}
	for m in Game.minions:
		counts[m.kind] = counts.get(m.kind, 0) + 1
	minion_box.add_child(h3("Minions · %d" % Game.minions.size()))
	var parts := []
	for k in counts:
		parts.append("%d × %s" % [counts[k], Data.UNITS[k].name])
	minion_box.add_child(lbl(", ".join(parts), 15))
	minion_box.add_child(lbl("Moving a %s. Click an open tile for its new post." % Data.UNITS[Game.sel_minion.kind].name.to_lower() if Game.sel_minion != null else "Click a minion on the map, then an open tile, to move its guard post.", 14, "#a7998f"))

func render_party() -> void:
	clear(party_box)
	party_box.add_child(h3("Tonight's raiders"))
	var names := []
	for k in Game.party:
		names.append(Data.UNITS[k].name)
	party_box.add_child(lbl(", ".join(names), 16, "#ede3cd"))
	party_box.add_child(lbl("They file in through your entrance a few at a time and hunt for you.", 14, "#a7998f"))
	clear(boon_box)
	boon_box.add_child(h3("Dark boons"))
	boon_box.add_child(lbl(", ".join(Game.taken) if Game.taken.size() > 0 else "None yet. Survive a night to earn one.", 15, "#c9a7ff" if Game.taken.size() > 0 else "#a7998f"))


# ---------------------------------------------------------------- night panels

func render_night() -> void:
	if battle == null:
		return
	turn_lbl.text = "The heroes advance" if battle.busy and battle.sel == null else "Night %d · round %d" % [Game.day, battle.turn]
	main_btn.text = "End turn"
	main_btn.disabled = battle.busy or battle.over
	if _hover_hero != null and _hover_hero.hp > 0:
		_render_hero(_hover_hero)
	else:
		_render_unit()
	clear(power_box)
	var si := Game.slot_idx("collapse")
	power_panel.visible = si >= 0
	if si >= 0:
		var l := Game.lvl("collapse")
		power_box.add_child(h3("Room powers"))
		power_box.add_child(opt("Collapse the Hall", "used" if battle.used.has("collapse") else "once",
			"%d damage to everyone standing in the Collapsing Hall, your units included." % (8 + (l - 1) * 4),
			func(): battle.collapse(), battle.used.has("collapse") or battle.busy))

func _stats_row(hp: int, mx: int, mv: int, hit: int, rng: int) -> Label:
	return lbl("HP %d/%d    Move %d    Hit %d    Range %d" % [hp, mx, mv, hit, rng], 15, "#ede3cd")

func _render_unit() -> void:
	clear(unit_box)
	var u := battle.sel
	if u == null:
		unit_box.add_child(h3("Selected"))
		unit_box.add_child(title("No unit"))
		unit_box.add_child(lbl("Click one of your units to command it.", 14, "#a7998f"))
		return
	unit_box.add_child(h3(("You" if u.kind == "monster" else ("Your thrall" if u.thrall else "Your minion")) + (" · done" if u.acted and u.moved else "")))
	unit_box.add_child(title(u.uname, Game.M.col if u.kind == "monster" else "#ede3cd", 22))
	unit_box.add_child(_stats_row(u.hp, u.max_hp, battle.move_of(u), battle.atk_of(u), u.rng))
	if u.kind == "monster":
		for sp in Game.M.specials:
			var cd: int = u.cds.get(sp.id, 0)
			var state := ("%d turn%s" % [cd, "s" if cd > 1 else ""]) if cd > 0 else ("acted" if u.acted else "ready")
			unit_box.add_child(opt(sp.name, state, sp.desc + ("" if sp.get("free", false) else " Uses your action."),
				func(): battle.arm_spell(sp.id), not battle.can_cast(sp), battle.mode == sp.id))

func _render_hero(h) -> void:
	clear(unit_box)
	var cond := []
	if h.stun > 0: cond.append("mesmerized")
	if h.conf > 0: cond.append("confused")
	if h.root > 0: cond.append("snared")
	if h.slow > 0: cond.append("slowed")
	if h.flee: cond.append("fleeing with gold")
	unit_box.add_child(h3("Hero" + (" · " + ", ".join(cond) if cond.size() > 0 else "")))
	unit_box.add_child(title("%s the %s" % [h.uname, h.d.name], "#ede3cd", 22))
	unit_box.add_child(_stats_row(h.hp, h.max_hp, battle.move_of(h), h.atk, h.rng))
	unit_box.add_child(lbl(h.d.get("note", "Hunts down the nearest monster.") + " Red tiles show where it can strike next turn.", 14, "#a7998f"))


# ---------------------------------------------------------------- input

func _on_tile_clicked(p: Vector2i) -> void:
	if start_ov.visible or pick_ov.visible or over_ov.visible:
		return
	if battle:
		battle.handle_click(p)
	else:
		Game.day_click(p)

func _on_tile_hovered(p: Vector2i) -> void:
	if battle == null:
		return
	var u = battle.unit_at(p) if Game.in_b(p) else null
	var h = u if u != null and u.side == "h" else null
	if h == _hover_hero:
		return
	_hover_hero = h
	battle.threat = battle.threat_of(h) if h != null else {}
	render_night()

func _on_main_btn() -> void:
	if battle == null:
		start_night()
	else:
		battle.enemy_turn()

func _toggle_fit() -> void:
	if not board.zoomed_out():
		board.fit()
	elif battle:
		board.look_at_tile(battle.mon.pos, board.night_z())

func _unhandled_input(e: InputEvent) -> void:
	if battle == null or battle.over or pick_ov.visible or over_ov.visible:
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_W, KEY_UP: board.pan(Vector2(0, -2))
		KEY_S, KEY_DOWN: board.pan(Vector2(0, 2))
		KEY_A, KEY_LEFT: board.pan(Vector2(-2, 0))
		KEY_D, KEY_RIGHT: board.pan(Vector2(2, 0))
		KEY_E: battle.enemy_turn()
		KEY_ESCAPE: battle.select(null)
		KEY_1, KEY_2:
			var idx := 0 if e.keycode == KEY_1 else 1
			if idx < Game.M.specials.size():
				battle.arm_spell(Game.M.specials[idx].id)


# ---------------------------------------------------------------- phases

func start_night() -> void:
	battle = Battle.new()
	add_child(battle)
	battle.changed.connect(refresh)
	battle.finished.connect(_on_finished)
	battle.focus.connect(board.follow)
	board.battle = battle
	night = true
	_hover_hero = null
	subtitle.text = "Night %d. The heroes are inside." % Game.day
	apply_layout()
	battle.start()
	await get_tree().process_frame
	board.look_at_tile(battle.mon.pos, board.night_z())
	refresh()

func end_night() -> void:
	board.battle = null
	if battle:
		battle.queue_free()
	battle = null
	night = false
	_hover_hero = null
	main_btn.text = "Let night fall"
	main_btn.disabled = false
	subtitle.text = "%s. Dig, build, and set the trap." % Game.M.name
	apply_layout()
	await get_tree().process_frame
	board.fit()

func _on_finished(won: bool) -> void:
	if won:
		var r := battle.resolve_win()
		Platform.on_night_survived(Game.day)
		_show_pick(r)
	else:
		var earned := Game.end_run()
		_show_over(earned)

func _show_pick(r: Dictionary) -> void:
	var v: VBoxContainer = pick_ov.get_meta("box")
	clear(v)
	v.add_child(title("Night %d: the raiders are dead" % Game.day, "#e4a648", 38))
	var extra := ""
	if r.stolen > 0: extra += ", %d gold stolen by thieves who got away" % r.stolen
	var lost := "You lost %d minion%s; recruit replacements by day. " % [r.lost, "s" if r.lost > 1 else ""] if r.lost > 0 else ""
	v.add_child(lbl("%d heroes defeated, %d gold looted%s. %sChoose a dark boon." % [r.kills, r.loot, extra, lost], 16, "#a7998f"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for o in Game.boon_choices():
		var bt := opt(o.name, "", o.desc, func(): _pick(o))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.custom_minimum_size = Vector2(200, 90)
		row.add_child(bt)
	pick_ov.visible = true

func _pick(o: Dictionary) -> void:
	pick_ov.visible = false
	await end_night()
	Game.dawn(o)
	Game.tip("Scouts report a Paladin among tonight's raiders." if Game.day % 5 == 0 else "A new day. Dig, build, and reset your traps.", Game.day % 5 == 0)

func _show_over(earned: int) -> void:
	var v: VBoxContainer = over_ov.get_meta("box")
	clear(v)
	v.add_child(title("You have been slain", "#e4a648", 38))
	v.add_child(lbl("%s falls on night %d. The village throws a feast. %d souls carry over to your next life." % [Game.M.name, Game.day, earned], 16, "#a7998f"))
	var dug := 0
	for s in Game.slots:
		if s.state != "rock":
			dug += 1
	v.add_child(lbl("Nights survived: %d    Heroes defeated: %d    Rooms dug: %d    Souls banked: %d" % [Game.day - 1, Game.kills, dug, Game.meta.souls], 17))
	var bt := Button.new()
	bt.text = "Rise again"
	bt.theme_type_variation = "PrimaryButton"
	bt.pressed.connect(_rise_again)
	v.add_child(bt)
	over_ov.visible = true

func show_start() -> void:
	var v: VBoxContainer = start_ov.get_meta("box")
	clear(v)
	v.add_child(title("Choose your monstrous form", "#e4a648", 38))
	v.add_child(lbl("You start with a cave mouth, two empty chambers and your lair. Dig outward, room by room. Every room is real ground the heroes must cross, so where you put your lair, your traps and your minions decides every fight.", 16, "#a7998f"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	v.add_child(flow)
	for k in Data.MONSTERS:
		var M: Dictionary = Data.MONSTERS[k]
		var rooms := []
		for t in Data.ROOMS:
			if Data.ROOMS[t].get("owner", "") == k:
				rooms.append(Data.ROOMS[t].name)
		var spells := []
		for sp in M.specials:
			spells.append("%s: %s" % [sp.name, sp.desc])
		var b := Button.new()
		b.text = "%s\n%s\n%d HP · moves %d · %s %d dmg, range %d\n%s\n\n%s\n\nRooms: %s" % [M.role.to_upper(), M.name, M.hp, M.move, M.attack, M.atk, M.rng, M.blurb, "\n".join(spells), ", ".join(rooms)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(320, 0)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", C(M.col))
		b.pressed.connect(func(): _choose(k))
		flow.add_child(b)
	var meta := HBoxContainer.new()
	v.add_child(meta)
	var ml := lbl("Souls banked: %d · Most nights survived: %d" % [Game.meta.souls, Game.meta.best], 15, "#c9a7ff", false)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(ml)
	var l: int = Game.meta.hoard
	var price := 15 * (l + 1)
	var hb := Button.new()
	hb.theme_type_variation = "GhostButton"
	hb.text = "Hoard maxed: +60 starting gold" if l >= 3 else "Bury treasure: +20 starting gold (%d souls)" % price
	hb.disabled = l >= 3 or Game.meta.souls < price
	hb.pressed.connect(_buy_hoard.bind(price))
	meta.add_child(hb)
	start_ov.visible = true

func _rise_again() -> void:
	over_ov.visible = false
	await end_night()
	show_start()

func _buy_hoard(price: int) -> void:
	Game.meta.souls -= price
	Game.meta.hoard += 1
	Game.save_meta()
	show_start()

func _choose(k: String) -> void:
	start_ov.visible = false
	Game.new_run(k)
	board.fit(true)
	Game.tip("Click a chamber to build in it, or the rock beside your rooms to dig. Heroes enter at the glowing gate.")
