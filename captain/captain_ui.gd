class_name CaptainUI
extends Control
## The captain's bridge: a big window onto space and a dashboard. The captain can see everything
## out there and touch nothing on the ship. They talk; the crew does.

const ORDERS: Array = [
	["helm", [["Turn port 15°", "turn", {"dir": -1.0, "amount": 0.26}], ["Turn port 45°", "turn", {"dir": -1.0, "amount": 0.79}], ["Turn port 90°", "turn", {"dir": -1.0, "amount": 1.57}],
		["Turn starboard 15°", "turn", {"dir": 1.0, "amount": 0.26}], ["Turn starboard 45°", "turn", {"dir": 1.0, "amount": 0.79}], ["Turn starboard 90°", "turn", {"dir": 1.0, "amount": 1.57}],
		["Hold heading", "hold", {}], ["Strafe port", "strafe", {"dir": -1.0}], ["Strafe starboard", "strafe", {"dir": 1.0}], ["Stop strafing", "strafe", {"dir": 0.0}], ["EMERGENCY ROLL!", "roll", {"dir": 1.0}]]],
	["engines", [["Full ahead", "speed", {"v": 46.0}], ["Half ahead", "speed", {"v": 24.0}], ["Slow ahead", "speed", {"v": 10.0}], ["All stop", "stop", {}],
		["Boost on", "boost", {"on": true}], ["Boost off", "boost", {"on": false}], ["Dampers OFF", "dampers", {"on": false}], ["Dampers on", "dampers", {"on": true}],
		["Easy on the throttle", "gentle", {"on": true}], ["Normal throttle", "gentle", {"on": false}]]],
	["power", [["Balanced power", "profile", {"name": "balanced"}], ["Combat power", "profile", {"name": "combat"}], ["Stealth power", "profile", {"name": "stealth"}],
		["Precision power", "profile", {"name": "precision"}], ["Everything to shields", "profile", {"name": "bastion"}], ["Vent the reactor", "vent", {}]]],
	["weapons", [["Fire at will", "engage", {"ids": []}], ["Hold fire", "hold_fire", {}], ["Torpedo the nearest!", "torp", {"id": -2, "weak": true}],
		["Stow the guns", "stow", {"on": true}], ["Guns free", "stow", {"on": false}]]],
	["sensors", [["Scan the hostiles", "scan", {"ids": [], "auto": true}], ["Active ping", "ping", {}], ["Internal scan", "iscan", {}], ["Deploy decoy beacon", "beacon", {}],
		["Viewscreen: forward", "view", {"dir": "fwd"}], ["Viewscreen: aft", "view", {"dir": "aft"}], ["Viewscreen: port", "view", {"dir": "port"}], ["Viewscreen: starboard", "view", {"dir": "stbd"}]]],
	["ops", [["Shields to front", "shield", {"mode": "front"}], ["Shields to starboard", "shield", {"mode": "stbd"}], ["Shields to aft", "shield", {"mode": "aft"}], ["Shields to port", "shield", {"mode": "port"}],
		["Shields: auto", "shield", {"mode": "auto"}], ["Tractor the nearest", "tractor", {"id": -2}], ["Tractor off", "tractor", {"id": -1}], ["Calm Pudding", "calm", {"on": true}], ["Secure the cargo", "secure", {"on": true}],
		["Fix the worst thing", "repair_worst", {}]]],
]

# ---------------------------------------------------------------- drawing helpers

