class_name Scope
extends Control
## The gun scope: a narrow straw-view along the selected turret. Everything inside +/-14 degrees shows up.

const HALF_FOV: float = 14.0

var contacts: Array = []
var lock_id: int = -1
var title: String = "SCOPE"
var t: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(380, 380)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 8.0
	var ink: Color = K.pal("ink")
	var font: Font = get_theme_default_font()
	draw_circle(c, r + 4.0, ink)
	draw_circle(c, r, Color(0.09, 0.07, 0.18))
	# star specks that slide with the scope
	for i in 26:
		var a: float = float(i) * 2.399
		var p: Vector2 = c + Vector2(cos(a), sin(a * 1.7)) * r * (0.2 + 0.75 * fmod(float(i) * 0.37, 1.0))
		draw_circle(p, 1.4, Color(1, 1, 1, 0.5))
	# range rings and crosshair
	draw_arc(c, r * 0.5, 0, TAU, 40, Color(1, 1, 1, 0.15), 1.5)
	draw_arc(c, r * 0.25, 0, TAU, 40, Color(1, 1, 1, 0.15), 1.5)
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(K.pal("coral"), 0.55), 2.0)
	draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(K.pal("coral"), 0.55), 2.0)
	draw_circle(c, 6.0, Color(K.pal("coral"), 0.0))
	draw_arc(c, 10.0, 0, TAU, 20, K.pal("coral"), 2.0)
	for item in contacts:
		var off: float = float(item.off)
		var d: float = float(item.d)
		var x: float = c.x + (rad_to_deg(off) / HALF_FOV) * r
		var yj: float = sin(float(item.id) * 12.9) * r * 0.28
		var y: float = c.y + yj
		var ang_r: float = atan2(float(item.r), maxf(d, 1.0))
		var px: float = clampf(rad_to_deg(ang_r) / HALF_FOV * r, 5.0, r * 0.5)
		var scanned: bool = bool(item.scanned)
		var col: Color = Color(0.6, 0.6, 0.65)
		if scanned:
			col = K.pal("magenta") if str(item.get("fac", "")) == "heg" else (K.pal("mint") if str(item.get("fac", "")) == "free" else K.pal("butter"))
		draw_circle(Vector2(x, y), px, col)
		draw_arc(Vector2(x, y), px, 0, TAU, 20, ink, 2.0)
		if scanned and str(item.kind) == "bastion" and item.has("weak_off"):
			var wx: float = c.x + (rad_to_deg(float(item.weak_off)) / HALF_FOV) * r
			draw_circle(Vector2(wx, y + px * 0.2), maxf(4.0, px * 0.15), K.pal("coral"))
			draw_arc(Vector2(wx, y + px * 0.2), maxf(8.0, px * 0.3), 0, TAU, 16, K.pal("coral"), 2.0)
		var label: String = ("%s %dm" % [str(item.kind), int(d)]) if scanned else ("? %dm" % int(d))
		draw_string(font, Vector2(x - 50, y + px + 16.0), label, HORIZONTAL_ALIGNMENT_CENTER, 100, 13, Color(1, 1, 1, 0.9))
		if int(item.id) == lock_id:
			var s: float = px + 8.0 + sin(t * 8.0) * 2.0
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var corner: Vector2 = Vector2(x + sx * s, y + sy * s)
					draw_line(corner, corner - Vector2(sx * 10.0, 0.0), K.pal("butter"), 3.0)
					draw_line(corner, corner - Vector2(0.0, sy * 10.0), K.pal("butter"), 3.0)
	draw_string(font, Vector2(c.x - 80, c.y - r + 18.0), title, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(c.x - 100, c.y + r - 8.0), "±%d° view" % int(HALF_FOV), HORIZONTAL_ALIGNMENT_CENTER, 200, 13, Color(1, 1, 1, 0.5))
