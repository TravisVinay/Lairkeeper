extends Control
## Builds the interface and wires the day phase, the night battle and the overlays together.
## Day: board and building panels side by side. Night: just the map, with the fight HUD on top.

const BoardScript := preload("res://scripts/board.gd")
const HudScript := preload("res://scripts/night_hud.gd")
const MenusScript := preload("res://scripts/menus.gd")
const TutorialScript := preload("res://scripts/tutorial.gd")

var battle: Battle = null
var night := false
## True while a run is being played. Only then is the run autosaved.
var in_run := false
var menus: Control
var board: Control
var display_font: Font

var body: BoxContainer
var left: VBoxContainer
var side: ScrollContainer
var night_side: ScrollContainer
var day_column: VBoxContainer     # inside the day side panel; the tutorial coach sits on top
var tutorial: Node
var day_box: VBoxContainer
var hud: Control
var bbar: HBoxContainer
var turn_lbl: Label
var main_btn: Button
var zoom_row: HBoxContainer
var floor_tabs: HBoxContainer
var tip_lbl: Label
var subtitle: Label
var stat_vals := {}

var revive_box: VBoxContainer   # buy back a fallen duo member
var room_box: VBoxContainer
var layout_box: VBoxContainer
var trap_box: VBoxContainer
var minion_box: VBoxContainer
var party_box: VBoxContainer
var boon_box: VBoxContainer
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
	Game.changed.connect(_autosave)
	Game.logged.connect(render_logs)
	Game.tipped.connect(_on_tip)
	get_viewport().size_changed.connect(apply_layout)
	Settings.changed.connect(apply_layout)
	Game.new_run("vampire")   # a placeholder dungeon to draw behind the title screen
	menus.show_title()
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
	var focus := _box("#000000", "#e4a648", 6, 10, 2)
	focus.draw_center = false   # just the outline; C() makes every color opaque
	th.set_stylebox("focus", "Button", focus)
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

## An option card: an optional small tag, the name with cost chips on the right, and a muted
## description below. Cost parts like "1h", "35g" or "25 souls" are colored, and turn red when
## you can't pay them, so a greyed-out option shows why.
func opt(name: String, cost: String, desc: String, cb: Callable, disabled := false, pressed := false, tag := "", tag_col := "#a7998f") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	if tag != "":
		v.add_child(lbl(tag.to_upper(), 11, tag_col))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	var n := lbl(name, 15, "#ede3cd")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(n)
	if cost != "":
		for part in cost.split(" · "):
			top.add_child(_cost_chip(part))
	if desc != "":
		v.add_child(lbl(desc, 13, "#b3a59b"))
	return card(v, cb, disabled, pressed)

func _cost_chip(part: String) -> Label:
	var col := "#a7998f"
	var short := false
	var num := part.to_int()
	if part.ends_with("run souls") or part.ends_with("run soul"):
		col = "#c9a7ff"
		short = Game.souls < num
	elif part.ends_with("souls"):
		col = "#c9a7ff"
		short = Game.meta.souls < num
	elif part.ends_with("h") and part.trim_suffix("h").is_valid_int():
		col = "#c9a7ff"
		short = not night and Game.hours < num
	elif part.ends_with("g") and part.trim_suffix("g").is_valid_int():
		col = "#e4a648"
		short = not night and Game.gold < num
	elif part == "ready":
		col = "#8fd18f"
	elif part.begins_with("+") and part.ends_with("%"):
		col = "#c9a7ff"   # a Dread modifier's souls bonus
	var l := lbl(part, 14, "#ff7d8f" if short else col, false)
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return l

## Wraps any content in a clickable card. A Button sits behind the content and draws the
## frame and hover states; the content ignores the mouse, so clicks land on the Button.
## Using a PanelContainer as the root means the card sizes itself to wrapped text.
func card(content: Control, cb: Callable, disabled := false, pressed := false) -> PanelContainer:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var b := Button.new()
	b.disabled = disabled
	b.toggle_mode = pressed
	b.button_pressed = pressed
	b.pressed.connect(cb)
	root.add_child(b)
	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 11)
	for k in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, 8)
	m.add_child(content)
	root.add_child(m)
	_ignore_mouse(m)
	if disabled:
		m.modulate = Color(1, 1, 1, 0.5)
	root.set_meta("button", b)
	return root

