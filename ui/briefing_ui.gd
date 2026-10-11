class_name BriefingUI
extends Control
## The mission briefing, read out by IGOR (text-to-speech, subtitled). Three short pages:
##   1. What's going on (the story)   2. The plan (numbered steps)   3. NEW TODAY (the one new thing, and whose it is)
## Then everyone presses I'M READY and a 3-second countdown launches the mission.

var head_num: Label
var head_title: Label
var head_place: Label
var narrator: TextureRect
var page_title: Label
var page_text: Label
var page_list: VBoxContainer
var new_who: HBoxContainer
var dots: HBoxContainer
var prev_btn: Button
var next_btn: Button
var jobs: VBoxContainer
var crew_row: HBoxContainer
var ready_btn: Button
var launch_btn: Button
var wait_lbl: Label
var count_lbl: Label
var count_box: Control

var brief: Dictionary = {}
var page: int = 0
var pages: Array = []
var _sig: String = ""
var _jobs_sig: String = ""
var _type_t: float = 0.0
var _page_t: float = 0.0
var _spoken: int = -1
var _auto: bool = true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("overlay", true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIK.bg(self)
	var root: VBoxContainer = UIK.vbox(10)
	var m: MarginContainer = UIK.margin(root, 16)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	# header
	var hh: HBoxContainer = UIK.hbox(16)
	root.add_child(hh)
	var hv: VBoxContainer = UIK.vbox(-2)
	hh.add_child(hv)
	head_num = UIK.head("MISSION BRIEFING", 22, UIK.c("red"))
	hv.add_child(head_num)
	head_title = UIK.title("", 50)
	hv.add_child(head_title)
	hh.add_child(UIK.spacer(true))
	head_place = UIK.head("", 22, K.pal("ink_soft"))
	head_place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(head_place)
	# main
	var main: HBoxContainer = UIK.hbox(16)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)
	var left: HBoxContainer = UIK.hbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.5
	main.add_child(left)
	narrator = UIK.portrait("igor", 150)
	narrator.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.add_child(narrator)
	var bub: PanelContainer = UIK.panel("panel", [10, 4, 10, 4])
	bub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(bub)
	var bv: VBoxContainer = UIK.vbox(8)
	bub.add_child(bv)
	page_title = UIK.head("", 26, UIK.c("red"))
	bv.add_child(page_title)
	page_text = UIK.para("", 24)
	bv.add_child(page_text)
	page_list = UIK.vbox(6)
	bv.add_child(page_list)
	new_who = UIK.hbox(6)
	bv.add_child(new_who)
	bv.add_child(UIK.spacer(true))
	var nav: HBoxContainer = UIK.hbox(10)
	bv.add_child(nav)
	prev_btn = UIK.btn("Back", "cream", func(): _goto(page - 1, false), "back", 20)
	nav.add_child(prev_btn)
	dots = UIK.hbox(6)
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_child(dots)
	nav.add_child(UIK.btn("Again", "cream", func(): _goto(page, false), "speaker", 20))
	next_btn = UIK.btn("Next", "blue", func(): _goto(page + 1, false), "play", 20)
	nav.add_child(next_btn)
	var jw: Array = UIK.window("YOUR JOB", "green", "crew")
	jw[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(jw[0])
	var js: ScrollContainer = ScrollContainer.new()
	js.size_flags_vertical = Control.SIZE_EXPAND_FILL
	js.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(jw[1] as VBoxContainer).add_child(js)
	jobs = UIK.vbox(10)
	jobs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	js.add_child(jobs)
	# crew strip + ready
	var foot: HBoxContainer = UIK.hbox(12)
	root.add_child(foot)
	var cp: PanelContainer = UIK.panel("panel_small", [2, 0, 2, 0])
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(cp)
	crew_row = UIK.hbox(4)
	crew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cp.add_child(crew_row)
	var rv: VBoxContainer = UIK.vbox(4)
	foot.add_child(rv)
	wait_lbl = UIK.label("", 18, K.pal("ink_soft"), HORIZONTAL_ALIGNMENT_CENTER)
	wait_lbl.clip_text = true
	wait_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wait_lbl.custom_minimum_size = Vector2(380, 0)
	rv.add_child(wait_lbl)
	var rb: HBoxContainer = UIK.hbox(8)
	rv.add_child(rb)
	launch_btn = UIK.btn("Launch now", "orange", func(): Net.send("launch"), "play", 18)
	rb.add_child(launch_btn)
	ready_btn = UIK.toggle("I'M READY", "green", func(on: bool):
		Net.send("ready", {"on": on}), "check", 26)
	ready_btn.custom_minimum_size = Vector2(200, 60)
	rb.add_child(ready_btn)
	# countdown
	count_box = CenterContainer.new()
	count_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_box.visible = false
	add_child(count_box)
	var cpn: PanelContainer = UIK.panel("panel", [30, 10, 30, 10])
	count_box.add_child(cpn)
	count_lbl = UIK.title("3", 140, UIK.c("red"), HORIZONTAL_ALIGNMENT_CENTER)
	count_lbl.custom_minimum_size = Vector2(180, 0)
	cpn.add_child(count_lbl)

func apply(pd: Dictionary, my_seats: Array) -> void:
	var b: Dictionary = pd.get("brief", {})
	var sig: String = "%s/%d" % [str(b.get("id", "")), int(b.get("num", 0))]
	if sig != _sig and not b.is_empty():
		_sig = sig
		_setup(b)
	var jsig: String = ",".join(PackedStringArray(my_seats))
	if jsig != _jobs_sig:
		_jobs_sig = jsig
		_build_jobs(my_seats)
	# crew + ready
	for c in crew_row.get_children():
		c.queue_free()
	var waiting: Array = []
	for r in pd.get("roster", []):
		crew_row.add_child(_crew_tile(r))
		if str(r.kind) == "human" and not bool(r.ready):
			waiting.append(K.seat_name(str(r.seat)) if str(r.who) == "You" else str(r.who))
	ready_btn.set_pressed_no_signal(bool(pd.get("you_ready", false)))
	ready_btn.text = "READY!" if ready_btn.button_pressed else "I'M READY"
	launch_btn.visible = bool(pd.get("can_launch", false))
	var cd: float = float(pd.get("countdown", -1.0))
	count_box.visible = cd >= 0.0
	if cd >= 0.0:
		count_lbl.text = str(int(ceil(cd)))
		wait_lbl.text = "Launching! Places, everyone."
	else:
		var uniq: Array = []
		for w in waiting:
			if not (w in uniq):
				uniq.append(w)
		wait_lbl.text = ("Waiting for: " + ", ".join(PackedStringArray(uniq))) if not uniq.is_empty() else ""

func _setup(b: Dictionary) -> void:
	brief = b
	head_num.text = "MISSION %d BRIEFING" % int(b.get("num", 0))
	head_title.text = str(b.get("title", "")).to_upper()
	head_place.text = str(b.get("place", ""))
	var nw: Dictionary = b.get("new", {})
	var plan_lines: Array = []
	for i in (b.get("plan", []) as Array).size():
		plan_lines.append("Step %d: %s." % [i + 1, str(b.plan[i])])
	pages = [
		{"title": "WHAT'S GOING ON", "who": str(b.get("narrator", "igor")), "text": str(b.get("story", "")), "say": str(b.get("story", ""))},
		{"title": "THE PLAN", "who": "igor", "text": "Here is the plan. IGOR made it. It is perfect.", "list": b.get("plan", []),
			"say": "Here is the plan. " + " ".join(PackedStringArray(plan_lines))},
		{"title": "NEW TODAY: " + str(nw.get("title", "")).to_upper(), "who": "igor", "text": str(nw.get("text", "")),
			"who_list": nw.get("who", []), "say": "New today. " + str(nw.get("title", "")) + ". " + str(nw.get("text", ""))},
	]
	_auto = true
	_spoken = -1
	_goto(0, true)

func _goto(i: int, auto: bool) -> void:
	if pages.is_empty():
		return
	if not auto:
		_auto = false
	page = clampi(i, 0, pages.size() - 1)
	var p: Dictionary = pages[page]
	narrator.texture = Art.sized("portrait_" + str(p.who), 150)
	page_title.text = str(p.title)
	page_text.text = str(p.text)
	page_text.visible_ratio = 0.0
	_type_t = 0.0
	_page_t = 0.0
	for c in page_list.get_children():
		c.queue_free()
	var n: int = 1
	for line in p.get("list", []):
		var h: HBoxContainer = UIK.hbox(10)
		var badge: PanelContainer = UIK.chip(str(n), "red", "", 20)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(badge)
		var l: Label = UIK.para(str(line), 22)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		page_list.add_child(h)
		n += 1
	for c2 in new_who.get_children():
		c2.queue_free()
	for st in p.get("who_list", []):
		var cell: VBoxContainer = UIK.vbox(0)
		cell.add_child(UIK.portrait(str(st), 64))
		cell.add_child(UIK.head(K.seat_name(str(st)).to_upper(), 14, K.seat_color(str(st)).darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER))
		new_who.add_child(cell)
	for d in dots.get_children():
		d.queue_free()
	for k in pages.size():
		dots.add_child(UIK.icon("star", 22, UIK.c("red") if k == page else Color(UIK.ink(), 0.25)))
	prev_btn.disabled = page == 0
	next_btn.disabled = page >= pages.size() - 1
	_spoken = page
	UIK.speak(str(p.get("say", p.text)))

func _process(dt: float) -> void:
	if not visible or pages.is_empty():
		return
	_type_t += dt
	_page_t += dt
	var total: int = page_text.text.length()
	if total > 0 and page_text.visible_ratio < 1.0:
		page_text.visible_ratio = minf(1.0, _type_t * 38.0 / float(total))
	# move on by itself when IGOR has finished talking (or after a reading-speed pause without speech)
	if _auto and page < pages.size() - 1:
		var say: String = str(pages[page].get("say", ""))
		var est: float = 2.5 + say.length() / 16.0
		var tts: bool = UIK.voice_on() and DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)
		var done: bool = (_page_t > 2.5 and not UIK.speaking()) if tts else _page_t > est
		if done:
			_goto(page + 1, true)

