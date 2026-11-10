class_name Screens
extends RefCounted
## Full-screen moments: the debrief after every mission or job, and the Shift's job board.

static func _frame(title: String, col: String, icon: String, w: float = 860.0) -> Array:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.set_meta("overlay", true)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var win: Array = UIK.window(title, col, icon)
	win[0].custom_minimum_size = Vector2(w, 0)
	cc.add_child(win[0])
	# every big card arrives with a little bounce
	win[0].scale = Vector2(0.86, 0.86)
	win[0].modulate.a = 0.0
	var tw: Tween = win[0].create_tween().set_parallel(true)
	tw.tween_property(win[0], "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(win[0], "modulate:a", 1.0, 0.18)
	win[0].resized.connect(func(): win[0].pivot_offset = win[0].size / 2.0)
	return [root, win[1]]

static func money(n: int) -> String:
	return ("-£%d" % -n) if n < 0 else "£%d" % n

static func _stars(got: int, px: int = 56) -> HBoxContainer:
	var stars: HBoxContainer = UIK.hbox(4)
	for i in 3:
		stars.add_child(UIK.icon("star", px, UIK.c("mustard") if i < got else Color(UIK.ink(), 0.18)))
	return stars

static func _fact(ok: bool, text: String) -> HBoxContainer:
	var h: HBoxContainer = UIK.hbox(6)
	h.add_child(UIK.icon("star", 20, UIK.c("mustard") if ok else Color(UIK.ink(), 0.2)))
	h.add_child(UIK.label(text, 20))
	return h

static func _awards(b: VBoxContainer, aw: Array, cols: int = 2, w: float = 390.0) -> void:
	if aw.is_empty():
		return
	b.add_child(UIK.head("CREW AWARDS", 20))
	var g: GridContainer = UIK.grid(cols, 8)
	b.add_child(g)
	for a in aw:
		var h: HBoxContainer = UIK.hbox(8)
		h.custom_minimum_size = Vector2(w, 0)
		h.add_child(UIK.portrait(str(a.seat), 46))
		var v: VBoxContainer = UIK.vbox(-4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIK.head(str(a.title), 18, UIK.c("red")))
		var l: Label = UIK.label("%s: %s" % [str(a.get("who", K.seat_name(str(a.seat)))), str(a.text)], 17)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
		h.add_child(v)
		g.add_child(h)

static func rent_bar(earned: int, rent: int, w: float = 300.0) -> Gauges.Bar:
	var bar: Gauges.Bar = Gauges.Bar.new("green" if earned >= rent else "mustard", 28)
	bar.custom_minimum_size = Vector2(w, 28)
	bar.set_value(clampf(float(earned) / maxf(1.0, float(rent)), 0.0, 1.0), "%s OF %s RENT" % [money(earned), money(rent)])
	return bar

static func debrief(d: Dictionary, on_next: Callable, on_retry: Callable, on_lobby: Callable, on_shuffle: Callable = Callable()) -> Control:
	if bool(d.get("job", false)):
		return _job_debrief(d, on_next, on_lobby, on_shuffle)
	var ok: bool = bool(d.get("ok", false))
	var final_: bool = bool(d.get("final", false))
	var title: String = ("MISSION %d COMPLETE!" % int(d.get("num", 0))) if ok else "MISSION FAILED"
	if final_:
		title = "YOU MADE IT TO HAVEN!"
	var fr: Array = _frame(title, "green" if ok else "red", "check" if ok else "x")
	var b: VBoxContainer = fr[1]
	b.add_theme_constant_override("separation", 10)
	var top: HBoxContainer = UIK.hbox(20)
	b.add_child(top)
	var sv: VBoxContainer = UIK.vbox(2)
	top.add_child(sv)
	sv.add_child(UIK.head(str(d.get("title", "")), 30))
	sv.add_child(_stars(int(d.get("stars", 0))))
	var facts: VBoxContainer = UIK.vbox(2)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(facts)
	if ok:
		facts.add_child(_fact(true, "Mission complete"))
		facts.add_child(_fact(float(d.get("hull", 0)) >= 60.0, "Hull above 60%%  (%d%%)" % int(float(d.get("hull", 0)))))
		facts.add_child(_fact(float(d.get("time", 0)) <= float(d.get("par", 0)), "Under par  (%s, par %s)" % [K.fmt_time(float(d.get("time", 0))), K.fmt_time(float(d.get("par", 0)))]))
	else:
		facts.add_child(UIK.para(str(d.get("reason", "Something went very wrong.")), 24, UIK.c("red")))
		facts.add_child(UIK.label("Time: %s" % K.fmt_time(float(d.get("time", 0))), 21))
	var said: String = str(d.get("said", ""))
	if final_:
		said = "Haven. Pudding is safe. The Overlord will calm down eventually. IGOR is proud of you, meat. IGOR will deny this."
	elif not ok:
		said += " IGOR suggests: talk more. Shout, even. Then try again."
	b.add_child(UIK.speech(said, "igor", "IGOR", 76, 21))
	if bool(d.get("shift_opened", false)):
		b.add_child(UIK.chip("NEW: THE SHIFT IS OPEN IN THE CREW ROOM. THREE JOBS. NEVER THE SAME TWICE.", "purple", "star", 17))
	elif bool(d.get("opened", false)) and str(d.get("next", "")) != "":
		var nid: String = str(d.next)
		b.add_child(UIK.chip("NEW MISSION UNLOCKED: %s  (NEW: %s)" % [str(Missions.INFO[nid].title), Missions.INFO[nid].new], "mustard", "star", 18))
	_awards(b, d.get("awards", []))
	var br: HBoxContainer = UIK.hbox(10)
	br.alignment = BoxContainer.ALIGNMENT_END
	b.add_child(br)
	if bool(d.get("can_continue", false)):
		if on_shuffle.is_valid():
			var sb: Button = UIK.btn("Shuffle seats", "lilac", on_shuffle, "crew", 18)
			sb.tooltip_text = "Everybody moves one seat round, so someone else gets to be Captain"
			br.add_child(sb)
		br.add_child(UIK.btn("Crew Room", "cream", on_lobby, "crew"))
		br.add_child(UIK.btn("Try again", "orange" if ok else "green", on_retry, "back"))
		if str(d.get("next", "")) != "":
			br.add_child(UIK.btn("Next mission", "green", on_next, "play", 24))
	else:
		br.add_child(UIK.label("Waiting for the captain to decide what's next...", 21, K.pal("ink_soft")))
	return fr[0]

static func _job_debrief(d: Dictionary, on_next: Callable, on_lobby: Callable, on_shuffle: Callable) -> Control:
	var ok: bool = bool(d.get("ok", false))
	var last: bool = bool(d.get("shift_done", false))
	var made: bool = bool(d.get("made_rent", false))
	var title: String = "JOB %d OF %d: %s" % [int(d.get("n", 1)), int(d.get("of", 3)), "DONE!" if ok else "A WRITE-OFF"]
	if last:
		title = "END OF SHIFT: RENT PAID!" if made else "END OF SHIFT: RENT IS SHORT"
	var fr: Array = _frame(title, "green" if (made if last else ok) else "red", "check" if (made if last else ok) else "x", 980.0 if last else 860.0)
	var b: VBoxContainer = fr[1]
	b.add_theme_constant_override("separation", 8)
	var cols: HBoxContainer = UIK.hbox(18)
	b.add_child(cols)
	# ---- the pay slip
	var slip: PanelContainer = UIK.panel("well", [4, 0, 4, 0])
	slip.custom_minimum_size = Vector2(430, 0)
	cols.add_child(slip)
	var sv: VBoxContainer = UIK.vbox(2)
	slip.add_child(sv)
	var hd: HBoxContainer = UIK.hbox(8)
	sv.add_child(hd)
	hd.add_child(UIK.head("PAY SLIP", 20, K.pal("ink_soft")))
	hd.add_child(UIK.spacer(true))
	hd.add_child(_stars(int(d.get("stars", 0)), 24))
	if not ok:
		sv.add_child(UIK.para(str(d.get("reason", "The ship fell apart.")), 20, UIK.c("red")))
	for ln in d.get("lines", []):
		var row: HBoxContainer = UIK.hbox(8)
		var l: Label = UIK.label(str(ln.text), 19)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		var amt: int = int(ln.amount)
		row.add_child(UIK.head(("+" if amt > 0 else "") + money(amt) if amt != 0 else "-", 19, UIK.c("green").darkened(0.2) if amt > 0 else (UIK.c("red") if amt < 0 else K.pal("ink_soft"))))
		sv.add_child(row)
	var tot: HBoxContainer = UIK.hbox(8)
	sv.add_child(tot)
	var tl: Label = UIK.head("THIS JOB", 24)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tot.add_child(tl)
	tot.add_child(UIK.head(money(int(d.get("pay", 0))), 30, UIK.c("green").darkened(0.2) if int(d.get("pay", 0)) >= 0 else UIK.c("red")))
	if last:
		sv.add_child(UIK.spacer(false, Vector2(0, 6)))
		sv.add_child(UIK.head("THE WHOLE SHIFT", 18, K.pal("ink_soft")))
		for hrow in d.get("history", []):
			var hr: HBoxContainer = UIK.hbox(8)
			var hl: Label = UIK.label(str(hrow.title) + ("" if bool(hrow.ok) else "  (write-off)"), 19)
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hr.add_child(hl)
			hr.add_child(UIK.head(money(int(hrow.pay)), 19, UIK.c("green").darkened(0.2) if int(hrow.pay) >= 0 else UIK.c("red")))
			sv.add_child(hr)
	sv.add_child(UIK.spacer(true))
	sv.add_child(rent_bar(int(d.get("earned", 0)), int(d.get("rent", 1)), 400.0))
	# ---- the right-hand side
	var right: VBoxContainer = UIK.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UIK.speech(str(d.get("said", "")), "igor", "IGOR", 70, 20))
	if last:
		var rv: Array = d.get("review", [])
		if not rv.is_empty():
			right.add_child(UIK.head("IGOR'S STAFF REVIEW", 19, K.pal("ink_soft")))
			for r in rv:
				var h: HBoxContainer = UIK.hbox(6)
				h.add_child(UIK.portrait(str(r.seat), 34))
				var t: Label = UIK.para("%s: %s" % [str(r.who), str(r.text)], 18)
				t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(t)
				right.add_child(h)
		var card: Dictionary = d.get("card", {})
		if not card.is_empty():
			var cp: PanelContainer = UIK.panel("panel_small", [2, -2, 2, -2])
			var cv: VBoxContainer = UIK.vbox(0)
			cp.add_child(cv)
			cv.add_child(UIK.head("NEW CARD IN YOUR DECK", 16, UIK.c("purple").darkened(0.15)))
			cv.add_child(UIK.head(str(card.get("title", "")), 22, UIK.c("red")))
			cv.add_child(UIK.para("IGOR will explain it at the next briefing. IGOR is looking forward to it.", 17, K.pal("ink_soft")))
			right.add_child(cp)
	else:
		_awards(right, (d.get("awards", []) as Array).slice(0, 3), 1, 360.0)
	var br: HBoxContainer = UIK.hbox(10)
	br.alignment = BoxContainer.ALIGNMENT_END
	b.add_child(br)
	if bool(d.get("can_continue", false)):
		if on_shuffle.is_valid():
			var sb: Button = UIK.btn("Shuffle seats", "lilac", on_shuffle, "crew", 18)
			sb.tooltip_text = "Everybody moves one seat round, so someone else gets to be Captain"
			br.add_child(sb)
		if last:
			br.add_child(UIK.btn("Back to the crew room", "green", on_next, "play", 24))
		else:
			br.add_child(UIK.btn("Abandon shift", "cream", on_lobby, "back", 18))
			br.add_child(UIK.btn("To the job board", "green", on_next, "play", 24))
	else:
		br.add_child(UIK.label("Waiting for the captain...", 21, K.pal("ink_soft")))
	return fr[0]