func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)

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
		val.set_meta("col", e[2])
		v.add_child(val)
		stat_vals[e[0]] = val
		stats.add_child(p)
	var mon_btn := Button.new()
	mon_btn.text = "Monster"
	mon_btn.tooltip_text = "Your monster's damage, armor, spells and bonuses"
	mon_btn.theme_type_variation = "GhostButton"
	mon_btn.pressed.connect(func(): menus.open_stats(Callable()))
	stats.add_child(mon_btn)
	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.tooltip_text = "Pause, settings and the room catalog (Esc)"
	menu_btn.theme_type_variation = "GhostButton"
	menu_btn.pressed.connect(func(): menus.open_pause())
	stats.add_child(menu_btn)

	body = BoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 3.0
	body.add_child(left)
	floor_tabs = HBoxContainer.new()
	floor_tabs.add_theme_constant_override("separation", 6)
	left.add_child(floor_tabs)
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
	board.floor_changed.connect(func(_f): render_floor_tabs())
	frame.add_child(board)
	hud = HudScript.new()
	frame.add_child(hud)
	hud.visible = false

	bbar = HBoxContainer.new()
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
	day_column = VBoxContainer.new()
	day_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_column.add_theme_constant_override("separation", 12)
	side.add_child(day_column)
	day_box = VBoxContainer.new()
	day_box.add_theme_constant_override("separation", 12)
	day_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_column.add_child(day_box)

	# night column: the selected unit's card and room powers live here, off the map
	night_side = ScrollContainer.new()
	night_side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(night_side)
	var dock := VBoxContainer.new()
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.add_theme_constant_override("separation", 12)
	night_side.add_child(dock)
	hud.build(self, board, dock)

	revive_box = panel(day_box)
	room_box = panel(day_box)
	layout_box = panel(day_box)
	trap_box = panel(day_box)
	minion_box = panel(day_box)
	party_box = panel(day_box)
	boon_box = panel(day_box)
	var dl := panel(day_box)
	dl.add_child(h3("Chronicle"))
	log_labels.append(_log_label(dl))

	start_ov = _overlay()
	pick_ov = _overlay()
	over_ov = _overlay()
	menus = MenusScript.new()
	add_child(menus)
	menus.build(self)
	tutorial = TutorialScript.new()
	add_child(tutorial)
	tutorial.build(self)

func _log_label(parent: Container) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", 14)
	parent.add_child(r)
	return r

func _overlay(parent: Node = null) -> Control:
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
	(parent if parent else self).add_child(o)
	return o

func apply_layout() -> void:
	var vp := get_viewport_rect().size
	var narrow := vp.x < 1000.0
	for o in [start_ov, pick_ov, over_ov]:
		o.get_meta("card").custom_minimum_size.x = minf(1080.0, vp.x - 40.0)
		o.get_meta("center").custom_minimum_size = vp
	menus.apply_layout(vp)
	body.vertical = narrow
	for s in [side, night_side]:
		s.custom_minimum_size = Vector2(0, 320) if narrow else Vector2(320 if s == night_side else 360, 0)
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL
	# at night the map takes the space, with a slim column for the selected unit
	side.visible = not night
	night_side.visible = night
	bbar.visible = not night
	tip_lbl.visible = not night
	hud.visible = night
	zoom_row.visible = false


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	stat_vals.day.text = str(Game.day)
	stat_vals.hours.text = str(Game.hours)
	stat_vals.gold.text = str(Game.gold)
	if Game.duo():
		# the Dark Lord · his Squire
		var lord := str(battle.mon.hp if battle else Game.mhp) if battle or not "lord" in Game.down else "–"
		var sq := str(battle.squire.hp if battle else Game.shp) if battle or not "squire" in Game.down else "–"
		stat_vals.hp.text = "%s · %s" % [lord, sq]
	else:
		stat_vals.hp.text = "%d/%d" % [battle.mon.hp if battle else Game.mhp, Game.mmax]
	stat_vals.souls.text = str(Game.souls)
	var out_of_time := not night and Game.hours <= 0
	stat_vals.hours.add_theme_color_override("font_color", C("#ff7d8f" if out_of_time else stat_vals.hours.get_meta("col")))
	stat_vals.hours.get_parent().get_parent().visible = not night
	if night:
		render_night()
	else:
		main_btn.disabled = not Game.allowed("night")
		turn_lbl.text = "Day %d · out of time, let night fall" % Game.day if out_of_time else "Day %d · %d hour%s left" % [Game.day, Game.hours, "" if Game.hours == 1 else "s"]
		render_revive_panel()
		render_room_panel()
		render_layout_panel()
		render_trap_panel()
		render_minion_panel()
		render_party()
	render_floor_tabs()
	render_logs()
	if menus.pause_ov.visible:
		menus.render_pause()   # Quit unlocks once the heroes finish moving

