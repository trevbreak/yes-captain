class_name PowerUI
extends StationUI

const SYS_LABELS: Dictionary = {"engines": "Engines", "rcs": "Helm jets", "weapons": "Weapons", "shields": "Shields", "sensors": "Sensors", "ops": "Ops / jump"}
const JARGON: Dictionary = {"engines": "Big Fans", "rcs": "Wiggle Jets", "weapons": "Pew Pews", "shields": "The Bubble", "sensors": "Eyeballs", "ops": "Doohickeys"}

var rows: Dictionary = {}
var reset_btns: Dictionary = {}
var avail_bar: BarGauge
var heat_dial: Dial
var cool_bar: BarGauge
var pump_btn: Button
var vent_btn: Button
var oc_opt: OptionButton
var oc_btn: SafetyBtn
var con_labels: Dictionary = {}
var iso_btns: Dictionary = {}
var charge_bar: BarGauge
var charge_btn: Button
var warn_lbl: Label
var scram_lbl: Label

func build() -> void:
	var h: HBoxContainer = UIK.hbox(12)
	add_body(h)
	var pw: Array = UIK.window("POWER PIPS", "power", "power", 10)
	(pw[0] as Control).custom_minimum_size = Vector2(390, 0)
	h.add_child(pw[0])
	var pv: VBoxContainer = pw[1]
	pv.add_child(UIK.wrapped(UIK.label("Click pips to share out power. 2 is normal. Over 4 trips the breaker!", 14, K.pal("ink_soft"))))
	for sys in K.SYSTEMS:
		var r: HBoxContainer = UIK.hbox(4)
		var pr: PipRow = PipRow.new(SYS_LABELS[sys], accent, 6)
		pr.custom_minimum_size = Vector2(300, 34)
		pr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var s_name: String = sys
		pr.changed.connect(func(n: int): send("alloc", {"sys": s_name, "n": n}))
		r.add_child(pr)
		var rb: Button = UIK.btn("Reset", "red", func(): send("reset_breaker", s_name))
		rb.add_theme_font_size_override("font_size", 14)
		rb.visible = false
		rb.disabled = readonly
		r.add_child(rb)
		pv.add_child(r)
		rows[sys] = pr
		reset_btns[sys] = rb
	avail_bar = BarGauge.new("", 14.0, accent)
	avail_bar.custom_minimum_size = Vector2(0, 26)
	pv.add_child(avail_bar)
	warn_lbl = UIK.heading("", 15, K.pal("red"))
	pv.add_child(warn_lbl)
	var oc: HBoxContainer = UIK.hbox(8)
	pv.add_child(oc)
	oc_opt = OptionButton.new()
	oc_opt.fit_to_longest_item = false
	oc_opt.custom_minimum_size = Vector2(130, 0)
	for sys2 in K.SYSTEMS:
		oc_opt.add_item(SYS_LABELS[sys2])
	oc.add_child(oc_opt)
	oc_btn = SafetyBtn.new("OVERCLOCK", "red")
	oc_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oc_btn.fired.connect(func(): send("oc", K.SYSTEMS[oc_opt.selected]))
	oc.add_child(oc_btn)
	var rw: Array = UIK.window("REACTOR", "red", "fire", 10)
	(rw[0] as Control).custom_minimum_size = Vector2(220, 0)
	h.add_child(rw[0])
	var rv: VBoxContainer = rw[1]
	heat_dial = Dial.new("reactor heat", 0.0, 100.0, K.pal("red"))
	heat_dial.danger_above = 85.0
	heat_dial.custom_minimum_size = Vector2(190, 170)
	rv.add_child(heat_dial)
	cool_bar = BarGauge.new("coolant", 100.0, K.pal("blue"))
	cool_bar.band_lo = 40.0
	cool_bar.band_hi = 100.0
	rv.add_child(cool_bar)
	pump_btn = UIK.hold_btn("Hold: pump", "blue", func(on: bool): send("pump", on), "fuel")
	pump_btn.disabled = readonly
	rv.add_child(pump_btn)
	vent_btn = UIK.btn("Vent heat", "orange", func(): send("vent", true), "fire")
	vent_btn.disabled = readonly
	rv.add_child(vent_btn)
	scram_lbl = UIK.wrapped(UIK.heading("", 15, K.pal("red")))
	rv.add_child(scram_lbl)
	var right: VBoxContainer = UIK.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var cw: Array = UIK.window("CONDUITS", "purple", "dc", 10)
	right.add_child(cw[0])
	(cw[1] as VBoxContainer).add_child(UIK.wrapped(UIK.label("Isolate a cut conduit BEFORE anyone splices it, or they get zapped.", 13, K.pal("ink_soft"))))
	for c in K.CONDUITS:
		var cr: HBoxContainer = UIK.hbox(6)
		var cl: Label = UIK.label(c, 15)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cr.add_child(cl)
		var cname: String = c
		var tb: Button = UIK.toggle_btn("Isolate", "orange", func(on: bool): send("isolate", {"cid": cname, "on": on}))
		tb.add_theme_font_size_override("font_size", 14)
		tb.disabled = readonly
		cr.add_child(tb)
		(cw[1] as VBoxContainer).add_child(cr)
		con_labels[c] = cl
		iso_btns[c] = tb
	var jw: Array = UIK.window("JUMP CAPACITOR", "yellow", "star", 10)
	right.add_child(jw[0])
	var cap: HBoxContainer = UIK.hbox(10)
	(jw[1] as VBoxContainer).add_child(cap)
	charge_bar = BarGauge.new("", 1.0, accent, true)
	charge_bar.custom_minimum_size = Vector2(40, 120)
	charge_bar.band_lo = 0.45
	charge_bar.band_hi = 0.62
	charge_bar.danger_above = 0.85
	cap.add_child(charge_bar)
	var cv: VBoxContainer = UIK.vbox(6)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.add_child(cv)
	cv.add_child(UIK.wrapped(UIK.label("Before a jump: charge it into the green band and hold it there.", 13, K.pal("ink_soft"))))
	charge_btn = UIK.hold_btn("Hold: charge", "yellow", func(on: bool): send("charge", on), "power")
	charge_btn.disabled = readonly
	cv.add_child(charge_btn)

