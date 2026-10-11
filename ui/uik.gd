class_name UIK
extends RefCounted
## "Two Point in Space" design system.
## Warm white cards, saturated candy buttons with a darker lip, tinted borders (never black),
## soft drop shadows, Fredoka headings, Nunito body text, SVG icons and character portraits.

const RADIUS: int = 18
const RADIUS_S: int = 12
const GAP: int = 10
const PAD: int = 14

static var _theme: Theme = null
static var _fonts: Dictionary = {}
static var _tex: Dictionary = {}

static func c(n: String) -> Color:
	return K.pal(n)

# ---------------------------------------------------------------- fonts

static func font_head() -> Font:
	return _font("Fredoka", 600)

static func font_body() -> Font:
	return _font("Nunito", 700)

static func font_bold() -> Font:
	return _font("Nunito", 900)

static func font() -> Font:
	return font_body()

static func _font(family: String, weight: int) -> Font:
	var key: String = "%s%d" % [family, weight]
	if _fonts.has(key):
		return _fonts[key]
	var base: FontFile = load("res://assets/fonts/%s.ttf" % family)
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[key] = fv
	return fv

# ---------------------------------------------------------------- textures (SVG rasterized at runtime, cached)

static func tex(name: String, px: int = 64) -> Texture2D:
	var key: String = "%s@%d" % [name, px]
	if _tex.has(key):
		return _tex[key]
	var path: String = "res://assets/art/%s.svg" % name
	if not FileAccess.file_exists(path):
		return null
	var buf: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var img: Image = Image.new()
	var native: float = 64.0 if name.begins_with("icon_") else 256.0
	if name.begins_with("art_"):
		native = 512.0
	img.load_svg_from_buffer(buf, float(px) / native)
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

static func icon(name: String, px: int = 48) -> Texture2D:
	return tex("icon_" + name, px)

static func portrait_tex(name: String, px: int = 128) -> Texture2D:
	return tex("portrait_" + name, px)

# ---------------------------------------------------------------- style boxes

static func sb(bg: Color, radius: int = RADIUS, border: Color = Color(0, 0, 0, 0), bw: int = 0, pad: int = PAD, shadow: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.0
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	if shadow > 0:
		s.shadow_color = Color(0.06, 0.03, 0.18, 0.28)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	return s

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = RADIUS, bw: int = 0, pad: int = PAD) -> StyleBoxFlat:
	## tinted border helper used by custom-drawn widgets
	var b: Color = border if border.a > 0.0 and border != K.pal("ink") else bg.darkened(0.22)
	return sb(bg, radius, b, bw, pad)

static func card_style(tint: String = "card") -> StyleBoxFlat:
	var bg: Color = c(tint)
	return sb(bg, RADIUS, bg.darkened(0.1), 2, PAD, 10)

static func btn_style(base: Color, state: String) -> StyleBoxFlat:
	var top: Color = base
	var lip: int = 6
	var shift: int = 0
	match state:
		"hover":
			top = base.lightened(0.12)
		"pressed":
			top = base.darkened(0.06)
			lip = 2
			shift = 4
		"disabled":
			top = base.lerp(Color(0.80, 0.78, 0.84), 0.6)
	var s: StyleBoxFlat = sb(top, RADIUS_S + 2, Color(0, 0, 0, 0), 0, 0, 0)
	s.border_color = base.darkened(0.28) if state != "disabled" else top.darkened(0.15)
	s.border_width_bottom = lip
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 7 + shift
	s.content_margin_bottom = 7 + lip - shift
	if state != "pressed" and state != "disabled":
		s.shadow_color = Color(0.06, 0.03, 0.18, 0.22)
		s.shadow_size = 4
		s.shadow_offset = Vector2(0, 3)
	if state == "focus":
		s.draw_center = false
		s.border_width_bottom = 0
		s.shadow_size = 0
	return s

static func text_on(bg: Color) -> Color:
	return c("ink") if bg.get_luminance() > 0.72 else Color.WHITE

