class_name BridgeWindow
extends Control
## The Captain's bridge window: looking out of the front of the ship. About 110 degrees wide and far-sighted
## (1.3 km), but nothing to the sides or behind. Things further off sit nearer the horizon and look smaller.
## Along the bottom edge, a small close-range ring shows anything within bumping distance, all round.
## When the Tech pins something on the radar, a marker on the window's edge says where it is ("DRONE · 5 o'clock
## · 400m"): that's the only way the Captain knows about trouble outside the glass.

var v: Dictionary = {}
var _tex: Dictionary = {}
var _done_t: Dictionary = {}

const SPRITE: Dictionary = Chart.SPRITE
const SKY_TOP: Color = Color("#141024")
const SKY_LOW: Color = Color("#2b2140")
const HORIZON: float = 0.30      # where "very far away" sits, as a share of the height
const NEAR_Y: float = 0.86       # where something at the close ring sits

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

func _process(_dt: float) -> void:
	if not v.is_empty() and is_visible_in_tree():
		queue_redraw()

# ---------------------------------------------------------------- projection

func _half() -> float:
	return float(v.get("window", {}).get("half", deg_to_rad(55.0)))

func _near() -> float:
	return float(v.get("window", {}).get("near", 140.0))

func project(rel: float, d: float) -> Vector3:
	## window position (x, y) and size scale (z) of something at bearing `rel` from the nose, `d` metres away.
	## z < 0: outside the glass
	var half: float = _half()
	if absf(rel) > half + 0.02:
		return Vector3(0, 0, -1)
	var x: float = size.x / 2.0 + tan(rel) / tan(half) * size.x * 0.47
	var hz: float = size.y * HORIZON
	var y: float = hz + (size.y * NEAR_Y - hz) * clampf(_near() / maxf(d, 1.0), 0.0, 1.15)
	return Vector3(x, y, clampf(260.0 / maxf(d, 40.0), 0.12, 3.0))

