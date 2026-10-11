class_name SafetyBtn
extends Button
## The "spicy" control. It lives under a flip-up safety cover. Click once to open the cover, again to fire.

signal fired

var cover_open: bool = false
var open_t: float = 0.0
var base_text: String = ""
var color_name: String = "coral"

func _init(t: String = "", color: String = "coral") -> void:
	base_text = t
	color_name = color
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(140, 48)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIK.style_btn(self, color)
	text = "[ %s ]" % t
	pressed.connect(_on_press)

func _on_press() -> void:
	if not cover_open:
		cover_open = true
		open_t = 3.0
		text = "!! %s !!" % base_text
		Sfx.play("clack")
	else:
		cover_open = false
		text = "[ %s ]" % base_text
		fired.emit()

func _process(delta: float) -> void:
	if cover_open:
		open_t -= delta
		if open_t <= 0.0:
			cover_open = false
			text = "[ %s ]" % base_text

func _draw() -> void:
	if not cover_open:
		# the translucent safety cover
		var r: Rect2 = Rect2(Vector2(3, 3), size - Vector2(6, 14))
		draw_rect(r, Color(1, 1, 1, 0.38), true)
		draw_rect(r, Color(K.pal("ink"), 0.7), false, 2.0)
		for i in 4:
			draw_line(Vector2(8 + i * 36, 8), Vector2(8 + i * 36 + 14, size.y - 16), Color(1, 1, 1, 0.35), 3.0)
