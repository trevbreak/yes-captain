class_name ShieldsUI
extends Station
## Shields: point the shield at the danger. Shields can't see what's coming, only where it hit.
## Later: the tractor beam (mission 2) and looking after Pudding (mission 4).

var dial: ClockDial
var status: Label
var tr_box: VBoxContainer
var tr_btn: BigButton
var tr_lbl: Label
var pud_box: VBoxContainer
var pud_pic: TextureRect
var mood: Gauges.Bar
var pet_btn: BigButton
var snack_btn: Button
var tin_btn: BigButton
var pud_lbl: Label
var _dir: float = 0.0
var _turn: float = 0.0

func _init() -> void:
	super("shields")

func build() -> void:
	dial = ClockDial.new()
	dial.mode = ClockDial.Mode.SHIELD
	dial.accent = UIK.c("purple")
	dial.custom_minimum_size = Vector2(470, 470)
	dial.changed.connect(func(v: float):
		_dir = v
		send("dir", v))
	hero.add_child(dial)
	var col: VBoxContainer = UIK.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(220, 0)
	hero.add_child(col)
	col.add_child(UIK.head("12 = our nose", 20))
	col.add_child(UIK.para("The captain calls the clock: \"incoming at 3 o'clock!\" Turn the purple shield to face it.", 19))
	status = UIK.para("", 20, UIK.c("red"))
	col.add_child(status)
	# the tractor beam lives on the console, beside the dial
	tr_box = UIK.vbox(6)
	col.add_child(UIK.spacer(false, Vector2(0, 10)))
	col.add_child(tr_box)
	tr_box.add_child(UIK.ribbon("TRACTOR BEAM", "lilac", "tractor", 17))
	var th: HBoxContainer = UIK.hbox(8)
	tr_box.add_child(th)
	tr_btn = BigButton.new("PULL", "purple", true, 74)
	tr_btn.key_hint = "T"
	tr_btn.held.connect(func(on: bool): send("tractor", on))
	th.add_child(tr_btn)
	tr_lbl = UIK.para("", 18)
	tr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tr_lbl)
	pud_box = side_window("PUDDING", "pink", "pudding")
	var ph: HBoxContainer = UIK.hbox(8)
	pud_box.add_child(ph)
	pud_pic = UIK.portrait("pudding", 56)
	ph.add_child(pud_pic)
	var pv: VBoxContainer = UIK.vbox(4)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pv)
	mood = Gauges.Bar.new("pink", 30)
	pv.add_child(mood)
	pud_lbl = UIK.para("", 18)
	pv.add_child(pud_lbl)
	var pr: HBoxContainer = UIK.hbox(6)
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pud_box.add_child(pr)
	pet_btn = BigButton.new("PET", "purple", true, 70)
	pet_btn.key_hint = "P"
	pet_btn.held.connect(func(on: bool): send("pet", on))
	pr.add_child(pet_btn)
	tin_btn = BigButton.new("SHAKE TIN", "mustard", true, 70)
	tin_btn.key_hint = "C"
	tin_btn.held.connect(func(on: bool): send("tin", on))
	pr.add_child(tin_btn)
	snack_btn = UIK.btn("Snack", "pink", func(): send("snack", true), "pudding", 16)
	snack_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(snack_btn)
	keys_lbl.text = "Drag the shield round the dial, or hold A / D.   It stays where you leave it."

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	var d: float = (1.0 if held(KEY_D) or held(KEY_RIGHT) else 0.0) - (1.0 if held(KEY_A) or held(KEY_LEFT) else 0.0)
	if d != 0.0:
		_dir = wrapf(_dir + d * 2.4 * dt, -PI, PI)
		dial.set_value(_dir)
		_turn += dt
		if _turn > 0.05:
			_turn = 0.0
			send("dir", _dir)

func refresh(v: Dictionary, _com: Dictionary) -> void:
	if not dial._drag and not (held(KEY_A) or held(KEY_D) or held(KEY_LEFT) or held(KEY_RIGHT)):
		_dir = float(v.get("dir", 0.0))
		dial.set_value(_dir)
	dial.broken = not bool(v.get("ok", true))
	dial.hits = v.get("hits", [])
	dial.stuck = v.get("stuck", [])
	dial.queue_redraw()
	status.text = "Shield is BROKEN! Ask the Engineer!" if not bool(v.get("ok", true)) else ("Something is STUCK to us! Point the shield at it." if not dial.stuck.is_empty() else "")
	tr_box.visible = feat("tractor")
	var tr: Dictionary = v.get("tractor", {})
	if not tr.is_empty():
		var d: float = float(tr.get("dist", -1.0))
		if not bool(tr.get("ok", true)):
			tr_lbl.text = "Tractor beam is BROKEN."
		elif d < 0.0:
			tr_lbl.text = "Nothing to grab."
		elif d <= float(tr.get("range", 150.0)):
			tr_lbl.text = "%s IN RANGE (%dm). Hold TRACTOR!" % [str(tr.nearest), int(d)]
		else:
			tr_lbl.text = "%s is %dm away. Range is %dm: get closer." % [str(tr.nearest), int(d), int(tr.get("range", 150.0))]
		tr_btn.set_disabled(not bool(tr.get("ok", true)))
	pud_box.get_parent().get_parent().visible = feat("pudding")
	var p: Dictionary = v.get("pudding", {})
	if not p.is_empty():
		var m: float = float(p.get("mood", 50.0))
		var out: bool = bool(p.get("out", false))
		mood.set_value(m / 100.0, "ESCAPED!" if out else "mood %d%%" % int(m))
		mood.set_colour(UIK.c("red") if m < 30.0 else UIK.c("pink"))
		pud_lbl.text = "Pudding is loose! Hold SHAKE TIN to call it back." if out else ("Happy." if m > 70.0 else ("Nervous..." if m > 30.0 else "Upset! Pet it!"))
		pet_btn.set_disabled(out)
		tin_btn.visible = out
		pet_btn.visible = not out
		tin_btn.set_progress(float(p.get("tin", 0.0)) if out else -1.0)
		snack_btn.text = "Snack (%d left)" % int(p.get("snacks", 0))
		snack_btn.disabled = int(p.get("snacks", 0)) <= 0 or out

func on_key(k: Key, down: bool) -> bool:
	match k:
		KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT:
			if not down:
				send("dir", _dir)
			return true
		KEY_T:
			if feat("tractor"):
				tr_btn.press_key(down)
			return true
		KEY_P:
			if feat("pudding"):
				pet_btn.press_key(down)
			return true
		KEY_C:
			if feat("pudding"):
				tin_btn.press_key(down)
			return true
		KEY_N:
			if down and feat("pudding"):
				send("snack", true)
			return true
	return false