func _rel_d(p: Vector2) -> Vector2:
	var ship: Dictionary = v.get("ship", {})
	var sp: Vector2 = _vec(ship.get("pos", [0, 0]))
	var hd: float = float(ship.get("heading", -PI / 2.0))
	return Vector2(K.wrap_pi((p - sp).angle() - hd), p.distance_to(sp))

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	# deep space, a little lighter near the horizon
	var hz: float = size.y * HORIZON
	draw_rect(r, SKY_TOP)
	for i in 10:
		var y0: float = hz - 80.0 + i * 28.0
		draw_rect(Rect2(0, y0, size.x, 30.0), Color(SKY_LOW, 0.12 + 0.05 * (5.0 - absf(i - 5.0))))
	if v.is_empty():
		return
	var ship: Dictionary = v.get("ship", {})
	var hd: float = float(ship.get("heading", -PI / 2.0))
	var tnow: float = Time.get_ticks_msec() / 1000.0
	_stars(hd)
	_dust()
	# a faint perspective floor of range lines, so distance reads at a glance
	var f: Font = UIK.font("head")
	for m in [250.0, 500.0, 1000.0]:
		var q: Vector3 = project(0.0, m)
		draw_line(Vector2(0, q.y), Vector2(size.x, q.y), Color("#a98fb8", 0.12), 1.5)
		draw_string(f, Vector2(10, q.y - 4), "%dm" % int(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a98fb8", 0.45))
	_heading_tape(hd)
	# everything out there, far things first
	var items: Array = []
	for e in v.get("ents", []):
		var rd: Vector2 = _rel_d(_vec(e.pos))
		items.append([rd.y, "ent", e, rd])
	for s in v.get("shots", []):
		var rd2: Vector2 = _rel_d(_vec(s.pos))
		items.append([rd2.y, "shot", s, rd2])
	var goal: Array = v.get("goal", [])
	if goal.size() == 2:
		var rd3: Vector2 = _rel_d(_vec(goal))
		items.append([rd3.y, "goal", {}, rd3])
	items.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var pinned: Dictionary = {}
	for pm in v.get("pins", []):
		pinned[int(pm.id)] = pm
	for it in items:
		var rd4: Vector2 = it[3]
		var q2: Vector3 = project(rd4.x, rd4.y)
		if q2.z < 0.0:
			continue
		var p: Vector2 = Vector2(q2.x, q2.y)
		match str(it[1]):
			"ent":
				_ent(it[2], p, q2.z, rd4.y, pinned.has(int(it[2].id)), tnow)
			"shot":
				_shot(it[2], p, q2.z)
			"goal":
				_flag(p, q2.z, rd4.y, pinned.has(-1))
	_fx()
	_near_ring(hd, tnow)
	_pins(tnow)
	_now_step()
	# the window frame: two struts and a sill, so it reads as glass you're looking through
	var frame: Color = Color("#0d0b12")
	draw_rect(Rect2(0, size.y - 10.0, size.x, 10.0), frame)
	for sx in [size.x * 0.0, size.x]:
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), frame, 14.0)
	var spd: String = "%d m/s" % int(float(ship.get("speed", 0.0)))
	var rr2: float = clampf(size.y * 0.13, 46.0, 80.0)
	var sp2: Vector2 = Vector2(rr2 * 2.0 + 58.0, size.y - rr2 - 30.0)
	draw_string_outline(f, sp2, spd, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, UIK.ink())
	draw_string(f, sp2, spd, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ecc983"))

func _ent(e: Dictionary, p: Vector2, z: float, d: float, pin: bool, tnow: float) -> void:
	var kind: String = str(e.kind)
	var tex: Texture2D = _t(SPRITE.get(kind, "obj_unknown"))
	var px: float = clampf(float(e.r) * 2.6 * z, 16.0, 260.0)
	if kind == "unknown":
		px = clampf(px, 22.0, 70.0)
	var asp: float = float(tex.get_height()) / float(tex.get_width())
	var sz: Vector2 = Vector2(px, px * asp)
	if float(e.get("charge", 0.0)) > 0.0:
		var pul: float = 0.5 + 0.5 * sin(tnow * 18.0)
		draw_circle(p, px * 0.8 + pul * 8.0, Color(UIK.c("red"), 0.35 + 0.3 * pul))
	if bool(e.hostile):
		draw_arc(p, px * 0.62, 0.0, TAU, 32, Color(UIK.c("red"), 0.7), 3.0, true)
	if pin:
		draw_arc(p, px * 0.62 + 9.0, 0.0, TAU, 32, Color(UIK.c("yellow"), 0.85), 3.0, true)
	var done: bool = kind == "ring" and str(e.note) == "done"
	var fade: float = 0.0
	if done:
		var key: String = "ring%d" % int(e.id)
		if not _done_t.has(key):
			_done_t[key] = tnow
		fade = clampf((tnow - float(_done_t[key]) - 1.5) / 2.0, 0.0, 1.0)
	var mod: Color = Color(1, 1, 1, lerpf(0.6, 0.15, fade)) if done else Color.WHITE
	if kind in Chart.ROTATES:
		# seen from behind us, a ship's nose turning towards us turns towards the bottom of the glass
		var hd: float = float(v.get("ship", {}).get("heading", 0.0))
		draw_set_transform(p, float(e.heading) - hd, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, mod)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, Rect2(p - sz / 2.0, sz), false, mod)
	if done and fade < 1.0:
		draw_texture_rect(Art.sized("icon_check", 26), Rect2(p - Vector2(13, 13), Vector2(26, 26)), false, Color(UIK.c("green"), 1.0 - fade))
	if kind == "cruiser" and bool(e.get("weak", false)):
		_label(p + Vector2(sz.x / 2.0 + 4.0, 0), "WEAK SPOT AT THE BACK", UIK.c("yellow"))
	if kind == "ring":
		return
	var nm: String = "?" if kind == "unknown" else str(e.name)
	var txt: String = "%s · %dm" % [nm, int(d)]
	if float(e.get("charge", 0.0)) > 0.0:
		txt = "%s · CHARGING!" % nm
	_label(p + Vector2(-sz.x / 2.0, sz.y / 2.0 + 16.0), txt, UIK.c("red") if bool(e.hostile) else Color("#ecc983"))

func _shot(s: Dictionary, p: Vector2, z: float) -> void:
	var rad: float = clampf(6.0 * z, 3.0, 14.0)
	if s.from == "them":
		draw_circle(p, rad + 2.0, UIK.ink())
		draw_circle(p, rad, UIK.c("red"))
		draw_circle(p, rad * 0.45, Color(1, 0.85, 0.8))
	elif s.kind == "torpedo":
		draw_circle(p, rad + 2.0, UIK.ink())
		draw_circle(p, rad, UIK.c("mustard"))
	else:
		draw_circle(p, rad * 0.8, UIK.c("teal").lightened(0.4))

