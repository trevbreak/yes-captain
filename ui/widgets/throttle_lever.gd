class_name ThrottleLever
extends Control
## The brass throttle. Drag the red handle (or W/S). It STAYS where you leave it. 0 = stop, 1 = full.

signal changed(v: float)

var value: float = 0.0
var disabled: bool = false
var marks: Array = [[0.0, "STOP"], [0.5, "HALF"], [1.0, "FULL"]]
var red_from: float = -1.0       # draw a red zone from here to FULL (heat mission)
var _drag: bool = false
var _plate: Texture2D
var _handle: Texture2D
var _lay: Dictionary = {}

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(230, 360)
	mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_plate = Art.tex("prop_throttle", 2.0)
	_handle = Art.tex("prop_throttle_handle", 2.0)
	var props: Variant = Art.layout("props")
	_lay = props.get("throttle", {}) if props is Dictionary else {}

func set_value(v: float, emit: bool = false) -> void:
	v = snappedf(clampf(v, 0.0, 1.0), 0.01)
	if absf(v - value) < 0.0001:
		return
	value = v
	queue_redraw()
	if emit:
		changed.emit(value)

const LABEL_W: float = 72.0   # room to the right of the plate for STOP / HALF / FULL

func _plate_rect() -> Rect2:
	## the plate keeps its shape and leaves room for its labels inside our own rect
	var ph: float = minf(size.y, (size.x - 24.0 - LABEL_W) * 440.0 / 200.0)
	var pw: float = ph * 200.0 / 440.0
	return Rect2(Vector2(24.0, (size.y - ph) / 2.0), Vector2(pw, ph))

func _slot() -> Vector2:
	## y of FULL and STOP in local coordinates
	var pr: Rect2 = _plate_rect()
	var k: float = pr.size.y / 440.0
	return Vector2(pr.position.y + float(_lay.get("slot_top", 62)) * k, pr.position.y + float(_lay.get("slot_bottom", 362)) * k)

func _y_for(v: float) -> float:
	var s: Vector2 = _slot()
	return lerpf(s.y, s.x, v)

func _gui_input(e: InputEvent) -> void:
	if disabled:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		if e.pressed:
			_set_from(e.position.y)
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		_set_from(e.position.y)
		accept_event()

func _set_from(y: float) -> void:
	var s: Vector2 = _slot()
	set_value(inverse_lerp(s.y, s.x, y), true)

func _draw() -> void:
	var pr: Rect2 = _plate_rect()
	draw_texture_rect(_plate, pr, false)
	var cx: float = pr.position.x + pr.size.x / 2.0
	var f: Font = UIK.font("head")
	if red_from >= 0.0:
		var y0: float = _y_for(1.0)
		var y1: float = _y_for(red_from)
		draw_rect(Rect2(cx - 9, y0, 18, y1 - y0), Color(UIK.c("red"), 0.85))
	for m in marks:
		var y: float = _y_for(float(m[0]))
		draw_string(f, Vector2(pr.end.x + 8, y + 8), str(m[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIK.ink())
	var hy: float = _y_for(value)
	var hw: float = pr.size.x * 1.12
	var hh: float = hw * 90.0 / 220.0
	draw_texture_rect(_handle, Rect2(Vector2(cx - hw / 2.0, hy - hh / 2.0), Vector2(hw, hh)), false)