func _build_jobs(seats: Array) -> void:
	for c in jobs.get_children():
		c.queue_free()
	var nw: Array = brief.get("new", {}).get("who", [])
	if seats.is_empty():
		jobs.add_child(UIK.para("You're watching this one. Pick a seat in the Crew Room next time!", 21))
	for s in seats:
		var row: HBoxContainer = UIK.hbox(8)
		jobs.add_child(row)
		var pr: TextureRect = UIK.portrait(str(s), 76)
		pr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(pr)
		var v: VBoxContainer = UIK.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var hr: HBoxContainer = UIK.hbox(6)
		v.add_child(hr)
		hr.add_child(UIK.head(K.seat_name(str(s)).to_upper(), 22, K.seat_color(str(s)).darkened(0.2)))
		if str(s) in nw:
			hr.add_child(UIK.chip("NEW!", "red", "star", 15))
		v.add_child(UIK.label(K.persona(str(s)), 18, K.pal("ink_soft")))
		v.add_child(UIK.para(str(K.SEAT_INFO[s].job), 20))

func _crew_tile(r: Dictionary) -> Control:
	var v: VBoxContainer = UIK.vbox(-2)
	v.custom_minimum_size = Vector2(88, 0)
	var pr: TextureRect = UIK.portrait(str(r.seat), 46)
	pr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if str(r.kind) == "empty":
		pr.modulate = Color(1, 1, 1, 0.35)
	v.add_child(pr)
	var who: String = str(r.who)
	v.add_child(UIK.label(who, 17, K.pal("ink_soft"), HORIZONTAL_ALIGNMENT_CENTER))
	var st: String = "READY" if bool(r.ready) and str(r.kind) == "human" else ("ROBOT" if str(r.kind) == "bot" else ("EMPTY" if str(r.kind) == "empty" else "READING"))
	var c: PanelContainer = UIK.chip(st, "green" if st == "READY" else ("steel" if st == "ROBOT" else "cream"), "", 14)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(c)
	return v
