class_name Screens
extends RefCounted
## Full-screen and overlay panels: sector map, Black Box replay, debrief, game over, ending, pit stop.

# ================================================================ Replay (Black Box)
class ReplayView extends Control:
	var trail: Array = []
	var frames: Array = []
	var marks: Array = []
	var goal: Vector2 = Vector2.ZERO
	var t: float = 0.0
	var duration: float = 1.0
	var bounds: Rect2 = Rect2(-100, -100, 200, 200)
	var speed: float = 2.0

	func _init() -> void:
		custom_minimum_size = Vector2(420, 180)
		clip_contents = true

	func setup(d: Dictionary) -> void:
		trail = d.get("trail", [])
		frames = d.get("frames", [])
		marks = d.get("marks", [])
		var g: Array = d.get("goal", [0, 0])
		goal = Vector2(float(g[0]), float(g[1]))
		var mn: Vector2 = Vector2(1e9, 1e9)
		var mx: Vector2 = Vector2(-1e9, -1e9)
		for p in trail:
			mn = Vector2(minf(mn.x, float(p[1])), minf(mn.y, float(p[2])))
			mx = Vector2(maxf(mx.x, float(p[1])), maxf(mx.y, float(p[2])))
		for f in frames:
			for e in f.e:
				var ep: Vector2 = Vector2(float(e[1]), float(e[2]))
				if absf(ep.x) < 1500.0 and absf(ep.y) < 1500.0:
					mn = Vector2(minf(mn.x, ep.x), minf(mn.y, ep.y))
					mx = Vector2(maxf(mx.x, ep.x), maxf(mx.y, ep.y))
		if trail.is_empty():
			mn = Vector2(-100, -100)
			mx = Vector2(100, 100)
		mn = mn.min(goal)
		mx = mx.max(goal)
		bounds = Rect2(mn - Vector2(60, 60), (mx - mn) + Vector2(120, 120))
		duration = float(trail[trail.size() - 1][0]) if not trail.is_empty() else 1.0
		t = 0.0

	func _process(delta: float) -> void:
		t += delta * speed * (duration / 20.0 if duration > 40.0 else 1.0)
		if t > duration + 2.0:
			t = 0.0
		queue_redraw()

	func _ready() -> void:
		set_process(true)

	func _map(p: Vector2) -> Vector2:
		var sc: float = minf(size.x / bounds.size.x, size.y / bounds.size.y)
		var off: Vector2 = (size - bounds.size * sc) * 0.5
		return off + (p - bounds.position) * sc

	func _draw() -> void:
		var ink: Color = K.pal("ink")
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.06, 0.16), true)
		for i in 12:
			draw_line(Vector2(i * size.x / 12.0, 0), Vector2(i * size.x / 12.0, size.y), Color(1, 1, 1, 0.04), 1.0)
		var font: Font = get_theme_default_font()
		# goal
		draw_arc(_map(goal), 10.0, 0, TAU, 20, K.pal("green"), 3.0)
		# trail
		if trail.size() > 1:
			var pts: PackedVector2Array = PackedVector2Array()
			for p in trail:
				if float(p[0]) <= t:
					pts.append(_map(Vector2(float(p[1]), float(p[2]))))
			if pts.size() > 1:
				draw_polyline(pts, K.pal("butter"), 3.0, true)
		# frame at time t
		var fr: Dictionary = {}
		for f in frames:
			if float(f.t) <= t:
				fr = f
		if not fr.is_empty():
			for e in fr.e:
				var col: Color = K.pal("magenta") if str(e[0]) in ["grabber", "snatch", "patrol", "bastion", "magnificence"] else (K.pal("coral") if str(e[0]) == "mine" else (K.pal("rock") if str(e[0]) == "asteroid" else K.pal("mint")))
				draw_circle(_map(Vector2(float(e[1]), float(e[2]))), clampf(float(e[3]) * 0.25, 3.0, 14.0), col)
			var sp: Vector2 = _map(Vector2(float(fr.s[0]), float(fr.s[1])))
			var h: float = float(fr.s[2])
			var tip: Vector2 = sp + Vector2.from_angle(h) * 11.0
			var l: Vector2 = sp + Vector2.from_angle(h + 2.5) * 8.0
			var r: Vector2 = sp + Vector2.from_angle(h - 2.5) * 8.0
			draw_colored_polygon(PackedVector2Array([tip, l, r]), K.pal("tangerine"))
			draw_polyline(PackedVector2Array([tip, l, r, tip]), K.pal("white"), 2.0)
		for m in marks:
			if float(m.t) <= t:
				var mp: Vector2 = _map(Vector2(float(m.x), float(m.y)))
				draw_circle(mp, 6.0, K.pal("coral"))
				draw_string(font, mp + Vector2(8, 4), str(m.text), HORIZONTAL_ALIGNMENT_LEFT, 200, 13, Color(1, 1, 1, 0.9))
		draw_string(font, Vector2(8, size.y - 8), "BLACK BOX  %s / %s  (x%.0f)" % [K.fmt_time(minf(t, duration)), K.fmt_time(duration), speed], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))

