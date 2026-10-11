class_name WeaponsUI
extends StationUI

var scope: Scope
var tur_ui: Dictionary = {}
var tube_lbl: Label
var tube_bar: BarGauge
var tube_load: Button
var tube_arm: Button
var tube_fire: SafetyBtn
var lock_box: VBoxContainer
var lock_sig: String = ""
var lock_lbl: Label
var weak_btn: Button
var stow_btn: Button
var sel_id: String = "TUR_A"

func build() -> void:
	var h: HBoxContainer = UIK.hbox(12)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	scope = Scope.new()
	scope.custom_minimum_size = Vector2(290, 290)
	h.add_child(scope)
	var mid: VBoxContainer = UIK.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	for tid in ["TUR_A", "TUR_B"]:
		mid.add_child(_make_turret(tid))
	stow_btn = UIK.toggle_btn("STOW GUNS", "mustard", func(on: bool): send("stow", on))
	stow_btn.disabled = readonly
	mid.add_child(stow_btn)
	var right: VBoxContainer = UIK.vbox(6)
	right.custom_minimum_size = Vector2(228, 0)
	h.add_child(right)
	right.add_child(UIK.label("TORPEDO", 17))
	tube_lbl = UIK.label("", 15)
	tube_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(tube_lbl)
	tube_bar = BarGauge.new("", 1.0, K.pal("tangerine"))
	right.add_child(tube_bar)
	var tr: HBoxContainer = UIK.hbox(4)
	right.add_child(tr)
	tube_load = UIK.hold_btn("LOAD", "tangerine", func(on: bool): send("load", {"id": "TUBE", "on": on}))
	tube_load.disabled = readonly
	tr.add_child(tube_load)
	tube_arm = UIK.btn("ARM", "mustard", func(): send("torp_arm", true))
	tube_arm.disabled = readonly
	tr.add_child(tube_arm)
	tube_fire = SafetyBtn.new("TORPEDO!", "coral")
	tube_fire.fired.connect(func(): send("torp_fire", true))
	right.add_child(tube_fire)
	right.add_child(UIK.label("TARGET LOCK (scanned only)", 17))
	lock_lbl = UIK.label("No lock", 15)
	lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(lock_lbl)
	weak_btn = UIK.toggle_btn("AIM AT WEAK SPOT", "coral", func(on: bool): send("weak", on))
	weak_btn.disabled = readonly
	right.add_child(weak_btn)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 120)
	right.add_child(sc)
	lock_box = UIK.vbox(4)
	lock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lock_box)

func _make_turret(tid: String) -> Control:
	var d: Dictionary = {}
	var p: PanelContainer = UIK.panel("cream2", 6, 14)
	var hb: HBoxContainer = UIK.hbox(8)
	p.add_child(hb)
	var arc: ArcGauge = ArcGauge.new()
	arc.custom_minimum_size = Vector2(92, 92)
	arc.accent = accent
	hb.add_child(arc)
	var v: VBoxContainer = UIK.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var title: Button = UIK.toggle_btn("PORT TURRET" if tid == "TUR_A" else "STAR TURRET", "coral", func(on: bool): send("sel", tid))
	title.disabled = readonly
	v.add_child(title)
	var aim: Lever = Lever.new("AIM", -PI, PI, accent, true)
	aim.custom_minimum_size = Vector2(0, 70)
	aim.step = 0.01
	aim.snap_zero = false
	aim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aim.changed.connect(func(a: float): send("aim", {"id": tid, "ang": a}))
	v.add_child(aim)
	var row: HBoxContainer = UIK.hbox(4)
	v.add_child(row)
	var load_b: Button = UIK.hold_btn("LOAD", "mustard", func(on: bool): send("load", {"id": tid, "on": on}))
	load_b.disabled = readonly
	row.add_child(load_b)
	var fire_b: Button = UIK.btn("FIRE", "coral", func(): send("fire", tid))
	fire_b.disabled = readonly
	row.add_child(fire_b)
	var track_b: Button = UIK.toggle_btn("TRACK", "mint", func(on: bool): send("track", {"id": tid, "on": on}))
	track_b.disabled = readonly
	row.add_child(track_b)
	var heat: BarGauge = BarGauge.new("barrel heat", 100.0, K.pal("tangerine"))
	heat.danger_above = 85.0
	heat.custom_minimum_size = Vector2(0, 20)
	v.add_child(heat)
	var st: Label = UIK.label("", 14)
	v.add_child(st)
	d = {"arc": arc, "aim": aim, "title": title, "load": load_b, "fire": fire_b, "track": track_b, "heat": heat, "st": st}
	tur_ui[tid] = d
	return p

