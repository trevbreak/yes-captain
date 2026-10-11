class_name Lever
extends Control
## Chunky lever, vertical or horizontal. Range [vmin, vmax]. Emits changed(v) while dragged.
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

func _init(t: String = "", lo: float = -1.0, hi: float = 1.0, color: Color = Color.WHITE, horizontal: bool = false) -> void:
	title = t
	vmin = lo
	vmax = hi
	accent = color
	horiz = horizontal
	custom_minimum_size = Vector2(240, 80) if horizontal else Vector2(70, 200)
	mouse_default_cursor_shape = Control.CURSOR_HSIZE if horizontal else Control.CURSOR_VSIZE

func set_value(v: float) -> void:
	if not dragging:
		value = clampf(v, vmin, vmax)
		queue_redraw()

func _span() -> float:
	return size.x if horiz else size.y

func _pos_of(v: float) -> float:
	var pad: float = 34.0
	var f: float = (v - vmin) / maxf(0.0001, vmax - vmin)
	if horiz:
		return lerpf(pad, size.x - pad, f)
	return lerpf(size.y - pad - 18.0, pad, f)

func _v_of(p: float) -> float:
	var pad: float = 34.0
	var f: float
	if horiz:
		f = clampf((p - pad) / maxf(1.0, size.x - 2.0 * pad), 0.0, 1.0)
	else:
		f = clampf((size.y - pad - 18.0 - p) / maxf(1.0, size.y - 2.0 * pad - 18.0), 0.0, 1.0)
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and dragging and spring:
		pass

func _draw() -> void:
	var ink: Color = K.pal("ink")
	var font: Font = get_theme_default_font()
	var col: Color = accent if not disabled else Color(0.6, 0.6, 0.6)
	if horiz:
		var cy: float = size.y * 0.5 - 6.0
		var l: float = _pos_of(vmin)
		var r: float = _pos_of(vmax)
		draw_rect(Rect2(l - 6, cy - 8, r - l + 12, 16), ink, true)
		draw_rect(Rect2(l - 3, cy - 5, r - l + 6, 10), K.pal("cream2"), true)
		for m in marks:
			var mx: float = _pos_of(float(m))
			draw_line(Vector2(mx, cy - 18), Vector2(mx, cy + 18), Color(ink, 0.5), 2.0)
		if vmin < 0.0 and vmax > 0.0:
			var zx: float = _pos_of(0.0)
			draw_line(Vector2(zx, cy - 22), Vector2(zx, cy + 22), ink, 3.0)
		var kx: float = _pos_of(value)
		draw_style_box(UIK.box(col, ink, 12, 3, 0), Rect2(kx - 17, cy - 24, 34, 48))
		draw_line(Vector2(kx, cy - 14), Vector2(kx, cy + 14), ink, 3.0)
		draw_string(font, Vector2(0, size.y - 4.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, ink)
		return
	var cx: float = size.x * 0.5
	var top: float = _pos_of(vmax)
	var bot: float = _pos_of(vmin)
	draw_rect(Rect2(cx - 8, top - 6, 16, bot - top + 12), ink, true)
	draw_rect(Rect2(cx - 5, top - 3, 10, bot - top + 6), K.pal("cream2"), true)
	for m in marks:
		var my: float = _pos_of(float(m))
		draw_line(Vector2(cx - 18, my), Vector2(cx + 18, my), Color(ink, 0.5), 2.0)
	if vmin < 0.0 and vmax > 0.0:
		var zy: float = _pos_of(0.0)
		draw_line(Vector2(cx - 24, zy), Vector2(cx + 24, zy), ink, 3.0)
	var ky: float = _pos_of(value)
	draw_style_box(UIK.box(col, ink, 12, 3, 0), Rect2(cx - 26, ky - 15, 52, 30))
	draw_line(Vector2(cx - 14, ky), Vector2(cx + 14, ky), ink, 3.0)
	draw_string(font, Vector2(0, size.y - 2.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, ink)
	var vt: String = (fmt % value) if fmt != "" else ("%+.2f" % value if vmin < 0.0 else "%.2f" % value)
	draw_string(font, Vector2(0, 16.0), vt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(ink, 0.7))
