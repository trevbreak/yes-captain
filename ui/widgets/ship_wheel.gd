class_name ShipWheel
extends Control
## The helm's ship's wheel. Drag it round (or use A/D). It STAYS where you leave it.
## value -1 (hard left) .. 1 (hard right); the wheel turns up to 140 degrees each way.

signal changed(v: float)

const MAX_TURN: float = deg_to_rad(140.0)

var value: float = 0.0
var disabled: bool = false
var _drag: bool = false
var _last_ang: float = 0.0
var _tex: Texture2D

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(300, 300)
	_tex = Art.tex("prop_wheel", 1.6)

func set_value(v: float, emit: bool = false) -> void:
	v = clampf(v, -1.0, 1.0)
	if absf(v) < 0.04:
		v = 0.0
	if absf(v - value) < 0.0001:
		return
	value = v
	queue_redraw()
	if emit:
		changed.emit(value)

func _center() -> Vector2:
	return size / 2.0

func _radius() -> float:
	return minf(size.x, size.y) / 2.0

func _gui_input(e: InputEvent) -> void:
	if disabled:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		_last_ang = (e.position - _center()).angle()
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		var a: float = (e.position - _center()).angle()
		var d: float = wrapf(a - _last_ang, -PI, PI)
		_last_ang = a
		set_value(value + d / MAX_TURN, true)
		accept_event()

func _draw() -> void:
	var c: Vector2 = _center()
	var r: float = _radius()
	# scale marks behind the wheel: HARD LEFT .. HARD RIGHT
	var f: Font = UIK.font("head")
	for k in range(-4, 5):
		var a: float = -PI / 2.0 + k * MAX_TURN / 4.0
		var p0: Vector2 = c + Vector2.from_angle(a) * (r * 0.98)
		var p1: Vector2 = c + Vector2.from_angle(a) * (r * (0.9 if k % 2 == 0 else 0.94))
		draw_line(p0, p1, UIK.ink(), 4.0 if k % 2 == 0 else 2.5, true)
	draw_string(f, c + Vector2(-r * 0.98, -r * 0.62), "LEFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIK.ink())
	draw_string(f, c + Vector2(r * 0.98 - 58, -r * 0.62), "RIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIK.ink())
	var wr: float = r * 0.86
	draw_set_transform(c, value * MAX_TURN, Vector2.ONE)
	draw_texture_rect(_tex, Rect2(Vector2(-wr, -wr), Vector2(wr * 2.0, wr * 2.0)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the pointer at the top: where "straight ahead" is
	var tip: Vector2 = c + Vector2(0, -r)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-11, -2), tip + Vector2(11, -2), tip + Vector2(0, 16)]), UIK.c("red"))
	draw_polyline(PackedVector2Array([tip + Vector2(-11, -2), tip + Vector2(11, -2), tip + Vector2(0, 16), tip + Vector2(-11, -2)]),
		UIK.ink(), 3.0, true)
