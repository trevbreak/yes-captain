extends Node
## Entry point: title screen -> Crew Room -> mission briefing -> game.
## Also hosts the automated UI tests (--autotest, --layoutcheck, --exercise, ...).

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
	Net.event.connect(_on_event)
	Net.connected.connect(func(): _show("lobby"))
	Net.join_failed.connect(func(r: String): menu.show_msg(r))
	Net.disconnected.connect(func(r: String): _leave(); menu.show_msg(r))
	_parse_args()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("autotest") or args.has("layoutcheck"):
		RunState.persist = false
	if args.has("server"):
		var port: int = int(args.get("port", K.PORT_DEFAULT))
		var err: Error = Net.start_host("Server", port, true, false)
		print("Yes, Captain! dedicated host on port %d (err %d)" % [port, err])
		Net.host.default_personality = "random"
		_show("lobby")
		lobby.set_addresses(true, port)
	elif args.has("host"):
		_on_host("Captain")
	elif args.has("solo"):
		_on_solo("Captain")
	elif args.has("join"):
		_on_join("Crew", str(args.join), int(args.get("port", K.PORT_DEFAULT)))
	if args.has("styleguide"):
		menu.visible = false
		root_ui.add_child(StyleGuide.new())
	if args.has("autotest"):
		_autotest.call_deferred()
	if args.has("layoutcheck"):
		_layoutcheck.call_deferred()
	if args.has("clienttest"):
		_clienttest.call_deferred()
	if args.has("menushot"):
		_menushot.call_deferred()

func _show(which: String) -> void:
	state = which
	menu.visible = which == "menu"
	lobby.visible = which == "lobby"
	game.visible = which == "game"
	if which == "lobby" and Net.last_lobby.has("seats"):
		lobby.update_lobby(Net.last_lobby)

func _on_host(pname: String) -> void:
	var port: int = K.PORT_DEFAULT
	var err: Error = Net.start_host(pname if pname.strip_edges() != "" else "Captain", port, true, true)
	if err != OK:
		menu.show_msg("Couldn't open port %d (is another game running?)" % port)
		return
	_show("lobby")
	lobby.set_addresses(true, port)

func _on_solo(pname: String) -> void:
	var err: Error = Net.start_host(pname if pname.strip_edges() != "" else "Captain", K.PORT_DEFAULT, false, true)
	if err != OK:
		menu.show_msg("Couldn't start solo mode.")
		return
	_show("lobby")
	lobby.set_addresses(false, 0)

func _on_join(pname: String, ip: String, port: int) -> void:
	if ip == "":
		menu.show_msg("Type the host's address first.")
		return
	var err: Error = Net.join(ip, port, pname if pname.strip_edges() != "" else "Crew")
	if err != OK:
		menu.show_msg("Couldn't connect to that address.")
		return
	menu.show_msg("Connecting...")

func _leave() -> void:
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
			game.reset()
			_show("lobby")
			if Net.last_lobby.has("seats"):
				lobby.update_lobby(Net.last_lobby)

# ================================================================ automated UI testing

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _shot(name: String) -> void:
	var dir: String = str(args.get("shots", ""))
	await get_tree().process_frame
	await get_tree().process_frame
	if dir == "":
		return
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])

func _check(name: String) -> void:
	## run the layout checker on what's visible right now, and screenshot it
	await get_tree().process_frame
	await get_tree().process_frame
	var issues: Array = LayoutCheck.check(root_ui)
	for i in issues:
		layout_issues.append("[%s] %s" % [name, i])
	print("LAYOUT %-28s %s" % [name, "ok" if issues.is_empty() else "%d issue(s)" % issues.size()])
	for i2 in issues:
		print("    ", i2)
	await _shot(name)

func _menushot() -> void:
	await _wait(0.8)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(str(args.menushot))
	get_tree().quit(0)

func _setup_mission(kind: String, mode: String, claim_all: bool) -> void:
	Net.send("opt", {"key": "mode", "val": mode})
	Net.send("opt", {"key": "shift_kind", "val": kind})
	Net.send("opt", {"key": "length", "val": "short"})
	Net.send("opt", {"key": "personality", "val": "competent"})
	if Net.host != null:
		Net.host.time_scale = float(args.get("speed", 1.0))
	if claim_all:
		for seat in K.SEATS:
			Net.send("claim", {"seat": seat})
	await _wait(0.3)

