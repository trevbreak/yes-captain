class_name HelmUI
extends StationUI

var compass: Compass
var yaw_lever: Lever
var strafe_lever: Lever
var trim_lever: Lever
var info: Label
var wp_lbl: Label
var auth_l: BarGauge
var auth_r: BarGauge
var drift_bar: BarGauge
var roll_btn: SafetyBtn
var code_edit: LineEdit
var codes_lbl: Label
var key_yaw: float = 0.0
var key_strafe: float = 0.0

func build() -> void:
	var h: HBoxContainer = UIK.hbox(12)
	add_body(h)
	var cw: Array = UIK.window("COMPASS", "helm", "helm", 10)
	h.add_child(cw[0])
	compass = Compass.new()
	compass.accent = accent
	compass.custom_minimum_size = Vector2(290, 290)
	(cw[1] as VBoxContainer).add_child(compass)
	wp_lbl = UIK.wrapped(UIK.heading("", 17, K.pal("green").darkened(0.35), 1))
	(cw[1] as VBoxContainer).add_child(wp_lbl)
	info = UIK.label("", 15, K.pal("ink_soft"), 1)
	(cw[1] as VBoxContainer).add_child(info)
	var mid: VBoxContainer = UIK.vbox(12)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	var sw: Array = UIK.window("STEERING   (A / D to turn, Q / E to strafe)", "blue", "helm", 12)
	mid.add_child(sw[0])
	yaw_lever = Lever.new("TURN", -1.0, 1.0, accent, true)
	yaw_lever.spring = true
	yaw_lever.changed.connect(func(v: float): send("yaw", v))
	(sw[1] as VBoxContainer).add_child(_labelled(yaw_lever, "PORT", "STARBOARD"))
	strafe_lever = Lever.new("STRAFE", -1.0, 1.0, K.pal("sensors"), true)
	strafe_lever.spring = true
	strafe_lever.changed.connect(func(v: float): send("strafe", v))
	(sw[1] as VBoxContainer).add_child(_labelled(strafe_lever, "PORT", "STARBOARD"))
	roll_btn = SafetyBtn.new("EMERGENCY ROLL", "red")
	roll_btn.fired.connect(func(): send("roll", 1.0 if yaw_lever.value >= 0.0 else -1.0))
	(sw[1] as VBoxContainer).add_child(roll_btn)
	var pw: Array = UIK.window("TURNING POWER", "neutral", "power", 12)
	mid.add_child(pw[0])
	var g: GridContainer = UIK.grid(2, 10, 6)
	(pw[1] as VBoxContainer).add_child(g)
	g.add_child(UIK.label("To port", 15))
	auth_l = BarGauge.new("", 1.0, accent)
	auth_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(auth_l)
	g.add_child(UIK.label("To starboard", 15))
	auth_r = BarGauge.new("", 1.0, accent)
	auth_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(auth_r)
	(pw[1] as VBoxContainer).add_child(UIK.wrapped(UIK.label("Uneven bars mean a thruster is broken: you'll turn one way much faster than the other.", 13, K.pal("ink_soft"))))
	var tw: Array = UIK.window("TRIM", "yellow", "", 8)
	(tw[0] as Control).custom_minimum_size = Vector2(120, 0)
	h.add_child(tw[0])
	trim_lever = Lever.new("", -1.0, 1.0, K.pal("yellow"))
	trim_lever.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trim_lever.custom_minimum_size = Vector2(90, 220)
	trim_lever.changed.connect(func(v: float): send("trim", v))
	(tw[1] as VBoxContainer).add_child(trim_lever)
	(tw[1] as VBoxContainer).add_child(UIK.label("drift", 13, K.pal("ink_soft"), 1))
	drift_bar = BarGauge.new("", 1.0, K.pal("orange"))
	drift_bar.vmin = -1.0
	drift_bar.custom_minimum_size = Vector2(90, 22)
	(tw[1] as VBoxContainer).add_child(drift_bar)

