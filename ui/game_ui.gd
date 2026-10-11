class_name GameUI
extends Control
## In-game shell. Top bar: who you are, the objective checklist, ship status, menu.
## Middle: your station (or the captain's bridge). Bottom dock: role switcher, IGOR, free seats.
## Overlays: mission briefing, debrief, game over, ending, pause.

signal leave_pressed

const TOP_H: int = 64
const DOCK_H: int = 70

var cap_ui: CaptainUI = null
var stations: Dictionary = {}
var current: String = ""
var shell: Control
# top bar
var role_portrait: TextureRect
var role_name: Label
var role_sub: Label
var obj_title: Label
var obj_step: Label
var obj_dots: HBoxContainer
var hull_chip: PanelContainer
var mood_chip: PanelContainer
var temper_chip: PanelContainer
var res_chip: PanelContainer
# dock
var seat_row: HBoxContainer
var seat_sig: String = ""
var igor_lbl: Label
var igor_t: float = 0.0
var igor_box: PanelContainer
var free_row: HBoxContainer
# overlays
var briefing: BriefingUI = null
var overlay: Control = null
var overlay_sig: String = ""
var toast_box: VBoxContainer
var order_card: PanelContainer
var order_lbl: Label
var order_t: float = 0.0
var pause_panel: Control
var spectate: PanelContainer
var last: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	UIK.space_bg(self)
	shell = Control.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_top = TOP_H + 4
	shell.offset_bottom = -DOCK_H - 4
	add_child(shell)
	_build_top()
	_build_dock()
	toast_box = UIK.vbox(6)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast_box.offset_left = -360
	toast_box.offset_right = -16
	toast_box.offset_top = TOP_H + 14
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.set_meta("overlay", true)
	add_child(toast_box)
	order_card = UIK.panel("yellow", 12, 16)
	order_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	order_card.offset_top = TOP_H + 10
	order_card.offset_left = -320
	order_card.offset_right = 320
	order_card.set_meta("overlay", true)
	var oh: HBoxContainer = UIK.hbox(10)
	order_card.add_child(oh)
	oh.add_child(UIK.portrait("captain", 48))
	order_lbl = UIK.wrapped(UIK.heading("", 20))
	order_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oh.add_child(order_lbl)
	order_card.visible = false
	add_child(order_card)
	spectate = UIK.panel("card", 18, 22)
	spectate.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	spectate.offset_left = -300
	spectate.offset_right = 300
	spectate.offset_top = -60
	spectate.offset_bottom = 60
	spectate.add_child(UIK.wrapped(UIK.heading("You don't have a role yet. Take a free seat from the dock at the bottom, or just watch the chaos.", 20, K.pal("ink"), 1)))
	spectate.visible = false
	add_child(spectate)
	_build_pause()
	Net.snapshot.connect(on_snapshot)
	Net.event.connect(on_event)

