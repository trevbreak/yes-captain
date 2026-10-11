class_name Dial
extends Control
## Wobbly analog dial with an optional green band and a title.

var value: float = 0.0
var shown: float = 0.0
var vmin: float = 0.0
var vmax: float = 1.0
var band_lo: float = -1.0
var band_hi: float = -1.0
var title: String = ""
var unit: String = ""
var accent: Color = Color.WHITE
var decimals: int = 0
var danger_above: float = 1e9
var wobble: float = 0.0

func _init(t: String = "", lo: float = 0.0, hi: float = 1.0, color: Color = Color.WHITE) -> void:
	title = t
	vmin = lo
	vmax = hi
	accent = color
	custom_minimum_size = Vector2(130, 130)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_value(v: float) -> void:
	value = v

func _process(delta: float) -> void:
	shown = lerpf(shown, value, 1.0 - exp(-10.0 * delta))
	wobble += delta
	queue_redraw()

func _ready() -> void:
	set_process(true)

func _frac(v: float) -> float:
	return clampf((v - vmin) / maxf(0.0001, vmax - vmin), 0.0, 1.0)

func _draw() -> void:
	var sz: Vector2 = size
	var c: Vector2 = Vector2(sz.x * 0.5, sz.y * 0.5 - 6.0)
	var r: float = minf(sz.x, sz.y - 18.0) * 0.5 - 4.0
	draw_circle(c, r + 3.0, K.pal("ink"))
	draw_circle(c, r, K.pal("cream"))
	var a0: float = deg_to_rad(135.0)
	var a1: float = deg_to_rad(405.0)
	# band
	if band_lo >= 0.0:
		var b0: float = lerpf(a0, a1, _frac(band_lo))
		var b1: float = lerpf(a0, a1, _frac(band_hi))
		draw_arc(c, r - 7.0, b0, b1, 24, K.pal("green"), 8.0, true)
	if danger_above < vmax:
		var d0: float = lerpf(a0, a1, _frac(danger_above))
		draw_arc(c, r - 7.0, d0, a1, 24, K.pal("coral"), 8.0, true)
	# ticks
	for i in 11:
		var a: float = lerpf(a0, a1, float(i) / 10.0)
		var p0: Vector2 = c + Vector2.from_angle(a) * (r - 3.0)
		var p1: Vector2 = c + Vector2.from_angle(a) * (r - (13.0 if i % 5 == 0 else 8.0))
		draw_line(p0, p1, K.pal("ink"), 2.0)
	# needle
	var f: float = _frac(shown)
	var na: float = lerpf(a0, a1, f) + sin(wobble * 18.0) * 0.012
	draw_line(c, c + Vector2.from_angle(na) * (r - 10.0), accent.darkened(0.3), 5.0, true)
	draw_circle(c, 7.0, K.pal("ink"))
	draw_circle(c, 3.5, accent)
	var font: Font = get_theme_default_font()
	var txt: String = ("%." + str(decimals) + "f%s") % [value, unit]
	draw_string(font, Vector2(0, c.y + r * 0.62), txt, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 17, K.pal("ink"))
	draw_string(font, Vector2(0, sz.y - 3.0), title, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 14, Color(K.pal("ink"), 0.8))
