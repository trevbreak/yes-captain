class_name EnginesUI
extends Station
## Engines: the throttle and a speedometer. Engines doesn't know where we're going: listen to the captain.
## Later: heat (mission 3), boost (mission 7).

var lever: ThrottleLever
var speedo: Gauges.Needle
var thermo: Gauges.Thermo
var lamp_p: Gauges.Lamp
var lamp_s: Gauges.Lamp
var lamp_lbl: Label
var boost_box: VBoxContainer
var boost_btn: BigButton

func _init() -> void:
	super("engines")

func build() -> void:
	lever = ThrottleLever.new()
	lever.custom_minimum_size = Vector2(250, 420)
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
	boost_btn.key_hint = "B"
	boost_btn.held.connect(func(on: bool): send("boost", on))
	boost_box.add_child(UIK.center(boost_btn))
	keys_lbl.text = "Drag the handle, or W / S.   X = all stop.   It stays where you leave it."

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
		msg = "BOTH engines are down! Get the Engineer!"
	elif ps != "ok" or ss != "ok":
		msg = "One engine is down: half power, and the ship pulls to one side."
	elif heat_on and float(v.get("heat", 0.0)) > 80.0:
		msg = "TOO HOT! Ease off the throttle!"
	lamp_lbl.text = msg
	boost_box.get_parent().get_parent().visible = feat("boost")

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