func _flag(p: Vector2, z: float, d: float, pin: bool) -> void:
	var hgt: float = clampf(70.0 * z, 26.0, 90.0)
	var bob: float = sin(Time.get_ticks_msec() * 0.006) * 3.0
	draw_line(p, p + Vector2(0, -hgt), UIK.ink(), 4.0, true)
	var fl: PackedVector2Array = PackedVector2Array([p + Vector2(0, -hgt), p + Vector2(hgt * 0.65, -hgt * 0.82 + bob), p + Vector2(0, -hgt * 0.62)])
	draw_colored_polygon(fl, UIK.c("red"))
	fl.append(fl[0])
	draw_polyline(fl, UIK.ink(), 3.0, true)
	draw_circle(p, 5.0, UIK.ink())
	# the label goes up by the flag, clear of whatever the goal is (a skip, a ring) and its own name
	_label(p + Vector2(hgt * 0.65 + 8.0, -hgt * 0.7), "GOAL · %dm%s" % [int(d), " (Tech)" if pin else ""], UIK.c("red"))

func _fx() -> void:
	for fx in v.get("fx", []):
		var rd: Vector2 = _rel_d(Vector2(float(fx.x), float(fx.y)))
		var q: Vector3 = project(rd.x, rd.y)
		if q.z < 0.0:
			continue
		var p: Vector2 = Vector2(q.x, q.y)
		var age: float = float(v.get("_t", 0.0)) - float(fx.t)
		var fade: float = clampf(1.0 - age / 0.9, 0.0, 1.0)
		match str(fx.kind):
			"puff":
				var s3: float = clampf(float(fx.get("size", 20.0)) * 3.0 * q.z, 30.0, 200.0) * (0.7 + age)
				draw_texture_rect(_t("fx_puff"), Rect2(p - Vector2(s3, s3) / 2.0, Vector2(s3, s3)), false, Color(1, 1, 1, fade))
			"hit", "star":
				draw_texture_rect(_t("fx_star"), Rect2(p - Vector2(30, 30), Vector2(60, 60)), false, Color(1, 1, 1, fade))

