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
var key_thr: float = 0.0

func build() -> void:
	var h: HBoxContainer = UIK.hbox(14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	# throttle levers
	var lv: HBoxContainer = UIK.hbox(8)
	h.add_child(lv)
	lev_p = Lever.new("PORT", -1.0, 1.0, accent)
	lev_p.custom_minimum_size = Vector2(90, 330)
	lev_p.marks = [-0.5, 0.5, 1.0]
	lev_p.changed.connect(func(v: float): _thr(v, true))
	lv.add_child(lev_p)
	var chain: VBoxContainer = UIK.vbox(4)
	chain.alignment = BoxContainer.ALIGNMENT_CENTER
	link_btn = UIK.toggle_btn("LINKED", "butter", func(on: bool): send("link", on))
	link_btn.disabled = readonly
	chain.add_child(link_btn)
	lv.add_child(chain)
	lev_s = Lever.new("STAR", -1.0, 1.0, accent)
	lev_s.custom_minimum_size = Vector2(90, 330)
	lev_s.marks = [-0.5, 0.5, 1.0]
	lev_s.changed.connect(func(v: float): _thr(v, false))
	lv.add_child(lev_s)
	# dials
	var dials: VBoxContainer = UIK.vbox(6)
	dials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(dials)
	var dr: HBoxContainer = UIK.hbox(8)
	dials.add_child(dr)
	speed_dial = Dial.new("SPEED m/s", 0.0, 100.0, accent)
	speed_dial.custom_minimum_size = Vector2(170, 170)
	dr.add_child(speed_dial)
	heat_dial = Dial.new("ENGINE HEAT", 0.0, 130.0, K.pal("coral"))
	heat_dial.danger_above = 100.0
	heat_dial.custom_minimum_size = Vector2(170, 170)
	dr.add_child(heat_dial)
	mix_dial = Dial.new("MIXTURE", 0.0, 1.0, K.pal("mint"))
	mix_dial.band_lo = 0.36
	mix_dial.band_hi = 0.64
	mix_dial.decimals = 2
	mix_dial.custom_minimum_size = Vector2(170, 170)
	dr.add_child(mix_dial)
	var mr: HBoxContainer = UIK.hbox(8)
	dials.add_child(mr)
	var lean: Button = UIK.btn("◄ LEAN", "mint", func(): send("mix", -0.04))
	lean.disabled = readonly
	mr.add_child(lean)
	var rich: Button = UIK.btn("RICH ►", "mint", func(): send("mix", 0.04))
	rich.disabled = readonly
	mr.add_child(rich)
	mr.add_child(UIK.label("Keep the needle in the green or thrust drops and heat climbs.", 14, Color(K.pal("ink"), 0.7)))
	accel_lbl = UIK.label("", 18)
	dials.add_child(accel_lbl)
	stat_lbl = UIK.label("", 16)
	stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dials.add_child(stat_lbl)
	var br: HBoxContainer = UIK.hbox(10)
	dials.add_child(br)
	boost_btn = UIK.toggle_btn("BOOST (burns heat)", "tangerine", func(on: bool): send("boost", on))
	boost_btn.disabled = readonly
	br.add_child(boost_btn)
	damp_btn = SafetyBtn.new("DAMPERS OFF", "coral")
	damp_btn.fired.connect(func(): send("dampers", false))
	br.add_child(damp_btn)
	damp_on_btn = UIK.btn("DAMPERS ON", "green", func(): send("dampers", true))
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
	accel_lbl.text = "Acceleration: %.1f m/s²" % float(view.get("accel", 0.0))
	var linked: bool = bool(view.get("link", true))
	link_btn.set_pressed_no_signal(linked)
	link_btn.text = "LINKED" if linked else "UNLINKED"
	lev_p.set_value(float(view.get("thr_p", 0.0)))
	lev_s.set_value(float(view.get("thr_s", 0.0)))
	boost_btn.set_pressed_no_signal(bool(view.get("boost", false)))
	var damp: bool = bool(view.get("dampers", true))
	damp_btn.visible = damp
	damp_on_btn.visible = not damp
	var txt: String = ""
	for side in ["p", "s"]:
		var st: int = int(view.get("st_" + side, 0))
		var nm: String = "Port" if side == "p" else "Star"
		if bool(view.get("stuck_" + side, false)):
			txt += "%s engine STUCK AT FULL!  " % nm
		elif not bool(view.get("on_" + side, true)):
			txt += "%s engine DEAD / NO POWER.  " % nm
		elif st >= 2:
			txt += "%s engine faulted.  " % nm
		elif st == 1:
			txt += "%s engine rattling.  " % nm
	if not bool(view.get("dampers_ok", true)):
		txt += "Dampers offline."
	if not damp:
		txt += "  NEWTONIAN MODE: nothing slows you down!"
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
