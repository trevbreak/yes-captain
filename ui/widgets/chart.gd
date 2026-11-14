class_name Chart
extends Control
## The captain's chart: a top-down, north-up paper chart centred on our ship. It shows the goal, every contact
## (a "?" until Sensors scans it), incoming shots, the shield arc, the turret, and a clock face round our ship
## so the captain can call "incoming at 4 o'clock!".

var v: Dictionary = {}
var big: bool = false
static var STYLE: String = "starchart"   # the captain's chart: an old astronomer's star chart (also: paper | night | void)
const STYLES: Dictionary = {
	"paper": {"bg": "#e9dcbb", "ink": "#1d1712", "grid": "#6b5a48", "stars": false},
	"night": {"bg": "#1c2436", "ink": "#f2e2c0", "grid": "#8fb8c9", "stars": true},
	"void": {"bg": "#121117", "ink": "#f2e2c0", "grid": "#a98fb8", "stars": true, "nebula": true},
	"starchart": {"bg": "#2a2118", "ink": "#ecc983", "grid": "#d9a43a", "stars": true, "links": true},
}
var _ink: Color = Color("#1d1712")
var _halo: Color = Color("#e9dcbb")
var _gridc: Color = Color("#6b5a48")
var _done_t: Dictionary = {}     # step index -> when we first saw it done (its flag fades away)

static func style() -> Dictionary:
	return STYLES.get(STYLE, STYLES.paper)

static func bg_color() -> Color:
	return Color(str(style().bg))            # the captain's viewscreen: route flags and trouble pinned as chips
var view_r: float = 520.0
var _tex: Dictionary = {}
var _seen_fx: Dictionary = {}
var _wake: Array = []

const SPRITE: Dictionary = {
	"unknown": "obj_unknown", "ring": "obj_ring", "target": "obj_target", "buoy": "obj_buoy", "drone": "obj_drone",
	"grabber": "obj_grabber", "mine": "obj_mine", "cruiser": "obj_cruiser", "patrol": "obj_patrol", "rock": "obj_rock",
	"junk": "obj_junk", "skip": "obj_skip", "pod": "obj_pod", "customs": "obj_customs", "haven": "obj_haven", "diner": "obj_diner",
}
const ROTATES: Array = ["drone", "grabber", "cruiser", "patrol"]

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(420, 320)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _t(n: String, s: float = 0.8) -> Texture2D:
	var key: String = "%s@%.1f" % [n, s]
	if not _tex.has(key):
		_tex[key] = Art.tex(n, s)
	return _tex[key]