class BridgeFrame extends Control:
	## The window bezel plus everything that happens ON the glass: smoke, fog, cracks, flashes, fuzzy dice.
	var t: float = 0.0
	var smoke: Array = []
	var fog: bool = false
	var scram: bool = false
	var flash: float = 0.0
	var jump_flash: float = 0.0
	var bridge_hp: float = 100.0
	var speed: float = 0.0
	var view_name: String = "fwd"
	var dice_swing: float = 0.0
	const BEZEL: float = 14.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		t += delta
		jump_flash = maxf(0.0, jump_flash - delta * 1.4)
		queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var wi: Rect2 = r.grow(-BEZEL)
		var bz: Color = Color.html("#3a4372")
		var cr: float = 30.0
		for corner in [[wi.position, Vector2(1, 1)], [Vector2(wi.end.x, wi.position.y), Vector2(-1, 1)], [Vector2(wi.position.x, wi.end.y), Vector2(1, -1)], [wi.end, Vector2(-1, -1)]]:
			var cp: Vector2 = corner[0]
			var dir: Vector2 = corner[1]
			var pts: PackedVector2Array = PackedVector2Array([cp])
			for i in range(0, 13):
				var a: float = float(i) / 12.0 * PI / 2.0
				pts.append(cp + Vector2(dir.x * (cr - cos(a) * cr), dir.y * (cr - sin(a) * cr)))
			draw_colored_polygon(pts, bz)
		var s: StyleBoxFlat = UIK.sb(Color(0, 0, 0, 0), 36, bz, int(BEZEL), 0)
		s.draw_center = false
		draw_style_box(s, r)
		var hi: StyleBoxFlat = UIK.sb(Color(0, 0, 0, 0), int(cr), bz.lightened(0.35), 3, 0)
		hi.draw_center = false
		draw_style_box(hi, wi.grow(2.0))
		for b in [Vector2(22, 22), Vector2(size.x - 22, 22), Vector2(22, size.y - 22), Vector2(size.x - 22, size.y - 22)]:
			draw_circle(b, 6.0, bz.darkened(0.3))
			draw_circle(b, 3.5, bz.lightened(0.4))
		var sw: float = sin(t * 2.3) * 0.12 + dice_swing
		for dx in [0.0, 40.0]:
			var top: Vector2 = Vector2(wi.position.x + 360 + dx, wi.position.y)
			var bottom: Vector2 = top + Vector2(sin(sw) * 54.0, cos(sw) * 54.0)
			draw_line(top, bottom, Color.html("#2b2f4a"), 3.0, true)
			var sq: Rect2 = Rect2(bottom - Vector2(15, 4), Vector2(30, 30))
			draw_style_box(UIK.sb(K.pal("pink"), 8, K.pal("pink").darkened(0.3), 2, 0), sq)
			for pip in [Vector2(8, 8), Vector2(22, 8), Vector2(15, 15), Vector2(8, 22), Vector2(22, 22)]:
				draw_circle(sq.position + pip, 2.4, Color.html("#2b2f4a"))
		if fog:
			for i in 7:
				var fx: float = wi.position.x + fmod(float(i) * 197.0 + t * 14.0, wi.size.x)
				var fy: float = wi.position.y + 40.0 + fmod(float(i) * 83.0, maxf(1.0, wi.size.y - 80.0))
				draw_texture_rect(SpaceBackdrop.glow_tex(), Rect2(fx - 140, fy - 140, 280, 280), false, Color(1, 1, 1, 0.22))
		for sm in smoke:
			var side: float = float(sm[1])
			var base_x: float = wi.position.x + 50.0 if side < -1.0 else (wi.end.x - 50.0 if side > 1.0 else wi.position.x + wi.size.x * 0.5 + side * 120.0)
			var inten: float = float(sm[2])
			for j in 6:
				var life: float = fmod(t * 0.7 + float(j) * 0.17 + float(sm[0]) * 0.03, 1.0)
				var px: float = base_x + sin(t * 2.0 + j) * 24.0
				var py: float = wi.end.y - 10.0 - life * 160.0 * inten
				var col: Color = Color(0.25, 0.22, 0.28, 0.45 * (1.0 - life)) if inten < 1.0 else Color(1.0, 0.6, 0.25, 0.5 * (1.0 - life))
				draw_circle(Vector2(px, py), 14.0 + life * 30.0, col)
		if bridge_hp < 45.0:
			var cx: float = wi.position.x + wi.size.x * 0.62
			var pts2: PackedVector2Array = PackedVector2Array([Vector2(cx, wi.position.y), Vector2(cx - 30, wi.position.y + 110), Vector2(cx + 10, wi.position.y + 190), Vector2(cx - 40, wi.end.y - 20)])
			draw_polyline(pts2, Color(1, 1, 1, 0.8), 3.0, true)
			draw_line(pts2[2], pts2[2] + Vector2(90, 40), Color(1, 1, 1, 0.7), 2.0, true)
		if flash > 0.0:
			draw_rect(wi, Color(K.pal("red"), clampf(flash * 1.4, 0.0, 0.45)), true)
		if scram:
			draw_rect(wi, Color(0.02, 0.0, 0.05, 0.92), true)
			draw_string(UIK.font_head(), wi.position + Vector2(0, wi.size.y * 0.5), "EMERGENCY LIGHTING", HORIZONTAL_ALIGNMENT_CENTER, wi.size.x, 34, Color(K.pal("red"), 0.5 + 0.5 * sin(t * 6.0)))
		if jump_flash > 0.0:
			draw_rect(wi, Color(1, 1, 1, clampf(jump_flash, 0.0, 1.0)), true)
		var tag: String = "VIEW: %s   ·   %d m/s" % [view_name.to_upper(), int(speed)]
		draw_style_box(UIK.sb(Color(K.pal("night"), 0.7), 10, Color(0, 0, 0, 0), 0, 0), Rect2(wi.position.x + 16, wi.end.y - 40, 230, 28))
		draw_string(UIK.font_bold(), Vector2(wi.position.x + 28, wi.end.y - 20), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.9))

