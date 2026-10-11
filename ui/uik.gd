class_name UIK
extends RefCounted
## The Two-Point-in-space UI kit: rounded cream panels, thick ink outlines, chunky candy buttons.

static var _theme: Theme = null
static var _font: SystemFont = null

static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Fredoka", "Arial Rounded MT Bold", "Nunito", "Trebuchet MS", "Verdana", "Segoe UI", "DejaVu Sans"])
		_font.font_weight = 600
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font.oversampling = 1.0
	return _font

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 14, bw: int = 3, pad: int = 8) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border if border.a > 0.0 else K.pal("ink")
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font()
	t.default_font_size = 17
	var ink: Color = K.pal("ink")
	t.set_color("font_color", "Label", ink)
	t.set_color("font_color", "Button", ink)
	t.set_color("font_hover_color", "Button", ink)
	t.set_color("font_pressed_color", "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(ink, 0.45))
	t.set_color("font_color", "CheckButton", ink)
	t.set_color("font_color", "LineEdit", ink)
	t.set_color("caret_color", "LineEdit", ink)
	t.set_color("font_placeholder_color", "LineEdit", Color(ink, 0.5))
	t.set_stylebox("normal", "LineEdit", box(K.pal("white"), ink, 10, 3, 8))
	t.set_stylebox("focus", "LineEdit", box(K.pal("white"), K.pal("tangerine"), 10, 4, 8))
	t.set_stylebox("panel", "PanelContainer", box(K.pal("cream"), ink, 18, 4, 10))
	t.set_font_size("font_size", "Button", 18)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(st, "Button", btn_style(K.pal("cream2"), st))
	t.set_stylebox("panel", "TooltipPanel", box(K.pal("cream"), ink, 8, 2, 6))
	t.set_color("font_color", "TooltipLabel", ink)
	t.set_stylebox("scroll", "VScrollBar", box(Color(ink, 0.15), Color(0, 0, 0, 0), 6, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(K.pal("tangerine"), ink, 6, 2, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(K.pal("butter"), ink, 6, 2, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(K.pal("butter"), ink, 6, 2, 0))
	_theme = t
	return t

static func btn_style(base: Color, state: String) -> StyleBoxFlat:
	var c: Color = base
	var lip: int = 7
	var top: int = 8
	match state:
		"hover":
			c = base.lightened(0.15)
		"pressed":
			c = base.darkened(0.15)
			lip = 3
			top = 12
		"disabled":
			c = base.lerp(Color(0.7, 0.7, 0.7), 0.6)
		"focus":
			c = base
	var sb: StyleBoxFlat = box(c, K.pal("ink"), 14, 3, 8)
	sb.border_width_bottom = lip + 3
	sb.content_margin_top = top - 2
	sb.content_margin_bottom = lip + 7
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	if state == "focus":
		sb.draw_center = false
	return sb

static func style_btn(b: Button, color_name: String) -> void:
	var base: Color = K.pal(color_name)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, btn_style(base, st))
	b.add_theme_stylebox_override("focus", btn_style(base, "focus"))

static func panel(color_name: String = "cream", pad: int = 10, radius: int = 18) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(K.pal(color_name), K.pal("ink"), radius, 4, pad))
	return p

static func label(text: String, size: int = 17, color: Color = Color(0, 0, 0, 0), align: int = 0) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	return l

static func btn(text: String, color_name: String = "cream2", cb: Callable = Callable()) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_btn(b, color_name)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func hold_btn(text: String, color_name: String, cb: Callable) -> Button:
	## cb(bool pressed)
	var b: Button = btn(text, color_name)
	b.button_down.connect(func(): cb.call(true))
	b.button_up.connect(func(): cb.call(false))
	return b

static func toggle_btn(text: String, color_name: String, cb: Callable) -> Button:
	var b: Button = btn(text, color_name)
	b.toggle_mode = true
	b.toggled.connect(func(on: bool): cb.call(on))
	return b

static func vbox(sep: int = 6) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 6) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func grid(cols: int, hsep: int = 6, vsep: int = 6) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", hsep)
	g.add_theme_constant_override("v_separation", vsep)
	return g

static func spacer(expand: bool = true, size: Vector2 = Vector2.ZERO) -> Control:
	var c: Control = Control.new()
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = size
	return c

static func fill(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func fillh(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func titled(title: String, color_name: String, content: Control) -> PanelContainer:
	## A cream panel with a coloured title pill.
	var p: PanelContainer = panel("cream", 8, 16)
	var v: VBoxContainer = vbox(4)
	p.add_child(v)
	var t: PanelContainer = PanelContainer.new()
	t.add_theme_stylebox_override("panel", box(K.pal(color_name), K.pal("ink"), 12, 3, 4))
	var l: Label = label(title, 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child(l)
	v.add_child(t)
	v.add_child(content)
	return p

static func bg_color(c: Control, color: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(r)
	c.move_child(r, 0)
	return r

static func angle_deg(rad: float) -> int:
	return int(round(rad_to_deg(rad) + 90.0 + 720.0)) % 360
