class_name StationUI
extends Control
## Base for every station screen: the station's instruments on the left, and a side column with
## "show the captain", the jump ritual, customs forms, the pit-stop wishlist and this station's problems.

const SIDE_W: int = 280

var station: String = ""
var readonly: bool = false
var view: Dictionary = {}
var full: Dictionary = {}
var accent: Color = Color.WHITE
var body: Control
var side: VBoxContainer
var share_btn: Button
var emp_lbl: PanelContainer
var fault_panel: PanelContainer
var fault_box: VBoxContainer
var fault_rows: Dictionary = {}
var fault_sig: String = "init"
var enc_panel: PanelContainer
var enc_box: VBoxContainer
var enc_sig: String = ""
var enc_btns: Dictionary = {}
var ritual_panel: PanelContainer
var ritual_box: VBoxContainer
var ritual_extra: Control = null
var ritual_steps: Label = null
var wish_panel: PanelContainer
var wish_box: VBoxContainer
var wish_sig: String = ""
var blocker: Control = null
var phase_now: String = ""

func _init(st: String = "", ro: bool = false) -> void:
	station = st
	readonly = ro
	accent = K.pal(UIK.seat_color(st))
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	build()
	if readonly:
		blocker = Control.new()
		blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(blocker)

func send(key: String, val: Variant = true) -> void:
	if readonly:
		return
	Net.intent(station, key, val)

func build() -> void:
	pass

func refresh() -> void:
	pass

func add_body(c: Control) -> Control:
	## helper: put the station's main layout container into the body, filling it
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# leave room for the windows' drop shadows: the body clips its contents
	c.offset_right = -4
	c.offset_bottom = -10
	body.add_child(c)
	return c