# ---------------------------------------------------------------- theme

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font_body()
	t.default_font_size = 17
	var ink: Color = c("ink")
	t.set_color("font_color", "Label", ink)
	for cls in ["Button", "CheckButton", "MenuButton"]:
		t.set_font("font", cls, font_head())
		t.set_font_size("font_size", cls, 18)
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(col, cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.7))
		t.set_constant("h_separation", cls, 8)
		t.set_constant("icon_max_width", cls, 26)
	var nb: Color = c("blue")
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(st, "Button", btn_style(nb, st))
	var opt_n: StyleBoxFlat = sb(Color.WHITE, RADIUS_S, c("well").darkened(0.18), 2, 8)
	opt_n.content_margin_left = 12
	t.set_stylebox("normal", "OptionButton", opt_n)
	t.set_stylebox("hover", "OptionButton", sb(Color.WHITE, RADIUS_S, c("blue"), 2, 8))
	t.set_stylebox("pressed", "OptionButton", opt_n)
	t.set_stylebox("focus", "OptionButton", sb(Color(0, 0, 0, 0), RADIUS_S, c("blue"), 2, 8))
	t.set_stylebox("disabled", "OptionButton", sb(c("well"), RADIUS_S, c("well").darkened(0.1), 2, 8))
	for col2 in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(col2, "OptionButton", ink)
	t.set_color("font_disabled_color", "OptionButton", c("ink_soft"))
	t.set_font("font", "OptionButton", font_body())
	t.set_font_size("font_size", "OptionButton", 16)
	t.set_stylebox("panel", "PopupMenu", sb(Color.WHITE, RADIUS_S, c("well").darkened(0.15), 2, 8, 8))
	t.set_stylebox("hover", "PopupMenu", sb(c("blue").lightened(0.6), 8, Color(0, 0, 0, 0), 0, 4))
	t.set_color("font_color", "PopupMenu", ink)
	t.set_color("font_hover_color", "PopupMenu", ink)
	t.set_font("font", "PopupMenu", font_body())
	t.set_font_size("font_size", "PopupMenu", 16)
	t.set_stylebox("normal", "LineEdit", sb(Color.WHITE, RADIUS_S, c("well").darkened(0.2), 2, 10))
	t.set_stylebox("focus", "LineEdit", sb(Color(0, 0, 0, 0), RADIUS_S, c("blue"), 3, 10))
	t.set_stylebox("read_only", "LineEdit", sb(c("well"), RADIUS_S, c("well").darkened(0.15), 2, 10))
	t.set_color("font_color", "LineEdit", ink)
	t.set_color("caret_color", "LineEdit", c("blue"))
	t.set_color("font_placeholder_color", "LineEdit", c("ink_soft"))
	t.set_font_size("font_size", "LineEdit", 18)
	t.set_stylebox("panel", "PanelContainer", card_style())
	t.set_stylebox("panel", "Panel", card_style())
	t.set_stylebox("panel", "TooltipPanel", sb(ink, 10, Color(0, 0, 0, 0), 0, 8))
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	t.set_font_size("font_size", "TooltipLabel", 15)
	for sc in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sc, sb(Color(ink, 0.08), 6, Color(0, 0, 0, 0), 0, 0))
		t.set_stylebox("grabber", sc, sb(c("blue"), 6, Color(0, 0, 0, 0), 0, 0))
		t.set_stylebox("grabber_highlight", sc, sb(c("blue").lightened(0.2), 6, Color(0, 0, 0, 0), 0, 0))
		t.set_stylebox("grabber_pressed", sc, sb(c("blue").darkened(0.1), 6, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("background", "ProgressBar", sb(c("well"), 8, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("fill", "ProgressBar", sb(c("green"), 8, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("separator", "HSeparator", sb(Color(ink, 0.1), 2, Color(0, 0, 0, 0), 0, 0))
	t.set_constant("separation", "HSeparator", 12)
	_theme = t
	return t

# ---------------------------------------------------------------- building blocks

static func label(text: String, size: int = 17, color: Color = Color(0, 0, 0, 0), align: int = 0) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	return l

static func heading(text: String, size: int = 24, color: Color = Color(0, 0, 0, 0), align: int = 0) -> Label:
	var l: Label = label(text, size, color if color.a > 0.0 else c("ink"), align)
	l.add_theme_font_override("font", font_head())
	return l

static func title(text: String, size: int = 40, color: Color = Color.WHITE, outline: Color = Color(0, 0, 0, 0)) -> Label:
	var l: Label = heading(text, size, color)
	var oc: Color = outline if outline.a > 0.0 else c("plum").darkened(0.3)
	l.add_theme_color_override("font_outline_color", oc)
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.15, 0.45))
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 14))
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l

static func wrapped(l: Label, min_w: float = 0.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if min_w > 0.0:
		l.custom_minimum_size.x = min_w
	return l

static func _alias(n: String) -> String:
	match n:
		"cream", "cream2":
			return "neutral"
	return n

static func style_btn(b: Button, color_name: String) -> void:
	var base: Color = c(_alias(color_name))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, btn_style(base, st))
	var fc: Color = text_on(base)
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(col, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.6))
	for ic in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(ic, fc)
	b.add_theme_color_override("icon_disabled_color", Color(fc, 0.6))

static func btn(text: String, color_name: String = "blue", cb: Callable = Callable(), icon_name: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if icon_name != "":
		b.icon = icon(icon_name, 48)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 22)
	style_btn(b, color_name)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func icon_btn(icon_name: String, color_name: String = "blue", cb: Callable = Callable(), tip: String = "") -> Button:
	var b: Button = btn("", color_name, cb, icon_name)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(50, 48)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 24)
	return b

