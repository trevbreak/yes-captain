class_name WeaponsUI
extends Station
## Weapons: a periscope down the barrel, a dial to turn the turret, and FIRE. Weapons can only see a narrow
## slice of space, so the captain has to say where to look. Later: gun heat (3), torpedoes (6).

var scope: Scope
var dial: ClockDial
var fire_btn: BigButton
var thermo: Gauges.Thermo
var torp_box: VBoxContainer
var load_btn: BigButton
var torp_btn: Button
var torp_lbl: Label
var _turn: float = 0.0
var _aim: float = 0.0

func _init() -> void:
	super("weapons")

func build() -> void:
	scope = Scope.new()
	scope.custom_minimum_size = Vector2(430, 430)
	hero.add_child(scope)
	var col: VBoxContainer = UIK.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(col)
	dial = ClockDial.new()
	dial.mode = ClockDial.Mode.TURRET
	dial.accent = UIK.c("red")
	dial.custom_minimum_size = Vector2(250, 250)
	dial.changed.connect(func(v: float):
		_aim = v
		send("aim", v))
	col.add_child(dial)
	col.add_child(UIK.head("TURRET DIRECTION", 18, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER))
	var fr: HBoxContainer = UIK.hbox(22)
	fr.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(fr)
	fire_btn = BigButton.new("FIRE", "red", true, 120)
	fire_btn.key_hint = "Space"
	fire_btn.held.connect(func(on: bool): send("fire", on))
	fr.add_child(fire_btn)
	thermo = Gauges.Thermo.new("HEAT", 140)
	fr.add_child(thermo)
	torp_box = side_window("TORPEDO", "mustard", "torpedo")
	torp_box.add_child(UIK.para("Hold LOAD until it's ready, then fire. Only the weak spot at the BACK of a cruiser takes real damage.", 18))
	var tr: HBoxContainer = UIK.hbox(8)
	tr.alignment = BoxContainer.ALIGNMENT_CENTER
	torp_box.add_child(tr)
	load_btn = BigButton.new("LOAD", "mustard", true, 96)
	load_btn.key_hint = "L"
	load_btn.held.connect(func(on: bool): send("load", on))
	tr.add_child(load_btn)
	torp_btn = UIK.btn("FIRE TORPEDO", "red", func(): send("torpedo", true), "torpedo", 20)
	torp_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(torp_btn)
	torp_lbl = UIK.label("", 20)
	torp_box.add_child(torp_lbl)
	keys_lbl.text = "Drag the turret dial, or hold A / D.   Hold SPACE (or the button) to fire."

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	var d: float = (1.0 if held(KEY_D) or held(KEY_RIGHT) else 0.0) - (1.0 if held(KEY_A) or held(KEY_LEFT) else 0.0)
	if d != 0.0:
		_aim = wrapf(_aim + d * 1.6 * dt, -PI, PI)
		dial.set_value(_aim)
		_turn += dt
		if _turn > 0.05:
			_turn = 0.0
			send("aim", _aim)

func refresh(v: Dictionary, _com: Dictionary) -> void:
	var gun_ok: bool = str(v.get("gun", "ok")) == "ok"
	if not dial._drag and not (held(KEY_A) or held(KEY_D) or held(KEY_LEFT) or held(KEY_RIGHT)):
		_aim = float(v.get("aim", 0.0))
		dial.set_value(_aim)
	dial.broken = not gun_ok
	scope.view = v
	scope.aim = _aim
	scope.firing = bool(v.get("firing", false))
	scope.gun_ok = gun_ok
	fire_btn.set_disabled(not gun_ok)
	thermo.visible = feat("heat")
	thermo.set_value(float(v.get("heat", 0.0)) / 100.0)
	torp_box.get_parent().get_parent().visible = feat("torpedo")
	var t: String = str(v.get("torp", "empty"))
	load_btn.set_progress(float(v.get("torp_load", 0.0)) if t != "empty" else -1.0)
	torp_btn.disabled = t != "ready" or not gun_ok
	torp_lbl.text = {"empty": "Tube empty", "loading": "Loading...", "ready": "READY TO FIRE!"}.get(t, t)

func on_key(k: Key, down: bool) -> bool:
	match k:
		KEY_SPACE:
			fire_btn.press_key(down)
			return true
		KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT:
			if not down:
				send("aim", _aim)
			return true
		KEY_L:
			if feat("torpedo"):
				load_btn.press_key(down)
			return true
		KEY_T:
			if down and feat("torpedo"):
				send("torpedo", true)
			return true
	return false