func _autosave() -> void:
	if in_run and battle == null:
		Game.save_run()

## One tab per floor. At night each tab also counts the heroes on that floor.
func render_floor_tabs() -> void:
	clear(floor_tabs)
	floor_tabs.visible = Game.floors > 1
	for f in Game.floors:
		var heroes := 0
		if battle:
			for u in battle.alive("h"):
				if Game.floor_of(u.pos) == f:
					heroes += 1
		var lair := Game.floor_of_slot(Game.slot_idx("lair")) == f
		var t := "Ground floor" if f == 0 else "Floor %d" % (f + 1)
		if lair: t += " · lair"
		if heroes > 0: t += " · %d hero%s" % [heroes, "es" if heroes > 1 else ""]
		var b := Button.new()
		b.text = t
		b.theme_type_variation = "GhostButton"
		b.toggle_mode = true
		b.button_pressed = board.shown_floor == f
		b.pressed.connect(_show_floor.bind(f))
		floor_tabs.add_child(b)

func _show_floor(f: int) -> void:
	board.show_floor(f)
	render_floor_tabs()

func render_logs() -> void:
	var cols := {"kill": "#ede3cd", "bad": "#ff9a8a", "info": "#c9a7ff", "": "#a7998f"}
	var t := ""
	for l in Game.logs:
		t += "[color=%s]%s[/color]\n" % [cols.get(l.kind, "#a7998f"), l.msg]
	for r in log_labels:
		r.text = t
	hud.set_log(Game.logs)

func _on_tip(msg: String, warn: bool) -> void:
	hud.set_tip(msg, warn)
	tip_lbl.text = msg
	tip_lbl.add_theme_color_override("font_color", C("#ff9a8a") if warn else C("#a7998f"))