class CRT extends Control:
	var lines: Array = []
	var waiting: bool = false
	var t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_style_box(UIK.sb(Color(0.05, 0.13, 0.11), 12, Color(0.12, 0.3, 0.24), 3, 0), Rect2(Vector2.ZERO, size))
		var fb: Font = UIK.font_bold()
		var g: Color = Color(0.5, 1.0, 0.72)
		var y: float = 22.0
		if lines.is_empty():
			draw_string(fb, Vector2(12, y), "...static..." if waiting else "No transmissions.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 15, Color(g, 0.75))
			if waiting:
				draw_string(fb, Vector2(12, y + 20), "(Sensors: tune us in!)", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 13, Color(g, 0.6))
				for i in 40:
					draw_rect(Rect2(8 + randf() * (size.x - 16), 8 + randf() * (size.y - 16), 6, 2), Color(1, 1, 1, 0.18))
		for ln in lines:
			draw_string(UIK.font_head(), Vector2(12, y), "%s:" % ln.from, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 15, K.pal("yellow"))
			y += 18.0
			var words: Array = str(ln.text).split(" ")
			var cur: String = ""
			var maxc: int = int(size.x / 7.6)
			for wd in words:
				if (cur + " " + wd).length() > maxc:
					draw_string(fb, Vector2(12, y), cur, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 13, g)
					y += 16.0
					cur = wd
				else:
					cur = (cur + " " + wd).strip_edges()
			draw_string(fb, Vector2(12, y), cur, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 13, g)
			y += 20.0
			if y > size.y - 8.0:
				break
		for i2 in range(0, int(size.y), 4):
			draw_line(Vector2(4, i2), Vector2(size.x - 4, i2), Color(0, 0, 0, 0.16), 1.0)

# ---------------------------------------------------------------- the real thing

var window_area: Control
var svc: SubViewportContainer
var sv: SubViewport
var c3d: Captain3D
var frame: BridgeFrame
var hull_dial: Dial
var shield_d: ShieldDiagram
var crt: CRT
var crew_imgs: Dictionary = {}
var pud_bar: BarGauge
var overlord_img: TextureRect
var temper_chip: PanelContainer
var sticky: PanelContainer
var sticky_lbl: Label
var meters_panel: PanelContainer
var meters_box: VBoxContainer
var meters_sig: String = ""
var sheet_panel: PanelContainer
var sheet_lbl: Label
var orders_btn: Button
var orders_panel: PanelContainer
var order_grid: VBoxContainer
var offer_panel: PanelContainer
var offer_lbl: Label
var offer_peer: int = 0
var shared_holder: PanelContainer
var shared_clip: Control
var shared_ui: StationUI = null
var shared_station: String = ""
var overlay: Control = null
var overlay_sig: String = ""
var punch_btn: Button
var ritual_lbl: Label
var bark_lbl: Label
var bark_t: float = 0.0
var t: float = 0.0
var map_panel: Screens.MapPanel = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var root: VBoxContainer = UIK.vbox(8)
	var m: MarginContainer = UIK.margin(root, 8)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	window_area = Control.new()
	window_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window_area.clip_contents = true
	root.add_child(window_area)
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.offset_left = BridgeFrame.BEZEL
	svc.offset_top = BridgeFrame.BEZEL
	svc.offset_right = -BridgeFrame.BEZEL
	svc.offset_bottom = -BridgeFrame.BEZEL
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_area.add_child(svc)
	sv = SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_2X
	sv.handle_input_locally = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)
	c3d = Captain3D.new()
	sv.add_child(c3d)
	frame = BridgeFrame.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window_area.add_child(frame)
	_build_window_widgets()
	root.add_child(_build_dashboard())

