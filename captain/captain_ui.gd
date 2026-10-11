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
	var holder: Control = Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.clip_contents = true
	(cw[1] as VBoxContainer).add_child(holder)
	chart = Chart.new()
	chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(chart)
	# LOOK OUT! sits on the chart, top-left, only when something is wrong
	warn_panel = UIK.panel("panel_small", [0, -2, 0, -2])
	warn_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	warn_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	warn_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	warn_panel.offset_right = -8
	warn_panel.offset_bottom = -8
	warn_panel.custom_minimum_size = Vector2(330, 0)
	warn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(warn_panel)
	var wv: VBoxContainer = UIK.vbox(2)
	warn_panel.add_child(wv)
	wv.add_child(UIK.head("LOOK OUT!", 18, UIK.c("red")))
	warn_box = UIK.vbox(3)
	wv.add_child(warn_box)
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
		ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ln.custom_minimum_size = Vector2(130, 0)
		ln.max_lines_visible = 2
		cv.add_child(ln)
		crew_cells[st] = {"line": ln, "name": nm, "pic": pr}

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
		warn_panel.visible = not warns.is_empty()
		for w in warns.slice(0, 4):
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
		var al: int = int(cl.get("alert", 0))
		(cell.line as Label).add_theme_color_override("font_color", UIK.c("red") if al >= 2 else (Color("#9a6a10") if al == 1 else UIK.ink()))

func _warn_row(w: Dictionary) -> Control:
	var h: HBoxContainer = UIK.hbox(6)
	var lvl: int = int(w.get("level", 1))
	var col: Color = UIK.c("red") if lvl >= 3 else (UIK.c("orange") if lvl == 2 else Color("#9a6a10"))
	h.add_child(UIK.icon("warning" if lvl >= 2 else "eye", 20, col))
	var l: Label = UIK.label(str(w.text), 18, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(150, 0)
	if lvl >= 3:
		l.add_theme_font_override("font", UIK.font("head"))
		l.add_theme_font_size_override("font_size", 16)
	h.add_child(l)
	var who: String = str(w.get("who", ""))
	if who != "":
		var pr: TextureRect = UIK.portrait(who, 28)
		pr.tooltip_text = "Tell " + K.seat_name(who)
		h.add_child(pr)
	return h
