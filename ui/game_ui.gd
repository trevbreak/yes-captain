class_name GameUI
extends Control
## The in-game shell: a top bar (who you are, the mission, the hull), the station in the middle,
## a dock at the bottom (your seats + IGOR's subtitles), toasts, the pause menu, the briefing and the debrief.

signal leave_pressed

const TOP_H: int = 58
const DOCK_H: int = 70

var top_pic: TextureRect
var top_role: Label
var top_persona: Label
var top_mission: Label
var top_time: Label
var hull_chip: PanelContainer
var content: Control
var stations: Dictionary = {}
var cap_ui: CaptainUI
var dock_seats: HBoxContainer
var igor_pic: TextureRect
var igor_who: Label
var igor_text: Label
var toasts: VBoxContainer
var pause_panel: Control
var briefing_ui: BriefingUI
var overlay: Control = null
var _active: String = ""
var _seats_sig: String = ""
var _phase: String = ""
var _debrief_sig: String = ""
var _igor_t: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.bg(self)
	var root: VBoxContainer = UIK.vbox(8)
	var m: MarginContainer = UIK.margin(root, 10)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	# ---- top bar
	var top: HBoxContainer = UIK.hbox(12)
	top.custom_minimum_size = Vector2(0, TOP_H)
	root.add_child(top)
	top_pic = UIK.portrait("captain", 56)
	top.add_child(top_pic)
	var tv: VBoxContainer = UIK.vbox(-6)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tv)
	top_role = UIK.head("CAPTAIN", 27)
	tv.add_child(top_role)
	top_persona = UIK.label("", 19, K.pal("ink_soft"))
	tv.add_child(top_persona)
	top.add_child(UIK.spacer(true))
	var mp: PanelContainer = UIK.panel("panel_small", [10, 0, 10, 0])
	mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(mp)
	var mh: HBoxContainer = UIK.hbox(12)
	mp.add_child(mh)
	top_mission = UIK.head("", 22)
	mh.add_child(top_mission)
	top_time = UIK.label("", 21, K.pal("ink_soft"))
	mh.add_child(top_time)
	top.add_child(UIK.spacer(true))
	hull_chip = UIK.chip("HULL 100%", "red", "heart", 20)
	hull_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hull_chip)
	var menu_btn: Button = UIK.btn("", "cream", _toggle_pause, "menu", 26)
	menu_btn.tooltip_text = "Menu (Esc)"
	menu_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(menu_btn)
	# ---- station area
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	cap_ui = CaptainUI.new()
	cap_ui.visible = false
	content.add_child(cap_ui)
	for st in K.STATIONS:
		var ui: Station = _make_station(st)
		ui.visible = false
		content.add_child(ui)
		stations[st] = ui
	# ---- dock
	var dock: HBoxContainer = UIK.hbox(10)
	dock.custom_minimum_size = Vector2(0, DOCK_H)
	root.add_child(dock)
	dock_seats = UIK.hbox(6)
	dock_seats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dock.add_child(dock_seats)
	var ib: PanelContainer = UIK.panel("panel_small", [0, -10, 0, -12])
	ib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.add_child(ib)
	var ih: HBoxContainer = UIK.hbox(10)
	ib.add_child(ih)
	igor_pic = UIK.portrait("igor", 46)
	ih.add_child(igor_pic)
	var iv: VBoxContainer = UIK.vbox(-6)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	ih.add_child(iv)
	igor_who = UIK.head("IGOR", 16, UIK.c("red"))
	iv.add_child(igor_who)
	igor_text = UIK.label("IGOR is watching. IGOR is always watching.", 21)
	igor_text.clip_text = true
	igor_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	igor_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_child(igor_text)
	# ---- toasts, pause, briefing
	toasts = UIK.vbox(6)
	toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toasts.alignment = BoxContainer.ALIGNMENT_END
	toasts.offset_left = -300
	toasts.offset_right = 300
	toasts.offset_top = -240
	toasts.offset_bottom = -(DOCK_H + 30)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.set_meta("overlay", true)
	toasts.z_index = 30
	add_child(toasts)
	briefing_ui = BriefingUI.new()
	briefing_ui.z_index = 20
	briefing_ui.visible = false
	add_child(briefing_ui)
	_build_pause()
	Net.snapshot.connect(on_snapshot)
	Net.event.connect(on_event)

