class_name CaptainUI
extends Control
## The Captain's bridge, made to be put on a TV. The chart fills a big viewscreen: where everything is, the mission
## as numbered flags along the route, trouble pinned where it is. Under it sits a row of consoles, one per crew
## member, each with the one instrument that shows what that job knows and the chart doesn't (the wheel, the
## throttle and heat, the torpedo, the scan, the shield's power, the repair), and the ship's hull in the middle.
## The captain touches NOTHING: they look, and they shout.

signal menu_pressed

const SEATS_LEFT: Array = ["helm", "engines", "weapons"]
const SEATS_RIGHT: Array = ["sensors", "shields", "engineer"]

var chart: Chart
var screen: Control
var plaque_title: Label
var plaque_time: Label
var plaque_pay: Label
var igor_box: HBoxContainer
var igor_pic: Face
var igor_text: Label
var toast_chip: PanelContainer
var seat_row: HBoxContainer
var consoles: Dictionary = {}     # seat (or "ship") -> {panel, face, inst, status}
var _flip: bool = false
var _igor_tw: Tween
var _toast_tw: Tween
var _seats_sig: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wall: ColorRect = ColorRect.new()
	wall.color = Color("#3b2c21")
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall.offset_left = -10
	wall.offset_top = -10
	wall.offset_right = 10
	wall.offset_bottom = 10
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall)
	_build_screen()
	_build_plaque()
	_build_consoles()

# ---------------------------------------------------------------- building

static func _box(bg: Color, border: Color, bw: int, radius: int, draw_bg: bool = true) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.draw_center = draw_bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb

func _build_screen() -> void:
	screen = Control.new()
	screen.name = "viewscreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.offset_left = 14
	screen.offset_right = -14
	screen.offset_top = 16
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	# a brass ring, then the screen itself (which clips the chart to its rounded corners), then the black bezel
	var ring: Panel = Panel.new()
	ring.add_theme_stylebox_override("panel", _box(K.pal("mustard"), UIK.ink(), 4, 40))
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = -9
	ring.offset_top = -9
	ring.offset_right = 9
	ring.offset_bottom = 9
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(ring)
	var mask: Panel = Panel.new()
	mask.add_theme_stylebox_override("panel", _box(Color("#e9dcbb"), Color("#e9dcbb"), 0, 32))
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(mask)
	chart = Chart.new()
	chart.big = true
	chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.add_child(chart)
	var bezel: Panel = Panel.new()
	bezel.add_theme_stylebox_override("panel", _box(Color.TRANSPARENT, UIK.ink(), 7, 34, false))
	bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(bezel)
	# IGOR talks from the top-left corner of the screen
	igor_box = UIK.hbox(6)
	igor_box.position = Vector2(20, 20)
	igor_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	igor_box.modulate.a = 0.0
	screen.add_child(igor_box)
	igor_pic = UIK.portrait("igor", 50)
	igor_pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	igor_box.add_child(igor_pic)
	var bubble: PanelContainer = PanelContainer.new()
	var bsb: StyleBoxFlat = _box(Color(K.pal("white"), 0.96), UIK.ink(), 3, 16)
	bsb.corner_radius_top_left = 4
	bsb.content_margin_left = 12
	bsb.content_margin_right = 12
	bsb.content_margin_top = 6
	bsb.content_margin_bottom = 7
	bubble.add_theme_stylebox_override("panel", bsb)
	bubble.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	igor_box.add_child(bubble)
	igor_text = UIK.label("", 19)
	igor_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	igor_text.custom_minimum_size = Vector2(380, 0)
	igor_text.max_lines_visible = 3
	igor_text.add_theme_constant_override("line_spacing", -5)
	bubble.add_child(igor_text)
	# the latest news, low in the middle of the screen
	toast_chip = UIK.chip("", "cream", "", 20)
	toast_chip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_chip.offset_bottom = -62
	toast_chip.modulate.a = 0.0
	screen.add_child(toast_chip)
	# when this player holds more than one seat: little buttons to hop between them
	seat_row = UIK.hbox(4)
	seat_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	seat_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	seat_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	seat_row.offset_right = -22
	seat_row.offset_bottom = -16
	screen.add_child(seat_row)

