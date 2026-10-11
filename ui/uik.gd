class_name UIK
extends RefCounted
## The hand-inked cartoon design system (v3).
## Look: cream paper, thick wobbly ink outlines, hard ink drop shadows, flat vintage colours.
## Type: Luckiest Guy for headings and buttons, Patrick Hand for everything else.
## All frames come from generated SVG art (tools/make_art.py) 9-sliced by InkBox.

const GAP: int = 12
const BODY: int = 22
const HEAD: int = 26

static var _fonts: Dictionary = {}
static var _theme: Theme = null

# ---------------------------------------------------------------- colour + fonts

static func c(n: String) -> Color:
	return K.pal(n)

static func ink() -> Color:
	return K.pal("ink")

static func font(kind: String = "body") -> Font:
	if not _fonts.has(kind):
		var path: String = "res://assets/fonts/LuckiestGuy.ttf" if kind == "head" else "res://assets/fonts/PatrickHand.ttf"
		var f: FontFile = FontFile.new()
		f.data = FileAccess.get_file_as_bytes(path)
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_fonts[kind] = f
	return _fonts[kind]

static func light(col: Color) -> bool:
	return col.get_luminance() > 0.5

static func text_on(col: Color) -> Color:
	return ink() if light(col) else c("white")

static func _sfx_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Sfx") if tree != null else null

static func sfx(name: String) -> void:
	## play a sound if the Sfx autoload is running (it isn't in tool scripts)
	var s: Node = _sfx_node()
	if s != null:
		s.call("play", name)

static func speak(text: String) -> void:
	var s: Node = _sfx_node()
	if s != null:
		s.call("speak", text)

static func stop_speech() -> void:
	if DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()

static func speaking() -> bool:
	if DisplayServer.get_name() == "headless" or not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return false
	return DisplayServer.tts_is_speaking()

static func sound_on() -> bool:
	var s: Node = _sfx_node()
	return s != null and bool(s.get("enabled"))

static func set_sound(on: bool) -> void:
	var s: Node = _sfx_node()
	if s != null:
		s.set("enabled", on)

static func voice_on() -> bool:
	var s: Node = _sfx_node()
	return s != null and bool(s.get("tts_on"))

static func set_voice(on: bool) -> void:
	var s: Node = _sfx_node()
	if s != null:
		s.set("tts_on", on)
	if not on:
		stop_speech()

static func set_grain(on: bool) -> void:
	Film.enabled = on
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		for f in tree.get_nodes_in_group("film"):
			(f as CanvasLayer).visible = on

# ---------------------------------------------------------------- theme

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font("body")
	t.default_font_size = BODY
	t.set_color("font_color", "Label", ink())
	for bt in ["Button", "OptionButton", "CheckBox"]:
		_button_theme(t, bt, "cream")
	t.set_color("font_color", "LineEdit", ink())
	t.set_color("font_placeholder_color", "LineEdit", Color(ink(), 0.4))
	t.set_color("caret_color", "LineEdit", ink())
	t.set_stylebox("normal", "LineEdit", Art.box("well", Color.WHITE, [4, 2, 4, 2]))
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_font_size("font_size", "LineEdit", 24)
	var tip: InkBox = Art.box("panel_small")
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", ink())
	t.set_stylebox("panel", "PopupMenu", Art.box("panel"))
	t.set_color("font_color", "PopupMenu", ink())
	t.set_color("font_hover_color", "PopupMenu", c("red"))
	t.set_font_size("font_size", "PopupMenu", 22)
	var sb_grab: StyleBoxFlat = StyleBoxFlat.new()
	sb_grab.bg_color = Color(ink(), 0.55)
	sb_grab.set_corner_radius_all(6)
	sb_grab.content_margin_left = 6
	sb_grab.content_margin_right = 6
	var sb_track: StyleBoxFlat = StyleBoxFlat.new()
	sb_track.bg_color = Color(ink(), 0.08)
	sb_track.set_corner_radius_all(6)
	sb_track.content_margin_left = 6
	sb_track.content_margin_right = 6
	for sbn in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", sbn, sb_grab)
		t.set_stylebox("grabber_highlight", sbn, sb_grab)
		t.set_stylebox("grabber_pressed", sbn, sb_grab)
		t.set_stylebox("scroll", sbn, sb_track)
	_theme = t
	return t

