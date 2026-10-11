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
	var h: HBoxContainer = UIK.hbox(10)
	add_body(h)
	var rw: Array = UIK.window("RADAR  (north is up · click a contact)", "sensors", "sensors", 8)
	h.add_child(rw[0])
	radar = Radar.new()
	radar.custom_minimum_size = Vector2(420, 420)
	radar.picked.connect(func(id: int): selected = id)
	(rw[1] as VBoxContainer).add_child(radar)
	info_lbl = UIK.label("", 13, K.pal("ink_soft"))
	(rw[1] as VBoxContainer).add_child(info_lbl)
	var right: VBoxContainer = UIK.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var cw: Array = UIK.window("CONTACT", "blue", "map", 8)
	right.add_child(cw[0])
	sel_lbl = UIK.wrapped(UIK.label("Click a contact on the radar.", 15))
	(cw[1] as VBoxContainer).add_child(sel_lbl)
	var sr: HBoxContainer = UIK.hbox(6)
	(cw[1] as VBoxContainer).add_child(sr)
	scan_btn = UIK.hold_btn("Hold to scan", "sensors", func(on: bool): send("scan", {"id": selected, "on": on and selected >= 0}), "sensors")
	scan_btn.disabled = readonly
	sr.add_child(scan_btn)
	scan_bar = BarGauge.new("", 1.0, K.pal("sensors"))
	scan_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sr.add_child(scan_bar)
	var mw: Array = UIK.window("COMMS  (tune until it locks: it drifts!)", "purple", "share", 8)
	right.add_child(mw[0])
	freq_lever = Lever.new("frequency", 0.0, 1.0, K.pal("purple"), true)
	freq_lever.snap_zero = false
	freq_lever.step = 0.005
	freq_lever.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	freq_lever.changed.connect(func(v: float): send("set_freq", v))
	(mw[1] as VBoxContainer).add_child(freq_lever)
	q_bar = BarGauge.new("signal", 1.0, K.pal("yellow"))
	q_bar.band_lo = 0.87
	q_bar.band_hi = 1.0
	(mw[1] as VBoxContainer).add_child(q_bar)
	hail_lbl = UIK.wrapped(UIK.label("", 14))
	(mw[1] as VBoxContainer).add_child(hail_lbl)
	var vw: Array = UIK.window("CAPTAIN'S VIEWSCREEN", "navy", "captain", 8)
	right.add_child(vw[0])
	var vr: HBoxContainer = UIK.hbox(4)
	(vw[1] as VBoxContainer).add_child(vr)
	for pair in [["fwd", "Fwd"], ["aft", "Aft"], ["port", "Port"], ["stbd", "Stbd"], ["target", "Lock"]]:
		var key: String = pair[0]
		var b: Button = UIK.toggle_btn(pair[1], "neutral", func(_on: bool): send("view", key))
		b.add_theme_font_size_override("font_size", 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = readonly
		vr.add_child(b)
		view_btns[key] = b
	var ar: HBoxContainer = UIK.hbox(6)
	right.add_child(ar)
	ping_btn = SafetyBtn.new("ACTIVE PING", "red")
	ping_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ping_btn.fired.connect(func(): send("ping", true))
	ar.add_child(ping_btn)
	iscan_btn = UIK.btn("Internal scan", "blue", func(): send("iscan", true), "dc")
	iscan_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iscan_btn.disabled = readonly
	ar.add_child(iscan_btn)
	beacon_btn = UIK.btn("Deploy decoy beacon", "pink", func(): send("beacon", true), "pudding")
	beacon_btn.disabled = readonly
	right.add_child(beacon_btn)

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
		sel_lbl.text = "Click a contact on the radar to select it."
		scan_btn.disabled = true
	else:
		var txt: String = "%s  ·  %dm" % [found.name, int((found.p as Vector2).length())]
		if bool(found.scanned):
			txt += "\nScanned %ds ago. Hull %d%%. Weapons can lock it." % [int(found.age), int(found.get("hp", 100.0))]
		else:
			txt += "\nNot scanned yet: Weapons can't lock it."
		sel_lbl.text = txt
		scan_btn.disabled = readonly or str(found.kind) in ["waypoint", "mine"]
	var sc: Dictionary = view.get("scan", {})
	scan_bar.value = float(sc.get("progress", 0.0)) if int(sc.get("target", -1)) == selected else 0.0
	if not freq_lever.dragging:
		freq_lever.set_value(float(view.get("freq", 0.5)))
	var hail: Dictionary = view.get("hail", {})
	if hail.is_empty():
		q_bar.value = 0.0
		hail_lbl.text = "No incoming hail. Just static."
	else:
		q_bar.value = float(hail.q)
		hail_lbl.text = "INCOMING from %s! %s" % [hail.from, "Locked: relaying to the captain..." if bool(hail.tuned) else "Slide the dial until the bar fills."]
	ping_btn.disabled = float(view.get("ping_cd", 0.0)) > 0.0 or readonly
	iscan_btn.disabled = float(view.get("iscan_cd", 0.0)) > 0.0 or readonly
	iscan_btn.text = "Internal scan" if float(view.get("reveal_t", 0.0)) <= 0.0 else "Scanning (%ds)" % int(view.reveal_t)
	beacon_btn.text = "Deploy decoy beacon (%d)" % int(view.get("beacons", 0))
	beacon_btn.disabled = int(view.get("beacons", 0)) <= 0 or readonly
	info_lbl.text = "Range %dm (more power to Sensors = more range)%s" % [int(radar.range_m), "   ·   INCOMING FIRE!" if not radar.incoming.is_empty() else ""]
