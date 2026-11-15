extends Node
## Entry point: title card -> (the Depot, on a server) -> Crew Room -> IGOR's briefing -> the mission -> debrief.
## With --server it is the public server instead: a Hub of rooms and no screen at all.
## Also hosts the automated UI checks (--autotest, --layoutcheck, --exercise, --tour, --clienttest).

var layer: CanvasLayer
var root_ui: Control
var menu: MenuUI
var sessions: SessionsUI
var lobby: LobbyUI
var game: GameUI
var state: String = "menu"
var args: Dictionary = {}
var layout_issues: Array = []

func _ready() -> void:
	_read_args()
	UIK.touch_ui = DisplayServer.is_touchscreen_available() or args.has("touchui")
	if args.has("server"):
		_run_server()
		return
	if args.has("mock"):
		_mock.call_deferred()
		return
	get_window().title = "Yes, Captain!"
	# a desktop window shouldn't shrink past usable; test runs may go phone-sized (--resolution 390x844)
	# (never in a browser: there the "window" is the page, and a minimum wider than a phone pushes the game off-screen)
	if not Web.on() and not (args.has("layoutcheck") or args.has("menushot") or args.has("touchtest") or args.has("phoneshots")):
		get_window().min_size = Vector2i(1024, 600)
	layer = CanvasLayer.new()
	add_child(layer)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.theme = UIK.theme()
	layer.add_child(root_ui)
	menu = MenuUI.new()
	menu.host_pressed.connect(_on_host)
	menu.solo_pressed.connect(_on_solo)
	menu.online_pressed.connect(_on_online)
	menu.quit_pressed.connect(func(): get_tree().quit())
	_screen(menu)
	sessions = SessionsUI.new()
	sessions.leave_pressed.connect(_leave)
	sessions.visible = false
	_screen(sessions)
	lobby = LobbyUI.new()
	lobby.leave_pressed.connect(_leave_room)
	lobby.visible = false
	_screen(lobby)
	game = GameUI.new()
	game.leave_pressed.connect(_leave_room)
	game.visible = false
	_screen(game)
	var fx: Fx = Fx.new()
	fx.target = root_ui
	add_child(fx)
	add_child(Film.new())
	var ex: Explain = Explain.new()
	ex.name = "Explain"
	add_child(ex)
	Net.event.connect(_on_event)
	Net.join_failed.connect(func(r: String):
		_show("menu")
		menu.show_msg(r))
	Net.disconnected.connect(func(r: String):
		_hide_reconnect()
		_leave()
		menu.show_msg(r))
	Net.reconnecting.connect(_show_reconnect)
	Net.reconnected.connect(func():
		_rejoining = true
		_hide_reconnect())
	_build_reconnect()
	UIK.last_input = "touch" if DisplayServer.is_touchscreen_available() else "mouse"
	_apply_args()
	get_tree().root.size_changed.connect(_orient)
	_orient()
	# the title screen has its music too (browsers hold it back until the first click; then it starts)
	UIK.music("menu")

func _input(e: InputEvent) -> void:
	# touch, mouse or keys: show the hints for whichever the player is using now
	if UIK.note_input(e):
		get_tree().call_group("input_hints", "queue_redraw")
		get_tree().call_group("input_hints_labels", "_on_input_kind")

func _process(delta: float) -> void:
	Voice.poll(delta)

func _read_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"

func _run_server() -> void:
	## the public server: no window, no art, just rooms
	Progress.persist = false
	var port: int = int(args.get("port", OS.get_environment("YC_PORT") if OS.get_environment("YC_PORT") != "" else str(K.PORT_DEFAULT)))
	var max_rooms: int = int(OS.get_environment("MAX_ROOMS")) if OS.get_environment("MAX_ROOMS") != "" else 20
	var err: Error = Net.start_server(port, clampi(max_rooms, 1, 200))
	print("Yes, Captain! server on port %d, up to %d rooms (err %d)" % [port, max_rooms, err])
	if err != OK:
		get_tree().quit(1)
	if TtsServer.available():
		var tts: TtsServer = TtsServer.new()
		add_child(tts)
		tts.start(int(OS.get_environment("YC_TTS_PORT")) if OS.get_environment("YC_TTS_PORT") != "" else TtsServer.PORT)

