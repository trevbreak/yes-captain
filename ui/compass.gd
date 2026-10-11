class_name Compass
extends Control
## Rotating compass ring. The ship's heading is fixed at the top.

var heading: float = -PI / 2.0
var angvel: float = 0.0
var wp_bearing: float = 999.0   # relative bearing to waypoint (rad, clockwise); 999 = none
var drift: float = 0.0
var shown_heading: float = -PI / 2.0
var accent: Color = Color.WHITE

func _init() -> void:
	custom_minimum_size = Vector2(320, 320)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	shown_heading = lerp_angle(shown_heading, heading, 1.0 - exp(-14.0 * delta))
	queue_redraw()

func _ready() -> void:
	set_process(true)

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 6.0
	var ink: Color = K.pal("ink")
	var font: Font = get_theme_default_font()
	draw_circle(c, r + 3.0, ink)
	draw_circle(c, r, K.pal("cream"))
	draw_circle(c, r * 0.62, K.pal("cream2"))
	var hd: float = fposmod(rad_to_deg(shown_heading) + 90.0, 360.0)
	for d in range(0, 360, 10):
		var a: float = deg_to_rad(float(d) - hd - 90.0)
		var major: bool = d % 30 == 0
		var p0: Vector2 = c + Vector2.from_angle(a) * (r - 2.0)
		var p1: Vector2 = c + Vector2.from_angle(a) * (r - (16.0 if major else 9.0))
		draw_line(p0, p1, ink, 3.0 if major else 1.5)
		if major:
			var lbl: String = {0: "N", 90: "E", 180: "S", 270: "W"}.get(d, str(d))
			var tp: Vector2 = c + Vector2.from_angle(a) * (r - 34.0)
			var col: Color = K.pal("coral") if d == 0 else ink
			draw_string(font, tp - Vector2(20, -6), lbl, HORIZONTAL_ALIGNMENT_CENTER, 40, 17, col)
	# waypoint marker
	if wp_bearing < 900.0:
		var wa: float = wp_bearing - PI / 2.0
		var tip: Vector2 = c + Vector2.from_angle(wa) * (r - 4.0)
		var l1: Vector2 = c + Vector2.from_angle(wa + 0.07) * (r - 30.0)
		var l2: Vector2 = c + Vector2.from_angle(wa - 0.07) * (r - 30.0)
		draw_colored_polygon(PackedVector2Array([tip, l1, l2]), K.pal("green"))
		draw_polyline(PackedVector2Array([tip, l1, l2, tip]), ink, 2.0)
	# ship icon (fixed, pointing up)
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -34), c + Vector2(22, 24), c + Vector2(0, 12), c + Vector2(-22, 24)])
	draw_colored_polygon(pts, accent)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), ink, 3.0)
	# spin arrow
	if absf(angvel) > 0.02:
		var sweep: float = clampf(angvel, -3.0, 3.0) * 0.5
		draw_arc(c, r * 0.5, -PI / 2.0, -PI / 2.0 + sweep, 20, K.pal("coral"), 5.0, true)
	draw_string(font, Vector2(c.x - 50, c.y + 46.0), "%03d°" % int(hd), HORIZONTAL_ALIGNMENT_CENTER, 100, 24, ink)
