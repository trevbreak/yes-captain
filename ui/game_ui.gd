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
var content: BoxContainer
var stations: Dictionary = {}
var wraps: Dictionary = {}          # seat -> the FitBox its screen sits in (captain too)
var cap_ui: CaptainUI
var hint_bar: HBoxContainer        # a crew role: both stations' "your job now", side by side over the desks
var hint_bits: Array = []           # [{chip, label, odd}] one per station
var _focus: String = ""             # a combined screen: the half that hears the keyboard
var _shown: Array = []
var sideways: Control              # "turn your phone sideways": in-game screens are landscape only
var _shell: Control
var _portrait: bool = false
var join_panel: PanelContainer      # watching mid-shift: take over a role from a robot
var join_row: HBoxContainer
var _join_sig: String = ""
var desks: Dictionary = {}          # role -> RoleDesk: a crew role's two stations on one console
var _desk: String = ""              # the role desk on screen ("" = a single station, or the captain)
var top_bar: HBoxContainer
var dock_bar: HBoxContainer
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
	_shell = m
	# ---- top bar
	var top: HBoxContainer = UIK.hbox(12)
	top.custom_minimum_size = Vector2(0, TOP_H)
	root.add_child(top)
	top_bar = top
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
	# ---- what a crew role is doing now: one line per station, colour-coded
	hint_bar = UIK.hbox(10)
	hint_bar.visible = false
	root.add_child(hint_bar)
	for i in 2:
		var hp: PanelContainer = UIK.panel("panel_small", [4, 0, 4, 0])
		hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_bar.add_child(hp)
		var hr: HBoxContainer = UIK.hbox(8)
		hp.add_child(hr)
		var chip: PanelContainer = UIK.chip("", "cream", "", 15)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(chip)
		var hl: Label = UIK.para("", 18)
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl.max_lines_visible = 2
		hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hr.add_child(hl)
		var odd: PanelContainer = UIK.chip("SOMETHING'S NOT RIGHT", "purple", "question", 14)
		odd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		odd.tooltip_text = "This station has a glitch. Tell the captain what's odd. The Tech has the manual."
		odd.mouse_filter = Control.MOUSE_FILTER_PASS
		odd.visible = false
		hr.add_child(odd)
		hint_bits.append({"chip": chip, "label": hl, "odd": odd})
	# ---- station area: each screen in a FitBox, so a small or odd-shaped screen shrinks it rather than
	# spilling controls over each other. A crew role's two stations sit side by side (stacked on a tall screen).
	content = BoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	cap_ui = CaptainUI.new()
	cap_ui.menu_pressed.connect(_toggle_pause)
	_wrap("captain", cap_ui)
	for st in K.STATIONS:
		var ui: Station = RoleDesk._make(st)
		ui.focus_wanted.connect(_set_focus)
		_wrap(st, ui)
		stations[st] = ui
	for rid in K.ROLES:
		var dk: RoleDesk = RoleDesk.new(rid)
		dk.focus_wanted.connect(_set_focus)
		_wrap("role_" + rid, dk)
		desks[rid] = dk
	# ---- dock
	var dock: HBoxContainer = UIK.hbox(10)
	dock.custom_minimum_size = Vector2(0, DOCK_H)
	root.add_child(dock)
	dock_bar = dock
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
	_build_join()
	_build_sideways()
	Net.snapshot.connect(on_snapshot)
	Net.event.connect(on_event)

func _wrap(st: String, ui: Control) -> void:
	var fb: FitBox = FitBox.new()
	fb.visible = false
	content.add_child(fb)
	fb.add_child(ui)
	wraps[st] = fb

func _st(seat: String) -> Station:
	## the Station showing this seat right now: on the role desk when there is one
	if _desk != "" and (desks[_desk] as RoleDesk).stations.has(seat):
		return (desks[_desk] as RoleDesk).stations[seat]
	return stations.get(seat)     # null for the captain