func _place(c: Control, preset: int, ox: float, oy: float, w: float, h: float) -> void:
	c.set_anchors_preset(preset)
	match preset:
		Control.PRESET_TOP_LEFT:
			c.offset_left = ox
			c.offset_top = oy
			c.offset_right = ox + w
			c.offset_bottom = oy + h
		Control.PRESET_TOP_RIGHT:
			c.offset_left = -ox - w
			c.offset_top = oy
			c.offset_right = -ox
			c.offset_bottom = oy + h
		Control.PRESET_CENTER_BOTTOM:
			c.offset_left = -w * 0.5
			c.offset_right = w * 0.5
			c.offset_top = -oy - h
			c.offset_bottom = -oy

func _build_window_widgets() -> void:
	sticky = PanelContainer.new()
	sticky.add_theme_stylebox_override("panel", UIK.sb(Color.html("#fff2a6"), 6, Color.html("#e6cf6a"), 2, 12, 8))
	_place(sticky, Control.PRESET_TOP_LEFT, 30, 30, 300, 0)
	sticky.rotation = -0.03
	var sv2: VBoxContainer = UIK.vbox(2)
	sticky.add_child(sv2)
	sv2.add_child(UIK.label("OBJECTIVE  (only you can see this)", 12, Color.html("#8a7a2a")))
	sticky_lbl = UIK.wrapped(UIK.label("", 16, K.pal("ink")))
	sv2.add_child(sticky_lbl)
	window_area.add_child(sticky)
	sheet_panel = UIK.panel("card", 10, 10)
	_place(sheet_panel, Control.PRESET_TOP_LEFT, 30, 200, 320, 0)
	sheet_lbl = UIK.wrapped(UIK.label("", 14))
	sheet_panel.add_child(sheet_lbl)
	sheet_panel.visible = false
	window_area.add_child(sheet_panel)
	meters_panel = UIK.panel("card", 8, 14)
	_place(meters_panel, Control.PRESET_TOP_RIGHT, 30, 30, 250, 0)
	meters_box = UIK.vbox(6)
	meters_panel.add_child(meters_box)
	meters_panel.visible = false
	window_area.add_child(meters_panel)
	bark_lbl = UIK.title("", 22, K.pal("yellow"))
	bark_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(bark_lbl, Control.PRESET_CENTER_BOTTOM, 0, 58, 900, 34)
	window_area.add_child(bark_lbl)
	offer_panel = UIK.panel("card", 10, 16)
	offer_panel.set_meta("overlay", true)
	_place(offer_panel, Control.PRESET_CENTER_BOTTOM, 0, 24, 620, 64)
	var oh: HBoxContainer = UIK.hbox(10)
	offer_panel.add_child(oh)
	oh.add_child(UIK.icon_rect("share", 26, K.pal("sensors")))
	offer_lbl = UIK.label("", 16)
	offer_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_lbl.clip_text = true
	oh.add_child(offer_lbl)
	oh.add_child(UIK.btn("Show me", "green", func(): Net.send("cap", {"cmd": "accept_share", "peer": offer_peer})))
	oh.add_child(UIK.btn("Not now", "neutral", func(): Net.send("cap", {"cmd": "decline_share", "peer": offer_peer})))
	offer_panel.visible = false
	window_area.add_child(offer_panel)
	shared_holder = PanelContainer.new()
	shared_holder.add_theme_stylebox_override("panel", UIK.sb(K.pal("yellow"), 18, K.pal("yellow").darkened(0.25), 3, 8, 12))
	shared_holder.set_meta("overlay", true)
	shared_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shared_holder.offset_left = 40
	shared_holder.offset_right = -40
	shared_holder.offset_top = 22
	shared_holder.offset_bottom = -22
	var shv: VBoxContainer = UIK.vbox(6)
	shared_holder.add_child(shv)
	var shh: HBoxContainer = UIK.hbox(8)
	shv.add_child(shh)
	shh.add_child(UIK.icon_rect("share", 22, K.pal("ink")))
	var shl: Label = UIK.heading("A crew member is showing you their screen", 17)
	shl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shh.add_child(shl)
	shh.add_child(UIK.btn("Back to the window", "red", func(): Net.send("cap", {"cmd": "stop_share"}), "back"))
	shared_clip = Control.new()
	shared_clip.clip_contents = true
	shared_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shv.add_child(shared_clip)
	shared_holder.visible = false
	window_area.add_child(shared_holder)
	orders_panel = PanelContainer.new()
	orders_panel.set_meta("overlay", true)
	orders_panel.add_theme_stylebox_override("panel", UIK.sb(K.pal("card"), UIK.RADIUS, K.pal("navy"), 3, 12, 12))
	orders_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	orders_panel.offset_left = -600
	orders_panel.offset_right = -24
	orders_panel.offset_top = 16
	orders_panel.offset_bottom = -16
	var ov: VBoxContainer = UIK.vbox(8)
	orders_panel.add_child(ov)
	var ohd: HBoxContainer = UIK.hbox(8)
	ov.add_child(ohd)
	ohd.add_child(UIK.icon_rect("captain", 22, K.pal("navy")))
	var ot: Label = UIK.heading("ORDER WHEEL", 18)
	ot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ohd.add_child(ot)
	var cb: Button = UIK.btn("Close", "neutral", func(): orders_panel.visible = false, "x")
	cb.add_theme_font_size_override("font_size", 14)
	ohd.add_child(cb)
	var tabs: GridContainer = UIK.grid(3, 6)
	ov.add_child(tabs)
	for entry in ORDERS:
		var st: String = entry[0]
		var tb: Button = UIK.btn(K.seat_name(st), UIK.seat_color(st), func(): _show_orders(st), str(K.SEAT_INFO[st].icon))
		tb.add_theme_font_size_override("font_size", 14)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tb)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ov.add_child(sc)
	order_grid = UIK.vbox(6)
	order_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(order_grid)
	orders_panel.visible = false
	window_area.add_child(orders_panel)
	_show_orders("helm")

