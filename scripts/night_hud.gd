extends Control
## The fight interface. On the map: round and hints top-left, camera and End turn top-right,
## and a short battle log bottom-left. In the column beside the map: the card for whichever
## unit you clicked, and room powers. Nothing pops up over the map itself.

var ui            # main.gd, for its widget helpers
var board
var battle: Battle = null
## A hero the player clicked to inspect. Takes over the pop-up until cleared.
var inspect = null

var round_lbl: Label
var tip_lbl: Label
var end_btn: Button
var ai_btn: Button
var undo_btn: Button
var fit_btn: Button
var powers: VBoxContainer
var log_rt: RichTextLabel
var popup: PanelContainer      # the selected unit's card, docked beside the map
var pop_box: VBoxContainer
var idle: PanelContainer       # shown in the dock when nothing is selected
var idle_lbl: Label
var dock: Container            # the night column beside the map


## dock is the night column beside the map: the selected unit's card and room powers go there.
func build(main_ui, board_node, dock: Container) -> void:
	ui = main_ui
	board = board_node
	self.dock = dock
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", ui._box("#140f17", "#3a3040", 6, 10))
	tp.self_modulate = Color(1, 1, 1, 0.6)   # see-through enough to spot units under it
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tp.position = Vector2(12, 12)
	add_child(tp)
	var tl := VBoxContainer.new()
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_theme_constant_override("separation", 2)
	tp.add_child(tl)
	round_lbl = _outlined(ui.title("", "#e4a648", 24))
	tl.add_child(round_lbl)
	tip_lbl = _outlined(ui.lbl("", 14, "#ede3cd"))
	tip_lbl.custom_minimum_size.x = 420
	tl.add_child(tip_lbl)

	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	add_child(tr)
	for z in [["−", func(): board.zoom_by(0.8)], ["+", func(): board.zoom_by(1.25)]]:
		var zb := Button.new()
		zb.text = z[0]
		zb.theme_type_variation = "GhostButton"
		zb.custom_minimum_size = Vector2(40, 0)
		zb.pressed.connect(z[1])
		tr.add_child(zb)
	fit_btn = Button.new()
	fit_btn.text = "Whole map"
	fit_btn.theme_type_variation = "GhostButton"
	fit_btn.tooltip_text = "Drag or WASD / arrow keys to pan.\nEsc deselects. Number keys cast spells and scrolls. F finishes the selected unit. Q lets the AI move your minions and ends the turn. Z undoes your last action."
	fit_btn.pressed.connect(ui._toggle_fit)
	tr.add_child(fit_btn)
	undo_btn = Button.new()
	undo_btn.text = "Undo  (Z)"
	undo_btn.theme_type_variation = "GhostButton"
	undo_btn.tooltip_text = "Take back your last move, attack or spell this turn.\nYou can keep undoing back to the start of your turn."
	undo_btn.pressed.connect(_undo)
	tr.add_child(undo_btn)
	ai_btn = Button.new()
	ai_btn.text = "AI moves  (Q)"
	ai_btn.theme_type_variation = "GhostButton"
	ai_btn.tooltip_text = "Every minion that hasn't acted moves and attacks on its own, then your turn ends.\nYour monster stays where you left it."
	ai_btn.pressed.connect(_ai_moves)
	tr.add_child(ai_btn)
	end_btn = Button.new()
	end_btn.text = "End turn  (E)"
	end_btn.theme_type_variation = "PrimaryButton"
	end_btn.pressed.connect(_end_turn)
	tr.add_child(end_btn)
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	popup = PanelContainer.new()
	popup.add_theme_stylebox_override("panel", ui._box("#28212e", "#e4a648", 8, 12))
	popup.visible = false
	dock.add_child(popup)
	pop_box = VBoxContainer.new()
	pop_box.add_theme_constant_override("separation", 6)
	popup.add_child(pop_box)

	idle = PanelContainer.new()
	dock.add_child(idle)
	idle_lbl = ui.lbl("", 14, "#a7998f")
	idle.add_child(idle_lbl)

	powers = VBoxContainer.new()
	powers.add_theme_constant_override("separation", 6)
	dock.add_child(powers)

	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", ui._box("#140f17", "#3a3040", 6, 8))
	lp.self_modulate = Color(1, 1, 1, 0.88)
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.custom_minimum_size = Vector2(380, 0)
	add_child(lp)
	log_rt = RichTextLabel.new()
	log_rt.bbcode_enabled = true
	log_rt.fit_content = true
	log_rt.scroll_active = false
	log_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_rt.add_theme_font_size_override("normal_font_size", 13)
	lp.add_child(log_rt)
	lp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	lp.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _end_turn() -> void:
	if battle:
		battle.enemy_turn()

func _undo() -> void:
	if battle:
		battle.undo()

func _ai_moves() -> void:
	if battle:
		battle.auto_minions()

func _outlined(l: Label) -> Label:
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l


# ---------------------------------------------------------------- content

func set_tip(msg: String, warn: bool) -> void:
	if tip_lbl:
		tip_lbl.text = msg
		tip_lbl.add_theme_color_override("font_color", ui.C("#ff9a8a") if warn else ui.C("#ede3cd"))

func set_log(lines: Array) -> void:
	var cols := {"kill": "#ede3cd", "bad": "#ff9a8a", "info": "#c9a7ff", "": "#b8aaa2"}
	var t := ""
	for l in lines.slice(0, 4):
		t += "[color=%s]%s[/color]\n" % [cols.get(l.kind, "#b8aaa2"), l.msg]
	log_rt.text = t.strip_edges()