func _all_stations() -> Array:
	var out: Array = stations.values()
	for dk in desks.values():
		out.append_array((dk as RoleDesk).stations.values())
	return out

func _build_join() -> void:
	join_panel = UIK.panel("panel_small", [6, 4, 6, 4])
	join_panel.set_meta("overlay", true)
	join_panel.z_index = 30
	join_panel.visible = false
	join_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	join_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	join_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	join_panel.offset_bottom = -200
	add_child(join_panel)
	var v: VBoxContainer = UIK.vbox(6)
	join_panel.add_child(v)
	v.add_child(UIK.head("YOU'RE WATCHING. JOIN IN?", 22, UIK.c("red")))
	v.add_child(UIK.para("A robot is playing these. Tap one and it's yours, right now.", 18, K.pal("ink_soft")))
	join_row = UIK.hbox(10)
	join_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(join_row)

func _update_join(seats: Array, phase: String) -> void:
	## the roles a robot is playing, offered to whoever is only watching
	var free: Array = []
	if seats.is_empty() and phase != "lobby" and phase != "":
		var ls: Dictionary = Net.last_lobby.get("seats", {})
		for rid in K.ROLES:
			var st: Dictionary = ls.get(str(K.ROLES[rid].seats[0]), {})
			if int(st.get("owner", 0)) == 0:
				free.append(rid)
	var sig: String = ",".join(PackedStringArray(free))
	join_panel.visible = not free.is_empty() and not _portrait
	if sig == _join_sig:
		return
	_join_sig = sig
	for c in join_row.get_children():
		c.queue_free()
	for rid2 in free:
		var b: Button = UIK.btn("Take the %s" % K.role_name(rid2), K.role_color(rid2), func(): Net.send("claim", {"seat": rid2}), K.role_icon(rid2), 20)
		b.custom_minimum_size = Vector2(0, 64)
		join_row.add_child(b)

