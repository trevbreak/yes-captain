class_name Gauges
extends RefCounted
## Small inked readouts: a brass needle gauge, a thermometer, a progress bar and a lamp.

class Needle extends Control:
	## round brass gauge; value 0..1 sweeps 270 degrees
	var value: float = 0.0
	var shown: float = 0.0
	var label: String = ""
	var readout: String = ""
	var _face: Texture2D
	var _needle: Texture2D

	func _init(lbl: String = "", px: int = 150) -> void:
		label = lbl
		custom_minimum_size = Vector2(px, px + 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_face = Art.tex("prop_gauge", 1.2)
		_needle = Art.tex("prop_needle", 1.5)

	func set_value(v: float, text: String = "") -> void:
		value = clampf(v, 0.0, 1.0)
		readout = text

	func _process(dt: float) -> void:
		var target: float = value + sin(Time.get_ticks_msec() * 0.02) * 0.004 * value
		if absf(target - shown) > 0.0005:
			shown = lerpf(shown, target, 1.0 - exp(-10.0 * dt))
			queue_redraw()

	func _draw() -> void:
		var s: float = minf(size.x, size.y - 30.0)
		var c: Vector2 = Vector2(size.x / 2.0, s / 2.0)
		draw_texture_rect(_face, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false)
		var a: float = deg_to_rad(135.0 + 270.0 * shown) + PI / 2.0
		var nl: float = s * 0.36
		var nw: float = nl * 40.0 / 112.0
		draw_set_transform(c, a, Vector2.ONE)
		draw_texture_rect(_needle, Rect2(Vector2(-nw / 2.0, -nl * 120.0 / 112.0), Vector2(nw, nl * 140.0 / 112.0)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var f: Font = UIK.font("head")
		if readout != "":
			var rs: Vector2 = f.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
			draw_string(f, Vector2(c.x - rs.x / 2.0, c.y + s * 0.34), readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIK.ink())
		var ls: Vector2 = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
		draw_string(f, Vector2(c.x - ls.x / 2.0, size.y - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UIK.ink())

class Thermo extends Control:
	## a thermometer: value 0..1, goes red past `danger`
	var value: float = 0.0
	var danger: float = 0.8
	var label: String = ""
	var _glass: Texture2D

	func _init(lbl: String = "HEAT", h: int = 220) -> void:
		label = lbl
		custom_minimum_size = Vector2(h * 90.0 / 320.0 + 20.0, h + 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_glass = Art.tex("prop_thermo", 1.4)

	func set_value(v: float) -> void:
		if absf(v - value) > 0.002:
			value = clampf(v, 0.0, 1.0)
			queue_redraw()

	func _draw() -> void:
		var h: float = size.y - 28.0
		var w: float = h * 90.0 / 320.0
		var o: Vector2 = Vector2((size.x - w) / 2.0, 0.0)
		var k: float = h / 320.0
		var col: Color = UIK.c("red") if value >= danger else (UIK.c("orange") if value > danger * 0.7 else UIK.c("red"))
		var hot: bool = value >= danger
		# bulb + tube contents
		draw_circle(o + Vector2(45, 272) * k, 26.0 * k, col)
		var top: float = lerpf(250.0, 16.0, value)
		draw_rect(Rect2(o + Vector2(33, top) * k, Vector2(24, 262 - top) * k), col)
		if hot and int(Time.get_ticks_msec() / 200) % 2 == 0:
			draw_circle(o + Vector2(45, 272) * k, 30.0 * k, Color(UIK.c("yellow"), 0.5))
		# the danger line
		var dy: float = lerpf(250.0, 16.0, danger) * k
		draw_line(o + Vector2(20 * k, dy), o + Vector2(80 * k, dy), UIK.c("red"), 3.0, true)
		draw_texture_rect(_glass, Rect2(o, Vector2(w, h)), false)
		var f: Font = UIK.font("head")
		var ls: Vector2 = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(f, Vector2(size.x / 2.0 - ls.x / 2.0, size.y - 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIK.ink())

	func _process(_dt: float) -> void:
		if value >= danger:
			queue_redraw()

class Bar extends Control:
	## an inked progress bar with a label on it
	var value: float = 0.0
	var col: Color = Color.WHITE
	var text: String = ""
	var marker: float = -1.0
	var _track: InkBox
	var _fill: InkBox

	func _init(c: String = "green", h: int = 34) -> void:
		col = UIK.c(c)
		custom_minimum_size = Vector2(120, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_track = Art.box("bar_track")
		_fill = Art.box("bar_fill", col)

	func set_value(v: float, t: String = "") -> void:
		v = clampf(v, 0.0, 1.0)
		if absf(v - value) > 0.002 or t != text:
			value = v
			text = t
			queue_redraw()

	func set_colour(c: Color) -> void:
		if c != col:
			col = c
			_fill = Art.box("bar_fill", col)
			queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_style_box(_track, r)
		if value > 0.01:
			var inner: Rect2 = Rect2(Vector2(3, 3), Vector2((size.x - 6.0) * value, size.y - 8.0))
			if inner.size.x > 14.0:
				draw_style_box(_fill, inner)
		if marker >= 0.0:
			var mx: float = 3.0 + (size.x - 6.0) * marker
			draw_line(Vector2(mx, 0), Vector2(mx, size.y - 4.0), UIK.ink(), 3.0, true)
		if text != "":
			var f: Font = UIK.font("head")
			var fs: int = int(clampf(size.y * 0.55, 13.0, 22.0))
			var ts: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var p: Vector2 = Vector2(size.x / 2.0 - ts.x / 2.0, (size.y - 4.0) / 2.0 + ts.y * 0.32)
			draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, UIK.c("cream"))
			draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIK.ink())

class Lamp extends TextureRect:
	var state: String = "off"

	func _init(px: int = 30) -> void:
		custom_minimum_size = Vector2(px, px)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_state("off")

	func set_state(s: String) -> void:
		## off | green | red | mustard
		if s != state or texture == null:
			state = s
			texture = Art.sized("lamp_" + s, custom_minimum_size.x)
