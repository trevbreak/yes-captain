class_name OpsUI
extends StationUI

var diagram: ShieldDiagram
var w_btns: Array = []
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
var bot_btn: Button
var bot_lbl: Label
var secure_btn: Button
var damaged_sig: String = ""
var damaged_ids: Array = []

func build() -> void:
	var h: HBoxContainer = UIK.hbox(12)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	# shields
	var col1: VBoxContainer = UIK.vbox(4)
	h.add_child(col1)
	col1.add_child(UIK.label("SHIELD FACINGS", 16))
	diagram = ShieldDiagram.new()
	diagram.accent = accent
	col1.add_child(diagram)
	var names: Array = ["FRONT", "STBD", "AFT", "PORT"]
	var g: GridContainer = UIK.grid(4, 4, 4)
	col1.add_child(g)
	for i in 4:
		var idx: int = i
		var v: VBoxContainer = UIK.vbox(2)
		v.add_child(UIK.label(names[i], 13))
		var plus: Button = UIK.btn("+", "lilac", func(): send("shield_w", {"i": idx, "d": 1}))
		plus.disabled = readonly
		var minus: Button = UIK.btn("-", "cream2", func(): send("shield_w", {"i": idx, "d": -1}))
		minus.disabled = readonly
		v.add_child(plus)
		v.add_child(minus)
		g.add_child(v)
	# pudding
	var col2: VBoxContainer = UIK.vbox(4)
	h.add_child(col2)
	col2.add_child(UIK.label("PUDDING", 16))
	pud_face = PuddingFace.new()
	col2.add_child(pud_face)
	mood_bar = BarGauge.new("MOOD", 100.0, K.pal("pink"))
	mood_bar.danger_above = 80.0
	col2.add_child(mood_bar)
	var pr: HBoxContainer = UIK.hbox(4)
	col2.add_child(pr)
	pat_btn = UIK.btn("PAT", "pink", func(): send("pat", true))
	pat_btn.disabled = readonly
	pr.add_child(pat_btn)
	snack_btn = UIK.btn("SNACK", "butter", func(): send("snack", true))
	snack_btn.disabled = readonly
	pr.add_child(snack_btn)
	music_btn = UIK.toggle_btn("MUSIC", "teal", func(on: bool): send("music", on))
	music_btn.disabled = readonly
	col2.add_child(music_btn)
	pud_lbl = UIK.label("", 14)
	pud_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pud_lbl.custom_minimum_size = Vector2(170, 0)
	col2.add_child(pud_lbl)
	# tractor + cargo + bots
	var col3: VBoxContainer = UIK.vbox(5)
	col3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col3)
	col3.add_child(UIK.label("TRACTOR BEAM", 16))
	trac_lbl = UIK.label("", 14)
	col3.add_child(trac_lbl)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 120)
	col3.add_child(sc)
	trac_box = UIK.vbox(3)
	trac_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(trac_box)
	col3.add_child(UIK.label("CARGO", 16))
	cargo_box = UIK.vbox(3)
	col3.add_child(cargo_box)
	secure_btn = UIK.toggle_btn("SECURE CARGO (for jumps)", "butter", func(on: bool): send("secure", on))
	secure_btn.disabled = readonly
	col3.add_child(secure_btn)
	col3.add_child(UIK.label("REPAIR BOT (slow but patient)", 16))
	bot_opt = OptionButton.new()
	col3.add_child(bot_opt)
	var br: HBoxContainer = UIK.hbox(4)
	col3.add_child(br)
	bot_btn = UIK.btn("DISPATCH", "lilac", _dispatch)
	bot_btn.disabled = readonly
	br.add_child(bot_btn)
	br.add_child(UIK.btn("RECALL", "cream2", func(): send("bot", "")))
	bot_lbl = UIK.label("", 14)
	col3.add_child(bot_lbl)

func _dispatch() -> void:
	var i: int = bot_opt.selected
	if i >= 0 and i < damaged_ids.size():
		send("bot", damaged_ids[i])

