class_name Radar
extends Control
## Sensors' radar. Our ship is in the middle, nose up. Click a blip to select it; then hold SCAN.

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

func _process(dt: float) -> void:
	_sweep = wrapf(_sweep + dt * 2.2, 0.0, TAU)
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var best: int = -1
		var bd: float = 46.0
		for h in _hits:
			var d: float = (h[0] as Vector2).distance_to(e.position)
			if d < bd:
				bd = d
				best = int(h[1])
		if best >= 0:
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
	for k in [0.33, 0.66, 1.0]:
		draw_arc(c, inner * k * 0.96, 0.0, TAU, 64, Color(green, 0.35), 2.0, true)
	draw_line(c + Vector2(0, -inner), c + Vector2(0, inner), Color(green, 0.2), 1.5)
	draw_line(c + Vector2(-inner, 0), c + Vector2(inner, 0), Color(green, 0.2), 1.5)
	var f: Font = UIK.font("head")
	_hits.clear()
	if not ok:
		draw_string_outline(f, c + Vector2(-110, 10), "SENSORS BROKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, UIK.ink())
		draw_string(f, c + Vector2(-110, 10), "SENSORS BROKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIK.c("red"))
		# static
		for i in 60:
			var a: float = randf() * TAU
			draw_circle(c + Vector2.from_angle(a) * randf() * inner, 1.5, Color(green, 0.4))
	else:
		# sweep
		for i in 14:
			var a2: float = _sweep - i * 0.045
			draw_line(c, c + Vector2.from_angle(a2) * inner * 0.97, Color(green, 0.22 - i * 0.015), 3.0, true)
		var rng: float = float(view.get("range", 520.0))
		for b in view.get("blips", []):
			var p: Vector2 = c + Vector2(float(b.x), float(b.y)) / rng * inner * 0.96
			_hits.append([p, int(b.id)])
			var sel: bool = int(b.id) == selected
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
	# us, in the middle
	var tip: Vector2 = c + Vector2(0, -14)
	draw_colored_polygon(PackedVector2Array([tip, c + Vector2(10, 10), c + Vector2(-10, 10)]), UIK.c("orange"))
	draw_polyline(PackedVector2Array([tip, c + Vector2(10, 10), c + Vector2(-10, 10), tip]), UIK.ink(), 2.5, true)
	draw_texture_rect(_bezel, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
