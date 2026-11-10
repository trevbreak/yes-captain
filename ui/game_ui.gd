class_name GameUI
extends Control
## The in-game shell: a top bar (who you are, the mission, the hull), the station in the middle,
## a dock at the bottom (your seats + IGOR's subtitles), toasts, the pause menu, the briefing and the debrief.

signal leave_pressed

const TOP_H: int = 58
const DOCK_H: int = 70

var top_pic: Face
var top_role: Label
var top_persona: Label
var top_mission: Label
var top_time: Label
var hull_chip: PanelContainer
var pay_chip: PanelContainer
var board_ui: Screens.JobBoard
var content: Control
var stations: Dictionary = {}
var cap_ui: CaptainUI
var dock_seats: HBoxContainer
var igor_pic: Face
var igor_who: Label
var igor_text: Label
var toast_chip: PanelContainer
var _toast_tw: Tween
var pause_panel: Control
var briefing_ui: BriefingUI
var overlay: Control = null
var _active: String = ""
var _seats_sig: String = ""
var _phase: String = ""
var _debrief_sig: String = ""
var _igor_t: float = 0.0
var _cheer_t: float = 0.0

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
	top.add_child(Voice.Bar.new())
	pay_chip = UIK.chip("", "green", "star", 18)
	pay_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pay_chip.visible = false
	pay_chip.tooltip_text = "This shift: money earned so far, and the rent the depot wants"
	pay_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(pay_chip)
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
	var iv: VBoxContainer = UIK.vbox(0)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	ih.add_child(iv)
	igor_who = UIK.head("IGOR", 16, UIK.c("red"))
	igor_who.visible = false
	iv.add_child(igor_who)
	igor_text = UIK.para("IGOR is watching. IGOR is always watching.", 18)
	igor_text.max_lines_visible = 2
	igor_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	igor_text.add_theme_constant_override("line_spacing", -7)
	igor_text.custom_minimum_size = Vector2(200, 50)
	igor_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_child(igor_text)
	# the latest news sits in a fixed slot at the end of the dock, so it never covers a control
	toast_chip = UIK.chip("", "cream", "", 18)
	toast_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toast_chip.modulate.a = 0.0
	ih.add_child(toast_chip)
	# ---- pause, briefing
	briefing_ui = BriefingUI.new()
	briefing_ui.z_index = 20
	briefing_ui.visible = false
	add_child(briefing_ui)
	board_ui = Screens.JobBoard.new()
	board_ui.z_index = 20
	board_ui.visible = false
	add_child(board_ui)
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
	var mus: Button = UIK.toggle("Music", "green", func(on: bool): UIK.set_music(on), "speaker")
	mus.button_pressed = UIK.music_on()
	b.add_child(mus)
	var grain: Button = UIK.toggle("Film grain", "green", func(on: bool): UIK.set_grain(on), "eye")
	grain.button_pressed = Film.enabled
	b.add_child(grain)
	b.add_child(UIK.btn("Back to the game", "green", _toggle_pause, "play"))
	b.add_child(UIK.btn("Leave the game", "red", func():
		pause_panel.visible = false
		leave_pressed.emit(), "back"))

func _process(dt: float) -> void:
	# IGOR's face settles back down a few seconds after he's said his piece
	_igor_t += dt
	if _igor_t > 4.5 and igor_pic.mood != "":
		igor_pic.set_mood("", false)

func _toggle_pause() -> void:
	pause_panel.visible = not pause_panel.visible

func _unhandled_input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: Key = (e as InputEventKey).physical_keycode
		if k == KEY_ESCAPE or k == KEY_QUOTELEFT:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
		var mine: Array = Net.last_snapshot.get("seats", [])
		if k == KEY_F and mine.size() > 1:
			_flip()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_M and Voice.active:
			Voice.set_muted(not Voice.muted)
			get_viewport().set_input_as_handled()
			return
		var idx: int = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7].find(k)
		if idx >= 0 and idx < K.SEATS.size() and K.SEATS[idx] in mine:
			Net.send("active", {"seat": K.SEATS[idx]})
			get_viewport().set_input_as_handled()

func _flip() -> void:
	## hop to the next seat you hold (a pair has two, so this is "the other one")
	var mine: Array = Net.last_snapshot.get("seats", [])
	if mine.size() < 2:
		return
	var order: Array = []
	for s in K.SEATS:
		if s in mine:
			order.append(s)
	var i: int = order.find(str(Net.last_snapshot.get("active", "")))
	UIK.sfx("clack")
	Net.send("active", {"seat": order[(i + 1) % order.size()]})