func _ready_and_launch() -> void:
	Net.send("ready", {"on": true})
	var t0: int = Time.get_ticks_msec()
	while Net.host != null and Net.host.phase == "briefing" and Time.get_ticks_msec() - t0 < 8000:
		await _wait(0.2)

func _layoutcheck() -> void:
	## Walk every screen and run the layout checker. Exit code = number of issues found.
	await _wait(0.5)
	await _check("menu")
	_on_solo("Tester")
	await _wait(0.5)
	await _setup_mission(str(args.get("layoutcheck", "drones")), "shift", false)
	await _check("crewroom_mission")
	lobby._set_step(1)
	await _check("crewroom_crew")
	for seat in K.SEATS:
		Net.send("claim", {"seat": seat})
	await _wait(0.4)
	await _check("crewroom_all_claimed")
	Net.send("start", {})
	await _wait(1.0)
	Net.send("active", {"seat": "helm"})
	await _wait(0.5)
	await _check("briefing")
	await _ready_and_launch()
	await _wait(2.0)
	for seat in ["captain", "helm", "engines", "power", "weapons", "sensors", "ops", "dc"]:
		Net.send("active", {"seat": seat})
		await _wait(0.6)
		await _check("station_" + seat)
	Net.send("active", {"seat": "captain"})
	await _wait(0.4)
	if game.cap_ui != null:
		game.cap_ui.orders_panel.visible = true
		await _check("captain_orders")
		game.cap_ui.orders_panel.visible = false
	game.pause_panel.visible = true
	await _check("pause_menu")
	game.pause_panel.visible = false
	# run-mode screens
	var h: GameHost = Net.host
	h.to_lobby()
	await _wait(0.4)
	await _setup_mission("binday", "run", false)
	Net.send("start", {})
	await _wait(0.8)
	await _ready_and_launch()
	await _wait(0.6)
	h.world.enc.finish(true)
	await _wait(0.6)
	Net.send("active", {"seat": "captain"})
	await _wait(0.4)
	await _check("debrief_captain")
	Net.send("active", {"seat": "helm"})
	await _wait(0.4)
	await _check("debrief_crew")
	h.captain_continue()
	await _wait(0.4)
	h._helm_code(str(h.run.options()[0].code))
	for seat2 in ["captain", "helm", "power", "engines", "ops"]:
		Net.send("active", {"seat": seat2})
		await _wait(0.5)
		await _check("staging_" + seat2)
	h.run.scrap = 90
	h._begin_pitstop()
	h.pit["requests"]["turbo"] = "engines"
	for seat3 in ["captain", "engines"]:
		Net.send("active", {"seat": seat3})
		await _wait(0.5)
		await _check("pitstop_" + seat3)
	h.pit_done()
	await _wait(0.2)
	h._finish_run("fin_haven")
	h.phase = "ending"
	Net.send("active", {"seat": "captain"})
	await _wait(0.5)
	await _check("ending")
	h.to_lobby()
	await _wait(0.4)
	await _setup_mission("drones", "run", false)
	Net.send("start", {})
	await _wait(0.8)
	await _ready_and_launch()
	await _wait(0.5)
	h._game_over("The ship fell apart. Several times.")
	await _wait(0.8)
	Net.send("active", {"seat": "captain"})
	await _wait(0.4)
	await _check("gameover")
	print("LAYOUTCHECK DONE issues=", layout_issues.size())
	get_tree().quit(mini(layout_issues.size(), 100))

func _poke_ui(root: Node) -> int:
	## Presses every enabled button, drags every lever, clicks every pip.
	var n: int = 0
	for b in root.find_children("*", "Button", true, false):
		var bt: Button = b
		if not bt.is_visible_in_tree() or bt.disabled or bt is OptionButton:
			continue
		if bt.text.begins_with("Leave") or bt.text.begins_with("Back to the Crew"):
			continue
		if bt is SafetyBtn:
			bt.pressed.emit()
			bt.pressed.emit()
			n += 2
			continue
		bt.button_down.emit()
		if bt.toggle_mode:
			bt.button_pressed = not bt.button_pressed
		else:
			bt.pressed.emit()
		bt.button_up.emit()
		n += 1
	for l in root.find_children("*", "Lever", true, false):
		var lv: Lever = l
		if lv.is_visible_in_tree() and not lv.disabled:
			lv.value = lv.vmin + (lv.vmax - lv.vmin) * 0.3
			lv.changed.emit(lv.value)
			n += 1
	for p in root.find_children("*", "PipRow", true, false):
		var pr: PipRow = p
		if pr.is_visible_in_tree():
			pr.changed.emit(3)
			n += 1
	for le in root.find_children("*", "LineEdit", true, false):
		var ed: LineEdit = le
		if ed.is_visible_in_tree() and ed.editable and ed.placeholder_text.begins_with("e.g."):
			ed.text = "123-45"
			ed.text_submitted.emit(ed.text)
			n += 1
	return n

