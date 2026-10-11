class_name OpsUI
extends StationUI

var diagram: ShieldDiagram
var pud_face: PuddingFace
var mood_bar: BarGauge
var pat_btn: Button
var snack_btn: Button
var music_btn: Button
var pud_lbl: Label
var trac_box: VBoxContainer
var trac_sig: String = ""
var trac_lbl: Label
var cargo_box: VBoxContainer
var cargo_sig: String = ""
var bot_opt: OptionButton
var bot_lbl: Label
var secure_btn: Button
var damaged_sig: String = ""
var damaged_ids: Array = []

func build() -> void:
	var h: HBoxContainer = UIK.hbox(10)
	add_body(h)
	var sw: Array = UIK.window("SHIELDS", "ops", "ops", 8)
	h.add_child(sw[0])
	diagram = ShieldDiagram.new()
	diagram.accent = accent
	diagram.custom_minimum_size = Vector2(220, 220)
	(sw[1] as VBoxContainer).add_child(diagram)
	var g: GridContainer = UIK.grid(4, 4, 4)
	(sw[1] as VBoxContainer).add_child(g)
	for nm in ["Front", "Stbd", "Aft", "Port"]:
		g.add_child(UIK.label(nm, 13, K.pal("ink_soft"), 1))
	for i in 4:
		var idx: int = i
		var plus: Button = UIK.btn("+", "ops", func(): send("shield_w", {"i": idx, "d": 1}))
		plus.disabled = readonly
		g.add_child(plus)
	for i2 in 4:
		var idx2: int = i2
		var minus: Button = UIK.btn("–", "neutral", func(): send("shield_w", {"i": idx2, "d": -1}))
		minus.disabled = readonly
		g.add_child(minus)
	(sw[1] as VBoxContainer).add_child(UIK.wrapped(UIK.label("+ moves shield strength to that side.", 13, K.pal("ink_soft")), 220))
	var pw: Array = UIK.window("PUDDING", "pink", "pudding", 8)
	(pw[0] as Control).custom_minimum_size = Vector2(220, 0)
	h.add_child(pw[0])
	pud_face = PuddingFace.new()
	pud_face.custom_minimum_size = Vector2(150, 140)
	pud_face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(pw[1] as VBoxContainer).add_child(pud_face)
	mood_bar = BarGauge.new("mood", 100.0, K.pal("pink"))
	mood_bar.danger_above = 80.0
	(pw[1] as VBoxContainer).add_child(mood_bar)
	var pr: HBoxContainer = UIK.hbox(6)
	(pw[1] as VBoxContainer).add_child(pr)
	pat_btn = UIK.btn("Pat", "pink", func(): send("pat", true))
	pat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pat_btn.disabled = readonly
	pr.add_child(pat_btn)
	snack_btn = UIK.btn("Snack", "yellow", func(): send("snack", true))
	snack_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snack_btn.disabled = readonly
	pr.add_child(snack_btn)
	music_btn = UIK.toggle_btn("Play music", "blue", func(on: bool): send("music", on), "star")
	music_btn.disabled = readonly
	(pw[1] as VBoxContainer).add_child(music_btn)
	pud_lbl = UIK.wrapped(UIK.label("", 14))
	(pw[1] as VBoxContainer).add_child(pud_lbl)
	var right: VBoxContainer = UIK.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var tw: Array = UIK.window("TRACTOR BEAM", "purple", "map", 8)
	(tw[0] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(tw[0])
	trac_lbl = UIK.label("", 14, K.pal("ink_soft"))
	(tw[1] as VBoxContainer).add_child(trac_lbl)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(tw[1] as VBoxContainer).add_child(sc)
	trac_box = UIK.vbox(4)
	trac_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(trac_box)
	var cw: Array = UIK.window("CARGO & REPAIR BOT", "orange", "dc", 8)
	right.add_child(cw[0])
	cargo_box = UIK.vbox(4)
	(cw[1] as VBoxContainer).add_child(cargo_box)
	secure_btn = UIK.toggle_btn("Secure cargo (for jumps)", "yellow", func(on: bool): send("secure", on), "lock")
	secure_btn.disabled = readonly
	(cw[1] as VBoxContainer).add_child(secure_btn)
	var br: HBoxContainer = UIK.hbox(6)
	(cw[1] as VBoxContainer).add_child(br)
	bot_opt = OptionButton.new()
	bot_opt.fit_to_longest_item = false
	bot_opt.clip_text = true
	bot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(bot_opt)
	var db: Button = UIK.btn("Send bot", "orange", _dispatch, "robot")
	db.disabled = readonly
	br.add_child(db)
	bot_lbl = UIK.label("", 13, K.pal("ink_soft"))
	(cw[1] as VBoxContainer).add_child(bot_lbl)

func _dispatch() -> void:
	var i: int = bot_opt.selected
	if i >= 0 and i < damaged_ids.size():
		send("bot", damaged_ids[i])

func refresh() -> void:
	diagram.shields = view.get("shield", [0, 0, 0, 0])
	diagram.weights = view.get("shield_w", [1, 1, 1, 1])
	diagram.threat = int(view.get("threat", -1)) if bool(view.get("has_threat", false)) else -1
	var pud: Dictionary = view.get("pud", {})
	pud_face.mood = float(pud.get("mood", 0.0))
	pud_face.loose = bool(pud.get("loose", false))
	mood_bar.value = pud_face.mood
	pat_btn.disabled = float(pud.get("pat_cd", 0.0)) > 0.0 or bool(pud.get("loose", false)) or readonly or not pud.get("aboard", false)
	snack_btn.disabled = int(view.get("snacks", 0)) <= 0 or float(pud.get("snack_cd", 0.0)) > 0.0 or readonly or not pud.get("aboard", false)
	snack_btn.text = "Snack ×%d" % int(view.get("snacks", 0))
	music_btn.set_pressed_no_signal(bool(pud.get("music", false)))
	if not pud.get("aboard", false):
		pud_lbl.text = "Pudding isn't aboard yet. One of these skips is suspiciously warm."
	elif bool(pud.get("loose", false)):
		pud_lbl.text = "LOOSE in %s and eating wiring! Snack to lure it back." % str(pud.get("at", "?"))
	elif float(pud.get("mood", 0.0)) > 70.0:
		pud_lbl.text = "About to bolt! Pat, snack, music!"
	else:
		pud_lbl.text = "A calm Pudding is a calm ship."
	var tr: int = int(view.get("tractor", -1))
	trac_lbl.text = "Reach %dm. %s" % [int(view.get("tractor_range", 80.0)), "Beam ON." if tr >= 0 else "Beam off."]
	var sig: String = ""
	for t in view.get("tractables", []):
		sig += "%d|" % int(t.id)
	if sig != trac_sig:
		trac_sig = sig
		for c in trac_box.get_children():
			c.queue_free()
		if view.get("tractables", []).is_empty():
			trac_box.add_child(UIK.label("Nothing nearby to grab.", 14, K.pal("ink_soft")))
		for t2 in view.get("tractables", []):
			var tid: int = int(t2.id)
			var b: Button = UIK.btn("Beam: %s" % t2.name, "purple", func(): send("tractor", tid), "map")
			b.add_theme_font_size_override("font_size", 14)
			b.clip_text = true
			b.disabled = readonly
			trac_box.add_child(b)
		if not view.get("tractables", []).is_empty():
			var off: Button = UIK.btn("Tractor off", "neutral", func(): send("tractor", -1))
			off.add_theme_font_size_override("font_size", 14)
			off.disabled = readonly
			trac_box.add_child(off)
	var tl: Array = view.get("tractables", [])
	for i in range(mini(trac_box.get_child_count(), tl.size())):
		var btn: Node = trac_box.get_child(i)
		if btn is Button:
			(btn as Button).text = "Beam: %s  %dm  (%.0f m/s)" % [tl[i].name, int(tl[i].d), float(tl[i].rel)]
	var csig: String = ""
	for c2 in view.get("cargo", []):
		csig += str(c2.name)
	if csig != cargo_sig:
		cargo_sig = csig
		for ch in cargo_box.get_children():
			ch.queue_free()
		if view.get("cargo", []).is_empty():
			cargo_box.add_child(UIK.label("Hold is empty. Just the smell.", 14, K.pal("ink_soft")))
		var idx: int = 0
		for c3 in view.get("cargo", []):
			var row: HBoxContainer = UIK.hbox(6)
			var bar: BarGauge = BarGauge.new(str(c3.name), 100.0, K.pal("yellow"))
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.custom_minimum_size = Vector2(120, 24)
			row.add_child(bar)
			var jid: int = idx
			var jb: SafetyBtn = SafetyBtn.new("JETTISON", "red")
			jb.custom_minimum_size = Vector2(130, 40)
			jb.fired.connect(func(): send("jettison", jid))
			row.add_child(jb)
			cargo_box.add_child(row)
			idx += 1
	var ci: int = 0
	for c4 in view.get("cargo", []):
		var rb: Node = cargo_box.get_child(ci) if ci < cargo_box.get_child_count() else null
		if rb != null and rb.get_child_count() > 0 and rb.get_child(0) is BarGauge:
			(rb.get_child(0) as BarGauge).value = float(c4.integrity)
		ci += 1
	secure_btn.set_pressed_no_signal(bool(view.get("secured", false)))
	var dsig: String = ""
	for d in view.get("damaged", []):
		dsig += str(d.id)
	if dsig != damaged_sig:
		damaged_sig = dsig
		bot_opt.clear()
		damaged_ids.clear()
		if view.get("damaged", []).is_empty():
			bot_opt.add_item("Nothing needs fixing")
		for d2 in view.get("damaged", []):
			bot_opt.add_item("%s (%d%%)" % [d2.label, int(d2.hp)])
			damaged_ids.append(d2.id)
	var job: String = str(view.get("bot_job", ""))
	bot_lbl.text = "Repair bot fixing %s: %d%%" % [job, int(float(view.get("bot_progress", 0.0)) * 100.0)] if job != "" else "Repair bot is idle. It is slow, but it never complains."