# ================================================================ Map (captain, staging)
class MapPanel extends Control:
	var nodes: Array = []
	var cur: int = 0
	var visited: Array = []
	var options: Array = []
	var chosen: int = -1
	var t: float = 0.0
	var sel_id: int = -1

	func _init() -> void:
		custom_minimum_size = Vector2(420, 200)

	func setup(m: Dictionary, opts: Array, node: int) -> void:
		nodes = m.get("nodes", [])
		cur = int(m.get("cur", 0))
		visited = m.get("visited", [])
		options = opts
		chosen = node

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _pos(n: Dictionary) -> Vector2:
		var cols: int = 1
		for q in nodes:
			cols = maxi(cols, int(q.col) + 1)
		var x: float = 30.0 + (size.x - 60.0) * float(n.col) / maxf(1.0, float(cols - 1))
		var rows: int = 3
		var y: float = size.y * 0.5 + (float(n.row) - 1.0) * minf(80.0, size.y * 0.3)
		if int(n.col) == 0:
			y = size.y * 0.5
		return Vector2(x, y)

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var ink: Color = K.pal("ink")
		draw_style_box(UIK.sb(K.pal("night"), 14, Color(0, 0, 0, 0), 0, 0), Rect2(Vector2.ZERO, size))
		for n in nodes:
			var p: Vector2 = _pos(n)
			for nid in n.next:
				var q: Vector2 = _pos(nodes[nid])
				var live: bool = int(n.id) == cur and nid in _option_ids()
				draw_line(p, q, K.pal("butter") if live else Color(1, 1, 1, 0.18), 3.0 if live else 1.5)
		for n2 in nodes:
			var p2: Vector2 = _pos(n2)
			var is_cur: bool = int(n2.id) == cur
			var is_opt: bool = int(n2.id) in _option_ids()
			var col: Color = K.pal("plum2")
			var kind: String = str(n2.kind)
			if kind == "dock":
				col = K.pal("mint")
			elif kind.begins_with("fin_"):
				col = K.pal("gold")
			elif kind in ["drones", "pods", "bastion"]:
				col = K.pal("coral")
			elif kind in ["casual", "checkpoint", "photo"]:
				col = K.pal("teal")
			elif kind in ["cake", "ducks", "bees"]:
				col = K.pal("pink")
			var rr: float = 14.0
			if int(n2.id) in visited:
				col = col.darkened(0.5)
			draw_circle(p2, rr + 3.0, ink)
			draw_circle(p2, rr, col)
			if is_opt:
				draw_arc(p2, rr + 8.0 + sin(t * 5.0) * 2.0, 0, TAU, 24, K.pal("butter"), 3.0)
			if int(n2.id) == chosen:
				draw_arc(p2, rr + 14.0, 0, TAU, 24, K.pal("green"), 4.0)
			if is_cur:
				draw_string(font, p2 + Vector2(-8, 6), "★", HORIZONTAL_ALIGNMENT_CENTER, 16, 18, K.pal("white"))
			if is_opt:
				draw_string(UIK.font_bold(), p2 + Vector2(-60, rr + 22), str(n2.name), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 1, 1, 0.95))
				draw_string(UIK.font_head(), p2 + Vector2(-60, rr + 38), str(n2.code), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, K.pal("butter"))

	func _option_ids() -> Array:
		var ids: Array = []
		for o in options:
			ids.append(int(o.id))
		return ids