func _labelled(lever: Lever, left: String, right: String) -> Control:
	var v: VBoxContainer = UIK.vbox(0)
	var r: HBoxContainer = UIK.hbox(0)
	r.add_child(UIK.label("◄ " + left, 13, K.pal("ink_soft")))
	r.add_child(UIK.spacer(true))
	r.add_child(UIK.label(right + " ►", 13, K.pal("ink_soft")))
	v.add_child(r)
	lever.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(lever)
	return v

func _build_ritual_extra() -> Control:
	var v: VBoxContainer = UIK.vbox(6)
	codes_lbl = UIK.wrapped(UIK.label("", 14))
	v.add_child(codes_lbl)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "e.g. 417-92"
	code_edit.editable = not readonly
	code_edit.text_submitted.connect(func(_t: String): _submit_code())
	v.add_child(code_edit)
	var b: Button = UIK.btn("Lay in course", "helm", _submit_code, "map")
	b.disabled = readonly
	v.add_child(b)
	return v

func _submit_code() -> void:
	if code_edit != null and code_edit.text.strip_edges() != "":
		send("code", code_edit.text.strip_edges())
		code_edit.release_focus()

func _update_ritual_extra(_rit: Dictionary, ph: Dictionary) -> void:
	if codes_lbl != null:
		var lines: Array = []
		for o in ph.get("options", []):
			lines.append(str(o.code))
		codes_lbl.text = "Ask the captain where to go. Coordinates on offer: %s" % ", ".join(lines)

func refresh() -> void:
	compass.heading = float(view.get("heading", -PI / 2.0))
	compass.angvel = float(view.get("angvel", 0.0))
	compass.wp_bearing = float(view.get("wp_bearing", 999.0))
	info.text = "Spin %+.2f   ·   thrusters %d%%" % [compass.angvel, int(float(view.get("rcs_pf", 0.0)) * 100.0)]
	if view.has("wp_bearing"):
		var rb: float = float(view.wp_bearing)
		wp_lbl.text = "Waypoint %d° to %s" % [int(absf(rad_to_deg(rb))), "starboard" if rb > 0.0 else "port"] if absf(rb) > 0.05 else "Waypoint dead ahead!"
	else:
		wp_lbl.text = "No waypoint. Ask the captain."
	auth_l.value = float(view.get("auth_l", 1.0))
	auth_r.value = float(view.get("auth_r", 1.0))
	drift_bar.value = float(view.get("drift", 0.0))
	trim_lever.set_value(float(view.get("trim", 0.0)))
	roll_btn.disabled = float(view.get("roll_cd", 0.0)) > 0.0 or readonly

func _unhandled_key_input(e: InputEvent) -> void:
	if readonly or not is_visible_in_tree() or not (e is InputEventKey):
		return
	var ke: InputEventKey = e
	if ke.echo:
		return
	var pr: float = 1.0 if ke.pressed else 0.0
	var changed_yaw: bool = false
	var changed_str: bool = false
	match ke.keycode:
		KEY_A, KEY_LEFT:
			key_yaw = -pr if pr > 0 else (0.0 if key_yaw < 0 else key_yaw)
			changed_yaw = true
		KEY_D, KEY_RIGHT:
			key_yaw = pr if pr > 0 else (0.0 if key_yaw > 0 else key_yaw)
			changed_yaw = true
		KEY_Q:
			key_strafe = -pr if pr > 0 else (0.0 if key_strafe < 0 else key_strafe)
			changed_str = true
		KEY_E:
			key_strafe = pr if pr > 0 else (0.0 if key_strafe > 0 else key_strafe)
			changed_str = true
	if changed_yaw:
		yaw_lever.value = key_yaw
		yaw_lever.queue_redraw()
		send("yaw", key_yaw * (0.5 if ke.shift_pressed else 1.0))
		get_viewport().set_input_as_handled()
	if changed_str:
		strafe_lever.value = key_strafe
		strafe_lever.queue_redraw()
		send("strafe", key_strafe)
		get_viewport().set_input_as_handled()
