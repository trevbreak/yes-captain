class_name Dial
extends Control
## Arc meter: a soft track, a coloured fill, an optional green target band and a big number.

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
var t: float = 0.0

func _init(tt: String = "", lo: float = 0.0, hi: float = 1.0, color: Color = Color.WHITE) -> void:
	title = tt
	vmin = lo
	vmax = hi
	accent = color
	custom_minimum_size = Vector2(130, 130)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_value(v: float) -> void:
	value = v

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	shown = lerpf(shown, value, 1.0 - exp(-10.0 * delta))
	t += delta
	queue_redraw()

func _frac(v: float) -> float:
	return clampf((v - vmin) / maxf(0.0001, vmax - vmin), 0.0, 1.0)

func _draw() -> void:
	var sz: Vector2 = size
	var r: float = minf(sz.x, sz.y - 22.0) * 0.5 - 6.0
	var c: Vector2 = Vector2(sz.x * 0.5, r + 6.0)
	var a0: float = deg_to_rad(140.0)
	var a1: float = deg_to_rad(400.0)
	var w: float = maxf(10.0, r * 0.2)
	# soft face
	draw_circle(c + Vector2(0, 3), r + 2.0, Color(0.06, 0.03, 0.18, 0.18))
	draw_circle(c, r + 2.0, K.pal("card"))
	draw_arc(c, r - w * 0.5, a0, a1, 48, K.pal("well"), w, true)
	if band_lo >= 0.0:
		draw_arc(c, r - w * 0.5, lerpf(a0, a1, _frac(band_lo)), lerpf(a0, a1, _frac(band_hi)), 24, Color(K.pal("green"), 0.45), w, true)
	if danger_above < vmax:
		draw_arc(c, r - w * 0.5, lerpf(a0, a1, _frac(danger_above)), a1, 24, Color(K.pal("red"), 0.3), w, true)
	var f: float = _frac(shown)
	var col: Color = accent
	if shown >= danger_above:
		col = K.pal("red").lerp(accent, 0.5 + 0.5 * sin(t * 10.0))
	if f > 0.002:
		draw_arc(c, r - w * 0.5, a0, lerpf(a0, a1, f), 48, col, w, true)
	var tip: Vector2 = c + Vector2.from_angle(lerpf(a0, a1, f)) * (r - w * 0.5)
	draw_circle(tip, w * 0.62, Color.WHITE)
	draw_circle(tip, w * 0.42, col.darkened(0.15))
	var font: Font = UIK.font_head()
	var txt: String = ("%." + str(decimals) + "f%s") % [value, unit]
	var fs: int = int(clampf(r * 0.42, 14.0, 34.0))
	draw_string(font, Vector2(0, c.y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, K.pal("ink"))
	draw_string(UIK.font_bold(), Vector2(0, sz.y - 4.0), title.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 13, K.pal("ink_soft"))
