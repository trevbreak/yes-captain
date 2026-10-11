class_name GameUI
extends Control
## In-game shell: the active station (or the captain's bridge), seat tabs, IGOR's subtitles,
## toasts, order cards and the phase overlays (debrief, game over, ending).

signal leave_pressed

var cap_ui: CaptainUI = null
var stations: Dictionary = {}
var current: String = ""
var tab_bar: HBoxContainer
var tab_sig: String = ""
var tab_btns: Dictionary = {}
var igor_panel: PanelContainer
var igor_lbl: Label
var igor_t: float = 0.0
var toast_box: VBoxContainer
var order_lbl: Label
var order_t: float = 0.0
var overlay: Control = null
var overlay_sig: String = ""
var hud: HBoxContainer
var hud_hull: BarGauge
var hud_mood: BarGauge
var hud_temper: Label
var hud_title: Label
var free_row: HBoxContainer
var free_sig: String = ""
var spectate_lbl: Label
var last: Dictionary = {}
var shell: Control
var pause_panel: PanelContainer
var hail_lbl: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	UIK.bg_color(self, K.pal("plum").darkened(0.15))
	shell = Control.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_top = 38
	shell.offset_bottom = -112
	add_child(shell)
	# top HUD (hidden for the captain, who has dials)
	hud = UIK.hbox(10)
	hud.position = Vector2(10, 4)
	hud.size = Vector2(1260, 32)
	add_child(hud)
	hud_title = UIK.label("", 17, K.pal("cream"))
	hud_title.custom_minimum_size = Vector2(300, 0)
	hud.add_child(hud_title)
	hud.add_child(UIK.label("HULL", 14, K.pal("cream")))
	hud_hull = BarGauge.new("", 100.0, K.pal("green"))
	hud_hull.custom_minimum_size = Vector2(170, 22)
	hud.add_child(hud_hull)
	hud.add_child(UIK.label("PUDDING", 14, K.pal("cream")))
	hud_mood = BarGauge.new("", 100.0, K.pal("pink"))
	hud_mood.danger_above = 80.0
	hud_mood.custom_minimum_size = Vector2(150, 22)
	hud.add_child(hud_mood)
	hud_temper = UIK.label("", 15, K.pal("butter"))
	hud.add_child(hud_temper)
	# bottom: IGOR subtitles, seat tabs
	igor_panel = UIK.panel("gunmetal", 6, 14)
	igor_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	igor_panel.offset_top = -118
	igor_panel.offset_bottom = -62
	igor_panel.offset_left = 10
	igor_panel.offset_right = -10
	igor_lbl = UIK.label("", 18, K.pal("mint"))
	igor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	igor_panel.add_child(igor_lbl)
	igor_panel.modulate.a = 0.0
	add_child(igor_panel)
	tab_bar = UIK.hbox(8)
	tab_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tab_bar.offset_top = -58
	tab_bar.offset_bottom = -4
	tab_bar.offset_left = 10
	tab_bar.offset_right = -10
	add_child(tab_bar)
	free_row = UIK.hbox(6)
	toast_box = UIK.vbox(4)
	toast_box.position = Vector2(930, 300)
	toast_box.size = Vector2(330, 160)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	order_lbl = UIK.label("", 24, K.pal("ink"), 1)
	order_lbl.add_theme_stylebox_override("normal", UIK.box(K.pal("butter"), K.pal("ink"), 16, 4, 10))
	order_lbl.position = Vector2(320, 44)
	order_lbl.size = Vector2(640, 0)
	order_lbl.visible = false
	add_child(order_lbl)
	hail_lbl = UIK.label("", 16, K.pal("mint"))
	spectate_lbl = UIK.label("You have no seat. Pick a free one at the top, or watch the chaos.", 22, K.pal("cream"), 1)
	spectate_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	spectate_lbl.visible = false
	add_child(spectate_lbl)
	_build_pause()
	Net.snapshot.connect(on_snapshot)
	Net.event.connect(on_event)

