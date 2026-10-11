class_name SensorsUI
extends Station
## Sensors: the radar. Click a blip, hold SCAN, and the captain finds out what it is.
## Later: the comms dial (mission 5) and deep scans for weak spots (mission 6).

var radar: Radar
var scan_btn: BigButton
var sel_card: Label
var sel_sub: Label
var comms_box: VBoxContainer
var knob: Knob
var sig_bar: Gauges.Bar
var msg_lbl: Label
var from_lbl: Label
var _sel: int = -1
var _blips: Array = []
var _freq: float = 0.5
var _turn: float = 0.0

func _init() -> void:
	super("sensors")

func build() -> void:
	radar = Radar.new()
	radar.custom_minimum_size = Vector2(450, 450)
	radar.picked.connect(func(id: int):
		_sel = id
		send("select", id))
	hero.add_child(radar)
	var col: VBoxContainer = UIK.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(230, 0)
	hero.add_child(col)
	var card: PanelContainer = UIK.panel("panel_small", [4, 2, 4, 2])
	col.add_child(card)
	var cv: VBoxContainer = UIK.vbox(0)
	card.add_child(cv)
	cv.add_child(UIK.head("SELECTED", 16, K.pal("ink_soft")))
	sel_card = UIK.head("Nothing", 24)
	cv.add_child(sel_card)
	sel_sub = UIK.para("Click a blip on the radar.", 18)
	cv.add_child(sel_sub)
	scan_btn = BigButton.new("SCAN", "green", true, 140)
	scan_btn.key_hint = "Space"
	scan_btn.held.connect(func(on: bool): send("scan", on))
	col.add_child(UIK.center(scan_btn))
	col.add_child(UIK.btn("Next blip", "cream", _cycle, "", 18))
	comms_box = side_window("COMMS", "teal", "speaker")
	comms_box.add_child(UIK.para("Turn the dial until the signal locks, then READ THE MESSAGE OUT LOUD.", 18))
	var kr: HBoxContainer = UIK.hbox(8)
	comms_box.add_child(kr)
	knob = Knob.new()
	knob.custom_minimum_size = Vector2(120, 120)
	knob.changed.connect(func(v: float):
		_freq = v
		send("freq", v))
	kr.add_child(knob)
	var kv: VBoxContainer = UIK.vbox(4)
	kv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kr.add_child(kv)
	from_lbl = UIK.head("No signal", 18)
	kv.add_child(from_lbl)
	sig_bar = Gauges.Bar.new("teal", 30)
	sig_bar.marker = 0.8
	kv.add_child(sig_bar)
	var mp: PanelContainer = UIK.panel("well", [2, 2, 2, 2])
	comms_box.add_child(mp)
	msg_lbl = UIK.para("...static...", 21)
	mp.add_child(msg_lbl)
	keys_lbl.text = "Click a blip (or TAB), then hold SPACE to scan.   Q / E turn the comms dial."

func _cycle() -> void:
	if _blips.is_empty():
		return
	var ids: Array = []
	for b in _blips:
		ids.append(int(b.id))
	var i: int = ids.find(_sel)
	_sel = ids[(i + 1) % ids.size()]
	send("select", _sel)

func _process(dt: float) -> void:
	if not is_visible_in_tree() or not feat("comms"):
		return
	var d: float = (1.0 if held(KEY_E) else 0.0) - (1.0 if held(KEY_Q) else 0.0)
	if d != 0.0:
		_freq = clampf(_freq + d * 0.25 * dt, 0.0, 1.0)
		knob.set_value(_freq)
		_turn += dt
		if _turn > 0.06:
			_turn = 0.0
			send("freq", _freq)

func refresh(v: Dictionary, _com: Dictionary) -> void:
	radar.view = v
	_blips = v.get("blips", [])
	_sel = int(v.get("selected", -1))
	radar.selected = _sel
	var b: Dictionary = {}
	for x in _blips:
		if int(x.id) == _sel:
			b = x
	if b.is_empty():
		sel_card.text = "Nothing"
		sel_sub.text = "Click a blip on the radar." if bool(v.get("ok", true)) else "Sensors are broken. Ask the Engineer!"
	else:
		sel_card.text = str(b.name) if bool(b.scanned) else "Unknown!"
		var bits: String = "%dm away. " % int(b.dist)
		if not bool(b.scanned):
			bits += "Hold SCAN to find out what it is."
		elif str(b.kind) == "cruiser" and feat("weakspot") and not bool(b.weak):
			bits += "Scan AGAIN to find its weak spot."
		elif bool(b.weak):
			bits += "Weak spot: the vent at the BACK."
		else:
			bits += "Hostile!" if bool(b.hostile) else "Not a threat."
		sel_sub.text = bits
	scan_btn.set_progress(float(v.get("prog", 0.0)) if bool(v.get("scanning", false)) else -1.0)
	scan_btn.set_disabled(not bool(v.get("ok", true)))
	comms_box.get_parent().get_parent().visible = feat("comms")
	var cm: Dictionary = v.get("comms", {})
	if not knob._drag and not (held(KEY_Q) or held(KEY_E)):
		_freq = float(v.get("freq", 0.5))
		knob.set_value(_freq)
	if cm.is_empty():
		from_lbl.text = "No signal"
		sig_bar.set_value(0.0, "")
		msg_lbl.text = "...static..."
	else:
		from_lbl.text = "Hail: " + str(cm.from)
		var sig: float = float(cm.signal)
		sig_bar.set_value(sig, "LOCKED" if bool(cm.heard) else "%d%%" % int(sig * 100.0))
		sig_bar.set_colour(UIK.c("green") if sig > 0.8 else UIK.c("teal"))
		msg_lbl.text = ("\"%s\"" % str(cm.text)) if bool(cm.heard) else ("...crackle... " + "▮".repeat(int(sig * 10.0)))

func on_key(k: Key, down: bool) -> bool:
	match k:
		KEY_SPACE:
			scan_btn.press_key(down)
			return true
		KEY_TAB:
			if down:
				_cycle()
			return true
		KEY_Q, KEY_E:
			if not down and feat("comms"):
				send("freq", _freq)
			return feat("comms")
	return false

class Knob extends Control:
	## a brass tuning knob: drag round to turn. value 0..1 over 270 degrees.
	signal changed(v: float)
	var value: float = 0.5
	var _drag: bool = false
	var _last: float = 0.0
	var _tex: Texture2D

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		_tex = Art.tex("prop_knob", 1.2)

	func set_value(v: float, emit: bool = false) -> void:
		v = clampf(v, 0.0, 1.0)
		if absf(v - value) > 0.0005:
			value = v
			queue_redraw()
			if emit:
				changed.emit(value)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
			_last = (e.position - size / 2.0).angle()
			accept_event()
		elif e is InputEventMouseMotion and _drag:
			var a: float = (e.position - size / 2.0).angle()
			set_value(value + wrapf(a - _last, -PI, PI) / deg_to_rad(270.0), true)
			_last = a
			accept_event()

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		var c: Vector2 = size / 2.0
		for i in 19:
			var a: float = deg_to_rad(135.0 + 270.0 * i / 18.0)
			draw_line(c + Vector2.from_angle(a) * s * 0.44, c + Vector2.from_angle(a) * s * (0.5 if i % 3 == 0 else 0.47), UIK.ink(), 2.5, true)
		draw_set_transform(c, deg_to_rad(-135.0 + 270.0 * value), Vector2.ONE)
		draw_texture_rect(_tex, Rect2(-Vector2(s, s) * 0.4, Vector2(s, s) * 0.8), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
