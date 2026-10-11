class_name SafetyBtn
extends Button
## The "spicy" control, under a flip-up hazard cover. Click once to lift the cover, again to fire.

signal fired

var cover_open: bool = false
var open_t: float = 0.0
var base_text: String = ""
var color_name: String = "red"

func _init(tt: String = "", color: String = "red") -> void:
	base_text = tt
	color_name = color if color != "coral" else "red"
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(150, 50)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIK.style_btn(self, color_name)
	text = tt
	icon = UIK.icon("warning", 40)
	add_theme_constant_override("icon_max_width", 20)
	pressed.connect(_on_press)

func _on_press() -> void:
	if not cover_open:
		cover_open = true
		open_t = 3.0
		text = "CONFIRM: " + base_text
		Sfx.play("clack")
	else:
		cover_open = false
		text = base_text
		fired.emit()

func _process(delta: float) -> void:
	if cover_open:
		open_t -= delta
		if open_t <= 0.0:
			cover_open = false
			text = base_text
	queue_redraw()

func _draw() -> void:
	if not cover_open:
		var r: Rect2 = Rect2(Vector2(2, 2), size - Vector2(4, 10))
		draw_style_box(UIK.sb(Color(1, 1, 1, 0.28), 12, Color(1, 1, 1, 0.55), 2, 0), r)
		# hazard stripes on the cover's lip
		var y: float = r.end.y - 7.0
		var x: float = r.position.x + 8.0
		var i: int = 0
		while x < r.end.x - 10.0:
			var col: Color = K.pal("yellow") if i % 2 == 0 else K.pal("ink")
			draw_colored_polygon(PackedVector2Array([Vector2(x, y + 5), Vector2(x + 6, y), Vector2(x + 14, y), Vector2(x + 8, y + 5)]), Color(col, 0.85))
			x += 8.0
			i += 1
