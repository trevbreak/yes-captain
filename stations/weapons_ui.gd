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
	var h: HBoxContainer = UIK.hbox(10)
	add_body(h)
	var sw: Array = UIK.window("GUN SCOPE", "weapons", "weapons", 8)
	h.add_child(sw[0])
	scope = Scope.new()
	scope.custom_minimum_size = Vector2(228, 228)
	(sw[1] as VBoxContainer).add_child(scope)
	stow_btn = UIK.toggle_btn("Stow guns", "orange", func(on: bool): send("stow", on), "lock")
	stow_btn.disabled = readonly
	(sw[1] as VBoxContainer).add_child(stow_btn)
	(sw[1] as VBoxContainer).add_child(UIK.wrapped(UIK.label("Space fires, L loads, T swaps turret.", 13, K.pal("ink_soft")), 240))
	var mid: VBoxContainer = UIK.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	for tid in ["TUR_A", "TUR_B"]:
		mid.add_child(_make_turret(tid))
	var right: VBoxContainer = UIK.vbox(10)
	right.custom_minimum_size = Vector2(200, 0)
	h.add_child(right)
	var tw: Array = UIK.window("TORPEDO", "red", "fire", 8)
	right.add_child(tw[0])
	tube_lbl = UIK.wrapped(UIK.label("", 14))
	(tw[1] as VBoxContainer).add_child(tube_lbl)
	tube_bar = BarGauge.new("", 1.0, K.pal("orange"))
	tube_bar.custom_minimum_size = Vector2(0, 16)
	(tw[1] as VBoxContainer).add_child(tube_bar)
	var tr: HBoxContainer = UIK.hbox(6)
	(tw[1] as VBoxContainer).add_child(tr)
	tube_load = UIK.hold_btn("Load", "orange", func(on: bool): send("load", {"id": "TUBE", "on": on}))
	tube_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tube_load.disabled = readonly
	tr.add_child(tube_load)
	tube_arm = UIK.btn("Arm", "yellow", func(): send("torp_arm", true))
	tube_arm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tube_arm.disabled = readonly
	tr.add_child(tube_arm)
	tube_fire = SafetyBtn.new("TORPEDO!", "red")
	tube_fire.fired.connect(func(): send("torp_fire", true))
	(tw[1] as VBoxContainer).add_child(tube_fire)
	var lw: Array = UIK.window("TARGET LOCK", "purple", "weapons", 8)
	(lw[0] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(lw[0])
	lock_lbl = UIK.wrapped(UIK.label("No lock", 14))
	(lw[1] as VBoxContainer).add_child(lock_lbl)
	weak_btn = UIK.toggle_btn("Aim at weak spot", "red", func(on: bool): send("weak", on))
	weak_btn.add_theme_font_size_override("font_size", 14)
	weak_btn.disabled = readonly
	(lw[1] as VBoxContainer).add_child(weak_btn)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(lw[1] as VBoxContainer).add_child(sc)
	lock_box = UIK.vbox(4)
	lock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lock_box)

func _make_turret(tid: String) -> Control:
	var w: Array = UIK.window("PORT TURRET" if tid == "TUR_A" else "STARBOARD TURRET", "weapons" if tid == "TUR_A" else "red", "weapons", 8)
	var hb: HBoxContainer = UIK.hbox(8)
	(w[1] as VBoxContainer).add_child(hb)
	var arc: ArcGauge = ArcGauge.new()
	arc.custom_minimum_size = Vector2(86, 86)
	arc.accent = accent
	hb.add_child(arc)
	var v: VBoxContainer = UIK.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var aim: Lever = Lever.new("aim", -PI, PI, accent, true)
	aim.custom_minimum_size = Vector2(0, 58)
	aim.step = 0.01
	aim.snap_zero = false
	aim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aim.changed.connect(func(a: float): send("aim", {"id": tid, "ang": a}))
	v.add_child(aim)
	var row: HBoxContainer = UIK.hbox(4)
	v.add_child(row)
	var sel_b: Button = UIK.toggle_btn("Scope", "neutral", func(_on: bool): send("sel", tid))
	sel_b.disabled = readonly
	row.add_child(sel_b)
	var load_b: Button = UIK.hold_btn("Load", "orange", func(on: bool): send("load", {"id": tid, "on": on}))
	load_b.disabled = readonly
	row.add_child(load_b)
	var fire_b: Button = UIK.btn("Fire", "red", func(): send("fire", tid), "weapons")
	fire_b.disabled = readonly
	row.add_child(fire_b)
	var track_b: Button = UIK.toggle_btn("Track", "sensors", func(on: bool): send("track", {"id": tid, "on": on}))
	track_b.disabled = readonly
	row.add_child(track_b)
	for b in [sel_b, load_b, fire_b, track_b]:
		(b as Button).add_theme_font_size_override("font_size", 14)
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heat: BarGauge = BarGauge.new("barrel heat", 100.0, K.pal("orange"))
	heat.danger_above = 85.0
	heat.custom_minimum_size = Vector2(0, 18)
	v.add_child(heat)
	var st: Label = UIK.label("", 14, K.pal("ink_soft"))
	v.add_child(st)
	tur_ui[tid] = {"arc": arc, "aim": aim, "title": sel_b, "load": load_b, "fire": fire_b, "track": track_b, "heat": heat, "st": st}
	return w[0]

