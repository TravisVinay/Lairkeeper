extends Control
## The dungeon view. Draws rooms, furniture, traps, units and effects through a camera,
## and turns pointer input into tile clicks. By day it shows the whole map; at night it zooms in.

signal tile_clicked(p: Vector2i)
signal tile_hovered(p: Vector2i)

const T := 64.0

var battle: Battle = null
var cam := Vector2(12.5, 10.0)   # camera center, in tiles
var cam_z := 30.0                # screen pixels per tile
var tgt := cam
var tgt_z := cam_z
var hover := Vector2i(-99, -99)
var hint_slot := -1              # a chamber the tutorial is pointing at, or -1
var now := 0.0
var font: Font
var _press = null
var _press_cam := Vector2.ZERO
var _dragging := false
var _sh := Vector2.ZERO          # this frame's screen shake
## The still parts of the map (rock, floor, room tints, walls, traps, furniture that does not move)
## are baked into a texture at the current zoom and shown as one sprite. Drawn shape by shape they
## cost over a thousand draw calls a frame in a big dungeon; baked, they cost one. The bake is
## redone only when the dungeon changes or the zoom settles somewhere new.
var map_vp: SubViewport
var map_drawer: Node2D
var map_sprite: Sprite2D
var _map_key := []
var _map_dirty := true
var _baked_z := 0.0
## Sharpest the bake gets, in pixels per tile; closer than this the texture is stretched.
const MAP_MAX_Z := 128.0

## Furniture that animates, so it is drawn every frame instead of into the cached map.
const ANIMATED := ["brazier", "candles", "fire", "forge", "gear", "gearbig", "jar", "pool", "runecircle", "well", "wisp"]


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font
	resized.connect(_on_resized)
	mouse_exited.connect(_on_mouse_exited)
	var bg := ColorRect.new()
	bg.color = Data.col("#0e0b10")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	map_vp = SubViewport.new()
	map_vp.transparent_bg = true
	map_vp.disable_3d = true
	map_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(map_vp)
	map_drawer = Node2D.new()
	map_drawer.draw.connect(_draw_map)
	map_vp.add_child(map_drawer)
	map_sprite = Sprite2D.new()   # a Node2D, so it is culled by its texture, not a Control's rect
	map_sprite.centered = false
	map_sprite.show_behind_parent = true
	map_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	map_sprite.texture = map_vp.get_texture()
	add_child(map_sprite)
	Game.changed.connect(func(): _map_dirty = true)


func _on_mouse_exited() -> void:
	hover = Vector2i(-99, -99)
	tile_hovered.emit(hover)


# ---------------------------------------------------------------- camera

func _on_resized() -> void:
	if battle == null:
		fit(true)
	else:
		clamp_cam()

## A trap that has already fired tonight.
func sprung(p: Vector2i) -> bool:
	return battle != null and battle.sprung.has(p)

func fit_z() -> float:
	return minf(size.x / Game.BW, size.y / Game.BH) if size.x > 0.0 else 30.0

func night_z() -> float:
	return maxf(fit_z() * 1.5, minf(size.x / 15.0, size.y / 11.0))

## Stable per-tile noise for floor shading, so every floor looks different without stored arrays.
func shade(x: int, y: int) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)

func fit(snap := false) -> void:
	tgt_z = fit_z()
	tgt = Vector2(Game.BW / 2.0, Game.BH / 2.0)
	if snap:
		cam = tgt
		cam_z = tgt_z

func zoomed_out() -> bool:
	return tgt_z <= fit_z() + 0.5

func zoom_by(f: float) -> void:
	tgt_z = clampf(tgt_z * f, fit_z(), fit_z() * 4.0)
	clamp_cam()

func look_at_tile(p: Vector2i, z := 0.0) -> void:
	tgt = Vector2(p) + Vector2(0.5, 0.5)
	if z > 0.0:
		tgt_z = z
	clamp_cam()

func pan(d: Vector2) -> void:
	tgt += d
	clamp_cam()

## Recenters on a tile only when it is near the edge of the view.
func follow(p: Vector2i) -> void:
	var hw := size.x / 2.0 / tgt_z
	var hh := size.y / 2.0 / tgt_z
	var c := Vector2(p) + Vector2(0.5, 0.5)
	if absf(c.x - tgt.x) > hw * 0.6 or absf(c.y - tgt.y) > hh * 0.6:
		tgt = c
		clamp_cam()