func render() -> void:
	if battle == null:
		return
	var enemy := battle.busy and battle.sel == null
	round_lbl.text = "The heroes advance" if enemy else "Night %d · round %d" % [Game.day, battle.turn]
	end_btn.disabled = battle.busy or battle.over
	ai_btn.disabled = battle.busy or battle.over
	undo_btn.disabled = not battle.can_undo()
	fit_btn.text = "Zoom in" if board.zoomed_out() else "Whole map"
	_render_powers()
	if inspect != null and inspect.hp <= 0:
		inspect = null
	var u = inspect if inspect != null else battle.sel
	popup.visible = u != null and not battle.busy
	idle.visible = not popup.visible
	idle_lbl.text = "The heroes are moving..." if battle.busy else "Click one of your units to act, or a hero to see where it can strike."
	if not popup.visible:
		return
	ui.clear(pop_box)
	if u.side == "h":
		_render_hero(u)
	else:
		_render_friend(u)

func _stats(u, hit: int) -> String:
	return "HP %d/%d · Move %d · Hit %d · Range %d" % [u.hp, u.max_hp, battle.move_of(u), hit, u.rng]

func _render_friend(u) -> void:
	var who: String = "You" if u.kind == "monster" else ("Your Squire" if u.kind == "squire" else ("Your thrall" if u.thrall else "Your minion"))
	pop_box.add_child(ui.h3(who + (" · done" if u.acted and u.moved else "")))
	var col: String = Game.M.col if u.kind == "monster" else (Game.M.partner.col if u.kind == "squire" else "#ede3cd")
	pop_box.add_child(ui.title(u.uname, col, 20))
	pop_box.add_child(ui.lbl(_stats(u, battle.atk_of(u)), 13))
	if not u.wpn.is_empty():
		pop_box.add_child(ui.lbl("%s: %s" % [u.wpn.name, u.wpn.desc], 12, "#c8a070"))
	if u.shield > 0 or u.rally:
		pop_box.add_child(ui.lbl(("Warded: soaks %d damage. " % u.shield if u.shield > 0 else "") + ("Rallied: +1 move, +2 damage." if u.rally else ""), 12, "#a8b4ff"))
	if battle.squire != null and battle.is_mon(u):
		pop_box.add_child(ui.lbl("Bonded: both deal +1 damage, and the Dark Lord's spells recharge faster." if battle.bonded()
			else "Not bonded. Stand within %d tiles of each other for +1 damage." % Data.oath_range(Game.lvl("oathstone")), 12, "#b89cff" if battle.bonded() else "#8a7f90"))
	if u.acted and u.moved:
		pop_box.add_child(ui.lbl("Done for this turn.", 13, "#a7998f"))
		return
	var hint := "Click a blue tile to move, or a hero ringed in red to attack."
	if u.moved:
		hint = "Moved. Attack a hero ringed in red, or finish this unit."
	pop_box.add_child(ui.lbl(hint, 12, "#a7998f"))
	var sps: Array = battle.specials_of(u)
	if sps.size() > 0:
		for si in sps.size():
			var sp: Dictionary = sps[si]
			var cd: int = u.cds.get(sp.id, 0)
			var state := ("%d turn%s" % [cd, "s" if cd > 1 else ""]) if cd > 0 else ("cancel" if battle.mode == sp.id else "ready")
			pop_box.add_child(ui.opt("%s  (%d)" % [sp.name, si + 1], state, sp.desc + ("" if sp.get("free", false) else " Uses your action."),
				func(): battle.arm_spell(sp.id), not battle.can_cast(sp), battle.mode == sp.id))
	var done := Button.new()
	done.text = "Finish this unit  (F)"
	done.theme_type_variation = "GhostButton"
	done.pressed.connect(func(): battle.finish_unit(u))
	pop_box.add_child(done)

func _render_hero(h) -> void:
	var cond := []
	if h.stun > 0: cond.append("mesmerized")
	if h.conf > 0: cond.append("confused")
	if h.root > 0: cond.append("snared")
	if h.slow > 0: cond.append("slowed")
	if h.flee: cond.append("fleeing with gold")
	if h.hex > 0: cond.append("hexed")
	if h.taunt != null: cond.append("challenged")
	pop_box.add_child(ui.h3("Hero" + (" · " + ", ".join(cond) if cond.size() > 0 else "")))
	pop_box.add_child(ui.title("%s the %s" % [h.uname, h.d.name], "#ede3cd", 20))
	pop_box.add_child(ui.lbl(_stats(h, battle.atk_of(h)), 13))
	pop_box.add_child(ui.lbl(h.d.get("note", "Hunts down the nearest monster.") + " Red tiles show where it can strike next turn.", 12, "#a7998f"))
	var s = battle.sel
	if s and not s.acted:
		pop_box.add_child(ui.lbl("Out of reach for %s." % s.uname, 12, "#ff9a8a"))

func _render_powers() -> void:
	ui.clear(powers)
	var si := Game.slot_idx("collapse")
	if si >= 0:
		var l := Game.lvl("collapse")
		powers.add_child(ui.opt("Collapse the Hall", "used" if battle.used.has("collapse") else "once",
			"%d damage to everyone in the Collapsing Hall, yours too." % (8 + (l - 1) * 4),
			func(): battle.collapse(), battle.used.has("collapse") or battle.busy))