func reset() -> void:
	_active = ""
	_seats_sig = ""
	_phase = ""
	_debrief_sig = ""
	toast_chip.modulate.a = 0.0
	_clear_overlay()
	briefing_ui.visible = false
	board_ui.visible = false
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
		if _phase != "":
			Fx.iris()
		_phase = phase
		_clear_overlay()
		_debrief_sig = ""
		for st in stations.values():
			(st as Station).release_all()
	briefing_ui.visible = phase == "briefing"
	board_ui.visible = phase == "board"
	content.visible = phase != "briefing" and phase != "board"
	if phase == "briefing":
		briefing_ui.apply(d.get("phase_data", {}), seats)
	if phase == "board":
		board_ui.apply(d.get("phase_data", {}))
		return
	var view_seat: String = act if act != "" else "captain"
	if view_seat != _active:
		_active = view_seat
		cap_ui.visible = view_seat == "captain"
		for st in stations.keys():
			stations[st].visible = st == view_seat
			if st != view_seat:
				(stations[st] as Station).release_all()
		var info: Dictionary = K.SEAT_INFO.get(view_seat, {})
		top_pic.set_who(view_seat)
		top_role.text = str(info.get("name", "")).to_upper()
		top_role.add_theme_color_override("font_color", K.seat_color(view_seat).darkened(0.2))
		top_persona.text = str(info.get("persona", "")) + ("" if act != "" else "  (watching)")
	var sig: String = ",".join(PackedStringArray(seats)) + "/" + act
	if sig != _seats_sig:
		_seats_sig = sig
		_build_dock(seats, act)
	var mi: Dictionary = com.get("mission", {})
	var sh: Dictionary = com.get("shift", {})
	pay_chip.visible = not sh.is_empty()
	if sh.is_empty():
		top_mission.text = "MISSION %d: %s" % [int(mi.get("num", 0)), str(mi.get("title", "")).to_upper()]
	else:
		top_mission.text = "JOB %d OF %d: %s" % [mini(int(sh.n), int(sh.of)), int(sh.of), str(mi.get("title", "")).to_upper()]
		UIK.set_chip(pay_chip, "%s OF %s" % [Screens.money(int(sh.earned)), Screens.money(int(sh.rent))], "green" if int(sh.earned) >= int(sh.rent) else "mustard")
	top_time.text = K.fmt_time(float(mi.get("time", 0.0)))
	var hull: float = float(com.get("hull", 100.0))
	UIK.set_chip(hull_chip, "HULL %d%%" % int(hull), "red" if hull > 35.0 else "ink")
	if phase == "mission":
		UIK.music("danger" if hull < 35.0 else "game")
		# your own face in the corner shows how it's going for you
		var worst: int = 0
		for wn in d.get("view", {}).get("warnings", []):
			worst = maxi(worst, int(wn.get("level", 0)))
		var mood: String = "panic" if (hull < 35.0 or bool(com.get("blackout", false)) or worst >= 3) else ("busy" if bool(com.get("glitchy", false)) else "")
		if _cheer_t > 0.0:
			_cheer_t -= 1.0 / 15.0
			mood = "cheer"
		top_pic.set_mood(mood)
	else:
		UIK.music("menu")
		top_pic.set_mood("", false)
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
			overlay = Screens.debrief(pd, func(): Net.send("next"), func(): Net.send("retry"), func(): Net.send("lobby"), func(): Net.send("shuffle"))
			overlay.z_index = 25
			add_child(overlay)
			move_child(overlay, pause_panel.get_index())

func _build_dock(seats: Array, act: String) -> void:
	for c in dock_seats.get_children():
		c.queue_free()
	if seats.size() <= 1:
		return
	if seats.size() == 2:
		# a pair: one big button that shows where you'd go
		var other: String = str(seats[0]) if str(seats[1]) == act else str(seats[1])
		var fb: Button = UIK.btn("Flip to %s  [F]" % K.seat_name(other), str(K.SEAT_INFO[other].color), _flip, str(K.SEAT_INFO[other].icon), 20)
		fb.custom_minimum_size = Vector2(250, 54)
		fb.tooltip_text = "You hold two stations. This hops to the other one."
		dock_seats.add_child(fb)
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
			igor_pic.set_who(who)
			igor_pic.set_mood("")
			igor_pic.set_mood("panic" if int(d.get("prio", 1)) >= 3 else "busy")
			igor_who.text = {"igor": "IGOR", "thrupp": "ADMIRAL THRUPP", "pudding": "PUDDING", "gristle": "MA GRISTLE"}.get(who, who.to_upper())
			igor_text.text = ("" if who == "igor" else igor_who.text + ": ") + str(d.get("text", ""))
			_igor_t = 0.0
			igor_text.tooltip_text = igor_text.text
			if bool(d.get("speak", false)) and _phase == "mission":
				UIK.speak(igor_text.text)
		"toast":
			toast(str(d.get("text", "")), str(d.get("kind", "info")), str(d.get("who", "")))
		"step":
			pass
		"fx":
			match str(d.get("fx", "")):
				"boom":
					UIK.sfx("boom")
					Fx.shake(5.0)
				"hit":
					UIK.sfx("bonk")
					Fx.shake(10.0)
				"alarm":
					UIK.sfx("alarm")
				"ding":
					UIK.sfx("ding")
					_cheer_t = 2.0
				"blackout":
					UIK.sfx("powerdown")
				"bump":
					UIK.sfx("clunk")
					Fx.shake(7.0)
				"ring":
					UIK.sfx("ring")
				"glitch":
					UIK.sfx("zap")
				"block":
					UIK.sfx("clack")
		"countdown":
			UIK.sfx("chime")
		"mission_start":
			UIK.sfx("whoosh")
			Fx.title_card("AND... ACTION!", str(d.get("title", "")))

func toast(text: String, kind: String = "info", _who: String = "") -> void:
	var col: String = {"bad": "red", "good": "green", "step": "mustard", "info": "cream"}.get(kind, "cream")
	if text.length() > 34:
		text = text.left(33) + "…"
	UIK.set_chip(toast_chip, text, col)
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	toast_chip.modulate.a = 1.0
	_toast_tw = toast_chip.create_tween()
	_toast_tw.tween_interval(3.0)
	_toast_tw.tween_property(toast_chip, "modulate:a", 0.0, 0.5)
