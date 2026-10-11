class_name HelmUI
extends StationUI

var compass: Compass
var yaw_lever: Lever
var strafe_lever: Lever
var trim_lever: Lever
var info: Label
var auth_l: BarGauge
var auth_r: BarGauge
var drift_bar: BarGauge
var roll_btn: SafetyBtn
var code_edit: LineEdit
var code_btn: Button
var codes_lbl: Label
var key_yaw: float = 0.0
var key_strafe: float = 0.0
var last_wp: float = 999.0

func build() -> void:
	var h: HBoxContainer = UIK.hbox(16)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	compass = Compass.new()
	compass.accent = accent
	h.add_child(compass)
	var mid: VBoxContainer = UIK.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	info = UIK.label("", 18)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(info)
	var g: GridContainer = UIK.grid(2, 10, 4)
	mid.add_child(g)
	g.add_child(UIK.label("Turn power: port", 15))
	auth_l = BarGauge.new("", 1.0, K.pal("teal"))
	g.add_child(auth_l)
	g.add_child(UIK.label("Turn power: starboard", 15))
	auth_r = BarGauge.new("", 1.0, K.pal("teal"))
	g.add_child(auth_r)
	g.add_child(UIK.label("Drift (needs trim)", 15))
	drift_bar = BarGauge.new("", 1.0, K.pal("mustard"))
	drift_bar.vmin = -1.0
	g.add_child(drift_bar)
	yaw_lever = Lever.new("YAW  ◄ PORT        STARBOARD ►   (A / D)", -1.0, 1.0, accent, true)
	yaw_lever.spring = true
	yaw_lever.custom_minimum_size = Vector2(420, 90)
	yaw_lever.changed.connect(func(v: float): send("yaw", v))
	mid.add_child(yaw_lever)
	strafe_lever = Lever.new("STRAFE  ◄ PORT   STARBOARD ►   (Q / E)", -1.0, 1.0, K.pal("mint"), true)
	strafe_lever.spring = true
	strafe_lever.custom_minimum_size = Vector2(420, 90)
	strafe_lever.changed.connect(func(v: float): send("strafe", v))
	mid.add_child(strafe_lever)
	roll_btn = SafetyBtn.new("EMERGENCY ROLL", "coral")
	roll_btn.fired.connect(func(): send("roll", 1.0 if yaw_lever.value >= 0.0 else -1.0))
	mid.add_child(roll_btn)
	trim_lever = Lever.new("TRIM", -1.0, 1.0, K.pal("butter"))
	trim_lever.custom_minimum_size = Vector2(80, 250)
	trim_lever.snap_zero = true
	trim_lever.changed.connect(func(v: float): send("trim", v))
	h.add_child(trim_lever)

func _build_ritual_extra() -> Control:
	var v: VBoxContainer = UIK.vbox(4)
	codes_lbl = UIK.label("Coordinates:", 15)
	codes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(codes_lbl)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "e.g. 417-92"
	code_edit.editable = not readonly
	code_edit.text_submitted.connect(func(t: String): _submit_code())
	v.add_child(code_edit)
	code_btn = UIK.btn("LAY IN COURSE", "teal", _submit_code)
	code_btn.disabled = readonly
	v.add_child(code_btn)
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
		codes_lbl.text = "The captain knows where each coordinate goes.\nAvailable: %s" % ", ".join(lines)

func refresh() -> void:
	compass.heading = float(view.get("heading", -PI / 2.0))
	compass.angvel = float(view.get("angvel", 0.0))
	compass.wp_bearing = float(view.get("wp_bearing", 999.0))
	var hd: int = UIK.angle_deg(compass.heading)
	var t: String = "Heading %03d°   Spin %+.2f rad/s\nRCS power %d%%" % [hd, compass.angvel, int(float(view.get("rcs_pf", 0.0)) * 100.0)]
	if view.has("wp_bearing"):
		var rb: float = float(view.wp_bearing)
		var side: String = "starboard" if rb > 0.0 else "port"
		t += "\nWaypoint: %d° to %s" % [int(absf(rad_to_deg(rb))), side]
	info.text = t
	auth_l.value = float(view.get("auth_l", 1.0))
	auth_r.value = float(view.get("auth_r", 1.0))
	drift_bar.value = float(view.get("drift", 0.0))
	drift_bar.text = "%+.2f" % float(view.get("drift", 0.0))
	trim_lever.set_value(float(view.get("trim", 0.0)))
	roll_btn.disabled = float(view.get("roll_cd", 0.0)) > 0.0 or readonly
	title_lbl.text = "HELM"

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
