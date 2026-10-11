class_name ClockDial
extends Control
## A round dial around our ship, marked like a clock (12 = the nose). Used by Weapons (turret) and Shields.
## Drag anywhere on it to point it; it STAYS where you leave it. value = angle relative to the nose (radians).

signal changed(v: float)

enum Mode { TURRET, SHIELD }

var mode: int = Mode.SHIELD
var value: float = 0.0
var arc: float = deg_to_rad(65.0)
var disabled: bool = false
var broken: bool = false
var hits: Array = []          # [{rel, blocked, age}]
var stuck: Array = []         # grabber relative angles
var accent: Color = Color.WHITE
var _drag: bool = false
var _bezel: Texture2D
var _ship: Texture2D

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(320, 320)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bezel = Art.tex("prop_dial", 1.4)
	_ship = Art.tex("ship_ours", 1.0)

func set_value(v: float, emit: bool = false) -> void:
	v = wrapf(v, -PI, PI)
	if absf(wrapf(v - value, -PI, PI)) < 0.0001:
		return
	value = v
	queue_redraw()
	if emit:
		changed.emit(value)

func _c() -> Vector2:
	return size / 2.0

func _r() -> float:
	return minf(size.x, size.y) / 2.0

func _gui_input(e: InputEvent) -> void:
	if disabled:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		if e.pressed:
			_point(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		_point(e.position)
		accept_event()

func _point(p: Vector2) -> void:
	var d: Vector2 = p - _c()
	if d.length() < 8.0:
		return
	# screen angle -> relative to nose (nose is up)
	set_value(wrapf(d.angle() + PI / 2.0, -PI, PI), true)

func _dir(rel: float) -> Vector2:
	return Vector2.from_angle(rel - PI / 2.0)

func _draw() -> void:
	var c: Vector2 = _c()
	var r: float = _r()
	var inner: float = r * 0.8
	draw_circle(c, inner, UIK.c("cream"))
	# clock numbers
	var f: Font = UIK.font("head")
	for h in 12:
		var a: float = h * TAU / 12.0
		var p: Vector2 = c + _dir(a) * (inner - 22.0)
		var lbl: String = str(12 if h == 0 else h)
		var big: bool = h % 3 == 0
		var fs: int = 22 if big else 15
		var sz: Vector2 = f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, p + Vector2(-sz.x / 2.0, sz.y * 0.32), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIK.ink(), 1.0 if big else 0.55))
	# the shield arc or turret
	var col: Color = accent if not broken else UIK.c("grey")
	if mode == Mode.SHIELD:
		var pts: PackedVector2Array = PackedVector2Array()
		var ro: float = inner - 44.0
		var ri: float = ro - 30.0
		var n: int = 28
		for i in n + 1:
			pts.append(c + _dir(value - arc + 2.0 * arc * i / n) * ro)
		for i in n + 1:
			pts.append(c + _dir(value + arc - 2.0 * arc * i / n) * ri)
		draw_colored_polygon(pts, Color(col, 0.85))
		pts.append(pts[0])
		draw_polyline(pts, UIK.ink(), 4.0, true)
	else:
		# a cone showing what Weapons can see down the barrel
		var cone: PackedVector2Array = PackedVector2Array([c])
		for i in 11:
			cone.append(c + _dir(value - 0.42 + 0.84 * i / 10.0) * (inner - 40.0))
		draw_colored_polygon(cone, Color(col, 0.22))
		var tip: Vector2 = c + _dir(value) * (inner - 40.0)
		draw_line(c, tip, UIK.ink(), 12.0, true)
		draw_line(c, tip, col, 6.0, true)
		draw_circle(tip, 9.0, UIK.ink())
		draw_circle(tip, 6.0, col)
	# hits flash around the edge
	for hh in hits:
		var hp: Vector2 = c + _dir(float(hh.rel)) * (inner - 8.0)
		var fade: float = 1.0 - clampf(float(hh.age) / 0.8, 0.0, 1.0)
		draw_circle(hp, 16.0 * fade + 6.0, Color(UIK.c("mustard") if hh.blocked else UIK.c("red"), fade))
	for s in stuck:
		var sp: Vector2 = c + _dir(float(s)) * (inner - 70.0)
		draw_circle(sp, 13.0, UIK.ink())
		draw_circle(sp, 9.0, UIK.c("rose"))
	# our ship in the middle
	var sw: float = inner * 0.42
	var sh: float = sw * 260.0 / 200.0
	draw_texture_rect(_ship, Rect2(c - Vector2(sw, sh) / 2.0, Vector2(sw, sh)), false)
	draw_texture_rect(_bezel, Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false)
