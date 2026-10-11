class_name Compass
extends Control
## Rotating compass ring. The ship's heading is fixed at the top.

var heading: float = -PI / 2.0
var angvel: float = 0.0
var wp_bearing: float = 999.0
var drift: float = 0.0
var shown_heading: float = -PI / 2.0
var accent: Color = Color.WHITE

func _init() -> void:
	custom_minimum_size = Vector2(300, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	shown_heading = lerp_angle(shown_heading, heading, 1.0 - exp(-14.0 * delta))
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 8.0
	var ink: Color = K.pal("ink")
	var fh: Font = UIK.font_head()
	draw_circle(c + Vector2(0, 4), r + 4.0, Color(0.06, 0.03, 0.18, 0.2))
	draw_circle(c, r + 4.0, K.pal("well").darkened(0.08))
	draw_circle(c, r, K.pal("card"))
	draw_circle(c, r * 0.6, K.pal("well"))
	var hd: float = fposmod(rad_to_deg(shown_heading) + 90.0, 360.0)
	for d in range(0, 360, 10):
		var a: float = deg_to_rad(float(d) - hd - 90.0)
		var major: bool = d % 30 == 0
		draw_line(c + Vector2.from_angle(a) * (r - 4.0), c + Vector2.from_angle(a) * (r - (16.0 if major else 9.0)), Color(ink, 0.7 if major else 0.35), 3.0 if major else 2.0, true)
		if major:
			var lbl: String = {0: "N", 90: "E", 180: "S", 270: "W"}.get(d, str(d))
			var tp: Vector2 = c + Vector2.from_angle(a) * (r - 32.0)
			var col: Color = K.pal("red") if d == 0 else (ink if d % 90 == 0 else K.pal("ink_soft"))
			draw_string(fh, tp - Vector2(20, -6), lbl, HORIZONTAL_ALIGNMENT_CENTER, 40, 18 if d % 90 == 0 else 14, col)
	if wp_bearing < 900.0:
		var wa: float = wp_bearing - PI / 2.0
		var tip: Vector2 = c + Vector2.from_angle(wa) * (r - 2.0)
		var l1: Vector2 = c + Vector2.from_angle(wa + 0.09) * (r - 30.0)
		var l2: Vector2 = c + Vector2.from_angle(wa - 0.09) * (r - 30.0)
		draw_colored_polygon(PackedVector2Array([tip, l1, l2]), K.pal("green"))
		draw_polyline(PackedVector2Array([tip, l1, l2, tip]), K.pal("green").darkened(0.3), 2.0, true)
	if absf(angvel) > 0.02:
		var sweep: float = clampf(angvel, -3.0, 3.0) * 0.5
		draw_arc(c, r * 0.48, -PI / 2.0, -PI / 2.0 + sweep, 24, K.pal("red"), 6.0, true)
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -36), c + Vector2(22, 22), c + Vector2(0, 10), c + Vector2(-22, 22)])
	draw_colored_polygon(pts, accent)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), accent.darkened(0.35), 3.0, true)
	draw_string(fh, Vector2(c.x - 50, c.y + 52.0), "%03d°" % int(hd), HORIZONTAL_ALIGNMENT_CENTER, 100, 22, ink)