func _build_dashboard() -> Control:
	var dash: HBoxContainer = UIK.hbox(8)
	dash.custom_minimum_size = Vector2(0, 150)
	var hw: Array = UIK.window("HULL", "red", "hull", 4)
	dash.add_child(hw[0])
	hull_dial = Dial.new("integrity", 0.0, 100.0, K.pal("green"))
	hull_dial.custom_minimum_size = Vector2(108, 104)
	(hw[1] as VBoxContainer).add_child(hull_dial)
	var sw: Array = UIK.window("SHIELDS", "ops", "ops", 4)
	dash.add_child(sw[0])
	shield_d = ShieldDiagram.new()
	shield_d.custom_minimum_size = Vector2(108, 104)
	shield_d.accent = K.pal("navy")
	(sw[1] as VBoxContainer).add_child(shield_d)
	var cw: Array = UIK.window("COMMS", "sensors", "share", 4)
	(cw[0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dash.add_child(cw[0])
	crt = CRT.new()
	crt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crt.custom_minimum_size = Vector2(220, 100)
	(cw[1] as VBoxContainer).add_child(crt)
	var bw: Array = UIK.window("BRIDGE CAM", "blue", "crew", 4)
	dash.add_child(bw[0])
	var crew_row: HBoxContainer = UIK.hbox(-6)
	(bw[1] as VBoxContainer).add_child(crew_row)
	for s in K.STATIONS:
		var holder: Control = Control.new()
		holder.custom_minimum_size = Vector2(52, 52)
		var pr: TextureRect = UIK.portrait(str(K.SEAT_INFO[s].portrait), 52)
		pr.tooltip_text = K.seat_name(s)
		pr.mouse_filter = Control.MOUSE_FILTER_PASS
		holder.add_child(pr)
		crew_row.add_child(holder)
		crew_imgs[s] = pr
	var pr2: HBoxContainer = UIK.hbox(6)
	(bw[1] as VBoxContainer).add_child(pr2)
	pr2.add_child(UIK.portrait("pudding", 34))
	pud_bar = BarGauge.new("Pudding", 100.0, K.pal("pink"))
	pud_bar.danger_above = 80.0
	pud_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pud_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr2.add_child(pud_bar)
	var tw: Array = UIK.window("OVERLORD", "purple", "temper", 4)
	dash.add_child(tw[0])
	var tv: VBoxContainer = tw[1]
	overlord_img = UIK.portrait("overlord", 70)
	overlord_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tv.add_child(overlord_img)
	temper_chip = UIK.chip("Peeved", "purple", "", 14)
	temper_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tv.add_child(temper_chip)
	var bc: VBoxContainer = UIK.vbox(8)
	bc.custom_minimum_size = Vector2(150, 0)
	bc.alignment = BoxContainer.ALIGNMENT_CENTER
	dash.add_child(bc)
	orders_btn = UIK.btn("Orders (O)", "navy", func(): orders_panel.visible = not orders_panel.visible, "captain")
	orders_btn.tooltip_text = "Give orders to robot crew members"
	bc.add_child(orders_btn)
	punch_btn = UIK.btn("PUNCH IT!", "red", func(): Net.send("cap", {"cmd": "punch"}), "play")
	punch_btn.custom_minimum_size = Vector2(0, 56)
	punch_btn.add_theme_font_size_override("font_size", 22)
	punch_btn.visible = false
	bc.add_child(punch_btn)
	return dash

func _show_orders(st: String) -> void:
	for c in order_grid.get_children():
		c.queue_free()
	for entry in ORDERS:
		if entry[0] != st:
			continue
		order_grid.add_child(UIK.wrapped(UIK.label("Robot crew follow these exactly. Human crew: just say it out loud!", 14, K.pal("ink_soft"))))
		var g: GridContainer = UIK.grid(2, 6, 6)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		order_grid.add_child(g)
		for o in entry[1]:
			var verb: String = o[1]
			var args: Dictionary = o[2]
			var b: Button = UIK.btn(str(o[0]), UIK.seat_color(st), func():
				Net.send("cap", {"cmd": "order", "seat": st, "verb": verb, "args": args})
				Sfx.play("blip"))
			b.add_theme_font_size_override("font_size", 14)
			b.clip_text = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(b)

# ---------------------------------------------------------------- per-snapshot

func apply(v: Dictionary, f: Dictionary) -> void:
	var com: Dictionary = f.get("common", {})
	var phase: String = str(f.get("phase", ""))
	c3d.apply(v)
	frame.smoke = _smoke_list(v.get("smoke", []))
	frame.fog = bool(v.get("fog", false))
	frame.scram = bool(com.get("scram", false))
	frame.flash = float(v.get("flash", 0.0))
	frame.bridge_hp = float(v.get("bridge_hp", 100.0))
	frame.speed = float(v.get("speed", 0.0))
	frame.view_name = str(v.get("view", "fwd"))
	frame.dice_swing = clampf(float(v.get("shake", 0.0)) * 0.6, 0.0, 0.8) * sin(Time.get_ticks_msec() / 90.0)
	var hull_pct: float = 100.0 * float(com.get("hull", 100.0)) / maxf(1.0, float(com.get("hull_max", 100.0)))
	hull_dial.value = maxf(0.0, hull_pct)
	hull_dial.accent = K.pal("green").lerp(K.pal("red"), clampf(1.0 - hull_pct / 100.0, 0.0, 1.0))
	shield_d.shields = v.get("shield", [0, 0, 0, 0])
	crt.lines = v.get("comms", [])
	crt.waiting = bool(v.get("hail_wait", false))
	var shake: float = float(v.get("shake", 0.0))
	for s in crew_imgs.keys():
		(crew_imgs[s] as TextureRect).position.y = sin(t * 3.0 + float(s.length())) * (1.0 + shake * 8.0)
	pud_bar.value = float(v.get("crew", {}).get("pud_mood", 0.0))
	var run: Dictionary = f.get("run", {})
	var lvl: int = int(run.get("temper", 1))
	overlord_img.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.55), float(lvl - 1) / 4.0)
	for l in temper_chip.find_children("*", "Label", true, false):
		(l as Label).text = "%s  %d/5" % [str(run.get("temper_name", "Peeved")), lvl]
	var note: String = str(v.get("note", ""))
	sticky_lbl.text = note if note != "" else "Nothing on the sticky note. Suspicious."
	sticky.visible = phase in ["encounter", "jumping"]
	var meters: Array = v.get("meters", [])
	var msig: String = ""
	for mm in meters:
		msig += str(mm.label)
	if msig != meters_sig:
		meters_sig = msig
		for c in meters_box.get_children():
			c.queue_free()
		for m2 in meters:
			var bg: BarGauge = BarGauge.new(str(m2.label), float(m2.max), K.pal(str(m2.color)))
			bg.name = "m_" + str(m2.label).replace(" ", "_")
			bg.custom_minimum_size = Vector2(226, 26)
			meters_box.add_child(bg)
	for m3 in meters:
		var node: Node = meters_box.get_node_or_null("m_" + str(m3.label).replace(" ", "_"))
		if node != null:
			(node as BarGauge).value = float(m3.v)
			(node as BarGauge).text = "%s  %d" % [str(m3.label).to_lower(), int(m3.v)]
	meters_panel.visible = not meters.is_empty() and phase == "encounter"
	var sheet: Array = v.get("sheet", [])
	sheet_panel.visible = not sheet.is_empty() and phase == "encounter"
	if sheet_panel.visible:
		sheet_lbl.text = "\n".join(sheet)
	var offers: Array = f.get("offers", [])
	offer_panel.visible = not offers.is_empty() and f.get("shared", {}).is_empty()
	if offer_panel.visible:
		offer_peer = int(offers[0].peer)
		offer_lbl.text = "%s (%s) wants to show you their screen." % [offers[0].name, K.seat_name(str(offers[0].station))]
	_update_shared(f)
	punch_btn.visible = phase == "staging"
	orders_btn.visible = phase in ["encounter", "staging"]
	if not orders_btn.visible:
		orders_panel.visible = false
	_update_overlay(f)
	if bark_t <= 0.0:
		bark_lbl.text = ""