static func _button_theme(t: Theme, type: String, col: String) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, type, Art.box("btn_%s_%s" % [col, st]))
	t.set_stylebox("hover_pressed", type, Art.box("btn_%s_pressed" % col))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_font("font", type, font("head"))
	t.set_font_size("font_size", type, 20)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(fc, type, ink())
	t.set_color("font_disabled_color", type, Color(ink(), 0.4))

# ---------------------------------------------------------------- text

static func label(text: String, size: int = BODY, col: Color = Color(0, 0, 0, 0), align: int = 0) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ink() if col.a == 0.0 else col)
	l.horizontal_alignment = align as HorizontalAlignment
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func head(text: String, size: int = HEAD, col: Color = Color(0, 0, 0, 0), align: int = 0) -> Label:
	var l: Label = label(text, size, col, align)
	l.add_theme_font_override("font", font("head"))
	return l

static func title(text: String, size: int = 56, col: Color = Color(0, 0, 0, 0), align: int = 0) -> Label:
	## big cartoon title: coloured letters, thick ink outline, hard ink shadow
	var l: Label = head(text, size, c("cream") if col.a == 0.0 else col, align)
	l.add_theme_color_override("font_outline_color", ink())
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.add_theme_color_override("font_shadow_color", ink())
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 12))
	l.add_theme_constant_override("shadow_outline_size", maxi(6, size / 5))
	return l

static func wrapped(l: Label, min_w: float = 0.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if min_w > 0.0:
		l.custom_minimum_size.x = min_w
	return l

static func para(text: String, size: int = BODY, col: Color = Color(0, 0, 0, 0)) -> Label:
	return wrapped(label(text, size, col))

# ---------------------------------------------------------------- buttons

static func style_btn(b: Button, col: String) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, Art.box("btn_%s_%s" % [col, st]))
	b.add_theme_stylebox_override("hover_pressed", Art.box("btn_%s_pressed" % col))
	var fc: Color = text_on(c(col))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	for k2 in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k2, fc)
	if not light(c(col)):
		b.add_theme_color_override("font_outline_color", ink())
		b.add_theme_constant_override("outline_size", 6)
	else:
		b.add_theme_constant_override("outline_size", 0)

static func btn(text: String, col: String = "cream", cb: Callable = Callable(), icon_name: String = "", size: int = 22) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("head"))
	b.add_theme_font_size_override("font_size", size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_btn(b, col)
	if icon_name != "":
		b.icon = Art.tex("icon_" + icon_name, float(size + 2) / 64.0)
		b.expand_icon = false
		b.add_theme_constant_override("h_separation", 8)
	if cb.is_valid():
		b.pressed.connect(cb)
	b.button_down.connect(func(): UIK.sfx("click"))
	return b

static func toggle(text: String, col: String, cb: Callable, icon_name: String = "", size: int = 22) -> Button:
	## cream when off; lights up in `col` when on
	var b: Button = btn(text, "cream", Callable(), icon_name, size)
	b.toggle_mode = true
	var on_n: InkBox = Art.box("btn_%s_pressed" % col)
	b.add_theme_stylebox_override("pressed", on_n)
	b.add_theme_stylebox_override("hover_pressed", on_n)
	var fc: Color = text_on(c(col))
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_hover_pressed_color", fc)
	b.add_theme_color_override("icon_pressed_color", fc)
	b.toggled.connect(func(v: bool): cb.call(v))
	return b

# ---------------------------------------------------------------- containers

static func panel(kind: String = "panel", pad: Array = []) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.box(kind, Color.WHITE, pad))
	return p