## For a duo: buy back a fallen Dark Lord or Squire with this run's souls.
func render_revive_panel() -> void:
	clear(revive_box)
	revive_box.get_parent().visible = Game.down.size() > 0
	if Game.down.is_empty():
		return
	revive_box.add_child(h3("Fallen"))
	for who in Game.down:
		var nm: String = Game.M.name if who == "lord" else Game.M.partner.name
		revive_box.add_child(opt("Bring back %s" % nm, "%d run soul%s" % [Game.day, "" if Game.day == 1 else "s"],
			"Returns at full HP. Paid from the souls this run has earned (%d), so the run banks less." % Game.souls,
			Game.buy_back.bind(who), Game.souls < Game.day))

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
		var ground := Game.floor_of_slot(i) == 0
		room_box.add_child(title("Solid rock" if ground else "Open air"))
		if Game.diggable(i):
			room_box.add_child(lbl(("Dig out" if ground else "Build out") + " a new 5x5 chamber. Each one costs a little more.", 15, "#a7998f"))
			room_box.add_child(opt("Dig chamber" if ground else "Build chamber", "1h · %dg" % Game.dig_cost(), "", func(): Game.dig(i), Game.hours < 1 or Game.gold < Game.dig_cost() or not Game.allowed("dig:%d" % i)))
		else:
			room_box.add_child(lbl("Open up a chamber next to it first.", 15, "#a7998f"))
	elif s.state == "dug":
		room_box.add_child(h3("Selected"))
		room_box.add_child(title("Empty chamber"))
		room_box.add_child(lbl("Each room can be built once and comes with its own furniture. Some pieces block movement and arrows.", 14, "#a7998f"))
		var mh := Game.lair_move_hours(i)
		room_box.add_child(opt("Move your Lair here", "%dh" % mh, "Where your throne sits and every fight starts." + (" Moving to another floor takes a whole day." if mh > 1 else ""),
			func(): Game.move_lair(i), Game.hours < mh or not Game.allowed("lair")))
		var sig := []
		var com := []
		for t in Data.ROOMS:
			if t != "stairs" and Game.can_build(t, i):
				(sig if Data.ROOMS[t].has("owner") else com).append(t)
		if Game.floor_type_count("stairs", Game.floor_of_slot(i)) == 0:
			room_box.add_child(h3("Build higher"))
			var why := Game.stairs_block(i)
			if why == "":
				room_box.add_child(_room_opt(i, "stairs"))
			else:
				var c: int = Data.ROOMS.stairs.cost[0]
				room_box.add_child(opt("Stairs Up", "1h · %dg" % c, why, func(): pass, true))
		if sig.size() > 0:
			room_box.add_child(lbl(("%s's rooms" % Game.M.name).to_upper(), 12, Game.M.col))
			for t in sig:
				room_box.add_child(_room_opt(i, t))
		if com.size() > 0:
			room_box.add_child(h3("Common rooms"))
			for t in com:
				room_box.add_child(_room_opt(i, t))
		var locked := Game.locked_rooms_for(Game.mk).size()
		if locked > 0:
			room_box.add_child(lbl("%d more room%s can be unlocked with souls between runs." % [locked, "s" if locked > 1 else ""], 13, "#a7998f"))
	else:
		var R: Dictionary = Data.ROOMS[s.type]
		room_box.add_child(h3("Selected · level %d" % s.lvl))
		room_box.add_child(title(R.name, Game.M.col if s.type == "lair" else R.col))
		room_box.add_child(lbl(Data.room_eff(s.type, s.lvl), 15))
		var c := Data.room_cost(s.type, s.lvl)
		room_box.add_child(opt("Upgrade to level %d" % (s.lvl + 1), "1h · %dg" % c, R.get("next", Data.room_eff(s.type, s.lvl + 1)), func(): Game.upgrade(i), Game.gold < c or Game.hours < 1 or not Game.allowed("upgrade:%d" % i)))
		if R.has("recruit"):
			var k: String = R.recruit
			var U: Dictionary = Data.UNITS[k]
			var n := Game.count_of(k)
			var cap := Game.cap_of(k)
			room_box.add_child(opt("Recruit %s" % U.name.to_lower(), "%dg" % U.cost, "%d of %d housed · %d HP, hits for %d, moves %d" % [n, cap, U.hp, U.atk, U.move],
				func(): Game.recruit(k), n >= cap or Game.gold < U.cost or not Game.allowed("recruit:" + k)))
		var dec_on := Game.decor_room == i
		room_box.add_child(opt("Done rearranging" if dec_on else "Rearrange furniture", "free",
			"Click a piece, then an empty tile in this room. Press again when done." if dec_on
			else "Move this room's furniture. Wall heroes off and they'll smash their way through.",
			func(): Game.toggle_decor(i), not Game.allowed("decor") and not dec_on, dec_on))
		var nb := Game.broken_count(i)
		if nb > 0:
			var rc := nb * Data.DECOR_REPAIR
			room_box.add_child(opt("Repair %d smashed piece%s" % [nb, "s" if nb > 1 else ""], "%dg" % rc,
				"Heroes broke through here. Rubble blocks no one until it's rebuilt.",
				func(): Game.repair_room(i), Game.gold < rc or not Game.allowed("decor")))
		if not R.get("fixed", false):
			room_box.add_child(opt("Tear it down", "1h", "No refund. Leaves an empty chamber.", func(): Game.demolish(i), Game.hours < 1 or not Game.allowed("demolish")))

