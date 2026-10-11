class_name Chart
extends Control
## The captain's chart: a top-down, north-up paper chart centred on our ship. It shows the goal, every contact
## (a "?" until Sensors scans it), incoming shots, the shield arc, the turret, and a clock face round our ship
## so the captain can call "incoming at 4 o'clock!".

var v: Dictionary = {}
var view_r: float = 520.0
var _tex: Dictionary = {}
var _seen_fx: Dictionary = {}

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
	draw_rect(r, Color("#e9dcbb"))
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
	var step: float = 100.0 * k
	var gcol: Color = Color(UIK.c("blue"), 0.22)
	var ox: float = fposmod(-sp.x * k + c.x, step)
	var oy: float = fposmod(-sp.y * k + c.y, step)
	var x: float = ox
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), gcol, 1.5)
		x += step
	var y: float = oy
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), gcol, 1.5)
		y += step
	var to_s: Callable = func(p: Vector2) -> Vector2: return c + (p - sp) * k
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
		if inside:
			_flag(gp)
		else:
			var dir: Vector2 = (gp - c).normalized()
			draw_colored_polygon(PackedVector2Array([gpe + dir * 18.0, gpe + dir.orthogonal() * 12.0, gpe - dir.orthogonal() * 12.0]), UIK.c("red"))
			var dist: String = "%dm" % int(_vec(goal).distance_to(sp))
			draw_string_outline(f, gpe - dir * 30.0 + Vector2(-20, 6), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, UIK.c("cream"))
			draw_string(f, gpe - dir * 30.0 + Vector2(-20, 6), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIK.c("red"))
	# clock face round our ship (12 = nose)
	var cr: float = 74.0
	draw_arc(c, cr, 0.0, TAU, 64, Color(UIK.ink(), 0.25), 2.0, true)
	for h in 12:
		var a: float = hd + h * TAU / 12.0
		var p0: Vector2 = c + Vector2.from_angle(a) * (cr - 6.0)
		var p1: Vector2 = c + Vector2.from_angle(a) * (cr + (8.0 if h % 3 == 0 else 3.0))
		draw_line(p0, p1, Color(UIK.ink(), 0.6), 2.5 if h % 3 == 0 else 1.5, true)
		if h % 3 == 0:
			var lbl: String = str(12 if h == 0 else h)
			var lp: Vector2 = c + Vector2.from_angle(a) * (cr + 20.0)
			var ls: Vector2 = f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
			draw_string_outline(f, lp + Vector2(-ls.x / 2.0, 6), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color("#e9dcbb"))
			draw_string(f, lp + Vector2(-ls.x / 2.0, 6), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UIK.ink())
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
		var mod: Color = Color(1, 1, 1, 0.45) if (kind == "ring" and str(e.note) == "done") else Color.WHITE
		if kind in ROTATES:
			draw_set_transform(p, float(e.heading) + PI / 2.0, Vector2.ONE)
			draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, mod)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(tex, Rect2(p - sz / 2.0, sz), false, mod)
		if kind == "ring" and str(e.note) == "done":
			draw_string(f, p + Vector2(-9, 9), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIK.c("green"))
		if bool(e.get("thrown", false)):
			var vdir: Vector2 = (c - p).normalized()
			_dashed(p, p + vdir * 46.0, UIK.c("red"), 3.0, 8.0)
		if kind == "cruiser" and bool(e.get("weak", false)):
			var back: Vector2 = p - Vector2.from_angle(float(e.heading)) * sz.y * 0.42
			draw_circle(back, 12.0 + 3.0 * sin(tnow * 6.0), Color(UIK.c("yellow"), 0.8))
			draw_arc(back, 15.0, 0.0, TAU, 24, UIK.ink(), 2.5, true)
			_label(back + Vector2(16, 4), "WEAK SPOT", UIK.c("red"))
		if kind != "ring":
			var nm: String = str(e.name) if kind != "unknown" else "?"
			if kind == "unknown":
				pass
			elif kind not in ["junk", "rock"] or not bool(e.get("thrown", false)):
				_label(p + Vector2(-sz.x / 2.0, sz.y / 2.0 + 15.0), nm, UIK.c("red") if bool(e.hostile) else UIK.ink())
	# shots
	for s in v.get("shots", []):
		var p2: Vector2 = to_s.call(_vec(s.pos))
		if not r.has_point(p2):
			continue
		if s.from == "them":
			var back2: Vector2 = p2 - Vector2.from_angle(float(s.dir)) * 14.0
			draw_line(back2, p2, Color(UIK.c("red"), 0.5), 5.0, true)
			draw_circle(p2, 7.0, UIK.ink())
			draw_circle(p2, 5.0, UIK.c("red"))
		elif s.kind == "torpedo":
			var t1: Vector2 = p2 - Vector2.from_angle(float(s.dir)) * 12.0
			draw_line(t1, p2, UIK.ink(), 7.0, true)
			draw_line(t1, p2, UIK.c("mustard"), 4.0, true)
		else:
			draw_circle(p2, 3.5, UIK.ink())
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
	# compass + scale
	_compass(Vector2(size.x - 44.0, 46.0))
	var bar_m: int = 100 if view_r < 600.0 else 200
	var bl: float = bar_m * k
	var bp: Vector2 = Vector2(18.0, size.y - 18.0)
	draw_line(bp, bp + Vector2(bl, 0), UIK.ink(), 4.0)
	draw_line(bp, bp + Vector2(0, -8), UIK.ink(), 3.0)
	draw_line(bp + Vector2(bl, 0), bp + Vector2(bl, -8), UIK.ink(), 3.0)
	draw_string(fb, bp + Vector2(bl + 8.0, 5.0), "%d m" % bar_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIK.ink())
	var spd: String = "%d m/s" % int(float(ship.get("speed", 0.0)))
	draw_string(f, Vector2(18.0, size.y - 34.0), spd, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIK.ink())

func _label(p: Vector2, text: String, col: Color) -> void:
	var f: Font = UIK.font("body")
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color("#e9dcbb"))
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
	draw_line(p, p + Vector2(0, -44), UIK.ink(), 4.0, true)
	var fl: PackedVector2Array = PackedVector2Array([p + Vector2(0, -44), p + Vector2(30, -36 + bob), p + Vector2(0, -26)])
	draw_colored_polygon(fl, UIK.c("red"))
	fl.append(fl[0])
	draw_polyline(fl, UIK.ink(), 3.0, true)
	draw_circle(p, 5.0, UIK.ink())

func _compass(c: Vector2) -> void:
	draw_circle(c, 24.0, Color(UIK.c("cream"), 0.9))
	draw_arc(c, 24.0, 0.0, TAU, 32, UIK.ink(), 2.5, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(7, 2), c + Vector2(-7, 2)]), UIK.c("red"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 20), c + Vector2(7, -2), c + Vector2(-7, -2)]), UIK.ink())
	draw_string(UIK.font("head"), c + Vector2(-7, -26), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIK.ink())