func refresh() -> void:
	sel_id = str(view.get("sel", "TUR_A"))
	scope.contacts = view.get("scope", [])
	scope.lock_id = int(view.get("lock", {}).get("id", -1))
	scope.title = "%s TURRET" % ("PORT" if sel_id == "TUR_A" else "STAR")
	for t in view.get("turrets", []):
		var d: Dictionary = tur_ui[t.id]
		var arc: ArcGauge = d.arc
		arc.lo = float(t.lo)
		arc.hi = float(t.hi)
		arc.ang = float(t.ang)
		arc.tgt = float(t.tgt)
		arc.jam = bool(t.jam)
		arc.queue_redraw()
		var aim: Lever = d.aim
		aim.vmin = float(t.lo)
		aim.vmax = float(t.hi)
		aim.fmt = "%.0f"
		aim.set_value(float(t.tgt))
		(d.title as Button).set_pressed_no_signal(t.id == sel_id)
		(d.heat as BarGauge).value = float(t.heat)
		(d.track as Button).set_pressed_no_signal(bool(t.track))
		var s: String = "Loaded" if t.loaded else "Empty: hold Load"
		if not t.online:
			s = "No power / broken"
		elif bool(t.jam):
			s = "JAMMED! Fires on its own!"
		elif float(t.cd) > 1.0:
			s = "Overheated"
		(d.st as Label).text = "%s  ·  %d°" % [s, int(round(rad_to_deg(float(t.ang))))]
	var tube: Dictionary = view.get("tube", {})
	var ts: String = str(tube.get("state", "empty"))
	tube_lbl.text = {"empty": "Tube empty. Hold Load.", "loaded": "Loaded. Press Arm.", "arming": "Arming...", "armed": "ARMED. Fire when ready!"}.get(ts, ts)
	if not bool(tube.get("online", true)):
		tube_lbl.text = "Tube offline!"
	tube_bar.value = float(tube.get("load_p", 0.0)) if ts == "empty" else (float(tube.get("arm_p", 0.0)) if ts == "arming" else 1.0)
	tube_fire.disabled = ts != "armed" or readonly
	stow_btn.set_pressed_no_signal(bool(view.get("stowed", false)))
	var lock: Dictionary = view.get("lock", {})
	lock_lbl.text = "No lock. Sensors must scan a target first." if lock.is_empty() else "Locked: %s  (%dm)" % [lock.name, int(lock.d)]
	weak_btn.set_pressed_no_signal(bool(view.get("lock_weak", false)))
	var sig: String = ""
	for l in view.get("locks", []):
		sig += "%d:%s|" % [l.id, l.name]
	if sig != lock_sig:
		lock_sig = sig
		for c in lock_box.get_children():
			c.queue_free()
		for l2 in view.get("locks", []):
			var lid: int = int(l2.id)
			var b: Button = UIK.btn("%s  %dm" % [l2.name, int(l2.d)], "purple", func(): send("lock", lid), "weapons")
			b.add_theme_font_size_override("font_size", 14)
			b.clip_text = true
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