func _near_ring(hd: float, tnow: float) -> void:
	## the close-range ring: a little top-down disc at the bottom of the glass, all round, for things about to bump us
	var ship: Dictionary = v.get("ship", {})
	var sp: Vector2 = _vec(ship.get("pos", [0, 0]))
	var rr: float = clampf(size.y * 0.13, 46.0, 80.0)
	var c: Vector2 = Vector2(rr + 34.0, size.y - rr - 30.0)
	var near: float = _near()
	draw_circle(c, rr + 4.0, UIK.ink())
	draw_circle(c, rr, Color("#1f3b2c", 0.92))
	draw_arc(c, rr * 0.5, 0.0, TAU, 32, Color("#9fe0a0", 0.25), 1.5, true)
	# the window's wedge, so the ring lines up with the glass
	var half: float = _half()
	draw_line(c, c + Vector2.from_angle(-PI / 2.0 - half) * rr, Color(UIK.c("yellow"), 0.35), 1.5, true)
	draw_line(c, c + Vector2.from_angle(-PI / 2.0 + half) * rr, Color(UIK.c("yellow"), 0.35), 1.5, true)
	var f: Font = UIK.font("head")
	for h in [0, 3, 6, 9]:
		var a: float = -PI / 2.0 + h * TAU / 12.0
		var lbl: String = str(12 if h == 0 else h)
		var lp: Vector2 = c + Vector2.from_angle(a) * (rr + 14.0) + Vector2(-6 if h != 0 else -9, 6)
		draw_string_outline(f, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, UIK.ink())
		draw_string(f, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9fe0a0"))
	var to_ring: Callable = func(p: Vector2) -> Vector2:
		return c + (p - sp).rotated(-hd - PI / 2.0) / near * rr
	# shield arc and the ship
	var shield: float = float(ship.get("shield", 0.0))
	if bool(ship.get("shield_ok", true)):
		var pts: PackedVector2Array = PackedVector2Array()
		for i in 13:
			pts.append(c + Vector2.from_angle(-PI / 2.0 + shield - 1.13 + 2.26 * i / 12.0) * 15.0)
		draw_polyline(pts, UIK.c("purple"), 4.0, true)
	var tip: Vector2 = c + Vector2(0, -9)
	draw_colored_polygon(PackedVector2Array([tip, c + Vector2(6, 6), c + Vector2(-6, 6)]), UIK.c("orange"))
	for e in v.get("ents", []):
		var ep: Vector2 = _vec(e.pos)
		if ep.distance_to(sp) > near * 1.05 or str(e.kind) == "ring":
			continue
		var q: Vector2 = to_ring.call(ep)
		var col: Color = UIK.c("red") if bool(e.hostile) else Color("#ecc983")
		if float(e.get("charge", 0.0)) > 0.0:
			draw_circle(q, 9.0 + 3.0 * sin(tnow * 18.0), Color(UIK.c("red"), 0.4))
		draw_circle(q, 6.0, UIK.ink())
		draw_circle(q, 4.5, col)
	for s in v.get("shots", []):
		if s.from != "them":
			continue
		var p2: Vector2 = _vec(s.pos)
		if p2.distance_to(sp) <= near * 1.05:
			draw_circle(to_ring.call(p2), 3.5, UIK.c("red"))
	draw_string_outline(f, c + Vector2(rr + 12.0, rr - 2.0), "CLOSE %dm" % int(near), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, UIK.ink())
	draw_string(f, c + Vector2(rr + 12.0, rr - 2.0), "CLOSE %dm" % int(near), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9fe0a0", 0.85))

func _pins(tnow: float) -> void:
	## what the Tech pointed out: anything outside the glass gets a marker on the nearest edge
	var half: float = _half()
	for pm in v.get("pins", []):
		if bool(pm.get("seen", false)):
			continue
		var rel: float = float(pm.get("rel", 0.0))
		var d: float = float(pm.get("dist", 0.0))
		var hz: float = size.y * HORIZON
		var at: Vector2
		var arrow: Vector2
		if absf(rel) <= half:
			# ahead but too far to make out: on the horizon
			at = Vector2(project(rel, 2000.0).x, hz - 30.0)
			arrow = Vector2(0, -1)
		else:
			var side: float = signf(rel)
			var behind: float = clampf((absf(rel) - half) / (PI - half), 0.0, 1.0)
			at = Vector2(size.x / 2.0 + side * (size.x / 2.0 - 30.0), lerpf(hz, size.y * 0.78, behind))
			arrow = Vector2(side, behind * 0.9).normalized()
		var col: Color = UIK.c("red") if bool(pm.get("hostile", false)) else UIK.c("yellow")
		if str(pm.get("kind", "")) == "goal":
			col = UIK.c("yellow")
		var flash: bool = float(pm.get("charge", 0.0)) > 0.0
		var nm: String = str(pm.get("name", "?"))
		if nm == "Unknown contact":
			nm = "Something"
		var txt: String = "%s · %d o'clock · %dm%s" % [nm.to_upper(), K.clock(rel), int(d), " · CHARGING!" if flash else ""]
		# the arrow on the edge
		var tipp: Vector2 = at + arrow * 22.0
		draw_colored_polygon(PackedVector2Array([tipp, at + arrow.orthogonal() * 14.0, at - arrow.orthogonal() * 14.0]), UIK.ink())
		draw_colored_polygon(PackedVector2Array([tipp - arrow * 3.0, at + arrow.orthogonal() * 10.0, at - arrow.orthogonal() * 10.0]), col)
		# the tag, on the inside of the arrow
		var fs: int = 17
		var w: float = UIK.font("head").get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
		var bx: float = at.x - w - 18.0 if arrow.x > 0.1 else (at.x + 18.0 if arrow.x < -0.1 else at.x - w / 2.0)
		var by: float = at.y - 14.0 if absf(arrow.x) > 0.1 else at.y + 22.0
		var alpha: float = clampf(float(pm.get("left", 5.0)) / 3.0, 0.3, 1.0)
		if flash and fmod(tnow, 0.5) < 0.25:
			alpha = 1.0
		_tag(Vector2(bx, by), txt, col, fs, alpha)

func _now_step() -> void:
	for st in v.get("steps", []):
		if bool(st.get("now", false)):
			var txt: String = "NOW: " + str(st.text).to_upper()
			if txt.length() > 44:
				txt = txt.left(43) + "…"
			var w: float = UIK.font("head").get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 16.0
			_tag(Vector2((size.x - w) / 2.0, size.y - 52.0), txt, K.pal("cream"), 17, 0.92)
			return

func _heading_tape(hd: float) -> void:
	## compass bearings marked along the horizon: which way is straight ahead
	var f: Font = UIK.font("head")
	var half: float = _half()
	var hz: float = size.y * HORIZON
	draw_line(Vector2(0, hz), Vector2(size.x, hz), Color("#ecc983", 0.25), 1.5)
	var names: Dictionary = {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
	for deg in range(0, 360, 15):
		var rel: float = K.wrap_pi(deg_to_rad(float(deg)) - (hd + PI / 2.0))
		if absf(rel) > half:
			continue
		var x: float = size.x / 2.0 + tan(rel) / tan(half) * size.x * 0.47
		var major: bool = deg % 45 == 0
		draw_line(Vector2(x, hz - (8.0 if major else 4.0)), Vector2(x, hz), Color("#ecc983", 0.6), 2.0)
		if major:
			var lbl: String = str(names[deg])
			var lw: float = f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(f, Vector2(x - lw / 2.0, hz - 12.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UIK.c("red") if deg == 0 else Color("#ecc983"), 0.8))
	# the nose: a little caret dead ahead
	draw_colored_polygon(PackedVector2Array([Vector2(size.x / 2.0 - 7, hz + 10), Vector2(size.x / 2.0 + 7, hz + 10), Vector2(size.x / 2.0, hz + 2)]), UIK.c("yellow"))

func _stars(hd: float) -> void:
	## distant stars, fixed to the sky: they slide sideways as we turn
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var half: float = _half()
	var hz: float = size.y * HORIZON
	for i in 260:
		var a: float = rng.randf() * TAU
		var el: float = rng.randf_range(-0.9, 1.0)
		var big: bool = rng.randf() < 0.12
		var rel: float = K.wrap_pi(a - hd)
		if absf(rel) > half:
			continue
		var x: float = size.x / 2.0 + tan(rel) / tan(half) * size.x * 0.47
		var y: float = hz - el * hz * 0.95
		if el < 0.0:
			y = hz - el * (size.y - hz)
		var tw: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 600.0 + i * 1.7)
		var col: Color = Color("#f2e2c0", (0.8 * tw) if big else 0.35)
		if big:
			draw_line(Vector2(x - 4, y), Vector2(x + 4, y), col, 1.5, true)
			draw_line(Vector2(x, y - 4), Vector2(x, y + 4), col, 1.5, true)
		draw_circle(Vector2(x, y), 1.6 if big else 1.0, col)

func _dust() -> void:
	## space dust fixed in the world, close by: it streams past as we fly, so speed and turning can be felt
	var ship: Dictionary = v.get("ship", {})
	var sp: Vector2 = _vec(ship.get("pos", [0, 0]))
	var cell: float = 90.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var reach: int = 5
	var cx: int = int(floor(sp.x / cell))
	var cy: int = int(floor(sp.y / cell))
	for gx in range(cx - reach, cx + reach + 1):
		for gy in range(cy - reach, cy + reach + 1):
			rng.seed = hash(Vector2i(gx, gy)) + 7
			var wp: Vector2 = Vector2((gx + rng.randf()) * cell, (gy + rng.randf()) * cell)
			var ht: float = rng.randf_range(-1.0, 1.0)
			var rd: Vector2 = _rel_d(wp)
			if rd.y < 30.0:
				continue
			var q: Vector3 = project(rd.x, rd.y)
			if q.z < 0.0:
				continue
			# dust floats above and below us, not on a floor: spread it up and down the glass
			var hz: float = size.y * HORIZON
			var y: float = hz + (q.y - hz) * ht * 1.6
			var a: float = clampf(q.z * 0.5, 0.05, 0.5)
			draw_circle(Vector2(q.x, y), clampf(q.z * 1.2, 0.8, 2.6), Color("#c9b8e8", a))

func _label(p: Vector2, text: String, col: Color) -> void:
	var f: Font = UIK.font("body")
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, UIK.ink())
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)

func _tag(p: Vector2, text: String, bg: Color, sz: int = 15, alpha: float = 1.0) -> void:
	var f: Font = UIK.font("head")
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 16.0
	var h: float = sz + 10.0
	var at: Vector2 = Vector2(clampf(p.x, 8.0, maxf(8.0, size.x - w - 8.0)), clampf(p.y, 8.0, maxf(8.0, size.y - h - 8.0)))
	var box: Rect2 = Rect2(at, Vector2(w, h))
	draw_rect(Rect2(box.position + Vector2(3, 3), box.size), Color(UIK.ink(), alpha))
	draw_rect(box, Color(bg, alpha))
	draw_rect(box, Color(UIK.ink(), alpha), false, 2.5)
	draw_string(f, at + Vector2(8, sz + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(UIK.text_on(bg), alpha))
