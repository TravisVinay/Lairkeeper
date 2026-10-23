class_name Sprites
extends RefCounted
## Placeholder art drawn with canvas primitives. Furniture and traps draw inside a 64x64 tile
## with its top-left at the origin; units draw centered on the origin. Swap any of these for
## real textures later without touching game logic.

static func C(h: String, a := 1.0) -> Color:
	return Data.col(h, a)

static func ell(c: CanvasItem, ctr: Vector2, rx: float, ry: float, col: Color, seg := 20) -> void:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, col)

static func poly(c: CanvasItem, pts: Array, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array(pts), col)

static func rect(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(x, y, w, h), col)

static func ln(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 2.0) -> void:
	c.draw_line(a, b, col, w, true)

static func arc(c: CanvasItem, p: Vector2, r: float, col: Color, w := 2.0, a0 := 0.0, a1 := TAU) -> void:
	c.draw_arc(p, r, a0, a1, 28, col, w, true)

static func glow(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	for i in 4:
		var cc := col
		cc.a = col.a * 0.28
		c.draw_circle(p, r * (1.0 - i * 0.22), cc)

static func quad(p0: Vector2, p1: Vector2, p2: Vector2, n := 8) -> Array:
	var o := []
	for i in n + 1:
		var t := float(i) / n
		o.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	return o

static func shadow(c: CanvasItem, w: float) -> void:
	ell(c, Vector2(32, 54), w, 7, Color(0, 0, 0, 0.4))

static func star(ctr: Vector2, r: float) -> Array:
	var o := []
	for i in 5:
		var a := -PI / 2 + i * PI * 4 / 5
		o.append(ctr + Vector2(cos(a), sin(a)) * r)
	return o


# ---------------------------------------------------------------- traps

static func trap(c: CanvasItem, t: String, now: float) -> void:
	match t:
		"spikes":
			rect(c, 10, 10, 44, 44, Color(0, 0, 0, 0.3))
			for i in 3:
				for j in 3:
					var p := Vector2(18 + i * 14, 20 + j * 13)
					poly(c, [p + Vector2(-5, 5), p + Vector2(0, -5), p + Vector2(5, 5)], C("#9a92a2"))
		"snare":
			arc(c, Vector2(32, 32), 16, C("#b08a5a"), 3)
			for i in 8:
				var a := i * PI / 4
				ln(c, Vector2(32, 32) + Vector2(cos(a), sin(a)) * 10, Vector2(32, 32) + Vector2(cos(a), sin(a)) * 18, C("#b08a5a"), 2)
		_:
			var col := C("#ff7a3a", 0.6 + sin(now * 3) * 0.25)
			var s := star(Vector2(32, 32), 17)
			c.draw_polyline(PackedVector2Array([s[0], s[2], s[4], s[1], s[3], s[0]]), col, 3, true)
			arc(c, Vector2(32, 32), 21, col, 3)


# ---------------------------------------------------------------- furniture

static func furniture(c: CanvasItem, k: String, now: float, seed: int, mcol: Color) -> void:
	match k:
		"pillar", "cracked":
			shadow(c, 20)
			rect(c, 16, 8, 32, 46, C("#4b4352"))
			rect(c, 16, 8, 10, 46, C("#5f5668"))
			rect(c, 12, 4, 40, 9, C("#3a3340"))
			rect(c, 12, 50, 40, 7, C("#3a3340"))
			if k == "cracked":
				c.draw_polyline(PackedVector2Array([Vector2(30, 14), Vector2(36, 26), Vector2(28, 36), Vector2(34, 48)]), C("#1d1822"), 2)
		"throne":
			rect(c, 14, 2, 36, 30, C("#2a1a22"))
			rect(c, 14, 2, 36, 4, mcol)
			poly(c, [Vector2(14, 2), Vector2(20, -6), Vector2(26, 2)], mcol)
			poly(c, [Vector2(38, 2), Vector2(44, -6), Vector2(50, 2)], mcol)
			rect(c, 10, 30, 44, 22, C("#3c2530"))
			rect(c, 10, 30, 44, 3, C("#e4a648"))
			rect(c, 8, 26, 6, 28, C("#e4a648"))
			rect(c, 50, 26, 6, 28, C("#e4a648"))
		"brazier":
			shadow(c, 14)
			rect(c, 28, 30, 8, 22, C("#3a3340"))
			poly(c, [Vector2(14, 24), Vector2(50, 24), Vector2(42, 36), Vector2(22, 36)], C("#5a4a3a"))
			var f := sin(now * 9 + seed) * 3
			glow(c, Vector2(32, 18), 30, C("#ffa03c", 0.5))
			ell(c, Vector2(32, 16 - f * 0.3), 9, 13 + f, C("#ffb040"))
			ell(c, Vector2(32, 20), 4, 7, C("#ffe090"))
		"rug":
			rect(c, 10, 0, 44, 64, C("#781428", 0.55))
			c.draw_rect(Rect2(14, 0, 36, 64), C("#e4a648", 0.5), false, 2)
		"chest":
			shadow(c, 20)
			rect(c, 12, 22, 40, 28, C("#6a4020"))
			poly(c, quad(Vector2(12, 24), Vector2(32, 8), Vector2(52, 24)), C("#7d4c26"))
			rect(c, 12, 30, 40, 4, C("#e4a648"))
			rect(c, 29, 28, 6, 10, C("#e4a648"))
		"coins":
			for e in [[24, 40, 7], [34, 42, 8], [30, 34, 7], [40, 36, 6], [20, 46, 5], [44, 46, 5]]:
				c.draw_circle(Vector2(e[0], e[1]), e[2], C("#e4a648"))
			c.draw_circle(Vector2(32, 32), 3, C("#ffe090"))
		"table":
			shadow(c, 24)
			rect(c, 8, 18, 48, 26, C("#5a3a22"))
			rect(c, 8, 18, 48, 6, C("#6d4a2c"))
			ell(c, Vector2(24, 32), 7, 4, C("#d8d0c0"))
			ell(c, Vector2(40, 32), 8, 5, C("#a03a2a"))
		"barrel":
			shadow(c, 16)
			ell(c, Vector2(32, 32), 16, 20, C("#6a4426"))
			ln(c, Vector2(17, 24), Vector2(47, 24), C("#3a2a1a"), 3)
			ln(c, Vector2(17, 40), Vector2(47, 40), C("#3a2a1a"), 3)
		"meat":
			ln(c, Vector2(32, 0), Vector2(32, 16), C("#8a8a90"), 2)
			ell(c, Vector2(32, 28), 9, 13, C("#a8323a"))
			rect(c, 30, 38, 4, 8, C("#e8dcc0"))
		"bunk":
			rect(c, 8, 6, 48, 52, C("#4a3424"))
			rect(c, 12, 18, 40, 36, C("#5f8f3a"))
			rect(c, 14, 10, 36, 10, C("#d8d0c0"))
		"fire":
			glow(c, Vector2(32, 34), 30, C("#ff9632", 0.45))
			ln(c, Vector2(18, 46), Vector2(46, 38), C("#5a3a22"), 5)
			ln(c, Vector2(18, 38), Vector2(46, 46), C("#5a3a22"), 5)
			var f := sin(now * 10) * 2
			ell(c, Vector2(32, 32 - f), 8, 12 + f, C("#ff9a30"))
			ell(c, Vector2(32, 36), 4, 6, C("#ffe090"))
		"rack":
			shadow(c, 20)
			rect(c, 8, 40, 48, 6, C("#4a3424"))
			rect(c, 8, 10, 4, 40, C("#4a3424"))
			rect(c, 52, 10, 4, 40, C("#4a3424"))
			for i in 4:
				ln(c, Vector2(18 + i * 9, 42), Vector2(18 + i * 9, 8), C("#c9ccd2"), 3)
		"armor":
			shadow(c, 16)
			rect(c, 30, 40, 4, 14, C("#4a3424"))
			poly(c, [Vector2(18, 16), Vector2(46, 16), Vector2(42, 42), Vector2(22, 42)], C("#8a94a0"))
			c.draw_circle(Vector2(32, 10), 8, C("#8a94a0"))
			rect(c, 28, 8, 8, 3, C("#5a6470"))
		"cage":
			shadow(c, 22)
			c.draw_rect(Rect2(10, 10, 44, 44), C("#6a6470"), false, 3)
			for i in range(1, 5):
				ln(c, Vector2(10 + i * 9, 10), Vector2(10 + i * 9, 54), C("#6a6470"), 3)
		"bones":
			ln(c, Vector2(14, 44), Vector2(34, 36), C("#e8dcc0"), 3)
			ln(c, Vector2(28, 48), Vector2(48, 40), C("#e8dcc0"), 3)
			c.draw_circle(Vector2(40, 26), 6, C("#e8dcc0"))
			rect(c, 37, 25, 2, 2, C("#1d1822"))
			rect(c, 41, 25, 2, 2, C("#1d1822"))
		"anvil":
			shadow(c, 20)
			poly(c, [Vector2(10, 22), Vector2(54, 22), Vector2(46, 32), Vector2(40, 32), Vector2(40, 46), Vector2(24, 46), Vector2(24, 32), Vector2(18, 32)], C("#3a3a42"))
			rect(c, 14, 22, 38, 3, C("#5a5a62"))
		"bench":
			shadow(c, 24)
			rect(c, 6, 20, 52, 22, C("#5a3a22"))
			rect(c, 14, 14, 4, 10, C("#8a8a90"))
			rect(c, 40, 12, 10, 6, C("#8a8a90"))
			arc(c, Vector2(28, 30), 5, C("#e4a648"), 2)
		"gear", "gearbig":
			var big := k == "gearbig"
			var r := 20.0 if big else 11.0
			var a := now * (0.8 if big else -1.4) + seed
			if big:
				shadow(c, 20)
			var gc := C("#b08a3a") if big else C("#8a7a5a")
			for i in 8:
				var ang := a + i * PI / 4
				var dir := Vector2(cos(ang), sin(ang))
				var side := Vector2(-dir.y, dir.x) * 3
				poly(c, [Vector2(32, 32) + dir * (r - 2) - side, Vector2(32, 32) + dir * (r + 5) - side, Vector2(32, 32) + dir * (r + 5) + side, Vector2(32, 32) + dir * (r - 2) + side], gc)
			c.draw_circle(Vector2(32, 32), r, gc)
			c.draw_circle(Vector2(32, 32), r * 0.35, C("#2a2230"))
		"rack2":
			shadow(c, 24)
			rect(c, 10, 14, 44, 36, C("#5a3a22"))
			rect(c, 14, 18, 36, 28, C("#3a2414"))
			arc(c, Vector2(10, 32), 6, C("#8a8a90"), 2)
			arc(c, Vector2(54, 32), 6, C("#8a8a90"), 2)
		"maiden":
			shadow(c, 16)
			poly(c, [Vector2(20, 56)] + quad(Vector2(18, 18), Vector2(32, 0), Vector2(46, 18)) + [Vector2(44, 56)], C("#4a4a52"))
			rect(c, 31, 14, 2, 40, C("#2a2a30"))
			c.draw_circle(Vector2(32, 18), 5, C("#d8d0c0"))
		"chains":
			for i in 5:
				c.draw_arc(Vector2(20 + i * 6, 10 + i * 9), 4, 0, TAU, 12, C("#7a7a82"), 2)
		"blood":
			for e in [[30, 34, 10], [42, 40, 5], [22, 42, 4], [38, 26, 3]]:
				c.draw_circle(Vector2(e[0], e[1]), e[2], C("#8c1020", 0.6))
		"rubble":
			for e in [[22, 40, 6], [34, 44, 8], [44, 36, 5], [28, 30, 4]]:
				c.draw_circle(Vector2(e[0], e[1]), e[2], C("#4b4352"))
		"shelf":
			shadow(c, 24)
			rect(c, 6, 6, 52, 50, C("#4a3020"))
			var cols := ["#7a2a3a", "#2a4a7a", "#3a6a3a", "#8a6a2a", "#5a3a7a"]
			for r in 3:
				rect(c, 9, 8 + r * 16, 46, 2, C("#2a1a10"))
				for i in 7:
					rect(c, 10 + i * 6.4, 11 + r * 16, 5, 12, C(cols[(i + r + seed) % 5]))
		"candles":
			for e in [[22, 40], [34, 34], [42, 44]]:
				rect(c, e[0] - 2, e[1] - 10, 4, 12, C("#e8dcc0"))
				glow(c, Vector2(e[0], e[1] - 14), 10, C("#ffc864", 0.55))
				ell(c, Vector2(e[0], e[1] - 14 + sin(now * 9 + e[0]) * 0.8), 2, 4, C("#ffd070"))
		"well":
			c.draw_circle(Vector2(32, 32), 24, C("#4b4352"))
			glow(c, Vector2(32, 32), 22, C("#7fb4ff", 0.7))
			c.draw_circle(Vector2(32, 32), 16, C("#7fb4ff", 0.5 + sin(now * 2) * 0.15))
		"crystal":
			shadow(c, 14)
			glow(c, Vector2(32, 28), 28, C("#b48cff", 0.4))
			poly(c, [Vector2(32, 2), Vector2(44, 26), Vector2(36, 54), Vector2(26, 54), Vector2(20, 26)], C("#9b84ff"))
			poly(c, [Vector2(32, 6), Vector2(36, 26), Vector2(30, 48)], Color(1, 1, 1, 0.35))
		"runecircle":
			var col := C("#ff8c50", 0.45 + sin(now * 2 + seed) * 0.15)
			arc(c, Vector2(32, 32), 24, col, 2)
			var s := star(Vector2(32, 32), 22)
			c.draw_polyline(PackedVector2Array([s[0], s[2], s[4], s[1], s[3], s[0]]), col, 2, true)
		"altar":
			rect(c, 14, 28, 36, 20, C("#5a5262"))
			rect(c, 12, 26, 40, 5, C("#6f6678"))
			glow(c, Vector2(32, 20), 22, C("#d6c8ff", 0.6))
			poly(c, [Vector2(32, 8), Vector2(38, 20), Vector2(32, 28), Vector2(26, 20)], C("#d6c8ff"))
		"coffin":
			shadow(c, 16)
			poly(c, [Vector2(24, 4), Vector2(40, 4), Vector2(48, 16), Vector2(42, 60), Vector2(22, 60), Vector2(16, 16)], C("#2a1a1a"))
			rect(c, 30, 18, 4, 20, C("#8a6a4a"))
			rect(c, 25, 24, 14, 4, C("#8a6a4a"))
		"bigcoffin":
			poly(c, [Vector2(22, 0), Vector2(42, 0), Vector2(52, 14), Vector2(44, 64), Vector2(20, 64), Vector2(12, 14)], C("#3a1020"))
			rect(c, 22, 10, 20, 46, C("#8a1a3a"))
			c.draw_rect(Rect2(22, 10, 20, 46), C("#e4a648"), false, 2)
		"pool":
			ell(c, Vector2(32, 34), 28, 22, C("#4b2030"))
			ell(c, Vector2(32, 34), 23, 17, C("#b41428", 0.75 + sin(now * 2) * 0.1))
		"tomb":
			shadow(c, 16)
			poly(c, [Vector2(18, 56)] + quad(Vector2(18, 20), Vector2(32, 4), Vector2(46, 20)) + [Vector2(46, 56)], C("#6a6470"))
			rect(c, 30, 20, 4, 18, C("#4b4552"))
			rect(c, 24, 26, 16, 4, C("#4b4552"))
			rect(c, 14, 52, 36, 5, C("#3a5a3a"))
		"forge":
			shadow(c, 22)
			rect(c, 8, 12, 48, 42, C("#3a3340"))
			rect(c, 16, 26, 32, 20, C("#1a1418"))
			glow(c, Vector2(32, 36), 26, C("#6fd3a0", 0.55))
			ell(c, Vector2(32, 38), 10, 6 + sin(now * 8) * 2, C("#6fd3a0"))
		"wisp":
			var y := 30 + sin(now * 2 + seed) * 6
			glow(c, Vector2(32, y), 20, C("#6fd3a0", 0.6))
			c.draw_circle(Vector2(32, y), 5, C("#cfffe0"))
		"bars":
			rect(c, 6, 6, 52, 52, C("#2a2230"))
			for i in 6:
				ln(c, Vector2(10 + i * 9, 6), Vector2(10 + i * 9, 58), C("#7a7a82"), 3)
			rect(c, 24, 26, 4, 3, C("#c77dff"))
			rect(c, 34, 26, 4, 3, C("#c77dff"))
		"jar":
			shadow(c, 14)
			rect(c, 16, 12, 32, 42, C("#aac8dc", 0.3))
			c.draw_rect(Rect2(16, 12, 32, 42), C("#c8dcf0", 0.6), false, 2)
			rect(c, 14, 8, 36, 6, C("#6a6470"))
			ell(c, Vector2(32, 36), 10 + sin(now * 2 + seed), 8, C("#e890b0"))
			ln(c, Vector2(32, 28), Vector2(32, 44), C("#b05a80"), 1.5)
		"crate":
			shadow(c, 22)
			rect(c, 10, 12, 44, 42, C("#7a5a32"))
			c.draw_rect(Rect2(10, 12, 44, 42), C("#4a3420"), false, 3)
			ln(c, Vector2(10, 12), Vector2(54, 54), C("#4a3420"), 3)
			ln(c, Vector2(54, 12), Vector2(10, 54), C("#4a3420"), 3)
		"rope":
			for i in 3:
				var pts := PackedVector2Array()
				for j in 21:
					var a := TAU * j / 20
					pts.append(Vector2(32, 38) + Vector2(cos(a) * (18 - i * 5), sin(a) * (10 - i * 3)))
				c.draw_polyline(pts, C("#b08a5a"), 3, true)
		"stairs_down":
			rect(c, 4, 4, 56, 56, C("#0b080d"))
			for i in 5:
				var w := 52.0 - i * 9
				rect(c, 32 - w / 2, 8 + i * 10, w, 7, Color.from_hsv(0.09, 0.25, 0.42 - i * 0.07))
			glow(c, Vector2(32, 50), 18, C("#e4a648", 0.25))
		"stairs_up":
			rect(c, 6, 6, 52, 52, C("#2a2230"))
			for i in 5:
				var w := 16.0 + i * 9
				rect(c, 32 - w / 2, 10 + i * 9, w, 6, Color.from_hsv(0.09, 0.2, 0.25 + i * 0.06))
			poly(c, [Vector2(32, 2), Vector2(24, 10), Vector2(40, 10)], C("#e4a648", 0.8))
		"stairs":
			for i in 4:
				rect(c, 6 + i * 3, 4 + i * 9, 52 - i * 6, 8, Color.from_hsv(0.08, 0.3, 0.3 - i * 0.05))


# ---------------------------------------------------------------- units

static func monster(c: CanvasItem, mk: String, col: Color, R: float, bob: float, fl: bool, now: float) -> void:
	glow(c, Vector2.ZERO, R + 16, Color(col, 0.5))
	var w := Color.WHITE
	match mk:
		"lich":
			poly(c, [Vector2(-R, R), Vector2(-R * 0.6, -R * 0.4 + bob), Vector2(R * 0.6, -R * 0.4 + bob), Vector2(R, R)], w if fl else C("#2f2656"))
			c.draw_circle(Vector2(0, -R * 0.45 + bob), 10, C("#e8e0d0"))
			rect(c, -6, -R * 0.5 + bob, 4, 4, C("#9b84ff"))
			rect(c, 2, -R * 0.5 + bob, 4, 4, C("#9b84ff"))
			poly(c, [Vector2(-9, -R * 0.75 + bob), Vector2(-6, -R * 1.1 + bob), Vector2(0, -R * 0.85 + bob), Vector2(6, -R * 1.1 + bob), Vector2(9, -R * 0.75 + bob)], C("#e4a648"))
			c.draw_circle(Vector2(R * 0.9, -4 + sin(now * 3) * 3), 4, C("#bfe0ff"))
		"vampire":
			poly(c, quad(Vector2(-R - 6, R), Vector2(-R, -R * 0.6), Vector2(0, -R * 0.5)) + quad(Vector2(0, -R * 0.5), Vector2(R, -R * 0.6), Vector2(R + 6, R)).slice(1), w if fl else C("#1a0c12"))
			poly(c, [Vector2(-8, R), Vector2(0, -2), Vector2(8, R)], C("#7a0f22"))
			ell(c, Vector2(0, -R * 0.45 + bob), 9, 11, C("#e8dcd8"))
			rect(c, -6, -R * 0.55 + bob, 4, 3, C("#ff2a4a"))
			rect(c, 2, -R * 0.55 + bob, 4, 3, C("#ff2a4a"))
			poly(c, [Vector2(-9, -R * 0.75 + bob), Vector2(0, -R * 1.1 + bob), Vector2(9, -R * 0.75 + bob), Vector2(0, -R * 0.55 + bob)], C("#1a0c12"))
		"necro":
			poly(c, [Vector2(-R, R), Vector2(0, -R + bob), Vector2(R, R)], w if fl else C("#1f3a2e"))
			c.draw_circle(Vector2(0, -R * 0.25 + bob), 8, C("#0c1410"))
			rect(c, -5, -R * 0.3 + bob, 3, 3, C("#6fd3a0"))
			rect(c, 2, -R * 0.3 + bob, 3, 3, C("#6fd3a0"))
			ln(c, Vector2(R * 0.8, R), Vector2(R * 0.8, -R * 0.9), C("#8a7050"), 3)
			c.draw_circle(Vector2(R * 0.8, -R), 9 + sin(now * 4) * 2, C("#6fd3a0", 0.5))
			c.draw_circle(Vector2(R * 0.8, -R), 6, C("#e8dcc0"))
		"flayer":
			for i in 4:
				var ox := -9 + i * 6
				var pts := quad(Vector2(ox, 2), Vector2(ox + sin(now * 3 + i) * 6, 12), Vector2(ox + sin(now * 2 + i) * 4, 20), 6)
				c.draw_polyline(PackedVector2Array(pts), C("#7a3f9e"), 4, true)
			ell(c, Vector2(0, -6 + bob), R * 0.75, R * 0.8, w if fl else C("#9a5cc4"))
			ell(c, Vector2(-7, -8 + bob), 4, 5, C("#f4f0ff"))
			ell(c, Vector2(7, -8 + bob), 4, 5, C("#f4f0ff"))
			arc(c, Vector2(0, -6), R + 4 + sin(now * 5) * 2, C("#c77dff", 0.5), 2, PI * 1.1, PI * 1.9)
		_:
			var open := maxf(0.0, sin(now * 2.2)) * 6
			rect(c, -R, -4 + open * 0.2, R * 2, R * 0.9, w if fl else C("#7a4a22"))
			rect(c, -R, -2, R * 2, 3, C("#e4a648"))
			rect(c, -3, -2, 6, 10, C("#e4a648"))
			poly(c, quad(Vector2(-R, -6 - open), Vector2(0, -R - 8 - open), Vector2(R, -6 - open)), C("#8f5a2a"))
			rect(c, -R + 2, -6 - open, R * 2 - 4, open + 3, C("#3a0a10"))
			for i in 6:
				poly(c, [Vector2(-R + 4 + i * 7, -6 - open), Vector2(-R + 7 + i * 7, -1 - open * 0.5), Vector2(-R + 10 + i * 7, -6 - open)], C("#f4ecd8"))
			rect(c, -8, -R * 0.4 - open, 4, 4, C("#ffe25a"))
			rect(c, 4, -R * 0.4 - open, 4, 4, C("#ffe25a"))

static func minion(c: CanvasItem, kind: String, bob: float, fl: bool, now: float) -> void:
	var w := Color.WHITE
	match kind:
		"goblin":
			poly(c, [Vector2(-10, -4 + bob), Vector2(-22, -11 + bob), Vector2(-9, 2 + bob)], C("#5f8f3a"))
			poly(c, [Vector2(10, -4 + bob), Vector2(22, -11 + bob), Vector2(9, 2 + bob)], C("#5f8f3a"))
			c.draw_circle(Vector2(0, bob), 13, w if fl else C("#78ad48"))
			rect(c, -6, -3 + bob, 4, 3, C("#ffe25a"))
			rect(c, 2, -3 + bob, 4, 3, C("#ffe25a"))
			ln(c, Vector2(9, 6 + bob), Vector2(17, -3 + bob), C("#d0d6dc"), 2.5)
		"hound":
			ell(c, Vector2(0, bob * 0.5), 18, 11, w if fl else C("#6a1e1a"))
			c.draw_circle(Vector2(12, -6), 9, w if fl else C("#6a1e1a"))
			poly(c, [Vector2(8, -12), Vector2(10, -22), Vector2(14, -13)], C("#6a1e1a"))
			rect(c, 13, -9, 4, 3, C("#ffb040"))
			c.draw_circle(Vector2(-16, -4 + sin(now * 9) * 2), 4, C("#ff7828", 0.6))
		"skeleton", "ghoul":
			var gh := kind == "ghoul"
			var bc := w if fl else (C("#8fa88a") if gh else C("#e8dcc0"))
			c.draw_circle(Vector2(0, -4 + bob), 13 if gh else 11, bc)
			rect(c, -6, 4 + bob, 12, 7, bc)
			c.draw_circle(Vector2(-4, -5 + bob), 3, C("#1d1822"))
			c.draw_circle(Vector2(4, -5 + bob), 3, C("#1d1822"))
			for i in 3:
				rect(c, -4 + i * 3.5, 6 + bob, 1.5, 4, C("#1d1822"))
		"spawn":
			poly(c, [Vector2(-16, 4 + bob), Vector2(-6, -6 + bob), Vector2(6, -6 + bob), Vector2(16, 4 + bob), Vector2(0, 12)], C("#1a0c12"))
			c.draw_circle(Vector2(0, -4 + bob), 8, w if fl else C("#d8c8c8"))
			rect(c, -4, -6 + bob, 3, 2, C("#ff2a4a"))
			rect(c, 1, -6 + bob, 3, 2, C("#ff2a4a"))
		_:
			c.draw_circle(Vector2(0, bob), 13, w if fl else C("#8a7a9a"))
			rect(c, -6, -3 + bob, 4, 3, C("#c77dff"))
			rect(c, 2, -3 + bob, 4, 3, C("#c77dff"))
			arc(c, Vector2(0, -14 + bob), 5, C("#c77dff"), 2)

static func hero(c: CanvasItem, kind: String, body: Color, R: float, bob: float, fl: bool, now: float) -> void:
	c.draw_circle(Vector2(0, bob * 0.3), R + 2, C("#120e15"))
	c.draw_circle(Vector2(0, bob * 0.3), R, Color.WHITE if fl else body)
	match kind:
		"peasant":
			ln(c, Vector2(10, 12), Vector2(17, -14), C("#d9c08a"), 2.5)
			ln(c, Vector2(12, -17), Vector2(22, -12), C("#d9c08a"), 2.5)
		"knight":
			rect(c, -20, -8, 10, 17, C("#5a6b80"))
			ln(c, Vector2(-6, -3), Vector2(6, -3), C("#3a4452"), 2.5)
		"rogue":
			poly(c, [Vector2(-14, -1), Vector2(0, -20), Vector2(14, -1)], C("#3d2a5a"))
			ln(c, Vector2(12, 8), Vector2(20, 0), C("#c9ccd2"), 2.5)
		"archer":
			arc(c, Vector2(10, 0), 13, C("#8a6440"), 2.5, -1.3, 1.3)
			ln(c, Vector2(13, -13), Vector2(13, 13), C("#e8dcc0"), 1)
		"cleric":
			ln(c, Vector2(0, -8), Vector2(0, 8), C("#d6a83a"), 2.5)
			ln(c, Vector2(-6, -2), Vector2(6, -2), C("#d6a83a"), 2.5)
		"sapper":
			poly(c, [Vector2(-9, 2), Vector2(0, 16), Vector2(9, 2)], C("#d8c0a0"))
			ln(c, Vector2(10, 10), Vector2(18, -10), C("#8a8a90"), 3)
			ln(c, Vector2(12, -12), Vector2(24, -6), C("#8a8a90"), 3)
		"mage":
			poly(c, [Vector2(-12, -6), Vector2(0, -28), Vector2(12, -6)], C("#2a3f7a"))
			c.draw_circle(Vector2(16, -2 + sin(now * 6) * 2), 5, C("#ff9a40"))
		"barbarian":
			ln(c, Vector2(-18, 10), Vector2(14, -16), C("#d0d6dc"), 4)
			c.draw_circle(Vector2(14, -16), 7, C("#d0d6dc"))
			poly(c, [Vector2(-10, -12), Vector2(-16, -22), Vector2(-6, -14)], C("#f3e2c0"))
			poly(c, [Vector2(10, -12), Vector2(16, -22), Vector2(6, -14)], C("#f3e2c0"))
		"paladin":
			poly(c, [Vector2(-11, -15), Vector2(-7, -27), Vector2(0, -18), Vector2(7, -27), Vector2(11, -15)], C("#fff2b0"))
			arc(c, Vector2.ZERO, R + 6 + sin(now * 4) * 2, C("#ffe68c", 0.5), 2)