func _build_top() -> void:
	var bar: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = UIK.sb(Color(K.pal("night"), 0.92), 0, Color(0, 0, 0, 0), 0, 8, 0)
	s.border_width_bottom = 3
	s.border_color = K.pal("night2").lightened(0.15)
	bar.add_theme_stylebox_override("panel", s)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = TOP_H
	add_child(bar)
	var h: HBoxContainer = UIK.hbox(12)
	bar.add_child(h)
	# who am I
	var who: HBoxContainer = UIK.hbox(8)
	who.custom_minimum_size = Vector2(250, 0)
	h.add_child(who)
	role_portrait = UIK.portrait("captain", 48)
	who.add_child(role_portrait)
	var wv: VBoxContainer = UIK.vbox(-2)
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_child(wv)
	role_name = UIK.heading("", 20, Color.WHITE)
	wv.add_child(role_name)
	role_sub = UIK.label("", 13, Color(1, 1, 1, 0.65))
	wv.add_child(role_sub)
	# objective tracker
	var obj: PanelContainer = PanelContainer.new()
	obj.add_theme_stylebox_override("panel", UIK.sb(K.pal("card"), UIK.RADIUS_S, K.pal("well").darkened(0.1), 2, 6))
	obj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(obj)
	var oh: HBoxContainer = UIK.hbox(8)
	obj.add_child(oh)
	oh.add_child(UIK.icon_rect("check", 22, K.pal("green")))
	var ov: VBoxContainer = UIK.vbox(-3)
	ov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oh.add_child(ov)
	obj_title = UIK.label("", 12, K.pal("ink_soft"))
	obj_title.clip_text = true
	ov.add_child(obj_title)
	obj_step = UIK.heading("", 17)
	obj_step.clip_text = true
	obj_step.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ov.add_child(obj_step)
	obj_dots = UIK.hbox(4)
	oh.add_child(obj_dots)
	# status
	hull_chip = UIK.chip("100%", "red", "hull", 15)
	hull_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(hull_chip)
	mood_chip = UIK.chip("Calm", "pink", "pudding", 15)
	mood_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mood_chip)
	temper_chip = UIK.chip("Peeved", "purple", "temper", 15)
	temper_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(temper_chip)
	res_chip = UIK.chip("", "yellow", "scrap", 15)
	res_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(res_chip)
	var menu: Button = UIK.icon_btn("menu", "neutral", func(): pause_panel.visible = not pause_panel.visible, "Menu (Esc)")
	h.add_child(menu)

func _build_dock() -> void:
	var dock: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = UIK.sb(Color(K.pal("night"), 0.92), 0, Color(0, 0, 0, 0), 0, 8, 0)
	s.border_width_top = 3
	s.border_color = K.pal("night2").lightened(0.15)
	dock.add_theme_stylebox_override("panel", s)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -DOCK_H
	add_child(dock)
	var h: HBoxContainer = UIK.hbox(10)
	dock.add_child(h)
	seat_row = UIK.hbox(6)
	h.add_child(seat_row)
	igor_box = PanelContainer.new()
	igor_box.add_theme_stylebox_override("panel", UIK.sb(K.pal("card"), UIK.RADIUS, K.pal("sensors").darkened(0.1), 2, 4))
	igor_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(igor_box)
	var ih: HBoxContainer = UIK.hbox(8)
	igor_box.add_child(ih)
	ih.add_child(UIK.portrait("igor", 44))
	igor_lbl = UIK.label("IGOR is watching. IGOR is always watching.", 15, K.pal("ink"))
	igor_lbl.clip_text = true
	igor_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	igor_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(igor_lbl)
	free_row = UIK.hbox(4)
	h.add_child(free_row)

func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.set_meta("overlay", true)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UIK.bg_color(pause_panel, Color(K.pal("night"), 0.7))
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)
	var w: Array = UIK.window("MENU", "blue", "menu", 18)
	(w[0] as Control).custom_minimum_size = Vector2(420, 0)
	center.add_child(w[0])
	var v: VBoxContainer = w[1]
	v.add_child(UIK.speech("The ship does not pause. IGOR does not allow it.", "igor", "", 56))
	var snd: Button = UIK.toggle_btn("Sound", "neutral", func(on: bool): Sfx.enabled = on)
	snd.button_pressed = Sfx.enabled
	v.add_child(snd)
	var tts: Button = UIK.toggle_btn("IGOR's voice", "neutral", func(on: bool): Sfx.tts_on = on)
	tts.button_pressed = Sfx.tts_on
	v.add_child(tts)
	v.add_child(UIK.btn("Back to the game", "green", func(): pause_panel.visible = false, "play"))
	v.add_child(UIK.btn("Leave the game", "red", func(): leave_pressed.emit(), "back"))
	pause_panel.visible = false
	add_child(pause_panel)

# ---------------------------------------------------------------- snapshots