func _apply_args() -> void:
	if args.has("targets"):
		LayoutCheck.min_target = float(args.targets)
	if args.has("autotest") or args.has("layoutcheck") or args.has("tour") or args.has("readmeshots") or args.has("shiftshots") or args.has("captainshots") or args.has("pairshots") or args.has("touchtest") or args.has("phoneshots"):
		Progress.persist = false
		Progress.forget_local()
		Progress.local().unlock_all()
	if args.has("shots"):
		# macOS stops redrawing covered windows, which freezes screenshots: keep the test window on top
		get_window().always_on_top = true
	if args.has("chartstyle"):
		Chart.STYLE = str(args.chartstyle)
	if args.has("nograin"):
		UIK.set_grain(false)
	if args.has("host"):
		_on_host("Captain")
	elif args.has("solo"):
		_on_solo("Captain")
	elif args.has("join"):
		var addr: String = str(args.join)
		_on_online(str(args.get("name", "Crew")), "ws://%s" % (addr if ":" in addr else "%s:%s" % [addr, str(args.get("port", K.PORT_DEFAULT))]))
	if args.has("room"):
		Net.want_room = str(args.room).to_upper()
	elif Web.room_param() != "":
		# an invite link: sign in with the saved name and go straight to that crew room
		Net.want_room = Web.room_param()
		if str(Web.setting("name", "")) != "":
			_on_online(str(Web.setting("name", "")), Web.server_url())
		else:
			menu.show_msg("You've been invited to crew %s. Type a name and find a crew!" % Net.want_room)
	if args.has("autotest"):
		_autotest.call_deferred()
	elif args.has("layoutcheck"):
		_layoutcheck.call_deferred()
	elif args.has("touchtest"):
		_touchtest.call_deferred()
	elif args.has("tour"):
		_tour.call_deferred()
	elif args.has("clienttest"):
		_clienttest.call_deferred()
	elif args.has("shiftshots"):
		args["shots"] = args.shiftshots
		get_window().always_on_top = true
		_shiftshots.call_deferred()
	elif args.has("pairshots"):
		args["shots"] = args.pairshots
		_pairshots.call_deferred()
	elif args.has("captainshots"):
		args["shots"] = args.captainshots
		get_window().always_on_top = true
		_captainshots.call_deferred()
	elif args.has("menushot"):
		_menushot.call_deferred()
	elif args.has("phoneshots"):
		args["shots"] = args.phoneshots
		get_window().always_on_top = true
		_phoneshots.call_deferred()
	elif args.has("readmeshots"):
		args["shots"] = args.readmeshots
		get_window().always_on_top = true
		_readmeshots.call_deferred()

# ---------------------------------------------------------------- lost the connection: hang on, get back in

var _rejoining: bool = false
var _rc_layer: CanvasLayer
var _rc_text: Label
var _rc_sub: Label

