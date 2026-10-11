class_name EnginesUI
extends StationUI

var lev_p: Lever
var lev_s: Lever
var link_btn: Button
var speed_dial: Dial
var heat_dial: Dial
var mix_dial: Dial
var accel_lbl: Label
var boost_btn: Button
var damp_btn: SafetyBtn
var damp_on_btn: Button
var stat_lbl: Label

func build() -> void:
	var h: HBoxContainer = UIK.hbox(12)
	add_body(h)
	var tw: Array = UIK.window("THROTTLES   (W / S, X = stop)", "engines", "engines", 10)
	h.add_child(tw[0])
	var lv: HBoxContainer = UIK.hbox(4)
	lv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(tw[1] as VBoxContainer).add_child(lv)
	lev_p = Lever.new("PORT", -1.0, 1.0, accent)
	lev_p.custom_minimum_size = Vector2(84, 300)
	lev_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lev_p.marks = [-0.5, 0.5]
	lev_p.changed.connect(func(v: float): _thr(v, true))
	lv.add_child(lev_p)
	lev_s = Lever.new("STAR", -1.0, 1.0, accent)
	lev_s.custom_minimum_size = Vector2(84, 300)
	lev_s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lev_s.marks = [-0.5, 0.5]
	lev_s.changed.connect(func(v: float): _thr(v, false))
	lv.add_child(lev_s)
	link_btn = UIK.toggle_btn("Linked", "yellow", func(on: bool): send("link", on))
	link_btn.disabled = readonly
	(tw[1] as VBoxContainer).add_child(link_btn)
	var right: VBoxContainer = UIK.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var gw: Array = UIK.window("GAUGES", "blue", "clock", 10)
	right.add_child(gw[0])
	var dr: HBoxContainer = UIK.hbox(6)
	dr.alignment = BoxContainer.ALIGNMENT_CENTER
	(gw[1] as VBoxContainer).add_child(dr)
	speed_dial = Dial.new("speed m/s", 0.0, 100.0, accent)
	speed_dial.custom_minimum_size = Vector2(156, 156)
	dr.add_child(speed_dial)
	heat_dial = Dial.new("engine heat", 0.0, 130.0, K.pal("red"))
	heat_dial.danger_above = 100.0
	heat_dial.custom_minimum_size = Vector2(156, 156)
	dr.add_child(heat_dial)
	mix_dial = Dial.new("fuel mixture", 0.0, 1.0, K.pal("sensors"))
	mix_dial.band_lo = 0.36
	mix_dial.band_hi = 0.64
	mix_dial.decimals = 2
	mix_dial.custom_minimum_size = Vector2(156, 156)
	dr.add_child(mix_dial)
	var mr: HBoxContainer = UIK.hbox(8)
	(gw[1] as VBoxContainer).add_child(mr)
	var lean: Button = UIK.btn("◄ Lean", "sensors", func(): send("mix", -0.04))
	lean.disabled = readonly
	mr.add_child(lean)
	var rich: Button = UIK.btn("Rich ►", "sensors", func(): send("mix", 0.04))
	rich.disabled = readonly
	mr.add_child(rich)
	var mh: Label = UIK.wrapped(UIK.label("Keep the mixture needle in the green, or thrust drops and heat climbs.", 13, K.pal("ink_soft")))
	mh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mr.add_child(mh)
	var sw: Array = UIK.window("DRIVE SYSTEMS", "neutral", "warning", 10)
	right.add_child(sw[0])
	accel_lbl = UIK.heading("", 17)
	(sw[1] as VBoxContainer).add_child(accel_lbl)
	stat_lbl = UIK.wrapped(UIK.label("", 15))
	(sw[1] as VBoxContainer).add_child(stat_lbl)
	var br: HBoxContainer = UIK.hbox(10)
	(sw[1] as VBoxContainer).add_child(br)
	boost_btn = UIK.toggle_btn("Boost (hot!)", "orange", func(on: bool): send("boost", on), "fire")
	boost_btn.disabled = readonly
	br.add_child(boost_btn)
	damp_btn = SafetyBtn.new("DAMPERS OFF", "red")
	damp_btn.fired.connect(func(): send("dampers", false))
	br.add_child(damp_btn)
	damp_on_btn = UIK.btn("Dampers on", "green", func(): send("dampers", true))
	damp_on_btn.disabled = readonly
	br.add_child(damp_on_btn)

func _thr(v: float, port: bool) -> void:
	if bool(view.get("link", true)):
		send("thr", v)
		if port:
			lev_s.value = v
			lev_s.queue_redraw()
		else:
			lev_p.value = v
			lev_p.queue_redraw()
	else:
		send("thr_p" if port else "thr_s", v)

func _update_ritual_extra(rit: Dictionary, _ph: Dictionary) -> void:
	var t: float = float(rit.get("target_speed", 0.0))
	speed_dial.band_lo = t - 4.0
	speed_dial.band_hi = t + 4.0

func refresh() -> void:
	if full.get("phase", "") != "staging":
		speed_dial.band_lo = -1.0
		speed_dial.band_hi = -1.0
	speed_dial.value = float(view.get("speed", 0.0))
	heat_dial.value = float(view.get("heat", 0.0))
	mix_dial.value = float(view.get("mix", 0.5))
	accel_lbl.text = "Acceleration  %.1f m/s²" % float(view.get("accel", 0.0))
	var linked: bool = bool(view.get("link", true))
	link_btn.set_pressed_no_signal(linked)
	link_btn.text = "Linked" if linked else "Unlinked"
	lev_p.set_value(float(view.get("thr_p", 0.0)))
	lev_s.set_value(float(view.get("thr_s", 0.0)))
	boost_btn.set_pressed_no_signal(bool(view.get("boost", false)))
	var damp: bool = bool(view.get("dampers", true))
	damp_btn.visible = damp
	damp_on_btn.visible = not damp
	var txt: String = ""
	for side_k in ["p", "s"]:
		var st: int = int(view.get("st_" + side_k, 0))
		var nm: String = "Port" if side_k == "p" else "Star"
		if bool(view.get("stuck_" + side_k, false)):
			txt += "%s engine STUCK AT FULL! " % nm
		elif not bool(view.get("on_" + side_k, true)):
			txt += "%s engine dead or unpowered. " % nm
		elif st >= 2:
			txt += "%s engine faulted. " % nm
		elif st == 1:
			txt += "%s engine rattling. " % nm
	if not bool(view.get("dampers_ok", true)):
		txt += "Dampers offline. "
	if not damp:
		txt += "NEWTONIAN MODE: nothing slows you down!"
	stat_lbl.text = txt if txt != "" else "Both engines happy. IGOR is unconvinced."

func _unhandled_key_input(e: InputEvent) -> void:
	if readonly or not is_visible_in_tree() or not (e is InputEventKey):
		return
	var ke: InputEventKey = e
	if not ke.pressed:
		return
	var cur: float = float(view.get("thr_p", 0.0))
	match ke.keycode:
		KEY_W, KEY_UP:
			send("thr", clampf(cur + 0.1, -1.0, 1.0))
			get_viewport().set_input_as_handled()
		KEY_S, KEY_DOWN:
			send("thr", clampf(cur - 0.1, -1.0, 1.0))
			get_viewport().set_input_as_handled()
		KEY_X:
			send("thr", 0.0)
			get_viewport().set_input_as_handled()
