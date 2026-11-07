extends Control
## The menus: the title screen (Continue, New run, Room catalog, Settings, Exit game), the room
## catalog, settings, the in-game pause menu and a yes/no confirm box. Sits above everything
## else in main.gd and borrows its widget helpers.

var ui            # main.gd

var title_scr: Control
var catalog_ov: Control
var settings_ov: Control
var pause_ov: Control
var stats_ov: Control
var confirm_ov: Control

var cont_btn: Button
var tut_btn: Button
var footer: Label
var _back: Callable            # where Back goes from the catalog and settings
var _cat_tab := ""             # "" for common rooms, otherwise a monster key


func build(main_ui) -> void:
	ui = main_ui
	# already in the tree, so the offsets must be reset too or it keeps its zero size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_scr = _title_screen()
	catalog_ov = ui._overlay(self)
	settings_ov = ui._overlay(self)
	pause_ov = ui._overlay(self)
	stats_ov = ui._overlay(self)
	confirm_ov = ui._overlay(self)

func apply_layout(vp: Vector2) -> void:
	for e in [[catalog_ov, 1080.0], [stats_ov, 760.0], [settings_ov, 640.0], [pause_ov, 420.0], [confirm_ov, 520.0]]:
		e[0].get_meta("card").custom_minimum_size.x = minf(e[1], vp.x - 40.0)
		e[0].get_meta("center").custom_minimum_size = vp
	if catalog_ov.visible:
		render_catalog()

func is_open() -> bool:
	return title_scr.visible or catalog_ov.visible or settings_ov.visible or pause_ov.visible or confirm_ov.visible or stats_ov.visible

func hide_all() -> void:
	for o in [title_scr, catalog_ov, settings_ov, pause_ov, confirm_ov, stats_ov]:
		o.visible = false

func _box(o: Control) -> VBoxContainer:
	var v: VBoxContainer = o.get_meta("box")
	ui.clear(v)
	return v