func refresh() -> void:
	var jargon: bool = "jargon" in full.get("common", {}).get("mods", [])
	var alloc: Dictionary = view.get("alloc", {})
	var trip: Dictionary = view.get("tripped", {})
	for sys in K.SYSTEMS:
		var pr: PipRow = rows[sys]
		pr.title = JARGON[sys] if jargon else SYS_LABELS[sys]
		pr.set_value(int(alloc.get(sys, 0)))
		pr.tripped = bool(trip.get(sys, false))
		pr.boosted = str(view.get("oc_sys", "")) == sys
		reset_btns[sys].visible = pr.tripped
	var used: float = float(view.get("used", 0.0))
	var avail: float = float(view.get("avail", 12.0))
	avail_bar.value = used
	avail_bar.band_lo = 0.0
	avail_bar.band_hi = avail
	avail_bar.text = "using %d of %d pips" % [int(used), int(avail)]
	warn_lbl.text = "BROWNOUT! Everything at %d%%" % int(100.0 * float(view.get("brown", 1.0))) if float(view.get("brown", 1.0)) < 0.99 else ""
	heat_dial.value = float(view.get("heat", 0.0))
	cool_bar.value = float(view.get("cool_p", 0.0))
	cool_bar.text = "coolant%s" % (" LEAK!" if bool(view.get("leak", false)) else "")
	vent_btn.disabled = float(view.get("vent_cd", 0.0)) > 0.0 or readonly
	var st: float = float(view.get("scram_t", 0.0))
	if st > 0.0:
		scram_lbl.text = "REACTOR SCRAM! %.0fs" % st
	elif str(view.get("oc_sys", "")) != "":
		scram_lbl.text = "Overclocking %s (%.0fs)" % [str(view.oc_sys), float(view.get("oc_t", 0.0))]
	else:
		scram_lbl.text = ""
	var cons: Dictionary = view.get("cons", {})
	for c in K.CONDUITS:
		var cd: Dictionary = cons.get(c, {})
		var txt: String = c.substr(2)
		if cd.get("cut", false):
			txt += "  CUT!"
		elif cd.get("unknown", false):
			txt += "  ???"
		else:
			txt += "  ok"
		con_labels[c].text = txt
		con_labels[c].add_theme_color_override("font_color", K.pal("red") if cd.get("cut", false) else K.pal("ink"))
		iso_btns[c].set_pressed_no_signal(bool(cd.get("iso", false)))
	charge_bar.value = float(view.get("jump_charge", 0.0))

func _unhandled_key_input(e: InputEvent) -> void:
	if readonly or not is_visible_in_tree() or not (e is InputEventKey):
		return
	var ke: InputEventKey = e
	if ke.keycode == KEY_SPACE and not ke.echo:
		send("pump", ke.pressed)
		get_viewport().set_input_as_handled()
