class_name EnginesUI
extends Station
## Engines: the throttle and a speedometer. Engines doesn't know where we're going: listen to the captain.
## Later: heat (mission 3), boost (mission 7), and sharing out the reactor's power (mission 8).

var lever: ThrottleLever
var speedo: Gauges.Needle
var thermo: Gauges.Thermo
var lamp_p: Gauges.Lamp
var lamp_s: Gauges.Lamp
var lamp_lbl: Label
var boost_box: VBoxContainer
var boost_btn: BigButton
var pow_box: VBoxContainer
var pips: Dictionary = {}
var draw_bar: Gauges.Bar
var over: Gauges.Bar
var _bars: Dictionary = {"engines": 2, "weapons": 2, "shields": 2}

const GROUPS: Array = [["engines", "Engines", "orange"], ["weapons", "Weapons", "red"], ["shields", "Shields", "purple"]]


func _init() -> void:
	super("engines")

func build() -> void:
	lever = ThrottleLever.new()
	lever.custom_minimum_size = Vector2(290, 420)
	lever.changed.connect(func(v: float): send("throttle", v))
	hero.add_child(lever)
	var col: VBoxContainer = UIK.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(col)
	speedo = Gauges.Needle.new("SPEED", 230)
	col.add_child(speedo)
	var lamps: HBoxContainer = UIK.hbox(10)
	lamps.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(lamps)
	lamp_p = Gauges.Lamp.new(36)
	lamp_s = Gauges.Lamp.new(36)
	lamps.add_child(UIK.head("PORT", 18))
	lamps.add_child(lamp_p)
	lamps.add_child(lamp_s)
	lamps.add_child(UIK.head("STARBOARD", 18))
	lamp_lbl = UIK.para("", 19, UIK.c("red"))
	lamp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lamp_lbl.custom_minimum_size = Vector2(260, 0)
	col.add_child(lamp_lbl)
	thermo = Gauges.Thermo.new("ENGINE HEAT", 300)
	hero.add_child(thermo)
	boost_box = side_window("BOOST", "orange", "engines")
	boost_box.add_child(UIK.para("Hold for a burst of speed. Gets HOT fast, and Pudding hates it.", 19))
	boost_btn = BigButton.new("BOOST", "red", true, 120)
	keyed(boost_btn, KEY_B)
	boost_btn.held.connect(func(on: bool): send("boost", on))
	boost_box.add_child(UIK.center(boost_btn))
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
			b.custom_minimum_size = Vector2(60, 58)
			r.add_child(b)
			btns.append(b)
		var z: Button = UIK.btn("0", "cream", func(): _set_bars(str(g[0]), 0), "", 16)
		z.custom_minimum_size = Vector2(52, 58)
		r.add_child(z)
		pips[g[0]] = btns
	draw_bar = Gauges.Bar.new("mustard", 28)
	draw_bar.marker = 6.0 / 9.0
	pow_box.add_child(draw_bar)
	over = Gauges.Bar.new("red", 28)
	pow_box.add_child(over)
	keys_lbl.text = "Drag the handle, or W / S.   X = all stop.   It stays where you leave it."

func _set_bars(g: String, n: int) -> void:
	_bars[g] = n
	send("power", {"group": g, "bars": n})
	_show_pips()

func _show_pips() -> void:
	for g in pips.keys():
		var btns: Array = pips[g]
		for i in btns.size():
			(btns[i] as Button).set_pressed_no_signal(i < int(_bars.get(g, 0)))

func refresh(v: Dictionary, _com: Dictionary) -> void:
	if not lever._drag:
		lever.set_value(float(v.get("throttle", 0.0)))
	var spd: float = float(v.get("speed", 0.0))
	speedo.set_value(spd / maxf(1.0, float(v.get("max", 70.0))), "%d m/s" % int(spd))
	var heat_on: bool = feat("heat")
	thermo.visible = heat_on
	thermo.set_value(float(v.get("heat", 0.0)) / 100.0)
	lever.red_from = 0.72 if heat_on else -1.0
	lever.queue_redraw()
	var ps: String = str(v.get("port", "ok"))
	var ss: String = str(v.get("star", "ok"))
	lamp_p.set_state("green" if ps == "ok" else "red")
	lamp_s.set_state("green" if ss == "ok" else "red")
	var msg: String = ""
	if ps != "ok" and ss != "ok":
		msg = "BOTH engines are down! Get the Tech to fix them!"
	elif ps != "ok" or ss != "ok":
		msg = "One engine is down: half power, and the ship pulls to one side."
	elif heat_on and float(v.get("heat", 0.0)) > 80.0:
		msg = "TOO HOT! Ease off the throttle!"
	lamp_lbl.text = msg
	boost_box.get_parent().get_parent().visible = feat("boost")
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
	match k:
		KEY_W, KEY_UP:
			if down:
				lever.set_value(lever.value + 0.1, true)
			return true
		KEY_S, KEY_DOWN:
			if down:
				lever.set_value(lever.value - 0.1, true)
			return true
		KEY_X:
			if down:
				lever.set_value(0.0, true)
			return true
		KEY_B:
			if feat("boost"):
				boost_btn.press_key(down)
			return true
	return false
