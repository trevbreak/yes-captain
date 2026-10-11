class_name CaptainUI
extends Control
## The Captain's Table. The captain sees the whole picture and touches NOTHING:
##   the chart (where everything is), the mission (what to do next), LOOK OUT! (what's about to go wrong and
##   who to tell), the ship board (what's broken or hot) and the crew board (what everyone is doing right now).

var chart: Chart
var goal_now: Label
var goal_next: Label
var goal_count: Label
var warn_box: VBoxContainer
var warn_panel: PanelContainer
var cut: Cutaway
var hull_bar: Gauges.Bar
var heat_bar: Gauges.Bar
var gun_bar: Gauges.Bar
var power_bar: Gauges.Bar
var pud_bar: Gauges.Bar
var crew_cells: Dictionary = {}
var mission_rib: PanelContainer
var _warn_sig: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row: HBoxContainer = UIK.hbox(12)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	# ---- the chart
	var cw: Array = UIK.window("THE CHART", "navy", "map")
	cw[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cw[0].size_flags_stretch_ratio = 1.05
	row.add_child(cw[0])
	# LOOK OUT! is a fixed strip above the chart: it never covers what it's warning about
	warn_panel = UIK.panel("well", [0, -6, 0, -6])
	warn_panel.custom_minimum_size = Vector2(0, 92)
	(cw[1] as VBoxContainer).add_child(warn_panel)
	var wh: HBoxContainer = UIK.hbox(8)
	warn_panel.add_child(wh)
	var wt: Label = UIK.head("LOOK\nOUT!", 18, UIK.c("red"))
	wt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wh.add_child(wt)
	warn_box = UIK.vbox(1)
	warn_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	wh.add_child(warn_box)
	chart = Chart.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(cw[1] as VBoxContainer).add_child(chart)
	# ---- the right column
	var right: VBoxContainer = UIK.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var gw: Array = UIK.window("THE MISSION", "red", "flag")
	right.add_child(gw[0])
	var gb: VBoxContainer = gw[1]
	goal_count = UIK.head("STEP 1 OF 1", 16, K.pal("ink_soft"))
	gb.add_child(goal_count)
	gb.add_theme_constant_override("separation", 2)
	goal_now = UIK.para("", 23)
	goal_now.add_theme_font_override("font", UIK.font("body"))
	gb.add_child(goal_now)
	goal_next = UIK.label("", 18, K.pal("ink_soft"))
	goal_next.clip_text = true
	goal_next.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	gb.add_child(goal_next)
	# ship board
	var sw: Array = UIK.window("THE SHIP", "mustard", "engineer")
	right.add_child(sw[0])
	var sh: HBoxContainer = UIK.hbox(10)
	(sw[1] as VBoxContainer).add_child(sh)
	cut = Cutaway.new()
	cut.custom_minimum_size = Vector2(240, 118)
	cut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(cut)
	var gauges: VBoxContainer = UIK.vbox(2)
	gauges.custom_minimum_size = Vector2(196, 0)
	gauges.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_child(gauges)
	hull_bar = Gauges.Bar.new("red", 25)
	heat_bar = Gauges.Bar.new("orange", 25)
	gun_bar = Gauges.Bar.new("orange", 25)
	power_bar = Gauges.Bar.new("mustard", 25)
	power_bar.marker = 6.0 / 9.0
	pud_bar = Gauges.Bar.new("pink", 25)
	for b in [hull_bar, heat_bar, gun_bar, power_bar, pud_bar]:
		gauges.add_child(b)
	# crew board
	var crw: Array = UIK.window("THE CREW", "blue", "crew")
	crw[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(crw[0])
	var g: GridContainer = UIK.grid(3, 6)
	(crw[1] as VBoxContainer).add_child(g)
	for st in K.STATIONS:
		var cell: HBoxContainer = UIK.hbox(6)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(180, 0)
		g.add_child(cell)
		var pr: TextureRect = UIK.portrait(st, 40)
		cell.add_child(pr)
		var cv: VBoxContainer = UIK.vbox(-4)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(cv)
		var nm: Label = UIK.head(K.seat_name(st).to_upper(), 15, K.seat_color(st).darkened(0.25))
		cv.add_child(nm)
		var ln: Label = UIK.label("", 16)
		ln.clip_text = true
		ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ln.custom_minimum_size = Vector2(120, 0)
		ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_child(ln)
		var wl: Label = UIK.label("", 16, UIK.c("red"))
		wl.clip_text = true
		wl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		wl.custom_minimum_size = Vector2(120, 0)
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_child(wl)
		crew_cells[st] = {"line": ln, "warn": wl, "name": nm, "pic": pr}

func apply(v: Dictionary, com: Dictionary) -> void:
	var feats: Dictionary = com.get("features", {})
	v["_t"] = float(com.get("t", 0.0))
	chart.v = v
	# the mission
	var steps: Array = v.get("steps", [])
	var now: int = -1
	for i in steps.size():
		if bool(steps[i].now):
			now = i
	if now >= 0:
		goal_count.text = "STEP %d OF %d" % [now + 1, steps.size()]
		goal_now.text = str(steps[now].text)
		goal_next.text = ("Then: " + str(steps[now + 1].text)) if now + 1 < steps.size() else "Last step!"
	elif not steps.is_empty():
		goal_count.text = "ALL DONE"
		goal_now.text = "Mission complete!"
		goal_next.text = ""
	# look out!
	var warns: Array = v.get("warnings", [])
	var sig: String = ""
	for w in warns:
		sig += str(w.text) + "|"
	if sig != _warn_sig:
		_warn_sig = sig
		for c in warn_box.get_children():
			c.queue_free()
		if warns.is_empty():
			warn_box.add_child(UIK.label("All quiet. Suspiciously quiet.", 18, K.pal("ink_soft")))
		for w in warns.slice(0, 3):
			warn_box.add_child(_warn_row(w))
	# the ship
	var bd: Dictionary = v.get("board", {})
	cut.systems = bd.get("systems", {})
	cut.features = feats
	cut.pudding_room = str(bd.get("pud_room", "")) if bool(bd.get("pud_out", false)) else ""
	cut.stuck = bd.get("stuck", [])
	cut.blackout = bool(bd.get("blackout", false))
	var eh: float = float(bd.get("engine_heat", 0.0)) / 100.0
	var gh: float = float(bd.get("gun_heat", 0.0)) / 100.0
	cut.hot = {"engine_p": eh, "engine_s": eh, "gun": gh}
	var hull: float = float(com.get("hull", 100.0))
	hull_bar.set_value(hull / maxf(1.0, float(com.get("hull_max", 100.0))), "HULL %d%%" % int(hull))
	heat_bar.visible = bool(feats.get("heat", false))
	heat_bar.set_value(eh, "ENGINES %d%%" % int(eh * 100.0))
	heat_bar.set_colour(UIK.c("red") if eh > 0.8 else UIK.c("orange"))
	gun_bar.visible = bool(feats.get("heat", false))
	gun_bar.set_value(gh, "GUN %d%%" % int(gh * 100.0))
	gun_bar.set_colour(UIK.c("red") if gh > 0.8 else UIK.c("orange"))
	power_bar.visible = bool(feats.get("power", false))
	var dr: float = float(bd.get("draw", 0.0))
	power_bar.set_value(dr / 9.0, "REACTOR %.1f/6" % dr)
	power_bar.set_colour(UIK.c("red") if dr > 6.0 else UIK.c("mustard"))
	pud_bar.visible = bool(feats.get("pudding", false))
	var pm: float = float(bd.get("pud_mood", 0.0))
	pud_bar.set_value(pm / 100.0, "PUDDING LOOSE!" if bool(bd.get("pud_out", false)) else "PUDDING %d%%" % int(pm))
	pud_bar.set_colour(UIK.c("red") if pm < 30.0 else UIK.c("pink"))
	# the crew
	var crew: Dictionary = v.get("crew", {})
	for st in crew_cells.keys():
		var cl: Dictionary = crew.get(st, {})
		var cell: Dictionary = crew_cells[st]
		(cell.line as Label).text = str(cl.get("text", ""))
		(cell.line as Label).tooltip_text = (cell.line as Label).text
		var al: int = int(cl.get("alert", 0))
		var wl2: Label = cell.warn
		wl2.text = str(cl.get("warn", ""))
		wl2.add_theme_color_override("font_color", UIK.c("red") if al >= 2 else Color("#9a6a10"))
		if al >= 2:
			wl2.add_theme_font_override("font", UIK.font("head"))
			wl2.add_theme_font_size_override("font_size", 14)
		else:
			wl2.add_theme_font_override("font", UIK.font("body"))
			wl2.add_theme_font_size_override("font_size", 16)

func _warn_row(w: Dictionary) -> Control:
	var h: HBoxContainer = UIK.hbox(6)
	var lvl: int = int(w.get("level", 1))
	var col: Color = UIK.c("red") if lvl >= 3 else (UIK.c("orange") if lvl == 2 else Color("#9a6a10"))
	h.add_child(UIK.icon("warning" if lvl >= 2 else "eye", 18, col))
	var l: Label = UIK.label(str(w.text), 17, col)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(200, 0)
	if lvl >= 3:
		l.add_theme_font_override("font", UIK.font("head"))
		l.add_theme_font_size_override("font_size", 15)
	h.add_child(l)
	var who: String = str(w.get("who", ""))
	if who != "":
		var pr: TextureRect = UIK.portrait(who, 22)
		pr.tooltip_text = "Tell " + K.seat_name(who)
		h.add_child(pr)
	return h
