class_name EngineerUI
extends Station
## Engineer: the ship's cutaway with every bit of damage on it. Click a room, hold REPAIR. Fires first!
## (The reactor's power bars are the Stoker's, on the Engines screen.)

var cut: Cutaway
var rep_btn: BigButton
var sel_lbl: Label
var man_name: Label
var man_who: Face
var man_state: PanelContainer
var _sel: String = ""


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
	cut.custom_minimum_size = Vector2(480, 230)
	cut.room_clicked.connect(func(id: String):
		_sel = id
		send("select", id))
	col.add_child(cut)
	var row: HBoxContainer = UIK.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	# what's wrong with the room you clicked; for a glitch, this is IGOR's manual
	man_who = UIK.portrait("helm", 74)
	man_who.visible = false
	man_who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(man_who)
	var sv: VBoxContainer = UIK.vbox(2)
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(sv)
	man_name = UIK.head("", 19, UIK.c("purple").darkened(0.2))
	man_name.visible = false
	sv.add_child(man_name)
	sel_lbl = UIK.para("Click a room on the ship.", 22)
	sel_lbl.custom_minimum_size = Vector2(380, 0)
	sv.add_child(sel_lbl)
	man_state = UIK.chip("READ THIS OUT LOUD", "mustard", "", 15)
	man_state.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	man_state.visible = false
	sv.add_child(man_state)
	rep_btn = BigButton.new("REPAIR", "green", true, 110)
	keyed(rep_btn, KEY_R)
	rep_btn.held.connect(func(on: bool): send("repair", on))
	row.add_child(rep_btn)
	keys_lbl.text = "Click a room, then hold R (or REPAIR).   Fires spread: put them out first!"

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
	var gl: Dictionary = v.get("glitches", {})
	cut.glitch_rooms = gl.keys()
	var mine: Dictionary = gl.get(_sel, {})
	var sel_ok: bool = str(cut.systems.get(_sel, {}).get("state", "ok")) == "ok"
	var manual: bool = not mine.is_empty() and sel_ok
	man_who.visible = manual
	man_name.visible = manual
	man_state.visible = manual
	if manual:
		man_name.text = "IGOR'S MANUAL: %s" % str(mine.name)
		man_who.set_who(str(mine.who))
		UIK.set_chip(man_state, "THAT'S IT! KEEP HOLDING REPAIR" if bool(mine.met) else "READ THIS OUT LOUD", "green" if bool(mine.met) else "mustard")
	if _sel == "":
		var n: int = 0
		for id in cut.systems.keys():
			if str(cut.systems[id].state) != "ok":
				n += 1
		if n == 0 and not gl.is_empty():
			sel_lbl.text = "Something's glitching! Click a room marked ?! to see IGOR's manual."
		else:
			sel_lbl.text = "All shipshape. Patch any dents while it's quiet." if n == 0 else "%d thing%s broken! Click one." % [n, "" if n == 1 else "s"]
	else:
		var st: Dictionary = cut.systems.get(_sel, {})
		var nm: String = str(Ship.SYS_NAME.get(_sel, _sel))
		match str(st.get("state", "ok")):
			"fire":
				sel_lbl.text = "%s is ON FIRE! Hold to put it out." % nm
			"broken":
				sel_lbl.text = "%s is broken. Hold REPAIR." % nm
			_:
				if not mine.is_empty():
					sel_lbl.text = "Hold REPAIR while %s." % str(mine.ask)
				else:
					sel_lbl.text = "%s is fine." % nm if float(st.get("hp", 100.0)) >= 100.0 else "%s is dented (%d%%). Hold to patch it." % [nm, int(st.hp)]
		var tip: String = str(v.get("rest_tip", ""))
		if str(st.get("state", "ok")) == "broken" and tip != "":
			sel_lbl.text += "\n" + ("Nobody's using it: fixing at double speed!" if bool(v.get("resting", false)) else tip)
	rep_btn.set_progress(float(v.get("prog", 0.0)) if bool(v.get("repairing", false)) else -1.0)
func on_key(k: Key, down: bool) -> bool:
	if k == KEY_R:
		rep_btn.press_key(down)
		return true
	return false