func _make_station(st: String) -> Station:
	match st:
		"helm":
			return HelmUI.new()
		"engines":
			return EnginesUI.new()
		"weapons":
			return WeaponsUI.new()
		"sensors":
			return SensorsUI.new()
		"shields":
			return ShieldsUI.new()
	return EngineerUI.new()

func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.set_meta("overlay", true)
	pause_panel.z_index = 40
	pause_panel.visible = false
	add_child(pause_panel)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var w: Array = UIK.window("MENU", "navy", "menu")
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(cc)
	w[0].custom_minimum_size = Vector2(440, 0)
	cc.add_child(w[0])
	var b: VBoxContainer = w[1]
	b.add_child(UIK.speech("The ship does not pause. IGOR does not allow it.", "igor", "", 70, 21))
	var snd: Button = UIK.toggle("Sound", "green", func(on: bool): UIK.set_sound(on), "speaker")
	snd.button_pressed = UIK.sound_on()
	b.add_child(snd)
	var voice: Button = UIK.toggle("IGOR's voice", "green", func(on: bool): UIK.set_voice(on), "robot")
	voice.button_pressed = UIK.voice_on()
	b.add_child(voice)
	var grain: Button = UIK.toggle("Film grain", "green", func(on: bool): UIK.set_grain(on), "eye")
	grain.button_pressed = Film.enabled
	b.add_child(grain)
	b.add_child(UIK.btn("Back to the game", "green", _toggle_pause, "play"))
	b.add_child(UIK.btn("Leave the game", "red", func():
		pause_panel.visible = false
		leave_pressed.emit(), "back"))

func _toggle_pause() -> void:
	pause_panel.visible = not pause_panel.visible

func _unhandled_input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: Key = (e as InputEventKey).physical_keycode
		if k == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
		var mine: Array = Net.last_snapshot.get("seats", [])
		var idx: int = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7].find(k)
		if idx >= 0 and idx < K.SEATS.size() and K.SEATS[idx] in mine:
			Net.send("active", {"seat": K.SEATS[idx]})
			get_viewport().set_input_as_handled()

func reset() -> void:
	_active = ""
	_seats_sig = ""
	_phase = ""
	_debrief_sig = ""
	for c in toasts.get_children():
		c.queue_free()
	_clear_overlay()
	briefing_ui.visible = false
	pause_panel.visible = false

func _clear_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null

# ---------------------------------------------------------------- snapshots