func _update_ritual_extra(_rit: Dictionary, _ph: Dictionary) -> void:
	pass

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
	snack_btn.text = "SNACK (%d)" % int(view.get("snacks", 0))
	music_btn.set_pressed_no_signal(bool(pud.get("music", false)))
	if not pud.get("aboard", false):
		pud_lbl.text = "Pudding isn't aboard yet. Suspicious skip on the way."
	elif bool(pud.get("loose", false)):
		pud_lbl.text = "PUDDING IS LOOSE in %s! Use a SNACK to lure it back to the pen. It eats wiring." % str(pud.get("at", "?"))
	elif float(pud.get("mood", 0.0)) > 70.0:
		pud_lbl.text = "Pudding is about to bolt! Pat, snack, music!"
	else:
		pud_lbl.text = "Calm Pudding = a calm ship."
	# tractor
	var tr: int = int(view.get("tractor", -1))
	trac_lbl.text = "Range %dm.  %s" % [int(view.get("tractor_range", 80.0)), "Beaming #%d" % tr if tr >= 0 else "Off"]
	var sig: String = ""
	for t in view.get("tractables", []):
		sig += "%d|" % int(t.id)
	if sig != trac_sig:
		trac_sig = sig
		for c in trac_box.get_children():
			c.queue_free()
		for t2 in view.get("tractables", []):
			var tid: int = int(t2.id)
			var b: Button = UIK.btn("Beam: %s" % t2.name, "lilac", func(): send("tractor", tid))
			b.disabled = readonly
			trac_box.add_child(b)
		if not view.get("tractables", []).is_empty():
			var off: Button = UIK.btn("Tractor OFF", "cream2", func(): send("tractor", -1))
			off.disabled = readonly
			trac_box.add_child(off)
	for i in range(mini(trac_box.get_child_count(), view.get("tractables", []).size())):
		var tt: Dictionary = view.tractables[i]
		(trac_box.get_child(i) as Button).text = "Beam: %s  %dm  (rel %.0f m/s)" % [tt.name, int(tt.d), float(tt.rel)]
	# cargo
	var csig: String = ""
	for c in view.get("cargo", []):
		csig += str(c.name)
	if csig != cargo_sig:
		cargo_sig = csig
		for ch in cargo_box.get_children():
			ch.queue_free()
		if view.get("cargo", []).is_empty():
			cargo_box.add_child(UIK.label("Empty. Just the smell.", 14))
		var idx: int = 0
		for c2 in view.get("cargo", []):
			var row: HBoxContainer = UIK.hbox(4)
			var bar: BarGauge = BarGauge.new(str(c2.name), 100.0, K.pal("butter"))
			bar.name = "cb%d" % idx
			bar.custom_minimum_size = Vector2(160, 24)
			row.add_child(bar)
			var jid: int = idx
			var jb: SafetyBtn = SafetyBtn.new("JETTISON", "coral")
			jb.custom_minimum_size = Vector2(110, 36)
			jb.fired.connect(func(): send("jettison", jid))
			row.add_child(jb)
			cargo_box.add_child(row)
			idx += 1
	var ci: int = 0
	for c3 in view.get("cargo", []):
		var rb: Node = cargo_box.get_child(ci) if ci < cargo_box.get_child_count() else null
		if rb != null and rb.get_child_count() > 0 and rb.get_child(0) is BarGauge:
			(rb.get_child(0) as BarGauge).value = float(c3.integrity)
		ci += 1
	secure_btn.set_pressed_no_signal(bool(view.get("secured", false)))
	# repair bot
	var dsig: String = ""
	for d in view.get("damaged", []):
		dsig += str(d.id)
	if dsig != damaged_sig:
		damaged_sig = dsig
		bot_opt.clear()
		damaged_ids.clear()
		for d2 in view.get("damaged", []):
			bot_opt.add_item("%s (%d%%)" % [d2.label, int(d2.hp)])
			damaged_ids.append(d2.id)
	var job: String = str(view.get("bot_job", ""))
	bot_lbl.text = "Bot working on %s: %d%%" % [job, int(float(view.get("bot_progress", 0.0)) * 100.0)] if job != "" else "Bot idle."
