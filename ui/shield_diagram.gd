class_name ShieldDiagram
extends Control
## Top-down ship with four shield facings (front, starboard, aft, port).

var shields: Array = [0.0, 0.0, 0.0, 0.0]
var weights: Array = [1, 1, 1, 1]
var threat: int = -1
var accent: Color = Color.WHITE
var t: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(230, 230)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 22.0
	var ink: Color = K.pal("ink")
	var font: Font = get_theme_default_font()
	# facing arcs: 0 front (up), 1 starboard (right), 2 aft, 3 port
	for i in 4:
		var mid: float = -PI / 2.0 + float(i) * PI / 2.0
		var f: float = clampf(float(shields[i]) / 100.0, 0.0, 1.0)
		draw_arc(c, r, mid - PI / 4.0 + 0.06, mid + PI / 4.0 - 0.06, 16, Color(ink, 0.25), 16.0, true)
		var col: Color = K.pal("sky").lerp(K.pal("coral"), 1.0 - f)
		if f > 0.01:
			draw_arc(c, r, mid - PI / 4.0 + 0.06, mid - PI / 4.0 + 0.06 + (PI / 2.0 - 0.12) * f, 16, col, 12.0, true)
		if i == threat:
			draw_arc(c, r + 16.0, mid - 0.3, mid + 0.3, 8, K.pal("coral"), 4.0 + sin(t * 10.0) * 1.5)
		var tp: Vector2 = c + Vector2.from_angle(mid) * (r - 24.0)
		draw_string(font, tp - Vector2(20, -5), "%d" % int(shields[i]), HORIZONTAL_ALIGNMENT_CENTER, 40, 15, ink)
		var wp: Vector2 = c + Vector2.from_angle(mid) * (r + 14.0)
		draw_string(font, wp - Vector2(10, -4), "x%d" % int(weights[i]), HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color(ink, 0.6))
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -r * 0.5), c + Vector2(r * 0.3, r * 0.4), c + Vector2(0, r * 0.25), c + Vector2(-r * 0.3, r * 0.4)])
	draw_colored_polygon(pts, accent)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), ink, 3.0)
