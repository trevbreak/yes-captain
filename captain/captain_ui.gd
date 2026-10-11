class_name CaptainUI
extends Control
## The captain's bridge: a 3D window, a dashboard of gauges, and a very small number of buttons.
## The captain can see. The captain cannot touch the ship. That is the whole joke.

const WIN: Rect2 = Rect2(78, 46, 1124, 416)

const ORDERS: Array = [
	["helm", [["Turn port 15°", "turn", {"dir": -1.0, "amount": 0.26}], ["Turn port 45°", "turn", {"dir": -1.0, "amount": 0.79}], ["Turn port 90°", "turn", {"dir": -1.0, "amount": 1.57}],
		["Turn starboard 15°", "turn", {"dir": 1.0, "amount": 0.26}], ["Turn starboard 45°", "turn", {"dir": 1.0, "amount": 0.79}], ["Turn starboard 90°", "turn", {"dir": 1.0, "amount": 1.57}],
		["Hold heading", "hold", {}], ["Strafe port", "strafe", {"dir": -1.0}], ["Strafe starboard", "strafe", {"dir": 1.0}], ["Stop strafing", "strafe", {"dir": 0.0}], ["EMERGENCY ROLL!", "roll", {"dir": 1.0}]]],
	["engines", [["Full ahead", "speed", {"v": 46.0}], ["Half ahead", "speed", {"v": 24.0}], ["Slow ahead", "speed", {"v": 10.0}], ["All stop", "stop", {}],
		["Boost ON", "boost", {"on": true}], ["Boost off", "boost", {"on": false}], ["Dampers OFF", "dampers", {"on": false}], ["Dampers on", "dampers", {"on": true}],
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

# ---------------------------------------------------------------- inner drawing classes

class BridgeFrame extends Control:
	var t: float = 0.0
	var smoke: Array = []
	var fog: bool = false
	var scram: bool = false
	var flash: float = 0.0
	var jump_flash: float = 0.0
	var bridge_hp: float = 100.0
	var shake: Vector2 = Vector2.ZERO
	var speed: float = 0.0
	var view_name: String = "fwd"
	var accel: float = 0.0
	var dice_swing: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		t += delta
		jump_flash = maxf(0.0, jump_flash - delta * 1.4)
		queue_redraw()

	func _draw() -> void:
		var ink: Color = K.pal("ink")
		var fc: Color = K.pal("plum2")
		var w: Rect2 = CaptainUI.WIN
		var wi: Rect2 = Rect2(w.position + Vector2(6, 6), w.size - Vector2(12, 12))
		# frame bars
		draw_rect(Rect2(0, 0, size.x, wi.position.y), fc)
		draw_rect(Rect2(0, wi.end.y, size.x, size.y - wi.end.y), fc)
		draw_rect(Rect2(0, wi.position.y, wi.position.x, wi.size.y), fc)
		draw_rect(Rect2(wi.end.x, wi.position.y, size.x - wi.end.x, wi.size.y), fc)
		# rounded window corners
		var cr: float = 34.0
		for corner in [[wi.position, Vector2(1, 1)], [Vector2(wi.end.x, wi.position.y), Vector2(-1, 1)], [Vector2(wi.position.x, wi.end.y), Vector2(1, -1)], [wi.end, Vector2(-1, -1)]]:
			var cp: Vector2 = corner[0]
			var dir: Vector2 = corner[1]
			var pts: PackedVector2Array = PackedVector2Array([cp])
			for i in range(0, 13):
				var a: float = float(i) / 12.0 * PI / 2.0
				pts.append(cp + Vector2(dir.x * (cr - cos(a) * cr), dir.y * (cr - sin(a) * cr)))
			draw_colored_polygon(pts, fc)
		draw_rect(wi, ink, false, 5.0)
		draw_rect(w, ink, false, 4.0)
		# bolts
		for bx in range(0, 22):
			var x: float = 40.0 + bx * 54.0
			draw_circle(Vector2(x, 36), 6.0, ink)
			draw_circle(Vector2(x, 36), 3.5, K.pal("lilac"))
		for by in [90.0, 200.0, 310.0, 410.0]:
			draw_circle(Vector2(36, by), 7.0, ink)
			draw_circle(Vector2(36, by), 4.0, K.pal("lilac"))
			draw_circle(Vector2(size.x - 36, by), 7.0, ink)
			draw_circle(Vector2(size.x - 36, by), 4.0, K.pal("lilac"))
		# dashboard slab
		draw_rect(Rect2(0, 470, size.x, size.y - 470), fc.darkened(0.2))
		draw_line(Vector2(0, 472), Vector2(size.x, 472), ink, 5.0)
		# fuzzy dice
		var sw: float = sin(t * 2.3) * 0.12 + dice_swing
		for dx in [0.0, 44.0]:
			var top: Vector2 = Vector2(w.position.x + 150 + dx, wi.position.y)
			var bottom: Vector2 = top + Vector2(sin(sw) * 70.0, cos(sw) * 70.0)
			draw_line(top, bottom, ink, 3.0)
			var sq: Rect2 = Rect2(bottom - Vector2(17, 5), Vector2(34, 34))
			draw_rect(sq, K.pal("pink"), true)
			draw_rect(sq, ink, false, 3.0)
			for pip in [Vector2(9, 9), Vector2(25, 9), Vector2(17, 17), Vector2(9, 25), Vector2(25, 25)]:
				draw_circle(sq.position + pip, 2.5, ink)
		# in-window overlays (clipped to the window by drawing inside wi)
		var font: Font = get_theme_default_font()
		if fog:
			for i in 7:
				var fx: float = wi.position.x + fmod(float(i) * 197.0 + t * 14.0, wi.size.x)
				var fy: float = wi.position.y + 50.0 + fmod(float(i) * 83.0, wi.size.y - 100.0)
				for k in 5:
					draw_circle(Vector2(fx, fy), 120.0 - float(k) * 22.0 + sin(t + i) * 8.0, Color(1, 1, 1, 0.035))
		for sm in smoke:
			var side: float = float(sm[1])
			var base_x: float = wi.position.x + 40.0 if side < -1.0 else (wi.end.x - 40.0 if side > 1.0 else wi.position.x + wi.size.x * 0.5 + side * 120.0)
			var inten: float = float(sm[2])
			for j in 6:
				var life: float = fmod(t * 0.7 + float(j) * 0.17 + float(sm[0]) * 0.03, 1.0)
				var px: float = base_x + sin(t * 2.0 + j) * 24.0
				var py: float = wi.end.y - 10.0 - life * 190.0 * inten
				var col: Color = Color(0.2, 0.18, 0.22, 0.45 * (1.0 - life))
				if inten >= 1.0:
					col = Color(0.95, 0.55, 0.2, 0.55 * (1.0 - life))
				draw_circle(Vector2(px, py), 14.0 + life * 30.0, col)
		if bridge_hp < 45.0:
			var cx: float = wi.position.x + wi.size.x * 0.62
			var pts2: PackedVector2Array = PackedVector2Array([Vector2(cx, wi.position.y), Vector2(cx - 30, wi.position.y + 120), Vector2(cx + 10, wi.position.y + 210), Vector2(cx - 40, wi.position.y + 330)])
			draw_polyline(pts2, Color(1, 1, 1, 0.85), 3.0)
			draw_line(pts2[2], pts2[2] + Vector2(90, 40), Color(1, 1, 1, 0.8), 2.0)
			draw_line(pts2[1], pts2[1] + Vector2(-80, 30), Color(1, 1, 1, 0.8), 2.0)
		if flash > 0.0:
			draw_rect(wi, Color(K.pal("coral"), clampf(flash * 1.4, 0.0, 0.5)), true)
		if scram:
			draw_rect(wi, Color(0.02, 0.0, 0.05, 0.93), true)
			draw_string(font, wi.position + Vector2(0, wi.size.y * 0.5), "EMERGENCY LIGHTING", HORIZONTAL_ALIGNMENT_CENTER, wi.size.x, 34, Color(K.pal("coral"), 0.5 + 0.5 * sin(t * 6.0)))
		if jump_flash > 0.0:
			draw_rect(wi, Color(1, 1, 1, clampf(jump_flash, 0.0, 1.0)), true)
		# window readouts
		draw_string(font, wi.position + Vector2(14, wi.size.y - 14), "VIEW: %s   SPEED %d m/s" % [view_name.to_upper(), int(speed)], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.85))

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
		var ink: Color = K.pal("ink")
		draw_style_box(UIK.box(Color(0.04, 0.12, 0.09), ink, 16, 5, 0), Rect2(Vector2.ZERO, size))
		var font: Font = get_theme_default_font()
		var g: Color = Color(0.45, 1.0, 0.65)
		draw_string(font, Vector2(14, 22), "COMMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(g, 0.6))
		var y: float = 44.0
		if lines.is_empty():
			var msg: String = "...static..." if waiting else "No transmissions."
			draw_string(font, Vector2(14, y), msg, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 16, Color(g, 0.7))
			if waiting:
				draw_string(font, Vector2(14, y + 22), "(Sensors, tune us in!)", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 14, Color(g, 0.6))
		for ln in lines:
			draw_string(font, Vector2(14, y), "%s:" % ln.from, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 15, K.pal("butter"))
			y += 18.0
			var txt: String = str(ln.text)
			var ws: Array = txt.split(" ")
			var cur: String = ""
			for wd in ws:
				if (cur + " " + wd).length() > 42:
					draw_string(font, Vector2(14, y), cur, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 14, g)
					y += 16.0
					cur = wd
				else:
					cur = (cur + " " + wd).strip_edges()
			draw_string(font, Vector2(14, y), cur, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 14, g)
			y += 20.0
			if y > size.y - 10.0:
				break
		for i in range(0, int(size.y), 4):
			draw_line(Vector2(6, i), Vector2(size.x - 6, i), Color(0, 0, 0, 0.18), 1.0)
		if waiting and lines.is_empty():
			for i in 40:
				draw_rect(Rect2(8 + randf() * (size.x - 16), 8 + randf() * (size.y - 16), 6, 3), Color(1, 1, 1, 0.2))

class TemperFace extends Control:
	var level: int = 1
	var tname: String = "Peeved"
	var rank: String = "Admiral"
	var t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var ink: Color = K.pal("ink")
		draw_style_box(UIK.box(Color(0.12, 0.08, 0.2), ink, 14, 4, 0), Rect2(Vector2.ZERO, size))
		var f: float = float(level - 1) / 4.0
		var skin: Color = K.pal("butter").lerp(K.pal("coral"), f)
		var c: Vector2 = Vector2(size.x * 0.5, 58.0)
		var shake: float = 0.0 if level < 5 else sin(t * 40.0) * 2.0
		c.x += shake
		draw_circle(c, 40.0, ink)
		draw_circle(c, 37.0, skin)
		# crown
		draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -30), c + Vector2(-18, -52), c + Vector2(-6, -34), c + Vector2(0, -56), c + Vector2(6, -34), c + Vector2(18, -52), c + Vector2(26, -30)]), K.pal("gold"))
		# brows get angrier
		var ang: float = f * 0.7
		draw_line(c + Vector2(-26, -12 - ang * 6), c + Vector2(-8, -12 + ang * 12), ink, 4.0)
		draw_line(c + Vector2(26, -12 - ang * 6), c + Vector2(8, -12 + ang * 12), ink, 4.0)
		for sx in [-1.0, 1.0]:
			draw_circle(c + Vector2(sx * 16, -2), 5.0, K.pal("white"))
			draw_circle(c + Vector2(sx * 16, -2), 2.5, ink)
		# mouth
		if level <= 1:
			draw_arc(c + Vector2(0, 14), 12.0, 0.2, PI - 0.2, 10, ink, 3.0)
		elif level == 2:
			draw_line(c + Vector2(-10, 20), c + Vector2(10, 20), ink, 3.0)
		else:
			draw_arc(c + Vector2(0, 28), 12.0, PI + 0.3, TAU - 0.3, 10, ink, 3.0)
		if level >= 5:
			for i in 3:
				draw_circle(c + Vector2(-44 + i * 6, -20 - i * 8) + Vector2(0, sin(t * 10 + i) * 2), 3.0, K.pal("coral"))
		var font: Font = get_theme_default_font()
		draw_string(font, Vector2(0, size.y - 34), tname.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, K.pal("white"))
		draw_string(font, Vector2(0, size.y - 14), "Lvl %d / 5" % level, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(1, 1, 1, 0.6))

