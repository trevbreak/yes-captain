extends Control
## Mock-ups of the combined two-station screen, built from the real stations and widgets fed by a real
## simulated ship, for comparing layouts. Render with tools/shot.gd:
##   godot --path . --resolution 1600x720 --script tools/shot.gd -- --ui=res://tools/pair_mock.gd --pair=pilot --v=side --out=x.png
## --v: side | stack | compact      --pair: driver | stoker | tech   (role desks: tools/role_mock.gd)

var w: World
var pair: Dictionary
var v: String = "side"
var stations: Array = []

func _ready() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	v = str(args.get("v", "side"))
	var rid: String = str(args.get("pair", "driver"))
	if not K.ROLES.has(rid):
		rid = "driver"
	pair = {"id": rid, "name": K.ROLES[rid].name, "seats": K.ROLES[rid].seats}
	_make_world()
	UIK.bg(self)
	var root: VBoxContainer = UIK.vbox(8)
	var m: MarginContainer = UIK.margin(root, 10)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	root.add_child(_top())
	var body: Control
	body = _two()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	root.add_child(_dock())
	_feed.call_deferred()

func _make_world() -> void:
	w = World.new(7)
	var mi: Mission = Missions.make("haven")
	mi.setup(w)
	w.features = Missions.features_upto(10)
	for k in Deck.HARD_ONLY:
		w.features.erase(k)
	var bots: Array = []
	for st in K.STATIONS:
		bots.append(Bot.new(st))
	for i in 240:
		for b in bots:
			b.tick(w, K.DT)
		w.step(K.DT)
	w.ship.throttle = 0.62
	w.ship.wheel = -1.0
	w.break_system("tractor", "test", false)

func _seats() -> Array:
	return pair.seats

func _view(st: String) -> Dictionary:
	match st:
		"helm":
			return Snapshots.helm(w)
		"engines":
			return Snapshots.engines(w)
		"weapons":
			return Snapshots.weapons(w)
		"sensors":
			return Snapshots.sensors(w)
		"shields":
			return Snapshots.shields(w)
	return Snapshots.engineer(w)

func _com(st: String) -> Dictionary:
	return Snapshots.common(w, st)

func _feed() -> void:
	for s in stations:
		var st: Station = s
		st.apply(_view(st.seat), _com(st.seat))
		if v == "compact":
			st.set_compact(true)

# ---------------------------------------------------------------- the shell

func _top() -> Control:
	var top: HBoxContainer = UIK.hbox(12)
	top.custom_minimum_size = Vector2(0, 58)
	top.add_child(UIK.portrait(str(_seats()[0]), 56))
	var tv: VBoxContainer = UIK.vbox(-6)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tv)
	tv.add_child(UIK.head(str(pair.name).to_upper(), 27, K.seat_color(str(_seats()[0])).darkened(0.2)))
	tv.add_child(UIK.label("Trev: %s and %s" % [K.seat_name(str(_seats()[0])), K.seat_name(str(_seats()[1]))], 19, K.pal("ink_soft")))
	top.add_child(UIK.spacer(true))
	var mp: PanelContainer = UIK.panel("panel_small", [10, 0, 10, 0])
	mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mp.add_child(UIK.head("JOB 1 OF 3: HOT SOUP RUN", 22))
	top.add_child(mp)
	top.add_child(UIK.spacer(true))
	var hull: PanelContainer = UIK.chip("HULL 100%", "red", "heart", 20)
	hull.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hull)
	return top

func _dock() -> Control:
	var ib: PanelContainer = UIK.panel("panel_small", [0, -10, 0, -12])
	ib.custom_minimum_size = Vector2(0, 60)
	var ih: HBoxContainer = UIK.hbox(10)
	ib.add_child(ih)
	ih.add_child(UIK.portrait("igor", 46))
	var t: Label = UIK.para("IGOR is watching. IGOR is always watching.", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(t)
	return ib

func _hints() -> Control:
	## one strip with both "your job now" lines, instead of a panel per half
	var h: HBoxContainer = UIK.hbox(10)
	for st in _seats():
		var p: PanelContainer = UIK.panel("panel_small", [4, 0, 4, 0])
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var r: HBoxContainer = UIK.hbox(8)
		p.add_child(r)
		r.add_child(UIK.chip(K.seat_name(str(st)).to_upper(), str(K.SEAT_INFO[st].color), str(K.SEAT_INFO[st].icon), 15))
		var l: Label = UIK.para(_short(str(_com(str(st)).hint)), 17)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.max_lines_visible = 2
		r.add_child(l)
		h.add_child(p)
	return h

static func _short(t: String) -> String:
	return t if t.length() < 90 else t.left(88) + "…"

func _fit(c: Control) -> FitBox:
	var fb: FitBox = FitBox.new()
	fb.add_child(c)
	return fb

func _station(st: String) -> Station:
	var ui: Station
	match st:
		"helm":
			ui = HelmUI.new()
		"engines":
			ui = EnginesUI.new()
		"weapons":
			ui = WeaponsUI.new()
		"sensors":
			ui = SensorsUI.new()
		"shields":
			ui = ShieldsUI.new()
		_:
			ui = EngineerUI.new()
	stations.append(ui)
	return ui

# ---------------------------------------------------------------- A / B / C: two real stations

func _two() -> Control:
	var col: VBoxContainer = UIK.vbox(8)
	if v == "compact":
		col.add_child(_hints())
	var box: BoxContainer = BoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# compact picks its direction from the screen: side by side when wide, stacked when tall
	box.vertical = v == "stack" or (v == "compact" and get_viewport_rect().size.y > get_viewport_rect().size.x)
	col.add_child(box)
	for st in _seats():
		box.add_child(_fit(_station(str(st))))
	return col
