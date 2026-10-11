class_name EngineerUI
extends Station
## Engineer: the ship's cutaway with every bit of damage on it. Click a room, hold REPAIR. Fires first!
## Later: sharing out the reactor's power, and keeping it from overloading (mission 8).

var cut: Cutaway
var rep_btn: BigButton
var sel_lbl: Label
var pow_box: VBoxContainer
var pips: Dictionary = {}
var draw_bar: Gauges.Bar
var over: Gauges.Bar
var _bars: Dictionary = {"engines": 2, "weapons": 2, "shields": 2}
var _sel: String = ""

const GROUPS: Array = [["engines", "Engines", "orange"], ["weapons", "Weapons", "red"], ["shields", "Shields", "purple"]]

func _init() -> void:
	super("engineer")

func build() -> void:
	hero.add_theme_constant_override("separation", 10)
	var col: VBoxContainer = UIK.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(col)
	cut = Cutaway.new()
	cut.clickable = true
	cut.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cut.custom_minimum_size = Vector2(560, 330)
	cut.room_clicked.connect(func(id: String):
		_sel = id
		send("select", id))
	col.add_child(cut)
	var row: HBoxContainer = UIK.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	sel_lbl = UIK.para("Click a room on the ship.", 22)
	sel_lbl.custom_minimum_size = Vector2(330, 0)
	row.add_child(sel_lbl)
	rep_btn = BigButton.new("REPAIR", "green", true, 110)
	rep_btn.key_hint = "Space"
	rep_btn.held.connect(func(on: bool): send("repair", on))
	row.add_child(rep_btn)
	pow_box = side_window("POWER", "mustard", "bolt")
	for g in GROUPS:
		var r: HBoxContainer = UIK.hbox(6)
		pow_box.add_child(r)
		var l: Label = UIK.head(str(g[1]), 19)
		l.custom_minimum_size = Vector2(96, 0)
		r.add_child(l)
		var btns: Array = []
		for i in 3:
			var b: Button = UIK.toggle("", str(g[2]), func(_on: bool): _set_bars(str(g[0]), i + 1), "", 16)
			b.custom_minimum_size = Vector2(44, 38)
			r.add_child(b)
			btns.append(b)
		var z: Button = UIK.btn("0", "cream", func(): _set_bars(str(g[0]), 0), "", 16)
		z.custom_minimum_size = Vector2(36, 40)
		r.add_child(z)
		pips[g[0]] = btns
	draw_bar = Gauges.Bar.new("mustard", 28)
	draw_bar.marker = 6.0 / 9.0
	pow_box.add_child(draw_bar)
	over = Gauges.Bar.new("red", 28)
	pow_box.add_child(over)
	keys_lbl.text = "Click a room, then hold SPACE (or REPAIR).   Fires spread: put them out first!"

func _set_bars(g: String, n: int) -> void:
	_bars[g] = n
	send("power", {"group": g, "bars": n})
	_show_pips()

func _show_pips() -> void:
	for g in pips.keys():
		var btns: Array = pips[g]
		for i in btns.size():
			(btns[i] as Button).set_pressed_no_signal(i < int(_bars.get(g, 0)))

func refresh(v: Dictionary, com: Dictionary) -> void:
	cut.systems = v.get("systems", {})
	_sel = str(v.get("selected", ""))
	cut.selected = _sel
	cut.prog = float(v.get("prog", 0.0))
	cut.repairing = bool(v.get("repairing", false))
	cut.pudding_room = str(v.get("pudding_room", ""))
	cut.features = features
	cut.blackout = bool(com.get("blackout", false))
	cut.stuck = v.get("stuck_rel", [])
	if _sel == "":
		var n: int = 0
		for id in cut.systems.keys():
			if str(cut.systems[id].state) != "ok":
				n += 1
		sel_lbl.text = "All shipshape. Wait for trouble." if n == 0 else "%d thing%s broken! Click one." % [n, "" if n == 1 else "s"]
	else:
		var st: Dictionary = cut.systems.get(_sel, {})
		var nm: String = str(Ship.SYS_NAME.get(_sel, _sel))
		match str(st.get("state", "ok")):
			"fire":
				sel_lbl.text = "%s is ON FIRE! Hold to put it out." % nm
			"broken":
				sel_lbl.text = "%s is broken. Hold REPAIR." % nm
			_:
				sel_lbl.text = "%s is fine." % nm if float(st.get("hp", 100.0)) >= 100.0 else "%s is dented (%d%%). Hold to patch it." % [nm, int(st.hp)]
	rep_btn.set_progress(float(v.get("prog", 0.0)) if bool(v.get("repairing", false)) else -1.0)
	pow_box.get_parent().get_parent().visible = feat("power")
	var pw: Dictionary = v.get("power", {})
	if not pw.is_empty():
		var bars: Dictionary = pw.get("bars", {})
		for g in bars.keys():
			_bars[g] = int(bars[g])
		_show_pips()
		var dr: float = float(pw.get("draw", 0.0))
		draw_bar.set_value(dr / 9.0, "DRAW %.1f / %d" % [dr, int(pw.get("cap", 6))])
		draw_bar.set_colour(UIK.c("red") if dr > float(pw.get("cap", 6)) else UIK.c("mustard"))
		var ov: float = float(pw.get("overload", 0.0))
		over.set_value(ov / 100.0, "BLACKOUT!" if float(pw.get("blackout", 0.0)) > 0.0 else "OVERLOAD %d%%" % int(ov))

func on_key(k: Key, down: bool) -> bool:
	if k == KEY_SPACE:
		rep_btn.press_key(down)
		return true
	return false