func on_snapshot(d: Dictionary) -> void:
	if not visible or not d.has("common"):
		return
	last = d
	var act: String = str(d.get("active", ""))
	var phase: String = str(d.get("phase", ""))
	var seats: Array = d.get("seats", [])
	_update_top(d, act)
	_update_dock(seats, act)
	# briefing takes over the whole screen
	if phase == "briefing":
		if briefing == null:
			briefing = BriefingUI.new()
			add_child(briefing)
			move_child(briefing, get_child_count() - 1)
			move_child(pause_panel, get_child_count() - 1)
		briefing.visible = true
		briefing.apply(d)
	elif briefing != null:
		briefing.queue_free()
		briefing = null
	spectate.visible = act == "" and phase != "briefing"
	if current != act:
		_switch(act)
	if act == "captain" and cap_ui != null:
		cap_ui.apply(d.view, d)
	elif act != "" and stations.has(act):
		var su: StationUI = stations[act]
		su.apply(d.view, d)
		var sh: float = float(d.common.get("shake", 0.0))
		su.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * sh * 4.0 if sh > 0.05 else Vector2.ZERO
	_update_overlay(d)

func _update_top(d: Dictionary, act: String) -> void:
	var com: Dictionary = d.common
	if act != "" and K.SEAT_INFO.has(act):
		var info: Dictionary = K.SEAT_INFO[act]
		var want: Texture2D = UIK.portrait_tex(str(info.portrait), 96)
		if role_portrait.texture != want:
			role_portrait.texture = want
		role_name.text = K.seat_name(act)
		role_sub.text = str(info.persona)
	else:
		role_name.text = "Spectating"
		role_sub.text = str(com.get("ship_name", ""))
	var steps: Array = com.get("steps", [])
	var phase: String = str(d.get("phase", ""))
	obj_title.text = "%s  ·  %s" % [str(com.get("title", "")), K.fmt_time(float(com.get("t", 0.0)))] if phase == "encounter" else str(com.get("ship_name", "")).to_upper()
	var cur: String = ""
	var done_n: int = 0
	for st in steps:
		if bool(st.done):
			done_n += 1
		elif cur == "":
			cur = str(st.text)
	match phase:
		"staging":
			cur = "JUMP RITUAL: coordinates, capacitor, speed, cargo... then PUNCH IT"
		"pitstop":
			cur = "Pit stop at Ma Gristle's: ask the captain for upgrades"
		"debrief":
			cur = "Mission complete. Waiting for the captain."
		"jumping":
			cur = "JUMPING..."
		"briefing":
			cur = "Mission briefing"
	obj_step.text = cur if cur != "" else str(com.get("obj", ""))
	if obj_dots.get_child_count() != steps.size():
		for ch in obj_dots.get_children():
			ch.queue_free()
		for i in steps.size():
			var dot: Panel = Panel.new()
			dot.custom_minimum_size = Vector2(14, 14)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			obj_dots.add_child(dot)
	for i2 in mini(steps.size(), obj_dots.get_child_count()):
		var dn: bool = bool(steps[i2].done)
		(obj_dots.get_child(i2) as Panel).add_theme_stylebox_override("panel", UIK.sb(K.pal("green") if dn else K.pal("well"), 7, K.pal("green").darkened(0.2) if dn else K.pal("well").darkened(0.15), 2, 0))
	var hull: float = maxf(0.0, 100.0 * float(com.hull) / maxf(1.0, float(com.hull_max)))
	_chip_text(hull_chip, "Hull %d%%" % int(hull))
	var mood: float = float(com.mood)
	_chip_text(mood_chip, "Pudding: " + ("LOOSE!" if bool(com.get("loose", false)) else ("calm" if mood < 40.0 else ("twitchy" if mood < 70.0 else "PANIC"))))
	var run: Dictionary = d.get("run", {})
	_chip_text(temper_chip, "Overlord: %s" % str(run.get("temper_name", "Cross")))
	_chip_text(res_chip, "%d scrap · %d fuel" % [int(run.get("scrap", 0)), int(run.get("fuel", 0))])