func _menu_btn(parent: Container, text: String, cb: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 50
	b.add_theme_font_size_override("font_size", 19)
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## A row with a title and Back button on the right.
func _header(v: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var t: Label = ui.title(text, "#e4a648", 36)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var back := Button.new()
	back.text = "Back  (Esc)"
	back.theme_type_variation = "GhostButton"
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(go_back)
	row.add_child(back)
	return row


# ---------------------------------------------------------------- title screen

func _title_screen() -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(o)
	var bg := Backdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	center.add_child(v)
	v.add_child(_centered(ui.title("Lairkeeper", "#e4a648", 84)))
	v.add_child(_centered(ui.lbl("Dig by day. Feast by night.", 18, "#a7998f", false)))
	var row := MonsterRow.new()
	row.custom_minimum_size = Vector2(460, 120)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(row)
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.custom_minimum_size.x = 340
	btns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(btns)
	cont_btn = _menu_btn(btns, "Continue", func(): ui.continue_run(), "PrimaryButton")
	_menu_btn(btns, "New run", _new_run)
	tut_btn = _menu_btn(btns, "Tutorial", _tutorial)
	_menu_btn(btns, "Room catalog", func(): open_catalog(show_title))
	_menu_btn(btns, "Settings", func(): open_settings(show_title))
	var ex := _menu_btn(btns, "Exit game", func(): get_tree().quit(), "GhostButton")
	ex.visible = Settings.can_quit()
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	v.add_child(gap)
	footer = _centered(ui.lbl("", 14, "#c9a7ff", false))
	v.add_child(footer)
	return o

func show_title() -> void:
	hide_all()
	for o in [ui.start_ov, ui.pick_ov, ui.over_ov]:
		o.visible = false
	var s := Game.run_summary()
	cont_btn.disabled = s.is_empty()
	cont_btn.text = "Continue" if s.is_empty() else "Continue\n%s · night %d" % [Data.MONSTERS[s.mk].name, s.day]
	var fresh: bool = not Game.meta.get("tutorial_done", 0) and Game.meta.best == 0
	tut_btn.text = "Tutorial  ·  start here" if fresh else "Tutorial"
	tut_btn.theme_type_variation = "PrimaryButton" if fresh and s.is_empty() else ""
	footer.text = "Souls banked: %d   ·   Most nights survived: %d" % [Game.meta.souls, Game.meta.best]
	title_scr.visible = true
	if not cont_btn.disabled:
		cont_btn.grab_focus()
	elif fresh:
		tut_btn.grab_focus()

func _new_run() -> void:
	_abandon_then("Start a new run", ui.show_start)

## Five guided nights as the Vampire Lord, then the run carries on as normal.
func _tutorial() -> void:
	_abandon_then("Start the tutorial", ui.start_tutorial)

## Runs then() at once, or after confirming when a saved run would be given up.
func _abandon_then(yes: String, then: Callable) -> void:
	var s := Game.run_summary()
	if s.is_empty():
		then.call()
		return
	confirm("Abandon your current run?",
		"%s is about to face night %d. Starting over gives up that run, and it banks no souls." % [Data.MONSTERS[s.mk].name, s.day],
		yes, func():
			Game.clear_run()
			then.call())


# ---------------------------------------------------------------- room catalog

func open_catalog(back: Callable) -> void:
	hide_all()
	_back = back
	if _cat_tab == "" and ui.in_run:
		_cat_tab = Game.mk
	render_catalog()
	catalog_ov.visible = true

func render_catalog() -> void:
	var v := _box(catalog_ov)
	var head := _header(v, "Room catalog")
	var souls: Label = ui.lbl("%d souls" % Game.meta.souls, 18, "#c9a7ff", false)
	souls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(souls)
	head.move_child(souls, 1)
	var how := "Every build or upgrade takes 1 hour. Each room type can be built once per floor. Rearrange a room's furniture to wall off paths; heroes who can't reach you smash through it."
	if ui.in_run:
		how += " Unlock new rooms from the title screen between runs."
	else:
		how += " Spend souls to unlock a room for every future run."
	v.add_child(ui.lbl(how, 15, "#a7998f"))

	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	v.add_child(tabs)
	var group := ButtonGroup.new()
	for k in [""] + Data.MONSTERS.keys():
		var rooms := _rooms_of(k)
		var open := 0
		for t in rooms:
			if Game.is_unlocked(t):
				open += 1
		var b := Button.new()
		b.text = "%s  %d/%d" % ["Common rooms" if k == "" else Data.MONSTERS[k].name, open, rooms.size()]
		b.theme_type_variation = "GhostButton"
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = k == _cat_tab
		if k != "":
			b.add_theme_color_override("font_color", ui.C(Data.MONSTERS[k].col))
		b.pressed.connect(func():
			_cat_tab = k
			render_catalog())
		tabs.add_child(b)

	var grid := GridContainer.new()
	grid.columns = 2 if catalog_ov.get_meta("card").custom_minimum_size.x >= 900.0 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for t in _rooms_of(_cat_tab):
		var e := _room_entry(t)
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(e)

func _rooms_of(k: String) -> Array:
	var o := []
	for t in Data.ROOMS:
		if Data.ROOMS[t].get("owner", "") == k:
			o.append(t)
	return o

func _room_entry(t: String) -> Control:
	var R: Dictionary = Data.ROOMS[t]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ui._box("#1a1520", "#463a4e", 8, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var unlocked := Game.is_unlocked(t)
	var prev := RoomPreview.new()
	prev.room = t
	prev.custom_minimum_size = Vector2(120, 120)
	prev.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not unlocked:
		prev.modulate = Color(1, 1, 1, 0.4)
	row.add_child(prev)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var status := "Always yours" if R.get("fixed", false) else ("Starter room" if not R.has("unlock") else ("Unlocked" if unlocked else "Locked"))
	var scol := "#ff9a8a" if not unlocked else ("#8fd18f" if R.has("unlock") else "#a7998f")
	v.add_child(ui.lbl(status.to_upper(), 11, scol))
	v.add_child(ui.title(R.name, R.col, 22))
	var costs := []
	for l in R.cost.size():
		if l == 0:
			costs.append("Built from the start" if R.get("fixed", false) else "Build %dg" % R.cost[0])
		else:
			costs.append("Lv %d: %dg" % [l + 1, R.cost[l]])
	costs.append("then +40% a level, no cap")
	v.add_child(ui.lbl(" · ".join(costs), 13, "#e4a648"))
	for l in range(1, maxi(R.cost.size(), 3) + 2):
		v.add_child(ui.lbl("Lv %d  %s" % [l, Data.room_eff(t, l)], 13, "#ede3cd" if l == 1 else "#b3a59b"))
	v.add_child(ui.lbl("…and it keeps growing with every level after.", 13, "#8a7f90"))
	if R.has("recruit"):
		var U: Dictionary = Data.UNITS[R.recruit]
		v.add_child(ui.lbl("%s: %d HP, hits for %d, moves %d. %dg each." % [U.name, U.hp, U.atk, U.move, U.cost], 13, "#a7998f"))
	if not unlocked:
		var c: int = R.unlock
		if ui.in_run:
			v.add_child(ui.lbl("Costs %d souls. Unlock it from the title screen." % c, 13, "#ff9a8a"))
		else:
			var b := Button.new()
			b.text = "Unlock for %d souls" % c if Game.meta.souls >= c else "Needs %d souls (you have %d)" % [c, Game.meta.souls]
			b.theme_type_variation = "PrimaryButton"
			b.disabled = Game.meta.souls < c
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			b.pressed.connect(func():
				if Game.unlock_room(t):
					render_catalog())
			v.add_child(b)
	return p


# ---------------------------------------------------------------- your monster

## A sheet with the monster's current numbers, after rooms, boons and Dread. For a duo,
## one column per unit. Pass an empty Callable to just close it again.
func open_stats(back: Callable) -> void:
	if not ui.in_run:
		return
	hide_all()
	_back = back
	render_stats()
	stats_ov.visible = true

func render_stats() -> void:
	var v := _box(stats_ov)
	_header(v, "Your monster")
	# at night read the live units; by day build throwaway ones so the numbers match a fight
	var b: Battle = ui.battle
	var temp := b == null
	if temp:
		b = Battle.new()
		b.mon = b.mk_unit("p", "monster", Game.monster_start())
		if Game.duo():
			b.squire = b.mk_unit("p", "squire", Game.squire_start())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for u in [b.mon, b.squire]:
		if u != null:
			var c := _unit_sheet(b, u)
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(c)
	if Game.duo():
		v.add_child(ui.lbl("Bond: within %d tiles of each other, both deal +1 damage and the Dark Lord's spells recharge 1 turn faster." % Data.oath_range(Game.lvl("oathstone")), 14, "#b89cff"))
	v.add_child(ui.h3("Dark boons"))
	v.add_child(ui.lbl(", ".join(Game.taken) if Game.taken.size() > 0 else "None yet. Survive a night to earn one.", 14, "#c9a7ff" if Game.taken.size() > 0 else "#a7998f"))
	if Game.mods.size() > 0:
		var names := []
		for o in Data.MODS:
			if o.id in Game.mods:
				names.append(o.name)
		v.add_child(ui.h3("Dread · souls ×%.2f" % Game.soul_mult()))
		v.add_child(ui.lbl(", ".join(names), 14, "#c9a7ff"))
	if temp:
		b.free()

## One unit's card: health, attack, defense, spells, and where its bonuses come from.
func _unit_sheet(b: Battle, u) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ui._box("#1a1520", "#463a4e", 8, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var D: Dictionary = u.d
	var col: String = D.col
	var down: bool = (u.kind == "monster" and "lord" in Game.down) or (u.kind == "squire" and "squire" in Game.down)
	v.add_child(ui.lbl(("Fallen · " if down else "") + ("Your partner" if u.kind == "squire" else Game.M.role).to_upper(), 12, "#ff9a8a" if down else col))
	v.add_child(ui.title(u.uname, col, 26))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	v.add_child(grid)
	var dmg: int = b.atk_of(u)
	var magic: bool = Game.mk == "darklord" and u.kind == "monster"
	for e in [["Health", "%d / %d" % [u.hp, u.max_hp]],
			["Attack", "%s · %d damage%s" % [D.attack, dmg, " (ignores armor)" if magic else ""]],
			["Range", "%d tile%s" % [u.rng, "" if u.rng == 1 else "s"]],
			["Move", "%d tiles" % b.move_of(u)],
			["Armor", "%d (blocks %d damage per hit)" % [u.armor, u.armor] if u.armor > 0 else "none"],
			["In your lair", "takes 1 less damage"]]:
		grid.add_child(ui.lbl(e[0], 14, "#a7998f", false))
		var val: Label = ui.lbl(e[1], 15, "#ede3cd")
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # wrapped text needs a width to wrap to
		grid.add_child(val)
	var extra: int = dmg - D.atk
	if extra > 0:
		var why := []
		if Game.b.atk > 0: why.append("+%d from boons" % Game.b.atk)
		var rooms: int = extra - Game.b.atk - (1 if b.bonded() else 0)
		if rooms > 0: why.append("+%d from rooms" % rooms)
		if b.bonded(): why.append("+1 from the bond")
		v.add_child(ui.lbl("Base damage %d, %s." % [D.atk, ", ".join(why)], 13, "#a7998f"))
	for sp in b.specials_of(u):
		var s := VBoxContainer.new()
		s.add_theme_constant_override("separation", 0)
		var cd: int = b.cd_of(sp)
		s.add_child(ui.lbl("%s  ·  recharges in %d turn%s%s" % [sp.name, cd, "" if cd == 1 else "s", " · free action" if sp.get("free", false) else ""], 14, col))
		s.add_child(ui.lbl(sp.desc, 13, "#b3a59b"))
		v.add_child(s)
	return p


# ---------------------------------------------------------------- settings

func open_settings(back: Callable) -> void:
	hide_all()
	_back = back
	render_settings()
	settings_ov.visible = true

func render_settings() -> void:
	var v := _box(settings_ov)
	_header(v, "Settings")
	if Settings.can_fullscreen():
		var cb := CheckButton.new()
		cb.button_pressed = Settings.fullscreen
		cb.toggled.connect(func(on): Settings.set_value("fullscreen", on))
		_setting_row(v, "Fullscreen", "Fill the whole screen. F11 also toggles it.", cb)
	_setting_row(v, "Interface size", "Scale text, buttons and panels.", _segmented("ui_scale", Settings.UI_SCALES))
	_setting_row(v, "Battle speed", "How fast heroes walk and attacks play out at night.", _segmented("battle_speed", Settings.SPEEDS))
	if not ui.in_run:
		var reset := Button.new()
		reset.text = "Reset progress"
		reset.theme_type_variation = "GhostButton"
		reset.add_theme_color_override("font_color", ui.C("#ff9a8a"))
		reset.pressed.connect(func():
			confirm("Reset all progress?",
				"This wipes your souls, unlocked rooms and best night, and abandons any run in progress. It can't be undone.",
				"Reset everything", func():
					Game.reset_meta()
					open_settings(_back)))
		_setting_row(v, "Progress", "Souls banked: %d · %d rooms unlocked" % [Game.meta.souls, Game.meta.rooms.size()], reset)

func _setting_row(v: VBoxContainer, name: String, desc: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(ui.lbl(name, 17))
	info.add_child(ui.lbl(desc, 13, "#a7998f"))
	row.add_child(info)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	v.add_child(HSeparator.new())

## A row of toggle buttons, one per [value, label] choice, bound to one setting.
func _segmented(key: String, choices: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for c in choices:
		var b := Button.new()
		b.text = c[1]
		b.theme_type_variation = "GhostButton"
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = is_equal_approx(Settings.get(key), c[0])
		b.pressed.connect(Settings.set_value.bind(key, c[0]))
		h.add_child(b)
	return h


# ---------------------------------------------------------------- pause menu

func open_pause() -> void:
	if not ui.in_run:
		return
	hide_all()
	render_pause()
	pause_ov.visible = true

func render_pause() -> void:
	var v := _box(pause_ov)
	v.add_child(_centered(ui.title("Paused", "#e4a648", 36)))
	v.add_child(_centered(ui.lbl("%s · %s %d" % [Game.M.name, "night" if ui.night else "day", Game.day], 15, "#a7998f", false)))
	if Game.mods.size() > 0:
		var names := []
		for o in Data.MODS:
			if o.id in Game.mods:
				names.append(o.name)
		v.add_child(_centered(ui.lbl("Dread: %s · souls ×%.2f" % [", ".join(names), Game.soul_mult()], 13, "#c9a7ff")))
	var resume := _menu_btn(v, "Resume  (Esc)", func(): pause_ov.visible = false, "PrimaryButton")
	_menu_btn(v, "Your monster", func(): open_stats(open_pause))
	_menu_btn(v, "Room catalog", func(): open_catalog(open_pause))
	_menu_btn(v, "Settings", func(): open_settings(open_pause))
	var busy: bool = ui.battle != null and ui.battle.busy
	var quit := _menu_btn(v, "Quit to title screen", func(): ui.quit_to_menu())
	quit.disabled = busy
	if Settings.can_quit():
		var ex := _menu_btn(v, "Exit game", func(): get_tree().quit(), "GhostButton")
		ex.disabled = busy
	var note := "Wait for the heroes to finish moving before you quit." if busy \
		else ("Tonight's fight starts over from dusk when you continue." if ui.night else "Your run is saved. Continue picks up right here.")
	v.add_child(_centered(ui.lbl(note, 13, "#a7998f")))
	resume.grab_focus()


# ---------------------------------------------------------------- confirm box

func confirm(head: String, body: String, yes: String, cb: Callable) -> void:
	var v := _box(confirm_ov)
	v.add_child(ui.title(head, "#e4a648", 30))
	v.add_child(ui.lbl(body, 16, "#b3a59b"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var no := Button.new()
	no.text = "Cancel"
	no.theme_type_variation = "GhostButton"
	no.pressed.connect(func(): confirm_ov.visible = false)
	row.add_child(no)
	var ok := Button.new()
	ok.text = yes
	ok.theme_type_variation = "PrimaryButton"
	ok.pressed.connect(func():
		confirm_ov.visible = false
		cb.call())
	row.add_child(ok)
	confirm_ov.visible = true
	no.grab_focus()


# ---------------------------------------------------------------- navigation

func go_back() -> void:
	catalog_ov.visible = false
	settings_ov.visible = false
	stats_ov.visible = false
	if _back.is_valid():
		_back.call()

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_F11 and Settings.can_fullscreen():
		Settings.set_value("fullscreen", not Settings.fullscreen)
		if settings_ov.visible:
			render_settings()
		get_viewport().set_input_as_handled()
		return
	if e.keycode != KEY_ESCAPE:
		return
	if confirm_ov.visible:
		confirm_ov.visible = false
	elif catalog_ov.visible or settings_ov.visible or stats_ov.visible:
		go_back()
	elif pause_ov.visible:
		pause_ov.visible = false
	elif title_scr.visible:
		return
	elif ui.start_ov.visible:
		show_title()
	elif not ui.in_run or ui.pick_ov.visible or ui.over_ov.visible:
		return
	elif ui.battle != null and (ui.battle.sel != null or ui.hud.inspect != null or ui.battle.mode != ""):
		return   # let the fight's Esc deselect first
	elif ui.battle == null and (Game.trap_mode != "" or Game.ent_mode or Game.sel_minion != null or Game.decor_room >= 0):
		Game.trap_mode = ""
		Game.ent_mode = false
		Game.sel_minion = null
		Game.decor_room = -1
		Game.decor_pick = null
		ui.refresh()
	else:
		open_pause()
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- drawn pieces

## The title screen's background: dark stone with a faint red glow behind the title.
class Backdrop extends Control:
	var _tex: GradientTexture2D

	func _ready() -> void:
		var g := Gradient.new()
		g.set_color(0, Data.col("#c0304c", 0.16))
		g.set_color(1, Data.col("#c0304c", 0.0))
		g.add_point(0.35, Data.col("#a02a44", 0.08))
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.width = 256
		_tex.height = 256

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Data.col("#1d1822"))
		var r := size.y * 0.7
		draw_texture_rect(_tex, Rect2(Vector2(size.x / 2.0, size.y * 0.38) - Vector2(r, r), Vector2(r, r) * 2.0), false)

## The five monsters standing in a row, bobbing.
class MonsterRow extends Control:
	var now := 0.0

	func _process(dt: float) -> void:
		if is_visible_in_tree():
			now += dt
			queue_redraw()

	func _draw() -> void:
		var keys := Data.MONSTERS.keys()
		var gap := size.x / keys.size()
		for i in keys.size():
			var k: String = keys[i]
			draw_set_transform(Vector2(gap * (i + 0.5), size.y * 0.55))
			Sprites.monster(self, k, Data.col(Data.MONSTERS[k].col), 24.0, sin(now * 2.0 + i * 1.3) * 2.0, false, now)
		draw_set_transform(Vector2.ZERO)

## A 5x5 room with its furniture, drawn with the same sprites as the map.
class RoomPreview extends Control:
	const T := 64.0
	var room := ""
	var now := 0.0

	func _ready() -> void:
		clip_contents = true

	func _process(dt: float) -> void:
		if is_visible_in_tree():
			now += dt
			queue_redraw()

	func _draw() -> void:
		var R: Dictionary = Data.ROOMS[room]
		var col := Data.col(R.col)
		var s := size.x / (5.0 * T)
		var base := Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO)
		draw_set_transform_matrix(base)
		for y in 5:
			for x in 5:
				var v := fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
				draw_rect(Rect2(x * T, y * T, T + 1, T + 1), Color(0.15 + v * 0.04, 0.13 + v * 0.035, 0.17 + v * 0.04))
				draw_rect(Rect2(x * T, y * T, T, T), Color(0, 0, 0, 0.35), false, 1.5)
		draw_rect(Rect2(0, 0, 5 * T, 5 * T), Color(col, 0.09))
		# flat pieces first, then the ones that block, like the map
		for blocking in [false, true]:
			for e in R.objs:
				if (e.size() > 3 and e[3] == 1) != blocking:
					continue
				draw_set_transform_matrix(base * Transform2D(0.0, Vector2(e[0], e[1]) * T))
				Sprites.furniture(self, e[2], now, e[0] * 7 + e[1], col)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_rect(Rect2(Vector2.ZERO, size), Data.col("#09070b"), false, 4.0)