func _room_opt(i: int, t: String) -> Control:
	var R: Dictionary = Data.ROOMS[t]
	var c: int = R.cost[0]
	return opt(R.name, "1h · %dg" % c, Data.room_eff(t, 1), func(): Game.build(i, t), Game.gold < c or Game.hours < 1 or not Game.allowed("build:%d:%s" % [i, t]))

func render_layout_panel() -> void:
	clear(layout_box)
	layout_box.add_child(h3("Entrance"))
	layout_box.add_child(lbl("Heroes file in through one gate on the outer edge of your dungeon. Put it right next to your lair to fight at once, or far away to make them walk a gauntlet.", 14, "#a7998f"))
	var on := Game.ent_mode
	layout_box.add_child(opt("Click an edge tile..." if on else "Move the entrance", "1h",
		"Glowing tiles are valid. Press again to cancel." if on else "Any open floor tile on the edge of the map.",
		_toggle_entrance, (Game.hours < 1 or not Game.allowed("entrance")) and not on, on))

func _toggle_entrance() -> void:
	Game.ent_mode = not Game.ent_mode
	Game.trap_mode = ""
	Game.sel_minion = null
	Game.decor_room = -1
	Game.decor_pick = null
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
		trap_box.add_child(opt(T.name, "%dg · %d dmg" % [Game.trap_cost(t), Game.trap_dmg(t)], T.desc, func(): _toggle_trap(t), not Game.allowed("trap") and Game.trap_mode != t, Game.trap_mode == t))
	trap_box.add_child(lbl("Click open floor to place. Click a trap to remove it for half its cost. Press the trap type again to stop." if Game.trap_mode != "" else "Pick a trap type, then click the map.", 14, "#a7998f"))

func _toggle_trap(t: String) -> void:
	Game.trap_mode = "" if Game.trap_mode == t else t
	Game.sel_minion = null
	Game.ent_mode = false
	Game.decor_room = -1
	Game.decor_pick = null
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
	minion_box.add_child(lbl("Moving a %s. Click an open tile for its new post, or press Esc to leave it." % Data.UNITS[Game.sel_minion.kind].name.to_lower() if Game.sel_minion != null else "Click a minion on the map, then an open tile, to move its guard post.", 14, "#a7998f"))

func render_party() -> void:
	clear(party_box)
	party_box.add_child(h3("Tonight's raiders"))
	var names := []
	for k in Game.party:
		names.append(Data.UNITS[k].name)
	party_box.add_child(lbl(", ".join(names), 16, "#ede3cd"))
	party_box.add_child(lbl("They file in through your entrance a few at a time and hunt for you.", 14, "#a7998f"))
	# the Scrying Pool shows the raiders still to come
	var sees := mini(Game.lvl("scrying"), Game.future.size())
	for n in sees:
		var fn := []
		for k in Game.future[n]:
			fn.append(Data.UNITS[k].name)
		party_box.add_child(lbl("%s: %s" % ["Tomorrow" if n == 0 else "In %d nights" % (n + 1), ", ".join(fn)], 14, "#5fa8c8"))
	clear(boon_box)
	boon_box.add_child(h3("Dark boons"))
	boon_box.add_child(lbl(", ".join(Game.taken) if Game.taken.size() > 0 else "None yet.", 15, "#c9a7ff" if Game.taken.size() > 0 else "#a7998f"))
	if not Game.has_mod("godless"):
		boon_box.add_child(lbl("Next boon: survive night %d." % Game.next_boon_night(), 13, "#a7998f"))


# ---------------------------------------------------------------- night panels

func render_night() -> void:
	if battle:
		hud.render()


# ---------------------------------------------------------------- input

func _on_tile_clicked(p: Vector2i) -> void:
	if start_ov.visible or pick_ov.visible or over_ov.visible or menus.is_open():
		return
	if battle == null:
		Game.day_click(p)
		return
	if battle.busy or battle.over:
		return
	if battle.mode != "":
		battle.handle_click(p)
		return
	var u = battle.unit_at(p) if Game.in_b(p) else null
	if u != null and u.side == "h":
		var s = battle.sel
		if s != null and not s.acted and Game.in_range(s.pos, u.pos, s.rng):
			hud.inspect = null
			battle.handle_click(p)
		else:
			# out of reach: open the hero's pop-up instead
			hud.inspect = u
			battle.threat = battle.threat_of(u)
			render_night()
		return
	hud.inspect = null
	battle.threat = {}
	battle.handle_click(p)

