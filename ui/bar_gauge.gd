class_name BarGauge
extends Control
## Rounded pill meter with an optional green target band, danger flashing and centred text.

var value: float = 0.0
var shown: float = 0.0
var vmax: float = 100.0
var vmin: float = 0.0
var fill: Color = Color.WHITE
var text: String = ""
var band_lo: float = -1.0
var band_hi: float = -1.0
var danger_above: float = 1e9
var vertical: bool = false
var t: float = 0.0

func _init(txt: String = "", mx: float = 100.0, color: Color = Color.WHITE, vert: bool = false) -> void:
	text = txt
	vmax = mx
	fill = color
	vertical = vert
	custom_minimum_size = Vector2(24, 100) if vert else Vector2(110, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	shown = lerpf(shown, value, 1.0 - exp(-12.0 * delta))
	t += delta
	queue_redraw()

func _f(v: float) -> float:
	return clampf((v - vmin) / maxf(0.0001, vmax - vmin), 0.0, 1.0)

func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var rad: int = int(minf(size.x, size.y) * 0.5)
	draw_style_box(UIK.sb(K.pal("well"), rad, K.pal("well").darkened(0.12), 2, 0), r)
	var inner: Rect2 = r.grow(-3.0)
	var f: float = _f(shown)
	var col: Color = fill
	if shown >= danger_above:
		col = K.pal("red").lerp(fill, 0.5 + 0.5 * sin(t * 12.0))
	if band_lo >= 0.0:
		var br: Rect2
		if vertical:
			var y0: float = inner.end.y - inner.size.y * _f(band_hi)
			var y1: float = inner.end.y - inner.size.y * _f(band_lo)
			br = Rect2(inner.position.x, y0, inner.size.x, y1 - y0)
		else:
			var x0: float = inner.position.x + inner.size.x * _f(band_lo)
			var x1: float = inner.position.x + inner.size.x * _f(band_hi)
			br = Rect2(x0, inner.position.y, x1 - x0, inner.size.y)
		draw_style_box(UIK.sb(Color(K.pal("green"), 0.35), 4, K.pal("green"), 2, 0), br)
	if f > 0.003:
		var fr: Rect2
		if vertical:
			var h: float = maxf(inner.size.x, inner.size.y * f)
			fr = Rect2(inner.position.x, inner.end.y - h, inner.size.x, h)
		else:
			var wd: float = maxf(inner.size.y, inner.size.x * f)
			fr = Rect2(inner.position.x, inner.position.y, wd, inner.size.y)
		var irad: int = int(minf(fr.size.x, fr.size.y) * 0.5)
		draw_style_box(UIK.sb(col, irad, Color(0, 0, 0, 0), 0, 0), fr)
		if not vertical and fr.size.y > 10.0:
			draw_rect(Rect2(fr.position.x + irad, fr.position.y + 3, maxf(0.0, fr.size.x - irad * 2), 3), Color(1, 1, 1, 0.3))
	if text != "":
		var fs: int = int(clampf(size.y * 0.58, 11.0, 16.0))
		draw_string(UIK.font_bold(), Vector2(0, size.y * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, K.pal("ink"))
