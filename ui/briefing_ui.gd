class_name BriefingUI
extends Control
## The pre-mission briefing: who's talking, what we're doing, YOUR job, who's ready. Then 3-2-1 launch.

var title_lbl: Label
var family_chip: PanelContainer
var par_chip: PanelContainer
var speech_box: VBoxContainer
var steps_box: VBoxContainer
var obj_lbl: Label
var job_box: VBoxContainer
var crew_row: HBoxContainer
var ready_btn: Button
var launch_btn: Button
var count_lbl: Label
var count_panel: PanelContainer
var waiting_lbl: Label
var sig: String = ""
var crew_sig: String = ""
var tiles: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("overlay", true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIK.space_bg(self)
	var root: VBoxContainer = UIK.vbox(10)
	var m: MarginContainer = UIK.margin(root, 18)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	# header
	var head: HBoxContainer = UIK.hbox(12)
	root.add_child(head)
	head.add_child(UIK.badge("map", "blue", 46))
	var hv: VBoxContainer = UIK.vbox(0)
	head.add_child(hv)
	hv.add_child(UIK.label("MISSION BRIEFING", 15, Color(1, 1, 1, 0.75)))
	title_lbl = UIK.title("", 36)
	hv.add_child(title_lbl)
	head.add_child(UIK.spacer(true))
	family_chip = UIK.chip("", "purple", "star", 16)
	family_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(family_chip)
	par_chip = UIK.chip("", "blue", "clock", 16)
	par_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(par_chip)
	# body
	var body: HBoxContainer = UIK.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var left: VBoxContainer = UIK.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	speech_box = UIK.vbox(0)
	left.add_child(speech_box)
	var ow: Array = UIK.window("THE PLAN", "green", "check", 12)
	(ow[0] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(ow[0])
	obj_lbl = UIK.wrapped(UIK.label("", 16, K.pal("ink")))
	(ow[1] as VBoxContainer).add_child(obj_lbl)
	steps_box = UIK.vbox(6)
	(ow[1] as VBoxContainer).add_child(steps_box)
	var jw: Array = UIK.window("YOUR JOB", "orange", "crew", 12)
	(jw[0] as Control).custom_minimum_size = Vector2(430, 0)
	body.add_child(jw[0])
	var js: ScrollContainer = ScrollContainer.new()
	js.size_flags_vertical = Control.SIZE_EXPAND_FILL
	js.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(jw[1] as VBoxContainer).add_child(js)
	job_box = UIK.vbox(10)
	job_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	js.add_child(job_box)
	# crew strip
	var cp: PanelContainer = UIK.panel("card", 8, 18)
	root.add_child(cp)
	crew_row = UIK.hbox(6)
	crew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cp.add_child(crew_row)
	# footer
	var foot: HBoxContainer = UIK.hbox(12)
	root.add_child(foot)
	waiting_lbl = UIK.label("", 17, Color(1, 1, 1, 0.85))
	waiting_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(waiting_lbl)
	launch_btn = UIK.btn("Launch now", "orange", func(): Net.send("launch", {}), "play")
	foot.add_child(launch_btn)
	ready_btn = UIK.toggle_btn("I'M READY", "green", func(on: bool): Net.send("ready", {"on": on}), "check")
	ready_btn.custom_minimum_size = Vector2(260, 58)
	ready_btn.add_theme_font_size_override("font_size", 24)
	foot.add_child(ready_btn)
	# countdown
	count_panel = PanelContainer.new()
	count_panel.add_theme_stylebox_override("panel", UIK.sb(Color(K.pal("night"), 0.82), 999, K.pal("yellow"), 6, 30, 12))
	count_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	count_panel.custom_minimum_size = Vector2(220, 220)
	count_panel.position = Vector2(-110, -110)
	count_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_lbl = UIK.title("3", 110, K.pal("yellow"))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_panel.add_child(count_lbl)
	count_panel.visible = false
	add_child(count_panel)

func apply(f: Dictionary) -> void:
	var ph: Dictionary = f.get("ph", {})
	var b: Dictionary = ph.get("briefing", {})
	var s: String = str(b.get("title", "")) + str(f.get("seats", []))
	if s != sig:
		sig = s
		_rebuild(b, f.get("seats", []))
	_update_steps(f.get("common", {}).get("steps", b.get("steps", [])))
	_update_crew(ph.get("roster", []))
	var cd: float = float(ph.get("countdown", -1.0))
	count_panel.visible = cd >= 0.0
	if cd >= 0.0:
		var n: int = int(ceil(cd))
		var tx: String = str(n) if n > 0 else "GO!"
		if count_lbl.text != tx:
			count_lbl.text = tx
			Sfx.play("blip" if n > 0 else "ding")
	ready_btn.set_pressed_no_signal(bool(ph.get("you_ready", false)))
	ready_btn.text = "READY!" if bool(ph.get("you_ready", false)) else "I'M READY"
	ready_btn.visible = not f.get("seats", []).is_empty()
	launch_btn.visible = bool(ph.get("can_launch", false))
	var waiting: Array = []
	for r in ph.get("roster", []):
		if int(r.owner) != 0 and not bool(r.ready) and not (str(r.name) in waiting):
			waiting.append(str(r.name))
	if cd >= 0.0:
		waiting_lbl.text = "Launching! Places, everyone."
	elif waiting.is_empty():
		waiting_lbl.text = "Everyone's ready."
	else:
		waiting_lbl.text = "Waiting for: " + ", ".join(waiting)

func _rebuild(b: Dictionary, seats: Array) -> void:
	title_lbl.text = str(b.get("title", "Mission"))
	for l in family_chip.find_children("*", "Label", true, false):
		(l as Label).text = str(b.get("family", ""))
	for l2 in par_chip.find_children("*", "Label", true, false):
		(l2 as Label).text = "Par " + K.fmt_time(float(b.get("par", 120.0)))
	for ch in speech_box.get_children():
		ch.queue_free()
	speech_box.add_child(UIK.speech(str(b.get("story", "")), str(b.get("narrator", "igor")), str(b.get("who", "IGOR")), 110))
	obj_lbl.text = str(b.get("objective", ""))
	for ch2 in job_box.get_children():
		ch2.queue_free()
	var tips: Dictionary = b.get("tips", {})
	if seats.is_empty():
		job_box.add_child(UIK.wrapped(UIK.label("You don't have a role yet. Take one from the crew below.", 16)))
	for seat in seats:
		var row: HBoxContainer = UIK.hbox(10)
		row.add_child(UIK.portrait(str(K.SEAT_INFO[seat].portrait), 70))
		var v: VBoxContainer = UIK.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var hh: HBoxContainer = UIK.hbox(6)
		v.add_child(hh)
		hh.add_child(UIK.chip(K.seat_name(seat).to_upper(), UIK.seat_color(seat), str(K.SEAT_INFO[seat].icon), 14))
		hh.add_child(UIK.label(str(K.SEAT_INFO[seat].persona), 14, K.pal("ink_soft")))
		v.add_child(UIK.wrapped(UIK.label(str(tips.get(seat, K.SEAT_INFO[seat].job)), 16)))
		job_box.add_child(row)

func _update_steps(steps: Array) -> void:
	var need: int = steps.size()
	while steps_box.get_child_count() < need:
		var h: HBoxContainer = UIK.hbox(8)
		var num: PanelContainer = UIK.badge("check", "neutral", 30)
		num.name = "badge"
		h.add_child(num)
		var l: Label = UIK.wrapped(UIK.label("", 16))
		l.name = "text"
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		steps_box.add_child(h)
	for i in steps_box.get_child_count():
		var row: Node = steps_box.get_child(i)
		row.visible = i < need
		if i < need:
			var st: Dictionary = steps[i]
			(row.get_node("text") as Label).text = "%d.  %s" % [i + 1, st.text]
			var bdg: PanelContainer = row.get_node("badge")
			var col: Color = K.pal("green") if bool(st.done) else K.pal("well")
			bdg.add_theme_stylebox_override("panel", UIK.sb(col, 15, col.darkened(0.2), 2, 5))
			(bdg.get_child(0) as TextureRect).modulate = Color.WHITE if bool(st.done) else Color(K.pal("ink"), 0.25)

func _update_crew(roster: Array) -> void:
	var s: String = ""
	for r in roster:
		s += "%s:%s:%s:%s:%s|" % [r.seat, r.owner, r.ready, r.bot, r.mine]
	if s == crew_sig:
		return
	crew_sig = s
	for ch in crew_row.get_children():
		ch.queue_free()
	for r2 in roster:
		var seat: String = r2.seat
		var tile: VBoxContainer = UIK.vbox(2)
		tile.custom_minimum_size = Vector2(160, 0)
		var top: HBoxContainer = UIK.hbox(6)
		tile.add_child(top)
		top.add_child(UIK.portrait(str(K.SEAT_INFO[seat].portrait), 50))
		var v: VBoxContainer = UIK.vbox(0)
		top.add_child(v)
		v.add_child(UIK.heading(K.seat_name(seat), 15))
		var who: String = "Open"
		if int(r2.owner) != 0:
			who = "You" if bool(r2.mine) else str(r2.name)
		elif bool(r2.bot):
			who = "AI " + str(Bot.PERSONALITIES.get(str(r2.kind), {}).get("name", "robot")).split(" ")[0]
		v.add_child(UIK.label(who, 13, K.pal("ink_soft")))
		var ok: bool = bool(r2.ready)
		var st: PanelContainer = UIK.chip("Ready" if ok else ("Reading..." if int(r2.owner) != 0 else "Empty"), "green" if ok else "neutral", "check" if ok else "clock", 13)
		st.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(st)
		if not bool(r2.mine) and int(r2.owner) == 0:
			var tb: Button = UIK.btn("Take", "blue", func(): Net.send("claim", {"seat": seat}))
			tb.add_theme_font_size_override("font_size", 13)
			tb.custom_minimum_size = Vector2(0, 30)
			tile.add_child(tb)
		elif bool(r2.mine):
			var lb: Button = UIK.btn("Leave", "neutral", func(): Net.send("release", {"seat": seat}))
			lb.add_theme_font_size_override("font_size", 13)
			lb.custom_minimum_size = Vector2(0, 30)
			tile.add_child(lb)
		crew_row.add_child(tile)