func _exercise() -> void:
	await _wait(0.6)
	await _setup_mission(str(args.get("autotest", "drones")), "shift", true)
	Net.send("start", {})
	await _wait(1.0)
	await _ready_and_launch()
	await _wait(1.0)
	var total: int = 0
	for round in 2:
		for seat in ["helm", "engines", "power", "weapons", "sensors", "ops", "dc"]:
			Net.send("active", {"seat": seat})
			await _wait(0.35)
			var ui: Node = game.stations.get(seat)
			if seat == "dc" and ui != null and Net.host != null and Net.host.world != null:
				var sh: Ship = Net.host.world.ship
				sh.set_fire("ENG_P")
				sh.set_breach("RCS_FP")
				sh.modules["TUR_A"].hp = 5.0
				sh.modules["SENS"].hp = 5.0
				sh.modules["SENS"].fault = "mirror"
				sh.cut_conduit("C_UTIL", false)
				sh.cut_conduit("C_CORE", true)
				await _wait(0.4)
				for mid in sh.mod_order:
					(ui as DamageControlUI).selected = mid
					await _wait(0.1)
					total += _poke_ui(ui)
			if ui != null:
				total += _poke_ui(ui)
			await _wait(0.2)
	Net.send("active", {"seat": "captain"})
	await _wait(0.5)
	if game.cap_ui != null:
		total += _poke_ui(game.cap_ui.get_child(0))
		game.cap_ui.orders_panel.visible = true
		total += _poke_ui(game.cap_ui.orders_panel)
	await _wait(1.0)
	var st: Dictionary = Net.host.world.stats.inputs if Net.host != null and Net.host.world != null else {}
	print("EXERCISE DONE pokes=", total, " inputs=", st, " phase=", Net.host.phase)
	get_tree().quit(0)

func _sharetest() -> void:
	await _wait(0.6)
	await _setup_mission("bastion", "shift", false)
	var h: GameHost = Net.host
	Net.send("claim", {"seat": "captain"})
	h.add_peer(2, "Sensors Sam")
	h.claim(2, "sensors")
	Net.send("start", {})
	await _wait(0.6)
	h.set_ready(2, true)
	await _ready_and_launch()
	await _wait(0.5)
	h.handle_msg(2, "active", {"seat": "sensors"})
	h.handle_msg(2, "share", {"on": true})
	await _wait(0.8)
	await _shot("share_offer")
	for b in game.cap_ui.find_children("*", "Button", true, false):
		if (b as Button).text == "Show me" and (b as Button).is_visible_in_tree():
			(b as Button).pressed.emit()
	await _wait(1.2)
	await _shot("share_shown")
	print("SHARETEST shared=", game.cap_ui.shared_holder.visible, " ui=", game.cap_ui.shared_ui != null)
	for b2 in game.cap_ui.find_children("*", "Button", true, false):
		if (b2 as Button).text == "Back to the window" and (b2 as Button).is_visible_in_tree():
			(b2 as Button).pressed.emit()
	await _wait(0.6)
	print("SHARETEST after back: visible=", game.cap_ui.shared_holder.visible)
	get_tree().quit(0)