func _build_frame() -> void:
	var row: HBoxContainer = UIK.hbox(10)
	var m: MarginContainer = UIK.margin(row, 10)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var bp: PanelContainer = PanelContainer.new()
	var bs: StyleBoxFlat = UIK.sb(K.pal("well"), UIK.RADIUS, accent, 3, 12, 10)
	bp.add_theme_stylebox_override("panel", bs)
	bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(bp)
	body = Control.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	bp.add_child(body)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(SIDE_W, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	side = UIK.vbox(10)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(side)
	if not readonly and station != "dc":
		share_btn = UIK.toggle_btn("Show the captain", "sensors", func(on: bool): Net.send("share", {"on": on}), "share")
		side.add_child(share_btn)
	emp_lbl = UIK.chip("EMP! CONTROLS INVERTED", "red", "warning", 15)
	emp_lbl.visible = false
	side.add_child(emp_lbl)
	ritual_box = UIK.vbox(6)
	ritual_panel = UIK.titled("JUMP RITUAL", "yellow", ritual_box, "star")
	ritual_panel.visible = false
	side.add_child(ritual_panel)
	enc_box = UIK.vbox(6)
	enc_panel = UIK.titled("FORM", "blue", enc_box, "crew")
	enc_panel.visible = false
	side.add_child(enc_panel)
	wish_box = UIK.vbox(6)
	wish_panel = UIK.titled("WISHLIST", "yellow", wish_box, "scrap")
	wish_panel.visible = false
	side.add_child(wish_panel)
	fault_box = UIK.vbox(6)
	fault_panel = UIK.titled("PROBLEMS", "red", fault_box, "warning")
	side.add_child(fault_panel)

# ---------------------------------------------------------------- per-snapshot update

func apply(v: Dictionary, f: Dictionary) -> void:
	view = v
	full = f
	phase_now = str(f.get("phase", ""))
	if emp_lbl != null:
		var et: float = float(v.get("emp_t", 0.0))
		emp_lbl.visible = et > 0.0
		if et > 0.0:
			for l in emp_lbl.find_children("*", "Label", true, false):
				(l as Label).text = "EMP! CONTROLS INVERTED  %ds" % int(et)
	if share_btn != null:
		var want: bool = bool(f.get("sharing", false)) or bool(f.get("shared_now", false))
		if share_btn.button_pressed != want:
			share_btn.set_pressed_no_signal(want)
		share_btn.text = "Captain is watching!" if f.get("shared_now", false) else ("Waiting for captain..." if want else "Show the captain")
	_update_faults(v.get("faults", []))
	_update_enc(v.get("enc", {}))
	_update_ritual(f.get("ph", {}))
	_update_wish(f.get("ph", {}))
	refresh()

func _update_faults(faults: Array) -> void:
	var sig: String = ""
	for fl in faults:
		sig += "%s:%d:%s:%s:%s:%s|" % [fl.id, fl.state, fl.fire, fl.breach, fl.nopower, str(fl.task.get("kind", ""))]
	if sig != fault_sig:
		fault_sig = sig
		for c in fault_box.get_children():
			c.queue_free()
		fault_rows.clear()
		if faults.is_empty():
			var q: HBoxContainer = UIK.hbox(8)
			q.add_child(UIK.icon_rect("check", 22, K.pal("green")))
			q.add_child(UIK.wrapped(UIK.label("All quiet. IGOR is suspicious.", 15, K.pal("ink_soft"))))
			(q.get_child(1) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fault_box.add_child(q)
		for fl in faults:
			_make_fault_row(fl)
	for fl2 in faults:
		var row: Dictionary = fault_rows.get(fl2.id, {})
		if row.has("bar"):
			(row.bar as BarGauge).value = float(fl2.work) if not fl2.task.get("mash", false) else float(fl2.mash)

func _make_fault_row(fl: Dictionary) -> void:
	var v: VBoxContainer = UIK.vbox(4)
	var state_txt: String = ["OK", "rattling", "faulted", "FAILED"][clampi(int(fl.state), 0, 3)]
	var ic: String = "warning"
	if fl.fire:
		state_txt = "ON FIRE"
		ic = "fire"
	elif fl.breach:
		state_txt = "hull breach"
	elif fl.nopower:
		state_txt = "no power"
		ic = "power"
	elif fl.warn:
		state_txt = "about to fail!"
	var h: HBoxContainer = UIK.hbox(6)
	h.add_child(UIK.icon_rect(ic, 20, K.pal("red")))
	var l: Label = UIK.wrapped(UIK.label("%s: %s" % [fl.label, state_txt], 15))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	v.add_child(h)
	var task: Dictionary = fl.task
	var can_quick: bool = not task.is_empty() and not fl.fire and not fl.breach and int(fl.state) < 3
	if can_quick:
		var bar: BarGauge = BarGauge.new("", 1.0, K.pal("green"))
		bar.custom_minimum_size = Vector2(0, 14)
		var b: Button
		var tgt: String = "mod:" + str(fl.id)
		if task.get("mash", false):
			b = UIK.btn("Kick it!", "orange", func(): send("fix", {"target": tgt, "click": true}), "dc")
		else:
			b = UIK.hold_btn("Hold to fix", "green", func(on: bool): send("fix", {"target": tgt, "on": on}), "dc")
		b.disabled = readonly
		v.add_child(b)
		v.add_child(bar)
		fault_rows[fl.id] = {"bar": bar}
	elif not task.is_empty():
		v.add_child(UIK.wrapped(UIK.label("Needs Damage Control (press F)", 14, K.pal("red").darkened(0.2))))
	fault_box.add_child(v)

func _update_enc(enc: Dictionary) -> void:
	var controls: Array = enc.get("controls", [])
	var info: String = str(enc.get("info", ""))
	if controls.is_empty() and info == "":
		enc_panel.visible = false
		enc_sig = ""
		return
	enc_panel.visible = true
	var sig: String = info + str(enc.get("title", ""))
	for c in controls:
		sig += str(c.id) + str(c.options)
	if sig != enc_sig:
		enc_sig = sig
		for c in enc_box.get_children():
			c.queue_free()
		enc_btns.clear()
		if enc.has("title"):
			var tl: Label = enc_panel.find_child("title", true, false)
			if tl != null:
				tl.text = str(enc.title)
		if info != "":
			enc_box.add_child(UIK.wrapped(UIK.label(info, 15)))
		for c in controls:
			enc_box.add_child(UIK.heading(str(c.label), 15))
			var g: GridContainer = UIK.grid(2, 4, 4)
			enc_box.add_child(g)
			enc_btns[c.id] = {}
			for opt in c.options:
				var cid: String = str(c.id)
				var ov: String = str(opt)
				var b: Button = UIK.toggle_btn(ov, "neutral", func(_on: bool): send("set", {"id": cid, "value": ov}))
				b.add_theme_font_size_override("font_size", 14)
				b.clip_text = true
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.custom_minimum_size = Vector2(120, 0)
				b.disabled = readonly
				g.add_child(b)
				enc_btns[c.id][opt] = b
	for c2 in controls:
		for opt2 in c2.options:
			var b2: Button = enc_btns.get(c2.id, {}).get(opt2)
			if b2 != null:
				b2.set_pressed_no_signal(str(c2.value) == str(opt2))

func _update_ritual(ph: Dictionary) -> void:
	if not ph.has("ritual"):
		ritual_panel.visible = false
		return
	ritual_panel.visible = true
	var rit: Dictionary = ph.ritual
	var ok: Dictionary = rit.get("ok", {})
	if ritual_steps == null:
		ritual_extra = _build_ritual_extra()
		if ritual_extra != null:
			ritual_box.add_child(ritual_extra)
		ritual_steps = UIK.wrapped(UIK.label("", 15))
		ritual_box.add_child(ritual_steps)
	var mark: Callable = func(b: bool) -> String: return "✔" if b else "·"
	ritual_steps.text = "%s Helm: coordinates\n%s Power: capacitor in the green\n%s Engines: hold the speed\n%s Ops: cargo secured\n· Captain: PUNCH IT" % [
		mark.call(ok.get("helm", false)), mark.call(ok.get("power", false)), mark.call(ok.get("engines", false)), mark.call(ok.get("ops", false))]
	_update_ritual_extra(rit, ph)

func _build_ritual_extra() -> Control:
	return null

func _update_ritual_extra(_rit: Dictionary, _ph: Dictionary) -> void:
	pass

func _update_wish(ph: Dictionary) -> void:
	if full.get("phase", "") != "pitstop" or not ph.has("items"):
		wish_panel.visible = false
		return
	wish_panel.visible = true
	var sig: String = ""
	for it in ph.items:
		sig += "%s:%s:%s|" % [it.id, it.requested, it.bought]
	if sig != wish_sig:
		wish_sig = sig
		for c in wish_box.get_children():
			c.queue_free()
		wish_box.add_child(UIK.wrapped(UIK.label("Convince the captain! Scrap: %d" % int(ph.get("scrap", 0)), 15)))
		for it in ph.items:
			var iid: String = str(it.id)
			var b: Button = UIK.btn("%s  (%d)" % [it.name, it.cost], "green" if it.requested else "yellow", func(): Net.send("pit_request", {"id": iid}), "scrap")
			b.add_theme_font_size_override("font_size", 14)
			b.clip_text = true
			b.tooltip_text = str(it.desc)
			b.disabled = readonly or it.bought
			wish_box.add_child(b)
			wish_box.add_child(UIK.wrapped(UIK.label(("Asked for!  " if it.requested else "") + str(it.desc), 13, K.pal("ink_soft"))))