func refresh() -> void:
	sel_id = str(view.get("sel", "TUR_A"))
	scope.contacts = view.get("scope", [])
	scope.lock_id = int(view.get("lock", {}).get("id", -1))
	scope.title = "SCOPE: %s" % ("PORT" if sel_id == "TUR_A" else "STAR")
	for t in view.get("turrets", []):
		var d: Dictionary = tur_ui[t.id]
		var arc: ArcGauge = d.arc
		arc.lo = float(t.lo)
		arc.hi = float(t.hi)
		arc.ang = float(t.ang)
		arc.tgt = float(t.tgt)
		arc.jam = bool(t.jam)
		var aim: Lever = d.aim
		aim.vmin = float(t.lo)
		aim.vmax = float(t.hi)
		aim.fmt = "%.0f°"
		aim.set_value(float(t.tgt))
		(d.title as Button).set_pressed_no_signal(t.id == sel_id)
		(d.heat as BarGauge).value = float(t.heat)
		(d.track as Button).set_pressed_no_signal(bool(t.track))
		var s: String = "LOADED" if t.loaded else "empty (hold LOAD)"
		if not t.online:
			s = "NO POWER / DEAD"
		elif bool(t.jam):
			s = "JAMMED! It fires on its own!"
		elif float(t.cd) > 1.0:
			s = "OVERHEATED"
		(d.st as Label).text = "%s   angle %d°" % [s, int(round(rad_to_deg(float(t.ang))))]
	var tube: Dictionary = view.get("tube", {})
	var ts: String = str(tube.get("state", "empty"))
	tube_lbl.text = {"empty": "Tube empty. Hold LOAD.", "loaded": "Loaded. Press ARM (takes 1.6s).", "arming": "Arming...", "armed": "ARMED and ready!"}.get(ts, ts)
	if not bool(tube.get("online", true)):
		tube_lbl.text = "Tube offline!"
	tube_bar.value = float(tube.get("load_p", 0.0)) if ts == "empty" else (float(tube.get("arm_p", 0.0)) if ts == "arming" else 1.0)
	tube_fire.disabled = ts != "armed" or readonly
	stow_btn.set_pressed_no_signal(bool(view.get("stowed", false)))
	var lock: Dictionary = view.get("lock", {})
	if lock.is_empty():
		lock_lbl.text = "No lock. Ask Sensors to scan something."
	else:
		lock_lbl.text = "LOCKED: %s  %dm" % [lock.name, int(lock.d)]
	weak_btn.set_pressed_no_signal(bool(view.get("lock_weak", false)))
	var sig: String = ""
	for l in view.get("locks", []):
		sig += "%d:%s|" % [l.id, l.name]
	if sig != lock_sig:
		lock_sig = sig
		for c in lock_box.get_children():
			c.queue_free()
		for l in view.get("locks", []):
			var lid: int = int(l.id)
			var b: Button = UIK.btn("%s (%dm)" % [l.name, int(l.d)], "mint", func(): send("lock", lid))
			b.disabled = readonly
			lock_box.add_child(b)

func _unhandled_key_input(e: InputEvent) -> void:
	if readonly or not is_visible_in_tree() or not (e is InputEventKey):
		return
	var ke: InputEventKey = e
	if ke.echo:
		return
	match ke.keycode:
		KEY_SPACE:
			if ke.pressed:
				send("fire", sel_id)
			get_viewport().set_input_as_handled()
		KEY_L:
			send("load", {"id": sel_id, "on": ke.pressed})
			get_viewport().set_input_as_handled()
		KEY_T:
			if ke.pressed:
				send("sel", "TUR_B" if sel_id == "TUR_A" else "TUR_A")
			get_viewport().set_input_as_handled()
