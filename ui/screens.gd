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
		custom_minimum_size = Vector2(440, 230)
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
		custom_minimum_size = Vector2(700, 215)

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
		var x: float = 50.0 + (size.x - 100.0) * float(n.col) / maxf(1.0, float(cols - 1))
		var rows: int = 3
		var y: float = size.y * 0.5 + (float(n.row) - (1.0 if int(n.col) > 0 and int(n.col) < cols - 1 and false else 1.0)) * 80.0
		if int(n.col) == 0:
			y = size.y * 0.5
		return Vector2(x, y)

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var ink: Color = K.pal("ink")
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.08, 0.22), true)
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
			var rr: float = 17.0
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
				draw_string(font, p2 + Vector2(-60, rr + 22), str(n2.name), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 1, 1, 0.95))
				draw_string(font, p2 + Vector2(-60, rr + 36), str(n2.code), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, K.pal("butter"))

	func _option_ids() -> Array:
		var ids: Array = []
		for o in options:
			ids.append(int(o.id))
		return ids

# ================================================================ builders

static func award_row(a: Dictionary) -> Control:
	var p: PanelContainer = UIK.panel("butter", 6, 12)
	var v: VBoxContainer = UIK.vbox(0)
	p.add_child(v)
	var who: String = K.seat_name(str(a.who)) if str(a.who) in K.SEATS else ("Damage Control" if str(a.who) == "dc" else "")
	v.add_child(UIK.label("🏆 %s%s" % [a.title, (" – " + who) if who != "" else ""], 17))
	var d: Label = UIK.label(str(a.desc), 14, Color(K.pal("ink"), 0.8))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return p