func clamp_cam() -> void:
	var hw := size.x / 2.0 / tgt_z
	var hh := size.y / 2.0 / tgt_z
	tgt.x = Game.BW / 2.0 if Game.BW <= hw * 2.0 else clampf(tgt.x, hw, Game.BW - hw)
	tgt.y = Game.BH / 2.0 if Game.BH <= hh * 2.0 else clampf(tgt.y, hh, Game.BH - hh)

## The tile under a screen point, or (-99, -99) when the point is off the map.
func screen_to_tile(sp: Vector2) -> Vector2i:
	var w := (sp - size / 2.0) / cam_z + cam
	var t := Vector2i(floori(w.x), floori(w.y))
	return t if Game.in_b(t) else Vector2i(-99, -99)

## Where a tile-space point (in tiles) currently appears on screen.
func tile_to_screen(w: Vector2) -> Vector2:
	return (w - cam) * cam_z + size / 2.0


# ---------------------------------------------------------------- input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_press = e.position
				_press_cam = cam
				_dragging = false
			else:
				if _press != null and not _dragging:
					tile_clicked.emit(screen_to_tile(e.position))
				_press = null
				_dragging = false
			accept_event()
		elif e.pressed and battle and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.12)
			accept_event()
		elif e.pressed and battle and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(0.9)
			accept_event()
	elif e is InputEventMouseMotion:
		if _press != null and battle:
			var d: Vector2 = e.position - _press
			if not _dragging and d.length() > 8.0:
				_dragging = true
			if _dragging:
				tgt = _press_cam - d / cam_z
				clamp_cam()
				cam = tgt
		var t := screen_to_tile(e.position)
		if t != hover:
			hover = t
			tile_hovered.emit(t)
	elif e is InputEventMagnifyGesture and battle:
		zoom_by(e.factor)
	elif e is InputEventPanGesture and battle:
		pan(e.delta * 0.5)


# ---------------------------------------------------------------- animation