func _chip_text(chip: PanelContainer, text: String) -> void:
	for l in chip.find_children("*", "Label", true, false):
		(l as Label).text = text

func _update_dock(seats: Array, act: String) -> void:
	var frees: Array = []
	var lob: Dictionary = Net.last_lobby
	for seat in K.SEATS:
		var s: Dictionary = lob.get("seats", {}).get(seat, {})
		if int(s.get("owner", 0)) == 0 and not lob.is_empty():
			frees.append(seat)
	var sig: String = ",".join(seats) + "|" + act + "|" + ",".join(frees)
	if sig == seat_sig:
		return
	seat_sig = sig
	for c in seat_row.get_children():
		c.queue_free()
	var i: int = 1
	for s2 in seats:
		var seat: String = s2
		var b: Button = UIK.btn(str(i), UIK.seat_color(seat) if seat == act else "neutral", func(): Net.send("active", {"seat": seat}), str(K.SEAT_INFO[seat].icon))
		b.tooltip_text = "%s (key %d)" % [K.seat_name(seat), i]
		b.custom_minimum_size = Vector2(64, 50)
		seat_row.add_child(b)
		i += 1
	if not seats.is_empty():
		var dc: Button = UIK.btn("F", "dc" if act == "dc" else "neutral", func(): Net.send("active", {"seat": "dc"}), "dc")
		dc.tooltip_text = "Damage Control (key F)"
		dc.custom_minimum_size = Vector2(64, 50)
		seat_row.add_child(dc)
	for c2 in free_row.get_children():
		c2.queue_free()
	if not frees.is_empty():
		free_row.add_child(UIK.label("Free:", 13, Color(1, 1, 1, 0.7)))
	for fs in frees:
		var fseat: String = fs
		var fb: Button = UIK.icon_btn(str(K.SEAT_INFO[fseat].icon), UIK.seat_color(fseat), func(): Net.send("claim", {"seat": fseat}), "Take the free %s seat" % K.seat_name(fseat))
		fb.custom_minimum_size = Vector2(46, 46)
		free_row.add_child(fb)

func _switch(want: String) -> void:
	current = want
	if cap_ui != null:
		cap_ui.visible = want == "captain"
		cap_ui.process_mode = Node.PROCESS_MODE_INHERIT if want == "captain" else Node.PROCESS_MODE_DISABLED
	for k in stations.keys():
		stations[k].visible = k == want
	if want == "captain":
		if cap_ui == null:
			cap_ui = CaptainUI.new()
			shell.add_child(cap_ui)
		cap_ui.visible = true
		cap_ui.process_mode = Node.PROCESS_MODE_INHERIT
	elif want != "":
		if not stations.has(want):
			var su: StationUI = Stations.make(want, false)
			stations[want] = su
			shell.add_child(su)
		stations[want].visible = true

func _update_overlay(d: Dictionary) -> void:
	var phase: String = str(d.get("phase", ""))
	var act: String = str(d.get("active", ""))
	var ph: Dictionary = d.get("ph", {})
	var is_cap: bool = act == "captain"
	var sig: String = ""
	match phase:
		"debrief":
			sig = "debrief" + str(ph.get("debrief", {}).get("title", "")) + str(ph.get("debrief", {}).get("time", ""))
		"gameover":
			sig = "gameover" + str(ph.get("over", {}).get("reason", ""))
		"ending":
			sig = "ending"
	if sig != "":
		sig += str(is_cap)
	if sig == overlay_sig:
		return
	overlay_sig = sig
	if overlay != null:
		overlay.queue_free()
		overlay = null
	var cont: Callable = func(): Net.send("cap", {"cmd": "continue"})
	var retry: Callable = func(): Net.send("cap", {"cmd": "retry"})
	var lob: Callable = func(): Net.send("cap", {"cmd": "lobby"})
	match phase:
		"debrief":
			overlay = Screens.debrief_panel(ph, is_cap, str(ph.get("mode", "run")), cont, retry, lob)
		"gameover":
			overlay = Screens.gameover_panel(ph, is_cap, str(ph.get("mode", "run")), cont, retry, lob)
		"ending":
			overlay = Screens.ending_panel(ph, is_cap, cont)
	if overlay != null:
		overlay.set_meta("overlay", true)
		shell.add_child(overlay)