func _on_tile_hovered(p: Vector2i) -> void:
	if battle == null or hud.inspect != null:
		return
	var u = battle.unit_at(p) if Game.in_b(p) else null
	var h = u if u != null and u.side == "h" else null
	if h == _hover_hero:
		return
	_hover_hero = h
	battle.threat = battle.threat_of(h) if h != null else {}

func _on_main_btn() -> void:
	if battle == null:
		if not Game.guard("night"):
			return
		start_night()
	else:
		battle.enemy_turn()

func _toggle_fit() -> void:
	if not board.zoomed_out():
		board.fit()
	elif battle:
		var p: Vector2i = battle.lead().pos if Game.floor_of(battle.lead().pos) == board.shown_floor else Vector2i(Game.BW / 2, board.shown_floor * Game.BH + Game.BH / 2)
		board.look_at_tile(p, board.night_z())

func _unhandled_input(e: InputEvent) -> void:
	if battle == null or battle.over or pick_ov.visible or over_ov.visible or menus.is_open():
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_W, KEY_UP: board.pan(Vector2(0, -2))
		KEY_S, KEY_DOWN: board.pan(Vector2(0, 2))
		KEY_A, KEY_LEFT: board.pan(Vector2(-2, 0))
		KEY_D, KEY_RIGHT: board.pan(Vector2(2, 0))
		KEY_E: battle.enemy_turn()
		KEY_F:
			if battle.sel != null and battle.sel.side == "p":
				battle.finish_unit(battle.sel)
		KEY_ESCAPE:
			hud.inspect = null
			battle.threat = {}
			battle.select(null)
		KEY_1, KEY_2:
			var idx := 0 if e.keycode == KEY_1 else 1
			# 1 and 2 cast the selected duo member's spells (or the monster's)
			var caster = battle.sel if battle.sel != null and battle.is_mon(battle.sel) else battle.lead()
			var sps: Array = battle.specials_of(caster)
			if idx < sps.size():
				battle.arm_spell(sps[idx].id)


# ---------------------------------------------------------------- phases

func start_night() -> void:
	battle = Battle.new()
	add_child(battle)
	battle.changed.connect(refresh)
	battle.finished.connect(_on_finished)
	battle.focus.connect(board.follow)
	board.battle = battle
	hud.battle = battle
	hud.inspect = null
	night = true
	_hover_hero = null
	subtitle.text = "Night %d. The heroes are inside." % Game.day
	apply_layout()
	battle.start()
	await get_tree().process_frame
	board.show_floor(Game.floor_of(battle.lead().pos))
	board.look_at_tile(battle.lead().pos, board.night_z())
	refresh()

func end_night() -> void:
	board.battle = null
	hud.battle = null
	hud.inspect = null
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
		in_run = false
		var was_tutorial := Game.tut >= 0
		tutorial.stop()
		var earned := Game.end_run()
		_show_over(earned, was_tutorial)

