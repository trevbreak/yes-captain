class_name StationUI
extends Control
## Base for every station screen. Frame = header + station body + side column (faults, customs form,
## jump ritual, pit-stop wishlist). Subclasses implement build() and refresh().

var station: String = ""
var readonly: bool = false
var view: Dictionary = {}
var full: Dictionary = {}
var accent: Color = Color.WHITE
var body: Control
var side: VBoxContainer
var title_lbl: Label
var obj_lbl: Label
var share_btn: Button
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
var wish_panel: PanelContainer
var wish_box: VBoxContainer
var wish_sig: String = ""
var blocker: Control = null
var phase_now: String = ""
var emp_lbl: Label

func _init(st: String = "", ro: bool = false) -> void:
	station = st
	readonly = ro
	accent = K.pal(K.SEAT_INFO.get(st, {"color": "cream2"}).color)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
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

func _build_frame() -> void:
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_bottom", 4)
	add_child(m)
	var root: VBoxContainer = UIK.vbox(6)
	m.add_child(root)
	# header
	var head: HBoxContainer = UIK.hbox(10)
	root.add_child(head)
	var pill: PanelContainer = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UIK.box(accent, K.pal("ink"), 16, 4, 6))
	title_lbl = UIK.label(K.seat_name(station).to_upper() if station != "dc" else "DAMAGE CONTROL", 24)
	pill.add_child(title_lbl)
	head.add_child(pill)
	obj_lbl = UIK.label("", 18, K.pal("cream"))
	obj_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_lbl.clip_text = true
	head.add_child(obj_lbl)
	emp_lbl = UIK.label("", 18, K.pal("ink"))
	emp_lbl.add_theme_stylebox_override("normal", UIK.box(K.pal("coral"), K.pal("ink"), 12, 3, 6))
	emp_lbl.visible = false
	head.add_child(emp_lbl)
	if not readonly and station != "dc":
		share_btn = UIK.toggle_btn("Share to Captain", "mint", func(on: bool): Net.send("share", {"on": on}))
		head.add_child(share_btn)
	# body + side
	var row: HBoxContainer = UIK.hbox(10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	var bp: PanelContainer = UIK.panel("cream", 10, 22)
	bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(bp)
	body = Control.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	bp.add_child(body)
	side = UIK.vbox(8)
	side.custom_minimum_size = Vector2(290, 0)
	row.add_child(side)
	# ritual (staging)
	ritual_box = UIK.vbox(4)
	ritual_box.custom_minimum_size = Vector2(262, 0)
	ritual_panel = UIK.titled("JUMP RITUAL", "butter", ritual_box)
	ritual_panel.visible = false
	side.add_child(ritual_panel)
	# customs / encounter controls
	enc_box = UIK.vbox(4)
	enc_box.custom_minimum_size = Vector2(262, 0)
	enc_panel = UIK.titled("FORM", "teal", enc_box)
	enc_panel.visible = false
	side.add_child(enc_panel)
	# wishlist (pit stop)
	wish_box = UIK.vbox(4)
	wish_box.custom_minimum_size = Vector2(262, 0)
	wish_panel = UIK.titled("WISHLIST", "butter", wish_box)
	wish_panel.visible = false
	side.add_child(wish_panel)
	# faults
	fault_box = UIK.vbox(4)
	fault_box.custom_minimum_size = Vector2(262, 0)
	fault_panel = UIK.titled("PROBLEMS", "coral", fault_box)
	side.add_child(fault_panel)

# ---------------------------------------------------------------- per-snapshot update

func apply(v: Dictionary, f: Dictionary) -> void:
	view = v
	full = f
	if obj_lbl != null:
		obj_lbl.text = str(f.get("common", {}).get("obj", ""))
	phase_now = str(f.get("phase", ""))
	if emp_lbl != null:
		var et: float = float(v.get("emp_t", 0.0))
		emp_lbl.visible = et > 0.0
		emp_lbl.text = "EMP! CONTROLS INVERTED  %ds" % int(et)
	if share_btn != null:
		var want: bool = bool(f.get("sharing", false))
		if share_btn.button_pressed != want:
			share_btn.set_pressed_no_signal(want)
		share_btn.text = "Captain is looking!" if f.get("shared_now", false) else ("Share to Captain" if not want else "Waiting for captain...")
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
			var q: Label = UIK.label("All quiet. IGOR is suspicious.", 15, Color(K.pal("ink"), 0.7))
			q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fault_box.add_child(q)
		for fl in faults:
			_make_fault_row(fl)
	for fl2 in faults:
		var row: Dictionary = fault_rows.get(fl2.id, {})
		if row.has("bar"):
			row.bar.value = float(fl2.work) * 100.0 if not fl2.task.get("mash", false) else float(fl2.mash) * 100.0

func _make_fault_row(fl: Dictionary) -> void:
	var v: VBoxContainer = UIK.vbox(2)
	var state_txt: String = ["OK", "rattling", "FAULTED", "FAILED"][clampi(int(fl.state), 0, 3)]
	if fl.fire:
		state_txt = "ON FIRE"
	elif fl.breach:
		state_txt = "BREACH"
	elif fl.nopower:
		state_txt = "NO POWER"
	elif fl.warn:
		state_txt = "about to fail!"
	var l: Label = UIK.label("%s: %s" % [fl.label, state_txt], 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var task: Dictionary = fl.task
	var can_quick: bool = not task.is_empty() and not fl.fire and not fl.breach and int(fl.state) < 3
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UIK.box(K.pal("white"), K.pal("ink"), 6, 2, 0))
	bar.add_theme_stylebox_override("fill", UIK.box(K.pal("green"), K.pal("ink"), 6, 2, 0))
	if can_quick:
		var h: HBoxContainer = UIK.hbox(4)
		var b: Button
		if task.get("mash", false):
			b = UIK.btn("KICK IT!", "mustard")
			var tgt: String = "mod:" + str(fl.id)
			b.pressed.connect(func(): send("fix", {"target": tgt, "click": true}))
		else:
			b = UIK.btn("HOLD TO FIX", "mint")
			var tgt2: String = "mod:" + str(fl.id)
			b.button_down.connect(func(): send("fix", {"target": tgt2, "on": true}))
			b.button_up.connect(func(): send("fix", {"target": tgt2, "on": false}))
		b.disabled = readonly
		h.add_child(b)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		v.add_child(h)
		fault_rows[fl.id] = {"bar": bar}
	elif not task.is_empty():
		v.add_child(UIK.label("Needs Damage Control! (press F or the DC tab)", 14, K.pal("coral")))
	var sep: HSeparator = HSeparator.new()
	v.add_child(sep)
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
			enc_box.add_child(UIK.label(str(enc.title), 15, K.pal("plum2")))
		if info != "":
			var l: Label = UIK.label(info, 15)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			enc_box.add_child(l)
		for c in controls:
			enc_box.add_child(UIK.label(str(c.label), 15))
			var g: GridContainer = UIK.grid(2, 4, 4)
			enc_box.add_child(g)
			enc_btns[c.id] = {}
			for opt in c.options:
				var b: Button = UIK.btn(str(opt), "cream2")
				b.toggle_mode = true
				b.disabled = readonly
				var cid: String = str(c.id)
				var ov: String = str(opt)
				b.pressed.connect(func(): send("set", {"id": cid, "value": ov}))
				g.add_child(b)
				enc_btns[c.id][opt] = b
	for c in controls:
		for opt in c.options:
			var b2: Button = enc_btns.get(c.id, {}).get(opt)
			if b2 != null:
				b2.set_pressed_no_signal(str(c.value) == str(opt))

func _update_ritual(ph: Dictionary) -> void:
	if not ph.has("ritual"):
		ritual_panel.visible = false
		return
	ritual_panel.visible = true
	var rit: Dictionary = ph.ritual
	var ok: Dictionary = rit.get("ok", {})
	if ritual_extra == null:
		ritual_extra = _build_ritual_extra()
		if ritual_extra != null:
			ritual_box.add_child(ritual_extra)
		var steps: Label = UIK.label("", 15)
		steps.name = "steps"
		steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ritual_box.add_child(steps)
	var steps_l: Label = ritual_box.get_node_or_null("steps")
	if steps_l != null:
		steps_l.text = "Helm: coordinates %s\nPower: capacitor %s\nEngines: speed %s\nOps: cargo %s\nCaptain: PUNCH IT" % [
			"✔" if ok.get("helm", false) else "...", "✔" if ok.get("power", false) else "...",
			"✔" if ok.get("engines", false) else "...", "✔" if ok.get("ops", false) else "..."]
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
	var sig: String = str(full.get("phase", ""))
	for it in ph.items:
		sig += "%s:%s:%s|" % [it.id, it.requested, it.bought]
	if sig != wish_sig:
		wish_sig = sig
		for c in wish_box.get_children():
			c.queue_free()
		wish_box.add_child(UIK.label("Convince the captain! Scrap: %d" % int(ph.get("scrap", 0)), 15))
		for it in ph.items:
			var b: Button = UIK.btn("%s (%d)" % [it.name, it.cost], "butter" if not it.requested else "mint")
			b.tooltip_text = str(it.desc)
			b.disabled = readonly or it.bought
			var iid: String = str(it.id)
			b.pressed.connect(func(): Net.send("pit_request", {"id": iid}))
			wish_box.add_child(b)
			var dl: Label = UIK.label(str(it.desc), 13, Color(K.pal("ink"), 0.7))
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wish_box.add_child(dl)

func _unhandled_key_input(_e: InputEvent) -> void:
	pass
