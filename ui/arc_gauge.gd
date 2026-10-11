class_name ArcGauge
extends Control
## Mini turret-arc diagram: ship forward is up; the allowed arc is highlighted; the needle is the barrel.

var lo: float = 0.0
var hi: float = 0.0
var ang: float = 0.0
var tgt: float = 0.0
var accent: Color = Color.WHITE
var jam: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(110, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 6.0
	var ink: Color = K.pal("ink")
	draw_circle(c, r, K.pal("cream2"))
	draw_arc(c, r, 0, TAU, 32, ink, 3.0)
	# allowed arc (screen angle = relative angle - 90deg)
	draw_arc(c, r - 6.0, lo - PI / 2.0, hi - PI / 2.0, 32, accent, 9.0, true)
	draw_line(c, c + Vector2.from_angle(tgt - PI / 2.0) * (r - 4.0), Color(ink, 0.35), 2.0)
	draw_line(c, c + Vector2.from_angle(ang - PI / 2.0) * (r - 2.0), K.pal("coral") if jam else ink, 5.0, true)
	draw_circle(c, 6.0, ink)
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 7), c + Vector2(-6, 7)])
	draw_colored_polygon(pts, K.pal("white"))