func _process(delta: float) -> void:
	t += delta
	bark_t = maxf(0.0, bark_t - delta)

func _smoke_list(raw: Array) -> Array:
	var out: Array = []
	var i: int = 0
	for s in raw:
		var ly: float = float(s[1])
		var side: float = -2.0 if ly < -1.5 else (2.0 if ly > 1.5 else ly / 2.0)
		out.append([float(i), side, float(s[2])])
		i += 1
	return out

func _update_shared(f: Dictionary) -> void:
	var sh: Dictionary = f.get("shared", {})
	if sh.is_empty():
		shared_holder.visible = false
		if shared_ui != null:
			shared_ui.get_parent().queue_free()
			shared_ui = null
			shared_station = ""
		return
	shared_holder.visible = true
	var st: String = str(sh.station)
	if st != shared_station or shared_ui == null:
		if shared_ui != null:
			shared_ui.get_parent().queue_free()
		shared_station = st
		shared_ui = Stations.make(st, true)
		var holder: Control = Control.new()
		holder.size = Vector2(1280, 580)
		holder.add_child(shared_ui)
		shared_clip.add_child(holder)
	# lay the station out at a virtual size that matches the clipboard's shape, then scale it down
	var cs: Vector2 = shared_clip.size
	var vh: float = 560.0
	var vw: float = maxf(980.0, vh * cs.x / maxf(1.0, cs.y))
	var sc: float = minf(cs.x / vw, cs.y / vh)
	var holder2: Control = shared_ui.get_parent()
	holder2.size = Vector2(vw, vh)
	holder2.scale = Vector2(sc, sc)
	holder2.position = Vector2((cs.x - vw * sc) * 0.5, 0)
	shared_ui.apply(sh.view, f)

