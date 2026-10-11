class_name Screens
extends RefCounted
## Full-screen moments: the debrief after every mission.

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
	return [root, win[1]]

static func debrief(d: Dictionary, on_next: Callable, on_retry: Callable, on_lobby: Callable) -> Control:
	var ok: bool = bool(d.get("ok", false))
	var final_: bool = bool(d.get("final", false))
	var title: String = ("MISSION %d COMPLETE!" % int(d.get("num", 0))) if ok else "MISSION FAILED"
	if final_:
		title = "YOU MADE IT TO HAVEN!"
	var fr: Array = _frame(title, "green" if ok else "red", "check" if ok else "x")
	var b: VBoxContainer = fr[1]
	b.add_theme_constant_override("separation", 12)
	var top: HBoxContainer = UIK.hbox(20)
	b.add_child(top)
	var sv: VBoxContainer = UIK.vbox(2)
	top.add_child(sv)
	sv.add_child(UIK.head(str(d.get("title", "")).to_upper(), 30))
	var stars: HBoxContainer = UIK.hbox(4)
	sv.add_child(stars)
	var got: int = int(d.get("stars", 0))
	for i in 3:
		stars.add_child(UIK.icon("star", 62, UIK.c("mustard") if i < got else Color(UIK.ink(), 0.18)))
	var facts: VBoxContainer = UIK.vbox(2)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(facts)
	if ok:
		facts.add_child(UIK.label("★ Mission complete", 21))
		facts.add_child(UIK.label("%s Hull above 60%%  (%d%%)" % ["★" if float(d.get("hull", 0)) >= 60.0 else "☆", int(float(d.get("hull", 0)))], 21))
		facts.add_child(UIK.label("%s Under par  (%s, par %s)" % ["★" if float(d.get("time", 0)) <= float(d.get("par", 0)) else "☆",
			K.fmt_time(float(d.get("time", 0))), K.fmt_time(float(d.get("par", 0)))], 21))
	else:
		facts.add_child(UIK.para(str(d.get("reason", "Something went very wrong.")), 24, UIK.c("red")))
		facts.add_child(UIK.label("Time: %s" % K.fmt_time(float(d.get("time", 0))), 21))
	var said: String
	if final_:
		said = "Haven. Pudding is safe. The Overlord will calm down eventually. IGOR is proud of you, meat. IGOR will deny this."
	elif ok:
		said = Igor.line("mission_done")
	else:
		said = "Is over. IGOR suggests: talk more. Shout, even. Then try again."
	b.add_child(UIK.speech(said, "igor", "IGOR", 80, 22))
	if bool(d.get("opened", false)) and str(d.get("next", "")) != "":
		var nid: String = str(d.next)
		b.add_child(UIK.chip("NEW MISSION UNLOCKED: %s  (new: %s)" % [str(Missions.INFO[nid].title).to_upper(), Missions.INFO[nid].new], "mustard", "star", 19))
	var aw: Array = d.get("awards", [])
	if not aw.is_empty():
		b.add_child(UIK.head("CREW AWARDS", 22))
		var g: GridContainer = UIK.grid(2, 10)
		b.add_child(g)
		for a in aw:
			var h: HBoxContainer = UIK.hbox(8)
			h.custom_minimum_size = Vector2(390, 0)
			h.add_child(UIK.portrait(str(a.seat), 52))
			var v: VBoxContainer = UIK.vbox(-4)
			v.add_child(UIK.head(str(a.title), 20, UIK.c("red")))
			v.add_child(UIK.label("%s: %s" % [K.seat_name(str(a.seat)), str(a.text)], 18))
			h.add_child(v)
			g.add_child(h)
	var br: HBoxContainer = UIK.hbox(10)
	br.alignment = BoxContainer.ALIGNMENT_END
	b.add_child(br)
	if bool(d.get("can_continue", false)):
		br.add_child(UIK.btn("Crew Room", "cream", on_lobby, "crew"))
		br.add_child(UIK.btn("Try again", "orange" if ok else "green", on_retry, "back"))
		if str(d.get("next", "")) != "":
			br.add_child(UIK.btn("Next mission", "green", on_next, "play", 24))
	else:
		br.add_child(UIK.label("Waiting for the captain to decide what's next...", 21, K.pal("ink_soft")))
	return fr[0]