func _build_sideways() -> void:
	sideways = Control.new()
	sideways.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sideways.set_meta("overlay", true)
	sideways.z_index = 45
	sideways.visible = false
	add_child(sideways)
	var bg: ColorRect = ColorRect.new()
	bg.color = K.pal("navy")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sideways.add_child(bg)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sideways.add_child(cc)
	var v: VBoxContainer = UIK.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var ic: TextureRect = UIK.pic("ship_ours", Vector2(150, 195))
	ic.rotation = deg_to_rad(90)
	ic.pivot_offset = Vector2(75, 97)
	v.add_child(UIK.center(ic))
	v.add_child(UIK.title("TURN SIDEWAYS", 64, UIK.c("mustard"), HORIZONTAL_ALIGNMENT_CENTER))
	var t: Label = UIK.para("Your desk needs both thumbs. Turn your phone on its side.", 28, K.pal("cream"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(560, 0)
	v.add_child(t)
	var fb: Button = UIK.btn("Go full screen", "cream", func(): Web.toggle_fullscreen(true), "", 26)
	fb.custom_minimum_size = Vector2(380, 70)
	fb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(fb)

func set_portrait(p: bool) -> void:
	## in-game screens are made for landscape: upright, cover them with the "turn sideways" card
	_portrait = p
	sideways.visible = p
	_shell.visible = not p
	if p:
		briefing_ui.visible = false
		board_ui.visible = false
		if overlay != null:
			overlay.visible = false
	elif overlay != null:
		overlay.visible = true
	_fit_direction()

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
	# the four switches two by two, so the menu fits a short phone screen with finger-sized buttons
	var tg: GridContainer = GridContainer.new()
	tg.columns = 2
	tg.add_theme_constant_override("h_separation", 8)
	tg.add_theme_constant_override("v_separation", 8)
	b.add_child(tg)
	var snd: Button = UIK.toggle("Sound", "green", func(on: bool): UIK.set_sound(on), "speaker")
	snd.button_pressed = UIK.sound_on()
	var voice: Button = UIK.toggle("IGOR's voice", "green", func(on: bool): UIK.set_voice(on), "robot")
	voice.button_pressed = UIK.voice_on()
	var mus: Button = UIK.toggle("Music", "green", func(on: bool): UIK.set_music(on), "speaker")
	mus.button_pressed = UIK.music_on()
	var grain: Button = UIK.toggle("Film grain", "green", func(on: bool): UIK.set_grain(on), "eye")
	grain.button_pressed = Film.enabled
	for t in [snd, voice, mus, grain]:
		(t as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tg.add_child(t)
	b.add_child(UIK.btn("Keys", "cream", _open_keys, "menu"))
	b.add_child(UIK.btn("Back to the game", "green", _toggle_pause, "play"))
	b.add_child(UIK.btn("Leave the game", "red", func():
		pause_panel.visible = false
		leave_pressed.emit(), "back"))

func _process(dt: float) -> void:
	# IGOR's face settles back down a few seconds after he's said his piece
	_igor_t += dt
	if _igor_t > 4.5 and igor_pic.mood != "":
		igor_pic.set_mood("", false)

# ---------------------------------------------------------------- rebinding keys

var keys_panel: Control = null
var _rebind: Array = []          # [station, default key, the button showing it] while waiting for a key

func _open_keys() -> void:
	## your own desk's actions and their keys; tap one, press a new key
	if keys_panel != null:
		keys_panel.queue_free()
	keys_panel = Control.new()
	keys_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	keys_panel.set_meta("overlay", true)
	keys_panel.z_index = 50
	add_child(keys_panel)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	keys_panel.add_child(dim)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	keys_panel.add_child(cc)
	var w: Array = UIK.window("KEYS", "navy", "menu")
	(w[0] as Control).custom_minimum_size = Vector2(620, 0)
	cc.add_child(w[0])
	var b: VBoxContainer = w[1]
	var mine: Array = Net.last_snapshot.get("seats", [])
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	var any: bool = false
	for st in mine:
		if not Keys.ACTIONS.has(str(st)):
			continue
		any = true
		for act in Keys.ACTIONS[str(st)]:
			var l: Label = UIK.label("%s: %s" % [K.seat_name(str(st)), str(act[1])], 20)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(l)
			var kb: Button = UIK.btn(Keys.hint(str(st), act[0]), "cream", Callable(), "", 20)
			kb.custom_minimum_size = Vector2(150, 0)
			kb.pressed.connect(func():
				_rebind = [str(st), act[0], kb]
				kb.text = "PRESS A KEY...")
			grid.add_child(kb)
	if any:
		b.add_child(grid)
	else:
		b.add_child(UIK.para("Take a seat to set its keys.", 20))
	var r: HBoxContainer = UIK.hbox(10)
	b.add_child(r)
	r.add_child(UIK.btn("Reset to defaults", "cream", func():
		Keys.reset()
		_keys_changed()
		_open_keys(), "", 18))
	var done: Button = UIK.btn("Done", "green", func():
		_rebind = []
		keys_panel.queue_free()
		keys_panel = null, "check", 20)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(done)

func _input(e: InputEvent) -> void:
	# waiting for the new key for an action
	if _rebind.is_empty() or not (e is InputEventKey) or not (e as InputEventKey).pressed or (e as InputEventKey).echo:
		return
	get_viewport().set_input_as_handled()
	var k: Key = (e as InputEventKey).physical_keycode
	var kb: Button = _rebind[2]
	if k == KEY_ESCAPE:
		kb.text = Keys.hint(str(_rebind[0]), _rebind[1])
	elif k in Keys.RESERVED:
		kb.text = "TAKEN, TRY ANOTHER"
		return
	else:
		Keys.bind(str(_rebind[0]), _rebind[1], k)
		kb.text = Keys.hint(str(_rebind[0]), _rebind[1])
		_keys_changed()
	_rebind = []

func _keys_changed() -> void:
	for st in _all_stations():
		(st as Station).refresh_keys()

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
			if K.combined(mine):
				_set_focus(str(mine[1]) if _focus == str(mine[0]) else str(mine[0]))
			else:
				_flip()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_M and Voice.active:
			Voice.set_muted(not Voice.muted)
			get_viewport().set_input_as_handled()
			return
		var idx: int = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7].find(k)
		if idx >= 0 and idx < K.SEATS.size() and K.SEATS[idx] in mine:
			if K.combined(mine):
				_set_focus(K.SEATS[idx])
			else:
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

func _set_focus(st: String) -> void:
	## a combined screen: the keyboard goes to the half you last touched (or picked with F)
	if not (st in _shown) or _shown.size() < 2:
		return
	if st != _focus:
		UIK.sfx("clack")
	_focus = st
	for s2 in _shown:
		_st(s2).set_keys_on(_desk != "" or s2 == _focus)

func reset() -> void:
	_active = ""
	_focus = ""
	_shown = []
	_desk = ""
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
		for st in _all_stations():
			(st as Station).release_all()
	briefing_ui.visible = phase == "briefing" and not _portrait
	board_ui.visible = phase == "board" and not _portrait
	content.visible = phase != "briefing" and phase != "board"
	hint_bar.visible = false
	if phase == "briefing":
		briefing_ui.apply(d.get("phase_data", {}), seats)
	if phase == "board":
		board_ui.apply(d.get("phase_data", {}))
		return
	_update_join(seats, phase)
	var view_seat: String = act if act != "" else "captain"
	var both: bool = K.combined(seats)
	var shown: Array = [str(seats[0]), str(seats[1])] if both else [view_seat]
	var who: String = str(d.get("name", ""))
	hint_bar.visible = both and content.visible
	var vsig: String = ",".join(PackedStringArray(shown)) + "/" + who + "/" + str(act != "")
	if vsig != _active:
		_active = vsig
		_shown = shown
		var rid: String = K.role_of(shown[0]) if both else ""
		_desk = rid if (rid != "" and rid == K.role_of(shown[1]) and desks.has(rid)) else ""
		# the captain's bridge is the whole screen: its own title plaque, IGOR on the viewscreen, no dock
		top_bar.visible = view_seat != "captain"
		dock_bar.visible = view_seat != "captain"
		for st in wraps.keys():
			wraps[st].visible = (st == "role_" + _desk) if _desk != "" else (st in shown)
		var live: Array = []
		for st1 in shown:
			if _st(st1) != null:
				live.append(_st(st1))
		for stn in _all_stations():
			if not (stn in live):
				(stn as Station).release_all()
		if both:
			if not (_focus in shown):
				_focus = view_seat if view_seat in shown else shown[0]
			for st3 in shown:
				# a role desk's keys never clash, so both halves listen; two odd stations take turns
				_st(st3).set_keys_on(_desk != "" or st3 == _focus)
				_st(st3).set_compact(true)
			for i in 2:
				UIK.set_chip(hint_bits[i].chip, K.seat_name(shown[i]).to_upper(), str(K.SEAT_INFO[shown[i]].color))
		else:
			_focus = ""
			if stations.has(view_seat):
				_st(view_seat).set_keys_on(true)
				_st(view_seat).set_compact(false)
		_fit_direction()
		var info: Dictionary = K.SEAT_INFO.get(view_seat, {})
		top_pic.set_who(K.role_face(shown[0]) if _desk != "" else shown[0])
		if both:
			top_role.text = _pair_name(shown)
			top_role.add_theme_color_override("font_color", UIK.c(K.role_color(_desk)).darkened(0.2) if _desk != "" else K.seat_color(shown[0]).darkened(0.2))
		else:
			top_role.text = str(info.get("name", "")).to_upper()
			top_role.add_theme_color_override("font_color", K.seat_color(view_seat).darkened(0.2))
		# your own name stays put whatever seat you're in (the seat's character comes with the seat)
		if act == "":
			top_persona.text = ("%s  (watching)" % who) if who != "" else "(watching)"
		elif both:
			top_persona.text = ("%s as %s" % [who, K.role_persona(shown[0])]) if _desk != "" else "%s: %s and %s" % [who, K.seat_name(shown[0]).to_lower(), K.seat_name(shown[1]).to_lower()]
		elif who != "":
			top_persona.text = "%s as %s" % [who, str(info.get("persona", ""))]
		else:
			top_persona.text = str(info.get("persona", ""))
	var sig: String = ",".join(PackedStringArray(seats)) + "/" + act
	if sig != _seats_sig:
		_seats_sig = sig
		_build_dock(seats, act)
	cap_ui.set_seats(seats, act)
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
	if both and d.has("views"):
		var views: Dictionary = d.get("views", {})
		var hints: Dictionary = d.get("hints", {})
		var odd: Dictionary = d.get("odd", {})
		for i2 in shown.size():
			var st4: String = shown[i2]
			var c2: Dictionary = com.duplicate()
			c2["hint"] = str(hints.get(st4, com.get("hint", "")))
			c2["glitchy"] = bool(odd.get(st4, false))
			_st(st4).apply(views.get(st4, {}), c2)
			(hint_bits[i2].label as Label).text = str(c2.hint)
			(hint_bits[i2].label as Label).tooltip_text = str(c2.hint)
			(hint_bits[i2].odd as Control).visible = bool(c2.glitchy)
	elif view_seat == "captain":
		cap_ui.apply(v, com)
	elif stations.has(view_seat):
		_st(view_seat).apply(v, com)
	if phase == "debrief":
		var pd: Dictionary = d.get("phase_data", {})
		var dsig: String = "%s/%s" % [str(pd.get("title", "")), str(pd.get("can_continue", false))]
		if dsig != _debrief_sig:
			_debrief_sig = dsig
			_clear_overlay()
			overlay = Screens.debrief(pd, func(): Net.send("next"), func(): Net.send("retry"), func(): Net.send("lobby"), func(): Net.send("shuffle"))
			overlay.z_index = 25
			overlay.visible = not _portrait
			add_child(overlay)
			move_child(overlay, pause_panel.get_index())

func _fit_direction() -> void:
	## a crew role's two desks: side by side on a wide screen, one above the other on a tall one
	var vp: Vector2 = get_viewport_rect().size
	var tall: bool = vp.y > vp.x
	if _desk != "":
		content.vertical = false
		(desks[_desk] as RoleDesk).set_vertical(tall)
	else:
		content.vertical = _shown.size() == 2 and tall

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and content != null:
		_fit_direction()

func _pair_name(shown: Array) -> String:
	var r: String = K.role_of(str(shown[0]))
	if r != "" and r == K.role_of(str(shown[1])):
		return K.role_name(r).to_upper()
	return "%s + %s" % [K.seat_name(str(shown[0])).to_upper(), K.seat_name(str(shown[1])).to_upper()]

func _build_dock(seats: Array, act: String) -> void:
	for c in dock_seats.get_children():
		c.queue_free()
	if seats.size() <= 1 or K.combined(seats):
		return     # one screen, or both of them on it: nothing to flip to
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
			cap_ui.say(who, str(d.get("text", "")), int(d.get("prio", 1)))
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
					Web.buzz(70)
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
	if "captain" in _shown:
		cap_ui.toast(text, col)
	if text.length() > 34:
		text = text.left(33) + "…"
	UIK.set_chip(toast_chip, text, col)
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	toast_chip.modulate.a = 1.0
	_toast_tw = toast_chip.create_tween()
	_toast_tw.tween_interval(3.0)
	_toast_tw.tween_property(toast_chip, "modulate:a", 0.0, 0.5)