static func window(title_text: String, col: String = "red", icon_name: String = "", kind: String = "panel") -> Array:
	## a card with a ribbon banner across its top edge. Returns [root VBox, body VBox].
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "window"
	v.add_theme_constant_override("separation", -24)
	var rib: PanelContainer = ribbon(title_text, col, icon_name)
	rib.z_index = 1
	var rm: MarginContainer = MarginContainer.new()
	rm.add_theme_constant_override("margin_left", 10)
	rm.add_child(rib)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var card: PanelContainer = panel(kind, [0, 14, 0, 0])
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(body)
	v.add_child(rm)
	v.add_child(card)
	return [v, body]

static func ribbon(text: String, col: String = "red", icon_name: String = "", size: int = 20) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.box("ribbon_" + col))
	var h: HBoxContainer = hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	var fc: Color = text_on(c(col))
	if icon_name != "":
		h.add_child(icon(icon_name, size + 2, fc))
	var l: Label = head(text, size, fc)
	l.name = "title"
	if not light(c(col)):
		l.add_theme_color_override("font_outline_color", ink())
		l.add_theme_constant_override("outline_size", 6)
	h.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func chip(text: String, col: String = "cream", icon_name: String = "", size: int = 18) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.box("chip_" + col))
	var h: HBoxContainer = hbox(5)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	var fc: Color = text_on(c(col))
	if icon_name != "":
		var ic: TextureRect = icon(icon_name, size, fc)
		ic.name = "icon"
		h.add_child(ic)
	var l: Label = head(text, size, fc)
	l.name = "text"
	h.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func set_chip(p: PanelContainer, text: String, col: String = "") -> void:
	var l: Label = p.find_child("text", true, false)
	if l != null:
		l.text = text
	if col != "" and p.get_meta("col", "") != col:
		p.set_meta("col", col)
		p.add_theme_stylebox_override("panel", Art.box("chip_" + col))
		var fc: Color = text_on(c(col))
		if l != null:
			l.add_theme_color_override("font_color", fc)
		var ic: TextureRect = p.find_child("icon", true, false)
		if ic != null:
			ic.modulate = fc

static func vbox(sep: int = GAP) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = GAP) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func grid(cols: int, sep: int = GAP) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g

static func margin(child: Control, m: int) -> MarginContainer:
	var mc: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc

static func spacer(expand: bool = true, min_size: Vector2 = Vector2.ZERO) -> Control:
	var s: Control = Control.new()
	s.custom_minimum_size = min_size
	if expand:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

static func center(child: Control) -> CenterContainer:
	var cc: CenterContainer = CenterContainer.new()
	cc.add_child(child)
	return cc

# ---------------------------------------------------------------- pictures

static func icon(name: String, px: int = 24, tint: Color = Color(0, 0, 0, 0)) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = Art.sized("icon_" + name, px)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = ink() if tint.a == 0.0 else tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func pic(name: String, px: Vector2) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = Art.sized(name, px.x)
	r.custom_minimum_size = px
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func portrait(name: String, px: int = 96) -> TextureRect:
	return pic("portrait_" + name, Vector2(px, px))

static func speech(text: String, who_portrait: String, who: String = "", px: int = 96, size: int = 24) -> HBoxContainer:
	## a character with a speech bubble
	var h: HBoxContainer = hbox(4)
	var pr: TextureRect = portrait(who_portrait, px)
	pr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(pr)
	var bub: PanelContainer = panel("panel_small", [6, 2, 6, 2])
	bub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v: VBoxContainer = vbox(0)
	bub.add_child(v)
	if who != "":
		v.add_child(head(who, 18, c("red")))
	var l: Label = para(text, size)
	l.name = "text"
	v.add_child(l)
	h.add_child(bub)
	return h

static func bg(parent: Control) -> Paper:
	var p: Paper = Paper.new()
	p.show_behind_parent = true
	parent.add_child(p)
	parent.move_child(p, 0)
	return p
