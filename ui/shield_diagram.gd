class_name ShieldDiagram
extends Control
## Top-down ship with four shield facings (front, starboard, aft, port).

var shields: Array = [0.0, 0.0, 0.0, 0.0]
var weights: Array = [1, 1, 1, 1]
var threat: int = -1
var accent: Color = Color.WHITE
var t: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 22.0
	var fh: Font = UIK.font_head()
	for i in 4:
		var mid: float = -PI / 2.0 + float(i) * PI / 2.0
		var f: float = clampf(float(shields[i]) / 100.0, 0.0, 1.0)
		var a0: float = mid - PI / 4.0 + 0.08
		var a1: float = mid + PI / 4.0 - 0.08
		draw_arc(c, r, a0, a1, 18, K.pal("well"), 16.0, true)
		var col: Color = K.pal("sky").lerp(K.pal("red"), 1.0 - f)
		if f > 0.01:
			draw_arc(c, r, a0, lerpf(a0, a1, f), 18, col, 16.0, true)
		if i == threat:
			draw_arc(c, r + 15.0, mid - 0.35, mid + 0.35, 10, K.pal("red"), 5.0 + sin(t * 10.0) * 1.5, true)
		var tp: Vector2 = c + Vector2.from_angle(mid) * (r - 28.0)
		draw_string(fh, tp - Vector2(20, -6), "%d" % int(shields[i]), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, K.pal("ink"))
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -r * 0.45), c + Vector2(r * 0.28, r * 0.38), c + Vector2(0, r * 0.22), c + Vector2(-r * 0.28, r * 0.38)])
	draw_colored_polygon(pts, accent)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), accent.darkened(0.35), 3.0, true)
