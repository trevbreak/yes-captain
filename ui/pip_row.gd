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
var label_w: float = 112.0

func _init(tt: String = "", color: Color = Color.WHITE, mx: int = 6) -> void:
	title = tt
	accent = color
	max_pips = mx
	custom_minimum_size = Vector2(320, 36)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_value(n: int) -> void:
	value = n
	queue_redraw()

func _pip_rect(i: int) -> Rect2:
	var w: float = minf(30.0, (size.x - label_w - 4.0) / max_pips - 5.0)
	return Rect2(label_w + i * (w + 5.0), 3.0, w, size.y - 9.0)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for i in max_pips:
			if _pip_rect(i).grow(3).has_point(ev.position):
				var n: int = i + 1
				if n == value:
					n = i
				changed.emit(n)
				return
		if ev.position.x < label_w:
			changed.emit(0)

func _draw() -> void:
	var font: Font = UIK.font_bold()
	draw_string(font, Vector2(2, size.y * 0.5 + 5.0), title, HORIZONTAL_ALIGNMENT_LEFT, label_w - 6.0, 14, K.pal("ink"))
	for i in max_pips:
		var r: Rect2 = _pip_rect(i)
		var on: bool = i < value
		var col: Color = accent
		if on and i >= over:
			col = K.pal("red")
		if tripped:
			col = Color(0.62, 0.62, 0.68)
		if on:
			var s: StyleBoxFlat = UIK.sb(col, 7, Color(0, 0, 0, 0), 0, 0)
			s.border_width_bottom = 4
			s.border_color = col.darkened(0.25)
			draw_style_box(s, r)
			draw_rect(Rect2(r.position.x + 5, r.position.y + 4, r.size.x - 10, 3), Color(1, 1, 1, 0.35))
		else:
			draw_style_box(UIK.sb(K.pal("well"), 7, K.pal("well").darkened(0.12), 2, 0), r)
	if tripped:
		var rr: Rect2 = _pip_rect(max_pips - 1)
		draw_string(UIK.font_head(), Vector2(rr.end.x + 8, size.y * 0.5 + 6.0), "TRIPPED", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, K.pal("red"))