func _tour() -> void:
	## An AI crew plays while we screenshot every phase change (or a single seat, every N seconds).
	var t0: float = Time.get_ticks_msec() / 1000.0
	var limit: float = float(args.get("limit", 120.0))
	var shots: int = 0
	var last_key: String = ""
	if args.has("stress") and Net.host != null and Net.host.world != null:
		Net.host.world.director.intensity = 5.0
		Net.host.world.director.cooldown = 2.0
		if args.has("nobots"):
			Net.host.bots.clear()
	if args.has("seat"):
		Net.send("active", {"seat": str(args.seat)})
		var every: float = float(args.get("every", 4.0))
		var n: int = 0
		while Time.get_ticks_msec() / 1000.0 - t0 < limit:
			await _wait(every)
			await _shot("seat_%s_%02d" % [str(args.seat), n])
			n += 1
		get_tree().quit(0)
		return
	if args.has("manual"):
		Net.host.bot_captain.auto_continue = false
	while Time.get_ticks_msec() / 1000.0 - t0 < limit:
		await _wait(0.5)
		if Net.host == null:
			break
		var h: GameHost = Net.host
		if h.phase == "briefing":
			Net.send("ready", {"on": true})
		var key: String = h.phase + (":" + h.world.enc.id if h.phase == "encounter" and h.world.enc != null else "")
		if key != last_key:
			last_key = key
			await _wait(float(args.get("settle", 2.0)))
			await _shot("tour_%02d_%s" % [shots, key.replace(":", "_")])
			shots += 1
			if args.has("manual") and (h.phase == "debrief" or h.phase == "gameover"):
				h.captain_continue()
				last_key = ""
		if h.phase == "ending" or h.phase == "lobby":
			await _wait(1.0)
			await _shot("tour_%02d_%s" % [shots, h.phase])
			break
	print("TOUR DONE phase=", Net.host.phase if Net.host != null else "-", " shots=", shots)
	get_tree().quit(0)

func _autotest() -> void:
	if args.has("sharetest"):
		_sharetest()
		return
	if args.has("exercise"):
		_exercise()
		return
	await _wait(0.6)
	var kind: String = str(args.get("autotest", "casual"))
	var mode: String = str(args.get("mode", "shift"))
	if args.has("aicrew"):
		await _setup_mission(kind, mode, false)
		Net.send("opt", {"key": "ai_captain", "val": true})
		Net.send("claim", {"seat": "captain"})
		if args.has("seat"):
			Net.send("claim", {"seat": str(args.seat)})
		await _wait(0.3)
		await _shot("01_lobby_claimed")
		Net.send("start", {})
		await _wait(0.6)
		await _shot("02_briefing")
		await _ready_and_launch()
		await _tour()
		return
	await _setup_mission(kind, mode, true)
	await _shot("00_lobby")
	Net.send("start", {})
	await _wait(1.0)
	await _shot("01_briefing")
	await _ready_and_launch()
	await _wait(1.5)
	var wait_s: float = float(args.get("wait", 1.5))
	for seat in ["captain", "helm", "engines", "power", "weapons", "sensors", "ops", "dc"]:
		Net.send("active", {"seat": seat})
		await _wait(wait_s)
		await _shot("02_" + seat)
	Net.send("active", {"seat": "engines"})
	await _wait(0.3)
	Net.intent("engines", "thr", 0.6)
	Net.send("active", {"seat": "captain"})
	await _wait(float(args.get("tail", 3.0)))
	await _shot("03_captain_late")
	print("AUTOTEST DONE phase=", Net.host.phase if Net.host != null else "-")
	get_tree().quit(0)

func _clienttest() -> void:
	var t0: float = Time.get_ticks_msec() / 1000.0
	while not Net.is_connected_online and Time.get_ticks_msec() / 1000.0 - t0 < 6.0:
		await _wait(0.2)
	await _wait(0.8)
	print("CLIENTTEST connected=", Net.is_connected_online, " id=", Net.my_id, " state=", state)
	Net.send("claim", {"seat": "captain"})
	Net.send("claim", {"seat": "helm"})
	Net.send("opt", {"key": "mode", "val": "shift"})
	Net.send("opt", {"key": "shift_kind", "val": "drones"})
	Net.send("opt", {"key": "personality", "val": "competent"})
	await _wait(0.8)
	lobby._set_step(1)
	await _shot("client_lobby")
	Net.send("start", {})
	await _wait(1.5)
	await _shot("client_briefing")
	Net.send("ready", {"on": true})
	await _wait(4.5)
	print("CLIENTTEST in-game state=", state, " active=", Net.last_snapshot.get("active", "?"), " phase=", Net.last_snapshot.get("phase", "?"))
	Net.send("active", {"seat": "helm"})
	await _wait(0.6)
	var pokes: int = 0
	if game.stations.has("helm"):
		pokes = _poke_ui(game.stations["helm"])
	await _wait(1.5)
	await _shot("client_helm")
	Net.send("active", {"seat": "captain"})
	await _wait(1.0)
	await _shot("client_captain")
	print("CLIENTTEST done pokes=", pokes, " snapshot_has_view=", Net.last_snapshot.has("view"), " phase=", Net.last_snapshot.get("phase", "?"))
	get_tree().quit(0)