func _build_pause() -> void:
	pause_panel = UIK.panel("cream", 16, 22)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(380, 0)
	pause_panel.position = Vector2(450, 200)
	pause_panel.visible = false
	var v: VBoxContainer = UIK.vbox(8)
	pause_panel.add_child(v)
	v.add_child(UIK.label("PAUSE MENU", 24))
	v.add_child(UIK.label("(The ship does NOT pause. IGOR does not allow it.)", 14, Color(K.pal("ink"), 0.7)))
	var snd: Button = UIK.toggle_btn("Sound", "butter", func(on: bool): Sfx.enabled = on)
	snd.button_pressed = Sfx.enabled
	v.add_child(snd)
	var tts: Button = UIK.toggle_btn("IGOR's voice", "butter", func(on: bool): Sfx.tts_on = on)
	tts.button_pressed = Sfx.tts_on
	v.add_child(tts)
	v.add_child(UIK.btn("Resume", "green", func(): pause_panel.visible = false))
	v.add_child(UIK.btn("Leave the game", "coral", func(): leave_pressed.emit()))
	add_child(pause_panel)

# ---------------------------------------------------------------- snapshots

func on_snapshot(d: Dictionary) -> void:
	if not visible or not d.has("common"):
		return
	last = d
	var act: String = str(d.get("active", ""))
	var seats: Array = d.get("seats", [])
	_update_tabs(seats, act, d)
	var com: Dictionary = d.common
	var phase: String = str(d.get("phase", ""))
	# HUD
	hud.visible = act != "captain" and act != ""
	hud_hull.value = 100.0 * float(com.hull) / maxf(1.0, float(com.hull_max))
	hud_hull.text = "%d%%" % int(hud_hull.value)
	hud_mood.value = float(com.mood)
	hud_title.text = "%s  %s" % [str(com.get("title", "")), K.fmt_time(float(com.get("t", 0.0)))] if phase == "encounter" else str(com.get("ship_name", ""))
	var run: Dictionary = d.get("run", {})
	hud_temper.text = "Overlord: %s   Fuel %d  Scrap %d" % [str(run.get("temper_name", "")), int(run.get("fuel", 0)), int(run.get("scrap", 0))]
	spectate_lbl.visible = act == ""
	# which view?
	var want: String = act
	if current != want:
		_switch(want)
	if act == "captain" and cap_ui != null:
		cap_ui.apply(d.view, d)
	elif act != "" and stations.has(act):
		var su: StationUI = stations[act]
		su.apply(d.view, d)
		var sh: float = float(com.get("shake", 0.0))
		su.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * sh * 5.0 if sh > 0.05 else Vector2.ZERO
	_update_overlay(d)

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
			cap_ui.offset_top = -38
			cap_ui.offset_bottom = 112
		cap_ui.visible = true
		cap_ui.process_mode = Node.PROCESS_MODE_INHERIT
	elif want != "":
		if not stations.has(want):
			var su: StationUI = Stations.make(want, false)
			stations[want] = su
			shell.add_child(su)
		stations[want].visible = true

func _free_seats() -> Array:
	var lob: Dictionary = Net.last_lobby
	var frees: Array = []
	for seat in K.SEATS:
		var s: Dictionary = lob.get("seats", {}).get(seat, {})
		if int(s.get("owner", 0)) == 0 and not lob.is_empty():
			frees.append(seat)
	return frees

func _update_tabs(seats: Array, act: String, d: Dictionary) -> void:
	var frees: Array = _free_seats()
	var sig: String = ",".join(seats) + "|" + act + "|" + ",".join(frees)
	if sig != tab_sig:
		tab_sig = sig
		for c in tab_bar.get_children():
			c.queue_free()
		tab_btns.clear()
		var i: int = 1
		for s in seats:
			var seat: String = s
			var b: Button = UIK.btn("%d  %s" % [i, K.seat_name(seat)], K.SEAT_INFO[seat].color, func(): Net.send("active", {"seat": seat}))
			if seat == act:
				b.add_theme_font_size_override("font_size", 22)
			b.custom_minimum_size = Vector2(112, 0)
			tab_bar.add_child(b)
			tab_btns[seat] = b
			i += 1
		if not seats.is_empty():
			var dc: Button = UIK.btn("F  Damage Ctrl", "mustard", func(): Net.send("active", {"seat": "dc"}))
			if act == "dc":
				dc.add_theme_font_size_override("font_size", 22)
			dc.custom_minimum_size = Vector2(150, 0)
			tab_bar.add_child(dc)
		tab_bar.add_child(UIK.spacer(true))
		if not frees.is_empty():
			tab_bar.add_child(UIK.label("Free:", 14, K.pal("cream")))
			for fs in frees:
				var fseat: String = fs
				var fb: Button = UIK.btn("+ " + K.seat_name(fseat), K.SEAT_INFO[fseat].color, func(): Net.send("claim", {"seat": fseat}))
				fb.add_theme_font_size_override("font_size", 14)
				tab_bar.add_child(fb)
		tab_bar.add_child(UIK.btn("Menu", "cream2", func(): pause_panel.visible = not pause_panel.visible))

