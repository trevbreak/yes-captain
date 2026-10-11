class_name Lever
extends Control
## A slider with a big round knob, vertical or horizontal. Range [vmin, vmax].
## `spring` snaps back to zero on release (yaw, strafe).

signal changed(v: float)
signal released

var value: float = 0.0
var vmin: float = -1.0
var vmax: float = 1.0
var title: String = ""
var accent: Color = Color.WHITE
var dragging: bool = false
var snap_zero: bool = true
var disabled: bool = false
var horiz: bool = false
var spring: bool = false
var marks: Array = []
var fmt: String = ""
var step: float = 0.02

func _init(tt: String = "", lo: float = -1.0, hi: float = 1.0, color: Color = Color.WHITE, horizontal: bool = false) -> void:
	title = tt
	vmin = lo
	vmax = hi
	accent = color
	horiz = horizontal
	custom_minimum_size = Vector2(220, 74) if horizontal else Vector2(76, 200)
	mouse_default_cursor_shape = Control.CURSOR_HSIZE if horizontal else Control.CURSOR_VSIZE

func set_value(v: float) -> void:
	if not dragging:
		value = clampf(v, vmin, vmax)
		queue_redraw()

func _pad() -> float:
	return 28.0

func _pos_of(v: float) -> float:
	var f: float = (v - vmin) / maxf(0.0001, vmax - vmin)
	if horiz:
		return lerpf(_pad(), size.x - _pad(), f)
	return lerpf(size.y - _pad() - 22.0, _pad() + 4.0, f)

func _v_of(p: float) -> float:
	var f: float
	if horiz:
		f = clampf((p - _pad()) / maxf(1.0, size.x - 2.0 * _pad()), 0.0, 1.0)
	else:
		f = clampf((size.y - _pad() - 22.0 - p) / maxf(1.0, size.y - 2.0 * _pad() - 26.0), 0.0, 1.0)
	return lerpf(vmin, vmax, f)

func _gui_input(ev: InputEvent) -> void:
	if disabled:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		dragging = ev.pressed
		if ev.pressed:
			_set_from(ev.position.x if horiz else ev.position.y)
		elif spring:
			value = 0.0
			changed.emit(0.0)
			released.emit()
		queue_redraw()
	elif ev is InputEventMouseMotion and dragging:
		_set_from(ev.position.x if horiz else ev.position.y)

func _set_from(p: float) -> void:
	var v: float = _v_of(p)
	if snap_zero and absf(v) < (vmax - vmin) * 0.04:
		v = 0.0
	v = snappedf(v, step)
	if v != value:
		value = v
		changed.emit(v)
		queue_redraw()

func _draw() -> void:
	var col: Color = accent if not disabled else Color(0.7, 0.7, 0.75)
	var well: Color = K.pal("well")
	var font: Font = UIK.font_bold()
	var vt: String = (fmt % value) if fmt != "" else ("%+.2f" % value if vmin < 0.0 else "%.2f" % value)
	if horiz:
		var cy: float = size.y * 0.42
		var l: float = _pos_of(vmin)
		var r: float = _pos_of(vmax)
		draw_style_box(UIK.sb(well, 8, well.darkened(0.12), 2, 0), Rect2(l - 8, cy - 8, r - l + 16, 16))
		var zero: float = _pos_of(clampf(0.0, vmin, vmax))
		var kx: float = _pos_of(value)
		var fx0: float = minf(zero, kx)
		var fx1: float = maxf(zero, kx)
		if fx1 - fx0 > 1.0:
			draw_style_box(UIK.sb(col, 6, Color(0, 0, 0, 0), 0, 0), Rect2(fx0, cy - 5, fx1 - fx0, 10))
		for m in marks:
			var mx: float = _pos_of(float(m))
			draw_line(Vector2(mx, cy - 14), Vector2(mx, cy + 14), Color(K.pal("ink"), 0.25), 2.0)
		if vmin < 0.0 and vmax > 0.0:
			draw_line(Vector2(zero, cy - 16), Vector2(zero, cy + 16), Color(K.pal("ink"), 0.45), 3.0)
		draw_circle(Vector2(kx, cy + 3), 17.0, Color(0.06, 0.03, 0.18, 0.25))
		draw_circle(Vector2(kx, cy), 17.0, Color.WHITE)
		draw_circle(Vector2(kx, cy), 12.0, col)
		draw_circle(Vector2(kx - 3, cy - 4), 4.0, Color(1, 1, 1, 0.45))
		draw_string(font, Vector2(0, size.y - 3.0), "%s  %s" % [title, vt] if title != "" else vt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, K.pal("ink_soft"))
		return
	var cx: float = size.x * 0.5
	var top: float = _pos_of(vmax)
	var bot: float = _pos_of(vmin)
	draw_style_box(UIK.sb(well, 9, well.darkened(0.12), 2, 0), Rect2(cx - 9, top - 8, 18, bot - top + 16))
	var zero2: float = _pos_of(clampf(0.0, vmin, vmax))
	var ky: float = _pos_of(value)
	var fy0: float = minf(zero2, ky)
	var fy1: float = maxf(zero2, ky)
	if fy1 - fy0 > 1.0:
		draw_style_box(UIK.sb(col, 6, Color(0, 0, 0, 0), 0, 0), Rect2(cx - 6, fy0, 12, fy1 - fy0))
	for m2 in marks:
		var my: float = _pos_of(float(m2))
		draw_line(Vector2(cx - 18, my), Vector2(cx + 18, my), Color(K.pal("ink"), 0.25), 2.0)
	if vmin < 0.0 and vmax > 0.0:
		draw_line(Vector2(cx - 22, zero2), Vector2(cx + 22, zero2), Color(K.pal("ink"), 0.45), 3.0)
	var kr: Rect2 = Rect2(cx - 28, ky - 15, 56, 30)
	draw_style_box(UIK.sb(Color(0.06, 0.03, 0.18, 0.22), 14, Color(0, 0, 0, 0), 0, 0), Rect2(kr.position + Vector2(0, 3), kr.size))
	draw_style_box(UIK.sb(Color.WHITE, 14, col, 4, 0), kr)
	draw_line(Vector2(cx - 12, ky), Vector2(cx + 12, ky), col, 4.0)
	draw_string(UIK.font_head(), Vector2(0, 15.0), vt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, K.pal("ink"))
	draw_string(font, Vector2(0, size.y - 3.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, K.pal("ink_soft"))