static func hold_btn(text: String, color_name: String, cb: Callable, icon_name: String = "") -> Button:
	## cb(bool pressed)
	var b: Button = btn(text, color_name, Callable(), icon_name)
	b.button_down.connect(func(): cb.call(true))
	b.button_up.connect(func(): cb.call(false))
	return b

static func toggle_btn(text: String, color_name: String, cb: Callable, icon_name: String = "") -> Button:
	var b: Button = btn(text, color_name, Callable(), icon_name)
	b.toggle_mode = true
	var base: Color = c(_alias(color_name))
	# neutral toggles light up yellow when on; coloured ones press in and darken
	var on_col: Color = c("yellow") if _alias(color_name) == "neutral" else base.darkened(0.14)
	var on: StyleBoxFlat = btn_style(on_col, "pressed")
	on.border_width_top = 0
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_pressed_color", text_on(on_col))
	b.add_theme_color_override("font_hover_pressed_color", text_on(on_col))
	b.add_theme_color_override("icon_pressed_color", text_on(on_col))
	b.toggled.connect(func(v: bool): cb.call(v))
	return b

static func panel(color_name: String = "card", pad: int = PAD, radius: int = RADIUS) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var bg: Color = c(_alias_panel(color_name))
	p.add_theme_stylebox_override("panel", sb(bg, radius, bg.darkened(0.1), 2, pad, 8))
	return p

static func _alias_panel(n: String) -> String:
	match n:
		"cream", "cream2":
			return "card"
	return n

static func well(pad: int = 10) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(c("well"), RADIUS_S, Color(0, 0, 0, 0), 0, pad))
	return p

static func window(title_text: String, color_name: String = "blue", icon_name: String = "", pad: int = 12) -> Array:
	## A card with a coloured header ribbon. Returns [PanelContainer, VBoxContainer body].
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(c("card"), RADIUS, c("card").darkened(0.1), 2, 0, 10))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var head: PanelContainer = PanelContainer.new()
	head.name = "head"
	var hc: Color = c(color_name)
	var hs: StyleBoxFlat = sb(hc, RADIUS, Color(0, 0, 0, 0), 0, 0, 0)
	hs.corner_radius_bottom_left = 0
	hs.corner_radius_bottom_right = 0
	hs.border_width_bottom = 4
	hs.border_color = hc.darkened(0.22)
	hs.content_margin_left = 12
	hs.content_margin_right = 12
	hs.content_margin_top = 5
	hs.content_margin_bottom = 5
	head.add_theme_stylebox_override("panel", hs)
	var hb: HBoxContainer = hbox(8)
	hb.name = "row"
	head.add_child(hb)
	if icon_name != "":
		hb.add_child(icon_rect(icon_name, 22, text_on(hc)))
	var tl: Label = heading(title_text, 18, text_on(hc))
	tl.name = "title"
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(tl)
	v.add_child(head)
	var m: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, pad)
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(m)
	var body: VBoxContainer = vbox(8)
	m.add_child(body)
	return [p, body]

