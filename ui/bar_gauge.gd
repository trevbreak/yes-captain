class_name BarGauge
extends Control
## Chunky horizontal bar with optional target band and centered text.

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
var flash: float = 0.0

func _init(txt: String = "", mx: float = 100.0, color: Color = Color.WHITE, vert: bool = false) -> void:
	text = txt
	vmax = mx
	fill = color
	vertical = vert
	custom_minimum_size = Vector2(24, 100) if vert else Vector2(120, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	shown = lerpf(shown, value, 1.0 - exp(-12.0 * delta))
	flash += delta
	queue_redraw()

func _f(v: float) -> float:
	return clampf((v - vmin) / maxf(0.0001, vmax - vmin), 0.0, 1.0)

func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var ink: Color = K.pal("ink")
	var sb: StyleBoxFlat = UIK.box(K.pal("white"), ink, 10, 3, 0)
	draw_style_box(sb, r)
	var inner: Rect2 = r.grow(-4.0)
	var f: float = _f(shown)
	var col: Color = fill
	if shown >= danger_above:
		col = K.pal("coral").lerp(fill, 0.5 + 0.5 * sin(flash * 12.0))
	if vertical:
		var h: float = inner.size.y * f
		draw_rect(Rect2(inner.position.x, inner.end.y - h, inner.size.x, h), col)
	else:
		draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x * f, inner.size.y), col)
	if band_lo >= 0.0:
		if vertical:
			var y0: float = inner.end.y - inner.size.y * _f(band_hi)
			var y1: float = inner.end.y - inner.size.y * _f(band_lo)
			draw_rect(Rect2(inner.position.x - 3, y0, inner.size.x + 6, y1 - y0), Color(K.pal("green"), 0.45))
			draw_rect(Rect2(inner.position.x - 3, y0, inner.size.x + 6, y1 - y0), K.pal("green"), false, 2.0)
		else:
			var x0: float = inner.position.x + inner.size.x * _f(band_lo)
			var x1: float = inner.position.x + inner.size.x * _f(band_hi)
			draw_rect(Rect2(x0, inner.position.y - 3, x1 - x0, inner.size.y + 6), Color(K.pal("green"), 0.45))
			draw_rect(Rect2(x0, inner.position.y - 3, x1 - x0, inner.size.y + 6), K.pal("green"), false, 2.0)
	if text != "":
		var font: Font = get_theme_default_font()
		draw_string(font, Vector2(0, size.y * 0.5 + 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, ink)