# ================================================================ builders

static func _frame(title: String, color: String, icon: String) -> Array:
	## a dimmed full-area backdrop with a big centred window. Returns [root, body]
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	UIK.bg_color(root, Color(K.pal("night"), 0.78))
	var w: Array = UIK.window(title, color, icon, 14)
	var p: Control = w[0]
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 40
	p.offset_right = -40
	p.offset_top = 16
	p.offset_bottom = -16
	root.add_child(p)
	return [root, w[1]]

static func award_row(a: Dictionary) -> Control:
	var p: PanelContainer = UIK.panel("well", 8, 14)
	var h: HBoxContainer = UIK.hbox(8)
	p.add_child(h)
	var who: String = str(a.who)
	if who in K.SEATS or who == "dc":
		h.add_child(UIK.portrait(str(K.SEAT_INFO[who].portrait), 48))
	else:
		h.add_child(UIK.badge("star", "yellow", 44))
	var v: VBoxContainer = UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_s: String = K.seat_name(who) if (who in K.SEATS or who == "dc") else ""
	v.add_child(UIK.heading("%s%s" % [a.title, ("  ·  " + name_s) if name_s != "" else ""], 15))
	v.add_child(UIK.wrapped(UIK.label(str(a.desc), 13, K.pal("ink_soft"))))
	return p

static func event_list(events: Array) -> Control:
	var v: VBoxContainer = UIK.vbox(2)
	for e in events:
		var col: Color = K.pal("ink")
		match str(e.kind):
			"bad":
				col = K.pal("red").darkened(0.2)
			"good":
				col = K.pal("green").darkened(0.35)
			"input":
				col = K.pal("navy")
		var who: String = K.seat_name(str(e.who)) if str(e.who) in K.SEATS else str(e.who).capitalize()
		v.add_child(UIK.wrapped(UIK.label("%s  %s: %s" % [K.fmt_time(float(e.t)), who, e.text], 14, col)))
	return v