# ---------------------------------------------------------------- events

func on_event(d: Dictionary) -> void:
	if not visible:
		return
	match str(d.get("t", "")):
		"igor":
			_igor(str(d.text))
			if cap_ui != null:
				cap_ui.on_igor()
		"toast":
			toast(str(d.text))
		"hail":
			if current != "captain":
				toast("%s: %s" % [d.from, d.text], "comms")
			Sfx.play("ding")
		"bark":
			if cap_ui != null and current == "captain":
				cap_ui.on_bark(str(d.text))
			else:
				toast(str(d.text), "robot")
		"order":
			order_lbl.text = str(d.text)
			order_card.visible = true
			order_t = 6.0
			Sfx.play("blip")
		"fx":
			if cap_ui != null:
				cap_ui.on_fx(d)
			if current != "captain":
				if d.get("fx", "") == "boom":
					Sfx.play("boom", randf_range(0.8, 1.2), -8.0)
				elif d.get("fx", "") == "alarm":
					Sfx.play("alarm")
		"encounter_start":
			Sfx.play("whoosh")
		"debrief":
			Sfx.play("ding")
		"gameover":
			Sfx.play("powerdown")

func _igor(text: String) -> void:
	igor_lbl.text = text
	igor_lbl.tooltip_text = text
	igor_t = 7.0 + float(text.length()) * 0.04
	var st: StyleBoxFlat = UIK.sb(K.pal("yellow").lightened(0.6), UIK.RADIUS, K.pal("sensors"), 3, 4)
	igor_box.add_theme_stylebox_override("panel", st)
	Sfx.speak(text)

func toast(text: String, icon_name: String = "warning") -> void:
	var p: PanelContainer = UIK.panel("card", 10, 14)
	var h: HBoxContainer = UIK.hbox(8)
	p.add_child(h)
	h.add_child(UIK.icon_rect(icon_name if UIK.icon(icon_name) != null else "warning", 20, K.pal("blue")))
	var l: Label = UIK.wrapped(UIK.label(text, 15))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.custom_minimum_size = Vector2(330, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	var tw: Tween = create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	while toast_box.get_child_count() > 4:
		var old: Node = toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()

func _process(delta: float) -> void:
	if igor_t > 0.0:
		igor_t -= delta
		if igor_t <= 0.0:
			igor_box.add_theme_stylebox_override("panel", UIK.sb(K.pal("card"), UIK.RADIUS, K.pal("sensors").darkened(0.1), 2, 4))
	if order_t > 0.0:
		order_t -= delta
		if order_t <= 0.0:
			order_card.visible = false

func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey):
		return
	var ke: InputEventKey = e
	if not ke.pressed or ke.echo:
		return
	var seats: Array = last.get("seats", [])
	if ke.keycode >= KEY_1 and ke.keycode <= KEY_7:
		var i: int = ke.keycode - KEY_1
		if i < seats.size():
			Net.send("active", {"seat": seats[i]})
			get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_F and not seats.is_empty():
		Net.send("active", {"seat": "dc"})
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE:
		pause_panel.visible = not pause_panel.visible

func reset() -> void:
	for k in stations.keys():
		stations[k].queue_free()
	stations.clear()
	if cap_ui != null:
		cap_ui.queue_free()
		cap_ui = null
	if overlay != null:
		overlay.queue_free()
		overlay = null
	if briefing != null:
		briefing.queue_free()
		briefing = null
	current = ""
	seat_sig = ""
	overlay_sig = ""
	pause_panel.visible = false