func _update_free(d: Dictionary) -> void:
	var lob: Dictionary = Net.last_lobby
	var sig: String = str(lob.get("seats", {}).keys().size())
	var frees: Array = []
	for seat in K.SEATS:
		var s: Dictionary = lob.get("seats", {}).get(seat, {})
		if int(s.get("owner", 0)) == 0 and (seat != "captain" or true):
			frees.append(seat)
	var sg: String = ",".join(frees)
	if sg == free_sig:
		return
	free_sig = sg
	for c in free_row.get_children():
		c.queue_free()
	if frees.is_empty():
		return
	free_row.add_child(UIK.label("Free seats:", 14, K.pal("cream")))
	for seat2 in frees:
		var sn: String = seat2
		var b: Button = UIK.btn("+ " + K.seat_name(sn), K.SEAT_INFO[sn].color, func(): Net.send("claim", {"seat": sn}))
		b.add_theme_font_size_override("font_size", 14)
		free_row.add_child(b)

func _update_overlay(d: Dictionary) -> void:
	var phase: String = str(d.get("phase", ""))
	var act: String = str(d.get("active", ""))
	var ph: Dictionary = d.get("ph", {})
	if act == "captain":
		if overlay != null:
			overlay.queue_free()
			overlay = null
			overlay_sig = ""
		return
	var sig: String = phase
	if phase == "debrief":
		sig += str(ph.get("debrief", {}).get("title", "")) + str(ph.get("debrief", {}).get("ok", ""))
	elif phase == "gameover":
		sig += str(ph.get("over", {}).get("reason", ""))
	if phase not in ["debrief", "gameover", "ending"]:
		sig = ""
	if sig == overlay_sig:
		return
	overlay_sig = sig
	if overlay != null:
		overlay.queue_free()
		overlay = null
	match phase:
		"debrief":
			overlay = Screens.debrief_panel(ph, false, "run", Callable(), Callable(), Callable())
		"gameover":
			overlay = Screens.gameover_panel(ph, false, "run", Callable(), Callable(), Callable())
		"ending":
			overlay = Screens.ending_panel(ph, false, Callable())
	if overlay != null:
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
			toast("%s: %s" % [d.from, d.text])
			Sfx.play("ding")
		"bark":
			if cap_ui != null:
				cap_ui.on_bark(str(d.text))
			toast(str(d.text))
		"order":
			order_lbl.text = "CAPTAIN: %s" % str(d.text)
			order_lbl.visible = true
			order_t = 6.0
			Sfx.play("blip")
		"fx":
			if cap_ui != null:
				cap_ui.on_fx(d)
			elif d.get("fx", "") == "boom":
				Sfx.play("boom", randf_range(0.8, 1.2), -8.0)
			elif d.get("fx", "") == "alarm":
				Sfx.play("alarm")
		"encounter_start":
			toast("New encounter: %s" % d.title)
			Sfx.play("ding")
		"debrief":
			Sfx.play("ding")
		"gameover":
			Sfx.play("powerdown")

func _igor(text: String) -> void:
	igor_lbl.text = "IGOR: " + text
	igor_panel.modulate.a = 1.0
	igor_t = 6.5 + float(text.length()) * 0.04
	Sfx.speak(text)

func toast(text: String) -> void:
	var l: Label = UIK.label(text, 15, K.pal("ink"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	l.add_theme_stylebox_override("normal", UIK.box(K.pal("cream"), K.pal("ink"), 10, 3, 6))
	toast_box.add_child(l)
	var tw: Tween = create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	while toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))

func _process(delta: float) -> void:
	if igor_t > 0.0:
		igor_t -= delta
		if igor_t <= 0.0:
			var tw: Tween = create_tween()
			tw.tween_property(igor_panel, "modulate:a", 0.0, 0.5)
	if order_t > 0.0:
		order_t -= delta
		if order_t <= 0.0:
			order_lbl.visible = false

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
	current = ""
	tab_sig = ""
	overlay_sig = ""
	free_sig = ""
	pause_panel.visible = false
