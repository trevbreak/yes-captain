class_name ArcGauge
extends Control
## Mini turret-arc diagram: ship forward is up, the allowed arc is highlighted, the needle is the barrel.

var lo: float = 0.0
var hi: float = 0.0
var ang: float = 0.0
var tgt: float = 0.0
var accent: Color = Color.WHITE
var jam: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(100, 100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(c, r, K.pal("well"))
	draw_arc(c, r - 6.0, lo - PI / 2.0, hi - PI / 2.0, 32, Color(accent, 0.55), 10.0, true)
	draw_line(c, c + Vector2.from_angle(tgt - PI / 2.0) * (r - 4.0), Color(K.pal("ink"), 0.25), 2.0, true)
	draw_line(c, c + Vector2.from_angle(ang - PI / 2.0) * (r - 2.0), K.pal("red") if jam else K.pal("ink"), 6.0, true)
	draw_circle(c, 9.0, K.pal("ink"))
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 5), c + Vector2(-5, 5)])
	draw_colored_polygon(pts, Color.WHITE)
