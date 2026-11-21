class_name Radar
extends Control
## Sensors' radar. Our ship is in the middle, nose up. Click a blip to select it; then hold SCAN.
## It sees all round and far. The pale wedge is what the Captain can see out of the bridge window.
## Distances are squashed (near things get more room), so the rings read 25% / 50% / 100% of range.

signal picked(id: int)

var view: Dictionary = {}
var selected: int = -1
var _bezel: Texture2D
var _tex: Dictionary = {}
var _sweep: float = 0.0
var _hits: Array = []        # [Vector2 local, id]

const ICON: Dictionary = {
	"target": "obj_target", "buoy": "obj_buoy", "drone": "obj_drone", "grabber": "obj_grabber", "mine": "obj_mine",
	"cruiser": "obj_cruiser", "patrol": "obj_patrol", "rock": "obj_rock", "skip": "obj_skip", "pod": "obj_pod",
	"customs": "obj_customs", "haven": "obj_haven", "diner": "obj_diner", "junk": "obj_junk",
}

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(400, 400)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bezel = Art.tex("prop_radar", 1.4)

func _t(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = Art.tex(n, 0.6)
	return _tex[n]

func at(c: Vector2, inner: float, x: float, y: float) -> Vector2:
	## radar position of a point (ship-up frame, metres): square-root squash so close contacts aren't a clump
	var rng: float = float(view.get("range", 1250.0))
	var v: Vector2 = Vector2(x, y)
	var d: float = v.length()
	if d < 0.01:
		return c
	return c + v / d * sqrt(clampf(d / rng, 0.0, 1.0)) * inner * 0.96

func _process(dt: float) -> void:
	_sweep = wrapf(_sweep + dt * 2.2, 0.0, TAU)
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if Pointer.swallow(e):
		accept_event()
		return
	if Pointer.down(e) != Pointer.NONE:
		var best: int = -2
		var bd: float = 46.0
		for h in _hits:
			var d: float = (h[0] as Vector2).distance_to(e.position)
			if d < bd:
				bd = d
				best = int(h[1])
		if best != -2:
			picked.emit(best)
			UIK.sfx("blip")
		accept_event()

func _draw() -> void:
	var r: float = minf(size.x, size.y) / 2.0
	var c: Vector2 = size / 2.0
	var inner: float = r * 0.8
	var green: Color = Color("#9fe0a0")
	draw_circle(c, inner, Color("#1f3b2c"))
	var ok: bool = bool(view.get("ok", true))
	for k in [0.25, 0.5, 1.0]:
		draw_arc(c, inner * sqrt(k) * 0.96, 0.0, TAU, 64, Color(green, 0.35), 2.0, true)
	draw_line(c + Vector2(0, -inner), c + Vector2(0, inner), Color(green, 0.2), 1.5)
	draw_line(c + Vector2(-inner, 0), c + Vector2(inner, 0), Color(green, 0.2), 1.5)
	var f: Font = UIK.font("head")
	_hits.clear()
	if not ok:
		draw_string_outline(f, c + Vector2(-110, -50), "SENSORS BROKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, UIK.ink())
		draw_string(f, c + Vector2(-110, -50), "SENSORS BROKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIK.c("red"))
		# static
		for i in 60:
			var a: float = randf() * TAU
			draw_circle(c + Vector2.from_angle(a) * randf() * inner, 1.5, Color(green, 0.4))
	else:
		# sweep
		for i in 14:
			var a2: float = _sweep - i * 0.045
			draw_line(c, c + Vector2.from_angle(a2) * inner * 0.97, Color(green, 0.22 - i * 0.015), 3.0, true)
		var rng: float = float(view.get("range", 1250.0))
		# what the Captain can see: the window wedge ahead
		var half: float = float(view.get("window", 0.0))
		if half > 0.0:
			var wr: float = sqrt(clampf(float(view.get("window_range", rng)) / rng, 0.0, 1.0)) * inner * 0.96
			var wedge: PackedVector2Array = [c]
			for i in 17:
				wedge.append(c + Vector2.from_angle(-PI / 2.0 - half + half * 2.0 * i / 16.0) * wr)
			draw_colored_polygon(wedge, Color(UIK.c("yellow"), 0.09))
			draw_polyline(wedge + PackedVector2Array([c]), Color(UIK.c("yellow"), 0.35), 2.0, true)
			draw_string(f, c + Vector2(-46, -wr * 0.55), "CAPTAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UIK.c("yellow"), 0.55))
		for k2 in [[0.25, "%d" % int(rng * 0.25)], [1.0, "%dm" % int(rng)]]:
			draw_string(f, c + Vector2(4, -inner * sqrt(float(k2[0])) * 0.96 + 16), str(k2[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(green, 0.55))
		# enemy shots in flight
		for sp in view.get("shots", []):
			var q: Vector2 = at(c, inner, float(sp[0]), float(sp[1]))
			draw_circle(q, 4.5, UIK.ink())
			draw_circle(q, 3.0, UIK.c("red"))
		var pins: Array = view.get("pins", [])
		for b in view.get("blips", []):
			var p: Vector2 = at(c, inner, float(b.x), float(b.y))
			_hits.append([p, int(b.id)])
			var sel: bool = int(b.id) == selected
			if bool(b.get("charge", false)):
				var pulse2: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
				draw_circle(p, 24.0 + pulse2 * 6.0, Color(UIK.c("red"), 0.25 + 0.3 * pulse2))
			if int(b.id) in pins:
				draw_arc(p, 31.0, 0.0, TAU, 24, Color(UIK.c("yellow"), 0.8), 3.0, true)
				draw_string_outline(f, p + Vector2(-14, -34), "PIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, UIK.ink())
				draw_string(f, p + Vector2(-14, -34), "PIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIK.c("yellow"))
			if bool(b.scanned) and ICON.has(str(b.kind)):
				var tx: Texture2D = _t(ICON[str(b.kind)])
				var s: float = 34.0 if str(b.kind) not in ["cruiser", "customs", "haven", "diner"] else 54.0
				var asp: float = float(tx.get_height()) / float(tx.get_width())
				draw_circle(p, s * 0.62, Color(UIK.c("red") if bool(b.hostile) else green, 0.35))
				draw_texture_rect(tx, Rect2(p - Vector2(s, s * asp) / 2.0, Vector2(s, s * asp)), false)
			else:
				var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006 + float(b.id))
				draw_circle(p, 10.0, UIK.ink())
				draw_circle(p, 7.0, Color(green, 0.6 + 0.4 * pulse))
				draw_string(f, p + Vector2(-5, -12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, green)
			if sel:
				draw_arc(p, 26.0, 0.0, TAU, 32, UIK.c("yellow"), 4.0, true)
				var nm: String = str(b.name) if bool(b.scanned) else "Unknown"
				draw_string_outline(f, p + Vector2(28, 6), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, UIK.ink())
				draw_string(f, p + Vector2(28, 6), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UIK.c("yellow"))
		# the goal
		var gl: Array = view.get("goal", [])
		if gl.size() == 2:
			var gp: Vector2 = at(c, inner, float(gl[0]), float(gl[1]))
			_hits.append([gp, -1])
			var gpin: bool = -1 in pins
			draw_circle(gp, 13.0, UIK.ink())
			draw_circle(gp, 10.0, UIK.c("yellow"))
			draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -6), gp + Vector2(6, 0), gp + Vector2(0, 6), gp + Vector2(-6, 0)]), UIK.ink())
			draw_string_outline(f, gp + Vector2(16, 6), "GOAL" + (" (shown)" if gpin else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, UIK.ink())
			draw_string(f, gp + Vector2(16, 6), "GOAL" + (" (shown)" if gpin else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIK.c("yellow"))
	# us, in the middle
	var tip: Vector2 = c + Vector2(0, -14)
	draw_colored_polygon(PackedVector2Array([tip, c + Vector2(10, 10), c + Vector2(-10, 10)]), UIK.c("orange"))
	draw_polyline(PackedVector2Array([tip, c + Vector2(10, 10), c + Vector2(-10, 10), tip]), UIK.ink(), 2.5, true)
	draw_texture_rect(_bezel, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