class IgorEye extends Control:
	var t: float = 0.0
	var mood: float = 0.0
	var speaking: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		t += delta
		speaking = maxf(0.0, speaking - delta)
		queue_redraw()

	func _draw() -> void:
		var ink: Color = K.pal("ink")
		draw_style_box(UIK.box(K.pal("gunmetal"), ink, 16, 5, 0), Rect2(Vector2.ZERO, size))
		for i in 6:
			draw_line(Vector2(14, 16 + i * 5), Vector2(size.x - 14, 16 + i * 5), Color(0, 0, 0, 0.5), 2.0)
		var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.62)
		draw_circle(c, 32.0, ink)
		draw_circle(c, 28.0, K.pal("gunmetal2"))
		var mp: Vector2 = get_local_mouse_position()
		var dir: Vector2 = (mp - c)
		var look: Vector2 = dir.normalized() * minf(10.0, dir.length() * 0.1) + Vector2(sin(t * 0.7) * 6.0, 0)
		draw_circle(c + look, 15.0, K.pal("coral") if speaking > 0.0 else K.pal("tangerine"))
		draw_circle(c + look, 7.0, ink)
		draw_circle(c + look + Vector2(-3, -4), 2.5, K.pal("white"))
		var blink: float = clampf(sin(t * 0.9) * 8.0 - 7.2, 0.0, 1.0)
		if blink > 0.0:
			draw_rect(Rect2(c.x - 30, c.y - 30, 60, 60 * blink), K.pal("gunmetal2"), true)
		var font: Font = get_theme_default_font()
		draw_string(font, Vector2(0, 14), "IGOR", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, K.pal("white"))

