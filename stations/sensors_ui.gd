class_name SensorsUI
extends StationUI

var radar: Radar
var sel_lbl: Label
var scan_btn: Button
var scan_bar: BarGauge
var freq_lever: Lever
var q_bar: BarGauge
var hail_lbl: Label
var view_btns: Dictionary = {}
var ping_btn: SafetyBtn
var iscan_btn: Button
var beacon_btn: Button
var info_lbl: Label
var selected: int = -1

func build() -> void:
	var h: HBoxContainer = UIK.hbox(12)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	radar = Radar.new()
	radar.picked.connect(func(id: int): selected = id)
	h.add_child(radar)
	var right: VBoxContainer = UIK.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	sel_lbl = UIK.label("Click a contact on the radar.", 17)
	sel_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(sel_lbl)
	var sr: HBoxContainer = UIK.hbox(6)
	right.add_child(sr)
	scan_btn = UIK.hold_btn("HOLD TO SCAN", "mint", func(on: bool): send("scan", {"id": selected, "on": on and selected >= 0}))
	scan_btn.disabled = readonly
	sr.add_child(scan_btn)
	scan_bar = BarGauge.new("", 1.0, K.pal("mint"))
	scan_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.add_child(scan_bar)
	right.add_child(HSeparator.new())
	right.add_child(UIK.label("COMMS: tune the dial until the signal locks (it drifts!)", 15))
	freq_lever = Lever.new("FREQUENCY", 0.0, 1.0, K.pal("mint"), true)
	freq_lever.snap_zero = false
	freq_lever.step = 0.005
	freq_lever.custom_minimum_size = Vector2(0, 80)
	freq_lever.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	freq_lever.changed.connect(func(v: float): send("set_freq", v))
	right.add_child(freq_lever)
	q_bar = BarGauge.new("SIGNAL", 1.0, K.pal("butter"))
	q_bar.band_lo = 0.87
	q_bar.band_hi = 1.0
	right.add_child(q_bar)
	hail_lbl = UIK.label("", 15)
	hail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(hail_lbl)
	right.add_child(HSeparator.new())
	right.add_child(UIK.label("CAPTAIN'S VIEWSCREEN DIRECTION", 15))
	var vr: HBoxContainer = UIK.hbox(4)
	right.add_child(vr)
	for pair in [["fwd", "FWD"], ["aft", "AFT"], ["port", "PORT"], ["stbd", "STBD"], ["target", "LOCK"]]:
		var key: String = pair[0]
		var b: Button = UIK.toggle_btn(pair[1], "butter", func(on: bool): send("view", key))
		b.disabled = readonly
		vr.add_child(b)
		view_btns[key] = b
	var ar: HBoxContainer = UIK.hbox(6)
	right.add_child(ar)
	ping_btn = SafetyBtn.new("ACTIVE PING", "coral")
	ping_btn.fired.connect(func(): send("ping", true))
	ar.add_child(ping_btn)
	iscan_btn = UIK.btn("INTERNAL SCAN", "teal", func(): send("iscan", true))
	iscan_btn.disabled = readonly
	ar.add_child(iscan_btn)
	beacon_btn = UIK.btn("DEPLOY BEACON", "pink", func(): send("beacon", true))
	beacon_btn.disabled = readonly
	right.add_child(beacon_btn)
	info_lbl = UIK.label("", 14, Color(K.pal("ink"), 0.75))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(info_lbl)

func refresh() -> void:
	radar.contacts = view.get("contacts", [])
	radar.incoming = view.get("incoming", [])
	radar.tele = view.get("tele", [])
	radar.heading = float(view.get("heading", -PI / 2.0))
	radar.range_m = float(view.get("range", 500.0))
	radar.mirror = bool(view.get("mirror", false))
	radar.ship_pos = view.get("pos", Vector2.ZERO)
	radar.locked = int(view.get("lock", -1))
	radar.ping_t = float(view.get("ping_t", 0.0))
	radar.rings = view.get("enc", {}).get("rings", [])
	radar.dock = view.get("enc", {}).get("dock", {})
	radar.selected = selected
	var vd: String = str(view.get("view", "fwd"))
	radar.view_ang = float(view.get("heading", 0.0)) + {"fwd": 0.0, "aft": PI, "port": -PI / 2.0, "stbd": PI / 2.0, "target": 0.0}.get(vd, 0.0)
	for k in view_btns.keys():
		view_btns[k].set_pressed_no_signal(k == vd)
	var found: Dictionary = {}
	for ct in radar.contacts:
		if int(ct.id) == selected:
			found = ct
	if found.is_empty():
		sel_lbl.text = "Click a contact on the radar to select it. Range %dm." % int(radar.range_m)
		scan_btn.disabled = true
	else:
		var txt: String = "%s  (%dm)" % [found.name, int((found.p as Vector2).length())]
		if bool(found.scanned):
			txt += "\nSCANNED %ds ago. Hull %d%%. Weapons can lock it." % [int(found.age), int(found.get("hp", 100.0))]
		else:
			txt += "\nNot scanned. Weapons can't lock it yet."
		sel_lbl.text = txt
		scan_btn.disabled = readonly or str(found.kind) in ["waypoint", "mine"]
	var sc: Dictionary = view.get("scan", {})
	scan_bar.value = float(sc.get("progress", 0.0)) if int(sc.get("target", -1)) == selected else 0.0
	if not freq_lever.dragging:
		freq_lever.set_value(float(view.get("freq", 0.5)))
	var hail: Dictionary = view.get("hail", {})
	if hail.is_empty():
		q_bar.value = 0.0
		hail_lbl.text = "No incoming hail. (Static: %.2f)" % float(view.get("freq", 0.5))
	else:
		q_bar.value = float(hail.q)
		hail_lbl.text = "INCOMING from %s! %s" % [hail.from, "LOCKED - relaying to captain..." if bool(hail.tuned) else "Tune the dial..."]
	ping_btn.disabled = float(view.get("ping_cd", 0.0)) > 0.0 or readonly
	iscan_btn.disabled = float(view.get("iscan_cd", 0.0)) > 0.0 or readonly
	iscan_btn.text = "INTERNAL SCAN" if float(view.get("reveal_t", 0.0)) <= 0.0 else "SCANNING INSIDE (%ds)" % int(view.reveal_t)
	beacon_btn.text = "DEPLOY BEACON (%d)" % int(view.get("beacons", 0))
	beacon_btn.disabled = int(view.get("beacons", 0)) <= 0 or readonly
	info_lbl.text = "Radar range %dm. Power to Sensors increases it.%s" % [int(radar.range_m), "  Beams are coming in!" if not radar.incoming.is_empty() else ""]
