class_name BigButton
extends Control
## A big round arcade button in a brass collar. hold=true: emits held(true/false) while pressed (FIRE, SCAN,
## REPAIR, TRACTOR...). hold=false: emits pressed_once. A key can drive it too (see press_key/release_key).

signal held(on: bool)
signal pressed_once

var label: String = ""
var colour: String = "red"
var hold: bool = true
var down: bool = false
var disabled: bool = false
var progress: float = -1.0     # optional ring of progress around the button (0..1)
var key_hint: String = ""
var arrow: int = 0             # -1 / 1: an arrow on the cap pointing left / right (the helm's turn buttons)
var _up: Texture2D
var _dn: Texture2D
var _mouse: bool = false
var _finger: int = Pointer.NONE   # the finger (or mouse) holding it down

func _init(text: String = "FIRE", col: String = "red", is_hold: bool = true, px: int = 150) -> void:
	label = text
	colour = col
	hold = is_hold
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(px, px + 34)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _ready() -> void:
	add_to_group("input_hints")
	_up = Art.tex("bigbtn_" + colour, 1.2)
	_dn = Art.tex("bigbtn_%s_down" % colour, 1.2)
	_fit_label()

func _label_text() -> String:
	return label + ("  [%s]" % key_hint if key_hint != "" and UIK.keys_shown() else "")

func _font_size() -> int:
	return 24 if label.length() < 9 else 19

func _fit_label() -> void:
	## the caption is drawn under the button: make sure the control is wide enough to hold it
	var full: String = label + ("  [%s]" % key_hint if key_hint != "" else "")
	var w: float = UIK.font("head").get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x + 6.0
	if custom_minimum_size.x < w:
		custom_minimum_size.x = w

func set_label(t: String) -> void:
	if t != label:
		label = t
		_fit_label()
		queue_redraw()

func set_disabled(v: bool) -> void:
	if v != disabled:
		disabled = v
		if v and down:
			_set_down(false)
		queue_redraw()

func set_progress(p: float) -> void:
	if absf(p - progress) > 0.005:
		progress = p
		queue_redraw()

func _set_down(v: bool) -> void:
	if v == down:
		return
	down = v
	queue_redraw()
	if v:
		UIK.sfx("clunk")
		Web.buzz(12)
	if hold:
		held.emit(v)
	elif v:
		pressed_once.emit()

func _gui_input(e: InputEvent) -> void:
	if disabled:
		return
	if Pointer.swallow(e):
		accept_event()
		return
	var d: int = Pointer.down(e)
	if d != Pointer.NONE and _finger == Pointer.NONE:
		_finger = d
		_mouse = true
		_set_down(true)
		accept_event()
		return
	var u: int = Pointer.up(e)
	if u != Pointer.NONE and u == _finger:
		_finger = Pointer.NONE
		_mouse = false
		_set_down(false)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _mouse and hold:
		pass

func press_key(on: bool) -> void:
	if disabled:
		return
	_set_down(on)

func _draw() -> void:
	var s: float = minf(size.x, size.y - 34.0)
	var r: Rect2 = Rect2(Vector2((size.x - s) / 2.0, 0.0), Vector2(s, s))
	var t: Texture2D = _dn if down else _up
	draw_texture_rect(t, r, false, Color(1, 1, 1, 0.45) if disabled else Color.WHITE)
	if progress >= 0.0:
		var c: Vector2 = r.get_center() + Vector2(0, 3)
		draw_arc(c, s * 0.47, -PI / 2.0, -PI / 2.0 + TAU, 48, Color(UIK.ink(), 0.25), 9.0, true)
		if progress > 0.0:
			draw_arc(c, s * 0.47, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, UIK.c("green"), 9.0, true)
	if arrow != 0:
		var ac: Vector2 = r.get_center() + Vector2(0, 4 if down else -2)
		var a: float = s * 0.2
		var pts: PackedVector2Array = PackedVector2Array([ac + Vector2(a * arrow, 0), ac + Vector2(-a * 0.75 * arrow, -a), ac + Vector2(-a * 0.75 * arrow, a)])
		var col: Color = Color(UIK.c("cream"), 0.5 if disabled else 1.0)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, UIK.ink(), 4.0, true)
	var f: Font = UIK.font("head")
	var fs: int = _font_size()
	var txt: String = _label_text()
	var ts: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p: Vector2 = Vector2(size.x / 2.0 - ts.x / 2.0, size.y - 6.0)
	draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIK.ink(), 0.4 if disabled else 1.0))