func _show_pick(r: Dictionary) -> void:
	var v: VBoxContainer = pick_ov.get_meta("box")
	clear(v)
	v.add_child(title("Night %d: the raiders are dead" % Game.day, "#e4a648", 38))
	var extra := ""
	if r.stolen > 0: extra += ", %d gold stolen by thieves who got away" % r.stolen
	var lost := "You lost %d minion%s; recruit replacements by day. " % [r.lost, "s" if r.lost > 1 else ""] if r.lost > 0 else ""
	var due := Game.boon_due(Game.day)
	var why := "Choose a dark boon." if due else ("Godless: no boons this run." if Game.has_mod("godless")
		else "Your next dark boon comes after night %d." % Game.next_boon_night())
	v.add_child(lbl("%d heroes defeated, %d gold looted%s. %s%s" % [r.kills, r.loot, extra, lost, why], 16, "#a7998f"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	if not due:
		var gb := Button.new()
		gb.text = "Greet the dawn"
		gb.theme_type_variation = "PrimaryButton"
		gb.pressed.connect(func(): _pick({}))
		row.add_child(gb)
	for o in (Game.boon_choices() if due else []):
		var bt := opt(o.name, "", o.desc, func(): _pick(o))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.custom_minimum_size = Vector2(200, 90)
		row.add_child(bt)
	pick_ov.visible = true

func _pick(o: Dictionary) -> void:
	pick_ov.visible = false
	await end_night()
	Game.dawn(o)
	Game.tip("Scouts report a Paladin among tonight's raiders." if Game.is_boss_night(Game.day) else "A new day. Dig, build, and reset your traps.", Game.is_boss_night(Game.day))

func _show_over(earned: int, was_tutorial := false) -> void:
	var v: VBoxContainer = over_ov.get_meta("box")
	clear(v)
	v.add_child(title("You have been slain", "#e4a648", 38))
	var bonus := " (×%.2f for Dread)" % Game.soul_mult() if Game.mods.size() > 0 else ""
	v.add_child(lbl("%s falls on night %d. The village throws a feast. %d souls%s carry over to your next life." % [Game.M.name, Game.day, earned, bonus], 16, "#a7998f"))
	var dug := 0
	for s in Game.slots:
		if s.state != "rock":
			dug += 1
	v.add_child(lbl("Nights survived: %d    Heroes defeated: %d    Rooms dug: %d    Souls banked: %d" % [Game.day - 1, Game.kills, dug, Game.meta.souls], 17))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var bt := Button.new()
	bt.text = "Rise again"
	bt.theme_type_variation = "PrimaryButton"
	bt.pressed.connect(_rise_again)
	row.add_child(bt)
	if was_tutorial:
		var tb := Button.new()
		tb.text = "Restart tutorial"
		tb.theme_type_variation = "GhostButton"
		tb.pressed.connect(func():
			over_ov.visible = false
			await end_night()
			start_tutorial())
		row.add_child(tb)
	var mb := Button.new()
	mb.text = "Title screen"
	mb.theme_type_variation = "GhostButton"
	mb.pressed.connect(quit_to_menu)
	row.add_child(mb)
	over_ov.visible = true

func show_start() -> void:
	menus.hide_all()
	var v: VBoxContainer = start_ov.get_meta("box")
	clear(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var ht := title("Choose your monstrous form", "#e4a648", 38)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	var back := Button.new()
	back.text = "Back  (Esc)"
	back.theme_type_variation = "GhostButton"
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): menus.show_title())
	head.add_child(back)
	v.add_child(lbl("You start with a cave mouth, two empty chambers and your lair. Dig outward, room by room. Every room is real ground the heroes must cross, so where you put your lair, your traps and your minions decides every fight.", 16, "#a7998f"))
	var grid := GridContainer.new()
	var card_w := minf(1080.0, get_viewport_rect().size.x - 40.0) - 48.0
	_dread_picker(v, card_w)
	v.add_child(h3("Choose a monster to begin"))
	grid.columns = clampi(int(card_w / 320.0), 1, 3)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for k in Data.MONSTERS:
		var c := _monster_card(k)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
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
	var cat := Button.new()
	cat.theme_type_variation = "GhostButton"
	cat.text = "Room catalog"
	cat.tooltip_text = "See every room and spend souls to unlock more."
	cat.pressed.connect(func():
		start_ov.visible = false
		menus.open_catalog(show_start))
	meta.add_child(cat)
	start_ov.visible = true

## Toggle cards for the Dread modifiers, or a note on how to unlock them.
func _dread_picker(v: VBoxContainer, card_w: float) -> void:
	if not Game.mods_unlocked():
		v.add_child(lbl("Dread modifiers unlock once a run survives to night 5. They make a run harder for more souls.", 14, "#8a7f90"))
		return
	var picked: Array = Game.meta.get("last_mods", [])
	var m := Game.soul_mult_of(picked)
	var head := lbl("DREAD MODIFIERS  ·  " + ("souls ×%.2f" % m if picked.size() > 0 else "none: normal souls"), 12, "#c9a7ff" if picked.size() > 0 else "#a7998f")
	v.add_child(head)
	var grid := GridContainer.new()
	grid.columns = clampi(int(card_w / 200.0), 1, 5)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for o in Data.MODS:
		var on: bool = o.id in picked
		var c := opt(o.name, "+%d%%" % roundi(o.bonus * 100), o.desc, _toggle_mod.bind(o.id), false, on)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)