func _build_reconnect() -> void:
	_rc_layer = CanvasLayer.new()
	_rc_layer.layer = 50
	_rc_layer.visible = false
	add_child(_rc_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rc_layer.add_child(dim)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.theme = UIK.theme()
	_rc_layer.add_child(cc)
	var w: Array = UIK.window("RECONNECTING", "mustard", "clock")
	(w[0] as Control).custom_minimum_size = Vector2(520, 0)
	cc.add_child(w[0])
	var b: VBoxContainer = w[1]
	_rc_text = UIK.para("", 24)
	_rc_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(_rc_text)
	_rc_sub = UIK.para("", 18, K.pal("ink_soft"))
	_rc_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(_rc_sub)
	b.add_child(UIK.btn("Stop trying", "cream", func():
		Net.give_up()
		_hide_reconnect()
		_leave()
		menu.show_msg("Gave up on the crew room. The invite link still works."), "x", 18))

func _show_reconnect(attempt: int, wait: float) -> void:
	_rc_layer.visible = true
	var mine: Array = Net.last_lobby.get("peers", {}).get(Net.my_id, {}).get("seats", [])
	var seat: String = K.role_name(K.role_of(str(mine[0]))) if not mine.is_empty() else ""
	_rc_text.text = ("Lost the connection. Your %s seat is safe: a robot is holding it." % seat) if seat != "" else "Lost the connection. Getting you back in."
	_rc_sub.text = "Trying again in %d s (attempt %d)." % [int(ceil(wait)), attempt]

func _hide_reconnect() -> void:
	if _rc_layer != null:
		_rc_layer.visible = false

# ---------------------------------------------------------------- phones held upright

var portrait: bool = false

func _screen(ui: Control) -> void:
	## every screen sits in a FitBox: on a small or squat display it shrinks to fit rather than spilling off
	var fb: FitBox = FitBox.new()
	fb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(fb)
	fb.add_child(ui)
	ui.visibility_changed.connect(func(): fb.visible = ui.visible)
	fb.visible = ui.visible

func _orient() -> void:
	## an upright phone gets a 720-wide canvas (everything about twice the size it would be squeezed into 1280)
	## and one-column screens; once the game starts it asks to be turned sideways
	var ws: Vector2i = get_window().size
	var p: bool = ws.y > ws.x * 1.05
	var want: Vector2i = Vector2i(720, 1280) if p else Vector2i(1280, 720)
	if p == portrait and get_window().content_scale_size == want:
		return
	portrait = p
	get_window().content_scale_size = want
	menu.set_portrait(p)
	sessions.set_portrait(p)
	lobby.set_portrait(p)
	game.set_portrait(p)

func _show(which: String) -> void:
	if which != state:
		Fx.iris()
	UIK.music("game" if which == "game" else "menu")
	state = which
	menu.visible = which == "menu"
	sessions.visible = which == "sessions"
	lobby.visible = which == "lobby"
	game.visible = which == "game"
	if which == "lobby" and Net.last_lobby.has("seats"):
		lobby.update_lobby(Net.last_lobby)
	if which == "sessions" and Net.last_rooms.has("rooms"):
		sessions.update_rooms(Net.last_rooms)

func _on_host(pname: String) -> void:
	var err: Error = Net.start_host(pname, K.PORT_DEFAULT, true, true)
	if err != OK:
		menu.show_msg("Couldn't open port %d. Is another game running?" % K.PORT_DEFAULT)
		return
	lobby.set_addresses(true, K.PORT_DEFAULT)
	_show("lobby")

func _on_solo(pname: String) -> void:
	var err: Error = Net.start_host(pname, K.PORT_DEFAULT, false, true)
	if err != OK:
		menu.show_msg("Couldn't start a solo game.")
		return
	lobby.set_addresses(false, 0)
	_show("lobby")

func _on_online(pname: String, url: String) -> void:
	if url == "":
		menu.show_msg("There's no server address to connect to.")
		return
	if Net.join_url(url, pname) != OK:
		menu.show_msg("Couldn't connect to that address.")
		return
	lobby.set_addresses(false, 0)
	menu.show_msg("Connecting...")

func _leave() -> void:
	## all the way out, back to the title card
	UIK.stop_speech()
	Voice.stop()
	Net.shutdown()
	game.reset()
	Web.set_room_in_url("")
	_show("menu")
	menu.show_msg("")

func _leave_room() -> void:
	## out of a crew room: back to the Depot on a server, or to the title card otherwise
	if Net.in_hub():
		UIK.stop_speech()
		Voice.stop()
		Net.send("leave")
	else:
		_leave()

func _on_event(d: Dictionary) -> void:
	match str(d.get("t", "")):
		"rooms":
			if state in ["menu", "sessions"] and Net.room_code == "":
				menu.show_msg("")
				_show("sessions")
			if state == "sessions":
				sessions.update_rooms(d)
		"hub_error":
			sessions.show_msg(str(d.get("text", "")))
		"joined":
			sessions.show_msg("")
			Web.set_room_in_url(str(d.get("code", "")))
			if _rejoining:
				# back after a drop: stay on whatever screen we're on; the server says where the crew is now
				_rejoining = false
				return
			game.reset()
			_show("lobby")
		"left", "kicked":
			game.reset()
			Voice.stop()
			Web.set_room_in_url("")
			_show("sessions")
			sessions.show_msg(str(d.get("text", "The host sent you home." if str(d.t) == "kicked" else "")))
			if str(d.t) == "kicked":
				Net.send("rooms")
		"lobby":
			if state in ["menu", "sessions"] or (state == "game" and str(d.get("phase", "")) == "lobby"):
				menu.show_msg("")
				game.reset()
				_show("lobby")
			if state == "lobby":
				lobby.update_lobby(d)
			Voice.sync(d)
		"rtc", "rtc_left":
			Voice.on_event(d)
		"started":
			game.reset()
			_show("game")
		"to_lobby":
			UIK.stop_speech()
			game.reset()
			_show("lobby")

# ================================================================ automated checks

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var dir: String = str(args.get("shots", ""))
	if dir == "":
		return
	var img: Image = get_viewport().get_texture().get_image()
	var vs: Vector2 = root_ui.get_viewport_rect().size
	if img.get_width() > int(vs.x) + 2:
		img.resize(int(vs.x), int(vs.y), Image.INTERPOLATE_LANCZOS)
	img.save_png("%s/%s.png" % [dir, name])

func _check(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var issues: Array = LayoutCheck.check(root_ui)
	for i in issues:
		layout_issues.append("[%s] %s" % [name, i])
	print("LAYOUT %-26s %s  phase=%s state=%s" % [name, "ok" if issues.is_empty() else "%d issue(s)" % issues.size(), Net.host.phase if Net.host else "-", state])
	for i2 in issues:
		print("    ", i2)
	await _shot(name)

func _menushot() -> void:
	await _wait(1.0)
	get_viewport().get_texture().get_image().save_png(str(args.menushot))
	get_tree().quit(0)

func _start_mission(id: String, claim: Array, autopilot: bool) -> void:
	var h: GameHost = Net.host
	h.autopilot = autopilot
	Net.send("opt", {"key": "mission", "val": id})
	for s in claim:
		Net.send("claim", {"seat": s})
	h.time_scale = float(args.get("speed", 1.0))
	await _wait(0.3)
	Net.send("start")
	await _wait(0.5)

func _play(id: String, seconds: float) -> void:
	## start a mission with robots at every station and let it run a while
	if Net.host.phase != "lobby":
		Net.host.to_lobby()
		await _wait(0.4)
	await _start_mission(id, K.SEATS, true)
	await _launch()
	await _wait(seconds)

func _mock() -> void:
	## render a design mock-up script (it reads its own arguments) to --out, then quit
	get_window().always_on_top = true
	UIK.set_grain(false)
	var cl: CanvasLayer = CanvasLayer.new()
	add_child(cl)
	var ui: Control = load(str(args.mock)).new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(ui)
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(str(args.get("out", "/tmp/mock.png")))
	get_tree().quit(0)

func _pairshots() -> void:
	## each crew role's screen (two stations on one screen)
	get_window().always_on_top = true
	await _wait(1.0)
	_on_solo("Tester")
	await _wait(0.4)
	Net.host.career.hard = true
	await _start_mission("bigone", K.SEATS, true)
	await _wait(0.8)
	await _launch()
	await _wait(2.0)
	for rid in K.ROLES:
		Net.send("release_all")
		Net.send("claim", {"seat": rid})
		await _wait(0.8)
		await _shot(str(rid))
	get_tree().quit(0)

func _captainshots() -> void:
	## the captain's chart just after a step is ticked, and once the tick has faded (for trying chart styles)
	await _wait(1.0)
	_on_solo("Captain")
	await _wait(0.4)
	args["speed"] = 1.0
	await _play(str(args.get("mission", "lesson")), 0.5)
	Net.send("active", {"seat": "captain"})
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000 and (Net.host.mission == null or Net.host.mission.step < 2):
		await _wait(0.1)
	await _wait(0.6)
	await _shot("cap_a_tick")
	await _wait(4.5)
	await _shot("cap_b_faded")
	get_tree().quit(0)

func _readmeshots() -> void:
	## every picture in the README, in good-looking states (1280x720). Phone pictures: --phoneshots.
	await _wait(1.0)
	await _shot("01_title")
	_fake_depot()
	await _wait(0.8)
	await _shot("02_depot")
	_on_solo("Trev")
	await _wait(0.4)
	_unlock_everything()
	# a crew room as it looks on a server: a name, a code and the QR code to scan
	Net.host.room_name = "The Bin Lids"
	Net.host.room_code = "BEGA"
	Net.send("release_all")
	Net.send("claim", {"seat": "captain"})
	Net.send("opt", {"key": "mode", "val": "shift"})
	await _wait(0.8)
	await _shot("03_crew_room")
	Net.host.room_code = ""
	Net.host.room_name = ""
	Net.host.autopilot = true
	Net.send("start")
	await _wait(0.8)
	Net.send("vote", {"i": 1})
	await _wait(0.4)
	await _shot("04_job_board")
	# the Stoker's short briefing: what's new, and their two jobs
	Net.send("release_all")
	Net.send("claim", {"seat": "stoker"})
	await _wait(0.3)
	Net.send("pick", {"i": 1})
	await _wait(1.0)
	UIK.stop_speech()
	await _wait(0.3)
	game.briefing_ui.page_text.visible_ratio = 1.0
	await _shot("05_briefing")
	await _launch()
	await _wait(6.0)
	Net.host.autopilot = true
	Net.host._sync_bots()
	# the Captain's bridge, at a moment with something to shout about
	Net.send("release_all")
	Net.send("claim", {"seat": "captain"})
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		var warns: Array = Snapshots.forecasts(Net.host.world)
		if not warns.is_empty() and int(warns[0].level) >= 2:
			break
		await _wait(0.1)
	await _wait(0.6)
	await _shot("06_captain")
	# the three crew desks
	for rid in ["driver", "stoker", "tech"]:
		Net.send("release_all")
		Net.send("claim", {"seat": rid})
		await _wait(1.6)
		await _shot("07_%s" % rid)
	# glitches: the Tech reads IGOR's manual; the chart turns upside down
	var w: World = Net.host.world
	w.add_glitch("backwards_wheel")
	w.add_glitch("upside_chart")
	Net.intent("engineer", "select", "bridge")
	await _wait(1.2)
	await _shot("08_glitch_manual")
	Net.send("release_all")
	Net.send("claim", {"seat": "captain"})
	await _wait(1.6)
	await _shot("09_upside_down_chart")
	Net.host.mission.done = true
	await _wait(1.2)
	await _shot("10_pay_slip")
	# the rest of the shift, to the end
	for k in 2:
		Net.send("next")
		await _wait(0.6)
		if k == 0 and not (Net.host.shift.get("part_offers", []) as Array).is_empty():
			Net.send("part", {"id": str(Net.host.shift.part_offers[0].id)})
		Net.send("pick", {"i": 0})
		await _wait(0.5)
		await _launch()
		await _wait(0.8)
		Net.host.mission.done = true
		await _wait(1.2)
	await _shot("11_shift_end")
	print("README SHOTS DONE")
	get_tree().quit(0)

func _phoneshots() -> void:
	## the phone pictures: upright title and Crew Room, then the Stoker's desk held sideways (run at 390x844 --touchui)
	await _wait(1.0)
	await _shot("12_phone_title")
	_on_solo("Sam")
	await _wait(0.4)
	_unlock_everything()
	Net.host.room_name = "The Bin Lids"
	Net.host.room_code = "BEGA"
	Net.send("opt", {"key": "mode", "val": "shift"})
	await _wait(0.8)
	await _shot("13_phone_crew_room")
	Net.host.room_code = ""
	Net.host.autopilot = true
	Net.send("release_all")
	Net.send("claim", {"seat": "stoker"})
	Net.send("opt", {"key": "mode", "val": "career"})
	Net.send("opt", {"key": "mission", "val": "haven"})
	await _wait(0.3)
	Net.send("start")
	await _wait(0.6)
	await _shot("14_phone_turn_sideways")
	get_window().size = Vector2i(844, 390)
	await _launch()
	await _wait(6.0)
	await _shot("15_phone_stoker")
	print("PHONE SHOTS DONE")
	get_tree().quit(0)

func _launch() -> void:
	if Net.host != null and Net.host.phase == "briefing":
		Net.host.force_launch()
	await _wait(0.3)

# ---------------------------------------------------------------- two thumbs at once

var _touch_fails: Array = []

func _finger(idx: int, at: Vector2, pressed: bool, drag: bool = false) -> void:
	## a real touch, sent the way the browser sends it (so Godot also makes its pretend mouse from finger 0)
	var w: Vector2 = get_viewport().get_final_transform() * at
	var ev: InputEvent
	if drag:
		var dr: InputEventScreenDrag = InputEventScreenDrag.new()
		dr.index = idx
		dr.position = w
		ev = dr
	else:
		var t: InputEventScreenTouch = InputEventScreenTouch.new()
		t.index = idx
		t.position = w
		t.pressed = pressed
		ev = t
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame

func _centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _touch_check(ok: bool, what: String) -> void:
	print("TOUCH %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_touch_fails.append(what)

func _touchtest() -> void:
	## both thumbs on a desk at once: hold one control, work another, let go of one, the other carries on
	await _wait(0.6)
	_on_solo("Tester")
	await _wait(0.6)
	# ---- tap to explain (touch screens have no hover tooltips)
	var ex: Explain = get_node("Explain")
	var face: Control = (lobby.seat_cards["driver"] as Control).find_children("*", "TextureRect", true, false)[0]
	await _finger(0, _centre(face), true)
	await _finger(0, _centre(face), false)
	await _wait(0.2)
	_touch_check(ex.bubble.visible and ex.text_lbl.text == K.role_persona("driver"), "tap a face: a bubble says who it is ('%s')" % ex.text_lbl.text)
	var hb: Button = lobby.hard_btn
	var was: bool = hb.button_pressed
	await _finger(0, _centre(hb), true)
	await _wait(0.8)
	await _finger(0, _centre(hb), false)
	await _wait(0.3)
	_touch_check(ex.bubble.visible and ex.text_lbl.text.begins_with("Off:") and hb.button_pressed == was and not bool(Net.last_lobby.get("hard", false)),
		"hold a button: it explains itself and does NOT switch (hard mode still %s)" % str(Net.last_lobby.get("hard", false)))
	await _finger(0, _centre(hb), true)
	await _finger(0, _centre(hb), false)
	await _wait(0.3)
	_touch_check(bool(Net.last_lobby.get("hard", false)), "a quick tap on the same button still works (hard mode on)")
	Net.send("opt", {"key": "hard", "val": false})
	await _wait(0.2)
	await _start_mission("hot", K.SEATS, false)
	await _launch()
	await _wait(1.0)
	Net.host.autopilot = false
	var w: World = Net.host.world
	# ---- the Stoker: hold FIRE, turn the turret
	Net.send("release_all")
	Net.send("claim", {"seat": "stoker"})
	await _wait(0.8)
	var desk: RoleDesk = game.desks["stoker"]
	var wp: WeaponsUI = desk.stations["weapons"]
	var en: EnginesUI = desk.stations["engines"]
	var aim0: float = w.ship.aim
	await _finger(0, _centre(wp.fire_btn) - Vector2(0, 17), true)
	await _wait(0.3)
	_touch_check(w.ship.firing, "Stoker: finger 1 holds FIRE")
	var dc: Vector2 = _centre(wp.dial)
	var r: float = minf(wp.dial.size.x, wp.dial.size.y) * wp.dial.get_global_transform().get_scale().x * 0.3
	await _finger(1, dc + Vector2(r, 0), true)
	await _finger(1, dc + Vector2(0, r), false, true)
	await _wait(0.3)
	_touch_check(w.ship.firing and absf(K.wrap_pi(w.ship.aim - aim0)) > 0.3, "Stoker: finger 2 turns the turret while FIRE is held (aim %.2f -> %.2f)" % [aim0, w.ship.aim])
	await _finger(0, _centre(wp.fire_btn) - Vector2(0, 17), false)
	await _wait(0.3)
	var aim1: float = w.ship.aim
	_touch_check(not w.ship.firing, "Stoker: lifting finger 1 lets go of FIRE")
	await _finger(1, dc + Vector2(-r, 0), false, true)
	await _wait(0.3)
	_touch_check(absf(K.wrap_pi(w.ship.aim - aim1)) > 0.3, "Stoker: finger 2 still turns the turret after finger 1 lifts")
	await _finger(1, dc + Vector2(-r, 0), false)
	# throttle with one thumb while firing with the other
	var thr0: float = w.ship.throttle
	await _finger(0, _centre(wp.fire_btn) - Vector2(0, 17), true)
	var lv: Rect2 = en.lever.get_global_rect()
	await _finger(1, Vector2(lv.get_center().x, lv.position.y + lv.size.y * 0.5), true)
	await _finger(1, Vector2(lv.get_center().x, lv.position.y + lv.size.y * 0.15), false, true)
	await _wait(0.3)
	_touch_check(w.ship.firing and w.ship.throttle > thr0 + 0.2, "Stoker: throttle up with one thumb while firing with the other (%.2f -> %.2f)" % [thr0, w.ship.throttle])
	await _finger(1, Vector2(lv.get_center().x, lv.position.y + lv.size.y * 0.15), false)
	await _finger(0, _centre(wp.fire_btn) - Vector2(0, 17), false)
	# ---- the Driver: hold LEFT, swing the shield
	Net.send("release_all")
	Net.send("claim", {"seat": "driver"})
	await _wait(0.8)
	var dd: RoleDesk = game.desks["driver"]
	var hm: HelmUI = dd.stations["helm"]
	var sh: ShieldsUI = dd.stations["shields"]
	var sh0: float = w.ship.shield_dir
	await _finger(0, _centre(hm.left_btn) - Vector2(0, 17), true)
	await _wait(0.3)
	_touch_check(w.ship.wheel < -0.5, "Driver: finger 1 holds LEFT (wheel %.2f)" % w.ship.wheel)
	var sc: Vector2 = _centre(sh.dial)
	var sr: float = minf(sh.dial.size.x, sh.dial.size.y) * sh.dial.get_global_transform().get_scale().x * 0.3
	await _finger(1, sc + Vector2(0, sr), true)
	await _finger(1, sc + Vector2(sr, 0), false, true)
	await _wait(0.3)
	_touch_check(w.ship.wheel < -0.5 and absf(K.wrap_pi(w.ship.shield_dir - sh0)) > 0.3, "Driver: finger 2 swings the shield while LEFT is held (shield %.2f -> %.2f)" % [sh0, w.ship.shield_dir])
	await _finger(0, _centre(hm.left_btn) - Vector2(0, 17), false)
	await _wait(0.3)
	_touch_check(absf(w.ship.wheel) < 0.05, "Driver: lifting finger 1 straightens up")
	await _finger(1, sc + Vector2(sr, 0), false)
	# ---- a plain mouse still works (desktop players)
	var mb: InputEventMouseButton = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = get_viewport().get_final_transform() * (_centre(hm.right_btn) - Vector2(0, 17))
	Input.parse_input_event(mb)
	await _wait(0.3)
	_touch_check(w.ship.wheel > 0.5, "mouse: holding RIGHT turns right")
	var mu: InputEventMouseButton = mb.duplicate()
	mu.pressed = false
	Input.parse_input_event(mu)
	await _wait(0.3)
	_touch_check(absf(w.ship.wheel) < 0.05, "mouse: letting go straightens up")
	# ---- rebinding a key (keyboard players)
	Keys.bind("helm", KEY_A, KEY_J)
	game._keys_changed()
	var kj: InputEventKey = InputEventKey.new()
	kj.physical_keycode = KEY_J
	kj.pressed = true
	Input.parse_input_event(kj)
	await _wait(0.3)
	_touch_check(w.ship.wheel < -0.5 and hm.left_btn.key_hint == "J", "keys: 'turn left' rebound to J turns left, and the button says J")
	var kju: InputEventKey = kj.duplicate()
	kju.pressed = false
	Input.parse_input_event(kju)
	var ka: InputEventKey = InputEventKey.new()
	ka.physical_keycode = KEY_A
	ka.pressed = true
	Input.parse_input_event(ka)
	await _wait(0.3)
	_touch_check(absf(w.ship.wheel) < 0.05, "keys: the old key A no longer turns")
	var kau: InputEventKey = ka.duplicate()
	kau.pressed = false
	Input.parse_input_event(kau)
	Keys.reset()
	game._keys_changed()
	await _wait(0.2)
	_touch_check(hm.left_btn.key_hint == "A", "keys: reset puts A back")
	print("TOUCHTEST %s" % ("PASS" if _touch_fails.is_empty() else "FAIL %s" % str(_touch_fails)))
	get_tree().quit(_touch_fails.size())

func _layoutcheck() -> void:
	## visit every screen and run the layout checker; exit code = number of issues
	await _wait(0.6)
	await _check("menu")
	_fake_depot()
	await _wait(0.3)
	await _check("depot")
	_on_solo("Tester")
	await _wait(0.5)
	await _check("crewroom")
	# the Shift: crew room tab, job board (with parts), a job briefing with its extra page, both pay slips
	await _shift_to_board()
	await _check("crewroom_shift")
	# an online crew's version: the whole deck, so the board below deals from everything too
	Net.host.career.full_deck = true
	Net.host._send_lobby()
	await _wait(0.3)
	await _check("crewroom_online")
	Net.send("start")
	await _wait(0.6)
	Net.send("vote", {"i": 0})
	await _check("board")
	Net.send("pick", {"i": 2})
	await _wait(0.6)
	game.briefing_ui._goto(3, false)
	await _check("job_briefing_card")
	await _launch()
	await _wait(0.6)
	Net.host.world.add_glitch("backwards_wheel")
	Net.host.autopilot = false
	Net.host._sync_bots()
	Net.send("active", {"seat": "engineer"})
	Net.intent("engineer", "select", "bridge")
	await _wait(0.8)
	await _check("engineer_manual")
	Net.host.autopilot = true
	Net.host._sync_bots()
	Net.host.mission.done = true
	await _wait(1.0)
	await _check("pay_slip")
	Net.send("next")
	await _wait(0.6)
	await _check("board_parts")
	for k in 2:
		Net.send("pick", {"i": 0})
		await _wait(0.4)
		await _launch()
		if k == 0:
			Net.host.mission.fail("The hull fell off. All of it.")
		else:
			Net.host.mission.done = true
		await _wait(1.0)
		if k == 0:
			await _check("pay_slip_writeoff")
			Net.send("next")
			await _wait(0.5)
	await _check("shift_end")
	Net.host.to_lobby()
	Net.send("opt", {"key": "mode", "val": "career"})
	Net.send("release_all")
	Net.send("claim", {"seat": "captain"})
	await _wait(0.4)
	var mid: String = str(args.get("layoutcheck", "haven"))
	if mid == "1":
		mid = "haven"
	await _start_mission(mid, K.SEATS, true)
	await _wait(1.0)
	await _check("briefing_p1")
	game.briefing_ui._goto(1, false)
	await _check("briefing_p2")
	game.briefing_ui._goto(2, false)
	await _check("briefing_p3")
	await _launch()
	await _wait(2.5)
	for seat in K.SEATS:
		Net.send("active", {"seat": seat})
		await _wait(0.7)
		await _check("seat_" + seat)
	# now make everything go wrong at once: long texts, stamps, warnings, alerts
	var w: World = Net.host.world
	w.break_system("gun", "test", true)
	w.break_system("engine_p", "test", false)
	w.break_system("sensors", "test", false)
	w.break_system("bridge", "test", true)
	w.ship.pud_mood = 0.0
	w.ship.engine_heat = 95.0
	w.ship.gun_heat = 90.0
	w.ship.overload = 80.0
	w.ship.torp = "ready"
	w.send_hail("Customs Officer", "Turn your ship to face heading 090. East, for the meat-brained. And do it quickly, please.")
	w.hail.heard = true
	w.spawn("grabber", w.ship.pos + Vector2(30, 0), {"ai": "grabber"})
	w.spawn("patrol", w.ship.pos + Vector2(0, 300), {"ai": "patrol", "charge": 1.0})
	Net.host.autopilot = false
	Net.host._sync_bots()
	for seat2 in K.SEATS:
		Net.send("active", {"seat": seat2})
		await _wait(0.6)
		await _check("stress_" + seat2)
	# the crew roles: one player, two stations, one screen
	for rid in K.ROLES:
		Net.send("release_all")
		Net.send("claim", {"seat": rid})
		await _wait(0.7)
		await _check("role_" + str(rid))
	Net.host.autopilot = true
	Net.host._sync_bots()
	game.pause_panel.visible = true
	await _check("pause")
	game.pause_panel.visible = false
	Net.host.mission.done = true
	await _wait(0.6)
	await _check("debrief_ok")
	Net.send("retry")
	await _wait(0.4)
	await _launch()
	await _wait(0.5)
	Net.host.mission.fail("The hull fell off. All of it.")
	await _wait(0.6)
	await _check("debrief_fail")
	print("LAYOUTCHECK DONE issues=", layout_issues.size())
	get_tree().quit(mini(layout_issues.size(), 100))

func _poke(root: Node) -> int:
	## press every visible button, drag every dial and lever
	var n: int = 0
	for b in root.find_children("*", "BaseButton", true, false):
		var bt: BaseButton = b
		if not bt.is_visible_in_tree() or bt.disabled:
			continue
		if bt is Button and ((bt as Button).text.begins_with("Leave") or (bt as Button).text.begins_with("Crew Room")):
			continue
		if bt.toggle_mode:
			bt.button_pressed = not bt.button_pressed
		else:
			bt.pressed.emit()
		n += 1
	for bb in root.find_children("*", "BigButton", true, false):
		var big: BigButton = bb
		if big.is_visible_in_tree() and not big.disabled:
			big.press_key(true)
			big.press_key(false)
			n += 1
	for w in root.find_children("*", "ShipWheel", true, false):
		(w as ShipWheel).set_value(0.5, true)
		n += 1
	for t in root.find_children("*", "ThrottleLever", true, false):
		(t as ThrottleLever).set_value(0.6, true)
		n += 1
	for d in root.find_children("*", "ClockDial", true, false):
		(d as ClockDial).set_value(1.2, true)
		n += 1
	for c in root.find_children("*", "Cutaway", true, false):
		if (c as Cutaway).clickable:
			(c as Cutaway).room_clicked.emit("gun")
			n += 1
	for r in root.find_children("*", "Radar", true, false):
		var bl: Array = (r as Radar).view.get("blips", [])
		if not bl.is_empty():
			(r as Radar).picked.emit(int(bl[0].id))
			n += 1
	return n

func _autotest() -> void:
	## screenshots of every seat in a mission (robots fly it), or --exercise to poke every control
	if Net.host == null:
		_on_solo("Captain")
	await _wait(0.6)
	var id: String = str(args.get("autotest", "lesson"))
	if id == "1":
		id = "lesson"
	await _start_mission(id, K.SEATS, true)
	await _shot("01_briefing")
	await _launch()
	await _wait(float(args.get("warm", 3.0)))
	var pokes: int = 0
	var wait_s: float = float(args.get("wait", 1.2))
	for seat in K.SEATS:
		Net.send("active", {"seat": seat})
		await _wait(wait_s)
		if args.has("exercise") and seat != "captain":
			Net.host.autopilot = false
			Net.host._sync_bots()
			pokes += _poke(game.stations[seat])
			await _wait(0.3)
			Net.host.autopilot = true
			Net.host._sync_bots()
		await _shot("02_" + seat)
	if args.has("exercise"):
		Net.host.world.break_system("gun", "test", true)
		Net.host.world.break_system("engine_p", "test", false)
		Net.send("active", {"seat": "engineer"})
		await _wait(0.5)
		Net.host.autopilot = false
		Net.host._sync_bots()
		pokes += _poke(game.stations["engineer"])
		Net.send("intent", {"station": "engineer", "key": "select", "val": "gun"})
		Net.send("intent", {"station": "engineer", "key": "repair", "val": true})
		await _wait(3.5)
		Net.send("intent", {"station": "engineer", "key": "repair", "val": false})
		print("EXERCISE fire after repair: ", Net.host.world.ship.sys.gun.state)
	Net.send("active", {"seat": "captain"})
	await _wait(float(args.get("tail", 2.0)))
	await _shot("03_captain_late")
	print("AUTOTEST DONE mission=%s phase=%s pokes=%d step=%d" % [id, Net.host.phase, pokes, Net.host.mission.step if Net.host.mission else -1])
	get_tree().quit(0)

func _tour() -> void:
	## a robot crew plays the career; screenshot every phase change
	if Net.host == null:
		_on_solo("Captain")
	await _wait(0.6)
	var first: String = str(args.get("tour", "lesson"))
	if first == "1":
		first = "lesson"
	Net.host.time_scale = float(args.get("speed", 3.0))
	await _start_mission(first, ["captain"], false)
	var limit: float = float(args.get("limit", 240.0))
	var t0: float = Time.get_ticks_msec() / 1000.0
	var last: String = ""
	var n: int = 0
	while Time.get_ticks_msec() / 1000.0 - t0 < limit:
		await _wait(0.4)
		var h: GameHost = Net.host
		if h == null:
			break
		if h.phase == "briefing" and float(h.briefing.get("t", 0.0)) > 1.0:
			Net.send("ready", {"on": true})
		var key: String = h.phase + ":" + (h.mission_id if h.mission else "")
		if key != last:
			last = key
			await _wait(float(args.get("settle", 1.5)))
			await _shot("tour_%02d_%s" % [n, key.replace(":", "_")])
			n += 1
			if h.phase == "debrief":
				if str(h.debrief.get("next", "")) == "" or n > int(args.get("max", 99)):
					break
				Net.send("next")
	print("TOUR DONE shots=%d phase=%s mission=%s" % [n, Net.host.phase if Net.host else "-", Net.host.mission_id if Net.host else "-"])
	get_tree().quit(0)

func _clienttest() -> void:
	var t0: float = Time.get_ticks_msec() / 1000.0
	while not Net.is_connected_online and Time.get_ticks_msec() / 1000.0 - t0 < 6.0:
		await _wait(0.2)
	await _wait(0.8)
	print("CLIENTTEST connected=", Net.is_connected_online, " id=", Net.my_id, " state=", state)
	Net.send("claim", {"seat": "captain"})
	Net.send("claim", {"seat": "helm"})
	await _wait(0.8)
	await _shot("client_lobby")
	Net.send("start")
	await _wait(1.5)
	await _shot("client_briefing")
	Net.send("ready", {"on": true})
	await _wait(4.5)
	print("CLIENTTEST in-game state=", state, " phase=", Net.last_snapshot.get("phase", "?"))
	Net.send("active", {"seat": "helm"})
	await _wait(0.8)
	var pokes: int = _poke(game.stations["helm"])
	await _wait(1.0)
	await _shot("client_helm")
	Net.send("active", {"seat": "captain"})
	await _wait(1.0)
	await _shot("client_captain")
	print("CLIENTTEST done pokes=", pokes, " has_view=", Net.last_snapshot.has("view"), " phase=", Net.last_snapshot.get("phase", "?"))
	get_tree().quit(0)

func _unlock_everything() -> void:
	var c: Progress = Net.host.career
	c.unlock_all()
	for id in Missions.ORDER:
		c.star_map[id] = 2
	c.shifts = int(args.get("shifts", 6))

func _fake_depot() -> void:
	## the Depot only exists on a server: show it with made-up crews so it can be checked and photographed
	_show("sessions")
	sessions.update_rooms({"you": "Tester", "full": false, "rooms": [
		{"code": "PUDD", "name": "The Bin Lids", "host": "Maggie", "players": 2, "max": 4, "doing": "In the crew room", "phase": "lobby", "open": ["stoker", "tech"]},
		{"code": "SKIP", "name": "Wobble's crew", "host": "Wobble", "players": 3, "max": 4, "doing": "Flying: Hot Soup Run", "phase": "mission", "open": ["tech"]},
		{"code": "ZOGA", "name": "Loud Friends United", "host": "Captain Biscuit", "players": 4, "max": 4, "doing": "Briefing: The Big One", "phase": "briefing", "open": []}]})

func _shift_to_board() -> void:
	if Net.host.phase != "lobby":
		Net.host.to_lobby()
		await _wait(0.3)
	_unlock_everything()
	Net.host.autopilot = true
	Net.send("opt", {"key": "mode", "val": "shift"})
	for s in K.SEATS:
		Net.send("claim", {"seat": s})
	await _wait(0.3)

func _shiftshots() -> void:
	## photographs of the Shift: crew room, job board, briefing, glitches, pay slip, end of shift
	await _wait(0.8)
	_fake_depot()
	await _wait(1.0)
	await _shot("s01_depot")
	_on_solo("Trev")
	await _wait(0.4)
	await _shift_to_board()
	await _shot("s02_crewroom_shift")
	Net.send("start")
	await _wait(0.8)
	Net.send("vote", {"i": 1})
	await _wait(0.4)
	await _shot("s03_board")
	Net.send("pick", {"i": 1})
	await _wait(1.0)
	game.briefing_ui._goto(2, false)
	UIK.stop_speech()
	await _wait(0.3)
	game.briefing_ui.page_text.visible_ratio = 1.0
	await _shot("s04_job_briefing")
	await _launch()
	await _wait(3.0)
	var w: World = Net.host.world
	w.add_glitch("backwards_wheel")
	w.add_glitch("gun_pull")
	w.add_glitch("upside_chart")
	Net.host.autopilot = false
	Net.host._sync_bots()
	Net.send("active", {"seat": "engineer"})
	Net.intent("engineer", "select", "bridge")
	await _wait(1.2)
	await _shot("s05_engineer_manual")
	Net.send("active", {"seat": "captain"})
	await _wait(1.5)
	await _shot("s06_captain_glitches")
	Net.send("active", {"seat": "helm"})
	await _wait(6.0)
	await _shot("s07_helm_glitchy")
	Net.send("active", {"seat": "weapons"})
	await _wait(1.0)
	await _shot("s08_weapons")
	Net.host.autopilot = true
	Net.host._sync_bots()
	Net.host.mission.done = true
	await _wait(1.2)
	await _shot("s09_pay_slip")
	Net.send("next")
	await _wait(0.8)
	await _shot("s10_board_parts")
	Net.send("part", {"id": str(Net.host.shift.part_offers[0].id)})
	Net.send("pick", {"i": 0})
	await _wait(0.5)
	await _launch()
	Net.host.mission.done = true
	await _wait(0.6)
	Net.send("next")
	await _wait(0.5)
	Net.send("pick", {"i": 2})
	await _wait(0.5)
	await _launch()
	await _wait(1.0)
	Net.host.mission.done = true
	await _wait(1.2)
	await _shot("s11_shift_end")
	print("SHIFT SHOTS DONE")
	get_tree().quit(0)
