extends Node
## Entry point: title card -> Crew Room -> IGOR's briefing -> the mission -> debrief.
## Also hosts the automated UI checks (--autotest, --layoutcheck, --exercise, --tour, --clienttest).

var layer: CanvasLayer
var root_ui: Control
var menu: MenuUI
var lobby: LobbyUI
var game: GameUI
var state: String = "menu"
var args: Dictionary = {}
var layout_issues: Array = []

func _ready() -> void:
	get_window().title = "Yes, Captain!"
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
	menu.join_pressed.connect(_on_join)
	menu.quit_pressed.connect(func(): get_tree().quit())
	root_ui.add_child(menu)
	lobby = LobbyUI.new()
	lobby.leave_pressed.connect(_leave)
	lobby.visible = false
	root_ui.add_child(lobby)
	game = GameUI.new()
	game.leave_pressed.connect(_leave)
	game.visible = false
	root_ui.add_child(game)
	add_child(Film.new())
	Net.event.connect(_on_event)
	Net.connected.connect(func(): _show("lobby"))
	Net.join_failed.connect(func(r: String): menu.show_msg(r))
	Net.disconnected.connect(func(r: String):
		_leave()
		menu.show_msg(r))
	_parse_args()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("autotest") or args.has("layoutcheck") or args.has("tour"):
		Progress.persist = false
		Progress.unlock_all()
	if args.has("shots"):
		# macOS stops redrawing covered windows, which freezes screenshots: keep the test window on top
		get_window().always_on_top = true
	if args.has("nograin"):
		UIK.set_grain(false)
	if args.has("server"):
		var port: int = int(args.get("port", K.PORT_DEFAULT))
		var err: Error = Net.start_host("Server", port, true, false)
		print("Yes, Captain! dedicated host on port %d (err %d)" % [port, err])
		_show("lobby")
		lobby.set_addresses(true, port)
	elif args.has("host"):
		_on_host("Captain")
	elif args.has("solo"):
		_on_solo("Captain")
	elif args.has("join"):
		_on_join("Crew", str(args.join), int(args.get("port", K.PORT_DEFAULT)))
	if args.has("autotest"):
		_autotest.call_deferred()
	elif args.has("layoutcheck"):
		_layoutcheck.call_deferred()
	elif args.has("tour"):
		_tour.call_deferred()
	elif args.has("clienttest"):
		_clienttest.call_deferred()
	elif args.has("menushot"):
		_menushot.call_deferred()

func _show(which: String) -> void:
	state = which
	menu.visible = which == "menu"
	lobby.visible = which == "lobby"
	game.visible = which == "game"
	if which == "lobby" and Net.last_lobby.has("seats"):
		lobby.update_lobby(Net.last_lobby)

func _on_host(pname: String) -> void:
	var err: Error = Net.start_host(pname if pname.strip_edges() != "" else "Captain", K.PORT_DEFAULT, true, true)
	if err != OK:
		menu.show_msg("Couldn't open port %d. Is another game running?" % K.PORT_DEFAULT)
		return
	_show("lobby")
	lobby.set_addresses(true, K.PORT_DEFAULT)

func _on_solo(pname: String) -> void:
	var err: Error = Net.start_host(pname if pname.strip_edges() != "" else "Captain", K.PORT_DEFAULT, false, true)
	if err != OK:
		menu.show_msg("Couldn't start a solo game.")
		return
	_show("lobby")
	lobby.set_addresses(false, 0)

func _on_join(pname: String, ip: String, port: int) -> void:
	if ip == "":
		menu.show_msg("Type the host's address first.")
		return
	if Net.join(ip, port, pname if pname.strip_edges() != "" else "Crew") != OK:
		menu.show_msg("Couldn't connect to that address.")
		return
	menu.show_msg("Connecting...")

func _leave() -> void:
	UIK.stop_speech()
	Net.shutdown()
	game.reset()
	_show("menu")
	menu.show_msg("")

func _on_event(d: Dictionary) -> void:
	match str(d.get("t", "")):
		"lobby":
			if state == "lobby":
				lobby.update_lobby(d)
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

func _launch() -> void:
	if Net.host != null and Net.host.phase == "briefing":
		Net.host.force_launch()
	await _wait(0.3)

func _layoutcheck() -> void:
	## visit every screen and run the layout checker; exit code = number of issues
	await _wait(0.6)
	await _check("menu")
	_on_solo("Tester")
	await _wait(0.5)
	await _check("crewroom")
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