func _update_overlay(f: Dictionary) -> void:
	var phase: String = str(f.get("phase", ""))
	var ph: Dictionary = f.get("ph", {})
	var sig: String = phase
	if phase == "pitstop":
		for it in ph.get("items", []):
			sig += "%s%s%s" % [it.id, it.requested, it.bought]
		sig += str(ph.get("scrap", 0))
	elif phase != "staging":
		sig = ""
	if sig == overlay_sig:
		if phase == "staging":
			_update_staging(f)
		return
	overlay_sig = sig
	if overlay != null:
		overlay.queue_free()
		overlay = null
	map_panel = null
	ritual_lbl = null
	match phase:
		"staging":
			overlay = _staging_panel(f)
		"pitstop":
			overlay = _pit_panel(f)
	if overlay != null:
		overlay.set_meta("overlay", true)
		window_area.add_child(overlay)
		window_area.move_child(orders_panel, window_area.get_child_count() - 1)

func _staging_panel(f: Dictionary) -> Control:
	var ph: Dictionary = f.get("ph", {})
	var w: Array = UIK.window("SECTOR MAP: where to next, captain?", "navy", "map", 10)
	var p: Control = w[0]
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 28
	p.offset_right = -28
	p.offset_top = 20
	p.offset_bottom = -20
	var v: VBoxContainer = w[1]
	var h: HBoxContainer = UIK.hbox(10)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	map_panel = Screens.MapPanel.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.setup(ph.get("map", {}), ph.get("options", []), int(ph.get("ritual", {}).get("node", -1)))
	h.add_child(map_panel)
	var opts: VBoxContainer = UIK.vbox(6)
	opts.custom_minimum_size = Vector2(330, 0)
	h.add_child(opts)
	opts.add_child(UIK.heading("Destinations: read the code to Helm", 15))
	for o in ph.get("options", []):
		var pp: PanelContainer = UIK.panel("well", 8, 12)
		var vv: VBoxContainer = UIK.vbox(2)
		pp.add_child(vv)
		var hh: HBoxContainer = UIK.hbox(6)
		vv.add_child(hh)
		var nl: Label = UIK.heading(str(o.name), 15)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		hh.add_child(nl)
		hh.add_child(UIK.chip(str(o.code), "navy", "", 13))
		vv.add_child(UIK.wrapped(UIK.label(str(o.blurb) + ("   Threat " + "★".repeat(int(o.threat)) if int(o.threat) > 0 else ""), 13, K.pal("ink_soft"))))
		opts.add_child(pp)
	ritual_lbl = UIK.wrapped(UIK.label("", 14, K.pal("ink")))
	v.add_child(ritual_lbl)
	return p