static func event_list(events: Array) -> Control:
	var v: VBoxContainer = UIK.vbox(2)
	for e in events:
		var col: Color = K.pal("ink")
		match str(e.kind):
			"bad":
				col = K.pal("coral").darkened(0.2)
			"good":
				col = Color(0.15, 0.5, 0.25)
			"input":
				col = K.pal("plum2")
		var who: String = K.seat_name(str(e.who)) if str(e.who) in K.SEATS else str(e.who).capitalize()
		var l: Label = UIK.label("%s  %s: %s" % [K.fmt_time(float(e.t)), who, e.text], 14, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v

static func debrief_panel(ph: Dictionary, is_captain: bool, mode: String, on_continue: Callable, on_retry: Callable, on_lobby: Callable) -> Control:
	var d: Dictionary = ph.get("debrief", {})
	var root: PanelContainer = UIK.panel("cream", 14, 24)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 50
	root.offset_right = -50
	root.offset_top = 40
	root.offset_bottom = -132
	var v: VBoxContainer = UIK.vbox(8)
	root.add_child(v)
	var ok: bool = bool(d.get("ok", false))
	var head: Label = UIK.label(("%s: COMPLETE!" if ok else "%s: FAILED") % str(d.get("title", "Encounter")), 30, K.pal("green").darkened(0.3) if ok else K.pal("coral").darkened(0.1))
	v.add_child(head)
	if not ok:
		v.add_child(UIK.label(str(d.get("reason", "")), 18))
	var sub: String = ""
	if d.has("time"):
		sub = "Time %s (par %s)   Damages billed: %d" % [K.fmt_time(float(d.time)), K.fmt_time(float(d.get("par", 0.0))), int(float(d.get("damages", 0.0)))]
	v.add_child(UIK.label(sub, 17))
	if d.has("thrupp"):
		v.add_child(UIK.label(str(d.thrupp), 16, K.pal("magenta")))
	if d.has("setback"):
		v.add_child(UIK.label(str(d.setback), 16, K.pal("coral")))
	var cols: HBoxContainer = UIK.hbox(14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left: VBoxContainer = UIK.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	if is_captain and d.has("trail"):
		var rv: ReplayView = ReplayView.new()
		rv.setup(d)
		left.add_child(rv)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(300, 70)
	left.add_child(sc)
	if is_captain and d.has("events"):
		var el: Control = event_list(d.events)
		el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(el)
	var right: VBoxContainer = UIK.vbox(6)
	right.custom_minimum_size = Vector2(340, 0)
	cols.add_child(right)
	right.add_child(UIK.label("CREW AWARDS", 18))
	for a in d.get("awards", []):
		right.add_child(award_row(a))
	var spoils: Dictionary = d.get("spoils", {})
	if not spoils.is_empty():
		right.add_child(UIK.label("Spoils: %d scrap%s" % [int(spoils.get("scrap", 0)), ", +snacks" if int(spoils.get("snacks", 0)) > 0 else ""], 15))
	if is_captain:
		var br: HBoxContainer = UIK.hbox(10)
		v.add_child(br)
		br.add_child(UIK.btn("CONTINUE  ►", "green", on_continue))
		if mode == "shift":
			br.add_child(UIK.btn("RETRY", "tangerine", on_retry))
			br.add_child(UIK.btn("BACK TO LOBBY", "cream2", on_lobby))
	else:
		v.add_child(UIK.label("Waiting for the captain to continue...", 16, Color(K.pal("ink"), 0.7)))
	return root

static func gameover_panel(ph: Dictionary, is_captain: bool, mode: String, on_continue: Callable, on_retry: Callable, on_lobby: Callable) -> Control:
	var d: Dictionary = ph.get("over", {})
	var root: PanelContainer = UIK.panel("plum2", 14, 24)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 80
	root.offset_right = -80
	root.offset_top = 50
	root.offset_bottom = -132
	var v: VBoxContainer = UIK.vbox(8)
	root.add_child(v)
	var cw: Color = K.pal("cream")
	v.add_child(UIK.label("HEGEMONY VICTORY BROADCAST", 30, K.pal("gold")))
	v.add_child(UIK.label("\"Glory is mandatory. Today's glory is brought to you by %s Thrupp.\"" % str(d.get("thrupp", "Admiral")), 18, cw))
	var why: Label = UIK.label("The criminals were apprehended after the following events: %s" % str(d.get("reason", "")), 17, cw)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	for line in d.get("lines", []):
		var l: Label = UIK.label("• %s" % str(line), 16, K.pal("pink"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	if is_captain and d.has("trail"):
		var rv: ReplayView = ReplayView.new()
		rv.setup(d)
		rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(rv)
	var aw: HBoxContainer = UIK.hbox(8)
	v.add_child(aw)
	for a in d.get("awards", []):
		aw.add_child(award_row(a))
	v.add_child(UIK.label("IGOR: \"Is over. Ship is gone. IGOR has seen worse. Not often. Rarely. Once.\"", 16, K.pal("mint")))
	if is_captain:
		var br: HBoxContainer = UIK.hbox(10)
		v.add_child(br)
		if mode == "shift":
			br.add_child(UIK.btn("TRY AGAIN", "tangerine", on_retry))
		br.add_child(UIK.btn("BACK TO LOBBY", "cream2", on_lobby))
	return root

static func ending_panel(ph: Dictionary, is_captain: bool, on_lobby: Callable) -> Control:
	var d: Dictionary = ph.get("ending", {})
	var root: PanelContainer = UIK.panel("butter", 16, 26)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 100
	root.offset_right = -100
	root.offset_top = 60
	root.offset_bottom = -132
	var v: VBoxContainer = UIK.vbox(12)
	root.add_child(v)
	v.add_child(UIK.label("ENDING: %s" % str(d.get("title", "")), 36, K.pal("magenta")))
	var t: Label = UIK.label(str(d.get("text", "")), 22)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	v.add_child(UIK.label(str(d.get("thrupp", "")), 18, K.pal("plum2")))
	v.add_child(UIK.label("Jumps: %d    Scrap: %d    Pudding's average calm: %d%%" % [int(d.get("jumps", 0)), int(d.get("scrap", 0)), int(100.0 - float(d.get("calm", 50.0)))], 17))
	v.add_child(UIK.spacer(true))
	v.add_child(UIK.label("IGOR: \"IGOR has enjoyed this. IGOR did not say this. Delete.\"", 18, K.pal("teal").darkened(0.3)))
	if is_captain:
		v.add_child(UIK.btn("BACK TO LOBBY", "green", on_lobby))
	return root