func _process(dt: float) -> void:
	now += dt
	var k := minf(1.0, dt * 7.0)
	cam = cam.lerp(tgt, k)
	cam_z = lerpf(cam_z, tgt_z, k)
	if battle:
		var uk := minf(1.0, dt * 16.0)
		for u in battle.units:
			u.draw_pos = u.draw_pos.lerp(Vector2(u.pos), uk)
			u.flash = maxf(0.0, u.flash - dt)
			if u.lunge_t > 0.0:
				u.lunge_t -= dt
				if u.lunge_t <= 0.0:
					u.lunge = Vector2.ZERO
		for f in battle.fx:
			f.t -= dt
		battle.fx = battle.fx.filter(func(f): return f.t > 0.0)
		for p in battle.parts:
			p.t -= dt
			p.p += p.v * dt
			p.v *= 0.92
		battle.parts = battle.parts.filter(func(p): return p.t > 0.0)
		for t in battle.texts:
			t.t -= dt
			t.p.y -= dt * 0.7
		battle.texts = battle.texts.filter(func(t): return t.t > 0.0)
		battle.shake = maxf(0.0, battle.shake - dt)
	_sh = Vector2(randf() - 0.5, randf() - 0.5) * 8.0 if battle and battle.shake > 0.0 else Vector2.ZERO
	var key := [Game.map_ver, Game.mk, Game.SW, Game.SH, Game.entrance, Game.traps.hash(), battle.sprung.hash() if battle else 0]
	var want_z := minf(cam_z, MAP_MAX_Z)
	var off := absf(want_z - _baked_z) / want_z
	var settled := absf(cam_z - tgt_z) < tgt_z * 0.01
	if _map_dirty or key != _map_key or (off > 0.02 and settled) or off > 0.5:
		_map_dirty = false
		_map_key = key
		_bake_map(want_z)
	var sc := cam_z / _baked_z
	var at := size / 2.0 - cam * cam_z + _sh
	map_sprite.scale = Vector2(sc, sc)
	map_sprite.position = at.round() if absf(sc - 1.0) < 0.001 else at
	map_sprite.visible = Game.mk != ""
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if Game.mk == "":
		return
	var s := cam_z / T
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, size / 2.0 - cam * cam_z + _sh)
	var mcol := Data.col(Game.M.col)
	draw_set_transform_matrix(xf)
	for si in Game.slots.size():
		var sl: Dictionary = Game.slots[si]
		if sl.state == "built" and sl.type == "cistern":
			var o := Vector2(Game.slot_xy(si) * Game.RS) * T
			for i in 5:
				var pts := PackedVector2Array()
				for j in 33:
					var xx := j * 10.0
					pts.append(o + Vector2(xx, (0.5 + i) * T + sin(xx / 16.0 + now * 2.0 + i) * 3.0))
				draw_polyline(pts, Data.col("#96c8f0", 0.25), 2.0)
	# animated flat furniture; the still pieces are in the cached map
	for k in Game.obj:
		if not Game.obj[k].block and Game.obj[k].kind in ANIMATED:
			draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(k) * T))
			Sprites.furniture(self, Game.obj[k].kind, now, k.x * 7 + k.y, mcol)
	draw_set_transform_matrix(xf)
	_draw_gate(xf)

	if battle == null:
		_draw_day_overlay()
	else:
		_draw_night_overlay()

	# armed blast runes pulse, so they draw live; everything else is in the cached map
	for k in Game.traps:
		if Game.traps[k] != "rune" or sprung(k):
			continue
		draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(k) * T))
		Sprites.trap(self, Game.traps[k], now)
	for k in Game.obj:
		if Game.obj[k].block:
			draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(k) * T))
			if Game.obj[k].kind in ANIMATED:
				Sprites.furniture(self, Game.obj[k].kind, now, k.x * 7 + k.y, mcol)
			# furniture the heroes are hacking at shows how much it has left
			if battle and battle.decor_hp.has(k):
				var f := float(battle.decor_hp[k]) / Data.decor_hp(Game.obj[k].kind)
				draw_rect(Rect2(6, T - 12, T - 12, 7), Color(0.05, 0.04, 0.06, 0.8))
				draw_rect(Rect2(6, T - 12, (T - 12) * f, 7), Data.col("#e4a648"))
	draw_set_transform_matrix(xf)

	# room labels
	var fs := int(maxf(18.0, 13.0 * T / cam_z))
	var pad := fs * 0.35
	for si in Game.slots.size():
		var sl: Dictionary = Game.slots[si]
		if sl.state == "rock":
			continue
		var o := Vector2(Game.slot_xy(si) * Game.RS) * T
		var nm: String = "Empty chamber" if sl.state == "dug" else Data.ROOMS[sl.type].name
		if sl.get("lvl", 1) > 1:
			nm += " " + Data.roman(sl.lvl)
		var col := Data.col("#8a7f90") if sl.state == "dug" else (mcol if sl.type == "lair" else Data.col(Data.ROOMS[sl.type].col))
		col.a = 0.75 if battle else 1.0
		# a dark plate behind the name keeps it readable over floor and furniture
		var ts := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var at := o + Vector2(pad, pad)
		draw_rect(Rect2(at, Vector2(ts.x + pad * 2.0, ts.y + pad * 0.6)), Color(0.05, 0.04, 0.06, 0.45 if battle else 0.72))
		draw_string(font, at + Vector2(pad, pad * 0.3 + font.get_ascent(fs)), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	# the tutorial's pulsing pointer at the chamber to click next
	if hint_slot >= 0 and battle == null:
		var hr := Rect2(Vector2(Game.slot_xy(hint_slot) * Game.RS) * T, Vector2(Game.RS, Game.RS) * T)
		var pulse := 0.5 + 0.5 * sin(now * 4.0)
		draw_rect(hr, Data.col("#e4a648", 0.06 + 0.08 * pulse))
		draw_rect(hr.grow(-4), Data.col("#e4a648", 0.55 + 0.45 * pulse), false, 6.0 + 4.0 * pulse)

	if battle:
		for k in battle.corpses:
			if battle.unit_at(k) == null:
				var a := Vector2(k) * T
				draw_line(a + Vector2(18, 40), a + Vector2(46, 30), Data.col("#e8dcc0", 0.5), 3.0)
				draw_line(a + Vector2(22, 28), a + Vector2(42, 44), Data.col("#e8dcc0", 0.5), 3.0)
		if battle.sel and not battle.busy and battle.mode == "":
			for h in battle.targets_for(battle.sel):
				draw_arc((h.draw_pos + Vector2(0.5, 0.5)) * T, T * 0.46, 0, TAU, 28, Data.col("#ff5d6a"), 3.0, true)
		# the bond between the Dark Lord and his Squire
		if battle.bonded():
			var a := (battle.mon.draw_pos + Vector2(0.5, 0.5)) * T
			var z := (battle.squire.draw_pos + Vector2(0.5, 0.5)) * T
			draw_line(a, z, Data.col("#b89cff", 0.35 + 0.15 * sin(now * 3.0)), 3.0, true)
		for u in battle.units:
			if u.hp > 0:
				_draw_unit(xf, u.kind, u.d, u.draw_pos + u.lunge, u.side, u.hp, u.max_hp, u.id, u.flash > 0.0,
					battle.sel == u, u.acted and u.moved and u.side == "p" and not battle.busy, u.slow > 0, u.root > 0,
					u.thrall or u.conf > 0, u.flee, u.stun > 0, u.thrall, true)
		draw_set_transform_matrix(xf)
		for f in battle.fx:
			var a: float = clampf(f.t / f.max, 0.0, 1.0)
			var c: Color = f.col
			c.a = a
			if f.kind == "line":
				draw_line((Vector2(f.a) + Vector2(0.5, 0.5)) * T, (Vector2(f.b) + Vector2(0.5, 0.5)) * T, c, 4.0, true)
			else:
				draw_arc((Vector2(f.a) + Vector2(0.5, 0.5)) * T, T * f.r * (1.0 - a * 0.5), 0, TAU, 32, c, 4.0, true)
		for p in battle.parts:
			var c: Color = p.col
			c.a = clampf(p.t * 2.0, 0.0, 1.0)
			draw_rect(Rect2(p.p * T - Vector2(3, 3), Vector2(6, 6)), c)
		for t in battle.texts:
			var c: Color = t.col
			c.a = clampf(t.t * 2.0, 0.0, 1.0)
			var at: Vector2 = t.p * T - Vector2(110, 0)
			draw_string(font, at + Vector2(2, 2), t.s, HORIZONTAL_ALIGNMENT_CENTER, 220, 22, Color(0, 0, 0, c.a * 0.7))
			draw_string(font, at, t.s, HORIZONTAL_ALIGNMENT_CENTER, 220, 22, c)
	else:
		var ms := Game.monster_start()
		if not "lord" in Game.down:
			_draw_unit(xf, "monster", Game.M, Vector2(ms), "p", Game.mhp, Game.mmax, 0, false, false, false, false, false, false, false, false, false, false)
		if Game.duo() and not "squire" in Game.down:
			_draw_unit(xf, "squire", Game.M.partner, Vector2(Game.squire_start()), "p", Game.shp, Game.smax, 1, false, false, false, false, false, false, false, false, false, false)
		for m in Game.minions:
			_draw_unit(xf, m.kind, Data.UNITS[m.kind], Vector2(m.post), "p", 1, 1, m.mid, false, Game.sel_minion == m, false,
				false, false, false, false, false, false, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## Re-renders the still map into its texture at z pixels per tile.
func _bake_map(z: float) -> void:
	_baked_z = z
	map_vp.size = Vector2i(ceili(Game.BW * z), ceili(Game.BH * z))
	map_drawer.scale = Vector2(z / T, z / T)
	map_drawer.position = Vector2.ZERO
	map_drawer.queue_redraw()
	map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

## The still map, in world pixels. map_drawer's transform maps it onto the texture.
func _draw_map() -> void:
	if Game.mk == "":
		return
	var c := map_drawer
	var mcol := Data.col(Game.M.col)

	# rock and floor
	for y in Game.BH:
		for x in Game.BW:
			var p := Vector2i(x, y)
			var v := shade(x, y)
			var r := Rect2(x * T, y * T, T + 1, T + 1)
			if not Game.is_floor(p):
				c.draw_rect(r, Color(0.06 + v * 0.03, 0.05 + v * 0.025, 0.07 + v * 0.03))
			else:
				c.draw_rect(r, Color(0.15 + v * 0.04, 0.13 + v * 0.035, 0.17 + v * 0.04))
				c.draw_rect(Rect2(x * T, y * T, T, T), Color(0, 0, 0, 0.35), false, 1.5)
	for si in Game.slots.size():
		var sl: Dictionary = Game.slots[si]
		if sl.state != "built":
			continue
		var o := Vector2(Game.slot_xy(si) * Game.RS) * T
		var col := mcol if sl.type == "lair" else Data.col(Data.ROOMS[sl.type].col)
		c.draw_rect(Rect2(o, Vector2(Game.RS, Game.RS) * T), Color(col, 0.09))
		if sl.type == "lair":
			Sprites.glow(c, o + Vector2(2.5, 1.5) * T, Game.RS * T * 0.6, Color(col, 0.35))
		elif sl.type == "cistern":
			c.draw_rect(Rect2(o, Vector2(Game.RS, Game.RS) * T), Data.col("#4f8fbf", 0.2))

	# flat furniture
	for k in Game.obj:
		if not Game.obj[k].block and not Game.obj[k].kind in ANIMATED:
			c.draw_set_transform(Vector2(k) * T)
			Sprites.furniture(c, Game.obj[k].kind, now, k.x * 7 + k.y, mcol)
	c.draw_set_transform(Vector2.ZERO)

	# walls
	var segs := PackedVector2Array()
	for y in Game.BH:
		for x in Game.BW:
			var p := Vector2i(x, y)
			if not Game.is_floor(p):
				continue
			for d in Game.DIRS:
				var n: Vector2i = p + d
				if not Game.wall_between(p, n) or (p == Game.entrance and not Game.in_b(n)):
					continue
				var a := Vector2(x, y) * T
				if d.x == 1:
					segs.append_array([a + Vector2(T, 0), a + Vector2(T, T)])
				elif d.x == -1:
					segs.append_array([a, a + Vector2(0, T)])
				elif d.y == 1:
					segs.append_array([a + Vector2(0, T), a + Vector2(T, T)])
				else:
					segs.append_array([a, a + Vector2(T, 0)])
	if segs.size() > 0:
		c.draw_multiline(segs, Data.col("#09070b"), 9.0)
	for k in Game.traps:
		if Game.traps[k] != "rune" or sprung(k):
			c.draw_set_transform(Vector2(k) * T)
			Sprites.trap(c, Game.traps[k], now)
			if sprung(k):
				# fired tonight: dimmed until it re-arms at dawn
				c.draw_rect(Rect2(6, 6, T - 12, T - 12), Color(0.05, 0.04, 0.06, 0.6))
	c.draw_set_transform(Vector2.ZERO)
	# still blocking furniture sits on top of the walls
	for k in Game.obj:
		if Game.obj[k].block and not Game.obj[k].kind in ANIMATED:
			c.draw_set_transform(Vector2(k) * T)
			Sprites.furniture(c, Game.obj[k].kind, now, k.x * 7 + k.y, mcol)
	c.draw_set_transform(Vector2.ZERO)

func _draw_gate(xf: Transform2D) -> void:
	var e := Game.entrance
	var c := (Vector2(e) + Vector2(0.5, 0.5)) * T
	Sprites.glow(self, c, T * 1.6, Data.col("#ffc86e", 0.45))
	var ang := 0.0
	if e.y == Game.BH - 1: ang = PI
	elif e.x == 0 and e.y != 0: ang = -PI / 2
	elif e.x == Game.BW - 1 and e.y != 0: ang = PI / 2
	draw_set_transform_matrix(xf * Transform2D(ang, c))
	var h := T / 2.0
	draw_rect(Rect2(-h - 6, -h - 4, 10, T * 0.7), Data.col("#4a3a2c"))
	draw_rect(Rect2(h - 4, -h - 4, 10, T * 0.7), Data.col("#4a3a2c"))
	draw_polyline(PackedVector2Array(Sprites.quad(Vector2(-h, -h + 4), Vector2(0, -h - 18), Vector2(h, -h + 4))), Data.col("#e4a648"), 4.0, true)
	Sprites.poly(self, [Vector2(0, 4), Vector2(-9, -8), Vector2(9, -8)], Data.col("#ffd278", 0.85))
	var fl := sin(now * 11.0) * 2.0
	Sprites.ell(self, Vector2(-h - 1, -h - 10), 4, 7 + fl, Data.col("#ffcc70"))
	Sprites.ell(self, Vector2(h + 1, -h - 10), 4, 7 - fl, Data.col("#ffcc70"))
	draw_set_transform_matrix(xf)
	if battle and battle.queue.size() > 0:
		var at := c + Vector2(-110, T * 0.9 if e.y == 0 else -T * 0.7)
		draw_string(font, at, "+%d waiting" % battle.queue.size(), HORIZONTAL_ALIGNMENT_CENTER, 220, 20, Data.col("#ffd090"))

func _draw_day_overlay() -> void:
	# arranging furniture: every movable piece outlined, the picked one bright,
	# and once one is in hand, every free spot tinted
	if Game.arrange == "furniture":
		var tint := Data.col("#b89cff", 0.2 + sin(now * 4.0) * 0.06)
		for y in Game.BH:
			for x in Game.BW:
				var p := Vector2i(x, y)
				if Game.decor_movable(p):
					draw_rect(Rect2(p.x * T + 3, p.y * T + 3, T - 6, T - 6), Data.col("#b89cff", 1.0 if p == Game.decor_pick else 0.45), false, 3.0)
				elif Game.decor_pick != null and Game.decor_spot_ok(p):
					draw_rect(Rect2(p.x * T + 4, p.y * T + 4, T - 8, T - 8), tint)
	# arranging traps: every trap outlined, the picked one bright, and free tiles tinted
	if Game.arrange == "traps":
		var tt := Data.col("#e4a648", 0.18 + sin(now * 4.0) * 0.06)
		for y in Game.BH:
			for x in Game.BW:
				var p := Vector2i(x, y)
				if Game.traps.has(p):
					draw_rect(Rect2(p.x * T + 3, p.y * T + 3, T - 6, T - 6), Data.col("#e4a648", 1.0 if p == Game.trap_pick else 0.45), false, 3.0)
				elif Game.trap_pick != null and Game.trap_spot_ok(p):
					draw_rect(Rect2(p.x * T + 4, p.y * T + 4, T - 8, T - 8), tt)
	# arranging minions: a ring on each one so they're easy to find
	if Game.arrange == "minions":
		for m in Game.minions:
			var on: bool = Game.sel_minion == m
			draw_arc((Vector2(m.post) + Vector2(0.5, 0.5)) * T, T * 0.46, 0, TAU, 28, Data.col("#86b35e", 1.0 if on else 0.55 + sin(now * 4.0) * 0.2), 3.0, true)
	if Game.ent_mode:
		var a := 0.25 + sin(now * 4.0) * 0.1
		for y in Game.BH:
			for x in Game.BW:
				var p := Vector2i(x, y)
				if Game.on_border(p) and Game.is_open(p) and p != Game.entrance:
					draw_rect(Rect2(x * T + 4, y * T + 4, T - 8, T - 8), Data.col("#e4a648", a))
	if Game.sel >= 0 and not Game.ent_mode and Game.trap_mode == "":
		var o := Vector2(Game.slot_xy(Game.sel) * Game.RS) * T
		draw_rect(Rect2(o + Vector2(4, 4), Vector2(Game.RS, Game.RS) * T - Vector2(8, 8)), Data.col("#e4a648"), false, 4.0)
	if not Game.in_b(hover):
		return
	if Game.trap_mode != "" or Game.sel_minion != null or Game.ent_mode or Game.arrange != "":
		var c := Data.col("#e4a648") if Game.trap_mode != "" else (Data.col("#ffd090") if Game.ent_mode else (Data.col("#b89cff") if Game.arrange == "furniture" else (Data.col("#e4a648") if Game.arrange == "traps" else Data.col("#86b35e"))))
		draw_rect(Rect2(hover.x * T + 3, hover.y * T + 3, T - 6, T - 6), c, false, 3.0)
	else:
		var o := Vector2(Game.slot_xy(Game.slot_of(hover)) * Game.RS) * T
		draw_rect(Rect2(o + Vector2(8, 8), Vector2(Game.RS, Game.RS) * T - Vector2(16, 16)), Data.col("#e4a648", 0.35), false, 2.5)

func _draw_night_overlay() -> void:
	if battle.threat.size() > 0:
		for k in battle.threat:
			draw_rect(Rect2(k.x * T + 1, k.y * T + 1, T - 2, T - 2), Data.col("#dc3c46", 0.2))
	if battle.mode != "":
		var sp := battle.spell(battle.mode)
		for p in battle.spell_tiles(sp):
			draw_rect(Rect2(p.x * T + 3, p.y * T + 3, T - 6, T - 6), Data.col("#9b84ff", 0.3))
		if sp.kind == "area" and Game.in_b(hover):
			draw_rect(Rect2((hover.x - 1) * T + 3, (hover.y - 1) * T + 3, 3 * T - 6, 3 * T - 6), Data.col(Game.M.col), false, 3.0)
	elif battle.reach.size() > 0 and not battle.busy:
		for k in battle.reach:
			var v: Dictionary = battle.reach[k]
			if v.d > 0 and not v.occ:
				draw_rect(Rect2(k.x * T + 3, k.y * T + 3, T - 6, T - 6), Data.col("#6e96ff", 0.26))
		if battle.reach.has(hover) and battle.reach[hover].d > 0 and not battle.reach[hover].occ:
			draw_rect(Rect2(hover.x * T + 4, hover.y * T + 4, T - 8, T - 8), Data.col("#96b4ff", 0.9), false, 3.0)

func _draw_unit(xf: Transform2D, kind: String, D: Dictionary, at: Vector2, side: String, hp: int, max_hp: int, id: int,
		fl: bool, selected: bool, done: bool, slow: bool, root: bool, dashed: bool, flee: bool, stun: bool, thrall: bool, bar: bool) -> void:
	var c := (at + Vector2(0.5, 0.5)) * T
	draw_set_transform_matrix(xf * Transform2D(0.0, c))
	var R := 22.0 if kind == "monster" else (20.0 if kind == "squire" else (21.0 if D.get("boss", false) else 15.0))
	var bob := sin(now * 3.0 + id) * 1.5
	Sprites.ell(self, Vector2(0, R + 3), R * 0.9, 4, Color(0, 0, 0, 0.65))
	if selected:
		draw_arc(Vector2.ZERO, R + 6, 0, TAU, 28, Data.col("#86b35e") if battle == null else Data.col("#e4a648"), 3.0, true)
	if slow or root:
		draw_circle(Vector2.ZERO, R + 6, Data.col("#b08a5a", 0.35) if root else Data.col("#a8d8ff", 0.3))
	if dashed:
		for i in 12:
			draw_arc(Vector2.ZERO, R + 5, i * TAU / 12, i * TAU / 12 + TAU / 24, 4, Data.col("#c77dff"), 2.0)
	if flee:
		draw_circle(Vector2(-R + 2, R - 6), 6, Data.col("#e4a648"))
	if kind == "monster":
		Sprites.monster(self, Game.mk, Data.col(Game.M.col), R, bob, fl, now)
	elif kind == "squire":
		Sprites.monster(self, "squire", Data.col(D.col), R, bob, fl, now)
	elif side == "h" or thrall:
		Sprites.hero(self, kind, Data.col(D.get("col", "#cccccc")), R, bob, fl, now)
	else:
		Sprites.minion(self, kind, bob, fl, now)
	if done:
		draw_circle(Vector2.ZERO, R + 2, Color(0.05, 0.04, 0.06, 0.45))
	if stun:
		draw_string(font, Vector2(R - 10, -R), "zz", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Data.col("#ff9ab0"))
	if bar and battle:
		var w := T * 0.78
		draw_rect(Rect2(-w / 2, T * 0.38, w, 6), Color(0, 0, 0, 0.8))
		var bc := Data.col("#ff5d74") if kind == "monster" or kind == "squire" else (Data.col("#c77dff") if thrall else (Data.col("#86b35e") if side == "p" else Data.col("#e0a050")))
		draw_rect(Rect2(-w / 2, T * 0.38, w * float(hp) / max_hp, 6), bc)