class BridgeCam extends Control:
	var t: float = 0.0
	var shake: float = 0.0
	var mood: float = 0.0
	var loose: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var ink: Color = K.pal("ink")
		draw_style_box(UIK.box(Color(0.78, 0.74, 0.62), ink, 14, 4, 0), Rect2(Vector2.ZERO, size))
		draw_string(get_theme_default_font(), Vector2(10, 18), "BRIDGE CAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(ink, 0.6))
		var seats: Array = ["helm", "engines", "power", "weapons", "sensors", "ops"]
		for i in seats.size():
			var x: float = 28.0 + i * 46.0
			var y: float = size.y * 0.62 + sin(t * 3.0 + i) * (1.0 + shake * 14.0)
			var col: Color = K.pal(K.SEAT_INFO[seats[i]].color)
			draw_rect(Rect2(x - 14, y + 4, 28, 26), col, true)
			draw_rect(Rect2(x - 14, y + 4, 28, 26), ink, false, 2.0)
			draw_circle(Vector2(x, y - 6), 14.0, K.pal("cream"))
			draw_arc(Vector2(x, y - 6), 14.0, 0, TAU, 14, ink, 2.0)
			draw_circle(Vector2(x - 5, y - 8), 2.0, ink)
			draw_circle(Vector2(x + 5, y - 8), 2.0, ink)
			draw_line(Vector2(x - 4, y - 1), Vector2(x + 4, y - 1) + Vector2(0, sin(t * 5.0 + i) * 1.5), ink, 2.0)
			draw_rect(Rect2(x - 12, y - 24, 24, 8), col.darkened(0.15), true)
			draw_rect(Rect2(x - 12, y - 24, 24, 8), ink, false, 2.0)
		# Pudding wanders
		var px: float = size.x - 26.0 + (sin(t * 0.7) * 6.0 if not loose else sin(t * 2.0) * 120.0)
		var pc: Color = K.pal("pink").lerp(K.pal("coral"), clampf(mood / 100.0, 0.0, 1.0))
		var pr: float = 11.0 + mood / 100.0 * 4.0
		draw_circle(Vector2(clampf(px, 20, size.x - 20), size.y - 20), pr, ink)
		draw_circle(Vector2(clampf(px, 20, size.x - 20), size.y - 20), pr - 2.5, pc)

# ---------------------------------------------------------------- the real thing

var svc: SubViewportContainer
var sv: SubViewport
var c3d: Captain3D
var frame: BridgeFrame
var hull_dial: Dial
var shield_d: ShieldDiagram
var crt: CRT
var temper: TemperFace
var eye: IgorEye
var cam_strip: BridgeCam
var sticky: PanelContainer
var sticky_lbl: Label
var meters_box: VBoxContainer
var meters_sig: String = ""
var sheet_panel: PanelContainer
var sheet_lbl: Label
var orders_btn: Button
var orders_panel: PanelContainer
var order_tab: String = "helm"
var order_grid: VBoxContainer
var offer_panel: PanelContainer
var offer_lbl: Label
var offer_peer: int = 0
var shared_holder: PanelContainer
var shared_ui: StationUI = null
var shared_station: String = ""
var overlay: Control = null
var overlay_sig: String = ""
var punch_btn: Button
var status_lbl: Label
var view: Dictionary = {}
var full: Dictionary = {}
var last_hull: float = 100.0
var bark_lbl: Label
var bark_t: float = 0.0
var hail_flash: float = 0.0
var map_panel: Screens.MapPanel = null
var ritual_lbl: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	UIK.bg_color(self, K.pal("plum").darkened(0.2))
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.position = WIN.position + Vector2(8, 8)
	svc.size = WIN.size - Vector2(16, 16)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
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
	add_child(frame)
	_build_dashboard()
	_build_windows()

func _build_dashboard() -> void:
	hull_dial = Dial.new("HULL %", 0.0, 100.0, K.pal("green"))
	hull_dial.position = Vector2(26, 486)
	hull_dial.size = Vector2(140, 150)
	hull_dial.custom_minimum_size = Vector2(140, 150)
	add_child(hull_dial)
	shield_d = ShieldDiagram.new()
	shield_d.position = Vector2(178, 486)
	shield_d.custom_minimum_size = Vector2(150, 150)
	shield_d.size = Vector2(150, 150)
	shield_d.accent = K.pal("plum2")
	add_child(shield_d)
	crt = CRT.new()
	crt.position = Vector2(336, 486)
	crt.size = Vector2(340, 146)
	add_child(crt)
	cam_strip = BridgeCam.new()
	cam_strip.position = Vector2(690, 486)
	cam_strip.size = Vector2(300, 146)
	add_child(cam_strip)
	temper = TemperFace.new()
	temper.position = Vector2(1004, 482)
	temper.size = Vector2(126, 154)
	add_child(temper)
	eye = IgorEye.new()
	eye.position = Vector2(1140, 482)
	eye.size = Vector2(124, 154)
	add_child(eye)
	status_lbl = UIK.label("", 17, K.pal("cream"))
	status_lbl.position = Vector2(20, 2)
	status_lbl.size = Vector2(700, 30)
	add_child(status_lbl)
	orders_btn = UIK.btn("ORDERS  (O)", "butter", func(): orders_panel.visible = not orders_panel.visible)
	orders_btn.position = Vector2(1040, 2)
	add_child(orders_btn)
	punch_btn = UIK.btn("PUNCH IT!", "coral", func(): Net.send("cap", {"cmd": "punch"}))
	punch_btn.position = Vector2(860, 2)
	punch_btn.visible = false
	add_child(punch_btn)
	bark_lbl = UIK.label("", 18, K.pal("butter"))
	bark_lbl.position = Vector2(100, 430)
	bark_lbl.size = Vector2(900, 28)
	add_child(bark_lbl)

func _build_windows() -> void:
	# sticky note (objective): only the captain ever sees it
	sticky = PanelContainer.new()
	sticky.add_theme_stylebox_override("panel", UIK.box(Color.html("#fff2a6"), K.pal("ink"), 6, 3, 10))
	sticky.position = Vector2(96, 100)
	sticky.custom_minimum_size = Vector2(290, 0)
	sticky.size = Vector2(290, 130)
	sticky.rotation = -0.035
	sticky_lbl = UIK.label("", 17)
	sticky_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sticky.add_child(sticky_lbl)
	add_child(sticky)
	# meters (suspicion, cake integrity...)
	meters_box = UIK.vbox(4)
	var mp: PanelContainer = UIK.panel("cream", 6, 12)
	mp.add_child(meters_box)
	mp.position = Vector2(930, 64)
	mp.size = Vector2(250, 40)
	mp.name = "meters_panel"
	add_child(mp)
	# customs sheet etc.
	sheet_panel = PanelContainer.new()
	sheet_panel.add_theme_stylebox_override("panel", UIK.box(Color.html("#f3efe0"), K.pal("ink"), 8, 3, 10))
	sheet_panel.position = Vector2(96, 240)
	sheet_panel.size = Vector2(300, 100)
	sheet_lbl = UIK.label("", 15)
	sheet_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_panel.add_child(sheet_lbl)
	sheet_panel.visible = false
	add_child(sheet_panel)
	# orders menu
	orders_panel = UIK.panel("cream", 10, 18)
	orders_panel.position = Vector2(560, 50)
	orders_panel.size = Vector2(640, 410)
	orders_panel.visible = false
	var ov: HBoxContainer = UIK.hbox(10)
	orders_panel.add_child(ov)
	var tabs: VBoxContainer = UIK.vbox(4)
	ov.add_child(tabs)
	tabs.add_child(UIK.label("ORDER WHEEL", 16))
	for entry in ORDERS:
		var st: String = entry[0]
		var tb: Button = UIK.btn(K.seat_name(st), K.SEAT_INFO[st].color, func(): _show_orders(st))
		tb.custom_minimum_size = Vector2(120, 0)
		tabs.add_child(tb)
	tabs.add_child(UIK.spacer(true))
	tabs.add_child(UIK.btn("Close", "cream2", func(): orders_panel.visible = false))
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ov.add_child(sc)
	order_grid = UIK.vbox(5)
	order_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(order_grid)
	add_child(orders_panel)
	_show_orders("helm")
	# share offers
	offer_panel = UIK.panel("mint", 8, 16)
	offer_panel.position = Vector2(330, 380)
	offer_panel.size = Vector2(560, 70)
	offer_panel.visible = false
	var oh: HBoxContainer = UIK.hbox(8)
	offer_panel.add_child(oh)
	offer_lbl = UIK.label("", 17)
	offer_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oh.add_child(offer_lbl)
	oh.add_child(UIK.btn("Show me", "green", func(): Net.send("cap", {"cmd": "accept_share", "peer": offer_peer})))
	oh.add_child(UIK.btn("Not now", "cream2", func(): Net.send("cap", {"cmd": "decline_share", "peer": offer_peer})))
	add_child(offer_panel)
	# shared clipboard
	shared_holder = UIK.panel("butter", 8, 20)
	shared_holder.position = Vector2(180, 50)
	shared_holder.size = Vector2(930, 410)
	shared_holder.visible = false
	var sh_v: VBoxContainer = UIK.vbox(4)
	shared_holder.add_child(sh_v)
	var hh: HBoxContainer = UIK.hbox(6)
	sh_v.add_child(hh)
	hh.add_child(UIK.label("A crew member is showing you their screen", 16))
	hh.add_child(UIK.spacer(true))
	hh.add_child(UIK.btn("BACK TO WINDOW", "coral", func(): Net.send("cap", {"cmd": "stop_share"})))
	var clip: Control = Control.new()
	clip.name = "clip"
	clip.custom_minimum_size = Vector2(900, 372)
	clip.clip_contents = true
	sh_v.add_child(clip)
	add_child(shared_holder)

func _show_orders(st: String) -> void:
	order_tab = st
	for c in order_grid.get_children():
		c.queue_free()
	for entry in ORDERS:
		if entry[0] != st:
			continue
		order_grid.add_child(UIK.label("Orders for %s  (they only do what you SAY)" % K.seat_name(st), 15, Color(K.pal("ink"), 0.7)))
		for o in entry[1]:
			var label: String = o[0]
			var verb: String = o[1]
			var args: Dictionary = o[2]
			var b: Button = UIK.btn(label, K.SEAT_INFO[st].color, func():
				Net.send("cap", {"cmd": "order", "seat": st, "verb": verb, "args": args})
				Sfx.play("blip"))
			order_grid.add_child(b)

# ---------------------------------------------------------------- per-snapshot

func apply(v: Dictionary, f: Dictionary) -> void:
	view = v
	full = f
	var com: Dictionary = f.get("common", {})
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
	hull_dial.value = hull_pct
	hull_dial.accent = K.pal("green").lerp(K.pal("coral"), clampf(1.0 - hull_pct / 100.0, 0.0, 1.0))
	hull_dial.danger_above = 1e9
	shield_d.shields = v.get("shield", [0, 0, 0, 0])
	shield_d.weights = [1, 1, 1, 1]
	var run: Dictionary = f.get("run", {})
	temper.level = int(run.get("temper", 1))
	temper.tname = str(run.get("temper_name", "Peeved"))
	temper.rank = str(run.get("rank", "Admiral"))
	crt.lines = v.get("comms", [])
	crt.waiting = bool(v.get("hail_wait", false))
	cam_strip.shake = float(v.get("shake", 0.0))
	cam_strip.mood = float(v.get("crew", {}).get("pud_mood", 0.0))
	cam_strip.loose = bool(v.get("crew", {}).get("loose", false))
	var phase: String = str(f.get("phase", ""))
	var note: String = str(v.get("note", ""))
	if phase == "staging":
		note = "JUMP RITUAL! Pick a destination on the map, tell Helm the coordinates, then PUNCH IT when everyone says they're ready."
	elif phase == "pitstop":
		note = "Ma Gristle's Diner. The Budget Meeting: your crew will pitch. You hold the scrap."
	sticky_lbl.text = note if note != "" else "Nothing on the sticky note. Suspicious."
	sticky.visible = phase in ["encounter", "staging", "pitstop", "jumping"]
	sticky.size.y = 0
	status_lbl.text = "%s    Scrap %d   Fuel %d   Thrupp: %s" % [str(com.get("ship_name", "")), int(run.get("scrap", 0)), int(run.get("fuel", 0)), str(run.get("rank", ""))]
	# meters
	var meters: Array = v.get("meters", [])
	var msig: String = ""
	for m in meters:
		msig += str(m.label)
	if msig != meters_sig:
		meters_sig = msig
		for c in meters_box.get_children():
			c.queue_free()
		for m2 in meters:
			var bg: BarGauge = BarGauge.new(str(m2.label), float(m2.max), K.pal(str(m2.color)))
			bg.name = "m_" + str(m2.label)
			bg.custom_minimum_size = Vector2(230, 26)
			meters_box.add_child(bg)
	for m3 in meters:
		var node: Node = meters_box.get_node_or_null("m_" + str(m3.label))
		if node != null:
			(node as BarGauge).value = float(m3.v)
			(node as BarGauge).text = "%s %d" % [m3.label, int(m3.v)]
	get_node("meters_panel").visible = not meters.is_empty() and phase == "encounter"
	var sheet: Array = v.get("sheet", [])
	sheet_panel.visible = not sheet.is_empty() and phase == "encounter"
	if sheet_panel.visible:
		sheet_lbl.text = "\n".join(sheet)
		sheet_panel.size.y = 0
	# share offers
	var offers: Array = f.get("offers", [])
	offer_panel.visible = not offers.is_empty() and f.get("shared", {}).is_empty()
	if offer_panel.visible:
		offer_peer = int(offers[0].peer)
		offer_lbl.text = "%s (%s) wants to show you their screen." % [offers[0].name, K.seat_name(str(offers[0].station))]
	_update_shared(f)
	punch_btn.visible = phase == "staging"
	orders_btn.visible = phase in ["encounter", "staging"]
	_update_overlay(f)
	bark_t = maxf(0.0, bark_t - 0.066)
	if bark_t <= 0.0:
		bark_lbl.text = ""
	if hull_pct < last_hull - 0.5:
		pass
	last_hull = hull_pct

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
			shared_ui.queue_free()
			shared_ui = null
			shared_station = ""
		return
	shared_holder.visible = true
	var st: String = str(sh.station)
	if st != shared_station or shared_ui == null:
		if shared_ui != null:
			shared_ui.queue_free()
		shared_station = st
		shared_ui = Stations.make(st, true)
		var holder: Control = Control.new()
		holder.size = Vector2(1280, 600)
		holder.scale = Vector2(0.64, 0.64)
		holder.position = Vector2.ZERO
		holder.add_child(shared_ui)
		_clip().add_child(holder)
	shared_ui.apply(sh.view, f)

func _clip() -> Control:
	return shared_holder.get_child(0).get_node("clip")

func _update_overlay(f: Dictionary) -> void:
	var phase: String = str(f.get("phase", ""))
	var ph: Dictionary = f.get("ph", {})
	var sig: String = phase
	if phase == "debrief":
		sig += str(ph.get("debrief", {}).get("title", "")) + str(ph.get("debrief", {}).get("time", 0))
	elif phase == "staging":
		sig += "map"
	elif phase == "pitstop":
		for it in ph.get("items", []):
			sig += "%s%s%s" % [it.id, it.requested, it.bought]
		sig += str(ph.get("scrap", 0))
	elif phase == "gameover":
		sig += str(ph.get("over", {}).get("reason", ""))
	if sig == overlay_sig:
		if phase == "staging":
			_update_staging(f)
		return
	overlay_sig = sig
	if overlay != null:
		overlay.queue_free()
		overlay = null
	map_panel = null
	match phase:
		"staging":
			overlay = _staging_panel(f)
		"pitstop":
			overlay = _pit_panel(f)
		"debrief":
			overlay = Screens.debrief_panel(ph, true, str(ph.get("mode", "run")), func(): Net.send("cap", {"cmd": "continue"}), func(): Net.send("cap", {"cmd": "retry"}), func(): Net.send("cap", {"cmd": "lobby"}))
		"gameover":
			overlay = Screens.gameover_panel(ph, true, str(ph.get("mode", "run")), func(): Net.send("cap", {"cmd": "continue"}), func(): Net.send("cap", {"cmd": "retry"}), func(): Net.send("cap", {"cmd": "lobby"}))
		"ending":
			overlay = Screens.ending_panel(ph, true, func(): Net.send("cap", {"cmd": "continue"}))
	if overlay != null:
		add_child(overlay)

func _staging_panel(f: Dictionary) -> Control:
	var ph: Dictionary = f.get("ph", {})
	var p: PanelContainer = UIK.panel("plum2", 10, 20)
	p.position = Vector2(410, 52)
	p.size = Vector2(760, 400)
	var v: VBoxContainer = UIK.vbox(6)
	p.add_child(v)
	v.add_child(UIK.label("SECTOR MAP: choose where to go", 22, K.pal("cream")))
	map_panel = Screens.MapPanel.new()
	map_panel.setup(ph.get("map", {}), ph.get("options", []), int(ph.get("ritual", {}).get("node", -1)))
	v.add_child(map_panel)
	var hint: Label = UIK.label("Read the coordinates of your choice out to HELM. Power charges the capacitor, Engines holds speed, Ops secures cargo. Then PUNCH IT (top right).", 15, K.pal("cream"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	ritual_lbl = UIK.label("", 16, K.pal("butter"))
	v.add_child(ritual_lbl)
	var opts: GridContainer = UIK.grid(3, 8, 4)
	v.add_child(opts)
	for o in ph.get("options", []):
		var pp: PanelContainer = UIK.panel("cream", 6, 12)
		var vv: VBoxContainer = UIK.vbox(0)
		pp.add_child(vv)
		vv.add_child(UIK.label("%s  [%s]" % [o.name, o.code], 15))
		var bl: Label = UIK.label(str(o.blurb) + ("  Threat %s" % "★".repeat(int(o.threat))), 13, Color(K.pal("ink"), 0.8))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(220, 0)
		vv.add_child(bl)
		opts.add_child(pp)
	return p

func _update_staging(f: Dictionary) -> void:
	if ritual_lbl == null:
		return
	var rit: Dictionary = f.get("ph", {}).get("ritual", {})
	var ok: Dictionary = rit.get("ok", {})
	ritual_lbl.text = "Coordinates %s   Capacitor %s   Speed %s   Cargo %s    (target speed %d)" % [
		"✔" if ok.get("helm", false) else "...", "✔" if ok.get("power", false) else "...",
		"✔" if ok.get("engines", false) else "...", "✔" if ok.get("ops", false) else "...", int(rit.get("target_speed", 0))]
	if bool(rit.get("over", false)):
		ritual_lbl.text += "   OVERCHARGED!"

func _pit_panel(f: Dictionary) -> Control:
	var ph: Dictionary = f.get("ph", {})
	var p: PanelContainer = UIK.panel("cream", 12, 22)
	p.position = Vector2(200, 50)
	p.size = Vector2(880, 410)
	var v: VBoxContainer = UIK.vbox(6)
	p.add_child(v)
	v.add_child(UIK.label("BUDGET MEETING AT MA GRISTLE'S      Scrap: %d" % int(ph.get("scrap", 0)), 24))
	v.add_child(UIK.label("Your crew will lobby you. You hold the purse. Approve what you like. Remember who funded whose shields.", 15, Color(K.pal("ink"), 0.75)))
	var g: GridContainer = UIK.grid(2, 10, 8)
	v.add_child(g)
	for it in ph.get("items", []):
		var row: PanelContainer = UIK.panel("mint" if it.requested else "cream2", 6, 12)
		var h: HBoxContainer = UIK.hbox(6)
		row.add_child(h)
		var lv: VBoxContainer = UIK.vbox(0)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lv)
		var who: String = ("  ← %s asks!" % K.seat_name(str(it.by))) if it.requested else ("  (%s)" % K.seat_name(str(it.station)))
		lv.add_child(UIK.label("%s%s" % [it.name, who], 15))
		var dl: Label = UIK.label(str(it.desc), 13, Color(K.pal("ink"), 0.75))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(300, 0)
		lv.add_child(dl)
		var iid: String = str(it.id)
		var b: Button = UIK.btn("BUY %d" % int(it.cost), "green", func(): Net.send("cap", {"cmd": "pit_buy", "id": iid}))
		b.disabled = int(it.cost) > int(ph.get("scrap", 0))
		h.add_child(b)
		g.add_child(row)
	v.add_child(UIK.spacer(true))
	v.add_child(UIK.btn("DONE: BACK TO THE MAP  ►", "tangerine", func(): Net.send("cap", {"cmd": "pit_done"})))
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
	eye.speaking = 3.0


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
