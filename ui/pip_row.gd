class_name PipRow
extends Control
## A row of clickable power pips (0..max). Click a pip to set the level.

signal changed(n: int)

var value: int = 0
var max_pips: int = 6
var accent: Color = Color.WHITE
var title: String = ""
var tripped: bool = false
var boosted: bool = false
var over: int = 4

func _init(t: String = "", color: Color = Color.WHITE, mx: int = 6) -> void:
	title = t
	accent = color
	max_pips = mx
	custom_minimum_size = Vector2(300, 38)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_value(n: int) -> void:
	value = n
	queue_redraw()

func _pip_rect(i: int) -> Rect2:
	var x0: float = 96.0
	var w: float = 30.0
	return Rect2(x0 + i * (w + 6.0), 4.0, w, size.y - 8.0)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for i in max_pips:
			if _pip_rect(i).grow(3).has_point(ev.position):
				var n: int = i + 1
				if n == value:
					n = i
				changed.emit(n)
				return
		if ev.position.x < 90.0:
			changed.emit(0)

func _draw() -> void:
	var ink: Color = K.pal("ink")
	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(2, size.y * 0.5 + 6.0), title, HORIZONTAL_ALIGNMENT_LEFT, 92, 16, ink)
	for i in max_pips:
		var r: Rect2 = _pip_rect(i)
		var on: bool = i < value
		var col: Color = accent if on else K.pal("white")
		if on and i >= over:
			col = K.pal("coral")
		if tripped:
			col = Color(0.55, 0.55, 0.55) if on else K.pal("white")
		draw_style_box(UIK.box(col, ink, 9, 3, 0), r)
	if tripped:
		draw_string(font, Vector2(_pip_rect(max_pips - 1).end.x + 8, size.y * 0.5 + 6.0), "TRIPPED", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, K.pal("coral"))
