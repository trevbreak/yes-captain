class_name PowerUI
extends StationUI

const SYS_LABELS: Dictionary = {"engines": "ENGINES", "rcs": "HELM / RCS", "weapons": "WEAPONS", "shields": "SHIELDS", "sensors": "SENSORS", "ops": "OPS / JUMP"}

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
	var h: HBoxContainer = UIK.hbox(14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	var left: VBoxContainer = UIK.vbox(6)
	left.custom_minimum_size = Vector2(400, 0)
	h.add_child(left)
	var hint: Label = UIK.label("POWER PIPS: click a pip. 2 = normal. Over 4 trips the breaker!", 15)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	for sys in K.SYSTEMS:
		var r: HBoxContainer = UIK.hbox(6)
		var pr: PipRow = PipRow.new(SYS_LABELS[sys], accent, 6)
		pr.custom_minimum_size = Vector2(320, 36)
		var s_name: String = sys
		pr.changed.connect(func(n: int): send("alloc", {"sys": s_name, "n": n}))
		r.add_child(pr)
		var rb: Button = UIK.btn("RESET", "coral", func(): send("reset_breaker", s_name))
		rb.visible = false
		rb.disabled = readonly
		r.add_child(rb)
		left.add_child(r)
		rows[sys] = pr
		reset_btns[sys] = rb
	avail_bar = BarGauge.new("", 12.0, K.pal("butter"))
	avail_bar.danger_above = 12.5
	avail_bar.custom_minimum_size = Vector2(300, 30)
	left.add_child(avail_bar)
	warn_lbl = UIK.label("", 16, K.pal("coral"))
	left.add_child(warn_lbl)
	var oc: HBoxContainer = UIK.hbox(8)
	left.add_child(oc)
	oc_opt = OptionButton.new()
	for sys2 in K.SYSTEMS:
		oc_opt.add_item(SYS_LABELS[sys2])
	oc.add_child(oc_opt)
	oc_btn = SafetyBtn.new("OVERCLOCK", "coral")
	oc_btn.fired.connect(func(): send("oc", K.SYSTEMS[oc_opt.selected]))
	oc.add_child(oc_btn)
	# reactor
	var mid: VBoxContainer = UIK.vbox(6)
	h.add_child(mid)
	heat_dial = Dial.new("REACTOR HEAT", 0.0, 100.0, K.pal("coral"))
	heat_dial.danger_above = 85.0
	heat_dial.custom_minimum_size = Vector2(200, 180)
	mid.custom_minimum_size = Vector2(210, 0)
	mid.add_child(heat_dial)
	cool_bar = BarGauge.new("COOLANT", 100.0, K.pal("teal"))
	cool_bar.band_lo = 40.0
	cool_bar.band_hi = 100.0
	mid.add_child(cool_bar)
	pump_btn = UIK.hold_btn("HOLD: PUMP COOLANT", "teal", func(on: bool): send("pump", on))
	pump_btn.disabled = readonly
	mid.add_child(pump_btn)
	vent_btn = UIK.btn("VENT HEAT", "mustard", func(): send("vent", true))
	vent_btn.disabled = readonly
	mid.add_child(vent_btn)
	scram_lbl = UIK.label("", 18, K.pal("coral"))
	mid.add_child(scram_lbl)
	# conduits + capacitor
	var right: VBoxContainer = UIK.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	right.add_child(UIK.label("CONDUITS (isolate before splicing!)", 15))
	for c in K.CONDUITS:
		var cr: HBoxContainer = UIK.hbox(6)
		var cl: Label = UIK.label(c, 15)
		cl.custom_minimum_size = Vector2(100, 0)
		cr.add_child(cl)
		var cname: String = c
		var tb: Button = UIK.toggle_btn("ISOLATE", "mustard", func(on: bool): send("isolate", {"cid": cname, "on": on}))
		tb.disabled = readonly
		cr.add_child(tb)
		right.add_child(cr)
		con_labels[c] = cl
		iso_btns[c] = tb
	right.add_child(UIK.label("JUMP CAPACITOR", 15))
	var cap: HBoxContainer = UIK.hbox(8)
	right.add_child(cap)
	charge_bar = BarGauge.new("", 1.0, K.pal("butter"), true)
	charge_bar.custom_minimum_size = Vector2(46, 150)
	charge_bar.band_lo = 0.45
	charge_bar.band_hi = 0.62
	charge_bar.danger_above = 0.85
	cap.add_child(charge_bar)
	charge_btn = UIK.hold_btn("HOLD:\nCHARGE", "butter", func(on: bool): send("charge", on))
	charge_btn.disabled = readonly
	charge_btn.custom_minimum_size = Vector2(110, 80)
	cap.add_child(charge_btn)

const JARGON: Dictionary = {"engines": "BIG FANS", "rcs": "WIGGLE JETS", "weapons": "PEW PEWS", "shields": "THE BUBBLE", "sensors": "EYEBALLS", "ops": "DOOHICKEYS"}

func refresh() -> void:
	var jargon: bool = "jargon" in full.get("common", {}).get("mods", [])
	for sysn in K.SYSTEMS:
		rows[sysn].title = JARGON[sysn] if jargon else SYS_LABELS[sysn]
	var alloc: Dictionary = view.get("alloc", {})
	var trip: Dictionary = view.get("tripped", {})
	for sys in K.SYSTEMS:
		var pr: PipRow = rows[sys]
		pr.set_value(int(alloc.get(sys, 0)))
		pr.tripped = bool(trip.get(sys, false))
		pr.boosted = str(view.get("oc_sys", "")) == sys
		reset_btns[sys].visible = pr.tripped
	var used: float = float(view.get("used", 0.0))
	var avail: float = float(view.get("avail", 12.0))
	avail_bar.value = used
	avail_bar.vmax = 14.0
	avail_bar.band_lo = 0.0
	avail_bar.band_hi = avail
	avail_bar.text = "USING %d of %d available pips" % [int(used), int(avail)]
	warn_lbl.text = "BROWNOUT! Everything runs at %d%%." % int(100.0 * float(view.get("brown", 1.0))) if float(view.get("brown", 1.0)) < 0.99 else ""
	heat_dial.value = float(view.get("heat", 0.0))
	cool_bar.value = float(view.get("cool_p", 0.0))
	cool_bar.text = "COOLANT PRESSURE%s" % ("  (LEAK!)" if bool(view.get("leak", false)) else "")
	vent_btn.disabled = float(view.get("vent_cd", 0.0)) > 0.0 or readonly
	var st: float = float(view.get("scram_t", 0.0))
	if st > 0.0:
		scram_lbl.text = "REACTOR SCRAM! %.0fs" % st
	elif str(view.get("oc_sys", "")) != "":
		scram_lbl.text = "OVERCLOCKING %s (%.0fs)" % [str(view.oc_sys).to_upper(), float(view.get("oc_t", 0.0))]
	else:
		scram_lbl.text = ""
	var cons: Dictionary = view.get("cons", {})
	for c in K.CONDUITS:
		var cd: Dictionary = cons.get(c, {})
		var txt: String = c
		if cd.get("cut", false):
			txt += "  CUT!"
		elif cd.get("unknown", false):
			txt += "  ???"
		else:
			txt += "  ok"
		con_labels[c].text = txt
		iso_btns[c].set_pressed_no_signal(bool(cd.get("iso", false)))
	charge_bar.value = float(view.get("jump_charge", 0.0))

func _unhandled_key_input(e: InputEvent) -> void:
	if readonly or not is_visible_in_tree() or not (e is InputEventKey):
		return
	var ke: InputEventKey = e
	if ke.keycode == KEY_SPACE and not ke.echo:
		send("pump", ke.pressed)
		get_viewport().set_input_as_handled()
