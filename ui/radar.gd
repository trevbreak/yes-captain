class_name Radar
extends Control
## Top-down radar, north up, ship at the centre. Click a contact to select it.

signal picked(id: int)

var contacts: Array = []
var incoming: Array = []
var tele: Array = []
var rings: Array = []
var heading: float = -PI / 2.0
var view_ang: float = 0.0
var range_m: float = 500.0
var mirror: bool = false
var ship_pos: Vector2 = Vector2.ZERO
var selected: int = -1
var locked: int = -1
var ping_t: float = 0.0
var t: float = 0.0
var dock: Dictionary = {}

func _init() -> void:
	custom_minimum_size = Vector2(430, 430)
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	clip_contents = true

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _scale() -> float:
	return (minf(size.x, size.y) * 0.5 - 10.0) / maxf(50.0, range_m)

func _to_screen(rel: Vector2) -> Vector2:
	var c: Vector2 = size * 0.5
	var p: Vector2 = rel * _scale()
	if mirror:
		p.x = -p.x
	return c + p

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var best: int = -1
		var bd: float = 22.0
		for ct in contacts:
			var sp: Vector2 = _to_screen(ct.p)
			var d: float = sp.distance_to(ev.position)
			if d < bd:
				bd = d
				best = int(ct.id)
		selected = best
		picked.emit(best)

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var R: float = minf(size.x, size.y) * 0.5 - 6.0
	var ink: Color = K.pal("ink")
	var font: Font = get_theme_default_font()
	draw_circle(c, R + 4.0, ink)
	draw_circle(c, R, Color(0.05, 0.16, 0.14))
	for i in range(1, 5):
		draw_arc(c, R * float(i) / 4.0, 0, TAU, 48, Color(K.pal("mint"), 0.22), 1.5)
		draw_string(font, c + Vector2(4, -R * float(i) / 4.0 + 14), "%dm" % int(range_m * float(i) / 4.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(K.pal("mint"), 0.6))
	draw_line(c - Vector2(R, 0), c + Vector2(R, 0), Color(K.pal("mint"), 0.18), 1.0)
	draw_line(c - Vector2(0, R), c + Vector2(0, R), Color(K.pal("mint"), 0.18), 1.0)
	draw_string(font, Vector2(c.x - 6, c.y - R + 14), "N", HORIZONTAL_ALIGNMENT_CENTER, 12, 14, K.pal("mint"))
	# sweep
	var sw: float = fmod(t * 1.6, TAU)
	draw_line(c, c + Vector2.from_angle(sw) * R, Color(K.pal("mint"), 0.35), 3.0)
	# view direction wedge
	var va: float = (PI - view_ang) if mirror else view_ang
	var wedge: PackedVector2Array = PackedVector2Array([c, c + Vector2.from_angle(va - 0.55) * R * 0.5, c + Vector2.from_angle(va + 0.55) * R * 0.5])
	draw_colored_polygon(wedge, Color(K.pal("butter"), 0.10))
	# patrol / scan rings
	for rg in rings:
		var rel: Vector2 = (rg.pos as Vector2) - ship_pos
		draw_arc(_to_screen(rel), float(rg.r) * _scale(), 0, TAU, 40, Color(K.pal("coral"), 0.6), 2.0)
	# dock marker
	if not dock.is_empty():
		var dp: Vector2 = _to_screen((dock.port as Vector2) - ship_pos)
		draw_circle(dp, 6.0, K.pal("butter"))
		draw_arc(dp, 10.0 + sin(t * 6.0) * 2.0, 0, TAU, 16, K.pal("butter"), 2.0)
	# telegraphs
	for tl in tele:
		var tp: Vector2 = _to_screen(tl.p)
		draw_line(tp, c, Color(K.pal("coral"), 0.5 + 0.4 * sin(t * 14.0)), 4.0)
		draw_string(font, tp + Vector2(10, 0), "CHARGING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, K.pal("coral"))
	# contacts
	for ct in contacts:
		var sp: Vector2 = _to_screen(ct.p)
		if sp.distance_to(c) > R:
			continue
		var kind: String = str(ct.kind)
		var col: Color = Color(0.75, 0.75, 0.8)
		if bool(ct.scanned):
			var fac: String = str(ct.get("fac", "neu"))
			col = K.pal("magenta") if fac == "heg" else (K.pal("mint") if fac == "free" else K.pal("butter"))
		var rr: float = clampf(float(ct.r) * _scale(), 4.0, 40.0)
		match kind:
			"mine":
				draw_line(sp + Vector2(-5, -5), sp + Vector2(5, 5), K.pal("coral"), 3.0)
				draw_line(sp + Vector2(-5, 5), sp + Vector2(5, -5), K.pal("coral"), 3.0)
			"waypoint":
				draw_arc(sp, rr, 0, TAU, 24, K.pal("green"), 3.0)
				draw_string(font, sp + Vector2(rr + 4, 4), "WAYPOINT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, K.pal("green"))
			"asteroid":
				draw_circle(sp, rr, K.pal("rock"))
			_:
				draw_circle(sp, rr, col)
				draw_arc(sp, rr, 0, TAU, 20, ink, 2.0)
				if kind != "?" and kind != "skip" and rr < 30.0:
					pass
		if bool(ct.scanned) and kind != "waypoint":
			draw_string(font, sp + Vector2(rr + 3, 4), str(ct.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
		elif kind == "?":
			draw_string(font, sp + Vector2(rr + 3, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))
		if bool(ct.scanned) and ct.has("weak"):
			draw_circle(_to_screen(ct.weak), 4.0, K.pal("coral"))
		if int(ct.id) == selected:
			draw_arc(sp, rr + 7.0, 0, TAU, 20, K.pal("butter"), 3.0)
		if int(ct.id) == locked:
			var s: float = rr + 12.0
			draw_rect(Rect2(sp - Vector2(s, s), Vector2(s, s) * 2.0), K.pal("coral"), false, 2.0)
	for ic in incoming:
		var ip: Vector2 = _to_screen(ic.p)
		var vel: Vector2 = ic.v
		var tail: Vector2 = ip - (Vector2(-vel.x if mirror else vel.x, vel.y)).normalized() * (14.0 if bool(ic.big) else 9.0)
		draw_line(tail, ip, K.pal("coral"), 4.0 if bool(ic.big) else 2.0)
		draw_circle(ip, 3.0, K.pal("butter"))
	# the ship, pointing along its heading
	var ha: float = heading * (-1.0 if mirror else 1.0) if false else heading
	if mirror:
		ha = PI - heading
	var tip: Vector2 = c + Vector2.from_angle(ha) * 13.0
	var l: Vector2 = c + Vector2.from_angle(ha + 2.5) * 10.0
	var rr2: Vector2 = c + Vector2.from_angle(ha - 2.5) * 10.0
	draw_colored_polygon(PackedVector2Array([tip, l, rr2]), K.pal("butter"))
	draw_polyline(PackedVector2Array([tip, l, rr2, tip]), ink, 2.0)
	if ping_t > 0.0:
		var pr: float = R * (1.0 - ping_t / 6.0)
		draw_arc(c, pr, 0, TAU, 60, Color(1, 1, 1, ping_t / 6.0), 3.0)
	if mirror:
		draw_string(font, Vector2(8, 22), "DISPLAY MIRRORED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, K.pal("coral"))