func _build_plaque() -> void:
	var pl: PanelContainer = PanelContainer.new()
	pl.name = "plaque"
	var sb: StyleBoxFlat = _box(K.pal("mustard"), UIK.ink(), 4, 14)
	sb.content_margin_left = 18
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.shadow_color = UIK.ink()
	sb.shadow_offset = Vector2(3, 4)
	sb.shadow_size = 1
	pl.add_theme_stylebox_override("panel", sb)
	pl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pl.offset_top = 0
	add_child(pl)
	var h: HBoxContainer = UIK.hbox(14)
	pl.add_child(h)
	plaque_title = UIK.head("", 22)
	plaque_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(plaque_title)
	plaque_time = UIK.head("", 22, K.pal("red2"))
	plaque_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(plaque_time)
	plaque_pay = UIK.label("", 18)
	plaque_pay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(plaque_pay)
	h.add_child(Voice.Bar.new())
	var mb: Button = UIK.btn("", "cream", func(): menu_pressed.emit(), "menu", 18)
	mb.tooltip_text = "Menu (Esc)"
	mb.custom_minimum_size = Vector2(40, 36)
	mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mb)

func _console_h() -> float:
	return clampf(size.y * 0.215, 132.0, 200.0)

func _build_consoles() -> void:
	var row: HBoxContainer = UIK.hbox(8)
	row.name = "consoles"
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_left = 4
	row.offset_right = -4
	row.offset_bottom = 0
	add_child(row)
	for st in SEATS_LEFT:
		row.add_child(_console(st))
	row.add_child(_console("ship"))
	for st2 in SEATS_RIGHT:
		row.add_child(_console(st2))
	resized.connect(_relayout)
	_relayout.call_deferred()

func _relayout() -> void:
	var ch: float = _console_h()
	var row: Control = get_node("consoles")
	row.offset_top = -ch
	screen.offset_bottom = -(ch + 22.0)

func _console(st: String) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = _box(K.pal("cream"), UIK.ink(), 4, 14)
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if st == "ship":
		p.size_flags_stretch_ratio = 1.25
	p.clip_contents = true
	var v: VBoxContainer = UIK.vbox(0)
	p.add_child(v)
	var head: HBoxContainer = UIK.hbox(4)
	v.add_child(head)
	var face: Face = UIK.portrait("captain" if st == "ship" else st, 32)
	head.add_child(face)
	var nm: Label = UIK.head("THE SHIP" if st == "ship" else K.seat_name(st).to_upper(), 15,
		K.pal("red") if st == "ship" else K.seat_color(st).darkened(0.25))
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(nm)
	var inst: Instrument = Instrument.new()
	inst.kind = st
	inst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inst.custom_minimum_size = Vector2(110, 56)
	v.add_child(inst)
	var status: Label = UIK.label("", 15)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.custom_minimum_size = Vector2(60, 0)
	v.add_child(status)
	consoles[st] = {"panel": p, "face": face, "inst": inst, "status": status}
	return p

# ---------------------------------------------------------------- live