static func titled(title_text: String, color_name: String, content: Control, icon_name: String = "") -> PanelContainer:
	var w: Array = window(title_text, color_name, icon_name, 10)
	(w[1] as VBoxContainer).add_child(content)
	return w[0]

static func icon_rect(icon_name: String, px: int = 32, tint: Color = Color.WHITE) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = icon(icon_name, px * 2)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func badge(icon_name: String, color_name: String, px: int = 44) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var col: Color = c(color_name)
	p.add_theme_stylebox_override("panel", sb(col, px / 2, col.darkened(0.25), 3, int(px * 0.16), 0))
	p.custom_minimum_size = Vector2(px, px)
	p.add_child(icon_rect(icon_name, int(px * 0.56), text_on(col)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func portrait(name: String, px: int = 96) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = portrait_tex(name, px * 2)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func chip(text: String, color_name: String = "blue", icon_name: String = "", size: int = 15) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var col: Color = c(color_name)
	var s: StyleBoxFlat = sb(col, 99, Color(0, 0, 0, 0), 0, 0, 0)
	s.content_margin_left = 10
	s.content_margin_right = 12
	s.content_margin_top = 3
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	var h: HBoxContainer = hbox(5)
	p.add_child(h)
	if icon_name != "":
		h.add_child(icon_rect(icon_name, size + 2, text_on(col)))
	var l: Label = label(text, size, text_on(col))
	l.add_theme_font_override("font", font_bold())
	l.name = "text"
	h.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func speech(text: String, portrait_name: String, who: String = "", px: int = 84) -> HBoxContainer:
	var h: HBoxContainer = hbox(10)
	var pr: TextureRect = portrait(portrait_name, px)
	pr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(pr)
	var bub: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = sb(Color.WHITE, RADIUS, c("well").darkened(0.15), 2, 12, 6)
	s.corner_radius_top_left = 4
	bub.add_theme_stylebox_override("panel", s)
	bub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = vbox(2)
	bub.add_child(v)
	if who != "":
		v.add_child(heading(who, 16, c("blue").darkened(0.2)))
	var l: Label = wrapped(label(text, 17))
	l.name = "text"
	v.add_child(l)
	h.add_child(bub)
	return h

static func vbox(sep: int = GAP) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = GAP) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func grid(cols: int, hsep: int = GAP, vsep: int = GAP) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", hsep)
	g.add_theme_constant_override("v_separation", vsep)
	return g

static func margin(child: Control, m: int = 12) -> MarginContainer:
	var mc: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc

static func spacer(expand: bool = true, size: Vector2 = Vector2.ZERO) -> Control:
	var cc: Control = Control.new()
	if expand:
		cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cc.custom_minimum_size = size
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cc

static func fill(cc: Control) -> Control:
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return cc

static func fillh(cc: Control) -> Control:
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cc

static func bg_color(cc: Control, color: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(r)
	cc.move_child(r, 0)
	return r

static func space_bg(cc: Control) -> Control:
	var bg: SpaceBackdrop = SpaceBackdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(bg)
	cc.move_child(bg, 0)
	return bg

static func angle_deg(rad: float) -> int:
	return int(round(rad_to_deg(rad) + 90.0 + 720.0)) % 360

static func seat_color(seat: String) -> String:
	return str(K.SEAT_INFO.get(seat, {"color": "blue"}).color)