static func debrief_panel(ph: Dictionary, is_captain: bool, mode: String, on_continue: Callable, on_retry: Callable, on_lobby: Callable) -> Control:
	var d: Dictionary = ph.get("debrief", {})
	var ok: bool = bool(d.get("ok", false))
	var fr: Array = _frame(("MISSION COMPLETE: %s" if ok else "MISSION FAILED: %s") % str(d.get("title", "")), "green" if ok else "red", "check" if ok else "warning")
	var v: VBoxContainer = fr[1]
	var top: HBoxContainer = UIK.hbox(10)
	v.add_child(top)
	if d.has("time"):
		top.add_child(UIK.chip("Time %s  (par %s)" % [K.fmt_time(float(d.time)), K.fmt_time(float(d.get("par", 0.0)))], "blue", "clock"))
		top.add_child(UIK.chip("Damages billed: %d" % int(float(d.get("damages", 0.0))), "orange", "scrap"))
	var spoils: Dictionary = d.get("spoils", {})
	if not spoils.is_empty():
		top.add_child(UIK.chip("+%d scrap" % int(spoils.get("scrap", 0)), "yellow", "scrap"))
	if not ok:
		v.add_child(UIK.wrapped(UIK.heading(str(d.get("reason", "")), 18, K.pal("red").darkened(0.2))))
	var cols: HBoxContainer = UIK.hbox(14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left: VBoxContainer = UIK.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	if is_captain and d.has("trail"):
		var rv: ReplayView = ReplayView.new()
		rv.setup(d)
		rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_child(rv)
	if str(d.get("thrupp", "")) != "":
		left.add_child(UIK.speech(str(d.thrupp), "thrupp", "", 52))
	if d.has("setback"):
		left.add_child(UIK.wrapped(UIK.heading(str(d.setback), 15, K.pal("red"))))
	if d.has("events"):
		left.add_child(UIK.heading("WHAT HAPPENED", 16))
		var sc: ScrollContainer = ScrollContainer.new()
		sc.custom_minimum_size = Vector2(0, 90)
		if not is_captain:
			sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(sc)
		var el: Control = event_list(d.events)
		el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(el)
	var right: VBoxContainer = UIK.vbox(8)
	right.custom_minimum_size = Vector2(380, 0)
	cols.add_child(right)
	right.add_child(UIK.heading("CREW AWARDS", 18))
	var asc: ScrollContainer = ScrollContainer.new()
	asc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(asc)
	var av: VBoxContainer = UIK.vbox(6)
	av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asc.add_child(av)
	for a in d.get("awards", []):
		av.add_child(award_row(a))
	var br: HBoxContainer = UIK.hbox(10)
	v.add_child(br)
	if is_captain:
		br.add_child(UIK.btn("Continue", "green", on_continue, "play"))
		if mode == "shift":
			br.add_child(UIK.btn("Retry", "orange", on_retry, "back"))
			br.add_child(UIK.btn("Back to the Crew Room", "neutral", on_lobby, "crew"))
	else:
		br.add_child(UIK.label("Waiting for the captain to continue...", 16, K.pal("ink_soft")))
	return fr[0]

static func gameover_panel(ph: Dictionary, is_captain: bool, mode: String, on_continue: Callable, on_retry: Callable, on_lobby: Callable) -> Control:
	var d: Dictionary = ph.get("over", {})
	var fr: Array = _frame("HEGEMONY VICTORY BROADCAST", "purple", "temper")
	var v: VBoxContainer = fr[1]
	var h: HBoxContainer = UIK.hbox(14)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var left: VBoxContainer = UIK.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(UIK.speech("Glory is mandatory. Today's glory is brought to you by %s Thrupp. The criminals were apprehended because: %s" % [str(d.get("thrupp", "Admiral")), str(d.get("reason", ""))], "thrupp", "Hegemony News", 80))
	for line in d.get("lines", []):
		left.add_child(UIK.wrapped(UIK.label("• %s" % str(line), 15, K.pal("red").darkened(0.25))))
	if is_captain and d.has("trail"):
		var rv: ReplayView = ReplayView.new()
		rv.setup(d)
		rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_child(rv)
	var right: VBoxContainer = UIK.vbox(6)
	right.custom_minimum_size = Vector2(360, 0)
	h.add_child(right)
	right.add_child(UIK.heading("CREW AWARDS", 18))
	for a in d.get("awards", []):
		right.add_child(award_row(a))
	right.add_child(UIK.speech("Is over. Ship is gone. IGOR has seen worse. Not often. Rarely. Once.", "igor", "", 52))
	if is_captain:
		var br: HBoxContainer = UIK.hbox(10)
		v.add_child(br)
		if mode == "shift":
			br.add_child(UIK.btn("Try again", "orange", on_retry, "back"))
		br.add_child(UIK.btn("Back to the Crew Room", "neutral", on_lobby, "crew"))
	return fr[0]

static func ending_panel(ph: Dictionary, is_captain: bool, on_lobby: Callable) -> Control:
	var d: Dictionary = ph.get("ending", {})
	var fr: Array = _frame("THE END: %s" % str(d.get("title", "")), "yellow", "star")
	var v: VBoxContainer = fr[1]
	var faces: HBoxContainer = UIK.hbox(-12)
	faces.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in ["captain", "helm", "engines", "pudding", "power", "weapons", "sensors", "ops"]:
		faces.add_child(UIK.portrait(p, 84))
	v.add_child(faces)
	v.add_child(UIK.wrapped(UIK.heading(str(d.get("text", "")), 21, K.pal("ink"), 1)))
	var chips: HBoxContainer = UIK.hbox(8)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(chips)
	chips.add_child(UIK.chip("%d jumps" % int(d.get("jumps", 0)), "blue", "map"))
	chips.add_child(UIK.chip("%d scrap" % int(d.get("scrap", 0)), "yellow", "scrap"))
	chips.add_child(UIK.chip("Pudding calm %d%%" % int(100.0 - float(d.get("calm", 50.0))), "pink", "pudding"))
	v.add_child(UIK.speech(str(d.get("thrupp", "")), "thrupp", "", 52))
	v.add_child(UIK.spacer(true))
	v.add_child(UIK.speech("IGOR has enjoyed this. IGOR did not say this. Delete.", "igor", "", 52))
	if is_captain:
		v.add_child(UIK.btn("Back to the Crew Room", "green", on_lobby, "crew"))
	return fr[0]