# ================================================================ the job board

class JobBoard extends Control:
	## Three jobs pinned to a board. The crew votes by clicking; the captain (or the host) takes one.
	var title_chip: PanelContainer
	var rent: HBoxContainer
	var cards: HBoxContainer
	var parts_box: HBoxContainer
	var parts_row: HBoxContainer
	var igor_lbl: Label
	var hint: Label
	var _sig: String = ""
	var _votes_sig: String = ""
	var _vote_rows: Array = []
	var _take_btns: Array = []
	var _part_btns: Dictionary = {}

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		set_meta("overlay", true)
		mouse_filter = Control.MOUSE_FILTER_STOP
		UIK.bg(self)
		var root: VBoxContainer = UIK.vbox(8)
		var m: MarginContainer = UIK.margin(root, 14)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(m)
		var top: HBoxContainer = UIK.hbox(12)
		root.add_child(top)
		top.add_child(UIK.title("THE JOB BOARD", 46))
		title_chip = UIK.chip("JOB 1 OF 3", "navy", "flag", 20)
		title_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(title_chip)
		top.add_child(UIK.spacer(true))
		rent = UIK.hbox(0)
		rent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(rent)
		top.add_child(Voice.Bar.new())
		cards = UIK.hbox(14)
		cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(cards)
		var foot: HBoxContainer = UIK.hbox(12)
		foot.custom_minimum_size = Vector2(0, 118)
		root.add_child(foot)
		var sp: HBoxContainer = UIK.speech("", "igor", "IGOR", 72, 20)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		igor_lbl = sp.find_child("text", true, false)
		foot.add_child(sp)
		parts_box = UIK.hbox(8)
		foot.add_child(parts_box)
		var pv: VBoxContainer = UIK.vbox(2)
		parts_box.add_child(pv)
		pv.add_child(UIK.head("IGOR FOUND A PART", 17, UIK.c("purple").darkened(0.15)))
		parts_row = UIK.hbox(8)
		pv.add_child(parts_row)
		hint = UIK.label("", 18, K.pal("ink_soft"), HORIZONTAL_ALIGNMENT_CENTER)
		root.add_child(hint)

	func apply(pd: Dictionary) -> void:
		var offers: Array = pd.get("offers", [])
		var boss: bool = bool(pd.get("can_pick", false))
		var sig: String = JSON.stringify(offers) + str(boss) + JSON.stringify(pd.get("parts", []))
		if sig != _sig:
			_sig = sig
			_votes_sig = ""
			_build(pd, offers, boss)
		UIK.set_chip(title_chip, "JOB %d OF %d" % [int(pd.get("n", 0)) + 1, int(pd.get("of", 3))], "navy")
		igor_lbl.text = str(pd.get("line", ""))
		hint.text = "You choose. The crew's votes are the faces on each card. You may ignore them. Captains do." if boss else "Click a job to vote for it. The captain has the final say (and the blame)."
		# votes
		var votes: Dictionary = pd.get("votes", {})
		var vs: String = JSON.stringify(votes) + str(pd.get("my_vote", -1)) + str(pd.get("part_pick", ""))
		if vs != _votes_sig:
			_votes_sig = vs
			for i in _vote_rows.size():
				var row: HBoxContainer = _vote_rows[i]
				for c in row.get_children():
					c.queue_free()
				var who: Array = votes.get(i, votes.get(float(i), []))
				if who.is_empty():
					row.add_child(UIK.label("no votes yet", 16, Color(UIK.ink(), 0.35)))
				for v in who:
					var pr: TextureRect = UIK.portrait(str(v.seat), 34)
					pr.tooltip_text = "%s wants this one" % str(v.name)
					pr.mouse_filter = Control.MOUSE_FILTER_PASS
					row.add_child(pr)
			for id in _part_btns.keys():
				(_part_btns[id] as Button).set_pressed_no_signal(str(pd.get("part_pick", "")) == id)

	func _build(pd: Dictionary, offers: Array, boss: bool) -> void:
		for c in cards.get_children():
			c.queue_free()
		for c2 in rent.get_children():
			c2.queue_free()
		rent.add_child(Screens.rent_bar(int(pd.get("earned", 0)), int(pd.get("rent", 1)), 320.0))
		_vote_rows = []
		_take_btns = []
		var places: Dictionary = pd.get("places", {})
		var twists: Dictionary = pd.get("twists", {})
		var tilt: Array = [-0.012, 0.008, -0.006]
		for i in offers.size():
			var o: Dictionary = offers[i]
			var w: Array = UIK.window(str(o.title), ["green", "mustard", "red"][clampi(int(o.danger) - 1, 0, 2) if int(o.danger) < 4 else 2], "flag")
			w[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
			w[0].rotation = float(tilt[i % 3])
			cards.add_child(w[0])
			var b: VBoxContainer = w[1]
			b.add_theme_constant_override("separation", 6)
			var hd: HBoxContainer = UIK.hbox(8)
			b.add_child(hd)
			hd.add_child(UIK.portrait(str(o.get("client", "igor")), 62))
			var hv: VBoxContainer = UIK.vbox(-2)
			hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hd.add_child(hv)
			hv.add_child(UIK.head(Screens.money(int(o.pay)), 40, UIK.c("green").darkened(0.25)))
			var dz: HBoxContainer = UIK.hbox(0)
			hv.add_child(dz)
			dz.add_child(UIK.label("Danger ", 17, K.pal("ink_soft")))
			for k in 5:
				dz.add_child(UIK.icon("fire", 20, UIK.c("red") if k < int(o.danger) else Color(UIK.ink(), 0.15)))
			var blurb: Label = UIK.para(str(o.get("blurb", "")), 18)
			blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
			blurb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_child(blurb)
			var pl: Dictionary = places.get(str(o.place), {})
			var pc: PanelContainer = UIK.chip(str(pl.get("name", o.place)), "sky" if false else "paper2", "map", 15)
			pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			pc.tooltip_text = str(pl.get("text", ""))
			pc.mouse_filter = Control.MOUSE_FILTER_PASS
			b.add_child(pc)
			for x in o.get("twists", []):
				var tw: Dictionary = twists.get(str(x), {})
				var tc: PanelContainer = UIK.chip(str(tw.get("name", x)), "lilac", "warning", 15)
				tc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				tc.tooltip_text = str(tw.get("text", ""))
				tc.mouse_filter = Control.MOUSE_FILTER_PASS
				b.add_child(tc)
			var vr: HBoxContainer = UIK.hbox(-6)
			vr.custom_minimum_size = Vector2(0, 36)
			b.add_child(vr)
			_vote_rows.append(vr)
			var tb: Button
			if boss:
				tb = UIK.btn("Take this job", "green", func(): Net.send("pick", {"i": i}), "play", 22)
			else:
				tb = UIK.btn("Vote for this", "blue", func(): Net.send("vote", {"i": i}), "check", 20)
			tb.custom_minimum_size = Vector2(0, 52)
			b.add_child(tb)
			_take_btns.append(tb)
		# parts
		for c3 in parts_row.get_children():
			c3.queue_free()
		_part_btns = {}
		var parts: Array = pd.get("parts", [])
		parts_box.visible = not parts.is_empty()
		for p in parts:
			var id: String = str(p.id)
			var pb: Button = UIK.toggle("%s\n+ %s\n- %s" % [str(p.name), str(p.good), str(p.bad)], "purple", func(_on: bool): Net.send("part", {"id": id}), "", 14)
			pb.custom_minimum_size = Vector2(250, 84)
			pb.disabled = not boss
			pb.tooltip_text = "Fit it for the rest of the shift. One part per job. Or fit nothing."
			parts_row.add_child(pb)
			_part_btns[id] = pb