func _update_staging(f: Dictionary) -> void:
	if ritual_lbl == null:
		return
	var rit: Dictionary = f.get("ph", {}).get("ritual", {})
	var ok: Dictionary = rit.get("ok", {})
	var mark: Callable = func(b: bool) -> String: return "✔" if b else "…"
	ritual_lbl.text = "Ritual:  %s coordinates   %s capacitor   %s speed %d   %s cargo%s   → then PUNCH IT" % [
		mark.call(ok.get("helm", false)), mark.call(ok.get("power", false)), mark.call(ok.get("engines", false)), int(rit.get("target_speed", 0)),
		mark.call(ok.get("ops", false)), "   OVERCHARGED!" if bool(rit.get("over", false)) else ""]

func _pit_panel(f: Dictionary) -> Control:
	var ph: Dictionary = f.get("ph", {})
	var w: Array = UIK.window("BUDGET MEETING AT MA GRISTLE'S  ·  scrap %d" % int(ph.get("scrap", 0)), "pink", "scrap", 10)
	var p: Control = w[0]
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 28
	p.offset_right = -28
	p.offset_top = 16
	p.offset_bottom = -16
	var v: VBoxContainer = w[1]
	v.add_child(UIK.speech("Shout at the captain for what you want, dearie. The captain holds the purse.", "gristle", "", 44))
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var g: GridContainer = UIK.grid(2, 8, 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	for it in ph.get("items", []):
		var row: PanelContainer = UIK.panel("mint" if it.requested else "well", 6, 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h: HBoxContainer = UIK.hbox(6)
		row.add_child(h)
		var lv: VBoxContainer = UIK.vbox(0)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lv)
		var who: String = ("  ← %s asks!" % K.seat_name(str(it.by))) if it.requested else ""
		lv.add_child(UIK.heading("%s%s" % [it.name, who], 14))
		lv.add_child(UIK.wrapped(UIK.label(str(it.desc), 12, K.pal("ink_soft"))))
		var iid: String = str(it.id)
		var b: Button = UIK.btn("Buy %d" % int(it.cost), "green", func(): Net.send("cap", {"cmd": "pit_buy", "id": iid}), "scrap")
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = int(it.cost) > int(ph.get("scrap", 0))
		h.add_child(b)
		g.add_child(row)
	v.add_child(UIK.btn("Done: back to the map", "orange", func(): Net.send("cap", {"cmd": "pit_done"}), "map"))
	return p

# ---------------------------------------------------------------- events from the host

func on_fx(d: Dictionary) -> void:
	match str(d.get("fx", "")):
		"boom":
			c3d.boom(Vector2(float(d.x), float(d.y)), float(d.size))
		"jump":
			c3d.jump_fx()
			frame.jump_flash = 1.2
		"scram":
			Sfx.play("powerdown")
		"alarm":
			Sfx.play("alarm")

func on_igor() -> void:
	pass

func on_bark(text: String) -> void:
	bark_lbl.text = text
	bark_t = 3.0

func _unhandled_key_input(e: InputEvent) -> void:
	if not is_visible_in_tree() or not (e is InputEventKey):
		return
	var ke: InputEventKey = e
	if ke.pressed and not ke.echo:
		match ke.keycode:
			KEY_O:
				if orders_btn.visible:
					orders_panel.visible = not orders_panel.visible
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				orders_panel.visible = false