func _toggle_mod(id: String) -> void:
	var picked: Array = Game.meta.get("last_mods", []).duplicate()
	if id in picked:
		picked.erase(id)
	else:
		picked.append(id)
	Game.meta.last_mods = picked
	Game.save_meta()
	show_start()

func _monster_card(k: String) -> Control:
	var M: Dictionary = Data.MONSTERS[k]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(lbl(M.role.to_upper(), 12, M.col))
	v.add_child(title(M.name, M.col, 24))
	v.add_child(lbl("%d HP · moves %d · %s %d dmg, range %d" % [M.hp, M.move, M.attack, M.atk, M.rng], 14, "#ede3cd"))
	v.add_child(lbl(M.blurb, 14, "#b3a59b"))
	for sp in M.specials:
		var s := VBoxContainer.new()
		s.add_theme_constant_override("separation", 0)
		s.add_child(lbl(sp.name, 14, M.col))
		s.add_child(lbl(sp.desc, 13, "#b3a59b"))
		v.add_child(s)
	if M.has("partner"):
		var P: Dictionary = M.partner
		v.add_child(lbl("With %s: %d HP · moves %d · %s %d dmg · armor %d" % [P.name, P.hp, P.move, P.attack, P.atk, P.get("armor", 0)], 14, P.col))
		for sp in P.specials:
			var s := VBoxContainer.new()
			s.add_theme_constant_override("separation", 0)
			s.add_child(lbl(sp.name, 14, P.col))
			s.add_child(lbl(sp.desc, 13, "#b3a59b"))
			v.add_child(s)
	var rooms := []
	for t in Data.ROOMS:
		if Data.ROOMS[t].get("owner", "") == k:
			rooms.append(Data.ROOMS[t].name)
	v.add_child(lbl("Rooms: " + ", ".join(rooms), 13, "#8a7f90"))
	return card(v, func(): _choose(k))

func _rise_again() -> void:
	over_ov.visible = false
	await end_night()
	show_start()

func _buy_hoard(price: int) -> void:
	Game.meta.souls -= price
	Game.meta.hoard += 1
	Game.save_meta()
	show_start()

func _choose(k: String, use_mods := true) -> void:
	tutorial.stop()
	start_ov.visible = false
	menus.hide_all()
	in_run = true
	Game.new_run(k, Game.meta.get("last_mods", []) if use_mods and Game.mods_unlocked() else [])
	subtitle.text = "%s. Dig, build, and set the trap." % Game.M.name
	board.show_floor(0)
	board.fit(true)
	Game.tip("Click a chamber to build in it, or the rock beside your rooms to dig. Heroes enter at the glowing gate.")

## A Vampire Lord run whose first five nights follow the tutorial's steps.
func start_tutorial() -> void:
	_choose("vampire", false)
	Game.tut = 0
	tutorial.resume()

## Picks up the saved run. Runs are saved by day, so this always lands on a day.
func continue_run() -> void:
	if not Game.load_run():
		menus.show_title()
		return
	menus.hide_all()
	in_run = true
	if Game.tut >= 0:
		tutorial.resume()
	else:
		tutorial.stop()
	subtitle.text = "%s. Dig, build, and set the trap." % Game.M.name
	board.show_floor(Game.floor_of_slot(Game.slot_idx("lair")))
	board.fit(true)
	refresh()
	Game.tip("Welcome back. Your dungeon is as you left it. Night %d is coming." % Game.day)

## Leaves the run for the title screen. By day the run is already saved; at night the fight
## is dropped and Continue starts it over from dusk.
func quit_to_menu() -> void:
	if battle != null and battle.busy:
		return
	if battle == null and in_run:
		Game.save_run()
	in_run = false
	tutorial.stop()
	over_ov.visible = false
	pick_ov.visible = false
	menus.show_title()
	if battle != null:
		await end_night()