func apply(v: Dictionary, com: Dictionary) -> void:
	var feats: Dictionary = com.get("features", {})
	v["_t"] = float(com.get("t", 0.0))
	chart.v = v
	# the "chart's upside down" glitch really does turn the chart upside down, lettering and all
	var flip: bool = bool(v.get("flip", false))
	chart.pivot_offset = chart.size / 2.0
	if flip != _flip:
		_flip = flip
		var tw: Tween = chart.create_tween()
		tw.tween_property(chart, "rotation", PI if flip else 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# the plaque
	var mi: Dictionary = com.get("mission", {})
	var sh: Dictionary = com.get("shift", {})
	plaque_title.text = str(mi.get("title", "")).to_upper()
	plaque_time.text = K.fmt_time(float(mi.get("time", 0.0)))
	if sh.is_empty():
		plaque_pay.text = "mission %d" % int(mi.get("num", 0))
	else:
		plaque_pay.text = "job %d of %d · %s of %s" % [mini(int(sh.n), int(sh.of)), int(sh.of), Screens.money(int(sh.earned)), Screens.money(int(sh.rent))]
	# the consoles
	var bd: Dictionary = v.get("board", {})
	var inst: Dictionary = v.get("inst", {})
	var crew: Dictionary = v.get("crew", {})
	var data: Dictionary = inst.duplicate()
	data["feats"] = feats
	data["engine_heat"] = float(bd.get("engine_heat", 0.0))
	data["gun_heat"] = float(bd.get("gun_heat", 0.0))
	data["draw"] = float(bd.get("draw", 0.0))
	data["cap"] = float(bd.get("cap", 6.0))
	data["blackout"] = bool(bd.get("blackout", false))
	data["pud"] = float(bd.get("pud_mood", 0.0))
	data["pud_out"] = bool(bd.get("pud_out", false))
	data["hull"] = float(com.get("hull", 100.0)) / maxf(1.0, float(com.get("hull_max", 100.0)))
	data["hull_pct"] = int(float(com.get("hull", 100.0)))
	data["systems"] = bd.get("systems", {})
	for st in consoles.keys():
		var c: Dictionary = consoles[st]
		var ins: Instrument = c.inst
		ins.data = data
		ins.odd = st in inst.get("odd", [])
		ins.queue_redraw()
		var cl: Dictionary = crew.get(st, {})
		var al: int = int(cl.get("alert", 0))
		if st == "ship":
			al = 2 if float(data.hull) < 0.35 else (1 if float(data.hull) < 0.6 else 0)
		(c.face as Face).set_mood("panic" if al >= 2 else ("busy" if al == 1 or ins.odd else ""))
		var stl: Label = c.status
		stl.text = _status(st, cl, data)
		stl.tooltip_text = stl.text
		stl.add_theme_color_override("font_color", UIK.c("red") if al >= 2 else (Color("#9a6a10") if al == 1 else UIK.ink()))
		var psb: StyleBoxFlat = (c.panel as PanelContainer).get_theme_stylebox("panel")
		psb.border_color = UIK.c("red") if al >= 2 else UIK.ink()

func _status(st: String, cl: Dictionary, d: Dictionary) -> String:
	var warn: String = str(cl.get("warn", ""))
	match st:
		"ship":
			if bool(d.get("blackout", false)):
				return "BLACKOUT!"
			return "Pudding is LOOSE!" if bool(d.get("pud_out", false)) else ""
		"helm":
			return warn if warn != "" else str(cl.get("text", "")).get_slice(" · ", 0)
		"engines":
			return warn if warn != "" else "Throttle %d%%" % int(float(d.get("throttle", 0.0)) * 100.0)
		"weapons":
			if warn != "":
				return warn
			return "FIRING" if bool(d.get("firing", false)) else "Gun ready"
		"sensors":
			if warn != "":
				return warn
			return "Scanning %d%%" % int(float(d.scan) * 100.0) if float(d.get("scan", -1.0)) >= 0.0 else "Watching"
		"shields":
			return warn if warn != "" else "Blocked %d of %d" % [int(d.get("blocked", 0)), int(d.get("blocked", 0)) + int(d.get("hits", 0))]
		"engineer":
			if warn != "":
				return warn
			var fx: String = str(d.get("fixing", ""))
			return ("Fixing the %s" % Ship.SYS_NAME.get(fx, fx).to_lower()) if fx != "" else "Standing by"
	return warn

func say(who: String, text: String, prio: int) -> void:
	igor_pic.set_who(who)
	igor_pic.set_mood("panic" if prio >= 3 else "busy")
	var names: Dictionary = {"thrupp": "ADMIRAL THRUPP", "pudding": "PUDDING", "gristle": "MA GRISTLE"}
	igor_text.text = (str(names.get(who, who.to_upper())) + ": " if who != "igor" else "") + text
	if _igor_tw != null and _igor_tw.is_valid():
		_igor_tw.kill()
	igor_box.modulate.a = 1.0
	_igor_tw = igor_box.create_tween()
	_igor_tw.tween_interval(clampf(2.5 + text.length() * 0.06, 4.0, 9.0))
	_igor_tw.tween_property(igor_box, "modulate:a", 0.0, 0.6)

func toast(text: String, col: String) -> void:
	UIK.set_chip(toast_chip, text, col)
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	toast_chip.modulate.a = 1.0
	_toast_tw = toast_chip.create_tween()
	_toast_tw.tween_interval(3.0)
	_toast_tw.tween_property(toast_chip, "modulate:a", 0.0, 0.5)

func set_seats(seats: Array, act: String) -> void:
	var sig: String = ",".join(PackedStringArray(seats)) + "/" + act
	if sig == _seats_sig:
		return
	_seats_sig = sig
	for c in seat_row.get_children():
		c.queue_free()
	if seats.size() <= 1:
		return
	for i in K.SEATS.size():
		var s: String = K.SEATS[i]
		if not (s in seats):
			continue
		var on: bool = s == act
		var b: Button = UIK.btn(str(i + 1), str(K.SEAT_INFO[s].color) if on else "cream", func(): Net.send("active", {"seat": s}), str(K.SEAT_INFO[s].icon), 14)
		b.tooltip_text = "%s (key %d)" % [K.seat_name(s), i + 1]
		b.custom_minimum_size = Vector2(48, 36)
		seat_row.add_child(b)

# ---------------------------------------------------------------- one instrument per job

class Instrument extends Control:
	## each crew console's one drawn instrument, designed on a 120 x 78 card and scaled to fit
	var kind: String = ""
	var data: Dictionary = {}
	var odd: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_dt: float) -> void:
		if kind == "sensors" and is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		if data.is_empty():
			return
		var s: float = minf(size.x / 120.0, size.y / 78.0)
		var off: Vector2 = (size - Vector2(120.0, 78.0) * s) / 2.0
		draw_set_transform(off, 0.0, Vector2(s, s))
		match kind:
			"helm":
				_helm()
			"engines":
				_engines()
			"weapons":
				_weapons()
			"sensors":
				_sensors()
			"shields":
				_shields()
			"engineer":
				_engineer()
			"ship":
				_ship()
		if odd:
			_stamp(Vector2(96, 14), "?!", UIK.c("red"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _f(k: String) -> bool:
		return bool(data.get("feats", {}).get(k, false))

	func _text(p: Vector2, t: String, sz: int, col: Color, head: bool = true) -> void:
		var f: Font = UIK.font("head" if head else "body")
		var w: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(f, p - Vector2(w / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

	func _stamp(p: Vector2, t: String, col: Color) -> void:
		var f: Font = UIK.font("head")
		var w: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10.0
		draw_rect(Rect2(p - Vector2(w / 2.0, 10), Vector2(w, 18)), col)
		draw_rect(Rect2(p - Vector2(w / 2.0, 10), Vector2(w, 18)), UIK.ink(), false, 2.0)
		_text(p + Vector2(0, 5), t, 13, Color.WHITE)

	func _bar(r: Rect2, frac: float, col: Color, vertical: bool = false) -> void:
		draw_rect(r, K.pal("paper2"))
		var fr: Rect2 = r
		if vertical:
			fr = Rect2(r.position.x, r.end.y - r.size.y * clampf(frac, 0.0, 1.0), r.size.x, r.size.y * clampf(frac, 0.0, 1.0))
		else:
			fr.size.x = r.size.x * clampf(frac, 0.0, 1.0)
		draw_rect(fr, col)
		draw_rect(r, UIK.ink(), false, 2.5)

	func _helm() -> void:
		## the ship's wheel, turned as far as Helm has it turned
		var c: Vector2 = Vector2(60, 38)
		var rot: float = float(data.get("wheel", 0.0)) * 1.6
		var wood: Color = K.pal("brown")
		var broken: bool = str(data.get("systems", {}).get("bridge", {}).get("state", "ok")) != "ok"
		if broken:
			wood = K.pal("grey")
		for i in 4:
			var a: float = rot + i * PI / 4.0
			var d: Vector2 = Vector2.from_angle(a)
			draw_line(c - d * 34.0, c + d * 34.0, UIK.ink(), 7.0, true)
			draw_line(c - d * 34.0, c + d * 34.0, wood, 4.0, true)
		draw_arc(c, 26.0, 0.0, TAU, 40, UIK.ink(), 9.0, true)
		draw_arc(c, 26.0, 0.0, TAU, 40, wood, 5.0, true)
		draw_circle(c, 8.0, UIK.ink())
		draw_circle(c, 6.0, K.pal("mustard"))
		draw_circle(c + Vector2.from_angle(rot - PI / 2.0) * 34.0, 4.5, UIK.c("red"))
		var wv: float = float(data.get("wheel", 0.0))
		if absf(wv) > 0.08:
			var sgn: float = signf(wv)
			var a0: float = -PI / 2.0
			draw_arc(c, 40.0, a0, a0 + sgn * 0.9, 12, K.pal("blue"), 4.0, true)
			var tip: Vector2 = c + Vector2.from_angle(a0 + sgn * 0.9) * 40.0
			draw_circle(tip, 4.0, K.pal("blue"))
		if broken:
			_stamp(Vector2(60, 70), "BROKEN", UIK.ink())

	func _engines() -> void:
		## the throttle lever in its slot, and the engines' thermometer
		var thr: float = clampf(float(data.get("throttle", 0.0)), 0.0, 1.0)
		var slot: Rect2 = Rect2(20, 8, 12, 60)
		draw_rect(slot, K.pal("paper2"))
		draw_rect(slot, UIK.ink(), false, 3.0)
		for n in 3:
			draw_line(Vector2(13, 18 + n * 20), Vector2(17, 18 + n * 20), UIK.ink(), 2.0)
		var hy: float = slot.end.y - 6.0 - thr * (slot.size.y - 12.0)
		draw_line(Vector2(26, hy), Vector2(46, hy - 4), UIK.ink(), 5.0, true)
		draw_circle(Vector2(48, hy - 4), 7.0, UIK.ink())
		draw_circle(Vector2(48, hy - 4), 5.0, UIK.c("red") if bool(data.get("boost", false)) else K.pal("blue"))
		_text(Vector2(64, 76), "%d m/s" % int(data.get("speed", 0)), 14, UIK.ink())
		if _f("heat"):
			var h: float = float(data.get("engine_heat", 0.0)) / 100.0
			var col: Color = UIK.c("red") if h > 0.8 else UIK.c("orange")
			_bar(Rect2(96, 6, 12, 50), h, col, true)
			draw_circle(Vector2(102, 62), 9.0, UIK.ink())
			draw_circle(Vector2(102, 62), 7.0, col)
		if int(data.get("engines_ok", 2)) < 2:
			_stamp(Vector2(64, 40), "ENGINE DOWN" if int(data.get("engines_ok", 2)) == 1 else "BOTH DOWN", UIK.c("red"))

	func _weapons() -> void:
		## the torpedo in its tube, and the gun's heat
		if _f("torpedo"):
			draw_rect(Rect2(8, 10, 104, 28), K.pal("ink_soft"))
			draw_rect(Rect2(8, 10, 104, 28), UIK.ink(), false, 3.0)
			var st: String = str(data.get("torp", "empty"))
			var fill: float = 1.0 if st == "ready" else (float(data.get("torp_load", 0.0)) if st == "loading" else 0.0)
			var body: PackedVector2Array = PackedVector2Array([Vector2(16, 24), Vector2(26, 16), Vector2(84, 16), Vector2(102, 24), Vector2(84, 32), Vector2(26, 32)])
			draw_colored_polygon(body, K.pal("paper2"))
			if fill > 0.0:
				var fx: float = 16.0 + 86.0 * fill
				var part: PackedVector2Array = PackedVector2Array()
				for p in body:
					part.append(Vector2(minf(p.x, fx), p.y))
				draw_colored_polygon(part, K.pal("mustard"))
			body.append(body[0])
			draw_polyline(body, UIK.ink(), 2.5, true)
			_text(Vector2(60, 29), "READY" if st == "ready" else ("LOADING" if st == "loading" else "EMPTY"), 11, UIK.ink())
		else:
			# no torpedoes yet: just the gun's barrel
			draw_rect(Rect2(20, 14, 80, 18), K.pal("steel"))
			draw_rect(Rect2(20, 14, 80, 18), UIK.ink(), false, 3.0)
			draw_rect(Rect2(10, 10, 14, 26), K.pal("ink_soft"))
			draw_rect(Rect2(10, 10, 14, 26), UIK.ink(), false, 3.0)
			if bool(data.get("firing", false)):
				draw_circle(Vector2(106, 23), 7.0, K.pal("yellow"))
		if _f("heat"):
			var h: float = float(data.get("gun_heat", 0.0)) / 100.0
			_bar(Rect2(8, 50, 104, 12), h, UIK.c("red") if h > 0.8 else K.pal("mustard"))
			_text(Vector2(60, 76), "gun heat", 12, UIK.ink(), false)
		if not bool(data.get("gun_ok", true)):
			_stamp(Vector2(60, 40), "GUN BROKEN", UIK.c("red"))

	func _sensors() -> void:
		## a little radar sweeping, with the scan (or the hail's signal) filling a ring round it
		var c: Vector2 = Vector2(60, 38)
		var r: float = 32.0
		var ok: bool = bool(data.get("sensors_ok", true))
		draw_circle(c, r, Color("#dfe9cf") if ok else K.pal("grey2"))
		draw_arc(c, r * 0.55, 0.0, TAU, 32, Color(K.pal("green"), 0.6), 1.5, true)
		if ok:
			var a: float = fmod(Time.get_ticks_msec() / 700.0, TAU)
			var wedge: PackedVector2Array = PackedVector2Array([c])
			for i in 9:
				wedge.append(c + Vector2.from_angle(a - 0.7 + 0.7 * i / 8.0) * r)
			draw_colored_polygon(wedge, Color(K.pal("green"), 0.45))
		draw_arc(c, r, 0.0, TAU, 40, UIK.ink(), 3.0, true)
		var prog: float = float(data.get("scan", -1.0))
		var col: Color = K.pal("green")
		var hail: float = float(data.get("hail", -1.0))
		if prog < 0.0 and hail >= 0.0 and _f("comms"):
			prog = hail
			col = K.pal("blue")
		if prog >= 0.0:
			draw_arc(c, r + 5.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(prog, 0.0, 1.0), 40, col, 5.0, true)
		var n: int = int(data.get("unknown", 0))
		_text(c + Vector2(0, 6), "%d ?" % n if n > 0 else "ALL", 15, UIK.ink())
		if not ok:
			_stamp(Vector2(60, 70), "BROKEN", UIK.ink())

	func _shields() -> void:
		## the shield's crest, filled to its power, and the hits it has stopped
		var crest: PackedVector2Array = PackedVector2Array([Vector2(36, 6), Vector2(76, 6), Vector2(76, 34), Vector2(70, 52), Vector2(56, 70), Vector2(42, 52), Vector2(36, 34)])
		draw_colored_polygon(crest, K.pal("paper2"))
		var ok: bool = bool(data.get("shield_ok", true))
		var pw: int = clampi(int(data.get("shield_power", 2)), 0, 3) if _f("power") else (3 if ok else 0)
		if not ok:
			pw = 0
		var bands: Array = [Rect2(36, 6, 40, 21), Rect2(36, 27, 40, 21), Rect2(36, 48, 40, 22)]
		for i in pw:
			var band: Rect2 = bands[2 - i]
			var quad: PackedVector2Array = PackedVector2Array([band.position, Vector2(band.end.x, band.position.y), band.end, Vector2(band.position.x, band.end.y)])
			for part in Geometry2D.intersect_polygons(crest, quad):
				if (part as PackedVector2Array).size() >= 3:
					draw_colored_polygon(part, K.pal("purple"))
		draw_line(Vector2(36, 27), Vector2(76, 27), UIK.ink(), 2.0)
		draw_line(Vector2(36, 48), Vector2(76, 48), UIK.ink(), 2.0)
		crest.append(crest[0])
		draw_polyline(crest, UIK.ink(), 3.5, true)
		_text(Vector2(100, 34), str(int(data.get("blocked", 0))), 20, UIK.ink())
		_text(Vector2(100, 50), "blocked", 12, UIK.ink(), false)
		if not ok:
			_stamp(Vector2(56, 40), "BROKEN", UIK.c("red"))

	func _engineer() -> void:
		## the repair under way, as a ring filling round a spanner; and the reactor's load
		var c: Vector2 = Vector2(46, 38)
		draw_arc(c, 28.0, 0.0, TAU, 40, K.pal("paper2"), 8.0, true)
		var fixing: bool = str(data.get("fixing", "")) != ""
		if fixing:
			draw_arc(c, 28.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(float(data.get("fix", 0.0)), 0.0, 1.0), 40, K.pal("green"), 8.0, true)
		draw_arc(c, 33.0, 0.0, TAU, 40, UIK.ink(), 2.0, true)
		# a spanner
		var d: Vector2 = Vector2.from_angle(-0.8)
		draw_line(c - d * 14.0, c + d * 12.0, UIK.ink(), 8.0, true)
		draw_line(c - d * 14.0, c + d * 12.0, K.pal("steel"), 5.0, true)
		draw_arc(c + d * 15.0, 7.0, -0.8 + 0.9, -0.8 + TAU - 0.9, 16, UIK.ink(), 6.0, true)
		draw_arc(c + d * 15.0, 7.0, -0.8 + 0.9, -0.8 + TAU - 0.9, 16, K.pal("steel"), 3.0, true)
		if _f("power"):
			var load: float = float(data.get("draw", 0.0)) / maxf(1.0, float(data.get("cap", 6.0)))
			_bar(Rect2(92, 8, 14, 56), clampf(load, 0.0, 1.0), UIK.c("red") if load > 1.0 else K.pal("mustard"), true)
			_text(Vector2(99, 76), "load", 12, UIK.ink(), false)
		if bool(data.get("blackout", false)):
			_stamp(Vector2(60, 40), "BLACKOUT", UIK.ink())

	func _ship() -> void:
		## the hull as a big heart, filled to what's left of it; Pudding's mood under it
		var h: float = clampf(float(data.get("hull", 1.0)), 0.0, 1.0)
		var cx: float = 60.0 if not _f("pudding") else 40.0
		var heart: PackedVector2Array = PackedVector2Array()
		for i in 48:
			var t: float = TAU * i / 48.0
			var x: float = 16.0 * pow(sin(t), 3)
			var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
			heart.append(Vector2(cx + x * 2.0, 36.0 + y * 2.0))
		draw_colored_polygon(heart, K.pal("paper2"))
		var top: float = 36.0 + 34.0 - 68.0 * h
		var fill: Array = Geometry2D.intersect_polygons(heart, PackedVector2Array([Vector2(cx - 40, top), Vector2(cx + 40, top), Vector2(cx + 40, 80), Vector2(cx - 40, 80)]))
		for part in fill:
			draw_colored_polygon(part, UIK.c("red") if h > 0.35 else K.pal("red2"))
		heart.append(heart[0])
		draw_polyline(heart, UIK.ink(), 3.5, true)
		var f: Font = UIK.font("head")
		var t2: String = "%d%%" % int(data.get("hull_pct", 100))
		var w: float = f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string_outline(f, Vector2(cx - w / 2.0, 44), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, UIK.ink())
		draw_string(f, Vector2(cx - w / 2.0, 44), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		if _f("pudding"):
			var pm: float = float(data.get("pud", 0.0)) / 100.0
			_text(Vector2(96, 22), "Pudding", 13, UIK.ink(), false)
			_bar(Rect2(78, 28, 36, 12), pm, UIK.c("red") if pm < 0.3 else K.pal("pink"))
			if bool(data.get("pud_out", false)):
				_stamp(Vector2(96, 56), "LOOSE!", UIK.c("red"))