func on_snapshot(d: Dictionary) -> void:
	if not is_visible_in_tree():
		return
	var phase: String = str(d.get("phase", ""))
	var com: Dictionary = d.get("common", {})
	var act: String = str(d.get("active", ""))
	var seats: Array = d.get("seats", [])
	if phase != _phase:
		_phase = phase
		_clear_overlay()
		_debrief_sig = ""
		for st in stations.values():
			(st as Station).release_all()
	briefing_ui.visible = phase == "briefing"
	content.visible = phase != "briefing"
	if phase == "briefing":
		briefing_ui.apply(d.get("phase_data", {}), seats)
	var view_seat: String = act if act != "" else "captain"
	if view_seat != _active:
		_active = view_seat
		cap_ui.visible = view_seat == "captain"
		for st in stations.keys():
			stations[st].visible = st == view_seat
			if st != view_seat:
				(stations[st] as Station).release_all()
		var info: Dictionary = K.SEAT_INFO.get(view_seat, {})
		top_pic.texture = Art.sized("portrait_" + view_seat, 56)
		top_role.text = str(info.get("name", "")).to_upper()
		top_role.add_theme_color_override("font_color", K.seat_color(view_seat).darkened(0.2))
		top_persona.text = str(info.get("persona", "")) + ("" if act != "" else "  (watching)")
	var sig: String = ",".join(PackedStringArray(seats)) + "/" + act
	if sig != _seats_sig:
		_seats_sig = sig
		_build_dock(seats, act)
	var mi: Dictionary = com.get("mission", {})
	top_mission.text = "MISSION %d: %s" % [int(mi.get("num", 0)), str(mi.get("title", "")).to_upper()]
	top_time.text = K.fmt_time(float(mi.get("time", 0.0)))
	var hull: float = float(com.get("hull", 100.0))
	UIK.set_chip(hull_chip, "HULL %d%%" % int(hull), "red" if hull > 35.0 else "ink")
	var v: Dictionary = d.get("view", {})
	if view_seat == "captain":
		cap_ui.apply(v, com)
	elif stations.has(view_seat):
		(stations[view_seat] as Station).apply(v, com)
	if phase == "debrief":
		var pd: Dictionary = d.get("phase_data", {})
		var dsig: String = "%s/%s" % [str(pd.get("title", "")), str(pd.get("can_continue", false))]
		if dsig != _debrief_sig:
			_debrief_sig = dsig
			_clear_overlay()
			overlay = Screens.debrief(pd, func(): Net.send("next"), func(): Net.send("retry"), func(): Net.send("lobby"))
			overlay.z_index = 25
			add_child(overlay)
			move_child(overlay, pause_panel.get_index())

func _build_dock(seats: Array, act: String) -> void:
	for c in dock_seats.get_children():
		c.queue_free()
	if seats.size() <= 1:
		return
	for i in K.SEATS.size():
		var s: String = K.SEATS[i]
		if not (s in seats):
			continue
		var on: bool = s == act
		var b: Button = UIK.btn(str(i + 1), str(K.SEAT_INFO[s].color) if on else "cream", func(): Net.send("active", {"seat": s}), str(K.SEAT_INFO[s].icon), 20)
		b.tooltip_text = "%s (key %d)" % [K.seat_name(s), i + 1]
		b.custom_minimum_size = Vector2(70, 54)
		dock_seats.add_child(b)

# ---------------------------------------------------------------- events

func on_event(d: Dictionary) -> void:
	if not is_visible_in_tree():
		return
	match str(d.get("t", "")):
		"igor":
			var who: String = str(d.get("who", "igor"))
			igor_pic.texture = Art.sized("portrait_" + who, 50)
			igor_who.text = {"igor": "IGOR", "thrupp": "ADMIRAL THRUPP", "pudding": "PUDDING", "gristle": "MA GRISTLE"}.get(who, who.to_upper())
			igor_text.text = str(d.get("text", ""))
			igor_text.tooltip_text = igor_text.text
			if bool(d.get("speak", false)) and _phase == "mission":
				UIK.speak(igor_text.text)
		"toast":
			toast(str(d.get("text", "")), str(d.get("kind", "info")), str(d.get("who", "")))
		"step":
			if _phase == "mission":
				toast("NEXT: " + str(d.get("text", "")), "step", "captain")
		"fx":
			match str(d.get("fx", "")):
				"boom":
					UIK.sfx("boom")
				"hit":
					UIK.sfx("bonk")
				"alarm":
					UIK.sfx("alarm")
				"ding":
					UIK.sfx("ding")
				"blackout":
					UIK.sfx("powerdown")
				"bump":
					UIK.sfx("clunk")
		"countdown":
			UIK.sfx("chime")
		"mission_start":
			UIK.sfx("whoosh")

func toast(text: String, kind: String = "info", who: String = "") -> void:
	var col: String = {"bad": "red", "good": "green", "step": "mustard", "info": "cream"}.get(kind, "cream")
	var p: PanelContainer = UIK.chip(text, col, "", 18)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toasts.add_child(p)
	if toasts.get_child_count() > 3:
		toasts.get_child(0).queue_free()
	var tw: Tween = p.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