func _vec(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() >= 2 else Vector2.ZERO

func _process(dt: float) -> void:
	if v.is_empty():
		return
	# zoom to keep the goal and the nearest trouble in view
	var sp: Vector2 = _vec(v.get("ship", {}).get("pos", [0, 0]))
	var want: float = 420.0
	var g: Vector2 = _vec(v.get("goal", []))
	if v.get("goal", []) is Array and (v.goal as Array).size() == 2:
		want = maxf(want, minf(g.distance_to(sp) * 1.15, 1000.0))
	for e in v.get("ents", []):
		var d: float = _vec(e.pos).distance_to(sp)
		if bool(e.hostile) and d < 900.0:
			want = maxf(want, d * 1.1)
	view_r = lerpf(view_r, clampf(want, 380.0, 1000.0), 1.0 - exp(-1.5 * dt))
	queue_redraw()

func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var stl: Dictionary = style()
	_ink = Color(str(stl.ink))
	_halo = Color(str(stl.bg))
	_gridc = Color(str(stl.grid))
	draw_rect(r, _halo)
	if v.is_empty():
		return
	var ship: Dictionary = v.get("ship", {})
	var sp: Vector2 = _vec(ship.get("pos", [0, 0]))
	var hd: float = float(ship.get("heading", -PI / 2.0))
	var c: Vector2 = size / 2.0
	var k: float = minf(size.x, size.y) * 0.5 / view_r
	var f: Font = UIK.font("head")
	var fb: Font = UIK.font("body")
	var tnow: float = Time.get_ticks_msec() / 1000.0
	# grid (100 m squares), sliding under us
	# a sea chart, not graph paper: faint sepia lines, every fifth one firmer
	var step: float = 100.0 * k
	var x: float = fposmod(-sp.x * k + c.x, step)
	var ix: int = int(floor((x - c.x) / step + sp.x / 100.0 + 0.5))
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(_gridc, 0.28 if ix % 5 == 0 else 0.11), 2.0 if ix % 5 == 0 else 1.2)
		x += step
		ix += 1
	var y: float = fposmod(-sp.y * k + c.y, step)
	var iy: int = int(floor((y - c.y) / step + sp.y / 100.0 + 0.5))
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(_gridc, 0.28 if iy % 5 == 0 else 0.11), 2.0 if iy % 5 == 0 else 1.2)
		y += step
		iy += 1
	if bool(stl.get("stars", false)):
		_stars(sp, k, c, stl)
	# somebody's tea has been on this chart
	if STYLE == "paper":
		draw_arc(Vector2(size.x * 0.82, size.y * 0.78), 34.0, 0.3, TAU - 0.5, 40, Color(K.pal("brown"), 0.16), 5.0, true)
		draw_arc(Vector2(size.x * 0.82 + 3.0, size.y * 0.78 + 2.0), 30.0, 1.0, TAU, 40, Color(K.pal("brown"), 0.08), 3.0, true)
	var to_s: Callable = func(p: Vector2) -> Vector2: return c + (p - sp) * k
	# where we've been: a pencil line behind the ship
	if _wake.is_empty() or (_wake[_wake.size() - 1] as Vector2).distance_to(sp) > 22.0:
		_wake.append(sp)
		if _wake.size() > 60:
			_wake.pop_front()
	if not _wake.is_empty() and (_wake[_wake.size() - 1] as Vector2).distance_to(sp) > 600.0:
		_wake.clear()
	for wi in range(1, _wake.size()):
		if wi % 2 == 0:
			draw_line(to_s.call(_wake[wi - 1]), to_s.call(_wake[wi]), Color(_ink, 0.3 * float(wi) / float(_wake.size())), 2.5, true)
	# tractor range
	if ship.get("tractor", -1) != null and v.get("_feat_tractor", false):
		draw_arc(c, 150.0 * k, 0.0, TAU, 48, Color(UIK.c("lilac"), 0.6), 2.0, true)
	# goal
	var goal: Array = v.get("goal", [])
	if goal.size() == 2:
		var gp: Vector2 = to_s.call(_vec(goal))
		var inside: bool = r.grow(-30.0).has_point(gp)
		var gpe: Vector2 = gp if inside else _edge(c, gp, r.grow(-34.0))
		_dashed(c, gpe, UIK.c("red"), 3.0, 14.0)
		if inside and not (big and _has_route()):
			_flag(gp)
		else:
			var dir: Vector2 = (gp - c).normalized()
			draw_colored_polygon(PackedVector2Array([gpe + dir * 18.0, gpe + dir.orthogonal() * 12.0, gpe - dir.orthogonal() * 12.0]), UIK.c("red"))
			var dist: String = "%dm" % int(_vec(goal).distance_to(sp))
			var dp: Vector2 = gpe + dir.orthogonal() * 26.0 + Vector2(-18, 6)
			draw_string_outline(f, dp, dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 8, _halo)
			draw_string(f, dp, dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIK.c("red"))
	# entities
	for e in v.get("ents", []):
		var p: Vector2 = to_s.call(_vec(e.pos))
		if not r.grow(80.0).has_point(p):
			continue
		var kind: String = str(e.kind)
		var tex: Texture2D = _t(SPRITE.get(kind, "obj_unknown"))
		var px: float = clampf(float(e.r) * 2.4 * k, 24.0, 150.0)
		if kind == "ring":
			px = clampf(float(e.r) * 2.0 * k, 30.0, 90.0)
		elif kind == "unknown":
			px = clampf(px, 30.0, 52.0)
		var asp: float = float(tex.get_height()) / float(tex.get_width())
		var sz: Vector2 = Vector2(px, px * asp)
		if float(e.get("charge", 0.0)) > 0.0:
			var pul: float = 0.5 + 0.5 * sin(tnow * 18.0)
			draw_circle(p, px * 0.75 + pul * 8.0, Color(UIK.c("red"), 0.35 + 0.25 * pul))
		if bool(e.hostile):
			draw_arc(p, px * 0.6, 0.0, TAU, 32, Color(UIK.c("red"), 0.7), 3.0, true)
		var ring_done: bool = kind == "ring" and str(e.note) == "done"
		var ring_fade: float = 0.0
		if ring_done:
			# a ring we've flown through ticks for a moment, then fades into the background
			var key: String = "ring%d" % int(e.id)
			if not _done_t.has(key):
				_done_t[key] = tnow
			ring_fade = clampf((tnow - float(_done_t[key]) - 1.5) / 2.0, 0.0, 1.0)
		var mod: Color = Color(1, 1, 1, lerpf(0.6, 0.18, ring_fade)) if ring_done else Color.WHITE
		if kind in ROTATES:
			draw_set_transform(p, float(e.heading) + PI / 2.0, Vector2.ONE)
			draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, mod)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(tex, Rect2(p - sz / 2.0, sz), false, mod)
		if ring_done and ring_fade < 1.0:
			draw_texture_rect(Art.sized("icon_check", 26), Rect2(p - Vector2(13, 13), Vector2(26, 26)), false, Color(UIK.c("green"), 1.0 - ring_fade))
		if bool(e.get("thrown", false)):
			var vdir: Vector2 = (c - p).normalized()
			_dashed(p, p + vdir * 46.0, UIK.c("red"), 3.0, 8.0)
		if kind == "cruiser" and bool(e.get("weak", false)):
			var back: Vector2 = p - Vector2.from_angle(float(e.heading)) * sz.y * 0.42
			draw_circle(back, 12.0 + 3.0 * sin(tnow * 6.0), Color(UIK.c("yellow"), 0.8))
			draw_arc(back, 15.0, 0.0, TAU, 24, _ink, 2.5, true)
			_label(back + Vector2(16, 4), "WEAK SPOT", UIK.c("red"))
		if kind != "ring":
			var nm: String = str(e.name) if kind != "unknown" else "?"
			if kind == "unknown":
				pass
			elif (kind not in ["junk", "rock"] or not bool(e.get("thrown", false))) and p.distance_to(c) > 95.0:
				# skip names close to our ship: the clock face lives there
				if big and bool(e.hostile):
					_chip(p + Vector2(sz.x / 2.0 + 6.0, -12.0), ("%s · CHARGING!" % nm) if float(e.get("charge", 0.0)) > 0.0 else nm, UIK.c("red"))
				else:
					_label(p + Vector2(-sz.x / 2.0, sz.y / 2.0 + 15.0), nm, UIK.c("red") if bool(e.hostile) else _ink)
	# shots
	for s in v.get("shots", []):
		var p2: Vector2 = to_s.call(_vec(s.pos))
		if not r.has_point(p2):
			continue
		if s.from == "them":
			var back2: Vector2 = p2 - Vector2.from_angle(float(s.dir)) * 14.0
			draw_line(back2, p2, Color(UIK.c("red"), 0.5), 5.0, true)
			draw_circle(p2, 7.0, _ink)
			draw_circle(p2, 5.0, UIK.c("red"))
		elif s.kind == "torpedo":
			var t1: Vector2 = p2 - Vector2.from_angle(float(s.dir)) * 12.0
			draw_line(t1, p2, _ink, 7.0, true)
			draw_line(t1, p2, UIK.c("mustard"), 4.0, true)
		else:
			draw_circle(p2, 3.5, _ink)
	# effects
	for fx in v.get("fx", []):
		var p3: Vector2 = to_s.call(Vector2(float(fx.x), float(fx.y)))
		var age: float = float(v.get("_t", 0.0)) - float(fx.t)
		var fade: float = clampf(1.0 - age / 0.9, 0.0, 1.0)
		match str(fx.kind):
			"puff":
				var s3: float = clampf(float(fx.get("size", 20.0)) * 3.0 * k, 40.0, 140.0) * (0.7 + age)
				draw_texture_rect(_t("fx_puff"), Rect2(p3 - Vector2(s3, s3) / 2.0, Vector2(s3, s3)), false, Color(1, 1, 1, fade))
			"block":
				draw_circle(p3, 14.0 * fade + 4.0, Color(UIK.c("purple"), fade))
			"hit":
				draw_texture_rect(_t("fx_star"), Rect2(p3 - Vector2(24, 24), Vector2(48, 48)), false, Color(1, 1, 1, fade))
			"star":
				draw_texture_rect(_t("fx_star"), Rect2(p3 - Vector2(30, 30), Vector2(60, 60)), false, Color(1, 1, 1, fade))
	if big:
		_route(to_s, r, c)
	# our ship: shield arc, the ship, its turret
	var shield: float = hd + float(ship.get("shield", 0.0))
	if bool(ship.get("shield_ok", true)):
		var pts: PackedVector2Array = PackedVector2Array()
		var ro: float = 50.0
		var ri: float = 41.0
		for i in 21:
			pts.append(c + Vector2.from_angle(shield - 1.13 + 2.26 * i / 20.0) * ro)
		for i in 21:
			pts.append(c + Vector2.from_angle(shield + 1.13 - 2.26 * i / 20.0) * ri)
		draw_colored_polygon(pts, Color(UIK.c("purple"), 0.75))
	var tr: int = int(ship.get("tractor", -1))
	if tr >= 0:
		for e2 in v.get("ents", []):
			if int(e2.id) == tr:
				var tp: Vector2 = to_s.call(_vec(e2.pos))
				draw_line(c, tp, Color(UIK.c("lilac"), 0.8), 10.0, true)
	var stex: Texture2D = _t("ship_ours", 0.7)
	var sw: float = 46.0
	var sh: float = sw * 260.0 / 200.0
	draw_set_transform(c, hd + PI / 2.0, Vector2.ONE)
	draw_texture_rect(stex, Rect2(Vector2(-sw / 2.0, -sh / 2.0), Vector2(sw, sh)), false, Color(1, 1, 1, 0.55) if bool(ship.get("rolling", false)) else Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var aim_dir: Vector2 = Vector2.from_angle(hd + float(ship.get("aim", 0.0)))
	_dashed(c + aim_dir * 22.0, c + aim_dir * 130.0, Color(UIK.c("red"), 0.6), 2.0, 7.0)
	var ttex: Texture2D = _t("ship_turret", 0.6)
	draw_set_transform(c, hd + float(ship.get("aim", 0.0)) + PI / 2.0, Vector2.ONE)
	draw_texture_rect(ttex, Rect2(Vector2(-9, -19), Vector2(18, 30)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# clock face round our ship (12 = nose), on top so the numbers are always readable
	var cr: float = 74.0
	draw_arc(c, cr, 0.0, TAU, 64, Color(_ink, 0.25), 2.0, true)
	for h in 12:
		var a: float = hd + h * TAU / 12.0
		var p0: Vector2 = c + Vector2.from_angle(a) * (cr - 6.0)
		var p1: Vector2 = c + Vector2.from_angle(a) * (cr + (8.0 if h % 3 == 0 else 3.0))
		draw_line(p0, p1, Color(_ink, 0.6), 2.5 if h % 3 == 0 else 1.5, true)
		if h % 3 == 0:
			var lbl: String = str(12 if h == 0 else h)
			var lp: Vector2 = c + Vector2.from_angle(a) * (cr + 20.0)
			var ls: Vector2 = f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
			draw_string_outline(f, lp + Vector2(-ls.x / 2.0, 6), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, _halo)
			draw_string(f, lp + Vector2(-ls.x / 2.0, 6), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, _ink)
	# compass + scale
	_compass(Vector2(size.x - 54.0, 58.0))
	var bar_m: int = 100 if view_r < 600.0 else 200
	var bl: float = bar_m * k
	var bp: Vector2 = Vector2(18.0, size.y - 18.0)
	draw_line(bp, bp + Vector2(bl, 0), _ink, 4.0)
	draw_line(bp, bp + Vector2(0, -8), _ink, 3.0)
	draw_line(bp + Vector2(bl, 0), bp + Vector2(bl, -8), _ink, 3.0)
	draw_string(fb, bp + Vector2(bl + 8.0, 5.0), "%d m" % bar_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, _ink)
	var spd: String = "%d m/s" % int(float(ship.get("speed", 0.0)))
	draw_string(f, Vector2(18.0, size.y - 34.0), spd, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, _ink)

func _label(p: Vector2, text: String, col: Color) -> void:
	var f: Font = UIK.font("body")
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, _halo)
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)

func _dashed(a: Vector2, b: Vector2, col: Color, w: float, dash: float) -> void:
	var d: float = a.distance_to(b)
	if d < 1.0:
		return
	var dir: Vector2 = (b - a) / d
	var t: float = 0.0
	while t < d:
		draw_line(a + dir * t, a + dir * minf(t + dash, d), col, w, true)
		t += dash * 1.8

func _edge(c: Vector2, p: Vector2, r: Rect2) -> Vector2:
	var d: Vector2 = p - c
	var tx: float = (r.end.x - c.x) / d.x if d.x > 0.0 else ((r.position.x - c.x) / d.x if d.x < 0.0 else 1e9)
	var ty: float = (r.end.y - c.y) / d.y if d.y > 0.0 else ((r.position.y - c.y) / d.y if d.y < 0.0 else 1e9)
	return c + d * minf(tx, ty)

func _flag(p: Vector2) -> void:
	var bob: float = sin(Time.get_ticks_msec() * 0.006) * 3.0
	draw_line(p, p + Vector2(0, -44), _ink, 4.0, true)
	var fl: PackedVector2Array = PackedVector2Array([p + Vector2(0, -44), p + Vector2(30, -36 + bob), p + Vector2(0, -26)])
	draw_colored_polygon(fl, UIK.c("red"))
	fl.append(fl[0])
	draw_polyline(fl, _ink, 3.0, true)
	draw_circle(p, 5.0, _ink)

func _compass(c: Vector2) -> void:
	## an inked compass rose; the red point is north
	var s: float = 84.0
	if STYLE != "paper":
		draw_circle(c, s * 0.52, Color("#e9dcbb"))
		draw_arc(c, s * 0.52, 0.0, TAU, 40, K.pal("mustard"), 4.0, true)
	draw_texture_rect(_t("doodad_rose", 0.8), Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false)
	var f: Font = UIK.font("head")
	draw_string_outline(f, c + Vector2(-7, -s / 2.0 + 2.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, _halo)
	draw_string(f, c + Vector2(-7, -s / 2.0 + 2.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIK.c("red"))

func _has_route() -> bool:
	for st in v.get("steps", []):
		if bool(st.get("now", false)) and st.has("pos"):
			return true
	return false

func _route(to_s: Callable, r: Rect2, c: Vector2) -> void:
	## the mission as numbered flags along the way: done ones ticked, the one to do now big and red, the rest waiting
	var steps: Array = v.get("steps", [])
	var f: Font = UIK.font("head")
	var prev: Vector2 = c
	var tnow: float = Time.get_ticks_msec() / 1000.0
	var now_i: int = -1
	for i in steps.size():
		if bool(steps[i].get("now", false)):
			now_i = i
	for i in steps.size():
		var st: Dictionary = steps[i]
		if not st.has("pos"):
			continue
		var p: Vector2 = to_s.call(_vec(st.pos))
		var done: bool = bool(st.get("done", false))
		var now: bool = i == now_i
		if i > now_i and now_i >= 0:
			_dashed(prev, p, Color(_ink, 0.35), 2.5, 9.0)
		if i >= now_i:
			prev = p
		if not r.grow(-16.0).has_point(p):
			continue
		if done:
			# a finished step's flag shows its tick for a moment, then shrinks to a small dot on the trail
			if not _done_t.has(i):
				_done_t[i] = tnow
			var fade: float = clampf((tnow - float(_done_t[i]) - 1.5) / 2.0, 0.0, 1.0)
			if fade >= 1.0:
				draw_circle(p, 4.0, Color(_ink, 0.35))
				continue
			var a: float = 1.0 - fade * 0.8
			var rr: float = lerpf(14.0, 5.0, fade)
			draw_circle(p, rr + 2.5, Color(_ink, a))
			draw_circle(p, rr, Color(UIK.c("green"), a))
			if fade < 0.5:
				draw_polyline(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(-2, 6), p + Vector2(8, -6)]), Color(1, 1, 1, a), 3.5, true)
			continue
		var col: Color = UIK.c("red") if now else K.pal("cream")
		var rad: float = 17.0 if now else 14.0
		if now:
			draw_arc(p, rad + 9.0 + 3.0 * sin(tnow * 4.0), 0.0, TAU, 32, Color(UIK.c("red"), 0.45), 4.0, true)
		draw_circle(p, rad + 2.5, UIK.ink())
		draw_circle(p, rad, col)
		if true:
			var n: String = str(i + 1)
			var nw: float = f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(f, p + Vector2(-nw / 2.0, 8), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE if now else UIK.ink())
		if now or i == now_i + 1:
			var txt: String = str(st.text)
			if txt.length() > 34:
				txt = txt.left(33) + "…"
			_chip(p + Vector2(rad + 8.0, -13.0), txt.to_upper() if now else txt.to_upper(), K.pal("cream"), 18 if now else 14, 1.0 if now else 0.8)

func _chip(p: Vector2, text: String, bg: Color, sz: int = 15, alpha: float = 1.0) -> void:
	## a little inked label stuck on the chart; flips to the left of `p` if it would run off the edge
	var f: Font = UIK.font("head")
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 16.0
	var h: float = sz + 10.0
	var at: Vector2 = p
	if at.x + w > size.x - 8.0:
		at.x = p.x - w - 40.0
	at.x = clampf(at.x, 8.0, maxf(8.0, size.x - w - 8.0))
	at.y = clampf(at.y, 8.0, maxf(8.0, size.y - h - 8.0))
	var box: Rect2 = Rect2(at, Vector2(w, h))
	draw_rect(Rect2(box.position + Vector2(3, 3), box.size), Color(UIK.ink(), alpha))
	draw_rect(box, Color(bg, alpha))
	draw_rect(box, Color(UIK.ink(), alpha), false, 2.5)
	var fc: Color = UIK.text_on(bg)
	draw_string(f, at + Vector2(8, sz + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(fc, alpha))

func _stars(sp: Vector2, k: float, c: Vector2, stl: Dictionary) -> void:
	## stars fixed in the world (so they slide past as we fly), a few per 250 m square
	var cell: float = 250.0
	var half: Vector2 = size / (2.0 * k)
	var x0: int = int(floor((sp.x - half.x) / cell)) - 1
	var x1: int = int(floor((sp.x + half.x) / cell)) + 1
	var y0: int = int(floor((sp.y - half.y) / cell)) - 1
	var y1: int = int(floor((sp.y + half.y) / cell)) + 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var neb: bool = bool(stl.get("nebula", false))
	var links: bool = bool(stl.get("links", false))
	for gx in range(x0, x1 + 1):
		for gy in range(y0, y1 + 1):
			rng.seed = hash(Vector2i(gx, gy))
			if neb and rng.randf() < 0.18:
				var np: Vector2 = c + (Vector2((gx + rng.randf()) * cell, (gy + rng.randf()) * cell) - sp) * k
				var nc: Color = [K.pal("purple"), K.pal("teal"), K.pal("rose")][rng.randi() % 3]
				for ring in 12:
					draw_circle(np, (130.0 - ring * 10.0) * k * 2.0, Color(nc, 0.016))
			var prev: Vector2 = Vector2.INF
			for n in 6:
				var wp: Vector2 = Vector2((gx + rng.randf()) * cell, (gy + rng.randf()) * cell)
				var p: Vector2 = c + (wp - sp) * k
				var big_star: bool = rng.randf() < 0.15
				var tw: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 600.0 + n * 1.7 + gx)
				var col: Color = Color(_ink, (0.75 if big_star else 0.4) * (tw if big_star else 1.0))
				if big_star:
					draw_line(p - Vector2(4, 0), p + Vector2(4, 0), col, 1.5, true)
					draw_line(p - Vector2(0, 4), p + Vector2(0, 4), col, 1.5, true)
				draw_circle(p, 1.6 if big_star else 1.0, col)
				if links and big_star and prev != Vector2.INF and prev.distance_to(p) < cell * k * 0.9:
					_dashed(prev, p, Color(_ink, 0.18), 1.2, 4.0)
				if big_star:
					prev = p
